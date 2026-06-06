import SwiftUI

enum NativeRoute: Hashable {
    case mountainDetail(String)
    case checkIn(String)
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case checkIn
    case records
    case leaderboard
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首頁"
        case .checkIn: "打卡"
        case .records: "紀錄"
        case .leaderboard: "排行"
        case .profile: "個人"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "mountain.2"
        case .checkIn: "location.circle.fill"
        case .records: "chart.bar"
        case .leaderboard: "trophy"
        case .profile: "person"
        }
    }
}

struct WildFrogRootView: View {
    @State private var selectedTab: AppTab = .home

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let tabFlagIndex = arguments.firstIndex(of: "-qaTab"),
           arguments.indices.contains(arguments.index(after: tabFlagIndex)),
           let qaTab = AppTab(rawValue: arguments[arguments.index(after: tabFlagIndex)]) {
            _selectedTab = State(initialValue: qaTab)
        }
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeMapListView()
                    .withNativeRoutes()
            }
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)

            NavigationStack {
                CheckInCameraView(mountain: MountainCatalog.mountain(id: "tai-mo-shan"))
            }
            .tabItem { Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage) }
            .tag(AppTab.checkIn)

            NavigationStack {
                RecordsCalendarView()
                    .withNativeRoutes()
            }
            .tabItem { Label(AppTab.records.title, systemImage: AppTab.records.systemImage) }
            .tag(AppTab.records)

            NavigationStack {
                LeaderboardView()
                    .withNativeRoutes()
            }
            .tabItem { Label(AppTab.leaderboard.title, systemImage: AppTab.leaderboard.systemImage) }
            .tag(AppTab.leaderboard)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
            .tag(AppTab.profile)
        }
        .tint(FrogTheme.orange)
        .preferredColorScheme(.light)
        .background(FrogTheme.paper.ignoresSafeArea())
    }
}

private extension View {
    func withNativeRoutes() -> some View {
        navigationDestination(for: NativeRoute.self) { route in
            switch route {
            case .mountainDetail(let id):
                MountainDetailView(mountain: MountainCatalog.mountain(id: id))
            case .checkIn(let id):
                CheckInCameraView(mountain: MountainCatalog.mountain(id: id))
            }
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FrogTheme.orange)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.ink)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
        .lineLimit(2)
        .minimumScaleFactor(0.78)
    }
}
