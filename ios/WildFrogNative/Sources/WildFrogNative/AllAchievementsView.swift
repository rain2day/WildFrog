import SwiftUI

// MARK: - AllAchievementsView

struct AllAchievementsView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private enum AchievementMetric: Equatable {
        case peaks          // checkInStore.distinctMountainCount
        case checkIns       // checkInStore.totalCheckIns
        case streak         // checkInStore.currentStreak
        case region(String) // checkInStore.visitedCount(inRegion:)
        case height         // checkInStore.highestVisitedPeakHeight
    }

    private struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let tint: Color
        let metric: AchievementMetric
        let threshold: Int
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
            Achievement(id: "peaks300", title: "300 Peak Champion", description: "完成全部 300 峰", systemImage: "trophy.fill", tint: FrogTheme.orange, metric: .peaks, threshold: 300),

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

            // MARK: Streak — consecutive days
            Achievement(id: "streak2", title: "兩天連續", description: "連續 2 天打卡", systemImage: "flame.fill", tint: FrogTheme.leaf, metric: .streak, threshold: 2),
            Achievement(id: "streak3", title: "三天熱身", description: "連續 3 天打卡", systemImage: "flame.fill", tint: FrogTheme.moss, metric: .streak, threshold: 3),
            Achievement(id: "streak5", title: "5-Day Streak", description: "連續 5 天打卡", systemImage: "bolt.fill", tint: FrogTheme.slate, metric: .streak, threshold: 5),
            Achievement(id: "streak7", title: "Week Streak", description: "連續 7 天打卡", systemImage: "flame.fill", tint: FrogTheme.orange, metric: .streak, threshold: 7),
            Achievement(id: "streak10", title: "10-Day Streak", description: "連續 10 天打卡", systemImage: "bolt.fill", tint: FrogTheme.gold, metric: .streak, threshold: 10),
            Achievement(id: "streak14", title: "兩週不斷", description: "連續 14 天打卡", systemImage: "sunrise.fill", tint: FrogTheme.gold, metric: .streak, threshold: 14),
            Achievement(id: "streak21", title: "21-Day Habit", description: "連續 21 天打卡", systemImage: "calendar", tint: FrogTheme.forest, metric: .streak, threshold: 21),
            Achievement(id: "streak30", title: "Monthly Streak", description: "連續 30 天打卡", systemImage: "moon.stars.fill", tint: FrogTheme.gold, metric: .streak, threshold: 30),
            Achievement(id: "streak50", title: "五十日不斷", description: "連續 50 天打卡", systemImage: "flame.fill", tint: FrogTheme.orange, metric: .streak, threshold: 50),
            Achievement(id: "streak100", title: "Streak Legend", description: "連續 100 天打卡", systemImage: "trophy.fill", tint: FrogTheme.orange, metric: .streak, threshold: 100),

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
        case .streak: progress = checkInStore.currentStreak
        case .region(let region): progress = checkInStore.visitedCount(inRegion: region)
        case .height: progress = checkInStore.highestVisitedPeakHeight
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
                        let unlocked = isUnlocked(badge)
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
            Text(isCurrentUser ? "—" : "\(user.rank)")
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
        .background(isCurrentUser ? FrogTheme.orangeSoft.opacity(0.55) : FrogTheme.surface)
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
