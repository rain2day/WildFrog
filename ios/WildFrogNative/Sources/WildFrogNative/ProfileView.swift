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
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarData: Data
    @State private var activeSheet: ProfileAuthSheet?
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                profileHero
                peakPassportCard
                recentCheckInCard
                certificateCard
                achievementsPanel
                if !authService.isSignedIn {
                    signInPanel
                }
                accountPanel
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .hiddenNavigationBar()
        .background(FrogTheme.passport)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .email:
                EmailAuthSheet()
                    .presentationDetents([.medium])
            case .phone:
                PhoneAuthSheet()
                    .presentationDetents([.medium])
            }
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
    }

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
                    VStack(alignment: .leading, spacing: 4) {
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
                    }

                    Spacer()

                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(alignment: .center, spacing: 15) {
                    PhotosPicker(selection: $selectedAvatar, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarContent(avatarData: currentAvatarData)
                                .frame(width: 82, height: 82)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))

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
                        Text(authService.isSignedIn ? authService.profileLine : "FrogWalker")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(authService.isSignedIn ? "Keep exploring" : "Guest passport")
                            .font(.frogCaption)
                            .foregroundStyle(.white.opacity(0.74))

                        HStack(spacing: 12) {
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
        .frame(height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 16, y: 8)
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
                AchievementBadge(title: "Summit", systemImage: "mountain.2.fill", tint: FrogTheme.gold)
                AchievementBadge(title: "Photo", systemImage: "camera.fill", tint: FrogTheme.slate)
                AchievementBadge(title: "10+", systemImage: "checkmark.seal.fill", tint: FrogTheme.orange)
            }
        }
    }

    private var signInPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("登入")
                .font(.frogTitle)
                .foregroundStyle(FrogTheme.forest)

            VStack(spacing: 10) {
                AuthProviderButton(
                    title: "Google",
                    subtitle: "用 Google 帳戶登入",
                    mark: .letter("G"),
                    tint: Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
                ) {
                    Task {
                        await authService.signInWithGoogle()
                    }
                }

                AuthProviderButton(
                    title: "Apple ID",
                    subtitle: "用 Apple ID 登入",
                    mark: .systemImage("apple.logo"),
                    tint: FrogTheme.ink
                ) {
                    authService.signInWithApple()
                }

                AuthProviderButton(
                    title: "電郵",
                    subtitle: "Email + 密碼",
                    mark: .systemImage("envelope.fill"),
                    tint: FrogTheme.orange
                ) {
                    activeSheet = .email
                }

                AuthProviderButton(
                    title: "電話號碼",
                    subtitle: "SMS 驗證碼",
                    mark: .systemImage("phone.fill"),
                    tint: FrogTheme.moss
                ) {
                    activeSheet = .phone
                }
            }
            .disabled(authService.isBusy)
            .opacity(authService.isBusy ? 0.58 : 1)
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private var accountPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: authService.isSignedIn ? "checkmark.shield.fill" : "lock.open.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(authService.isSignedIn ? FrogTheme.orange : FrogTheme.muted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(authService.session?.statusTitle ?? "訪客模式")
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.ink)
                    Text(authService.statusMessage)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                if authService.isSignedIn {
                    Button("登出") {
                        authService.signOut()
                    }
                    .font(.caption.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
                }
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

private struct PassportMiniMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 7, weight: .bold))
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
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(FrogTheme.forest.opacity(0.18), lineWidth: 1))

            Text(title)
                .font(.frogMicro.weight(.bold))
                .foregroundStyle(FrogTheme.forest)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum ProfileAuthSheet: Identifiable {
    case email
    case phone

    var id: String {
        switch self {
        case .email: "email"
        case .phone: "phone"
        }
    }
}

private enum AuthMark {
    case letter(String)
    case systemImage(String)
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

private struct AuthProviderButton: View {
    let title: String
    let subtitle: String
    let mark: AuthMark
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                markView
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(FrogTheme.muted)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .letter(let value):
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

private struct EmailAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .wildFrogEmailInput()
                    SecureField("密碼", text: $password)
                }

                Section {
                    Button("登入") {
                        Task {
                            await complete(.signIn)
                        }
                    }
                    .disabled(!canSubmit || authService.isBusy)

                    Button("建立帳戶") {
                        Task {
                            await complete(.createAccount)
                        }
                    }
                    .disabled(!canSubmit || authService.isBusy)
                }
            }
            .navigationTitle("Email 登入")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") && password.count >= 6
    }

    private func complete(_ mode: EmailAuthMode) async {
        switch mode {
        case .signIn:
            await authService.signInWithEmail(email: email, password: password)
        case .createAccount:
            await authService.createEmailAccount(email: email, password: password)
        }

        if authService.isSignedIn {
            dismiss()
        }
    }
}

private struct PhoneAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService
    @State private var phone = "+852 "
    @State private var code = ""
    @State private var codeSent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("電話號碼", text: $phone)
                        .wildFrogPhoneInput()

                    if codeSent {
                        TextField("6 位驗證碼", text: $code)
                            .wildFrogNumberInput()
                    }
                }

                Section {
                    Button(codeSent ? "完成登入" : "發送驗證碼") {
                        Task {
                            if codeSent {
                                let signedIn = await authService.confirmPhoneCode(code)
                                if signedIn {
                                    dismiss()
                                }
                            } else {
                                codeSent = await authService.sendPhoneCode(phoneNumber: phone)
                            }
                        }
                    }
                    .disabled(!canSubmit || authService.isBusy)
                } footer: {
                    Text("使用電話登入可能會收到 SMS，費用依電訊商而定。")
                }
            }
            .navigationTitle("電話登入")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        if codeSent {
            return code.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
        }

        return phone.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }
}

private enum EmailAuthMode {
    case signIn
    case createAccount
}

private extension View {
    @ViewBuilder
    func wildFrogEmailInput() -> some View {
        #if os(iOS)
        self
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func wildFrogPhoneInput() -> some View {
        #if os(iOS)
        self
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
        #else
        self
        #endif
    }

    @ViewBuilder
    func wildFrogNumberInput() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
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

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(ProfileAuthService(activateFirebase: false))
}
