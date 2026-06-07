import CoreLocation
import SwiftUI

enum NativeRoute: Hashable {
    case mountainDetail(String)
    case checkIn(String)
    case tripDetail(UUID)
    case routeToCheckpoint(String)
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
    @EnvironmentObject private var locationManager: LocationManager

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
                    NavigationStack { CheckInPickerView() }
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
            case .tripDetail(let id):
                TripDetailView(recordId: id)
            case .routeToCheckpoint(let id):
                RouteToCheckpointView(mountain: MountainCatalog.mountain(id: id))
            }
        }
    }
}

// MARK: - CheckInPickerView

struct CheckInPickerView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore

    /// Mountains sorted by distance (nearest first). Falls back to alphabetical when no location fix.
    private var sortedMountains: [Mountain] {
        MountainCatalog.mountains.sorted { a, b in
            let da = locationManager.distance(to: a.coordinate)
            let db = locationManager.distance(to: b.coordinate)
            switch (da, db) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.nameZh < b.nameZh
            }
        }
    }

    private var hasLocation: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("選擇要打卡嘅山峰")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                    Text(hasLocation ? "按距離排列，最近優先" : "開啟定位可按距離排列")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.top, 16)

                if !hasLocation {
                    HStack(spacing: 10) {
                        Image(systemName: "location.slash.fill")
                            .foregroundStyle(FrogTheme.orange)
                        Text("允許定位後可睇到最近嘅山峰")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FrogTheme.mapWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, FrogSpace.screenPadding)
                }

                LazyVStack(spacing: 10) {
                    ForEach(sortedMountains) { mountain in
                        NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
                            CheckInPickerRow(mountain: mountain,
                                            distance: locationManager.distance(to: mountain.coordinate),
                                            visitCount: checkInStore.count(for: mountain.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.bottom, 110)
            }
        }
        .background(FrogTheme.paper)
        .navigationTitle("打卡")
        .nativeInlineTitle()
        .withNativeRoutes()
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating()
        }
    }
}

private struct CheckInPickerRow: View {
    let mountain: Mountain
    let distance: CLLocationDistance?
    let visitCount: Int

    private var distanceText: String {
        guard let d = distance else { return "—" }
        return d < 1000 ? "\(Int(d))m" : String(format: "%.1fkm", d / 1000)
    }

    private var isVisited: Bool { visitCount > 0 }

    var body: some View {
        HStack(spacing: 14) {
            MountainPhoto(mountain: mountain, dimming: 0.08)
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(mountain.nameZh)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    if isVisited {
                        Text("已打卡")
                            .font(.frogMicro.weight(.black))
                            .foregroundStyle(FrogTheme.forest)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(FrogTheme.leaf, in: Capsule())
                    }
                }
                Text(mountain.nameEn)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.forest)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(mountain.height)m", systemImage: "triangle.fill")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    Text("·").foregroundStyle(FrogTheme.muted).font(.frogMicro)
                    Text(mountain.region)
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(distance == nil ? FrogTheme.muted : FrogTheme.ink)
                if isVisited {
                    Text("\(visitCount)次")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isVisited ? FrogTheme.moss.opacity(0.35) : FrogTheme.line, lineWidth: 1)
        )
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
