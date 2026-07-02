import SwiftUI
import UserNotifications

/// Routes check-in notification taps into the chat UI.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    /// Step text from a tapped check-in notification; ChatView consumes it
    /// and seeds a follow-up session.
    var pendingCheckInStep: String?
    /// True when the user tapped "Did it" on the notification.
    var pendingCheckInCompleted = false
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let stepText = response.notification.request.content.userInfo["stepText"] as? String
        let didIt = response.actionIdentifier == NotificationScheduler.actionDidIt
        // completionHandler is not Sendable, so it's called synchronously here
        // rather than captured into the MainActor Task below.
        defer { completionHandler() }

        guard let stepText else { return }
        Task { @MainActor in
            NotificationRouter.shared.pendingCheckInStep = stepText
            NotificationRouter.shared.pendingCheckInCompleted = didIt
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
