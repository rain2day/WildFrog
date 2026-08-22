import Foundation
import SwiftUI

struct TripStorePaths {
    let rootDirectory: URL

    var envelopeURL: URL {
        rootDirectory.appendingPathComponent("trips-v1.json")
    }

    /// The live session checkpoint lives in its own file: it is rewritten every
    /// ~30 s while recording, and folding it into the envelope would rewrite every
    /// trip and every track point on each tick.
    var checkpointURL: URL {
        rootDirectory.appendingPathComponent("checkpoint-v1.json")
    }

    static func live(fileManager: FileManager = .default) -> TripStorePaths {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return TripStorePaths(
            rootDirectory: applicationSupport
                .appendingPathComponent("WildFrog", isDirectory: true)
                .appendingPathComponent("Trips", isDirectory: true)
        )
    }
}

enum TripStoreError: Error, Equatable {
    case unsupportedSchema(Int)
    case activityTypeNotFound
}

@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var activityTypes: [TripActivityType] = []
    @Published private(set) var gearItems: [GearItem] = []
    @Published private(set) var gearKits: [GearKit] = []
    @Published private(set) var trips: [StandaloneTrip] = []
    @Published private(set) var activeCheckpoint: TripSessionCheckpoint?
    @Published private(set) var lastCorruptEnvelopeURL: URL?

    let paths: TripStorePaths
    private let fileManager: FileManager

    private struct Envelope: Codable {
        let schemaVersion: Int
        var activityTypes: [TripActivityType]
        var gearItems: [GearItem]
        var gearKits: [GearKit]
        var trips: [StandaloneTrip]
        /// Checkpoints used to live inside the envelope. Decoded for a one-time
        /// migration into `checkpoint-v1.json`; deliberately never written back.
        var legacyActiveCheckpoint: TripSessionCheckpoint?

        enum CodingKeys: String, CodingKey {
            case schemaVersion
            case activityTypes
            case gearItems
            case gearKits
            case trips
            case legacyActiveCheckpoint = "activeCheckpoint"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encode(activityTypes, forKey: .activityTypes)
            try container.encode(gearItems, forKey: .gearItems)
            try container.encode(gearKits, forKey: .gearKits)
            try container.encode(trips, forKey: .trips)
        }
    }

    /// Serialises checkpoint writes off the main actor while preserving order.
    private let checkpointQueue = DispatchQueue(
        label: "com.wildfrog.tripstore.checkpoint",
        qos: .utility
    )

    init(paths: TripStorePaths = .live(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        load()
    }

    func saveActivityType(_ activityType: TripActivityType) throws {
        var next = snapshot()
        upsert(activityType, in: &next.activityTypes)
        try commit(next)
    }

    func archiveActivityType(_ id: String) throws {
        var next = snapshot()
        guard let index = next.activityTypes.firstIndex(where: { $0.id == id }) else {
            throw TripStoreError.activityTypeNotFound
        }
        next.activityTypes[index].isArchived = true
        try commit(next)
    }

    func saveGearItem(_ item: GearItem) throws {
        var next = snapshot()
        upsert(item, in: &next.gearItems)
        try commit(next)
    }

    func saveGearKit(_ kit: GearKit) throws {
        var next = snapshot()
        upsert(kit, in: &next.gearKits)
        try commit(next)
    }

    func saveTrip(_ trip: StandaloneTrip) throws {
        var next = snapshot()
        upsert(trip, in: &next.trips)
        try commit(next)
    }

    /// Permanently removes a trip (All Trips → swipe to delete). Callers must
    /// make sure the trip isn't the live session before calling.
    func deleteTrip(_ id: UUID) throws {
        var next = snapshot()
        next.trips.removeAll { $0.id == id }
        if activeCheckpoint?.tripID == id { try clearActiveCheckpoint() }
        try commit(next)
    }

    func setActiveCheckpoint(_ checkpoint: TripSessionCheckpoint) throws {
        // Encode on the main actor (the model is main-actor state), write on the
        // serial queue so a 30 s tick never blocks the recording UI.
        let data = try Self.checkpointEncoder().encode(checkpoint)
        activeCheckpoint = checkpoint
        enqueueCheckpointWrite(data)
    }

    func clearActiveCheckpoint() throws {
        activeCheckpoint = nil
        enqueueCheckpointWrite(nil)
    }

    /// Blocks until every queued checkpoint write has landed on disk. Used by
    /// tests and by anything that needs the file to be current right now.
    func waitForPendingCheckpointWrites() {
        checkpointQueue.sync {}
    }

    #if DEBUG
    func seedQADataIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-qaTrips"), trips.isEmpty else { return }
        let shoes = GearItem(name: "山徑鞋", category: "穿著", unitWeightGrams: 620)
        let water = GearItem(name: "水 1.5L", category: "補給", unitWeightGrams: 1_500)
        let camera = GearItem(name: "微距相機", category: "攝影", unitWeightGrams: 490)
        let kit = GearKit(
            name: "昆蟲攝影輕裝",
            activityTypeIDs: [TripActivityType.insectPhotography.id],
            lines: [
                GearKitLine(gearItemID: shoes.id, priority: .required),
                GearKitLine(gearItemID: water.id, priority: .required),
                GearKitLine(gearItemID: camera.id, priority: .optional)
            ]
        )
        do {
            try saveGearItem(shoes)
            try saveGearItem(water)
            try saveGearItem(camera)
            try saveGearKit(kit)
            try saveTrip(StandaloneTrip(
                name: "城門昆蟲觀察",
                activity: TripActivitySnapshot(.insectPhotography),
                scheduledAt: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                gear: kit.snapshot(using: [shoes, water, camera])
            ))
        } catch {}
    }
    #endif

    private func load() {
        var legacyCheckpoint: TripSessionCheckpoint?
        do {
            try prepareDirectory()
            guard fileManager.fileExists(atPath: paths.envelopeURL.path) else {
                let initial = Envelope(
                    schemaVersion: 1,
                    activityTypes: TripActivityType.builtIns,
                    gearItems: [],
                    gearKits: [],
                    trips: [],
                    legacyActiveCheckpoint: nil
                )
                try persist(initial)
                apply(initial)
                loadCheckpoint(migrating: nil)
                return
            }

            let data = try Data(contentsOf: paths.envelopeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == 1 else {
                throw TripStoreError.unsupportedSchema(envelope.schemaVersion)
            }
            legacyCheckpoint = envelope.legacyActiveCheckpoint
            apply(envelope)
        } catch {
            preserveCorruptEnvelope()
            // A corrupt envelope must still leave the app usable: re-seed the
            // built-in activities exactly like a fresh install does, and persist
            // them so the next launch is a normal load.
            let reseeded = Envelope(
                schemaVersion: 1,
                activityTypes: TripActivityType.builtIns,
                gearItems: [],
                gearKits: [],
                trips: [],
                legacyActiveCheckpoint: nil
            )
            try? persist(reseeded)
            apply(reseeded)
        }
        loadCheckpoint(migrating: legacyCheckpoint)
    }

    private func loadCheckpoint(migrating legacy: TripSessionCheckpoint?) {
        if fileManager.fileExists(atPath: paths.checkpointURL.path) {
            do {
                let data = try Data(contentsOf: paths.checkpointURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .deferredToDate
                activeCheckpoint = try decoder.decode(TripSessionCheckpoint.self, from: data)
                return
            } catch {
                preserveCorruptCheckpoint()
            }
        }
        guard let legacy else { return }
        // One-time migration out of the old in-envelope checkpoint.
        try? setActiveCheckpoint(legacy)
    }

    private func snapshot() -> Envelope {
        Envelope(
            schemaVersion: 1,
            activityTypes: activityTypes,
            gearItems: gearItems,
            gearKits: gearKits,
            trips: trips,
            legacyActiveCheckpoint: nil
        )
    }

    private func commit(_ envelope: Envelope) throws {
        try persist(envelope)
        apply(envelope)
    }

    private func apply(_ envelope: Envelope) {
        activityTypes = envelope.activityTypes
        gearItems = envelope.gearItems.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        gearKits = envelope.gearKits.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        trips = envelope.trips.sorted {
            if $0.scheduledAt == $1.scheduledAt { return $0.createdAt > $1.createdAt }
            return $0.scheduledAt > $1.scheduledAt
        }
    }

    private func persist(_ envelope: Envelope) throws {
        try prepareDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let temporaryURL = paths.rootDirectory
            .appendingPathComponent(".trips-\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: .atomic)
        if fileManager.fileExists(atPath: paths.envelopeURL.path) {
            _ = try fileManager.replaceItemAt(paths.envelopeURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: paths.envelopeURL)
        }
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: paths.rootDirectory, withIntermediateDirectories: true)
    }

    private static func checkpointEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// `nil` data removes the checkpoint file. Only `Sendable` values cross the
    /// queue boundary; the writer uses its own `FileManager` instance.
    private func enqueueCheckpointWrite(_ data: Data?) {
        let directory = paths.rootDirectory
        let destination = paths.checkpointURL
        checkpointQueue.async {
            Self.writeCheckpointFile(data, to: destination, in: directory)
        }
    }

    nonisolated private static func writeCheckpointFile(
        _ data: Data?,
        to destination: URL,
        in directory: URL
    ) {
        let fileManager = FileManager()
        do {
            guard let data else {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                return
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let temporaryURL = directory
                .appendingPathComponent(".checkpoint-\(UUID().uuidString).tmp")
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destination)
            }
        } catch {
            // A dropped checkpoint costs at most the last tick of progress; the
            // recording itself keeps running in memory.
        }
    }

    private func preserveCorruptCheckpoint() {
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let target = paths.rootDirectory
            .appendingPathComponent("checkpoint-v1.corrupt-\(timestamp).json")
        try? fileManager.moveItem(at: paths.checkpointURL, to: target)
        activeCheckpoint = nil
    }

    private func preserveCorruptEnvelope() {
        guard fileManager.fileExists(atPath: paths.envelopeURL.path) else { return }
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let target = paths.rootDirectory
            .appendingPathComponent("trips-v1.corrupt-\(timestamp).json")
        do {
            try fileManager.moveItem(at: paths.envelopeURL, to: target)
            lastCorruptEnvelopeURL = target
        } catch {
            lastCorruptEnvelopeURL = paths.envelopeURL
        }
    }

    private func upsert<Value: Identifiable>(_ value: Value, in values: inout [Value]) where Value.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
    }
}
