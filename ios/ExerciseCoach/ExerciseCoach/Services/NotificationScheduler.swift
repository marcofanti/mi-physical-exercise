import Foundation
import UserNotifications

/// Local check-in notifications for committed next steps.
enum NotificationScheduler {
    static let categoryIdentifier = "EXERCISE_CHECKIN"
    static let actionDidIt = "CHECKIN_DID_IT"
    static let actionNotYet = "CHECKIN_NOT_YET"

    /// Registers the check-in category with its action buttons. Call once at launch.
    static func registerCategories() {
        let didIt = UNNotificationAction(
            identifier: actionDidIt,
            title: "Did it",
            options: []
        )
        let notYet = UNNotificationAction(
            identifier: actionNotYet,
            title: "Not yet",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [didIt, notYet],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Requests permission lazily — first called when the user commits a step.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Schedules the check-in for a committed step. Takes plain Sendable
    /// values rather than the SwiftData `CommittedStep` model, which is not
    /// Sendable and must not cross this async boundary. Returns false if the
    /// user denied notification permission.
    @discardableResult
    static func scheduleCheckIn(
        text: String,
        remindAt: Date,
        notificationIdentifier: String
    ) async -> Bool {
        guard await requestAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Exercise check-in"
        content.body = "You planned: \(text). How did it go?"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["stepText": text]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: remindAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancelCheckIn(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
