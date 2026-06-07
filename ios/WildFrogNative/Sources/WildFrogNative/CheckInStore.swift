import Foundation

/// A recorded hike snapshot bound to a single check-in: the GPS path plus its
/// derived statistics. Persisted alongside the check-in so the proof of the
/// climb travels with it.
struct TrackSummary: Codable, Equatable {
    var coordinates: [TrackPoint]
    var distanceMeters: Double
    var durationSeconds: Double
    var ascentMeters: Double

    init(coordinates: [TrackPoint], distanceMeters: Double, durationSeconds: Double, ascentMeters: Double) {
        self.coordinates = coordinates
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.ascentMeters = ascentMeters
    }

    init(track: Track) {
        self.coordinates = track.points
        self.distanceMeters = track.distanceMeters
        self.durationSeconds = track.durationSeconds
        self.ascentMeters = track.ascentMeters
    }
}

struct CheckInRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let mountainId: String
    let date: Date
    var photoFilename: String?
    var track: TrackSummary?

    init(
        id: UUID = UUID(),
        mountainId: String,
        date: Date,
        photoFilename: String? = nil,
        track: TrackSummary? = nil
    ) {
        self.id = id
        self.mountainId = mountainId
        self.date = date
        self.photoFilename = photoFilename
        self.track = track
    }
}

@MainActor
final class CheckInStore: ObservableObject {
    @Published private(set) var records: [CheckInRecord] = []

    private var currentUserId: String?
    private let defaults: UserDefaults
    private let firestoreService: FirestoreService

    private static let hongKongCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        return calendar
    }()

    init(defaults: UserDefaults = .standard, firestoreService: FirestoreService = FirestoreService()) {
        self.defaults = defaults
        self.firestoreService = firestoreService
    }

    // MARK: - Lifecycle

    func configure(for uid: String?) async {
        guard let uid else {
            records = []
            currentUserId = nil
            return
        }

        currentUserId = uid
        records = loadCache(for: uid)

        guard let remote = try? await firestoreService.fetchUserCheckIns(userId: uid) else {
            return
        }

        // Guard against a race where the account changed while awaiting.
        guard currentUserId == uid else { return }

        let localById = Dictionary(
            records.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let reconciled = remote.map { record -> CheckInRecord in
            var record = record
            let local = localById[record.id]
            if record.photoFilename == nil, let localPhoto = local?.photoFilename {
                record.photoFilename = localPhoto
            }
            if record.track == nil, let localTrack = local?.track {
                record.track = localTrack
            }
            return record
        }

        records = reconciled
        saveCache(for: uid)
    }

    // MARK: - Mutations

    func addCheckIn(mountainId: String, photoFilename: String? = nil, track: TrackSummary? = nil) {
        guard let currentUserId else { return }
        let record = CheckInRecord(
            mountainId: mountainId,
            date: Date(),
            photoFilename: photoFilename,
            track: track
        )
        records.append(record)
        saveCache(for: currentUserId)
    }

    // MARK: - Queries

    func count(for mountainId: String) -> Int {
        records.reduce(into: 0) { $0 += ($1.mountainId == mountainId ? 1 : 0) }
    }

    var totalCheckIns: Int {
        records.count
    }

    var distinctMountainCount: Int {
        Set(records.map(\.mountainId)).count
    }

    var currentStreak: Int {
        let calendar = Self.hongKongCalendar
        let activeDays = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        var cursor: Date
        if activeDays.contains(today) {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  activeDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func days(year: Int, month: Int) -> Set<Int> {
        let calendar = Self.hongKongCalendar
        var result: Set<Int> = []
        for record in records {
            let components = calendar.dateComponents([.year, .month, .day], from: record.date)
            if components.year == year, components.month == month, let day = components.day {
                result.insert(day)
            }
        }
        return result
    }

    // MARK: - Persistence

    private func cacheKey(for uid: String) -> String {
        "wildfrog.checkins.v2.\(uid)"
    }

    private func loadCache(for uid: String) -> [CheckInRecord] {
        guard let data = defaults.data(forKey: cacheKey(for: uid)),
              let decoded = try? JSONDecoder().decode([CheckInRecord].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveCache(for uid: String) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: cacheKey(for: uid))
    }
}
