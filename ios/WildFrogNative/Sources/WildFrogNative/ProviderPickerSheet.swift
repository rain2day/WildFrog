import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Bottom sheet that collects all four sign-in providers in one focused place.
/// Each provider re-uses the existing `ProfileAuthService` API; the email/phone
/// flows are pushed onto an inner navigation stack so the picker stays in context.
/// The sheet dismisses itself automatically once the user becomes signed in.
struct ProviderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService

    @State private var route: ProviderRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(spacing: 10) {
                        AuthProviderButton(
                            title: "Google",
                            subtitle: AppText.value(zh: "用 Google 帳戶登入", en: "Sign in with Google"),
                            mark: .letter("G"),
                            tint: Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
                        ) {
                            Task { await authService.signInWithGoogle() }
                        }

                        AuthProviderButton(
                            title: "Apple ID",
                            subtitle: AppText.value(zh: "用 Apple ID 登入", en: "Sign in with Apple ID"),
                            mark: .systemImage("apple.logo"),
                            tint: FrogTheme.ink
                        ) {
                            authService.signInWithApple()
                        }

                        AuthProviderButton(
                            title: AppText.value(zh: "電郵", en: "Email"),
                            subtitle: AppText.value(zh: "Email + 密碼", en: "Email + password"),
                            mark: .systemImage("envelope.fill"),
                            tint: FrogTheme.orange
                        ) {
                            route = .email
                        }

                        AuthProviderButton(
                            title: AppText.value(zh: "電話號碼", en: "Phone"),
                            subtitle: AppText.value(zh: "SMS 驗證碼", en: "SMS verification code"),
                            mark: .systemImage("phone.fill"),
                            tint: FrogTheme.moss
                        ) {
                            route = .phone
                        }
                    }
                    .disabled(authService.isBusy)
                    .opacity(authService.isBusy ? 0.58 : 1)

                    if authService.isBusy {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(AppText.value(zh: "登入中…", en: "Signing in..."))
                                .font(.frogCaption.weight(.semibold))
                                .foregroundStyle(FrogTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Label(AppText.value(zh: "WildFrog 唔會公開你的帳戶資料", en: "WildFrog never publishes your account details"), systemImage: "lock.fill")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(maxWidth: .infinity)

                    WildFrogLegalConsentFooter()
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(FrogTheme.passport)
            .navigationDestination(item: $route) { route in
                switch route {
                case .email:
                    EmailAuthSheet()
                case .phone:
                    PhoneAuthSheet()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                }
            }
            .nativeInlineTitle()
        }
        .onChange(of: authService.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 12) {
            WildFrogLoginLogo(width: 188)
                .shadow(color: FrogTheme.warmShadow.opacity(0.12), radius: 12, y: 5)

            VStack(alignment: .center, spacing: 4) {
                Text(AppText.value(zh: "登入或建立帳戶", en: "Sign In or Create Account"))
                    .font(.frogDisplay)
                    .foregroundStyle(FrogTheme.forest)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(AppText.value(zh: "揀一個方式開始記錄你的山旅", en: "Choose a sign-in method to start saving your hikes"))
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum ProviderRoute: String, Identifiable, Hashable {
    case email
    case phone

    var id: String { rawValue }
}

private enum AuthMark {
    case letter(String)
    case systemImage(String)
}

private struct AuthProviderButton: View {
    let title: String
    let subtitle: String
    let mark: AuthMark
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                markView
                    .frame(width: 42, height: 42)
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
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

private struct EmailAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var hasSubmitted = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .wildFrogEmailInput()
                SecureField(AppText.value(zh: "密碼", en: "Password"), text: $password)
            }

            Section {
                Button(AppText.value(zh: "登入", en: "Sign In")) {
                    Task { await complete(.signIn) }
                }
                .disabled(!canSubmit || authService.isBusy)

                Button(AppText.value(zh: "建立帳戶", en: "Create Account")) {
                    Task { await complete(.createAccount) }
                }
                .disabled(!canSubmit || authService.isBusy)
            } footer: {
                WildFrogLegalConsentFooter(
                    statusMessage: hasSubmitted && !authService.isSignedIn ? authService.statusMessage : nil
                )
            }
        }
        .localizedNavigationTitle { AppText.value(zh: "Email 登入", en: "Email Sign In") }
        .nativeInlineTitle()
    }

    private var canSubmit: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") && password.count >= 6
    }

    private func complete(_ mode: EmailAuthMode) async {
        hasSubmitted = true

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
        Form {
            Section {
                TextField(AppText.value(zh: "電話號碼", en: "Phone number"), text: $phone)
                    .wildFrogPhoneInput()

                if codeSent {
                    TextField(AppText.value(zh: "6 位驗證碼", en: "6-digit code"), text: $code)
                        .wildFrogNumberInput()
                }
            }

            Section {
                Button(codeSent ? AppText.value(zh: "完成登入", en: "Finish Sign In") : AppText.value(zh: "發送驗證碼", en: "Send Code")) {
                    Task {
                        if codeSent {
                            let signedIn = await authService.confirmPhoneCode(code)
                            if signedIn { dismiss() }
                        } else {
                            codeSent = await authService.sendPhoneCode(phoneNumber: phone)
                        }
                    }
                }
                .disabled(!canSubmit || authService.isBusy)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.value(zh: "使用電話登入可能會收到 SMS，費用依電訊商而定。", en: "Phone sign-in may send SMS messages. Carrier fees may apply."))
                    WildFrogLegalConsentFooter()
                }
            }
        }
        .localizedNavigationTitle { AppText.value(zh: "電話登入", en: "Phone Sign In") }
        .nativeInlineTitle()
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

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ProviderPickerSheet()
                .environment(ProfileAuthService(activateFirebase: false))
        }
}
