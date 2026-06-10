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
        let title = profile.unlockedTitle ?? "\(distinctPeaks)峰"
        switch scope {
        case .month:
            return "\(profile.homeRegion) · \(profile.style) · \(title)"
        case .all:
            return "\(profile.homeRegion) · 累計 \(distinctPeaks) 座 · \(title)"
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
}

enum SeedLeaderboard {
    private static let monthScoreCap = 24
    private static let totalScoreCap = 99

    private static let names = [
        "阿晴", "kinjai", "Ka Man", "Hei Lam", "jason.c", "嘉欣", "Lok Lok", "Yannis", "阿峰", "ms.joey",
        "Ho Yin", "cc.cheung", "Ming C.", "小米", "kelvinw", "Yan Yan", "Tsz Y.", "Audrey", "chris.hk", "晴晴",
        "阿健", "Vivi", "ryan_ng", "May L.", "子謙", "wing.s", "阿珊", "Marcus", "hoyi", "Kiki C.",
        "Kenji", "Jasmine", "tony.t", "阿浩", "nicolew", "Ben C.", "Cherry", "Ivan", "Rachel", "Long 仔",
        "Phoebe", "AK", "阿恩", "Toby Y.", "Grace", "darren.hk", "Jessie", "Howard", "Carmen", "Leo",
        "yan.c", "Nora", "Brian", "阿桐", "elaine.l", "Anson", "Mavis", "kit_山路", "Janice", "Oscar",
        "Tim C.", "Crystal", "阿邦", "suki.s", "Daniel", "琪琪", "Rico", "阿朗", "Ada", "Wallace",
        "Yuki", "Aaron"
    ]

    private static let homeRegions = ["沙田", "港島東", "大埔", "九龍", "西貢", "荃灣", "將軍澳", "屯元天", "大嶼山", "離島"]
    private static let styles = ["週末慢行", "收工散步", "相機先行", "日出線", "越野跑", "海邊山徑", "朋友約行", "清晨上山", "短線常客", "雨後打卡", "親子慢走", "夜景路線"]
    private static let titleMountainIds = [
        "tai-mo-shan", "lantau-peak", "sunset-peak", "lion-rock", "ma-on-shan", "sharp-peak",
        "high-junk-peak", "high-west", "tai-to-yan", "kau-nga-ling", "kai-kung-shan", "tung-wan-shan",
        "pyramid-hill", "north-peak-the-twins", "tai-tung", "wo-tong-kong", "ping-fung-mei", "sheung-tsz-fung"
    ]
    private static let heroMountainIds = [
        "wo-tong-kong", "kam-sing-teng", "tung-wan-shan", "sam-chi-heung-north-peak", "tai-tung",
        "miu-tsai-tun", "sharp-peak", "north-peak-the-twins", "sunset-peak", "lantau-peak",
        "high-junk-peak", "keung-shan", "tai-to-yan", "ping-fung-mei", "sheung-tsz-fung",
        "kowloon-peak", "lion-rock", "pyramid-hill"
    ]
    private static let cadenceOptions = [2, 3, 3, 4, 4, 5, 6, 7, 9]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        return calendar
    }()

    private static var seedEpoch: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? Date(timeIntervalSince1970: 1_780_272_000)
    }

    static let profiles: [SeedHikerProfile] = names.enumerated().map { index, name in
        let topBoost = max(0, 18 - index)
        let baseMonth = min(18, 2 + ((index * 5) % 8) + topBoost / 3)
        let baseTotal = min(88, 14 + ((index * 29) % 44) + topBoost * 2)
        let basePeaks = min(42, max(2, baseTotal / 4 + ((index * 5) % 11)))
        let hasTitle = index % 5 != 4
        return SeedHikerProfile(
            id: String(format: "seed-hiker-%03d", index + 1),
            name: name,
            homeRegion: homeRegions[index % homeRegions.count],
            style: styles[(index * 3) % styles.count],
            titleMountainId: hasTitle ? titleMountainIds[(index * 5) % titleMountainIds.count] : nil,
            heroMountainId: heroMountainIds[(index * 7) % heroMountainIds.count],
            progressSeed: index * 31 + 17,
            baseMonthCheckIns: baseMonth,
            baseTotalCheckIns: baseTotal,
            baseDistinctPeaks: basePeaks,
            cadenceDays: cadenceOptions[index % cadenceOptions.count],
            weekendCycle: 3 + (index % 5)
        )
    }

    static func entries(scope: SeedLeaderboardScope, asOf date: Date) -> [SeedLeaderboardEntry] {
        let current = rankedProfiles(scope: scope, asOf: date)
        let previousDate = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let previousRanks = Dictionary(
            uniqueKeysWithValues: rankedProfiles(scope: scope, asOf: previousDate).map { ($0.profile.id, $0.rank) }
        )

        return current.map { row in
            let previousRank = previousRanks[row.profile.id] ?? row.rank
            let deltaValue = previousRank - row.rank
            let direction: SeedLeaderboardDelta = deltaValue > 0 ? .up : (deltaValue < 0 ? .down : .flat)
            return SeedLeaderboardEntry(
                rank: row.rank,
                profile: row.profile,
                score: row.score,
                distinctPeaks: row.distinctPeaks,
                delta: direction,
                deltaN: abs(deltaValue)
            )
        }
    }

    static func rank(for score: Int, scope: SeedLeaderboardScope, asOf date: Date) -> Int {
        rankedProfiles(scope: scope, asOf: date).filter { $0.score > score }.count + 1
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

    private static func rankedProfiles(scope: SeedLeaderboardScope, asOf date: Date) -> [(rank: Int, profile: SeedHikerProfile, score: Int, distinctPeaks: Int)] {
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
            return min(monthScoreCap, profile.baseMonthCheckIns + rollingGain(for: profile, from: monthStart(for: date), to: date))
        case .all:
            return min(totalScoreCap, profile.baseTotalCheckIns + rollingGain(for: profile, from: seedEpoch, to: date))
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
