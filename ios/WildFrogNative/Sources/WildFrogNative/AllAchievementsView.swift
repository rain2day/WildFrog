import SwiftUI

// MARK: - AllAchievementsView

struct AllAchievementsView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private enum AchievementMetric: Equatable {
        case peaks          // checkInStore.distinctMountainCount
        case checkIns       // checkInStore.totalCheckIns
        case region(String) // checkInStore.visitedCount(inRegion:)
        case height         // checkInStore.highestVisitedPeakHeight
        case activeDays     // checkInStore.totalActiveDays (cumulative, not streak)
        case regions        // checkInStore.regionsVisitedCount
    }

    private struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let tint: Color
        let metric: AchievementMetric
        let threshold: Int

        var localizedTitle: String {
            AppText.value(zh: title, en: englishTitle)
        }

        var localizedDescription: String {
            AppText.value(zh: description, en: englishDescription)
        }

        private var englishTitle: String {
            switch id {
            case "peaks1": return "First Peak"
            case "peaks3": return "First Steps"
            case "peaks5": return "Five Peaks"
            case "peaks10": return "Ten Peaks"
            case "peaks15": return "Trail Regular"
            case "peaks20": return "Trailblazer"
            case "peaks25": return "Twenty-five Peaks"
            case "peaks30": return "Explorer"
            case "peaks40": return "Forty Peaks"
            case "peaks50": return "Peak Explorer"
            case "peaks60": return "Sixty Peaks"
            case "peaks75": return "Summit Seeker"
            case "peaks100": return "Century Hiker"
            case "peaks125": return "125 Peaks"
            case "peaks150": return "Half Way"
            case "peaks200": return "Two Hundred Peaks"
            case "peaks250": return "Peak Master"
            case "peaks300": return "300 Peak Champion"
            case "checkins1": return "First Check-in"
            case "checkins25": return "Dedicated Logger"
            case "checkins75": return "Check-in Regular"
            case "checkins150": return "Check-in Expert"
            case "checkins300": return "Check-in Champion"
            case "days3": return "Three Active Days"
            case "days7": return "Seven Active Days"
            case "days15": return "Fifteen Active Days"
            case "days30": return "Thirty Active Days"
            case "days60": return "Sixty Active Days"
            case "days100": return "Hundred Active Days"
            case "days200": return "Two Hundred Active Days"
            case "regions2": return "Two-region Walker"
            case "regions3": return "Three-region Trekker"
            case "regions4": return "All-region Explorer"
            case "regionNT10": return "New Territories Starter"
            case "regionNT30": return "New Territories Trekker"
            case "regionNT60": return "New Territories Master"
            case "regionLantau10": return "Lantau Starter"
            case "regionLantau30": return "Lantau Trekker"
            case "regionHKI10": return "Hong Kong Island Starter"
            case "regionHKI25": return "Hong Kong Island Master"
            case "regionKLN15": return "Kowloon Peaks"
            case "height957": return "Highest Point"
            default: return title
            }
        }

        private var englishDescription: String {
            switch metric {
            case .peaks:
                return threshold == 1 ? "Summit 1 peak" : "Summit \(threshold) peaks"
            case .checkIns:
                return threshold == 1 ? "Complete 1 check-in" : "Complete \(threshold) check-ins"
            case .region(let region):
                return "Summit \(threshold) peaks in \(AppText.region(region))"
            case .height:
                return "Reach a peak above \(threshold)m"
            case .activeDays:
                return threshold == 1 ? "Check in on 1 active day" : "Check in on \(threshold) active days"
            case .regions:
                return "Explore \(threshold) Hong Kong regions"
            }
        }
    }

    private var achievements: [Achievement] {
        [
            // MARK: Peaks — distinct summits
            Achievement(id: "peaks1", title: "首座山峰", description: "登頂 1 座山峰", systemImage: "figure.hiking", tint: FrogTheme.leaf, metric: .peaks, threshold: 1),
            Achievement(id: "peaks3", title: "起步", description: "登頂 3 座山峰", systemImage: "shoeprints.fill", tint: FrogTheme.moss, metric: .peaks, threshold: 3),
            Achievement(id: "peaks5", title: "五峰行者", description: "登頂 5 座山峰", systemImage: "mountain.2.fill", tint: FrogTheme.leaf, metric: .peaks, threshold: 5),
            Achievement(id: "peaks10", title: "Ten Peaks", description: "登頂 10 座山峰", systemImage: "flag.fill", tint: FrogTheme.moss, metric: .peaks, threshold: 10),
            Achievement(id: "peaks15", title: "山徑常客", description: "登頂 15 座山峰", systemImage: "map.fill", tint: FrogTheme.forest, metric: .peaks, threshold: 15),
            Achievement(id: "peaks20", title: "Trailblazer", description: "登頂 20 座山峰", systemImage: "location.fill", tint: FrogTheme.slate, metric: .peaks, threshold: 20),
            Achievement(id: "peaks25", title: "二十五峰", description: "登頂 25 座山峰", systemImage: "scope", tint: FrogTheme.moss, metric: .peaks, threshold: 25),
            Achievement(id: "peaks30", title: "Explorer", description: "登頂 30 座山峰", systemImage: "binoculars.fill", tint: FrogTheme.forest, metric: .peaks, threshold: 30),
            Achievement(id: "peaks40", title: "四十峰", description: "登頂 40 座山峰", systemImage: "star.fill", tint: FrogTheme.gold, metric: .peaks, threshold: 40),
            Achievement(id: "peaks50", title: "Peak Explorer", description: "登頂 50 座山峰", systemImage: "star.circle.fill", tint: FrogTheme.gold, metric: .peaks, threshold: 50),
            Achievement(id: "peaks60", title: "六十峰達人", description: "登頂 60 座山峰", systemImage: "rosette", tint: FrogTheme.gold, metric: .peaks, threshold: 60),
            Achievement(id: "peaks75", title: "Summit Seeker", description: "登頂 75 座山峰", systemImage: "medal.fill", tint: FrogTheme.orange, metric: .peaks, threshold: 75),
            Achievement(id: "peaks100", title: "Century Hiker", description: "登頂 100 座山峰", systemImage: "trophy.fill", tint: FrogTheme.gold, metric: .peaks, threshold: 100),
            Achievement(id: "peaks125", title: "百二五峰", description: "登頂 125 座山峰", systemImage: "medal.fill", tint: FrogTheme.orange, metric: .peaks, threshold: 125),
            Achievement(id: "peaks150", title: "Half Way", description: "登頂 150 座山峰", systemImage: "rosette", tint: FrogTheme.forest, metric: .peaks, threshold: 150),
            Achievement(id: "peaks200", title: "二百峰", description: "登頂 200 座山峰", systemImage: "crown.fill", tint: FrogTheme.gold, metric: .peaks, threshold: 200),
            Achievement(id: "peaks250", title: "Peak Master", description: "登頂 250 座山峰", systemImage: "crown.fill", tint: FrogTheme.orange, metric: .peaks, threshold: 250),
            Achievement(id: "peaks300", title: "300 Peak Champion", description: "登頂 300 座香港山峰", systemImage: "trophy.fill", tint: FrogTheme.orange, metric: .peaks, threshold: 300),

            // MARK: Check-ins — total visits
            Achievement(id: "checkins1", title: "首次打卡", description: "完成 1 次打卡", systemImage: "checkmark.seal.fill", tint: FrogTheme.leaf, metric: .checkIns, threshold: 1),
            Achievement(id: "checkins10", title: "10 Check-ins", description: "完成 10 次打卡", systemImage: "checkmark.seal.fill", tint: FrogTheme.moss, metric: .checkIns, threshold: 10),
            Achievement(id: "checkins25", title: "勤力打卡", description: "完成 25 次打卡", systemImage: "calendar", tint: FrogTheme.slate, metric: .checkIns, threshold: 25),
            Achievement(id: "checkins50", title: "50 Check-ins", description: "完成 50 次打卡", systemImage: "calendar", tint: FrogTheme.forest, metric: .checkIns, threshold: 50),
            Achievement(id: "checkins75", title: "打卡常客", description: "完成 75 次打卡", systemImage: "flag.fill", tint: FrogTheme.moss, metric: .checkIns, threshold: 75),
            Achievement(id: "checkins100", title: "Centurion", description: "完成 100 次打卡", systemImage: "star.fill", tint: FrogTheme.gold, metric: .checkIns, threshold: 100),
            Achievement(id: "checkins150", title: "打卡達人", description: "完成 150 次打卡", systemImage: "star.circle.fill", tint: FrogTheme.gold, metric: .checkIns, threshold: 150),
            Achievement(id: "checkins200", title: "200 Club", description: "完成 200 次打卡", systemImage: "medal.fill", tint: FrogTheme.orange, metric: .checkIns, threshold: 200),
            Achievement(id: "checkins300", title: "打卡王", description: "完成 300 次打卡", systemImage: "rosette", tint: FrogTheme.orange, metric: .checkIns, threshold: 300),
            Achievement(id: "checkins500", title: "Check-in Legend", description: "完成 500 次打卡", systemImage: "trophy.fill", tint: FrogTheme.gold, metric: .checkIns, threshold: 500),

            // MARK: Active days — cumulative check-in days (streaks are unrealistic for hiking)
            Achievement(id: "days3", title: "三日行者", description: "累計打卡 3 日", systemImage: "calendar", tint: FrogTheme.leaf, metric: .activeDays, threshold: 3),
            Achievement(id: "days7", title: "一週山客", description: "累計打卡 7 日", systemImage: "calendar", tint: FrogTheme.moss, metric: .activeDays, threshold: 7),
            Achievement(id: "days15", title: "半月縱橫", description: "累計打卡 15 日", systemImage: "calendar", tint: FrogTheme.slate, metric: .activeDays, threshold: 15),
            Achievement(id: "days30", title: "三十日山途", description: "累計打卡 30 日", systemImage: "calendar", tint: FrogTheme.forest, metric: .activeDays, threshold: 30),
            Achievement(id: "days60", title: "六十日行", description: "累計打卡 60 日", systemImage: "calendar", tint: FrogTheme.gold, metric: .activeDays, threshold: 60),
            Achievement(id: "days100", title: "百日登峰", description: "累計打卡 100 日", systemImage: "star.circle.fill", tint: FrogTheme.gold, metric: .activeDays, threshold: 100),
            Achievement(id: "days200", title: "二百日傳奇", description: "累計打卡 200 日", systemImage: "trophy.fill", tint: FrogTheme.orange, metric: .activeDays, threshold: 200),

            // MARK: Regions — distinct HK regions explored
            Achievement(id: "regions2", title: "雙區行者", description: "走遍 2 個地區", systemImage: "map.fill", tint: FrogTheme.moss, metric: .regions, threshold: 2),
            Achievement(id: "regions3", title: "三區縱走", description: "走遍 3 個地區", systemImage: "map.fill", tint: FrogTheme.forest, metric: .regions, threshold: 3),
            Achievement(id: "regions4", title: "四區走遍", description: "走遍全港 4 區", systemImage: "globe.asia.australia.fill", tint: FrogTheme.orange, metric: .regions, threshold: 4),

            // MARK: Region — distinct peaks per region
            Achievement(id: "regionNT10", title: "新界初探", description: "新界登頂 10 座", systemImage: "tree.fill", tint: FrogTheme.leaf, metric: .region("新界"), threshold: 10),
            Achievement(id: "regionNT30", title: "新界縱走", description: "新界登頂 30 座", systemImage: "leaf.fill", tint: FrogTheme.moss, metric: .region("新界"), threshold: 30),
            Achievement(id: "regionNT60", title: "新界之王", description: "新界登頂 60 座", systemImage: "crown.fill", tint: FrogTheme.forest, metric: .region("新界"), threshold: 60),
            Achievement(id: "regionLantau10", title: "大嶼初探", description: "大嶼山登頂 10 座", systemImage: "tree.fill", tint: FrogTheme.leaf, metric: .region("大嶼山"), threshold: 10),
            Achievement(id: "regionLantau30", title: "大嶼縱走", description: "大嶼山登頂 30 座", systemImage: "sunrise.fill", tint: FrogTheme.moss, metric: .region("大嶼山"), threshold: 30),
            Achievement(id: "regionHKI10", title: "港島初探", description: "港島登頂 10 座", systemImage: "building.2.fill", tint: FrogTheme.slate, metric: .region("港島"), threshold: 10),
            Achievement(id: "regionHKI25", title: "港島達人", description: "港島登頂 25 座", systemImage: "map.fill", tint: FrogTheme.forest, metric: .region("港島"), threshold: 25),
            Achievement(id: "regionKLN15", title: "九龍群山", description: "九龍登頂 15 座", systemImage: "binoculars.fill", tint: FrogTheme.gold, metric: .region("九龍"), threshold: 15),

            // MARK: Height — highest peak climbed
            Achievement(id: "height300", title: "300m 高度", description: "登上 300m 以上山峰", systemImage: "arrow.up.circle.fill", tint: FrogTheme.leaf, metric: .height, threshold: 300),
            Achievement(id: "height500", title: "500m 高度", description: "登上 500m 以上山峰", systemImage: "mountain.2.fill", tint: FrogTheme.moss, metric: .height, threshold: 500),
            Achievement(id: "height700", title: "700m 高度", description: "登上 700m 以上山峰", systemImage: "triangle.fill", tint: FrogTheme.forest, metric: .height, threshold: 700),
            Achievement(id: "height957", title: "香港之巔", description: "登上大帽山 957m", systemImage: "crown.fill", tint: FrogTheme.gold, metric: .height, threshold: 957),
        ]
    }

    private func isUnlocked(_ badge: Achievement) -> Bool {
        let progress: Int
        switch badge.metric {
        case .peaks: progress = checkInStore.distinctMountainCount
        case .checkIns: progress = checkInStore.totalCheckIns
        case .region(let region): progress = checkInStore.visitedCount(inRegion: region)
        case .height: progress = checkInStore.highestVisitedPeakHeight
        case .activeDays: progress = checkInStore.totalActiveDays
        case .regions: progress = checkInStore.regionsVisitedCount
        }
        return progress >= badge.threshold
    }

    private var unlockedCount: Int {
        achievements.filter { isUnlocked($0) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppText.value(zh: "成就徽章", en: "Achievement Badges"))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(FrogTheme.forest)
                        Text(AppText.value(zh: "已解鎖 \(unlockedCount) / \(achievements.count)", en: "Unlocked \(unlockedCount) / \(achievements.count)"))
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(FrogTheme.gold.opacity(0.72))
                }
                .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(achievements) { badge in
                        let unlocked = isUnlocked(badge)
                        VStack(spacing: 10) {
                            StampBadge(
                                systemImage: badge.systemImage,
                                tint: badge.tint,
                                isUnlocked: unlocked,
                                size: 64
                            )

                            VStack(spacing: 3) {
                                Text(badge.localizedTitle)
                                    .font(.frogRow.weight(.black))
                                    .foregroundStyle(unlocked ? FrogTheme.ink : FrogTheme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(badge.localizedDescription)
                                    .font(.frogMicro)
                                    .foregroundStyle(FrogTheme.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(unlocked ? FrogTheme.surface : FrogTheme.paper.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(unlocked ? badge.tint.opacity(0.22) : FrogTheme.line, lineWidth: 1)
                        )
                        .shadow(color: unlocked ? Color.black.opacity(0.07) : .clear, radius: 8, y: 3)
                        .opacity(unlocked ? 1 : 0.58)
                    }
                }
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .localizedNavigationTitle { AppText.value(zh: "成就", en: "Achievements") }
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper.ignoresSafeArea())
    }
}

// MARK: - AllLeaderboardView

struct AllLeaderboardView: View {
    let scope: SeedLeaderboardScope
    let profiles: [SeedHikerProfile]
    let publicationState: LeaderboardPublicationState
    let listRefresh: LeaderboardPublicationListRefresh.ListRefresh
    let asOf: Date
    let retryListRefresh: () -> Void
    let retryPublication: () -> Void

    @State private var selectedUser: LeaderboardUserSelection?
    @Environment(ProfileAuthService.self) private var authService
    @EnvironmentObject private var checkInStore: CheckInStore
    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""

    private var allUsers: [SeedLeaderboardEntry] { SeedLeaderboard.entries(profiles: profiles, scope: scope, asOf: asOf) }
    private var exactPublicEntry: SeedLeaderboardEntry? {
        LeaderboardCurrentUserSnapshot.exactEntry(
            publication: publicationState,
            listRefresh: listRefresh,
            entries: allUsers
        )
    }
    private var listProjection: FullLeaderboardListProjection {
        FullLeaderboardListProjection.resolve(
            entries: allUsers,
            exactPublicEntry: exactPublicEntry
        )
    }
    private var sheetState: FullLeaderboardSheetState {
        FullLeaderboardSheetState.resolve(
            publication: publicationState,
            listRefresh: listRefresh
        )
    }
    private var titleText: String {
        scope == .month
            ? AppText.value(zh: "本月公開全榜", en: "Monthly Public Ranking")
            : AppText.value(zh: "總榜公開全榜", en: "All-time Public Ranking")
    }
    private var scoreLabel: String { scope == .month ? AppText.value(zh: "本月", en: "Month") : AppText.value(zh: "總計", en: "Total") }

    private var myScore: Int {
        if let exactPublicEntry { return exactPublicEntry.score }
        switch scope {
        case .month:
            return checkInStore.records.filter {
                LeaderboardMonth.contains($0.date, inMonthOf: asOf)
            }.count
        case .all:
            return checkInStore.totalCheckIns
        }
    }

    private var myRank: Int? {
        exactPublicEntry?.rank
    }

    private var myDisplayName: String {
        exactPublicEntry?.profile.name ?? authService.profileLine
    }

    private var mySubtitle: String {
        if exactPublicEntry != nil {
            return equippedTitle ?? AppText.value(zh: "已由伺服器確認", en: "Server-confirmed")
        }
        return AppText.value(zh: "私人紀錄 · 非精確排名", en: "Private record · no exact rank")
    }

    private var equippedTitle: String? {
        guard !equippedTitleId.isEmpty,
              checkInStore.visitedMountainIds.contains(equippedTitleId) else { return nil }
        return MountainCatalog.mountain(id: equippedTitleId).localizedUnlockTitle
    }

    private var myAvatarId: String {
        checkInStore.records.sorted { $0.date > $1.date }.first?.mountainId ?? "lantau-peak"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(titleText)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Spacer()
                }
                .padding(.top, 4)

                if sheetState.showRetainedDisclosure {
                    if sheetState.showListRetry {
                        fullRankingStatusBanner(
                            message: AppText.value(
                                zh: "目前顯示保留的舊排行榜資料，名次並非最新。",
                                en: "Showing retained leaderboard rows; ranks are not current."
                            ),
                            button: AppText.value(zh: "重試排行", en: "Retry Ranking"),
                            action: retryListRefresh
                        )
                    } else {
                        fullRankingUpdatingBanner(
                            message: AppText.value(
                                zh: "排行榜更新中；暫時顯示上次結果。",
                                en: "Updating leaderboard; showing last results."
                            )
                        )
                    }
                }

                if sheetState.showPublicationRetry {
                    fullRankingStatusBanner(
                        message: AppText.value(
                            zh: "你的排行榜公開設定仍待伺服器確認。",
                            en: "Your leaderboard publication still needs server confirmation."
                        ),
                        button: AppText.value(zh: "重試同步", en: "Retry Sync"),
                        action: retryPublication
                    )
                }

                VStack(spacing: 0) {
                    Button {
                        selectedUser = exactPublicEntry.map(LeaderboardUserSelection.seed) ?? .current
                    } label: {
                        AllCurrentUserLeaderboardRow(
                            rank: myRank,
                            score: myScore,
                            scoreLabel: scoreLabel,
                            displayName: myDisplayName,
                            subtitle: mySubtitle,
                            avatarMountainId: myAvatarId
                        )
                    }
                    .buttonStyle(.plain)

                    if allUsers.isEmpty {
                        Text(AppText.value(zh: "暫時未有公開排行", en: "No public ranking yet"))
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        ForEach(listProjection.publicEntries) { user in
                            Button {
                                selectedUser = .seed(user)
                            } label: {
                                AllLeaderboardRow(user: user, scope: scope, scoreLabel: scoreLabel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .localizedNavigationTitle { AppText.value(zh: "全榜", en: "Full Ranking") }
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper.ignoresSafeArea())
        .sheet(item: $selectedUser) { selection in
            NavigationStack {
                LeaderboardUserDetailView(
                    selection: selection,
                    scope: scope,
                    asOf: asOf,
                    currentDisplayName: authService.profileLine,
                    currentTitle: equippedTitle
                )
                .withNativeRoutes()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppText.value(zh: "完成", en: "Done")) { selectedUser = nil }
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.orange)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func fullRankingStatusBanner(
        message: String,
        button: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundStyle(FrogTheme.orange)
            Text(message)
                .font(.frogMicro.weight(.semibold))
                .foregroundStyle(FrogTheme.ink)
            Spacer(minLength: 4)
            Button(button, action: action)
                .font(.frogCaption.weight(.black))
                .foregroundStyle(FrogTheme.moss)
        }
        .padding(12)
        .background(FrogTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fullRankingUpdatingBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(FrogTheme.moss)
            Text(message)
                .font(.frogMicro.weight(.semibold))
                .foregroundStyle(FrogTheme.ink)
            Spacer(minLength: 4)
        }
        .padding(12)
        .background(FrogTheme.mossSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AllLeaderboardRow: View {
    let user: SeedLeaderboardEntry
    let scope: SeedLeaderboardScope
    let scoreLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(user.rank)")
                .font(.headline.weight(.black))
                .foregroundStyle(rankColor)
                .frame(width: 34, alignment: .leading)

            SeedHikerAvatar(profile: user.profile, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.profile.name)
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(user.subtitle(scope: scope))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(user.score)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Text(scoreLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(12)
        .background(FrogTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.leading, 84)
        }
    }

    private var rankColor: Color {
        switch user.rank {
        case 1: FrogTheme.gold
        case 2, 3: FrogTheme.moss
        default: FrogTheme.forest
        }
    }
}

private struct AllCurrentUserLeaderboardRow: View {
    let rank: Int?
    let score: Int
    let scoreLabel: String
    let displayName: String
    let subtitle: String
    let avatarMountainId: String

    var body: some View {
        HStack(spacing: 12) {
            Text(rank.map(String.init) ?? "—")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.orange)
                .frame(width: 34, alignment: .leading)

            MountainPhoto(mountain: MountainCatalog.mountain(id: avatarMountainId), dimming: 0.02)
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().stroke(FrogTheme.leaf, lineWidth: 3))
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(score)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
                Text(scoreLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(12)
        .background(FrogTheme.orangeSoft.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.leading, 84)
        }
    }
}
