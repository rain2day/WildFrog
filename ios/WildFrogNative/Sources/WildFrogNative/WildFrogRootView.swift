import SwiftUI

enum NativeRoute: Hashable {
    case mountainDetail(String)
    case checkIn(String)
    case tripDetail(UUID)
    case routeToCheckpoint(String)
    case allMountains
    case allTrips
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case records
    case checkIn
    case leaderboard
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "探索"
        case .records: "紀錄"
        case .checkIn: "打卡"
        case .leaderboard: "排行"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "map.fill"
        case .records: "book.closed.fill"
        case .checkIn: "checkmark.seal.fill"
        case .leaderboard: "chart.bar.fill"
        case .profile: "person.fill"
        }
    }

    var isCenterCTA: Bool { self == .checkIn }
}

struct WildFrogRootView: View {
    @State private var selectedTab: AppTab = .home
    // One navigation path per tab so the root can tell when a detail is pushed.
    @State private var homePath = NavigationPath()
    @State private var recordsPath = NavigationPath()
    @State private var checkInPath = NavigationPath()
    @State private var leaderboardPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @EnvironmentObject private var locationManager: LocationManager

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let tabFlagIndex = arguments.firstIndex(of: "-qaTab"),
           arguments.indices.contains(arguments.index(after: tabFlagIndex)),
           let qaTab = AppTab(rawValue: arguments[arguments.index(after: tabFlagIndex)]) {
            _selectedTab = State(initialValue: qaTab)
        }
        // Deep-link straight to a mountain detail for screenshot/QA loops.
        if let mIndex = arguments.firstIndex(of: "-qaMountain"),
           arguments.indices.contains(arguments.index(after: mIndex)) {
            var path = NavigationPath()
            path.append(NativeRoute.mountainDetail(arguments[arguments.index(after: mIndex)]))
            _homePath = State(initialValue: path)
            _selectedTab = State(initialValue: .home)
        }
        if arguments.contains("-qaDirectory") {
            var path = NavigationPath()
            path.append(NativeRoute.allMountains)
            _homePath = State(initialValue: path)
            _selectedTab = State(initialValue: .home)
        }
        if let cIndex = arguments.firstIndex(of: "-qaCheckIn"),
           arguments.indices.contains(arguments.index(after: cIndex)) {
            var path = NavigationPath()
            path.append(NativeRoute.checkIn(arguments[arguments.index(after: cIndex)]))
            _homePath = State(initialValue: path)
            _selectedTab = State(initialValue: .home)
        }
        #endif
    }

    /// The floating tab bar only belongs at the root of a tab. Drilling into
    /// any pushed detail (check-in, mountain detail, trip, route) hides it so
    /// the content is never covered by the bar.
    private var isAtTabRoot: Bool {
        switch selectedTab {
        case .home: return homePath.isEmpty
        case .records: return recordsPath.isEmpty
        case .checkIn: return checkInPath.isEmpty
        case .leaderboard: return leaderboardPath.isEmpty
        case .profile: return profilePath.isEmpty
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) { HomeMapListView().withNativeRoutes() }
                case .records:
                    NavigationStack(path: $recordsPath) { RecordsCalendarView().withNativeRoutes() }
                case .checkIn:
                    NavigationStack(path: $checkInPath) { CheckInPickerView() }
                case .leaderboard:
                    NavigationStack(path: $leaderboardPath) { LeaderboardView().withNativeRoutes() }
                case .profile:
                    NavigationStack(path: $profilePath) { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isAtTabRoot {
                FrogTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isAtTabRoot)
        .preferredColorScheme(.light)
        .background(FrogTheme.paper.ignoresSafeArea())
    }
}

private struct FrogTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    if tab.isCenterCTA {
                        centerItem(tab)
                    } else {
                        flatItem(tab)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            LinearGradient(
                colors: [Color.white.opacity(0.96), FrogTheme.warmPaper.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: -6)
        }
    }

    private func flatItem(_ tab: AppTab) -> some View {
        let active = selectedTab == tab
        return VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(active ? FrogTheme.moss : FrogTheme.muted)
            Text(tab.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(active ? FrogTheme.ink : FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 3)
        .contentShape(Rectangle())
    }

    private func centerItem(_ tab: AppTab) -> some View {
        let active = selectedTab == tab
        return VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(FrogTheme.orange, in: Circle())
                .overlay(Circle().stroke(FrogTheme.surface, lineWidth: 4))
                .shadow(color: FrogTheme.orange.opacity(active ? 0.44 : 0.28), radius: 12, y: 5)
            Text(tab.title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(active ? FrogTheme.orange : FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -16)
        .contentShape(Rectangle())
    }
}

extension View {
    func withNativeRoutes() -> some View {
        navigationDestination(for: NativeRoute.self) { route in
            switch route {
            case .mountainDetail(let id):
                MountainDetailView(mountain: MountainCatalog.mountain(id: id))
            case .checkIn(let id):
                CheckInCameraView(mountain: MountainCatalog.mountain(id: id))
            case .tripDetail(let id):
                TripDetailView(recordId: id)
            case .routeToCheckpoint(let id):
                RouteToCheckpointView(mountain: MountainCatalog.mountain(id: id))
            case .allMountains:
                MountainDirectoryView()
            case .allTrips:
                AllTripsView()
            }
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let value: String
    let label: String
    let systemImage: String
    var tint: Color = FrogTheme.orange

    private var isEmpty: Bool {
        value == "—" || value == "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isEmpty ? FrogTheme.muted : .white)
                .frame(width: 30, height: 30)
                .background(isEmpty ? FrogTheme.ink.opacity(0.06) : tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(value)
                .font(.system(size: 22, weight: isEmpty ? .semibold : .bold, design: .rounded))
                .foregroundStyle(isEmpty ? FrogTheme.muted : FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
    }
}
