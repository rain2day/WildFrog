import SwiftUI

/// 排行榜 — "田野紀錄冊 / Field Ledger" layout (design Option B): a full-bleed image
/// hero (matching the other pages), a 今月/總榜 segment, a deep-green 本月領隊 leader
/// band, a precise tabular ranking with ▲▼ rank-deltas, and a pinned 我的名次 bar.
struct LeaderboardView: View {
    @State private var showAllLeaderboard = false
    @State private var scope: Scope = .month
    @EnvironmentObject private var checkInStore: CheckInStore
    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""

    private enum Scope { case month, all }

    // Demo cross-user data — placeholder until a Cloud Function backs the real board.

    // Monthly dataset
    private let leaderMonth = LbUser(rank: 1, name: "Kin", meta: "九龍 · 連續 21 日 · 最高 957m",
                                     count: 58, avatar: "tai-mo-shan", delta: .flat, deltaN: 0)
    private let rowsMonth: [LbUser] = [
        LbUser(rank: 2, name: "Mandy", meta: "新界 · 週末登山", count: 46, avatar: "lantau-peak", delta: .up, deltaN: 1),
        LbUser(rank: 3, name: "阿峯", meta: "港島 · 清晨路線", count: 41, avatar: "lion-rock", delta: .down, deltaN: 1),
        LbUser(rank: 4, name: "Wing", meta: "西貢 · 行山隊", count: 38, avatar: "lion-rock", delta: .up, deltaN: 2),
        LbUser(rank: 5, name: "阿康", meta: "大嶼山 · 日出線", count: 35, avatar: "lantau-peak", delta: .flat, deltaN: 0),
        LbUser(rank: 6, name: "Tina", meta: "新界 · 越野跑", count: 33, avatar: "tai-mo-shan", delta: .up, deltaN: 4),
    ]

    // All-time dataset
    private let leaderAll = LbUser(rank: 1, name: "Kin", meta: "九龍 · 累計 83 座 · 最高 957m",
                                   count: 312, avatar: "tai-mo-shan", delta: .flat, deltaN: 0)
    private let rowsAll: [LbUser] = [
        LbUser(rank: 2, name: "Mandy", meta: "新界 · 週末登山", count: 287, avatar: "lantau-peak", delta: .flat, deltaN: 0),
        LbUser(rank: 3, name: "阿峯", meta: "港島 · 清晨路線", count: 264, avatar: "lion-rock", delta: .flat, deltaN: 0),
        LbUser(rank: 4, name: "Wing", meta: "西貢 · 行山隊", count: 231, avatar: "lion-rock", delta: .flat, deltaN: 0),
        LbUser(rank: 5, name: "阿康", meta: "大嶼山 · 日出線", count: 198, avatar: "lantau-peak", delta: .flat, deltaN: 0),
        LbUser(rank: 6, name: "Tina", meta: "新界 · 越野跑", count: 176, avatar: "tai-mo-shan", delta: .flat, deltaN: 0),
    ]

    private var currentLeader: LbUser { scope == .month ? leaderMonth : leaderAll }
    private var currentRows: [LbUser] { scope == .month ? rowsMonth : rowsAll }

    /// Real personal stats from CheckInStore (true data, personal only).
    private var myTotalCheckIns: Int { checkInStore.totalCheckIns }
    private var myDistinctMountains: Int { checkInStore.distinctMountainCount }

    /// Computed rank against the current scope's demo dataset (leader + rows).
    private var myRank: Int {
        let allCounts = ([currentLeader] + currentRows).map { $0.count }
        return allCounts.filter { $0 > myTotalCheckIns }.count + 1
    }

    /// The equipped 稱號 (only while it's still a conquered peak); shown on my row.
    private var equippedTitle: String? {
        guard !equippedTitleId.isEmpty,
              checkInStore.visitedMountainIds.contains(equippedTitleId) else { return nil }
        return MountainCatalog.mountain(id: equippedTitleId).unlockTitle
    }

    private var myAvatarId: String {
        checkInStore.records.sorted { $0.date > $1.date }.first?.mountainId ?? "lantau-peak"
    }

    /// Current month label for the hero period chip, e.g. "2026 · 6月".
    private var periodText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_HK")
        f.dateFormat = "yyyy · M月"
        return f.string(from: Date())
    }

    /// .note text colour (#8a5a3e) — restrained brick-brown on trail-soft.
    private static let brickBrown = Color(red: 138 / 255, green: 90 / 255, blue: 62 / 255)

    var body: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    leaderboardCover(topInset: topInset)

                    VStack(alignment: .leading, spacing: 16) {
                        scopeSegment
                        crossUserDisclaimer
                        leaderBand
                        rankingTable
                        completeRankLink
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
                AllLeaderboardView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showAllLeaderboard = false }
                                .font(.frogCaption.weight(.bold))
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
            }
        }
    }

    // MARK: - Hero (full-bleed image, matches the other pages)

    private func leaderboardCover(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: "kowloon-peak"), dimming: 0)

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

                Text("排行榜")
                    .font(.frogNum(34, weight: .heavy))
                    .foregroundStyle(.white)

                Text("LEADERBOARD · 一齊征服香港群山")
                    .font(.frogCaption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 7)

                HStack(spacing: 9) {
                    LeaderboardCoverMetric(value: "\(myTotalCheckIns)", label: "我的打卡")
                    LeaderboardCoverMetric(value: "\(myDistinctMountains)", label: "已到山峰")
                    LeaderboardCoverMetric(value: "\(checkInStore.currentStreak)", label: "連續日")
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
            segItem("今月", isOn: scope == .month) { scope = .month }
            segItem("總榜", isOn: scope == .all) { scope = .all }
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

    // MARK: - Cross-user disclaimer

    private var crossUserDisclaimer: some View {
        HStack(spacing: 7) {
            Image(systemName: "info.circle")
                .font(.frogMicro.weight(.semibold))
            Text("示範資料 · 真實排行榜需要伺服器（即將推出）")
                .font(.frogMicro)
        }
        .foregroundStyle(Self.brickBrown)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrogTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 本月領隊 leader band (b-leader)

    private var leaderBand: some View {
        ZStack(alignment: .leading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: currentLeader.avatar), dimming: 0)

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
                TrigMarkSeal(size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(scope == .month ? "本月領隊 · LEADER" : "總榜領隊 · ALL-TIME LEADER")
                        .font(.frogNum(10, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(FrogTheme.gold)
                    Text(currentLeader.name)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                    Text(currentLeader.meta)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentLeader.count)")
                        .font(.frogNum(40, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("次打卡")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 16)
        }
        .frame(minHeight: 118)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Tabular ranking (b-colhead + b-row)

    private var rankingTable: some View {
        VStack(spacing: 0) {
            // column header
            HStack(spacing: 11) {
                Text("名次").frame(width: 26, alignment: .leading)
                Text(" ").frame(width: 30, alignment: .leading)
                Text("登山者")
                Spacer(minLength: 0)
                Text(scope == .month ? "本月" : "總計")
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

    private func rankRow(_ u: LbUser) -> some View {
        HStack(spacing: 11) {
            Text("\(u.rank)")
                .font(.frogNum(16, weight: .semibold))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 26, alignment: .leading)

            DeltaBadge(dir: u.delta, n: u.deltaN)
                .frame(width: 30, alignment: .leading)

            HStack(spacing: 11) {
                LbAvatar(mountainId: u.avatar)
                VStack(alignment: .leading, spacing: 1) {
                    Text(u.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(FrogTheme.ink)
                    Text(u.meta)
                        .font(.system(size: 11))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("\(u.count)")
                .font(.frogNum(17, weight: .semibold))
                .foregroundStyle(FrogTheme.ink)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { FrogTheme.lineSoft.frame(height: 1) }
    }

    private var completeRankLink: some View {
        Button { showAllLeaderboard = true } label: {
            HStack(spacing: 5) {
                Text("完整排行")
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
        HStack(spacing: 11) {
            Text("\(myRank)")
                .font(.frogNum(17, weight: .bold))
                .foregroundStyle(FrogTheme.leaf)
                .frame(width: 26, alignment: .leading)

            DeltaBadge(dir: .flat, n: 0)
                .frame(width: 30, alignment: .leading)

            HStack(spacing: 11) {
                LbAvatar(mountainId: myAvatarId, border: FrogTheme.leaf)
                VStack(alignment: .leading, spacing: 1) {
                    Text("你")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text(equippedTitle ?? "你的紀錄")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("\(myTotalCheckIns)")
                .font(.frogNum(18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 14)
        .background(FrogTheme.forest, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Models + components

private struct LbUser: Identifiable {
    let rank: Int
    let name: String
    let meta: String
    let count: Int
    let avatar: String
    let delta: LbDelta
    let deltaN: Int
    var id: Int { rank }
}

private enum LbDelta { case up, down, flat }

/// ▲▼ rank-delta badge: up = leaf, down = trail-orange, flat = faint dash.
private struct DeltaBadge: View {
    let dir: LbDelta
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
