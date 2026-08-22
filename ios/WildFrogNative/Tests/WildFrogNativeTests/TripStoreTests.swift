import Foundation
import Testing
@testable import WildFrogNative

private func makeTripStorePaths() throws -> TripStorePaths {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("WildFrogTripStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return TripStorePaths(rootDirectory: directory)
}

@Test @MainActor func tripStoreSeedsBuiltInsOnlyOnce() throws {
    let paths = try makeTripStorePaths()
    defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

    let first = TripStore(paths: paths)
    #expect(first.activityTypes.filter { $0.isBuiltIn }.count == 6)

    try first.archiveActivityType(TripActivityType.camping.id)
    let relaunched = TripStore(paths: paths)

    #expect(relaunched.activityTypes.first { $0.id == TripActivityType.camping.id }?.isArchived == true)
    #expect(relaunched.activityTypes.filter { $0.isBuiltIn }.count == 6)
}

@Test @MainActor func tripStoreRoundTripsGearKitsTripsAndCheckpoint() throws {
    let paths = try makeTripStorePaths()
    defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }
    let store = TripStore(paths: paths)

    let shoes = GearItem(name: "山徑鞋", category: "鞋履", unitWeightGrams: 520)
    try store.saveGearItem(shoes)
    let kit = GearKit(
        name: "山徑跑",
        activityTypeIDs: [TripActivityType.trailRunning.id],
        lines: [GearKitLine(gearItemID: shoes.id, priority: .required)]
    )
    try store.saveGearKit(kit)
    let trip = StandaloneTrip(
        name: "大帽山晨跑",
        activity: TripActivitySnapshot(.trailRunning),
        gear: kit.snapshot(using: [shoes])
    )
    try store.saveTrip(trip)
    let checkpoint = TripSessionCheckpoint(
        tripID: trip.id,
        status: .paused,
        savedAt: Date(timeIntervalSince1970: 1_777_777_777),
        elapsedSeconds: 600,
        distanceMeters: 2_400,
        ascentMeters: 180,
        points: []
    )
    try store.setActiveCheckpoint(checkpoint)
    store.waitForPendingCheckpointWrites()

    let relaunched = TripStore(paths: paths)
    #expect(relaunched.gearItems == [shoes])
    #expect(relaunched.gearKits == [kit])
    #expect(relaunched.trips == [trip])
    #expect(relaunched.activeCheckpoint == checkpoint)

    try relaunched.clearActiveCheckpoint()
    relaunched.waitForPendingCheckpointWrites()
    #expect(TripStore(paths: paths).activeCheckpoint == nil)
}

@Test @MainActor func checkpointLivesInItsOwnFileAndLeavesTheEnvelopeUntouched() throws {
    let paths = try makeTripStorePaths()
    defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }
    let store = TripStore(paths: paths)
    let trip = StandaloneTrip(name: "分檔測試", activity: TripActivitySnapshot(.hiking))
    try store.saveTrip(trip)
    let envelopeBefore = try Data(contentsOf: paths.envelopeURL)

    let checkpoint = TripSessionCheckpoint(
        tripID: trip.id,
        status: .active,
        savedAt: Date(timeIntervalSince1970: 1_777_777_777),
        elapsedSeconds: 120,
        distanceMeters: 800,
        ascentMeters: 40,
        points: [TrackPoint(latitude: 22.4, longitude: 114.1, elevation: 40, timestamp: .now)]
    )
    try store.setActiveCheckpoint(checkpoint)
    store.waitForPendingCheckpointWrites()

    let envelopeAfter = try Data(contentsOf: paths.envelopeURL)
    let envelopeKeys = Set(
        ((try JSONSerialization.jsonObject(with: envelopeAfter) as? [String: Any]) ?? [:]).keys
    )

    #expect(FileManager.default.fileExists(atPath: paths.checkpointURL.path))
    #expect(envelopeAfter == envelopeBefore)
    #expect(!envelopeKeys.contains("activeCheckpoint"))

    let relaunched = TripStore(paths: paths)
    #expect(relaunched.activeCheckpoint == checkpoint)

    try relaunched.clearActiveCheckpoint()
    relaunched.waitForPendingCheckpointWrites()
    #expect(FileManager.default.fileExists(atPath: paths.checkpointURL.path) == false)
}

@Test @MainActor func legacyInEnvelopeCheckpointMigratesToItsOwnFile() throws {
    let paths = try makeTripStorePaths()
    defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }
    let tripID = UUID()
    let legacyEnvelope: [String: Any] = [
        "schemaVersion": 1,
        "activityTypes": [],
        "gearItems": [],
        "gearKits": [],
        "trips": [],
        "activeCheckpoint": [
            "tripID": tripID.uuidString,
            "status": "active",
            "savedAt": 1_777_777_777.0 - 978_307_200.0,
            "elapsedSeconds": 200.0,
            "distanceMeters": 900.0,
            "ascentMeters": 55.0,
            "points": []
        ]
    ]
    try JSONSerialization.data(withJSONObject: legacyEnvelope)
        .write(to: paths.envelopeURL, options: .atomic)

    let store = TripStore(paths: paths)
    store.waitForPendingCheckpointWrites()

    #expect(store.activeCheckpoint?.tripID == tripID)
    #expect(store.activeCheckpoint?.distanceMeters == 900)
    #expect(FileManager.default.fileExists(atPath: paths.checkpointURL.path))
}

@Test @MainActor func corruptEnvelopeIsPreservedAndFailsSoft() throws {
    let paths = try makeTripStorePaths()
    defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }
    try Data("broken".utf8).write(to: paths.envelopeURL, options: .atomic)

    let store = TripStore(paths: paths)

    #expect(store.trips.isEmpty)
    #expect(store.activityTypes == TripActivityType.builtIns)
    #expect(store.lastCorruptEnvelopeURL != nil)
    #expect(store.lastCorruptEnvelopeURL.map { FileManager.default.fileExists(atPath: $0.path) } == true)

    // The re-seed is persisted, so the next launch is an ordinary load.
    let relaunched = TripStore(paths: paths)
    #expect(relaunched.activityTypes.filter(\.isBuiltIn).count == 6)
    #expect(relaunched.lastCorruptEnvelopeURL == nil)
}
