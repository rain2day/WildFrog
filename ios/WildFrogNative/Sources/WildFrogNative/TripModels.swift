import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case planned
    case active
    case paused
    case completed
    case cancelled
}

struct TripActivityType: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var nameZH: String
    var nameEN: String
    var symbolName: String
    var colorToken: String
    var isBuiltIn: Bool
    var isArchived: Bool
    var defaultGearKitID: UUID?

    var localizedName: String {
        AppText.value(zh: nameZH, en: nameEN)
    }

    static let hiking = builtIn(
        id: "activity.hiking",
        zh: "行山",
        en: "Hiking",
        symbol: "figure.hiking",
        color: "moss"
    )
    static let trailRunning = builtIn(
        id: "activity.trail-running",
        zh: "山徑跑",
        en: "Trail Running",
        symbol: "figure.run",
        color: "orange"
    )
    static let running = builtIn(
        id: "activity.running",
        zh: "跑步",
        en: "Running",
        symbol: "figure.run.circle",
        color: "leaf"
    )
    static let insectPhotography = builtIn(
        id: "activity.insect-photography",
        zh: "昆蟲攝影",
        en: "Insect Photography",
        symbol: "camera.macro",
        color: "gold"
    )
    static let landscapePhotography = builtIn(
        id: "activity.landscape-photography",
        zh: "風景攝影",
        en: "Landscape Photography",
        symbol: "camera.fill",
        color: "sky"
    )
    static let camping = builtIn(
        id: "activity.camping",
        zh: "露營",
        en: "Camping",
        symbol: "tent.fill",
        color: "forest"
    )

    static let builtIns = [
        hiking,
        trailRunning,
        running,
        insectPhotography,
        landscapePhotography,
        camping
    ]

    static func custom(
        name: String,
        symbolName: String = "figure.outdoor.cycle",
        colorToken: String = "moss"
    ) -> TripActivityType {
        TripActivityType(
            id: "activity.custom.\(UUID().uuidString.lowercased())",
            nameZH: name,
            nameEN: name,
            symbolName: symbolName,
            colorToken: colorToken,
            isBuiltIn: false,
            isArchived: false,
            defaultGearKitID: nil
        )
    }

    private static func builtIn(
        id: String,
        zh: String,
        en: String,
        symbol: String,
        color: String
    ) -> TripActivityType {
        TripActivityType(
            id: id,
            nameZH: zh,
            nameEN: en,
            symbolName: symbol,
            colorToken: color,
            isBuiltIn: true,
            isArchived: false,
            defaultGearKitID: nil
        )
    }
}

struct TripActivitySnapshot: Codable, Equatable, Hashable {
    let id: String
    let nameZH: String
    let nameEN: String
    let symbolName: String
    let colorToken: String

    init(_ activity: TripActivityType) {
        id = activity.id
        nameZH = activity.nameZH
        nameEN = activity.nameEN
        symbolName = activity.symbolName
        colorToken = activity.colorToken
    }

    var localizedName: String {
        AppText.value(zh: nameZH, en: nameEN)
    }
}

struct GearItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var brand: String?
    var unitWeightGrams: Double?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        brand: String? = nil,
        unitWeightGrams: Double? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brand = brand
        self.unitWeightGrams = unitWeightGrams
        self.isArchived = isArchived
    }
}

enum GearPriority: String, Codable, CaseIterable {
    case required
    case optional

    var localizedName: String {
        switch self {
        case .required: AppText.value(zh: "必要", en: "Required")
        case .optional: AppText.value(zh: "選帶", en: "Optional")
        }
    }
}

struct GearKitLine: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var gearItemID: UUID
    var quantity: Int
    var priority: GearPriority

    init(
        id: UUID = UUID(),
        gearItemID: UUID,
        quantity: Int = 1,
        priority: GearPriority = .optional
    ) {
        self.id = id
        self.gearItemID = gearItemID
        self.quantity = max(1, quantity)
        self.priority = priority
    }
}

struct GearKit: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var activityTypeIDs: Set<String>
    var lines: [GearKitLine]
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        activityTypeIDs: Set<String> = [],
        lines: [GearKitLine] = [],
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.activityTypeIDs = activityTypeIDs
        self.lines = lines
        self.isArchived = isArchived
    }

    func snapshot(using items: [GearItem]) -> [TripGearEntry] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return lines.compactMap { line in
            guard let item = itemsByID[line.gearItemID] else { return nil }
            return TripGearEntry(
                sourceGearItemID: item.id,
                name: item.name,
                category: item.category,
                brand: item.brand,
                unitWeightGrams: item.unitWeightGrams,
                quantity: line.quantity,
                priority: line.priority
            )
        }
    }
}

struct TripGearEntry: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var sourceGearItemID: UUID?
    var name: String
    var category: String
    var brand: String?
    var unitWeightGrams: Double?
    var quantity: Int
    var priority: GearPriority
    var isPacked: Bool

    init(
        id: UUID = UUID(),
        sourceGearItemID: UUID? = nil,
        name: String,
        category: String,
        brand: String? = nil,
        unitWeightGrams: Double? = nil,
        quantity: Int = 1,
        priority: GearPriority = .optional,
        isPacked: Bool = false
    ) {
        self.id = id
        self.sourceGearItemID = sourceGearItemID
        self.name = name
        self.category = category
        self.brand = brand
        self.unitWeightGrams = unitWeightGrams
        self.quantity = max(1, quantity)
        self.priority = priority
        self.isPacked = isPacked
    }
}

enum ConsumableKind: String, Codable, CaseIterable {
    case water
    case food
    case otherDrink

    var localizedName: String {
        switch self {
        case .water: AppText.value(zh: "水", en: "Water")
        case .food: AppText.value(zh: "食物", en: "Food")
        case .otherDrink: AppText.value(zh: "其他飲品", en: "Other Drink")
        }
    }

    var symbolName: String {
        switch self {
        case .water: "drop.fill"
        case .food: "fork.knife"
        case .otherDrink: "cup.and.saucer.fill"
        }
    }
}

enum ConsumableUnit: String, Codable, CaseIterable {
    case millilitres
    case litres
    case grams
    case servings
    case items

    var localizedName: String {
        switch self {
        case .millilitres: "ml"
        case .litres: "L"
        case .grams: "g"
        case .servings: AppText.value(zh: "份", en: "servings")
        case .items: AppText.value(zh: "件", en: "items")
        }
    }
}

struct TripConsumableEntry: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var kind: ConsumableKind
    var name: String
    var unit: ConsumableUnit
    var plannedQuantity: Double
    var consumedQuantity: Double
    var consumedCalories: Double

    init(
        id: UUID = UUID(),
        kind: ConsumableKind,
        name: String,
        unit: ConsumableUnit,
        plannedQuantity: Double = 0,
        consumedQuantity: Double = 0,
        consumedCalories: Double = 0
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.unit = unit
        self.plannedQuantity = max(0, plannedQuantity)
        self.consumedQuantity = max(0, consumedQuantity)
        self.consumedCalories = max(0, consumedCalories)
    }
}

struct StandaloneTrip: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var activity: TripActivitySnapshot
    var scheduledAt: Date
    var status: TripStatus
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var notes: String
    var gear: [TripGearEntry]
    var consumables: [TripConsumableEntry]
    var track: Track?
    var officialCheckInIDs: [UUID]
    var appleHealthActiveCalories: Double?
    var healthEnergyRefreshedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        activity: TripActivitySnapshot,
        scheduledAt: Date = .now,
        status: TripStatus = .planned,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        notes: String = "",
        gear: [TripGearEntry] = [],
        consumables: [TripConsumableEntry] = [],
        track: Track? = nil,
        officialCheckInIDs: [UUID] = [],
        appleHealthActiveCalories: Double? = nil,
        healthEnergyRefreshedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.activity = activity
        self.scheduledAt = scheduledAt
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.gear = gear
        self.consumables = consumables
        self.track = track
        self.officialCheckInIDs = officialCheckInIDs
        self.appleHealthActiveCalories = appleHealthActiveCalories
        self.healthEnergyRefreshedAt = healthEnergyRefreshedAt
    }
}

/// The crash/relaunch snapshot of a live trip. It carries the full point buffer
/// and is rewritten every ~30 s, so it is persisted in its own `checkpoint-v1.json`
/// rather than inside the trips envelope.
struct TripSessionCheckpoint: Codable, Equatable {
    var tripID: UUID
    var status: TripStatus
    var savedAt: Date
    var elapsedSeconds: TimeInterval
    var distanceMeters: Double
    var ascentMeters: Double
    var points: [TrackPoint]
}

enum TripTotals {
    static func waterMillilitres(_ entries: [TripConsumableEntry]) -> Double {
        fluidMillilitres(entries.filter { $0.kind == .water })
    }

    static func fluidMillilitres(_ entries: [TripConsumableEntry]) -> Double {
        entries.reduce(0) { total, entry in
            switch entry.unit {
            case .litres:
                total + entry.consumedQuantity * 1_000
            case .millilitres:
                total + entry.consumedQuantity
            case .grams, .servings, .items:
                total
            }
        }
    }

    static func intakeCalories(_ entries: [TripConsumableEntry]) -> Double {
        entries.reduce(0) { $0 + $1.consumedCalories }
    }

    static func gearWeight(_ entries: [TripGearEntry]) -> (knownGrams: Double, unknownLineCount: Int) {
        entries.reduce(into: (knownGrams: 0, unknownLineCount: 0)) { result, entry in
            if let unitWeight = entry.unitWeightGrams {
                result.knownGrams += unitWeight * Double(entry.quantity)
            } else {
                result.unknownLineCount += 1
            }
        }
    }
}

struct PackingProjection: Equatable {
    struct Section: Equatable {
        let priority: GearPriority
        let entries: [TripGearEntry]
    }

    let sections: [Section]
    let packedCount: Int
    let totalCount: Int
    let missingRequiredCount: Int

    init(entries: [TripGearEntry]) {
        sections = GearPriority.allCases.compactMap { priority in
            let matches = entries.filter { $0.priority == priority }
            return matches.isEmpty ? nil : Section(priority: priority, entries: matches)
        }
        packedCount = entries.filter(\.isPacked).count
        totalCount = entries.count
        missingRequiredCount = entries.filter { $0.priority == .required && !$0.isPacked }.count
    }

    /// Missing required gear only warns; it never blocks starting a trip.
    var shouldWarnBeforeStart: Bool { missingRequiredCount > 0 }
}
