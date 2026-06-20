import SwiftUI

/// 排行榜 — "田野紀錄冊 / Field Ledger" layout (design Option B): a full-bleed image
/// hero (matching the other pages), a 今月/總榜 segment, a deep-green 本月領隊 leader
/// band, a precise tabular ranking with ▲▼ rank-deltas, and a pinned 我的名次 bar.
struct LeaderboardView: View {
    @State private var showAllLeaderboard = false
    @State private var selectedUser: LeaderboardUserSelection?
    @State private var scope: Scope = .month
    @State private var heroMountainId = MountainCatalog.randomCinematicHeroMountainId()
    @State private var leaderboardDate = Date()
    @State private var leaderboardProfiles: [SeedHikerProfile] = []
    @State private var leaderboardLoadState: LeaderboardLoadState = .idle
    @Environment(ProfileAuthService.self) private var authService
    @EnvironmentObject private var checkInStore: CheckInStore
    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""

    private enum Scope { case month, all }
    private enum LeaderboardLoadState { case idle, loading, loaded, failed }

    private var seedScope: SeedLeaderboardScope { scope == .month ? .month : .all }
    private var currentEntries: [SeedLeaderboardEntry] { SeedLeaderboard.entries(profiles: leaderboardProfiles, scope: seedScope, asOf: leaderboardDate) }
    private var currentLeader: SeedLeaderboardEntry? { currentEntries.first }
    private var currentRows: [SeedLeaderboardEntry] { Array(currentEntries.dropFirst().prefix(8)) }

    /// Real personal stats from CheckInStore (true data, personal only).
    private var myTotalCheckIns: Int { checkInStore.totalCheckIns }
    private var myDistinctMountains: Int { checkInStore.distinctMountainCount }
    private var myMonthlyCheckIns: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: leaderboardDate)
        return checkInStore.records.filter {
            let recordComponents = calendar.dateComponents([.year, .month], from: $0.date)
            return recordComponents.year == components.year && recordComponents.month == components.month
        }.count
    }
    private var myScopeCount: Int { scope == .month ? myMonthlyCheckIns : myTotalCheckIns }

    private var myRank: Int? {
        guard !leaderboardProfiles.isEmpty else { return nil }
        return SeedLeaderboard.rank(for: myScopeCount, among: leaderboardProfiles, scope: seedScope, asOf: leaderboardDate)
    }

    /// The equipped 稱號 (only while it's still a conquered peak); shown on my row.
    private var equippedTitle: String? {
        guard !equippedTitleId.isEmpty,
              checkInStore.visitedMountainIds.contains(equippedTitleId) else { return nil }
        return MountainCatalog.mountain(id: equippedTitleId).localizedUnlockTitle
    }

    private var myAvatarId: String {
        checkInStore.records.sorted { $0.date > $1.date }.first?.mountainId ?? "lantau-peak"
    }

    /// Current month label for the hero period chip, e.g. "2026 · 6月".
    private var periodText: String {
        let f = DateFormatter()
        f.locale = AppText.locale
        f.dateFormat = AppText.isEnglish ? "MMM yyyy" : "yyyy · M月"
        return f.string(from: Date())
    }

    var body: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    leaderboardCover(topInset: topInset)

                    VStack(alignment: .leading, spacing: 16) {
                        scopeSegment
                        leaderboardContent
                        myRankBar
                    }
                    .padding(.horizontal, FrogSpace.screenPadding)
                    .padding(.top, FrogSpace.cardGap)
                    .padding(.bottom, 110)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .hiddenNavigationBar()
        .appPageBackground(FrogTheme.warmPaper)
        .sheet(isPresented: $showAllLeaderboard) {
            NavigationStack {
                AllLeaderboardView(scope: seedScope, profiles: leaderboardProfiles)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppText.value(zh: "完成", en: "Done")) { showAllLeaderboard = false }
                                .font(.frogCaption.weight(.bold))
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
            }
        }
        .sheet(item: $selectedUser) { selection in
            NavigationStack {
                LeaderboardUserDetailView(
                    selection: selection,
                    scope: seedScope,
                    asOf: leaderboardDate,
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
        .onAppear { leaderboardDate = Date() }
        .task { await loadLeaderboardProfiles() }
    }

    // MARK: - Hero (full-bleed image, matches the other pages)

    private func leaderboardCover(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: heroMountainId), dimming: 0)

            LinearGradient(
                colors: [
                    FrogTheme.forest.opacity(0.30),
                    FrogTheme.forest.opacity(0.55),
                    FrogTheme.forest.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    WildFrogWordmark(markSize: 30)
                        .shadow(color: Color.black.opacity(0.28), radius: 8, y: 3)

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .bold))
                        Text(periodText)
                            .font(.frogNum(11, weight: .bold))
                            .tracking(0.4)
                    }
                    .foregroundStyle(FrogTheme.forest)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(FrogTheme.leaf, in: Capsule())
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 24)

                Text(AppText.value(zh: "排行榜", en: "Leaderboard"))
                    .font(.frogNum(34, weight: .heavy))
                    .foregroundStyle(.white)

                Text(AppText.value(zh: "LEADERBOARD · 一齊征服香港群山", en: "LEADERBOARD · Hong Kong peak challenge"))
                    .font(.frogCaption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 7)

                HStack(spacing: 9) {
                    LeaderboardCoverMetric(value: "\(myTotalCheckIns)", label: AppText.value(zh: "我的打卡", en: "My Check-ins"))
                    LeaderboardCoverMetric(value: "\(myDistinctMountains)", label: AppText.value(zh: "已到山峰", en: "Peaks"))
                    LeaderboardCoverMetric(value: "\(checkInStore.currentStreak)", label: AppText.value(zh: "連續日", en: "Streak"))
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, FrogSpace.screenPadding + 4)
            .padding(.bottom, 24)
        }
        .frame(height: topInset + 290)
        .clipped()
    }

    // MARK: - Scope segment (今月 / 總榜)

    private var scopeSegment: some View {
        HStack(spacing: 0) {
            segItem(AppText.value(zh: "今月", en: "Month"), isOn: scope == .month) { scope = .month }
            segItem(AppText.value(zh: "總榜", en: "All-time"), isOn: scope == .all) { scope = .all }
        }
        .padding(3)
        .background(FrogTheme.surface2, in: Capsule())
        .overlay(Capsule().stroke(FrogTheme.line, lineWidth: 1))
    }

    private func segItem(_ title: String, isOn: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isOn ? .white : FrogTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isOn ? FrogTheme.forest : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 本月領隊 leader band (b-leader)

    @ViewBuilder
    private var leaderboardContent: some View {
        if let leader = currentLeader {
            leaderBand(leader)
            rankingTable
            if currentEntries.count > 9 {
                completeRankLink
            }
        } else {
            leaderboardStatusCard
        }
    }

    private var leaderboardStatusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: leaderboardLoadState == .loading ? "arrow.triangle.2.circlepath" : "chart.bar.doc.horizontal")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FrogTheme.orange)
                .frame(width: 38, height: 38)
                .background(FrogTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(leaderboardLoadState == .failed ? AppText.value(zh: "未能載入排行", en: "Could not load ranking") : AppText.value(zh: "暫時未有公開排行", en: "No public ranking yet"))
                    .font(.frogRow.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Text(leaderboardLoadState == .loading ? AppText.value(zh: "正在同步排行榜...", en: "Syncing leaderboard...") : AppText.value(zh: "有公開打卡紀錄後，排行會自動更新。", en: "The ranking updates when public check-ins are available."))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .cardStyle(cornerRadius: 16)
    }

    private func leaderBand(_ currentLeader: SeedLeaderboardEntry) -> some View {
        ZStack(alignment: .leading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: currentLeader.profile.heroMountainId), dimming: 0)

            // 105°-ish gradient: dark on the left (legible text) → photo on the right.
            LinearGradient(
                colors: [
                    Color(red: 8 / 255, green: 14 / 255, blue: 10 / 255).opacity(0.90),
                    FrogTheme.forest.opacity(0.62),
                    FrogTheme.forest.opacity(0.16)
                ],
                startPoint: UnitPoint(x: -0.05, y: 0.2),
                endPoint: UnitPoint(x: 1.0, y: 0.85)
            )

            HStack(spacing: 14) {
                SeedHikerAvatar(profile: currentLeader.profile, size: 54, border: FrogTheme.gold)

                VStack(alignment: .leading, spacing: 4) {
                    Text(scope == .month ? AppText.value(zh: "本月領隊 · LEADER", en: "MONTHLY LEADER") : AppText.value(zh: "總榜領隊 · ALL-TIME LEADER", en: "ALL-TIME LEADER"))
                        .font(.frogNum(10, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(FrogTheme.gold)
                    Text(currentLeader.profile.name)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                    Text(currentLeader.subtitle(scope: seedScope))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentLeader.score)")
                        .font(.frogNum(40, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(AppText.value(zh: "次打卡", en: "check-ins"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 16)
        }
        .frame(minHeight: 118)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { selectedUser = .seed(currentLeader) }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tabular ranking (b-colhead + b-row)

    private var rankingTable: some View {
        VStack(spacing: 0) {
            // column header
            HStack(spacing: 11) {
                Text(AppText.value(zh: "名次", en: "Rank")).frame(width: 38, alignment: .leading)
                Text(" ").frame(width: 22, alignment: .leading)
                Text(AppText.value(zh: "登山者", en: "Hiker"))
                Spacer(minLength: 0)
                Text(scope == .month ? AppText.value(zh: "本月", en: "Month") : AppText.value(zh: "總計", en: "Total"))
            }
            .font(.frogNum(9.5, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(FrogTheme.faint)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) { FrogTheme.line.frame(height: 1) }

            ForEach(currentRows) { u in
                rankRow(u)
            }
        }
    }

    private func rankRow(_ u: SeedLeaderboardEntry) -> some View {
        Button {
            selectedUser = .seed(u)
        } label: {
            HStack(spacing: 11) {
                Text("\(u.rank)")
                    .font(.frogNum(16, weight: .semibold))
                    .foregroundStyle(FrogTheme.forest)
                    .frame(width: 38, alignment: .leading)

                DeltaBadge(dir: u.delta, n: u.deltaN)
                    .frame(width: 22, alignment: .leading)

                HStack(spacing: 11) {
                    SeedHikerAvatar(profile: u.profile)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(u.profile.name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(FrogTheme.ink)
                        Text(u.subtitle(scope: seedScope))
                            .font(.system(size: 11))
                            .foregroundStyle(FrogTheme.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Text("\(u.score)")
                    .font(.frogNum(17, weight: .semibold))
                    .foregroundStyle(FrogTheme.ink)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { FrogTheme.lineSoft.frame(height: 1) }
    }

    private var completeRankLink: some View {
        Button { showAllLeaderboard = true } label: {
            HStack(spacing: 5) {
                Text(AppText.value(zh: "完整排行", en: "Full Ranking"))
                    .font(.frogCaption.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.frogMicro.weight(.bold))
            }
            .foregroundStyle(FrogTheme.moss)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 我的名次 bar (b-mybar)

    private var myRankBar: some View {
        Button {
            selectedUser = .current
        } label: {
            HStack(spacing: 11) {
                Text(myRank.map(String.init) ?? "—")
                    .font(.frogNum(17, weight: .bold))
                    .foregroundStyle(FrogTheme.leaf)
                    .frame(width: 38, alignment: .leading)

                DeltaBadge(dir: .flat, n: 0)
                    .frame(width: 22, alignment: .leading)

                HStack(spacing: 11) {
                    LbAvatar(mountainId: myAvatarId, border: FrogTheme.leaf)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(authService.profileLine)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(equippedTitle ?? AppText.value(zh: "你的紀錄", en: "Your record"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Text("\(myScopeCount)")
                    .font(.frogNum(18, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 19)
        .padding(.vertical, 14)
        .background(FrogTheme.forest, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @MainActor
    private func loadLeaderboardProfiles() async {
        leaderboardLoadState = .loading
        do {
            leaderboardProfiles = try await FirestoreService().fetchLeaderboardProfiles()
            leaderboardLoadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            leaderboardProfiles = []
            leaderboardLoadState = .failed
        }
    }
}

enum LeaderboardUserSelection: Identifiable {
    case seed(SeedLeaderboardEntry)
    case current

    var id: String {
        switch self {
        case .seed(let entry): entry.profile.id
        case .current: "current-user"
        }
    }
}

struct LeaderboardUserDetailView: View {
    let selection: LeaderboardUserSelection
    let scope: SeedLeaderboardScope
    let asOf: Date
    let currentDisplayName: String
    let currentTitle: String?

    @EnvironmentObject private var checkInStore: CheckInStore

    private let stampColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private let achievementColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var displayName: String {
        switch selection {
        case .seed(let entry): entry.profile.name
        case .current: currentDisplayName
        }
    }

    private var heroMountainId: String {
        switch selection {
        case .seed(let entry):
            return entry.profile.heroMountainId
        case .current:
            return checkInStore.records.sorted { $0.date > $1.date }.first?.mountainId ?? "lion-rock"
        }
    }

    private var profileSubtitle: String {
        switch selection {
        case .seed(let entry):
            return "\(AppText.seedRegion(entry.profile.homeRegion)) · \(AppText.hikerStyle(entry.profile.style))"
        case .current:
            return currentTitle ?? AppText.value(zh: "你的真實打卡紀錄", en: "Your real check-in record")
        }
    }

    private var titleText: String? {
        switch selection {
        case .seed(let entry): entry.profile.localizedUnlockedTitle
        case .current: currentTitle
        }
    }

    private var scopeScore: Int {
        switch selection {
        case .seed(let entry):
            return entry.score
        case .current:
            switch scope {
            case .month: return currentMonthCheckIns
            case .all: return checkInStore.totalCheckIns
            }
        }
    }

    private var totalCheckIns: Int {
        switch selection {
        case .seed(let entry):
            return SeedLeaderboard.score(for: entry.profile, scope: .all, asOf: asOf)
        case .current:
            return checkInStore.totalCheckIns
        }
    }

    private var distinctPeakCount: Int {
        checkedMountains.count
    }

    private var checkedMountains: [Mountain] {
        switch selection {
        case .seed(let entry):
            return SeedLeaderboard.checkedMountains(for: entry.profile, asOf: asOf)
        case .current:
            var seen: Set<String> = []
            return checkInStore.records
                .sorted { $0.date > $1.date }
                .compactMap { record in
                    guard seen.insert(record.mountainId).inserted else { return nil }
                    return MountainCatalog.mountain(id: record.mountainId)
                }
        }
    }

    private var recentVisits: [SeedMountainVisit] {
        switch selection {
        case .seed(let entry):
            return SeedLeaderboard.recentVisits(for: entry.profile, asOf: asOf)
        case .current:
            return checkInStore.records
                .sorted { $0.date > $1.date }
                .prefix(5)
                .map { record in
                    SeedMountainVisit(
                        id: record.id.uuidString,
                        mountain: MountainCatalog.mountain(id: record.mountainId),
                        date: record.date,
                        repeatCount: checkInStore.count(for: record.mountainId)
                    )
                }
        }
    }

    private var achievements: [SeedAchievementSummary] {
        switch selection {
        case .seed(let entry):
            return SeedLeaderboard.unlockedAchievements(for: entry.profile, asOf: asOf)
        case .current:
            return SeedLeaderboard.achievementSummaries(
                distinctPeaks: checkInStore.distinctMountainCount,
                totalCheckIns: checkInStore.totalCheckIns,
                activeDays: checkInStore.totalActiveDays,
                highestPeakHeight: checkInStore.highestVisitedPeakHeight,
                regionsVisited: checkInStore.regionsVisitedCount
            )
        }
    }

    private var currentMonthCheckIns: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: asOf)
        return checkInStore.records.filter {
            let recordComponents = calendar.dateComponents([.year, .month], from: $0.date)
            return recordComponents.year == components.year && recordComponents.month == components.month
        }.count
    }

    private var scoreLabel: String {
        scope == .month ? AppText.value(zh: "本月打卡", en: "This Month") : AppText.value(zh: "總榜分數", en: "All-time Score")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                statGrid
                recentSection
                visitedSection
                achievementsSection
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.bottom, 34)
        }
        .appPageBackground(FrogTheme.warmPaper)
        .localizedNavigationTitle { AppText.value(zh: "登山者", en: "Hiker") }
        .nativeInlineTitle()
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: heroMountainId), dimming: 0)
                .frame(height: 220)

            LinearGradient(
                colors: [.clear, FrogTheme.forest.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(profileSubtitle)
                        .font(.frogCaption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    if let titleText {
                        HStack(spacing: 5) {
                            Image(systemName: "rosette")
                                .font(.frogMicro.weight(.black))
                            Text(titleText)
                                .font(.frogNum(12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FrogTheme.gold.opacity(0.95), in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 6)
    }

    @ViewBuilder
    private var avatar: some View {
        switch selection {
        case .seed(let entry):
            SeedHikerAvatar(profile: entry.profile, size: 72, border: FrogTheme.gold)
        case .current:
            LbAvatar(mountainId: heroMountainId, size: 72, border: FrogTheme.leaf)
        }
    }

    private var statGrid: some View {
        HStack(spacing: 10) {
            LeaderboardDetailStat(value: "\(scopeScore)", label: scoreLabel, systemImage: "chart.bar.fill", tint: FrogTheme.orange)
            LeaderboardDetailStat(value: "\(totalCheckIns)", label: AppText.value(zh: "累計打卡", en: "Total Check-ins"), systemImage: "checkmark.seal.fill", tint: FrogTheme.moss)
            LeaderboardDetailStat(value: "\(distinctPeakCount)", label: AppText.value(zh: "已到山峰", en: "Peaks"), systemImage: "mountain.2.fill", tint: FrogTheme.forest)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(AppText.value(zh: "最近打卡", en: "Recent Check-ins"), trailing: recentVisits.isEmpty ? nil : AppText.times(recentVisits.count))

            if recentVisits.isEmpty {
                emptyState(AppText.value(zh: "未有打卡紀錄", en: "No check-in records yet"))
            } else {
                VStack(spacing: 0) {
                    ForEach(recentVisits) { visit in
                        LeaderboardVisitRow(visit: visit)
                    }
                }
                .cardStyle(cornerRadius: 16)
            }
        }
    }

    private var visitedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(AppText.value(zh: "打過卡的山", en: "Visited Peaks"), trailing: AppText.peaks(distinctPeakCount))

            if checkedMountains.isEmpty {
                emptyState(AppText.value(zh: "未有已打卡山峰", en: "No visited peaks yet"))
            } else {
                LazyVGrid(columns: stampColumns, spacing: 13) {
                    ForEach(Array(checkedMountains.prefix(16))) { mountain in
                        NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                            VStack(spacing: 6) {
                                MountainStampSeal(mountain: mountain, size: 54, isUnlocked: true, rotation: .degrees(0))
                                Text(mountain.localizedName)
                                    .font(.frogMicro)
                                    .foregroundStyle(FrogTheme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .cardStyle(cornerRadius: 16)
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(AppText.value(zh: "已解鎖成就", en: "Unlocked Achievements"), trailing: achievements.isEmpty ? nil : "\(achievements.count)")

            if achievements.isEmpty {
                emptyState(AppText.value(zh: "完成首次打卡後會解鎖成就", en: "Achievements unlock after your first check-in"))
            } else {
                LazyVGrid(columns: achievementColumns, spacing: 12) {
                    ForEach(achievements) { badge in
                        VStack(spacing: 9) {
                            StampBadge(systemImage: badge.systemImage, tint: badge.tint, isUnlocked: true, size: 54)
                            Text(badge.localizedTitle)
                                .font(.frogRow.weight(.black))
                                .foregroundStyle(FrogTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(badge.localizedDescription)
                                .font(.frogMicro)
                                .foregroundStyle(FrogTheme.muted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(badge.tint.opacity(0.22), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.frogEyebrow)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(FrogTheme.moss)
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
            if let trailing {
                Text(trailing)
                    .font(.frogNum(11, weight: .semibold))
                    .foregroundStyle(FrogTheme.faint)
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.frogCaption)
            .foregroundStyle(FrogTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .cardStyle(cornerRadius: 16)
    }
}

private struct LeaderboardDetailStat: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(value)
                .font(.frogNum(22, weight: .semibold))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle(cornerRadius: 15)
    }
}

private struct LeaderboardVisitRow: View {
    let visit: SeedMountainVisit

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppText.locale
        formatter.dateFormat = AppText.isEnglish ? "MMM d" : "M月d日"
        return formatter
    }()

    var body: some View {
        NavigationLink(value: NativeRoute.mountainDetail(visit.mountain.id)) {
            HStack(spacing: 12) {
                MountainPhoto(mountain: visit.mountain, dimming: 0.02)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(visit.mountain.localizedName)
                        .font(.frogRow.weight(.bold))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    Text("\(visit.mountain.nameEn) · \(visit.mountain.height)m")
                        .font(.frogMicro)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(Self.formatter.string(from: visit.date))
                        .font(.frogNum(12, weight: .semibold))
                        .foregroundStyle(FrogTheme.forest)
                    Text(AppText.times(visit.repeatCount))
                        .font(.frogMicro)
                        .foregroundStyle(FrogTheme.muted)
                }
            }
            .padding(12)
            .background(FrogTheme.surface)
            .overlay(alignment: .bottom) {
                FrogTheme.lineSoft.frame(height: 1).padding(.leading, 74)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Components

/// ▲▼ rank-delta badge: up = leaf, down = trail-orange, flat = faint dash.
private struct DeltaBadge: View {
    let dir: SeedLeaderboardDelta
    let n: Int

    var body: some View {
        switch dir {
        case .flat:
            Text("—")
                .font(.frogNum(11, weight: .semibold))
                .foregroundStyle(FrogTheme.faint)
        case .up:
            badge(systemImage: "arrow.up", tint: FrogTheme.leaf)
        case .down:
            badge(systemImage: "arrow.down", tint: FrogTheme.orange)
        }
    }

    private func badge(systemImage: String, tint: Color) -> some View {
        HStack(spacing: 1) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .black))
            Text("\(n)")
                .font(.frogNum(11, weight: .semibold))
        }
        .foregroundStyle(tint)
    }
}

/// Round survey-benchmark seal (trig point: triangle + centre dot) used for #1.
private struct TrigMarkSeal: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().strokeBorder(FrogTheme.gold, lineWidth: 1.5)
            Circle()
                .strokeBorder(FrogTheme.gold.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                .padding(3)
            ZStack {
                TrigTriangle()
                    .stroke(FrogTheme.gold, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                Circle()
                    .fill(FrogTheme.gold)
                    .frame(width: size * 0.1, height: size * 0.1)
                    .offset(y: size * 0.06)
            }
            .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

private struct TrigTriangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Circular mountain-photo avatar for ranking rows.
private struct LbAvatar: View {
    let mountainId: String
    var size: CGFloat = 36
    var border: Color = .white

    var body: some View {
        MountainPhoto(mountain: MountainCatalog.mountain(id: mountainId), dimming: 0)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(border, lineWidth: 2))
            .shadow(color: FrogTheme.warmShadow.opacity(0.14), radius: 4, y: 2)
    }
}

/// Stat pill on the leaderboard hero — mirrors the passport cover's metric.
private struct LeaderboardCoverMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.frogNum(22, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.frogMicro.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            Capsule()
                .fill(FrogTheme.leaf)
                .frame(width: 26, height: 3)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(FrogTheme.forest.opacity(0.42), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}
