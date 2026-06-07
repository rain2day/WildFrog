import SwiftUI

enum NativeRoute: Hashable {
    case mountainDetail(String)
    case checkIn(String)
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
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { HomeMapListView().withNativeRoutes() }
                case .records:
                    NavigationStack { RecordsCalendarView().withNativeRoutes() }
                case .checkIn:
                    NavigationStack { CheckInCameraView(mountain: MountainCatalog.mountain(id: "lion-rock")) }
                case .leaderboard:
                    NavigationStack { LeaderboardView().withNativeRoutes() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FrogTabBar(selectedTab: $selectedTab)
        }
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
            Color.white.opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: -6)
        }
    }

    private func flatItem(_ tab: AppTab) -> some View {
        let active = selectedTab == tab
        return VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(active ? FrogTheme.orange : FrogTheme.muted)
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
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
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
    var tint: Color = FrogTheme.orange

    private var isEmpty: Bool {
        value == "—" || value == "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isEmpty ? FrogTheme.muted : tint)
            Text(value)
                .font(.system(size: 22, weight: isEmpty ? .semibold : .bold, design: .rounded))
                .foregroundStyle(isEmpty ? FrogTheme.muted : FrogTheme.ink)
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
