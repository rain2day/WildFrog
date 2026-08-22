import CoreLocation
import Foundation
import Testing
@testable import WildFrogNative

@MainActor
private final class TrackRecordingFake: TrackRecording {
    var isRecording = false
    var isPaused = false
    var elapsedSeconds: TimeInterval = 0
    var distanceMeters: Double = 0
    var ascentMeters: Double = 0
    var points: [TrackPoint] = []
    var startMountainID: String?
    var startName = ""
    var finishedTrack: Track?
    var restoredCheckpoint: TripSessionCheckpoint?

    @discardableResult
    func start(mountainId: String?, mountainName: String, summitCoordinate: CLLocationCoordinate2D?) -> Bool {
        guard !isRecording else { return false }
        startMountainID = mountainId
        startName = mountainName
        isRecording = true
        return true
    }

    func restore(checkpoint: TripSessionCheckpoint, mountainId: String?, mountainName: String, summitCoordinate: CLLocationCoordinate2D?) {
        restoredCheckpoint = checkpoint
        isRecording = true
        isPaused = true
        elapsedSeconds = checkpoint.elapsedSeconds
        distanceMeters = checkpoint.distanceMeters
        ascentMeters = checkpoint.ascentMeters
        points = checkpoint.points
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func stop() -> Track? {
        isRecording = false
        return finishedTrack
    }

    func cancel() {
        isRecording = false
    }
}

private struct StubEnergyProvider: TripEnergyProviding {
    let calories: Double?

    func requestAccessAndReadActiveEnergy(from start: Date, to end: Date) async throws -> Double? {
        calories
    }
}

@MainActor
private func makeCoordinatorFixture(
    energyProvider: any TripEnergyProviding = StubEnergyProvider(calories: nil)
) throws -> (TripSessionCoordinator, TripStore, TrackRecordingFake, URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TripSessionCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    let store = TripStore(paths: TripStorePaths(rootDirectory: root))
    let recorder = TrackRecordingFake()
    let coordinator = TripSessionCoordinator(
        store: store,
        recorder: recorder,
        energyProvider: energyProvider
    )
    return (coordinator, store, recorder, root)
}

private func sampleStandaloneTrack() -> Track {
    let start = Date(timeIntervalSince1970: 1_777_777_700)
    return Track(
        name: "獨立軌跡",
        points: [TrackPoint(latitude: 22.4, longitude: 114.1, elevation: 50, timestamp: start)],
        distanceMeters: 1_200,
        durationSeconds: 900,
        ascentMeters: 80,
        startDate: start,
        endDate: start.addingTimeInterval(900)
    )
}

@Test @MainActor func standaloneTripStartsWithoutMountainAndFinishesWithTrack() throws {
    let (coordinator, store, recorder, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "城門慢行", activity: TripActivitySnapshot(.hiking))
    try store.saveTrip(trip)
    recorder.finishedTrack = sampleStandaloneTrack()

    try coordinator.start(tripID: trip.id)
    #expect(recorder.startMountainID == nil)
    #expect(recorder.startName == trip.name)
    #expect(store.trips.first { $0.id == trip.id }?.status == .active)

    let finished = try coordinator.finish()
    #expect(finished.status == .completed)
    #expect(finished.track?.points.isEmpty == false)
    #expect(store.activeCheckpoint == nil)
}

@Test @MainActor func onlyOneTripCanBeActive() throws {
    let (coordinator, store, _, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = StandaloneTrip(name: "第一程", activity: TripActivitySnapshot(.running))
    let second = StandaloneTrip(name: "第二程", activity: TripActivitySnapshot(.running))
    try store.saveTrip(first)
    try store.saveTrip(second)

    try coordinator.start(tripID: first.id)

    #expect(throws: TripSessionError.tripAlreadyActive) {
        try coordinator.start(tripID: second.id)
    }
}

@Test @MainActor func restoredCheckpointBecomesPausedAndKeepsProgress() throws {
    let (coordinator, store, recorder, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "恢復行程", activity: TripActivitySnapshot(.trailRunning), status: .active)
    try store.saveTrip(trip)
    let checkpoint = TripSessionCheckpoint(
        tripID: trip.id,
        status: .active,
        savedAt: Date().addingTimeInterval(-120),
        elapsedSeconds: 321,
        distanceMeters: 1_500,
        ascentMeters: 92,
        points: sampleStandaloneTrack().points
    )
    try store.setActiveCheckpoint(checkpoint)

    try coordinator.restoreCheckpointIfNeeded()

    #expect(coordinator.activeTrip?.status == .paused)
    #expect(recorder.restoredCheckpoint?.distanceMeters == 1_500)
    #expect(store.activeCheckpoint?.status == .paused)
}

@Test @MainActor func officialCheckInCanLinkWithoutChangingTripLifecycle() throws {
    let (coordinator, store, _, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "行山兼打卡", activity: TripActivitySnapshot(.hiking))
    try store.saveTrip(trip)
    try coordinator.start(tripID: trip.id)
    let checkInID = UUID()

    try coordinator.attachOfficialCheckIn(checkInID)

    #expect(coordinator.activeTrip?.officialCheckInIDs == [checkInID])
    #expect(coordinator.activeTrip?.status == .active)
    #expect(store.trips.first { $0.id == trip.id }?.officialCheckInIDs == [checkInID])
}

@Test @MainActor func staleCheckpointIsDroppedAndTripStaysPausedForIncompleteSave() throws {
    let (coordinator, store, recorder, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "去年嘅行程", activity: TripActivitySnapshot(.hiking), status: .active)
    try store.saveTrip(trip)
    let savedAt = Date(timeIntervalSince1970: 1_777_777_777)
    try store.setActiveCheckpoint(
        TripSessionCheckpoint(
            tripID: trip.id,
            status: .active,
            savedAt: savedAt,
            elapsedSeconds: 900,
            distanceMeters: 3_000,
            ascentMeters: 210,
            points: sampleStandaloneTrack().points
        )
    )

    try coordinator.restoreCheckpointIfNeeded(
        now: savedAt.addingTimeInterval(TripSessionCoordinator.checkpointStaleInterval + 1)
    )

    #expect(coordinator.activeTrip == nil)
    #expect(recorder.restoredCheckpoint == nil)
    #expect(recorder.isRecording == false)
    #expect(store.activeCheckpoint == nil)
    #expect(store.trips.first { $0.id == trip.id }?.status == .paused)
    #expect(coordinator.restoredGapDate == savedAt)
}

@Test @MainActor func checkpointJustInsideTheStaleWindowIsStillRestored() throws {
    let (coordinator, store, recorder, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "琴晚嘅行程", activity: TripActivitySnapshot(.hiking), status: .active)
    try store.saveTrip(trip)
    let savedAt = Date(timeIntervalSince1970: 1_777_777_777)
    try store.setActiveCheckpoint(
        TripSessionCheckpoint(
            tripID: trip.id,
            status: .active,
            savedAt: savedAt,
            elapsedSeconds: 900,
            distanceMeters: 3_000,
            ascentMeters: 210,
            points: sampleStandaloneTrack().points
        )
    )

    try coordinator.restoreCheckpointIfNeeded(
        now: savedAt.addingTimeInterval(TripSessionCoordinator.checkpointStaleInterval - 60)
    )

    #expect(coordinator.activeTrip?.status == .paused)
    #expect(recorder.restoredCheckpoint?.distanceMeters == 3_000)
    #expect(store.activeCheckpoint?.status == .paused)
}

@Test @MainActor func startingASecondTripNeverPersistsItAsActive() throws {
    let (coordinator, store, recorder, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let trip = StandaloneTrip(name: "已經記錄緊", activity: TripActivitySnapshot(.running))
    try store.saveTrip(trip)
    recorder.isRecording = true

    #expect(throws: TripSessionError.tripAlreadyActive) {
        try coordinator.start(tripID: trip.id)
    }
    #expect(store.trips.first { $0.id == trip.id }?.status == .planned)
}

@Test @MainActor func attachingACheckInWithoutAnActiveTripThrows() throws {
    let (coordinator, _, _, root) = try makeCoordinatorFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: TripSessionError.noActiveTrip) {
        try coordinator.attachOfficialCheckIn(UUID())
    }
}

@Test @MainActor func injectedEnergyProviderDistinguishesNoSamplesFromZeroCalories() async throws {
    let (noData, _, _, noDataRoot) = try makeCoordinatorFixture(
        energyProvider: StubEnergyProvider(calories: nil)
    )
    defer { try? FileManager.default.removeItem(at: noDataRoot) }
    let (zero, _, _, zeroRoot) = try makeCoordinatorFixture(
        energyProvider: StubEnergyProvider(calories: 0)
    )
    defer { try? FileManager.default.removeItem(at: zeroRoot) }

    let start = Date(timeIntervalSince1970: 1_777_777_700)
    let end = start.addingTimeInterval(900)

    let missing = try await noData.energyProvider.requestAccessAndReadActiveEnergy(from: start, to: end)
    let measured = try await zero.energyProvider.requestAccessAndReadActiveEnergy(from: start, to: end)

    #expect(missing == nil)
    #expect(measured == 0)
}

@Test @MainActor func restoredRecorderStaysDarkUntilResumeThenSamplesAgain() {
    let recorder = TrackRecorder()
    defer { recorder.cancel() }
    let checkpoint = TripSessionCheckpoint(
        tripID: UUID(),
        status: .active,
        savedAt: Date(),
        elapsedSeconds: 321,
        distanceMeters: 1_500,
        ascentMeters: 92,
        points: sampleStandaloneTrack().points
    )

    recorder.restore(checkpoint: checkpoint, mountainName: "恢復行程")

    #expect(recorder.isRecording)
    #expect(recorder.isPaused)
    #expect(recorder.isSamplingForTesting == false)
    #expect(recorder.elapsedSeconds == 321)

    recorder.resume()

    #expect(recorder.isPaused == false)
    #expect(recorder.isSamplingForTesting)
    #expect(
        recorder.allowsBackgroundLocationUpdatesForTesting
            == TrackRecorder.backgroundLocationDeclaredForTesting
    )
}

@Test @MainActor func startingAnAlreadyRecordingRecorderReportsFailure() {
    let recorder = TrackRecorder()
    defer { recorder.cancel() }

    #expect(recorder.start(mountainName: "第一程"))
    #expect(recorder.start(mountainName: "第二程") == false)
    #expect(recorder.activeMountainName == "第一程")
}
