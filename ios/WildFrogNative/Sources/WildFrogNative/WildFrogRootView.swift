import SwiftUI

enum NativeRoute: Hashable {
    case mountainDetail(String)
    case checkIn(String)
    case tripDetail(UUID)
    case routeToCheckpoint(String)
    case allMountains
    case allTrips
    case allStamps
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
        case .home: AppText.value(zh: "探索", en: "Explore")
        case .records: AppText.value(zh: "紀錄", en: "Records")
        case .checkIn: AppText.value(zh: "打卡", en: "Check In")
        case .leaderboard: AppText.value(zh: "排行", en: "Rankings")
        case .profile: AppText.value(zh: "我的", en: "Profile")
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
    @AppStorage(AppText.languagePreferenceKey) private var languageModeRaw = AppLanguageMode.system.rawValue
    // One navigation path per tab so the root can tell when a detail is pushed.
    @State private var homePath = NavigationPath()
    @State private var recordsPath = NavigationPath()
    @State private var checkInPath = NavigationPath()
    @State private var leaderboardPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var leaderboardProfiles: [SeedHikerProfile] = []
    @State private var hasLoadedLeaderboardProfiles = false
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var recorder: TrackRecorder

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
        if arguments.contains("-qaStamps") {
            var path = NavigationPath()
            path.append(NativeRoute.allStamps)
            _profilePath = State(initialValue: path)
            _selectedTab = State(initialValue: .profile)
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

    private var activeRecordingMountain: Mountain? {
        guard recorder.isRecording,
              let id = recorder.activeMountainId else { return nil }
        return MountainCatalog.mountains.first { $0.id == id }
    }

    private var shouldShowGlobalRecordingIsland: Bool {
        recorder.isRecording && isAtTabRoot && selectedTab != .checkIn
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
                    NavigationStack(path: $leaderboardPath) {
                        LeaderboardView(
                            leaderboardProfiles: $leaderboardProfiles,
                            hasLoadedLeaderboardProfiles: $hasLoadedLeaderboardProfiles
                        )
                        .withNativeRoutes()
                    }
                case .profile:
                    NavigationStack(path: $profilePath) { ProfileView() }
                }
            }
            .id(languageModeRaw)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isAtTabRoot {
                FrogTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if shouldShowGlobalRecordingIsland, let activeRecordingMountain {
                GlobalRecordingIsland(
                    mountain: activeRecordingMountain,
                    elapsedSeconds: recorder.elapsedSeconds,
                    distanceMeters: recorder.distanceMeters,
                    isPaused: recorder.isPaused
                ) {
                    openActiveRecording(activeRecordingMountain.id)
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isAtTabRoot)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: recorder.isRecording)
        .preferredColorScheme(.light)
        .background(FrogTheme.paper.ignoresSafeArea())
    }

    private func openActiveRecording(_ mountainId: String) {
        selectedTab = .checkIn
        checkInPath = NavigationPath()
        checkInPath.append(NativeRoute.checkIn(mountainId))
    }
}

private struct GlobalRecordingIsland: View {
    let mountain: Mountain
    let elapsedSeconds: TimeInterval
    let distanceMeters: Double
    let isPaused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isPaused ? "pause.fill" : "record.circle.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(isPaused ? FrogTheme.gold : FrogTheme.orange, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(isPaused ? AppText.value(zh: "行程已暫停", en: "Trip Paused") : AppText.value(zh: "行程記錄中", en: "Recording Trip"))
                        .font(.frogMicro.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(mountain.localizedName)
                        .font(.frogCaption.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(TrackFormat.distance(distanceMeters))
                        .font(.frogNum(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(TrackFormat.duration(elapsedSeconds))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))
            }
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.82), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.value(zh: "返回進行中的 \(mountain.localizedName) 行程記錄", en: "Return to active \(mountain.localizedName) trip recording"))
    }
}

private struct FrogTabBar: View {
    @Binding var selectedTab: AppTab
    @AppStorage(AppText.languagePreferenceKey) private var languageModeRaw = AppLanguageMode.system.rawValue

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
        .id(languageModeRaw)
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
            case .allStamps:
                FullPassportStampsView()
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
