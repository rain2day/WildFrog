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
    /// Weather captured at check-in (WeatherKit); nil for older records.
    var weather: WeatherSnapshot?

    init(
        id: UUID = UUID(),
        mountainId: String,
        date: Date,
        photoFilename: String? = nil,
        track: TrackSummary? = nil,
        weather: WeatherSnapshot? = nil
    ) {
        self.id = id
        self.mountainId = mountainId
        self.date = date
        self.photoFilename = photoFilename
        self.track = track
        self.weather = weather
    }
}

@MainActor
final class CheckInStore: ObservableObject {
    @Published private(set) var records: [CheckInRecord] = []

    private var currentUserId: String?
    private let defaults: UserDefaults
    private let firestoreService: FirestoreService

    #if DEBUG
    /// When demo data is seeded for screenshots, skip the real account sync so
    /// the sample records aren't wiped by `configure(for:)`.
    private(set) var isDemoMode = false
    #endif

    private static let hongKongCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        return calendar
    }()

    /// Mountain+day natural key used to suppress duplicate echoes of legacy remote
    /// docs written before a stable `clientId` was stored.
    private static func dayKey(for date: Date) -> String {
        let c = hongKongCalendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    init(defaults: UserDefaults = .standard, firestoreService: FirestoreService = FirestoreService()) {
        self.defaults = defaults
        self.firestoreService = firestoreService
    }

    // MARK: - Lifecycle

    func configure(for uid: String?) async {
        #if DEBUG
        if isDemoMode { return }
        #endif
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
        let localKeys = Set(records.map { "\($0.mountainId)|\(Self.dayKey(for: $0.date))" })

        // Keep every local record (they carry the photo + track), and append only
        // the remote records that are genuinely new to this device — matched neither
        // by stable id nor by mountain+day. This never overwrites local-only data.
        var merged = records
        for remoteRecord in remote where localById[remoteRecord.id] == nil {
            let key = "\(remoteRecord.mountainId)|\(Self.dayKey(for: remoteRecord.date))"
            if localKeys.contains(key) { continue }
            merged.append(remoteRecord)
        }

        records = merged.sorted { $0.date < $1.date }
        saveCache(for: uid)
    }

    // MARK: - Mutations

    @discardableResult
    func addCheckIn(mountainId: String, photoFilename: String? = nil, track: TrackSummary? = nil) -> CheckInRecord? {
        guard let currentUserId else { return nil }
        let record = CheckInRecord(
            mountainId: mountainId,
            date: Date(),
            photoFilename: photoFilename,
            track: track
        )
        records.append(record)
        saveCache(for: currentUserId)
        return record
    }

    #if DEBUG
    /// Populates in-memory sample check-ins (not persisted) so screenshots show
    /// realistic numbers. Triggered by the `-qaDemoData` launch argument.
    func seedDemoData() {
        isDemoMode = true
        currentUserId = "demo"
        let calendar = Self.hongKongCalendar
        let base = calendar.startOfDay(for: Date())
        var seeded: [CheckInRecord] = []
        for (index, mountain) in MountainCatalog.mountains.prefix(16).enumerated() {
            let day = calendar.date(byAdding: .day, value: -index, to: base) ?? base
            seeded.append(CheckInRecord(mountainId: mountain.id, date: day))
        }
        for mountain in MountainCatalog.mountains.prefix(6) {
            seeded.append(CheckInRecord(mountainId: mountain.id, date: base))
        }
        records = seeded
    }
    #endif

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

    var visitedMountainIds: Set<String> {
        Set(records.map(\.mountainId))
    }

    func visitedCount(inRegion region: String) -> Int {
        visitedMountainIds.reduce(into: 0) { acc, id in
            if MountainCatalog.mountain(id: id).region == region { acc += 1 }
        }
    }

    var highestVisitedPeakHeight: Int {
        visitedMountainIds.map { MountainCatalog.mountain(id: $0).height }.max() ?? 0
    }

    /// Distinct calendar days (HKT) with at least one check-in — cumulative, not
    /// consecutive (daily streaks are unrealistic for a hiking app).
    var totalActiveDays: Int {
        Set(records.map { Self.hongKongCalendar.startOfDay(for: $0.date) }).count
    }

    /// How many of the four HK regions the user has reached at least one peak in.
    var regionsVisitedCount: Int {
        let canonical: Set<String> = ["新界", "大嶼山", "港島", "九龍"]
        return Set(visitedMountainIds.map { MountainCatalog.mountain(id: $0).region })
            .intersection(canonical).count
    }

    func hasVisited(mountainId: String) -> Bool {
        visitedMountainIds.contains(mountainId)
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
