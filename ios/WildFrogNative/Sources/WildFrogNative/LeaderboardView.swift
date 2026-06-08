import SwiftUI

struct LeaderboardView: View {
    @State private var scope = LeaderboardScope.month
    @State private var showAllLeaderboard = false
    @EnvironmentObject private var checkInStore: CheckInStore

    private enum LeaderboardScope: String, CaseIterable, Identifiable {
        case month = "今月"
        case allTime = "總榜"

        var id: String { rawValue }
    }

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
                scopeSelector
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
        VStack(alignment: .leading, spacing: 3) {
            Text("排行榜")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.forest)
            Rectangle()
                .fill(FrogTheme.orange)
                .frame(width: 34, height: 3)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var scopeSelector: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardScope.allCases) { item in
                Button {
                    scope = item
                } label: {
                    Text(item.rawValue)
                        .font(.frogRow.weight(.bold))
                        .foregroundStyle(scope == item ? .white : FrogTheme.forest)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if scope == item {
                                Capsule()
                                    .fill(FrogTheme.forest)
                                    .padding(3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.56), in: Capsule())
        .overlay(Capsule().stroke(FrogTheme.line, lineWidth: 1))
    }


    private var crossUserDisclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.frogMicro.weight(.semibold))
            Text("示範資料 · 真實排行榜需要伺服器（即將推出）")
                .font(.frogMicro)
        }
        .foregroundStyle(FrogTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrogTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var myRankCard: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的紀錄")
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.forest)
                    Text("\(myTotalCheckIns)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text("總打卡")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.ink)
                        Text("\(myDistinctMountains)")
                            .font(.frogTitle)
                            .foregroundStyle(FrogTheme.orange)
                        Text("座山")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.ink)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.orange)
                        Text("連續 \(checkInStore.currentStreak) 日")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                }

                Spacer()

                ZStack(alignment: .top) {
                    MountainPhoto(mountain: MountainCatalog.mountain(id: "victoria-peak"), dimming: 0.05)
                        .frame(width: 126, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(Color.white, lineWidth: 8)
                        )
                        .rotationEffect(.degrees(1.5))

                    Rectangle()
                        .fill(Color(red: 218 / 255, green: 199 / 255, blue: 153 / 255).opacity(0.72))
                        .frame(width: 54, height: 18)
                        .rotationEffect(.degrees(-2))
                        .offset(y: -8)
                }
            }

            Image("WildFrogBrandMark")
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .opacity(0.18)
                .clipShape(Circle())
        }
        .padding(20)
        .background(FrogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.orange.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private var podiumPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top 3")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.forest)
                Rectangle()
                    .fill(FrogTheme.orange)
                    .frame(width: 28, height: 2)
                    .clipShape(Capsule())
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(demoUsers.prefix(3))) { user in
                    PodiumCard(user: user, height: user.rank == 1 ? 132 : 112)
                }
            }
        }
    }

    private var topUsers: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("排行榜（示範）")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Button { showAllLeaderboard = true } label: {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(demoUsers) { user in
                    LeaderboardRow(user: user, isCurrentUser: false)
                }
            }
            .cardStyle()
        }
    }

    private var mountainHeatList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("熱門山峰")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Button { showAllLeaderboard = true } label: {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                }
                .buttonStyle(.plain)
            }

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

    private var tint: Color {
        switch user.rank {
        case 1: FrogTheme.gold
        case 2: FrogTheme.moss
        default: FrogTheme.slate
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(user.rank)")
                .font(.system(size: user.rank == 1 ? 26 : 22, weight: .black, design: .rounded))
                .foregroundStyle(tint)

            LeaderboardAvatar(user: user, size: user.rank == 1 ? 62 : 54)
                .overlay {
                    if user.rank == 1 {
                        HStack(spacing: 26) {
                            Image(systemName: "laurel.leading")
                            Image(systemName: "laurel.trailing")
                        }
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(FrogTheme.gold)
                        .offset(y: 2)
                    }
                }

            VStack(spacing: 2) {
                Text(user.name)
                    .font(.frogCaption.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(user.climbed) 山")
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer(minLength: 0)

            Text("\(user.checkIns)")
                .font(.frogTitle)
                .foregroundStyle(FrogTheme.orange)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(10)
        .background(
            LinearGradient(
                colors: [FrogTheme.surface, tint.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct LeaderboardRow: View {
    let user: LeaderboardUser
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(user.rank)")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 34, alignment: .leading)

            LeaderboardAvatar(user: user, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(user.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(user.checkIns)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(isCurrentUser ? FrogTheme.orange : FrogTheme.ink)
                Text("次")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(12)
        .background(isCurrentUser ? FrogTheme.orangeSoft.opacity(0.55) : FrogTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.leading, 84)
        }
    }
}

private struct LeaderboardAvatar: View {
    let user: LeaderboardUser
    let size: CGFloat

    var body: some View {
        MountainPhoto(mountain: MountainCatalog.mountain(id: user.avatarMountainId), dimming: 0.02)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
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
