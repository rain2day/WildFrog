import Foundation
import OSLog
import SwiftUI

enum TripSessionError: Error, Equatable {
    case tripNotFound
    case tripAlreadyActive
    case noActiveTrip
    case invalidStatus
}

@MainActor
final class TripSessionCoordinator: ObservableObject {
    @Published private(set) var activeTrip: StandaloneTrip?
    @Published private(set) var restoredGapDate: Date?

    /// A checkpoint older than this is treated as abandoned: the trip stays
    /// paused so it can still be saved as incomplete, but nothing is resumed.
    static let checkpointStaleInterval: TimeInterval = 24 * 60 * 60

    /// Injected so tests (and previews) can stand in a fake Health source.
    let energyProvider: any TripEnergyProviding

    private let store: TripStore
    private let recorder: any TrackRecording
    private let log = Logger(subsystem: "com.wildfrog.app", category: "TripSession")

    init(
        store: TripStore,
        recorder: any TrackRecording,
        energyProvider: any TripEnergyProviding = AppleHealthTripEnergyProvider()
    ) {
        self.store = store
        self.recorder = recorder
        self.energyProvider = energyProvider
    }

    func start(tripID: UUID) throws {
        guard activeTrip == nil, store.activeCheckpoint == nil, !recorder.isRecording else {
            throw TripSessionError.tripAlreadyActive
        }
        guard var trip = store.trips.first(where: { $0.id == tripID }) else {
            throw TripSessionError.tripNotFound
        }
        guard trip.status == .planned else {
            throw TripSessionError.invalidStatus
        }

        // Start the recorder first: if it refuses, the trip must not be left
        // persisted as active with nothing recording it.
        guard recorder.start(mountainId: nil, mountainName: trip.name, summitCoordinate: nil) else {
            throw TripSessionError.tripAlreadyActive
        }

        let now = Date()
        trip.status = .active
        trip.startedAt = now
        trip.completedAt = nil
        try store.saveTrip(trip)
        activeTrip = trip
        try checkpoint(at: now)
    }

    func pause() throws {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        guard trip.status == .active else { throw TripSessionError.invalidStatus }
        recorder.pause()
        trip.status = .paused
        try store.saveTrip(trip)
        activeTrip = trip
        try checkpoint()
    }

    func resume() throws {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        guard trip.status == .paused else { throw TripSessionError.invalidStatus }
        recorder.resume()
        trip.status = .active
        try store.saveTrip(trip)
        activeTrip = trip
        restoredGapDate = nil
        try checkpoint()
    }

    @discardableResult
    func finish() throws -> StandaloneTrip {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        guard trip.status == .active || trip.status == .paused else {
            throw TripSessionError.invalidStatus
        }

        trip.track = recorder.stop()
        trip.status = .completed
        trip.completedAt = Date()
        try store.saveTrip(trip)
        clearCheckpointIgnoringFailure()
        activeTrip = nil
        restoredGapDate = nil
        return trip
    }

    func cancel(saveIncomplete: Bool) throws {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        recorder.cancel()
        if saveIncomplete {
            trip.status = .cancelled
            trip.completedAt = Date()
            try store.saveTrip(trip)
        } else {
            trip.status = .planned
            trip.startedAt = nil
            try store.saveTrip(trip)
        }
        clearCheckpointIgnoringFailure()
        activeTrip = nil
        restoredGapDate = nil
    }

    func restoreCheckpointIfNeeded(now: Date = Date()) throws {
        guard activeTrip == nil, let stored = store.activeCheckpoint else { return }
        guard var trip = store.trips.first(where: { $0.id == stored.tripID }) else {
            clearCheckpointIgnoringFailure()
            throw TripSessionError.tripNotFound
        }

        guard now.timeIntervalSince(stored.savedAt) < Self.checkpointStaleInterval else {
            // Abandoned session: never re-arm the recorder or the Live Activity.
            // The trip stays paused in the store so it can still be saved as
            // incomplete from the trip list.
            trip.status = .paused
            try store.saveTrip(trip)
            clearCheckpointIgnoringFailure()
            restoredGapDate = stored.savedAt
            return
        }

        var pausedCheckpoint = stored
        pausedCheckpoint.status = .paused
        pausedCheckpoint.savedAt = Date()
        trip.status = .paused
        try store.saveTrip(trip)
        recorder.restore(
            checkpoint: pausedCheckpoint,
            mountainId: nil,
            mountainName: trip.name,
            summitCoordinate: nil
        )
        try store.setActiveCheckpoint(pausedCheckpoint)
        activeTrip = trip
        restoredGapDate = stored.savedAt
    }

    func checkpoint(at date: Date = Date()) throws {
        guard let trip = activeTrip else { throw TripSessionError.noActiveTrip }
        let checkpoint = TripSessionCheckpoint(
            tripID: trip.id,
            status: trip.status,
            savedAt: date,
            elapsedSeconds: recorder.elapsedSeconds,
            distanceMeters: recorder.distanceMeters,
            ascentMeters: recorder.ascentMeters,
            points: recorder.points
        )
        try store.setActiveCheckpoint(checkpoint)
    }

    func addConsumable(_ entry: TripConsumableEntry) throws {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        trip.consumables.append(entry)
        try store.saveTrip(trip)
        activeTrip = trip
        try checkpoint()
    }

    func attachOfficialCheckIn(_ checkInID: UUID) throws {
        guard var trip = activeTrip else { throw TripSessionError.noActiveTrip }
        if !trip.officialCheckInIDs.contains(checkInID) {
            trip.officialCheckInIDs.append(checkInID)
            try store.saveTrip(trip)
            activeTrip = trip
        }
    }

    /// Clearing the checkpoint must never fail the surrounding operation — a
    /// surviving checkpoint would resurrect a trip the user just ended.
    private func clearCheckpointIgnoringFailure() {
        do {
            try store.clearActiveCheckpoint()
        } catch {
            log.error("Failed to clear the active trip checkpoint: \(error.localizedDescription, privacy: .public)")
        }
    }
}
