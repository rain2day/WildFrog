import SwiftUI

struct LeaderboardView: View {
    @State private var scope = LeaderboardScope.month

    private enum LeaderboardScope: String, CaseIterable, Identifiable {
        case month = "今月"
        case allTime = "總榜"

        var id: String { rawValue }
    }

    private let users: [LeaderboardUser] = [
        LeaderboardUser(rank: 1, name: "Kin", subtitle: "九龍 · 連續 21 日", checkIns: 151, climbed: 83),
        LeaderboardUser(rank: 2, name: "Mandy", subtitle: "新界 · 週末登山", checkIns: 138, climbed: 79),
        LeaderboardUser(rank: 3, name: "Hei", subtitle: "港島 · 清晨路線", checkIns: 126, climbed: 74),
        LeaderboardUser(rank: 18, name: "你", subtitle: "WildFrog Draft", checkIns: 86, climbed: 14),
        LeaderboardUser(rank: 27, name: "Aud", subtitle: "大嶼山 · 日落線", checkIns: 72, climbed: 21),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                myRankCard
                topUsers
                mountainHeatList
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .navigationTitle("排行")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("排行榜")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.ink)
                Text("睇自己同朋友的打卡進度")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer()

            Picker("排行範圍", selection: $scope) {
                ForEach(LeaderboardScope.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 128)
        }
    }

    private var myRankCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("我的排名")
                    .font(.caption.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
                Text("#18")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.ink)
                Text("比上週上升 4 位")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                RankMetric(value: "86", label: "有效打卡")
                RankMetric(value: "14", label: "已到訪山峰")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var topUsers: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scope == .month ? "今月 Top 5" : "總榜 Top 5")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.ink)

            VStack(spacing: 0) {
                ForEach(users) { user in
                    LeaderboardRow(user: user, isCurrentUser: user.name == "你")
                }
            }
            .cardStyle()
        }
    }

    private var mountainHeatList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("熱門山峰")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.ink)

            VStack(spacing: 0) {
                ForEach(MountainCatalog.mountains.prefix(5)) { mountain in
                    NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                        HStack(spacing: 10) {
                            MountainThumbnail(mountain: mountain, size: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(mountain.displayName)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(FrogTheme.ink)
                                    .lineLimit(1)
                                Text("\(mountain.totalCheckIns) 次打卡 · \(mountain.height)m")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(FrogTheme.muted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(mountain.rankText)
                                .font(.caption.weight(.black))
                                .foregroundStyle(FrogTheme.orange)
                        }
                        .padding(12)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(FrogTheme.line)
                            .frame(height: 1)
                            .padding(.leading, 68)
                    }
                }
            }
            .cardStyle()
        }
    }
}

private struct LeaderboardUser: Identifiable {
    let rank: Int
    let name: String
    let subtitle: String
    let checkIns: Int
    let climbed: Int

    var id: Int { rank }
}

private struct LeaderboardRow: View {
    let user: LeaderboardUser
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(user.rank)")
                .font(.headline.weight(.black))
                .foregroundStyle(isCurrentUser ? .white : FrogTheme.orange)
                .frame(width: 52, height: 42)
                .background(isCurrentUser ? FrogTheme.orange : FrogTheme.orangeSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                    .foregroundStyle(FrogTheme.ink)
                Text("\(user.climbed) 山")
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
                .padding(.leading, 76)
        }
    }
}

private struct RankMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(FrogTheme.ink)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(FrogTheme.muted)
        }
    }
}
