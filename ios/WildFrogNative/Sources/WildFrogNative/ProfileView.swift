import CoreLocation
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfileView: View {
    private static let avatarStorageKey = "wildfrog.profile.avatar.thumbnail"

    @Environment(ProfileAuthService.self) private var authService
    @EnvironmentObject private var checkInStore: CheckInStore
    @EnvironmentObject private var locationManager: LocationManager
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var showMockPicker = false
    @State private var avatarData: Data
    @State private var showProviderPicker = false
    @State private var showCertificateShare = false
    @State private var showAllAchievements = false
    @State private var showDeleteAccount = false
    @State private var showNameEditor = false
    @State private var heroMountainId = MountainCatalog.randomCinematicHeroMountainId()

    init() {
        let storedAvatar = UserDefaults.standard.data(forKey: Self.avatarStorageKey) ?? Data()
        _avatarData = State(initialValue: storedAvatar)
    }

    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""
    @AppStorage(AppText.languagePreferenceKey) private var languageModeRaw = AppLanguageMode.system.rawValue
    @State private var showTitlePicker = false

    /// The 稱號 the user has equipped — only valid while it's still a peak they've
    /// conquered (guards against an equipped title from data that was since reset).
    private var equippedTitle: String? {
        guard !equippedTitleId.isEmpty,
              checkInStore.visitedMountainIds.contains(equippedTitleId) else { return nil }
        return MountainCatalog.mountain(id: equippedTitleId).localizedUnlockTitle
    }

    private var completionRatio: Double {
        guard MountainCatalog.catalogCount > 0 else { return 0 }
        return min(1, Double(checkInStore.distinctMountainCount) / Double(MountainCatalog.catalogCount))
    }

    private var completionPercentText: String {
        let percent = Int((completionRatio * 100).rounded())
        return "\(max(percent, checkInStore.distinctMountainCount == 0 ? 0 : 1))%"
    }

    private var recentMountain: Mountain {
        if let latest = checkInStore.records.sorted(by: { $0.date > $1.date }).first {
            return MountainCatalog.mountain(id: latest.mountainId)
        }
        return MountainCatalog.mountain(id: "lion-rock")
    }

    var body: some View {
        Group {
            if authService.isSignedIn {
                signedInProfile
            } else {
                GuestOnboardingView(onStart: { showProviderPicker = true })
            }
        }
        .withNativeRoutes()
        .hiddenNavigationBar()
        .sheet(isPresented: $showProviderPicker) {
            ProviderPickerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNameEditor) {
            DisplayNameEditorSheet(
                initialName: authService.session?.displayName ?? "",
                fallbackName: authService.profileLine
            )
            .presentationDetents([.height(310), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllAchievements) {
            NavigationStack {
                AllAchievementsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppText.value(zh: "完成", en: "Done")) { showAllAchievements = false }
                                .font(.frogCaption.weight(.bold))
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
            }
        }
        .sheet(isPresented: $showCertificateShare) {
            if let latest = latestConqueredMountain {
                MountainCertificateSheet(mountain: latest, checkInCount: checkInStore.count(for: latest.id))
                    .environmentObject(checkInStore)
            }
        }
        .onChange(of: selectedAvatar) { _, item in
            Task {
                await loadAvatar(from: item)
            }
        }
        .onChange(of: authService.session?.uid) { _, _ in
            // Reload avatar from UserDefaults so a newly signed-in account
            // doesn't display the previous account's in-memory avatar.
            avatarData = UserDefaults.standard.data(forKey: Self.avatarStorageKey) ?? Data()
        }
        #if DEBUG
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-qaProfileCertificate") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if latestConqueredMountain != nil {
                    showCertificateShare = true
                }
            }
        }
        #endif
        .alert(AppText.value(zh: "刪除帳戶？", en: "Delete account?"), isPresented: $showDeleteAccount) {
            Button(AppText.value(zh: "永久刪除", en: "Delete Permanently"), role: .destructive) {
                Task { await authService.deleteAccount() }
            }
            Button(AppText.value(zh: "取消", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(AppText.value(zh: "此動作無法復原。你的帳戶同雲端打卡紀錄會被永久刪除。", en: "This cannot be undone. Your account and cloud check-in records will be permanently deleted."))
        }
        .overlay(alignment: .bottomTrailing) {
            if shouldShowMockControls {
                mockFloatingButton
            }
        }
        .sheet(isPresented: $showMockPicker) {
            MockLocationPickerSheet()
        }
    }

    // MARK: - Signed-in passport

    private var signedInProfile: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHero(topInset: topInset)

                    VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                        peakPassportCard
                        languageCard
                        titleCard
                        recentCheckInCard
                        certificateCard
                        achievementsPanel
                    }
                    .padding(.horizontal, FrogSpace.screenPadding)
                    .padding(.top, FrogSpace.cardGap)
                    .padding(.bottom, 110)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .appPageBackground(FrogTheme.warmPaper)
    }

    // MARK: - Reviewer / developer location override

    private var shouldShowMockControls: Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-qaScreenshot") else { return false }
        return authService.canUseReviewerTools
    }

    private var mockFloatingButton: some View {
        Button {
            showMockPicker = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: locationManager.mockCoordinate == nil ? "location.fill" : "location.fill.viewfinder")
                    .font(.system(size: 13, weight: .black))
                Text(mockButtonLabel)
                    .font(.frogCaption.weight(.black))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                locationManager.mockCoordinate == nil ? FrogTheme.slate : FrogTheme.orange,
                in: Capsule()
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.trailing, FrogSpace.screenPadding)
        .padding(.bottom, 124) // clear the floating tab bar
        .accessibilityLabel(AppText.value(zh: "測試定位", en: "Test Location"))
    }

    private var mockButtonLabel: String {
        guard let mock = locationManager.mockCoordinate else { return AppText.value(zh: "測試定位", en: "Test Location") }
        return AppText.value(zh: "模擬中 · \(mockLabel(for: mock))", en: "Mocking · \(mockLabel(for: mock))")
    }

    private func mockLabel(for coordinate: CLLocationCoordinate2D) -> String {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = MountainCatalog.mountains.min {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: here) <
            CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude).distance(from: here)
        }
        if let nearest {
            return "\(nearest.localizedName) · \(nearest.height)m"
        }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private struct MockLocationPickerSheet: View {
        @EnvironmentObject private var locationManager: LocationManager
        @Environment(\.dismiss) private var dismiss
        @State private var search = ""

        private var filtered: [Mountain] {
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return MountainCatalog.mountains }
            return MountainCatalog.mountains.filter {
                $0.nameZh.localizedCaseInsensitiveContains(query) ||
                $0.nameEn.localizedCaseInsensitiveContains(query)
            }
        }

        var body: some View {
            NavigationStack {
                List(filtered) { mountain in
                    Button {
                        locationManager.mockCoordinate = mountain.coordinate
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mountain.localizedName)
                                    .font(.frogRow.weight(.bold))
                                    .foregroundStyle(FrogTheme.ink)
                                Text("\(mountain.nameEn) · \(mountain.height)m · \(mountain.localizedRegion)")
                                    .font(.frogCaption)
                                    .foregroundStyle(FrogTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "scope")
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $search, prompt: AppText.value(zh: "搜尋山峰名稱", en: "Search peak name"))
                .localizedNavigationTitle { AppText.value(zh: "測試定位", en: "Test Location") }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                    }
                    if locationManager.mockCoordinate != nil {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppText.value(zh: "關閉模擬", en: "Stop Mocking"), role: .destructive) {
                                locationManager.mockCoordinate = nil
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    private func profileHero(topInset: CGFloat) -> some View {
        let currentAvatarData = avatarData

        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: heroMountainId), dimming: 0)

            LinearGradient(
                colors: [
                    .black.opacity(0.22),
                    .clear,
                    FrogTheme.forest.opacity(0.5),
                    FrogTheme.forest.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    WildFrogWordmark(markSize: 30)

                    Spacer()

                    syncChip

                    accountMenu
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 20)

                // .who — avatar + identity + completion ring
                HStack(alignment: .center, spacing: 15) {
                    PhotosPicker(selection: $selectedAvatar, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarContent(avatarData: currentAvatarData)
                                .frame(width: 84, height: 84)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                .shadow(color: Color.black.opacity(0.4), radius: 9, y: 6)

                            // .cam — trail-coloured camera button, forest border
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(FrogTheme.orange)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(FrogTheme.forest, lineWidth: 3))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.value(zh: "更換頭像", en: "Change Avatar"))

                    // .info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(authService.profileLine)
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Button { showNameEditor = true } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .shadow(color: Color.black.opacity(0.22), radius: 3, y: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(AppText.value(zh: "更改名稱", en: "Edit Name"))
                        }

                        if let providerLabel = authService.session?.providerLabel {
                            Text(AppText.value(zh: "以 \(providerLabel) 登入", en: "Signed in with \(providerLabel)"))
                                .font(.frogCaption)
                                .foregroundStyle(.white.opacity(0.74))
                        }

                        if let equippedTitle {
                            HStack(spacing: 5) {
                                Image(systemName: "rosette")
                                    .font(.system(size: 11, weight: .black))
                                Text(equippedTitle)
                                    .font(.frogNum(12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(FrogTheme.gold.opacity(0.92), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                            .padding(.top, 3)
                        }

                        HStack(spacing: 16) {
                            PassportMiniMetric(value: "\(checkInStore.totalCheckIns)", label: AppText.value(zh: "打卡", en: "Check-ins"))
                            PassportMiniMetric(value: "\(checkInStore.distinctMountainCount)", label: AppText.value(zh: "山峰", en: "Peaks"))
                            PassportMiniMetric(value: "\(checkInStore.currentStreak)", label: AppText.value(zh: "連續日", en: "Streak"))
                        }
                        .padding(.top, 7)
                    }

                    Spacer(minLength: 4)

                    CompletionRing(value: completionRatio, label: completionPercentText)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .frame(height: topInset + 244)
        .clipped()
    }

    private var syncChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 11, weight: .bold))
            Text(AppText.value(zh: "雲端帳戶", en: "Cloud Account"))
                .font(.frogNum(10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(FrogTheme.leaf.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
    }

    private var accountMenu: some View {
        Menu {
            Section {
                ForEach(AppLanguageMode.allCases) { mode in
                    Button {
                        languageModeRaw = mode.rawValue
                    } label: {
                        Label(mode.title, systemImage: languageModeRaw == mode.rawValue ? "checkmark" : "globe")
                    }
                }
            }
            Button {
                showNameEditor = true
            } label: {
                Label(AppText.value(zh: "更改名稱", en: "Edit Name"), systemImage: "pencil")
            }
            Link(destination: WildFrogLegalLinks.privacy) {
                Label(AppText.value(zh: "私隱政策", en: "Privacy Policy"), systemImage: "hand.raised.fill")
            }
            Link(destination: WildFrogLegalLinks.terms) {
                Label(AppText.value(zh: "使用條款", en: "Terms of Use"), systemImage: "doc.text.fill")
            }
            Link(destination: WildFrogLegalLinks.support) {
                Label(AppText.value(zh: "支援", en: "Support"), systemImage: "questionmark.circle.fill")
            }
            Button {
                authService.signOut()
            } label: {
                Label(AppText.value(zh: "登出", en: "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) {
                showDeleteAccount = true
            } label: {
                Label(AppText.value(zh: "刪除帳戶", en: "Delete Account"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 4, y: 1)
        }
        .accessibilityLabel(AppText.value(zh: "帳戶選項", en: "Account Options"))
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Text(AppText.value(zh: "語言 · LANGUAGE", en: "LANGUAGE"))
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)
                Rectangle().fill(FrogTheme.line).frame(height: 1)
            }

            Picker(AppText.value(zh: "語言", en: "Language"), selection: $languageModeRaw) {
                ForEach(AppLanguageMode.allCases) { mode in
                    Text(mode.shortTitle).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(FrogTheme.moss)

            Text(AppText.value(zh: "目前：\(currentLanguageTitle)", en: "Current: \(currentLanguageTitle)"))
                .font(.frogCaption)
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private var currentLanguageTitle: String {
        (AppLanguageMode(rawValue: languageModeRaw) ?? .system).title
    }

    /// 稱號: the title equipped for the leaderboard, chosen from conquered peaks.
    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Text(AppText.value(zh: "我的稱號 · TITLE", en: "MY TITLE"))
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle().fill(FrogTheme.line).frame(height: 1)
            }

            HStack(spacing: 12) {
                Image(systemName: "rosette")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(equippedTitle == nil ? FrogTheme.muted : FrogTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.value(zh: "排行榜顯示", en: "Leaderboard Display"))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text(equippedTitle ?? AppText.value(zh: "未設定稱號", en: "No title selected"))
                        .font(.title3.weight(.black))
                        .foregroundStyle(equippedTitle == nil ? FrogTheme.muted : FrogTheme.forest)
                }
                Spacer(minLength: 0)
                Button { showTitlePicker = true } label: {
                    Text(equippedTitle == nil ? AppText.value(zh: "選擇", en: "Choose") : AppText.value(zh: "更換", en: "Change"))
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(FrogTheme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text(AppText.value(zh: "已征服 \(checkInStore.distinctMountainCount) 座山 · 每征服一座解鎖一個稱號", en: "\(checkInStore.distinctMountainCount) peaks conquered · each peak unlocks a title"))
                .font(.frogCaption)
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
        .sheet(isPresented: $showTitlePicker) { TitlePickerSheet() }
    }

    private var peakPassportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // .panel-head
            HStack {
                HStack(spacing: 9) {
                    WildFrogMark()
                        .stroke(FrogTheme.moss, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18)
                    Text("Peak Passport")
                        .font(.frogRow.weight(.bold))
                        .foregroundStyle(FrogTheme.ink)
                }
                Spacer()
                Text("\(checkInStore.distinctMountainCount) / \(MountainCatalog.catalogCount) PEAKS")
                    .font(.frogNum(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(checkInStore.distinctMountainCount > 0 ? FrogTheme.gold : FrogTheme.orange)
            }

            // Preview row — first 10 catalog stamps, locked vs unlocked.
            let preview = Array(MountainCatalog.mountains.prefix(10))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 5),
                spacing: 11
            ) {
                ForEach(preview) { mountain in
                    NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                        MountainStampSeal(
                            mountain: mountain,
                            size: 54,
                            isUnlocked: checkInStore.visitedMountainIds.contains(mountain.id),
                            rotation: .degrees(0)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            NavigationLink(value: NativeRoute.allStamps) {
                HStack(spacing: 5) {
                    Text(AppText.value(zh: "全部 \(MountainCatalog.catalogCount)", en: "All \(MountainCatalog.catalogCount)"))
                    Image(systemName: "arrow.right")
                        .font(.frogMicro)
                }
                .font(.frogCaption.weight(.bold))
                .foregroundStyle(FrogTheme.moss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FrogTheme.mossSoft, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(FrogSpace.cardPadding)
        .background(FrogTheme.warmPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }

    private var recentCheckInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(AppText.value(zh: "最近打卡 · RECENT", en: "RECENT CHECK-IN"))
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)
                Rectangle()
                    .fill(FrogTheme.line)
                    .frame(height: 1)
            }

            if checkInStore.totalCheckIns == 0 {
                HStack(spacing: 14) {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(FrogTheme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppText.value(zh: "仲未有打卡紀錄", en: "No check-ins yet"))
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                        Text(AppText.value(zh: "完成第一次打卡後，呢度會顯示你最近征服嘅山峰。", en: "After your first check-in, your latest conquered peak will appear here."))
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(FrogSpace.cardPadding)
                .cardStyle()
            } else {
                NavigationLink(value: NativeRoute.mountainDetail(recentMountain.id)) {
                    ZStack(alignment: .bottomLeading) {
                        MountainPhoto(mountain: recentMountain, dimming: 0.15)
                            .frame(height: 150)
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recentMountain.localizedName)
                                .font(.frogTitle)
                            Text(AppText.value(zh: "\(recentMountain.height)m · \(recentMountain.region) · \(checkInStore.count(for: recentMountain.id)) 次", en: "\(recentMountain.height)m · \(recentMountain.localizedRegion) · \(AppText.times(checkInStore.count(for: recentMountain.id)))"))
                                .font(.frogCaption)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The most recently conquered peak — the certificate the Profile shortcut shows.
    private var latestConqueredMountain: Mountain? {
        checkInStore.records
            .sorted { $0.date > $1.date }
            .first
            .map { MountainCatalog.mountain(id: $0.mountainId) }
    }

    private var certificateCard: some View {
        let latest = latestConqueredMountain
        return HStack(spacing: 12) {
            if let latest {
                MountainStampSeal(mountain: latest, size: 46, isUnlocked: true, rotation: .degrees(-4))
            } else {
                WildFrogBrandMark(size: 46, cornerRadius: 11)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.value(zh: "登頂證書", en: "Summit Certificate"))
                    .font(.frogRow.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                Text(latest == nil
                     ? AppText.value(zh: "完成打卡後解鎖你的收藏證書", en: "Unlock your collectible certificate after checking in")
                     : AppText.value(zh: "最近征服 \(latest!.nameZh) · 收藏證書", en: "Latest: \(latest!.localizedName) · collectible certificate"))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if latest != nil {
                Button { showCertificateShare = true } label: {
                    Text(AppText.value(zh: "查看", en: "View"))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(FrogTheme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FrogSpace.cardPadding)
        .background(FrogTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }

    private var achievementsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // .wf-section — eyebrow + hairline rule + "View All" chevron
            Button { showAllAchievements = true } label: {
                HStack(spacing: 12) {
                    Text(AppText.value(zh: "成就 · ACHIEVEMENTS", en: "ACHIEVEMENTS"))
                        .font(.frogEyebrow)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(FrogTheme.moss)
                    Rectangle()
                        .fill(FrogTheme.line)
                        .frame(height: 1)
                    Image(systemName: "chevron.right")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.faint)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.value(zh: "查看全部成就", en: "View All Achievements"))

            // .achv — 4-up circular stamp badges
            HStack(spacing: 10) {
                AchievementBadge(title: "Trail", systemImage: "figure.hiking", tint: FrogTheme.moss,
                                 isUnlocked: checkInStore.distinctMountainCount >= 1)
                AchievementBadge(title: "Summit", systemImage: "mountain.2.fill", tint: FrogTheme.moss,
                                 isUnlocked: checkInStore.distinctMountainCount >= 10)
                AchievementBadge(title: "Active", systemImage: "sun.max", tint: FrogTheme.orange,
                                 isUnlocked: checkInStore.totalActiveDays >= 7)
                AchievementBadge(title: "10+", systemImage: "star", tint: FrogTheme.gold,
                                 isUnlocked: checkInStore.totalCheckIns >= 10)
            }
        }
    }

    @MainActor
    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                authService.noteAvatarFailed(AppText.value(zh: "未能讀取頭像相片", en: "Could not read avatar photo"))
                return
            }

            let storedData = avatarThumbnailData(from: data)
            avatarData = storedData
            UserDefaults.standard.set(storedData, forKey: Self.avatarStorageKey)
            authService.noteAvatarUpdated()
        } catch {
            authService.noteAvatarFailed(AppText.value(zh: "頭像更新失敗：\(error.localizedDescription)", en: "Avatar update failed: \(error.localizedDescription)"))
        }
    }

    private func avatarThumbnailData(from data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data),
              let thumbnail = image.wildFrogAvatarJPEGData() else {
            return data
        }
        return thumbnail
        #else
        return data
        #endif
    }

}

// MARK: - Display name editor

private struct DisplayNameEditorSheet: View {
    @Environment(ProfileAuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var name: String

    let fallbackName: String

    init(initialName: String, fallbackName: String) {
        _name = State(initialValue: initialName)
        self.fallbackName = fallbackName
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 24 && !authService.isBusy
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppText.value(zh: "排行榜名稱", en: "Leaderboard Name"))
                        .font(.frogEyebrow)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(FrogTheme.moss)
                    Text(AppText.value(zh: "現在顯示：\(fallbackName)", en: "Currently shown as: \(fallbackName)"))
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }

                TextField(AppText.value(zh: "輸入你的登山名", en: "Enter your trail name"), text: $name)
                    .font(.system(size: 20, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .padding(14)
                    .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(trimmedName.count > 24 ? FrogTheme.orange : FrogTheme.line, lineWidth: 1)
                    )

                HStack {
                    Text("\(trimmedName.count) / 24")
                        .font(.frogMicro)
                        .foregroundStyle(trimmedName.count > 24 ? FrogTheme.orange : FrogTheme.muted)
                    Spacer()
                    if authService.isBusy {
                        ProgressView()
                            .tint(FrogTheme.moss)
                    }
                }

                if !authService.statusMessage.isEmpty {
                    Text(authService.statusMessage)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(FrogSpace.screenPadding)
            .appPageBackground(FrogTheme.warmPaper)
            .localizedNavigationTitle { AppText.value(zh: "更改名稱", en: "Edit Name") }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                        .font(.frogCaption.weight(.semibold))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.value(zh: "儲存", en: "Save")) {
                        Task {
                            await authService.updateDisplayName(trimmedName)
                            if authService.session?.displayName == trimmedName {
                                dismiss()
                            }
                        }
                    }
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(canSave ? FrogTheme.orange : FrogTheme.muted)
                    .disabled(!canSave)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Title picker (稱號)

/// Lets the user equip one of the 稱號 they've unlocked (one per conquered peak)
/// for display on the leaderboard. "唔顯示稱號" clears it.
private struct TitlePickerSheet: View {
    @EnvironmentObject private var checkInStore: CheckInStore
    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""
    @Environment(\.dismiss) private var dismiss

    private var conquered: [Mountain] {
        checkInStore.visitedMountainIds
            .map { MountainCatalog.mountain(id: $0) }
            .sorted { (MountainCatalog.heightRankSortValue(for: $0.id), $0.id) < (MountainCatalog.heightRankSortValue(for: $1.id), $1.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    row(id: "", title: AppText.value(zh: "唔顯示稱號", en: "No title"), subtitle: AppText.value(zh: "排行榜唔顯示稱號", en: "Hide title on leaderboard"), mountain: nil)

                    if conquered.isEmpty {
                        Text(AppText.value(zh: "仲未征服任何山峰，征服一座就解鎖一個稱號。", en: "No peaks conquered yet. Each conquered peak unlocks one title."))
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        ForEach(conquered) { m in
                            row(id: m.id, title: m.localizedUnlockTitle, subtitle: AppText.value(zh: "征服 \(m.nameZh) 解鎖", en: "Unlocked by conquering \(m.localizedName)"), mountain: m)
                        }
                    }
                }
                .padding(FrogSpace.screenPadding)
                .padding(.bottom, 40)
            }
            .appPageBackground(FrogTheme.warmPaper)
            .localizedNavigationTitle { AppText.value(zh: "選擇稱號", en: "Choose Title") }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.value(zh: "完成", en: "Done")) { dismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                }
            }
        }
    }

    private func row(id: String, title: String, subtitle: String, mountain: Mountain?) -> some View {
        let isSelected = equippedTitleId == id
        return Button {
            equippedTitleId = id
            dismiss()
        } label: {
            HStack(spacing: 13) {
                if let mountain {
                    MountainStampSeal(mountain: mountain, size: 44, isUnlocked: true, rotation: .degrees(-3))
                } else {
                    Image(systemName: "nosign")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.frogRow)
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FrogTheme.orange)
                }
            }
            .padding(12)
            .background(
                isSelected ? FrogTheme.orange.opacity(0.08) : FrogTheme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? FrogTheme.orange.opacity(0.5) : FrogTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Guest onboarding

private struct GuestOnboardingView: View {
    let onStart: () -> Void
    @AppStorage(AppText.languagePreferenceKey) private var languageModeRaw = AppLanguageMode.system.rawValue
    @State private var heroMountainId = MountainCatalog.randomCinematicHeroMountainId()

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ScrollView {
                ZStack(alignment: .topLeading) {
                    MountainPhoto(mountain: MountainCatalog.mountain(id: heroMountainId), dimming: 0)
                        .frame(height: proxy.size.height * 0.62 + topInset)

                    LinearGradient(
                        colors: [
                            FrogTheme.forest.opacity(0),
                            FrogTheme.forest.opacity(0.55),
                            FrogTheme.forest.opacity(0.97)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: proxy.size.height * 0.62 + topInset)

                    content(topInset: topInset)
                }
            }
            .background(FrogTheme.forest)
            .ignoresSafeArea(edges: .top)
        }
    }

    private func content(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                LanguageMenuButton(selection: $languageModeRaw)
            }
            .padding(.bottom, 14)

            WildFrogLoginPinLogo(width: 176)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

            Text(AppText.value(zh: "記低你行過的\n每一座山", en: "Record every\npeak you climb"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(AppText.value(zh: "香港 330 座山峰，等你逐個征服、逐個收藏。", en: "330 Hong Kong peaks to conquer, collect and remember."))
                .font(.frogRow)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 10)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 16) {
                ValuePropRow(
                    systemImage: "checkmark.icloud.fill",
                    title: AppText.value(zh: "雲端同步打卡紀錄", en: "Cloud-synced check-ins"),
                    subtitle: AppText.value(zh: "換機都唔會遺失你的山旅足跡", en: "Keep your mountain record across devices")
                )
                ValuePropRow(
                    systemImage: "rosette",
                    title: AppText.value(zh: "解鎖紀念證書", en: "Unlock summit certificates"),
                    subtitle: AppText.value(zh: "完成里程碑即可生成分享證書", en: "Generate shareable certificates after milestones")
                )
                ValuePropRow(
                    systemImage: "chart.bar.fill",
                    title: AppText.value(zh: "加入排行榜", en: "Join the leaderboard"),
                    subtitle: AppText.value(zh: "同其他山友比拼打卡里程", en: "Compare progress with other hikers")
                )
            }
            .padding(.bottom, 28)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 17, weight: .black))
                    Text(AppText.value(zh: "登入 / 開始記錄", en: "Sign In / Start Recording"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: FrogTheme.orange.opacity(0.4), radius: 14, y: 6)
            }
            .buttonStyle(.plain)

            Text(AppText.value(zh: "免費 · 幾秒搞掂", en: "Free · Takes seconds"))
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, topInset + 36)
        .padding(.bottom, 130)
    }
}

private struct LanguageMenuButton: View {
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(AppLanguageMode.allCases) { mode in
                Button {
                    selection = mode.rawValue
                } label: {
                    Label(mode.title, systemImage: selection == mode.rawValue ? "checkmark" : "globe")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .bold))
                Text((AppLanguageMode(rawValue: selection) ?? .system).shortTitle)
                    .font(.frogCaption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.white.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.value(zh: "選擇語言", en: "Choose Language"))
    }
}

private struct ValuePropRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.frogCaption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Passport components

private struct PassportMiniMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.frogNum(16, weight: .semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct CompletionRing: View {
    let value: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: value)
                .stroke(FrogTheme.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(label)
                    .font(.frogNum(16, weight: .semibold))
                Text("COMPLETE")
                    .font(.frogNum(6.5, weight: .semibold))
                    .tracking(0.65)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 66, height: 66)
    }
}

private struct AchievementBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = FrogTheme.forest
    var isUnlocked: Bool = true

    var body: some View {
        VStack(spacing: 7) {
            StampBadge(systemImage: systemImage, tint: tint, isUnlocked: isUnlocked, size: 56)

            Text(title)
                .font(.frogNum(11, weight: .semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Vintage "passport stamp" badge that matches WildFrogStampSheet — a double-ring
/// engraved frame on cream paper, used so achievements share the stamp visual language.
struct StampBadge: View {
    let systemImage: String
    var tint: Color = FrogTheme.forest
    var isUnlocked: Bool = true
    var size: CGFloat = 52

    private var frameColor: Color { isUnlocked ? tint : FrogTheme.muted }

    var body: some View {
        ZStack {
            Circle()
                .fill(isUnlocked ? FrogTheme.passport : Color.black.opacity(0.04))

            Circle()
                .stroke(frameColor.opacity(isUnlocked ? 0.85 : 0.4), lineWidth: 2)
                .padding(2)

            Circle()
                .stroke(
                    frameColor.opacity(isUnlocked ? 0.5 : 0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                )
                .padding(6)

            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(frameColor)
        }
        .frame(width: size, height: size)
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

// MARK: - Full passport stamp wall

/// All 330 peak stamps grouped into region sections with sticky headers — the
/// "全部 330" closure from the Peak Passport panel. Locked stamps render greyed.
struct FullPassportStampsView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private var unlockedMountainIds: Set<String> { checkInStore.visitedMountainIds }

    private var unlockedCount: Int {
        MountainCatalog.mountains.filter { unlockedMountainIds.contains($0.id) }.count
    }

    private var grouped: [(region: String, peaks: [Mountain])] {
        Dictionary(grouping: MountainCatalog.mountains, by: { $0.region })
            .map { (region: $0.key, peaks: $0.value.sorted {
                MountainCatalog.heightRankSortValue(for: $0.id) < MountainCatalog.heightRankSortValue(for: $1.id)
            }) }
            .sorted { $0.peaks.count > $1.peaks.count }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 5)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(grouped, id: \.region) { group in
                    Section {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(group.peaks) { mountain in
                                NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                                    MountainStampSeal(
                                        mountain: mountain,
                                        size: 52,
                                        isUnlocked: unlockedMountainIds.contains(mountain.id),
                                        rotation: .degrees(0)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                    } header: {
                        HStack {
                            Text(group.region)
                                .font(.frogEyebrow)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(FrogTheme.moss)
                            Spacer()
                            Text("\(group.peaks.filter { unlockedMountainIds.contains($0.id) }.count) / \(group.peaks.count)")
                                .font(.frogNum(12, weight: .semibold))
                                .foregroundStyle(FrogTheme.faint)
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 9)
                        .background(FrogTheme.warmPaper)
                    }
                }
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .appPageBackground(FrogTheme.warmPaper)
        .localizedNavigationTitle { "Peak Passport · \(unlockedCount)/\(MountainCatalog.catalogCount)" }
        .nativeInlineTitle()
    }
}

private struct ProfileAvatarContent: View {
    let avatarData: Data

    var body: some View {
        if let profileImage {
            profileImage
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [FrogTheme.orange, FrogTheme.moss],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "person.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var profileImage: Image? {
        guard !avatarData.isEmpty else { return nil }

        #if canImport(UIKit)
        guard let uiImage = UIImage(data: avatarData) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: avatarData) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
private extension UIImage {
    func wildFrogAvatarJPEGData(maxPixel: CGFloat = 520) -> Data? {
        let longestSide = max(size.width, size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, maxPixel / longestSide)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.jpegData(withCompressionQuality: 0.82) { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
#endif

#Preview("Guest") {
    NavigationStack {
        ProfileView()
    }
    .environment(ProfileAuthService(activateFirebase: false))
}
