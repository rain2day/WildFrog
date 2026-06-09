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
    #if DEBUG
    @State private var showMockPicker = false
    #endif
    @State private var avatarData: Data
    @State private var showProviderPicker = false
    @State private var showCertificateShare = false
    @State private var showAllAchievements = false
    @State private var showDeleteAccount = false

    init() {
        let storedAvatar = UserDefaults.standard.data(forKey: Self.avatarStorageKey) ?? Data()
        _avatarData = State(initialValue: storedAvatar)
    }

    @AppStorage("wildfrog.profile.equippedTitleId") private var equippedTitleId = ""
    @State private var showTitlePicker = false

    /// The 稱號 the user has equipped — only valid while it's still a peak they've
    /// conquered (guards against an equipped title from data that was since reset).
    private var equippedTitle: String? {
        guard !equippedTitleId.isEmpty,
              checkInStore.visitedMountainIds.contains(equippedTitleId) else { return nil }
        return MountainCatalog.mountain(id: equippedTitleId).unlockTitle
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

    /// Hero image source — the user's latest peak, but only when it has artwork
    /// (some catalog stubs have no image); otherwise a guaranteed-image default.
    private var heroMountain: Mountain {
        recentMountain.imageName.isEmpty ? MountainCatalog.mountain(id: "tai-mo-shan") : recentMountain
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllAchievements) {
            NavigationStack {
                AllAchievementsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showAllAchievements = false }
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
        .alert("刪除帳戶？", isPresented: $showDeleteAccount) {
            Button("永久刪除", role: .destructive) {
                Task { await authService.deleteAccount() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此動作無法復原。你的帳戶同雲端打卡紀錄會被永久刪除。")
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            mockFloatingButton
        }
        .sheet(isPresented: $showMockPicker) {
            MockLocationPickerSheet()
        }
        #endif
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

    #if DEBUG
    // MARK: - Developer location override (DEBUG builds only)

    private var mockFloatingButton: some View {
        Button {
            showMockPicker = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: locationManager.mockCoordinate == nil ? "hammer.fill" : "location.fill.viewfinder")
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
        .accessibilityLabel("開發者模擬位置")
    }

    private var mockButtonLabel: String {
        guard let mock = locationManager.mockCoordinate else { return "模擬位置" }
        return "模擬中 · \(mockLabel(for: mock))"
    }

    private func mockLabel(for coordinate: CLLocationCoordinate2D) -> String {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = MountainCatalog.mountains.min {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: here) <
            CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude).distance(from: here)
        }
        if let nearest {
            return "\(nearest.nameZh) · \(nearest.height)m"
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
                                Text(mountain.nameZh)
                                    .font(.frogRow.weight(.bold))
                                    .foregroundStyle(FrogTheme.ink)
                                Text("\(mountain.nameEn) · \(mountain.height)m · \(mountain.region)")
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
                .searchable(text: $search, prompt: "搜尋山峰名稱")
                .navigationTitle("傳送到山峰")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    if locationManager.mockCoordinate != nil {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("關閉模擬", role: .destructive) {
                                locationManager.mockCoordinate = nil
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    #endif

    private func profileHero(topInset: CGFloat) -> some View {
        let currentAvatarData = avatarData

        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: heroMountain, dimming: 0)

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
                    .accessibilityLabel("更換頭像")

                    // .info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authService.profileLine)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let providerLabel = authService.session?.providerLabel {
                            Text("以 \(providerLabel) 登入")
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
                            PassportMiniMetric(value: "\(checkInStore.totalCheckIns)", label: "打卡")
                            PassportMiniMetric(value: "\(checkInStore.distinctMountainCount)", label: "山峰")
                            PassportMiniMetric(value: "\(checkInStore.currentStreak)", label: "連續日")
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
            Text("雲端帳戶")
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
            Button {
                authService.signOut()
            } label: {
                Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) {
                showDeleteAccount = true
            } label: {
                Label("刪除帳戶", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 4, y: 1)
        }
        .accessibilityLabel("帳戶選項")
    }

    /// 稱號: the title equipped for the leaderboard, chosen from conquered peaks.
    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Text("我的稱號 · TITLE")
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
                    Text("排行榜顯示")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text(equippedTitle ?? "未設定稱號")
                        .font(.title3.weight(.black))
                        .foregroundStyle(equippedTitle == nil ? FrogTheme.muted : FrogTheme.forest)
                }
                Spacer(minLength: 0)
                Button { showTitlePicker = true } label: {
                    Text(equippedTitle == nil ? "選擇" : "更換")
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(FrogTheme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("已征服 \(checkInStore.distinctMountainCount) 座山 · 每征服一座解鎖一個稱號")
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

            NavigationLink {
                FullPassportStampsView(unlockedMountainIds: checkInStore.visitedMountainIds)
            } label: {
                HStack(spacing: 5) {
                    Text("全部 \(MountainCatalog.catalogCount)")
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
                Text("最近打卡 · RECENT")
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)
                Rectangle()
                    .fill(FrogTheme.line)
                    .frame(height: 1)
            }

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
                        Text(recentMountain.displayName)
                            .font(.frogTitle)
                        Text("\(recentMountain.height)m · \(recentMountain.region) · \(checkInStore.count(for: recentMountain.id)) 次")
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
                Text("登頂證書")
                    .font(.frogRow.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                Text(latest == nil
                     ? "完成打卡後解鎖你的收藏證書"
                     : "最近征服 \(latest!.nameZh) · 收藏證書")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if latest != nil {
                Button { showCertificateShare = true } label: {
                    Text("查看")
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
                    Text("成就 · ACHIEVEMENTS")
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
            .accessibilityLabel("查看全部成就")

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
                authService.noteAvatarFailed("未能讀取頭像相片")
                return
            }

            let storedData = avatarThumbnailData(from: data)
            avatarData = storedData
            UserDefaults.standard.set(storedData, forKey: Self.avatarStorageKey)
            authService.noteAvatarUpdated()
        } catch {
            authService.noteAvatarFailed("頭像更新失敗：\(error.localizedDescription)")
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
            .sorted { ($0.topRank ?? .max, $0.id) < ($1.topRank ?? .max, $1.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    row(id: "", title: "唔顯示稱號", subtitle: "排行榜唔顯示稱號", mountain: nil)

                    if conquered.isEmpty {
                        Text("仲未征服任何山峰，征服一座就解鎖一個稱號。")
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        ForEach(conquered) { m in
                            row(id: m.id, title: m.unlockTitle, subtitle: "征服 \(m.nameZh) 解鎖", mountain: m)
                        }
                    }
                }
                .padding(FrogSpace.screenPadding)
                .padding(.bottom, 40)
            }
            .appPageBackground(FrogTheme.warmPaper)
            .navigationTitle("選擇稱號")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
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

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ScrollView {
                ZStack(alignment: .topLeading) {
                    MountainPhoto(mountain: MountainCatalog.mountain(id: "sunset-peak"), dimming: 0)
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
            HStack(spacing: 10) {
                WildFrogBrandMark(size: 40, cornerRadius: 11)
                Text("WILDFROG")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 18)

            Text("記低你行過的\n每一座山")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("香港 330 座山峰，等你逐個征服、逐個收藏。")
                .font(.frogRow)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 10)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 16) {
                ValuePropRow(
                    systemImage: "checkmark.icloud.fill",
                    title: "雲端同步打卡紀錄",
                    subtitle: "換機都唔會遺失你的山旅足跡"
                )
                ValuePropRow(
                    systemImage: "rosette",
                    title: "解鎖紀念證書",
                    subtitle: "完成里程碑即可生成分享證書"
                )
                ValuePropRow(
                    systemImage: "chart.bar.fill",
                    title: "加入排行榜",
                    subtitle: "同其他山友比拼打卡里程"
                )
            }
            .padding(.bottom, 28)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 17, weight: .black))
                    Text("登入 / 開始記錄")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: FrogTheme.orange.opacity(0.4), radius: 14, y: 6)
            }
            .buttonStyle(.plain)

            Text("免費 · 幾秒搞掂")
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
    let unlockedMountainIds: Set<String>

    private var unlockedCount: Int {
        MountainCatalog.mountains.filter { unlockedMountainIds.contains($0.id) }.count
    }

    private var grouped: [(region: String, peaks: [Mountain])] {
        Dictionary(grouping: MountainCatalog.mountains, by: { $0.region })
            .map { (region: $0.key, peaks: $0.value.sorted { ($0.topRank ?? 9999) < ($1.topRank ?? 9999) }) }
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
        .navigationTitle("Peak Passport · \(unlockedCount)/\(MountainCatalog.catalogCount)")
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
