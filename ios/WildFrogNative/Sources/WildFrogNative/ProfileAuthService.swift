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
        AppText.value(zh: "\(providerLabel) 已登入", en: "\(providerLabel) signed in")
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
struct AccountDeletionCloudWorkflow {
    private let establishTombstone: () async throws -> Void
    private let awaitPublicCleanup: () async throws -> Void
    private let finalCheckInSweep: () async throws -> Void

    init(
        establishTombstone: @escaping () async throws -> Void,
        awaitPublicCleanup: @escaping () async throws -> Void,
        finalCheckInSweep: @escaping () async throws -> Void
    ) {
        self.establishTombstone = establishTombstone
        self.awaitPublicCleanup = awaitPublicCleanup
        self.finalCheckInSweep = finalCheckInSweep
    }

    func run() async throws {
        try await establishTombstone()
        try await awaitPublicCleanup()
        try await finalCheckInSweep()
    }
}

enum AccountDeletionCleanupAcknowledgement {
    static let legacyRequestID = "legacy-tombstone-v1"

    static func matches(requestID: String, completedRequestID: String?) -> Bool {
        !requestID.isEmpty && completedRequestID == requestID
    }
}

struct AccountDeletionRequestPlan: Equatable {
    let requestID: String
    let mustWriteCleanupRequest: Bool

    static func resolve(
        tombstoneRequestID: String?,
        proposedRequestID: String
    ) -> Self {
        Self(
            requestID: tombstoneRequestID ?? proposedRequestID,
            mustWriteCleanupRequest: true
        )
    }
}

@MainActor
@Observable
final class ProfileAuthService {
    private(set) var session: ProfileAuthSession?
    private(set) var statusMessage = AppText.value(zh: "未登入", en: "Not signed in")
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

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaSignedIn") {
            session = ProfileAuthSession(
                uid: "wildfrog-qa-screenshot",
                email: WildFrogReviewerAccess.accountEmail,
                phoneNumber: nil,
                displayName: "WildFrog Demo",
                providerLabel: "Demo"
            )
            statusMessage = AppText.value(zh: "截圖模式已登入", en: "Signed in for screenshot mode")
            return
        }
        #endif

        WildFrogFirebaseBootstrap.configureIfNeeded()
        observeAuthState()
    }

    var isSignedIn: Bool {
        session != nil
    }

    var profileLine: String {
        session?.profileLine ?? AppText.value(zh: "用頭像同登入同步你的登山紀錄", en: "Sign in to sync your hiking record")
    }

    var canUseReviewerTools: Bool {
        session?.isReviewerAccount == true
    }

    func signInWithEmail(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(FirebaseAuth)
        statusMessage = AppText.value(zh: "正在用 Email 登入...", en: "Signing in with Email...")
        await runFirebaseAuthAction(successMessage: AppText.value(zh: "已用 Email 登入 Firebase。", en: "Signed in with Email.")) { completion in
            Auth.auth().signIn(withEmail: normalizedEmail, password: password, completion: completion)
        }
        #else
        markFirebaseAuthMissing()
        #endif
    }

    func createEmailAccount(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(FirebaseAuth)
        statusMessage = AppText.value(zh: "正在建立 Email 帳戶...", en: "Creating Email account...")
        await runFirebaseAuthAction(successMessage: AppText.value(zh: "已建立 Firebase Email 帳戶並登入。", en: "Created Email account and signed in.")) { completion in
            Auth.auth().createUser(withEmail: normalizedEmail, password: password, completion: completion)
        }
        #else
        markFirebaseAuthMissing()
        #endif
    }

    func signInWithGoogle() async {
        #if canImport(UIKit) && canImport(GoogleSignIn) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard let clientID = WildFrogFirebaseBootstrap.googleClientID else {
            statusMessage = AppText.value(zh: "Google 登入未能開始：現有 GoogleService-Info.plist 缺少 CLIENT_ID。請在 Firebase Console enable Google provider 後重新下載 plist。", en: "Google sign-in cannot start: GoogleService-Info.plist is missing CLIENT_ID. Enable Google provider in Firebase Console and download the plist again.")
            return
        }

        guard let reversedClientID = WildFrogFirebaseBootstrap.googleReversedClientID else {
            statusMessage = AppText.value(zh: "Google 登入未能開始：現有 GoogleService-Info.plist 缺少 REVERSED_CLIENT_ID。請重新下載已啟用 Google provider 的 plist。", en: "Google sign-in cannot start: GoogleService-Info.plist is missing REVERSED_CLIENT_ID.")
            return
        }

        guard WildFrogFirebaseBootstrap.hasURLScheme(reversedClientID) else {
            statusMessage = AppText.value(zh: "Google 登入未能開始：Info.plist 未加入 Google URL scheme \(reversedClientID)。", en: "Google sign-in cannot start: Info.plist is missing URL scheme \(reversedClientID).")
            return
        }

        guard let presentingViewController = UIApplication.shared.wildFrogTopViewController else {
            statusMessage = AppText.value(zh: "Google 登入未能開始：找不到目前畫面。", en: "Google sign-in cannot start: no presenting screen found.")
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
                statusMessage = AppText.value(zh: "Google 登入失敗：Google 沒有回傳 ID token。", en: "Google sign-in failed: no ID token returned.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            await signIn(with: credential, successMessage: AppText.value(zh: "已用 Google 登入 Firebase。", en: "Signed in with Google."))
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        statusMessage = AppText.value(zh: "Google 登入未能執行：GoogleSignIn 或 FirebaseAuth SDK 未連入此 build。", en: "Google sign-in is unavailable in this build.")
        #endif
    }

    func signInWithApple() {
        #if canImport(AuthenticationServices) && canImport(FirebaseAuth) && canImport(CryptoKit)
        Task { @MainActor in
            await signInWithAppleInteractively()
        }
        #else
        statusMessage = AppText.value(zh: "Apple ID 登入未能執行：AuthenticationServices / FirebaseAuth / CryptoKit 未連入此 build。", en: "Apple ID sign-in is unavailable in this build.")
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
            statusMessage = AppText.value(zh: "SMS 驗證碼已送出到 \(normalizedPhone)。", en: "SMS verification code sent to \(normalizedPhone).")
            return true
        } catch {
            statusMessage = Self.readableAuthError(error)
            return false
        }
        #else
        statusMessage = AppText.value(zh: "電話登入未能執行：FirebaseAuth SDK 未連入此 build。", en: "Phone sign-in is unavailable in this build.")
        return false
        #endif
    }

    @discardableResult
    func confirmPhoneCode(_ code: String) async -> Bool {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        #if os(iOS) && canImport(FirebaseAuth)
        guard let phoneVerificationID else {
            statusMessage = AppText.value(zh: "請先發送 SMS 驗證碼。", en: "Please send an SMS verification code first.")
            return false
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: phoneVerificationID,
            verificationCode: normalizedCode
        )
        await signIn(with: credential, successMessage: AppText.value(zh: "已用電話號碼登入 Firebase。", en: "Signed in with phone number."))

        if isSignedIn {
            self.phoneVerificationID = nil
            phoneVerificationNumber = nil
            return true
        }
        return false
        #else
        statusMessage = AppText.value(zh: "電話登入未能執行：FirebaseAuth SDK 未連入此 build。", en: "Phone sign-in is unavailable in this build.")
        return false
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            session = nil
            statusMessage = AppText.value(zh: "已登出", en: "Signed out")
            clearLocalAccountData(photoFilenamesToRemove: [])
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        session = nil
        statusMessage = AppText.value(zh: "已回到訪客模式", en: "Back to guest mode")
        clearLocalAccountData(photoFilenamesToRemove: [])
        #endif
    }

    @discardableResult
    func deleteAccount(
        expectedUID: String,
        ownedPhotoFilenames: Set<String>
    ) async -> String? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            session = nil
            statusMessage = AppText.value(zh: "已回到訪客模式", en: "Back to guest mode")
            return nil
        }
        guard user.uid == expectedUID else {
            statusMessage = AppText.value(
                zh: "登入帳戶已變更，刪除已安全停止。",
                en: "The signed-in account changed, so deletion stopped safely."
            )
            return nil
        }
        let uid = user.uid
        isBusy = true
        defer { isBusy = false }

        do {
            try await prepareForAccountDeletion(user)
            let firestoreService = FirestoreService()
            var deletionRequestID: String?
            try await AccountDeletionCloudWorkflow(
                establishTombstone: {
                    deletionRequestID = try await firestoreService.deleteLeaderboardParticipation(
                        userId: uid,
                        proposedDeletionRequestID: UUID().uuidString
                    )
                },
                awaitPublicCleanup: {
                    guard let deletionRequestID else {
                        throw FirestoreService.FirestoreServiceError.deletionCleanupUnconfirmed
                    }
                    try await firestoreService.waitForLeaderboardDeletionCleanup(
                        userId: uid,
                        deletionRequestID: deletionRequestID
                    )
                },
                finalCheckInSweep: {
                    try await firestoreService.deleteUserCheckIns(userId: uid)
                }
            ).run()
            try await user.delete()

            session = nil
            statusMessage = AppText.value(zh: "帳戶已刪除", en: "Account deleted")
            clearLocalAccountData(photoFilenamesToRemove: ownedPhotoFilenames)
            return uid
        } catch {
            statusMessage = Self.readableAuthError(error)
            return nil
        }
        #else
        guard session?.uid == expectedUID else { return nil }
        let uid = session?.uid
        session = nil
        statusMessage = AppText.value(zh: "帳戶已刪除（示範）", en: "Account deleted (demo)")
        clearLocalAccountData(photoFilenamesToRemove: ownedPhotoFilenames)
        return uid
        #endif
    }

    func updateDisplayName(_ rawName: String) async {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = AppText.value(zh: "名稱不可留空。", en: "Name cannot be empty.")
            return
        }
        guard trimmedName.count <= 24 else {
            statusMessage = AppText.value(zh: "名稱最多 24 個字。", en: "Name must be 24 characters or fewer.")
            return
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            replaceSessionDisplayName(trimmedName)
            statusMessage = AppText.value(zh: "名稱已更新。", en: "Name updated.")
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
            statusMessage = AppText.value(zh: "名稱已更新。", en: "Name updated.")
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
        #else
        replaceSessionDisplayName(trimmedName)
        statusMessage = AppText.value(zh: "名稱已更新。", en: "Name updated.")
        #endif
    }

    func noteAvatarUpdated() {
        statusMessage = AppText.value(zh: "頭像已更新", en: "Avatar updated")
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
    private func prepareForAccountDeletion(_ user: User) async throws {
        if Self.usesAppleProvider(user) {
            statusMessage = AppText.value(zh: "請再次用 Apple ID 確認刪除帳戶...", en: "Confirm with Apple ID to delete your account...")
            try await reauthenticateAndRevokeAppleToken(for: user)
            return
        }

        guard Self.hasRecentSignIn(user) else {
            throw ProfileAuthError.recentLoginRequired
        }
    }

    private func signInWithAppleInteractively() async {
        isBusy = true
        defer { isBusy = false }

        statusMessage = AppText.value(zh: "正在開啟 Apple ID 登入...", en: "Opening Apple ID sign-in...")

        do {
            let appleResult = try await requestAppleCredential()
            await signInWithAppleCredential(appleResult)
        } catch {
            statusMessage = Self.readableAuthError(error)
        }
    }

    private func signInWithAppleCredential(_ appleResult: AppleSignInResult) async {
        let credential = OAuthProvider.appleCredential(
            withIDToken: appleResult.idToken,
            rawNonce: appleResult.nonce,
            fullName: appleResult.fullName
        )
        await signIn(with: credential, successMessage: AppText.value(zh: "已用 Apple ID 登入 Firebase。", en: "Signed in with Apple ID."))
    }

    private func reauthenticateAndRevokeAppleToken(for user: User) async throws {
        let appleResult = try await requestAppleCredential()
        let credential = OAuthProvider.appleCredential(
            withIDToken: appleResult.idToken,
            rawNonce: appleResult.nonce,
            fullName: appleResult.fullName
        )
        _ = try await user.reauthenticate(with: credential)
        try await Auth.auth().revokeToken(withAuthorizationCode: appleResult.authorizationCode)
    }

    private func requestAppleCredential() async throws -> AppleSignInResult {
        let nonce = Self.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = AppleSignInCoordinator(nonce: nonce) { [weak self] result in
                Task { @MainActor [weak self] in
                    self?.appleSignInCoordinator = nil
                    continuation.resume(with: result)
                }
            }
            appleSignInCoordinator = coordinator

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
    }
    #endif

    private func apply(user: User?) {
        guard let user else {
            session = nil
            statusMessage = AppText.value(zh: "未登入", en: "Not signed in")
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

        if statusMessage.isEmpty || statusMessage == "未登入" || statusMessage == "Not signed in" {
            statusMessage = AppText.value(zh: "已以\(newSession.providerLabel)登入，紀錄已雲端同步。", en: "Signed in with \(newSession.providerLabel). Your records are synced.")
        }
    }

    private static func providerLabel(for user: User) -> String {
        let providerID = user.providerData.first?.providerID ?? user.providerID

        switch providerID {
        case "password":
            return "Email"
        case "phone":
            return AppText.value(zh: "電話", en: "Phone")
        case "google.com":
            return "Google"
        case "apple.com":
            return "Apple ID"
        default:
            return providerID
        }
    }

    private static func usesAppleProvider(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == "apple.com" } || user.providerID == "apple.com"
    }

    private static func hasRecentSignIn(_ user: User) -> Bool {
        guard let lastSignInDate = user.metadata.lastSignInDate else {
            return false
        }
        return Date().timeIntervalSince(lastSignInDate) < 4 * 60
    }
    #endif

    private func markFirebaseAuthMissing() {
        statusMessage = AppText.value(zh: "Firebase Auth SDK 未連入此 build，Email 登入未能執行。", en: "Firebase Auth SDK is not linked in this build, so Email sign-in cannot run.")
    }

    private func clearLocalAccountData(photoFilenamesToRemove: Set<String>) {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif

        UserDefaults.standard.removeObject(forKey: "wildfrog.profile.avatar.thumbnail")
        UserDefaults.standard.removeObject(forKey: "wildfrog.profile.equippedTitleId")

        guard !photoFilenamesToRemove.isEmpty else { return }

        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else {
            return
        }

        for file in AccountPhotoDeletionPlan.urlsToDelete(
            from: contents,
            ownedFilenames: photoFilenamesToRemove
        ) {
            try? fm.removeItem(at: file)
        }
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
            return AppText.value(zh: "登入失敗：Firebase 沒有回傳有效用戶。", en: "Sign-in failed: Firebase did not return a valid user.")
        }

        if case ProfileAuthError.emptyVerificationResult = error {
            return AppText.value(zh: "電話驗證失敗：Firebase 沒有回傳 verification ID。", en: "Phone verification failed: Firebase did not return a verification ID.")
        }

        if case ProfileAuthError.invalidAppleCredential(let reason) = error {
            return AppText.value(zh: "Apple ID 登入失敗：\(reason)", en: "Apple ID sign-in failed: \(reason)")
        }

        if case ProfileAuthError.recentLoginRequired = error {
            return AppText.value(zh: "為保障帳戶安全，請先登出再重新登入，然後再刪除帳戶。你的雲端打卡紀錄未有刪除。", en: "For account security, sign out and sign in again before deleting your account. Your cloud check-ins were not deleted.")
        }

        let nsError = error as NSError
        #if canImport(FirebaseAuth)
        if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
            return AppText.value(zh: "為保障帳戶安全，請先登出再重新登入，然後再刪除帳戶。你的雲端打卡紀錄未有刪除。", en: "For account security, sign out and sign in again before deleting your account. Your cloud check-ins were not deleted.")
        }
        #endif

        let description = nsError.localizedDescription
        if description.lowercased().contains("cancel") || description.contains("取消") {
            return AppText.value(zh: "已取消登入。", en: "Sign-in cancelled.")
        }

        guard !description.isEmpty else {
            return AppText.value(zh: "登入失敗，請稍後再試。", en: "Sign-in failed. Please try again later.")
        }
        return AppText.value(zh: "登入失敗：\(description)", en: "Sign-in failed: \(description)")
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
    case recentLoginRequired
}

#if canImport(AuthenticationServices)
private struct AppleSignInResult {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
    let authorizationCode: String
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

        guard let authorizationCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            completion(.failure(ProfileAuthError.invalidAppleCredential("Apple 沒有回傳可撤銷憑證所需的 authorization code。")))
            return
        }

        completion(.success(AppleSignInResult(idToken: token, nonce: nonce, fullName: credential.fullName, authorizationCode: authorizationCode)))
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
