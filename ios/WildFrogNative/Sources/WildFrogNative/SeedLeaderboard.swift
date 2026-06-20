import SwiftUI

enum SeedLeaderboardScope {
    case month
    case all
}

enum SeedLeaderboardDelta {
    case up
    case down
    case flat
}

struct SeedHikerProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let homeRegion: String
    let style: String
    let titleMountainId: String?
    let heroMountainId: String
    let progressSeed: Int
    let baseMonthCheckIns: Int
    let baseTotalCheckIns: Int
    let baseDistinctPeaks: Int
    let cadenceDays: Int
    let weekendCycle: Int

    var unlockedTitle: String? {
        guard let titleMountainId else { return nil }
        return MountainCatalog.mountain(id: titleMountainId).unlockTitle
    }

    var localizedUnlockedTitle: String? {
        guard let titleMountainId else { return nil }
        return MountainCatalog.mountain(id: titleMountainId).localizedUnlockTitle
    }

    var avatarAssetName: String {
        let suffix = id.split(separator: "-").last.flatMap { Int($0) } ?? 1
        let assetIndex = ((suffix - 1) % 72) + 1
        return String(format: "SeedAvatar%03d", assetIndex)
    }
}

struct SeedLeaderboardEntry: Identifiable {
    let rank: Int
    let profile: SeedHikerProfile
    let score: Int
    let distinctPeaks: Int
    let delta: SeedLeaderboardDelta
    let deltaN: Int

    var id: String { profile.id }

    func subtitle(scope: SeedLeaderboardScope) -> String {
        let title = profile.localizedUnlockedTitle ?? AppText.value(zh: "\(distinctPeaks)峰", en: "\(distinctPeaks) peaks")
        let home = AppText.seedRegion(profile.homeRegion)
        switch scope {
        case .month:
            return "\(home) · \(AppText.hikerStyle(profile.style)) · \(title)"
        case .all:
            return AppText.value(
                zh: "\(profile.homeRegion) · 累計 \(distinctPeaks) 座 · \(title)",
                en: "\(home) · \(distinctPeaks) peaks total · \(title)"
            )
        }
    }
}

struct SeedMountainVisit: Identifiable {
    let id: String
    let mountain: Mountain
    let date: Date
    let repeatCount: Int
}

struct SeedAchievementSummary: Identifiable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let tint: Color

    var localizedTitle: String {
        AppText.value(zh: title, en: englishTitle)
    }

    var localizedDescription: String {
        AppText.value(zh: description, en: englishDescription)
    }

    private var englishTitle: String {
        switch id {
        case "peaks1": return "First Peak"
        case "peaks10": return "Ten Peaks"
        case "peaks20": return "Trailblazer"
        case "peaks50": return "Peak Explorer"
        case "peaks100": return "Century Hiker"
        case "peaks300": return "300 Peak Champion"
        case "checkins25": return "Dedicated Logger"
        case "checkins300": return "Check-in Champion"
        case "days7": return "Seven Active Days"
        case "days30": return "Thirty Active Days"
        case "regions4": return "All-region Explorer"
        case "height700": return "700m Climber"
        case "height957": return "Highest Point"
        default: return title
        }
    }

    private var englishDescription: String {
        let number = Int(String(id.filter { $0.isNumber })) ?? 0
        if id.hasPrefix("peaks") {
            return number == 1 ? "Summit 1 peak" : "Summit \(number) peaks"
        }
        if id.hasPrefix("checkins") {
            return number == 1 ? "Complete 1 check-in" : "Complete \(number) check-ins"
        }
        if id.hasPrefix("days") {
            return number == 1 ? "Check in on 1 active day" : "Check in on \(number) active days"
        }
        if id.hasPrefix("regions") {
            return "Explore \(number) Hong Kong regions"
        }
        if id.hasPrefix("height") {
            return "Reach a peak above \(number)m"
        }
        return description
    }
}

enum SeedLeaderboard {
    static let profiles: [SeedHikerProfile] = []

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        return calendar
    }()

    private static var seedEpoch: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? Date(timeIntervalSince1970: 1_780_272_000)
    }

    static func entries(scope: SeedLeaderboardScope, asOf date: Date) -> [SeedLeaderboardEntry] {
        entries(profiles: profiles, scope: scope, asOf: date)
    }

    static func entries(profiles: [SeedHikerProfile], scope: SeedLeaderboardScope, asOf date: Date) -> [SeedLeaderboardEntry] {
        let current = rankedProfiles(profiles: profiles, scope: scope, asOf: date)

        return current.map { row in
            return SeedLeaderboardEntry(
                rank: row.rank,
                profile: row.profile,
                score: row.score,
                distinctPeaks: row.distinctPeaks,
                delta: .flat,
                deltaN: 0
            )
        }
    }

    static func rank(for score: Int, scope: SeedLeaderboardScope, asOf date: Date) -> Int {
        rank(for: score, among: profiles, scope: scope, asOf: date)
    }

    static func rank(for score: Int, among profiles: [SeedHikerProfile], scope: SeedLeaderboardScope, asOf date: Date) -> Int {
        rankedProfiles(profiles: profiles, scope: scope, asOf: date).filter { $0.score > score }.count + 1
    }

    static func checkedMountains(for profile: SeedHikerProfile, asOf date: Date) -> [Mountain] {
        let targetCount = min(MountainCatalog.catalogCount, max(0, distinctPeakCount(for: profile, asOf: date)))
        guard targetCount > 0 else { return [] }
        return Array(seededMountainOrder(for: profile).prefix(targetCount))
    }

    static func recentVisits(for profile: SeedHikerProfile, asOf date: Date, limit: Int = 5) -> [SeedMountainVisit] {
        let checked = checkedMountains(for: profile, asOf: date)
        guard !checked.isEmpty else { return [] }

        let base = calendar.startOfDay(for: date)
        return (0..<min(limit, checked.count)).map { index in
            let mountainIndex = (profile.progressSeed + index * 7) % checked.count
            let daysAgo = index * max(1, profile.cadenceDays - 1) + ((profile.progressSeed + index) % 3)
            let visitDate = calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? date
            let repeatCount = 1 + ((profile.progressSeed + index * 3) % 4)
            let mountain = checked[mountainIndex]
            return SeedMountainVisit(
                id: "\(profile.id)-\(mountain.id)-\(index)",
                mountain: mountain,
                date: visitDate,
                repeatCount: repeatCount
            )
        }
        .sorted { $0.date > $1.date }
    }

    static func unlockedAchievements(for profile: SeedHikerProfile, asOf date: Date, limit: Int = 6) -> [SeedAchievementSummary] {
        let checked = checkedMountains(for: profile, asOf: date)
        let total = score(for: profile, scope: .all, asOf: date)
        let activeDays = min(total, max(1, total / 2 + (profile.progressSeed % 21)))
        let highest = checked.map(\.height).max() ?? 0
        let regions = Set(checked.map(\.region)).count

        return achievementSummaries(
            distinctPeaks: checked.count,
            totalCheckIns: total,
            activeDays: activeDays,
            highestPeakHeight: highest,
            regionsVisited: regions,
            limit: limit
        )
    }

    static func achievementSummaries(
        distinctPeaks: Int,
        totalCheckIns: Int,
        activeDays: Int,
        highestPeakHeight: Int,
        regionsVisited: Int,
        limit: Int = 6
    ) -> [SeedAchievementSummary] {
        let candidates: [(isUnlocked: Bool, badge: SeedAchievementSummary)] = [
            (distinctPeaks >= 300, SeedAchievementSummary(id: "peaks300", title: "300 Peak Champion", description: "登頂 300 座香港山峰", systemImage: "trophy.fill", tint: FrogTheme.orange)),
            (distinctPeaks >= 100, SeedAchievementSummary(id: "peaks100", title: "Century Hiker", description: "登頂 100 座山峰", systemImage: "trophy.fill", tint: FrogTheme.gold)),
            (distinctPeaks >= 50, SeedAchievementSummary(id: "peaks50", title: "Peak Explorer", description: "登頂 50 座山峰", systemImage: "star.circle.fill", tint: FrogTheme.gold)),
            (distinctPeaks >= 20, SeedAchievementSummary(id: "peaks20", title: "Trailblazer", description: "登頂 20 座山峰", systemImage: "location.fill", tint: FrogTheme.slate)),
            (distinctPeaks >= 10, SeedAchievementSummary(id: "peaks10", title: "Ten Peaks", description: "登頂 10 座山峰", systemImage: "flag.fill", tint: FrogTheme.moss)),
            (distinctPeaks >= 1, SeedAchievementSummary(id: "peaks1", title: "首座山峰", description: "登頂 1 座山峰", systemImage: "figure.hiking", tint: FrogTheme.leaf)),
            (totalCheckIns >= 300, SeedAchievementSummary(id: "checkins300", title: "打卡王", description: "完成 300 次打卡", systemImage: "rosette", tint: FrogTheme.orange)),
            (totalCheckIns >= 100, SeedAchievementSummary(id: "checkins100", title: "Centurion", description: "完成 100 次打卡", systemImage: "star.fill", tint: FrogTheme.gold)),
            (totalCheckIns >= 25, SeedAchievementSummary(id: "checkins25", title: "勤力打卡", description: "完成 25 次打卡", systemImage: "calendar", tint: FrogTheme.slate)),
            (activeDays >= 30, SeedAchievementSummary(id: "days30", title: "三十日山途", description: "累計打卡 30 日", systemImage: "calendar", tint: FrogTheme.forest)),
            (activeDays >= 7, SeedAchievementSummary(id: "days7", title: "一週山客", description: "累計打卡 7 日", systemImage: "calendar", tint: FrogTheme.moss)),
            (regionsVisited >= 4, SeedAchievementSummary(id: "regions4", title: "四區走遍", description: "走遍全港 4 區", systemImage: "globe.asia.australia.fill", tint: FrogTheme.orange)),
            (highestPeakHeight >= 957, SeedAchievementSummary(id: "height957", title: "香港之巔", description: "登上大帽山 957m", systemImage: "crown.fill", tint: FrogTheme.gold)),
            (highestPeakHeight >= 700, SeedAchievementSummary(id: "height700", title: "700m 高度", description: "登上 700m 以上山峰", systemImage: "triangle.fill", tint: FrogTheme.forest))
        ]

        return Array(candidates.filter(\.isUnlocked).map(\.badge).prefix(limit))
    }

    private static func rankedProfiles(profiles: [SeedHikerProfile], scope: SeedLeaderboardScope, asOf date: Date) -> [(rank: Int, profile: SeedHikerProfile, score: Int, distinctPeaks: Int)] {
        profiles
            .map { profile in
                let score = score(for: profile, scope: scope, asOf: date)
                let distinctPeaks = distinctPeakCount(for: profile, asOf: date)
                return (profile: profile, score: score, distinctPeaks: distinctPeaks)
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.profile.id < $1.profile.id
            }
            .enumerated()
            .map { index, row in
                (rank: index + 1, profile: row.profile, score: row.score, distinctPeaks: row.distinctPeaks)
            }
    }

    static func score(for profile: SeedHikerProfile, scope: SeedLeaderboardScope, asOf date: Date) -> Int {
        switch scope {
        case .month:
            return max(0, profile.baseMonthCheckIns + rollingGain(for: profile, from: monthStart(for: date), to: date))
        case .all:
            return max(0, profile.baseTotalCheckIns + rollingGain(for: profile, from: seedEpoch, to: date))
        }
    }

    private static func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func rollingGain(for profile: SeedHikerProfile, from startDate: Date, to endDate: Date) -> Int {
        let start = calendar.startOfDay(for: max(startDate, seedEpoch))
        let end = calendar.startOfDay(for: endDate)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        guard days > 0 else { return 0 }

        var gain = 0
        for offset in 0...days {
            let marker = offset + profile.progressSeed
            if marker % profile.cadenceDays == 0 {
                gain += marker % 4 == 0 ? 2 : 1
            }

            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            if isWeekend && marker % profile.weekendCycle == 0 {
                gain += 1
            }
        }
        return gain
    }

    private static func distinctPeakCount(for profile: SeedHikerProfile, asOf date: Date) -> Int {
        let totalScore = score(for: profile, scope: .all, asOf: date)
        return min(MountainCatalog.catalogCount, profile.baseDistinctPeaks + totalScore / 18 + rollingGain(for: profile, from: seedEpoch, to: date) / 3)
    }

    private static func seededMountainOrder(for profile: SeedHikerProfile) -> [Mountain] {
        var seen: Set<String> = []
        let priorityIds = [profile.heroMountainId, profile.titleMountainId].compactMap { $0 }
        let priority = priorityIds.compactMap { id -> Mountain? in
            guard seen.insert(id).inserted else { return nil }
            return MountainCatalog.mountain(id: id)
        }

        let ranked = MountainCatalog.mountains.sorted { lhs, rhs in
            let lhsValue = seededSortValue(for: lhs, profile: profile)
            let rhsValue = seededSortValue(for: rhs, profile: profile)
            if lhsValue != rhsValue { return lhsValue < rhsValue }
            return lhs.id < rhs.id
        }

        return priority + ranked.filter { seen.insert($0.id).inserted }
    }

    private static func seededSortValue(for mountain: Mountain, profile: SeedHikerProfile) -> Int {
        let rank = MountainCatalog.heightRankSortValue(for: mountain.id)
        return (rank * 53 + mountain.height * 7 + profile.progressSeed * 29) % 10_000
    }
}

struct SeedHikerAvatar: View {
    let profile: SeedHikerProfile
    var size: CGFloat = 36
    var border: Color = .white

    var body: some View {
        Image(profile.avatarAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(border, lineWidth: size > 42 ? 3 : 2))
            .shadow(color: FrogTheme.warmShadow.opacity(0.14), radius: 4, y: 2)
    }
}
