import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
final class WildFrogAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        WildFrogFirebaseBootstrap.configureIfNeeded()
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        WildFrogFirebaseBootstrap.handleOpenURL(url)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        WildFrogFirebaseBootstrap.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if WildFrogFirebaseBootstrap.handleRemoteNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        completionHandler(.noData)
    }
}
#endif

@main
struct WildFrogNativeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(WildFrogAppDelegate.self) private var appDelegate
    #endif
    @State private var authService: ProfileAuthService

    init() {
        _authService = State(initialValue: ProfileAuthService(activateFirebase: false))
    }

    var body: some Scene {
        WindowGroup {
            WildFrogRootView()
                .environment(authService)
                .task { @MainActor in
                    authService.activate()
                }
                .onOpenURL { url in
                    WildFrogFirebaseBootstrap.handleOpenURL(url)
                }
        }
    }
}
