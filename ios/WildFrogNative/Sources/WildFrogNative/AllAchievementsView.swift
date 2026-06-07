import SwiftUI

// MARK: - AllAchievementsView

struct AllAchievementsView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let tint: Color
        let threshold: Int

        var isUnlocked: Bool { false }
    }

    private var achievements: [Achievement] {
        [
            Achievement(id: "trail1", title: "Trail", description: "完成首次打卡", systemImage: "figure.hiking", tint: FrogTheme.moss, threshold: 1),
            Achievement(id: "summit1", title: "Summit", description: "登頂 10 座山峰", systemImage: "mountain.2.fill", tint: FrogTheme.gold, threshold: 10),
            Achievement(id: "photo1", title: "Photo", description: "上載登頂相片", systemImage: "camera.fill", tint: FrogTheme.slate, threshold: 1),
            Achievement(id: "ten1", title: "10+ Peaks", description: "完成 10 次打卡", systemImage: "checkmark.seal.fill", tint: FrogTheme.orange, threshold: 10),
            Achievement(id: "summit50", title: "Peak Explorer", description: "登頂 50 座山峰", systemImage: "scope", tint: FrogTheme.moss, threshold: 50),
            Achievement(id: "summit100", title: "Century Hiker", description: "登頂 100 座山峰", systemImage: "star.circle.fill", tint: FrogTheme.gold, threshold: 100),
            Achievement(id: "summit300", title: "300 Peak Champion", description: "完成全部 300 峰", systemImage: "crown.fill", tint: FrogTheme.orange, threshold: 300),
            Achievement(id: "streak7", title: "Week Streak", description: "連續 7 天打卡", systemImage: "flame.fill", tint: FrogTheme.orange, threshold: 7),
        ]
    }

    private var unlockedCount: Int {
        achievements.filter { checkInStore.distinctMountainCount >= $0.threshold }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("成就徽章")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(FrogTheme.forest)
                        Text("已解鎖 \(unlockedCount) / \(achievements.count)")
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
                        let unlocked = checkInStore.distinctMountainCount >= badge.threshold
                        VStack(spacing: 10) {
                            StampBadge(
                                systemImage: badge.systemImage,
                                tint: badge.tint,
                                isUnlocked: unlocked,
                                size: 64
                            )

                            VStack(spacing: 3) {
                                Text(badge.title)
                                    .font(.frogRow.weight(.black))
                                    .foregroundStyle(unlocked ? FrogTheme.ink : FrogTheme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(badge.description)
                                    .font(.frogMicro)
                                    .foregroundStyle(FrogTheme.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(unlocked ? Color.white : Color.black.opacity(0.03))
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
        .navigationTitle("成就")
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper.ignoresSafeArea())
    }
}

// MARK: - AllLeaderboardView

struct AllLeaderboardView: View {
    private let allUsers: [PublicLeaderboardUser] = [
        PublicLeaderboardUser(rank: 1, name: "Kin", subtitle: "九龍 · 連續 21 日", checkIns: 58, climbed: 83, avatarMountainId: "tai-mo-shan"),
        PublicLeaderboardUser(rank: 2, name: "Mandy", subtitle: "新界 · 週末登山", checkIns: 46, climbed: 79, avatarMountainId: "sunset-peak"),
        PublicLeaderboardUser(rank: 3, name: "阿峯", subtitle: "港島 · 清晨路線", checkIns: 41, climbed: 74, avatarMountainId: "lion-rock"),
        PublicLeaderboardUser(rank: 4, name: "Cheung", subtitle: "離島 · 越野跑", checkIns: 38, climbed: 68, avatarMountainId: "lantau-peak"),
        PublicLeaderboardUser(rank: 5, name: "Sarah", subtitle: "新界 · 假日行山", checkIns: 37, climbed: 55, avatarMountainId: "victoria-peak"),
        PublicLeaderboardUser(rank: 18, name: "你", subtitle: "WildFrog Draft", checkIns: 36, climbed: 14, avatarMountainId: "victoria-peak"),
        PublicLeaderboardUser(rank: 21, name: "Aud", subtitle: "大嶼山 · 日落線", checkIns: 29, climbed: 21, avatarMountainId: "lantau-peak"),
        PublicLeaderboardUser(rank: 22, name: "Kit", subtitle: "九龍 · 晨運", checkIns: 27, climbed: 18, avatarMountainId: "lion-rock"),
        PublicLeaderboardUser(rank: 23, name: "Wing", subtitle: "港島 · 後山", checkIns: 24, climbed: 16, avatarMountainId: "tai-mo-shan"),
        PublicLeaderboardUser(rank: 24, name: "Ping", subtitle: "新界 · 北行", checkIns: 22, climbed: 14, avatarMountainId: "sunset-peak"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("本月好友全榜")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Spacer()
                }
                .padding(.top, 4)

                Text("示範資料 · 真實排名將由 Cloud Function 提供")
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FrogTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(allUsers) { user in
                        AllLeaderboardRow(user: user, isCurrentUser: user.name == "你")
                    }
                }
                .cardStyle()
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .navigationTitle("全榜")
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper.ignoresSafeArea())
    }
}

struct PublicLeaderboardUser: Identifiable {
    let rank: Int
    let name: String
    let subtitle: String
    let checkIns: Int
    let climbed: Int
    let avatarMountainId: String

    var id: Int { rank }
}

private struct AllLeaderboardRow: View {
    let user: PublicLeaderboardUser
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(user.rank)")
                .font(.headline.weight(.black))
                .foregroundStyle(rankColor)
                .frame(width: 34, alignment: .leading)

            MountainPhoto(mountain: MountainCatalog.mountain(id: user.avatarMountainId), dimming: 0.02)
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)

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
        .background(isCurrentUser ? FrogTheme.orangeSoft.opacity(0.55) : Color.white)
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
