import Foundation
import Observation
import Security
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(FirebaseAuth)
@preconcurrency import FirebaseAuth
#endif
#if canImport(FirebaseCore)
@preconcurrency import FirebaseCore
#endif
#if canImport(GoogleSignIn)
@preconcurrency import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

enum WildFrogFirebaseBootstrap {
    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    @discardableResult
    static func handleOpenURL(_ url: URL) -> Bool {
        var handled = false

        #if canImport(GoogleSignIn)
        handled = GIDSignIn.sharedInstance.handle(url) || handled
        #endif

        #if os(iOS) && canImport(FirebaseAuth)
        handled = Auth.auth().canHandle(url) || handled
        #endif

        return handled
    }

    static func setAPNSToken(_ deviceToken: Data) {
        #if os(iOS) && canImport(FirebaseAuth)
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
        #endif
    }

    @discardableResult
    static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        #if os(iOS) && canImport(FirebaseAuth)
        Auth.auth().canHandleNotification(userInfo)
        #else
        false
        #endif
    }

    static var googleClientID: String? {
        #if canImport(FirebaseCore)
        FirebaseApp.app()?.options.clientID ?? googleServiceInfoValue(for: "CLIENT_ID")
        #else
        googleServiceInfoValue(for: "CLIENT_ID")
        #endif
    }

    static var googleReversedClientID: String? {
        googleServiceInfoValue(for: "REVERSED_CLIENT_ID")
    }

    static func hasURLScheme(_ scheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        return urlTypes.contains { urlType in
            guard let schemes = urlType["CFBundleURLSchemes"] as? [String] else {
                return false
            }

            return schemes.contains(scheme)
        }
    }

    private static func googleServiceInfoValue(for key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Any],
              let value = values[key] as? String,
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

struct ProfileAuthSession: Equatable {
    let uid: String
    let email: String?
    let phoneNumber: String?
    let displayName: String?
    let providerLabel: String

    var isReviewerAccount: Bool {
        WildFrogReviewerAccess.isReviewerEmail(email)
    }

    var profileLine: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }

        if let email, !email.isEmpty {
            return email
        }

        if let phoneNumber, !phoneNumber.isEmpty {
            return phoneNumber
        }

        return "Firebase UID \(uid.prefix(8))"
    }

    var statusTitle: String {
        "\(providerLabel) 已登入"
    }
}

enum ProfileExternalAuthProvider {
    case google
    case apple
    case phone
}

enum WildFrogReviewerAccess {
    static let accountEmail = "rainsdayjp+wildfrog-asc-20260610@gmail.com"

    static func isReviewerEmail(_ email: String?) -> Bool {
        guard let email else { return false }
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == accountEmail
    }
}

@MainActor
@Observable
final class ProfileAuthService {
    private(set) var session: ProfileAuthSession?
    private(set) var statusMessage = "未登入"
    private(set) var isBusy = false

    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    #endif
    #if canImport(AuthenticationServices) && canImport(FirebaseAuth)
    private var appleSignInCoordinator: AppleSignInCoordinator?
    #endif
    private var phoneVerificationID: String?
    private var phoneVerificationNumber: String?
    private var isActivated = false

    init(activateFirebase: Bool = true) {
        guard activateFirebase else { return }
        activate()
    }

    func activate() {
        guard !isActivated else { return }
        isActivated = true

        WildFrogFirebaseBootstrap.configureIfNeeded()
        observeAuthState()
    }

    var isSignedIn: Bool {
        session != nil
    }

    var profileLine: String {
        session?.profileLine ?? "用頭像同登入同步你的登山紀錄"
    }

    var canUseReviewerTools: Bool {
        session?.isReviewerAccount == true
    }

    func signInWithEmail(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(FirebaseAuth)
        await runFirebaseAuthAction(successMessage: "已用 Email 登入 Firebase。") { completion in
            Auth.auth().signIn(withEmail: normalizedEmail, password: password, completion: completion)
        }
        #else
        markFirebaseAuthMissing()
        #endif
    }

    func createEmailAccount(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(FirebaseAuth)
        await runFirebaseAuthAction(successMessage: "已建立 Firebase Email 帳戶並登入。") { completion in
            Auth.auth().createUser(withEmail: normalizedEmail, password: password, completion: completion)
        }
        #else
        markFirebaseAuthMissing()
        #endif
    }

    func signInWithGoogle() async {
        #if canImport(UIKit) && canImport(GoogleSignIn) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard let clientID = WildFrogFirebaseBootstrap.googleClientID else {
            statusMessage = "Google 登入未能開始：現有 GoogleService-Info.plist 缺少 CLIENT_ID。請在 Firebase Console enable Google provider 後重新下載 plist。"
            return
        }

        guard let reversedClientID = WildFrogFirebaseBootstrap.googleReversedClientID else {
            statusMessage = "Google 登入未能開始：現有 GoogleService-Info.plist 缺少 REVERSED_CLIENT_ID。請重新下載已啟用 Google provider 的 plist。"
            return
        }

        guard WildFrogFirebaseBootstrap.hasURLScheme(reversedClientID) else {
            statusMessage = "Google 登入未能開始：Info.plist 未加入 Google URL scheme \(reversedClientID)。"
            return
        }

        guard let presentingViewController = UIApplication.shared.wildFrogTopViewController else {
            statusMessage = "Google 登入未能開始：找不到目前畫面。"
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let result {
                        continuation.resume(returning: result)
                        return
                    }

                    continuation.resume(throwing: ProfileAuthError.emptyAuthResult)
                }
            }

            guard let idToken = result.user.idToken?.tokenString else {
                statusMessage = "Google 登入失敗：Google 沒有回傳 ID token。"
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            await signIn(with: credential, successMessage: "已用 Google 登入 Firebase。")
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        statusMessage = "Google 登入未能執行：GoogleSignIn 或 FirebaseAuth SDK 未連入此 build。"
        #endif
    }

    func signInWithApple() {
        #if canImport(AuthenticationServices) && canImport(FirebaseAuth) && canImport(CryptoKit)
        let nonce = Self.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        isBusy = true
        statusMessage = "正在開啟 Apple ID 登入..."

        let coordinator = AppleSignInCoordinator(nonce: nonce) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBusy = false

                switch result {
                case .success(let appleResult):
                    await self.signInWithAppleCredential(appleResult)
                case .failure(let error):
                    self.statusMessage = Self.readableAuthError(error)
                }

                self.appleSignInCoordinator = nil
            }
        }
        appleSignInCoordinator = coordinator

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
        #else
        statusMessage = "Apple ID 登入未能執行：AuthenticationServices / FirebaseAuth / CryptoKit 未連入此 build。"
        #endif
    }

    @discardableResult
    func sendPhoneCode(phoneNumber: String) async -> Bool {
        let normalizedPhone = Self.normalizedPhoneNumber(phoneNumber)

        #if os(iOS) && canImport(FirebaseAuth)
        isBusy = true
        defer { isBusy = false }

        do {
            let verificationID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                PhoneAuthProvider.provider().verifyPhoneNumber(normalizedPhone, uiDelegate: nil) { verificationID, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let verificationID {
                        continuation.resume(returning: verificationID)
                        return
                    }

                    continuation.resume(throwing: ProfileAuthError.emptyVerificationResult)
                }
            }

            phoneVerificationID = verificationID
            phoneVerificationNumber = normalizedPhone
            statusMessage = "SMS 驗證碼已送出到 \(normalizedPhone)。"
            return true
        } catch {
            statusMessage = Self.readableAuthError(error)
            return false
        }
        #else
        statusMessage = "電話登入未能執行：FirebaseAuth SDK 未連入此 build。"
        return false
        #endif
    }

    @discardableResult
    func confirmPhoneCode(_ code: String) async -> Bool {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        #if os(iOS) && canImport(FirebaseAuth)
        guard let phoneVerificationID else {
            statusMessage = "請先發送 SMS 驗證碼。"
            return false
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: phoneVerificationID,
            verificationCode: normalizedCode
        )
        await signIn(with: credential, successMessage: "已用電話號碼登入 Firebase。")

        if isSignedIn {
            self.phoneVerificationID = nil
            phoneVerificationNumber = nil
            return true
        }
        return false
        #else
        statusMessage = "電話登入未能執行：FirebaseAuth SDK 未連入此 build。"
        return false
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
            try Auth.auth().signOut()
            session = nil
            statusMessage = "已登出"
            // Profile cosmetics are device-local; clear so the next account doesn't inherit them.
            UserDefaults.standard.removeObject(forKey: "wildfrog.profile.avatar.thumbnail")
            UserDefaults.standard.removeObject(forKey: "wildfrog.profile.equippedTitleId")
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        session = nil
        statusMessage = "已回到訪客模式"
        // Profile cosmetics are device-local; clear so the next account doesn't inherit them.
        UserDefaults.standard.removeObject(forKey: "wildfrog.profile.avatar.thumbnail")
        UserDefaults.standard.removeObject(forKey: "wildfrog.profile.equippedTitleId")
        #endif
    }

    func deleteAccount() async {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            session = nil
            statusMessage = "已回到訪客模式"
            return
        }
        let uid = user.uid
        isBusy = true
        defer { isBusy = false }

        // Best-effort: remove the user's cloud check-ins before deleting the auth user.
        try? await FirestoreService().deleteUserCheckIns(userId: uid)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                user.delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif

            // Best-effort: remove summit photos stored as .jpg in the app's Documents directory.
            let fm = FileManager.default
            if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
               let contents = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
                for file in contents where file.pathExtension.lowercased() == "jpg" {
                    try? fm.removeItem(at: file)
                }
            }

            session = nil
            statusMessage = "帳戶已刪除"
            // Profile cosmetics are device-local; clear so the next account doesn't inherit them.
            UserDefaults.standard.removeObject(forKey: "wildfrog.profile.avatar.thumbnail")
            UserDefaults.standard.removeObject(forKey: "wildfrog.profile.equippedTitleId")
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        session = nil
        statusMessage = "帳戶已刪除（示範）"
        #endif
    }

    func updateDisplayName(_ rawName: String) async {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "名稱不可留空。"
            return
        }
        guard trimmedName.count <= 24 else {
            statusMessage = "名稱最多 24 個字。"
            return
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            replaceSessionDisplayName(trimmedName)
            statusMessage = "名稱已更新。"
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let request = user.createProfileChangeRequest()
            request.displayName = trimmedName
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                request.commitChanges { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            replaceSessionDisplayName(trimmedName)
            statusMessage = "名稱已更新。"
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        replaceSessionDisplayName(trimmedName)
        statusMessage = "名稱已更新。"
        #endif
    }

    func noteAvatarUpdated() {
        statusMessage = "頭像已更新"
    }

    func noteAvatarFailed(_ message: String) {
        statusMessage = message
    }

    #if canImport(FirebaseAuth)
    private func observeAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.apply(user: user)
            }
        }
    }

    private func runFirebaseAuthAction(
        successMessage: String,
        operation: (@escaping (AuthDataResult?, Error?) -> Void) -> Void
    ) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
                operation { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let result {
                        continuation.resume(returning: result)
                        return
                    }

                    continuation.resume(throwing: ProfileAuthError.emptyAuthResult)
                }
            }

            apply(user: result.user)
            statusMessage = successMessage
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
    }

    private func signIn(with credential: AuthCredential, successMessage: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
                Auth.auth().signIn(with: credential) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let result {
                        continuation.resume(returning: result)
                        return
                    }

                    continuation.resume(throwing: ProfileAuthError.emptyAuthResult)
                }
            }

            apply(user: result.user)
            statusMessage = successMessage
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
    }

    #if canImport(AuthenticationServices) && canImport(FirebaseAuth)
    private func signInWithAppleCredential(_ appleResult: AppleSignInResult) async {
        let credential = OAuthProvider.appleCredential(
            withIDToken: appleResult.idToken,
            rawNonce: appleResult.nonce,
            fullName: appleResult.fullName
        )
        await signIn(with: credential, successMessage: "已用 Apple ID 登入 Firebase。")
    }
    #endif

    private func apply(user: User?) {
        guard let user else {
            session = nil
            statusMessage = "未登入"
            return
        }

        let newSession = ProfileAuthSession(
            uid: user.uid,
            email: user.email,
            phoneNumber: user.phoneNumber,
            displayName: user.displayName,
            providerLabel: Self.providerLabel(for: user)
        )
        session = newSession

        if statusMessage.isEmpty || statusMessage == "未登入" {
            statusMessage = "已以\(newSession.providerLabel)登入，紀錄已雲端同步。"
        }
    }

    private static func providerLabel(for user: User) -> String {
        let providerID = user.providerData.first?.providerID ?? user.providerID

        switch providerID {
        case "password":
            return "Email"
        case "phone":
            return "電話"
        case "google.com":
            return "Google"
        case "apple.com":
            return "Apple ID"
        default:
            return providerID
        }
    }
    #endif

    private func markFirebaseAuthMissing() {
        statusMessage = "Firebase Auth SDK 未連入此 build，Email 登入未能執行。"
    }

    private func replaceSessionDisplayName(_ displayName: String) {
        guard let current = session else { return }
        session = ProfileAuthSession(
            uid: current.uid,
            email: current.email,
            phoneNumber: current.phoneNumber,
            displayName: displayName,
            providerLabel: current.providerLabel
        )
    }

    private static func readableAuthError(_ error: Error) -> String {
        if case ProfileAuthError.emptyAuthResult = error {
            return "登入失敗：Firebase 沒有回傳有效用戶。"
        }

        if case ProfileAuthError.emptyVerificationResult = error {
            return "電話驗證失敗：Firebase 沒有回傳 verification ID。"
        }

        if case ProfileAuthError.invalidAppleCredential(let reason) = error {
            return "Apple ID 登入失敗：\(reason)"
        }

        let description = (error as NSError).localizedDescription
        guard !description.isEmpty else {
            return "登入失敗，請稍後再試。"
        }
        return "登入失敗：\(description)"
    }

    private static func normalizedPhoneNumber(_ phoneNumber: String) -> String {
        let removableCharacters = CharacterSet(charactersIn: " -()")
        return phoneNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { !removableCharacters.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard result == errSecSuccess else {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(result)")
        }

        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    #if canImport(CryptoKit)
    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
    #endif
}

private enum ProfileAuthError: Error {
    case emptyAuthResult
    case emptyVerificationResult
    case invalidAppleCredential(String)
}

#if canImport(AuthenticationServices)
private struct AppleSignInResult {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let nonce: String
    private let completion: (Result<AppleSignInResult, Error>) -> Void

    init(nonce: String, completion: @escaping (Result<AppleSignInResult, Error>) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        UIApplication.shared.wildFrogKeyWindow ?? ASPresentationAnchor()
        #else
        ASPresentationAnchor()
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(ProfileAuthError.invalidAppleCredential("Apple 沒有回傳 AppleID credential。")))
            return
        }

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            completion(.failure(ProfileAuthError.invalidAppleCredential("Apple 沒有回傳可讀取的 identity token。")))
            return
        }

        completion(.success(AppleSignInResult(idToken: token, nonce: nonce, fullName: credential.fullName)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}
#endif

#if canImport(UIKit)
private extension UIApplication {
    var wildFrogKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    var wildFrogTopViewController: UIViewController? {
        var controller = wildFrogKeyWindow?.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }

        if let navigationController = controller as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController
        }

        if let tabController = controller as? UITabBarController {
            return tabController.selectedViewController ?? tabController
        }

        return controller
    }
}
#endif
