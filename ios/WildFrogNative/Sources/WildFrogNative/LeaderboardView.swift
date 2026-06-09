import SwiftUI

struct LeaderboardView: View {
    @State private var showAllLeaderboard = false
    @EnvironmentObject private var checkInStore: CheckInStore

    // Demo cross-user data — rank 18 / checkIns are placeholder until Cloud Function
    private let demoUsers: [LeaderboardUser] = [
        LeaderboardUser(rank: 1, name: "Kin", subtitle: "九龍 · 連續 21 日", checkIns: 58, climbed: 83, avatarMountainId: "tai-mo-shan"),
        LeaderboardUser(rank: 2, name: "Mandy", subtitle: "新界 · 週末登山", checkIns: 46, climbed: 79, avatarMountainId: "sunset-peak"),
        LeaderboardUser(rank: 3, name: "阿峯", subtitle: "港島 · 清晨路線", checkIns: 41, climbed: 74, avatarMountainId: "lion-rock"),
        LeaderboardUser(rank: 21, name: "Aud", subtitle: "大嶼山 · 日落線", checkIns: 29, climbed: 21, avatarMountainId: "lantau-peak"),
    ]

    /// Real personal stats from CheckInStore (true data, personal only).
    private var myTotalCheckIns: Int { checkInStore.totalCheckIns }
    private var myDistinctMountains: Int { checkInStore.distinctMountainCount }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                leaderboardHeader
                crossUserDisclaimer
                myRankCard
                podiumPanel
                topUsers
                mountainHeatList
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
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

    private var leaderboardHeader: some View {
        // .lb-title: 34 / forest / tight tracking, with a 32×3 trail underline (.u)
        VStack(alignment: .leading, spacing: 7) {
            Text("排行榜")
                .font(.frogNum(34, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(FrogTheme.forest)
            Capsule()
                .fill(FrogTheme.orange)
                .frame(width: 32, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var crossUserDisclaimer: some View {
        // .note: trail-soft bg, small brick-brown text (#8a5a3e), info glyph.
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

    /// .note text colour (#8a5a3e) — restrained brick-brown on trail-soft.
    private static let brickBrown = Color(red: 138 / 255, green: 90 / 255, blue: 62 / 255)

    private var myRankCard: some View {
        // .myrank: left = eyebrow + big rank number + "總打卡 · N 座山" + streak;
        // right = tilted poster photo (white border). Plain hairline card.
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("我的紀錄 · MY RECORD")
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)

                Text("\(myTotalCheckIns)")
                    .font(.frogNum(62, weight: .semibold))
                    .tracking(-1.5)
                    .foregroundStyle(FrogTheme.forest)
                    .lineLimit(1)
                    .padding(.top, 4)

                // .sub — count is a numeral data-accent (gold), not orange.
                (
                    Text("總打卡 · ")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                    + Text("\(myDistinctMountains)")
                        .font(.frogNum(14, weight: .bold))
                        .foregroundStyle(FrogTheme.gold)
                    + Text(" 座山")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                )
                .padding(.top, 8)

                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                    Text("連續 \(checkInStore.currentStreak) 日")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }
                .padding(.top, 9)
            }

            Spacer(minLength: 0)

            MountainPhoto(mountain: MountainCatalog.mountain(id: "tai-mo-shan"), dimming: 0.05)
                .frame(width: 104, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white, lineWidth: 6)
                )
                .shadow(color: FrogTheme.warmShadow.opacity(0.14), radius: 9, x: 0, y: 5)
                .rotationEffect(.degrees(1.5))
        }
        .padding(18)
        .cardStyle()
    }

    private var podiumPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader("TOP 3")

            // .podium: 3 cards end-aligned; first centred + elevated (gold tint).
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(podiumOrder) { user in
                    PodiumCard(user: user, height: user.rank == 1 ? 158 : 138)
                }
            }
        }
    }

    /// Podium display order: 2nd · 1st · 3rd (winner centred), matching the design.
    private var podiumOrder: [LeaderboardUser] {
        let top = Array(demoUsers.prefix(3))
        let first = top.first { $0.rank == 1 }
        let second = top.first { $0.rank == 2 }
        let third = top.first { $0.rank == 3 }
        return [second, first, third].compactMap { $0 }
    }

    /// .wf-section: eyebrow label + trailing hairline rule.
    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.frogEyebrow)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(FrogTheme.moss)
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
        }
    }

    private var topUsers: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("排行榜（示範）")

            // .lb-row list — the current-user row (.me) gets a trail-soft highlight.
            VStack(spacing: 0) {
                ForEach(demoUsers) { user in
                    LeaderboardRow(user: user, isCurrentUser: false)
                }
            }
            .padding(.top, 6)

            // 完整排行 → opens the full ranking list.
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
            .padding(.top, 6)
        }
    }

    private var mountainHeatList: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader("熱門山峰 · HOT PEAKS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MountainCatalog.mountains.prefix(6)) { mountain in
                        NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                            HotMountainCard(mountain: mountain)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct LeaderboardUser: Identifiable {
    let rank: Int
    let name: String
    let subtitle: String
    let checkIns: Int
    let climbed: Int
    let avatarMountainId: String

    var id: Int { rank }
}

private struct PodiumCard: View {
    let user: LeaderboardUser
    let height: CGFloat

    private var isFirst: Bool { user.rank == 1 }

    /// .pod .rk colour — first gold, second pine, third faint (ink-3).
    private var rankColor: Color {
        switch user.rank {
        case 1: FrogTheme.gold
        case 2: FrogTheme.moss
        default: FrogTheme.faint
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("\(user.rank)")
                .font(.frogNum(20, weight: .semibold))
                .foregroundStyle(rankColor)

            LeaderboardAvatar(user: user, size: isFirst ? 58 : 50)

            VStack(spacing: 4) {
                Text(user.name)
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)

                Text("\(user.checkIns)")
                    .font(.frogNum(18, weight: .semibold))
                    .foregroundStyle(isFirst ? FrogTheme.forest : FrogTheme.moss)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            // .pod: plain surface + hairline; .pod.first gets a gold tint.
            if isFirst {
                LinearGradient(
                    colors: [FrogTheme.surface, FrogTheme.gold.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                FrogTheme.surface
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }
}

private struct LeaderboardRow: View {
    let user: LeaderboardUser
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 13) {
            Text("\(user.rank)")
                .font(.frogNum(16, weight: .semibold))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 26, alignment: .leading)

            LeaderboardAvatar(user: user, size: 38, borderWidth: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "你 · \(user.name)" : user.name)
                    .font(.frogRow.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(user.subtitle)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(user.checkIns)")
                    .font(.frogNum(17, weight: .semibold))
                    .foregroundStyle(isCurrentUser ? FrogTheme.orange : FrogTheme.ink)
                Text("次")
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.faint)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, isCurrentUser ? 12 : 4)
        .background {
            // .lb-row.me: trail-soft highlight, rounded; others = hairline divider.
            if isCurrentUser {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FrogTheme.orangeSoft)
            }
        }
        .overlay(alignment: .bottom) {
            if !isCurrentUser {
                Rectangle()
                    .fill(FrogTheme.lineSoft)
                    .frame(height: 1)
            }
        }
    }
}

private struct LeaderboardAvatar: View {
    let user: LeaderboardUser
    let size: CGFloat
    var borderWidth: CGFloat = 3

    var body: some View {
        MountainPhoto(mountain: MountainCatalog.mountain(id: user.avatarMountainId), dimming: 0.02)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: borderWidth))
            .shadow(color: FrogTheme.warmShadow.opacity(0.12), radius: 5, y: 2)
    }
}

private struct HotMountainCard: View {
    let mountain: Mountain

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.16)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(mountain.nameZh)
                    .font(.frogRow.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(mountain.totalCheckIns) 次打卡")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 128, height: 116)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
