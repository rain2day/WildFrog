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
    @State private var renderedCertificate: UIImage?

    init() {
        let storedAvatar = UserDefaults.standard.data(forKey: Self.avatarStorageKey) ?? Data()
        _avatarData = State(initialValue: storedAvatar)
    }

    private var checkedMountains: [Mountain] {
        MountainCatalog.mountains.filter { $0.checkIns > 0 }
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
        checkedMountains.first ?? MountainCatalog.mountain(id: "lion-rock")
    }

    /// Subtitle for the signed-in account panel. Never shows a "not signed in"
    /// string while a session exists — falls back to the account identifier so
    /// the UI can't contradict the signed-in header.
    private var accountStatusMessage: String {
        guard let session = authService.session else {
            return authService.statusMessage
        }

        let raw = authService.statusMessage
        let staleStates = ["未登入", "已登出", "已回到訪客模式"]
        if !raw.isEmpty, !staleStates.contains(raw) {
            return raw
        }

        if let email = session.email, !email.isEmpty {
            return "已登入 · \(email)"
        }
        if let phone = session.phoneNumber, !phone.isEmpty {
            return "已登入 · \(phone)"
        }
        return "已以\(session.providerLabel)登入，紀錄已雲端同步。"
    }

    var body: some View {
        Group {
            if authService.isSignedIn {
                signedInProfile
            } else {
                GuestOnboardingView(onStart: { showProviderPicker = true })
            }
        }
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
        .sheet(isPresented: $showCertificateShare, onDismiss: { renderedCertificate = nil }) {
            CertificateShareSheet(
                mountainCount: checkInStore.distinctMountainCount,
                onDismiss: { showCertificateShare = false }
            )
            .environmentObject(checkInStore)
        }
        .onChange(of: selectedAvatar) { _, item in
            Task {
                await loadAvatar(from: item)
            }
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
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                profileHero
                peakPassportCard
                recentCheckInCard
                certificateCard
                achievementsPanel
                accountPanel
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(FrogTheme.passport)
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

    private var profileHero: some View {
        let currentAvatarData = avatarData

        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: "sunset-peak"), dimming: 0.5)
                .overlay {
                    LinearGradient(
                        colors: [FrogTheme.forest.opacity(0.25), FrogTheme.forest.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        WildFrogBrandMark(size: 30, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("WILDFROG")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text("PEAK PASSPORT")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    syncChip
                }

                HStack(alignment: .center, spacing: 15) {
                    PhotosPicker(selection: $selectedAvatar, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarContent(avatarData: currentAvatarData)
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(FrogTheme.orange)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("更換頭像")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(authService.profileLine)
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let providerLabel = authService.session?.providerLabel {
                            Text("以 \(providerLabel) 登入")
                                .font(.frogCaption)
                                .foregroundStyle(.white.opacity(0.74))
                        }

                        HStack(spacing: 14) {
                            PassportMiniMetric(value: "\(checkInStore.totalCheckIns)", label: "打卡")
                            PassportMiniMetric(value: "\(checkInStore.distinctMountainCount)", label: "山峰")
                            PassportMiniMetric(value: "\(checkInStore.currentStreak)", label: "連續日")
                        }
                    }

                    Spacer()

                    CompletionRing(value: completionRatio, label: completionPercentText)
                }
            }
            .padding(18)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 16, y: 8)
    }

    private var syncChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11, weight: .black))
            Text("已雲端同步")
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FrogTheme.moss.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
    }

    private var peakPassportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Peak Passport", systemImage: "mountain.2.circle")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Text("\(checkInStore.distinctMountainCount) / \(MountainCatalog.catalogCount) Peaks")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.orange)
            }

            Image("WildFrogStampSheet")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(FrogSpace.cardPadding)
        .background(FrogTheme.passport)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FrogTheme.forest.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var recentCheckInCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recent Check-in", systemImage: "mountain.2.fill")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Text("View All")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.orange)
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
                        Text("\(recentMountain.height)m · \(recentMountain.region) · \(recentMountain.checkIns) 次")
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

    private var certificateCard: some View {
        HStack(spacing: 12) {
            Image("WildFrogBrandMark")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(0.82)

            VStack(alignment: .leading, spacing: 4) {
                Text("Peak Explorer Certificate")
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.forest)
                Text("You've completed \(checkInStore.distinctMountainCount) Hong Kong peaks.")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer()

            Button { showCertificateShare = true } label: {
                Text("VIEW & SHARE")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(FrogTheme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(FrogSpace.cardPadding)
        .background(Color(red: 247 / 255, green: 240 / 255, blue: 210 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var achievementsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Achievements", systemImage: "trophy.fill")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Button { showAllAchievements = true } label: {
                    Text("View All")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.orange)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                AchievementBadge(title: "Trail", systemImage: "figure.hiking", tint: FrogTheme.moss)
                AchievementBadge(title: "Summit", systemImage: "mountain.2.fill", tint: FrogTheme.forest)
                AchievementBadge(title: "Sunrise", systemImage: "sun.max.fill", tint: FrogTheme.orange)
                AchievementBadge(title: "10+", systemImage: "checkmark.seal.fill", tint: FrogTheme.gold)
            }
        }
    }

    private var accountPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FrogTheme.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(authService.session?.statusTitle ?? "已登入")
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.ink)
                    Text(accountStatusMessage)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Button("登出") {
                    authService.signOut()
                }
                .font(.caption.weight(.black))
                .foregroundStyle(FrogTheme.orange)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
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

// MARK: - Guest onboarding

private struct GuestOnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ScrollView {
                ZStack(alignment: .bottom) {
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

                    content
                }
            }
            .background(FrogTheme.forest)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var content: some View {
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
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
        }
    }
}

private struct CompletionRing: View {
    let value: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 6)
            Circle()
                .trim(from: 0, to: value)
                .stroke(FrogTheme.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text("COMPLETE")
                    .font(.system(size: 6.5, weight: .black))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 68, height: 68)
    }
}

private struct AchievementBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = FrogTheme.forest
    var isUnlocked: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            StampBadge(systemImage: systemImage, tint: tint, isUnlocked: isUnlocked, size: 52)

            Text(title)
                .font(.frogMicro.weight(.bold))
                .foregroundStyle(isUnlocked ? FrogTheme.forest : FrogTheme.muted)
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
