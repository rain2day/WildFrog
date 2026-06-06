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
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarData: Data
    @State private var activeSheet: ProfileAuthSheet?

    init() {
        let storedAvatar = UserDefaults.standard.data(forKey: Self.avatarStorageKey) ?? Data()
        _avatarData = State(initialValue: storedAvatar)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileHeader
                statsStrip
                signInPanel
                accountPanel
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .navigationTitle("個人")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
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
        .onChange(of: selectedAvatar) { _, item in
            Task {
                await loadAvatar(from: item)
            }
        }
    }

    private var profileHeader: some View {
        let currentAvatarData = avatarData

        return HStack(alignment: .center, spacing: 14) {
            PhotosPicker(selection: $selectedAvatar, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatarContent(avatarData: currentAvatarData)
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(FrogTheme.orange)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更換頭像")

            VStack(alignment: .leading, spacing: 6) {
                Text("個人")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.ink)
                Text(authService.profileLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 10) {
            StatCard(value: "86", label: "有效打卡", systemImage: "checkmark.seal")
            StatCard(value: "14", label: "已到訪山峰", systemImage: "mountain.2")
            StatCard(value: "#18", label: "我的排名", systemImage: "trophy")
        }
    }

    private var signInPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("登入")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.ink)

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
        .padding(14)
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
                        .font(.headline.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                    Text(authService.statusMessage)
                        .font(.caption.weight(.semibold))
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
        .padding(14)
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
