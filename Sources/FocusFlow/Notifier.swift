import Foundation
import AppKit
import UserNotifications

/// macOS notifications. "Session complete" carries "+5 more" and "Take break" buttons.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    static let extendRequested = Notification.Name("FocusFlow.extendRequested")
    static let breakRequested = Notification.Name("FocusFlow.breakRequested")
    static let focusRequested = Notification.Name("FocusFlow.focusRequested")
    static let openRequested = Notification.Name("FocusFlow.openRequested")

    private enum ID {
        static let focusDone = "FOCUS_DONE"
        static let breakDone = "BREAK_DONE"
        static let extend = "EXTEND"
        static let takeBreak = "TAKE_BREAK"
        static let startFocus = "START_FOCUS"
    }

    /// Outside an .app bundle (e.g. `swift run`) the notification center isn't available.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func setup() {
        guard let center = center else { return }
        center.delegate = self
        registerCategories(step: 5)
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func registerCategories(step: Int) {
        guard let center = center else { return }
        let extend = UNNotificationAction(identifier: ID.extend, title: "+\(step) more", options: [])
        let takeBreak = UNNotificationAction(identifier: ID.takeBreak, title: "Take break", options: [])
        let start = UNNotificationAction(identifier: ID.startFocus, title: "Start focus", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: ID.focusDone, actions: [extend, takeBreak], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: ID.breakDone, actions: [start], intentIdentifiers: [], options: []),
        ])
    }

    func focusDone(minutes: Int, intention: String, step: Int) {
        registerCategories(step: step)
        let body: String
        if intention.isEmpty {
            body = "Great focus — \(minutes) minutes. Add \(step) more minutes or take a break."
        } else {
            body = "Great work! You focused for \(minutes) minutes on “\(intention)”."
        }
        post(title: "Session complete! 🎉", body: body, category: ID.focusDone)
    }

    func breakDone() {
        post(title: "Break's over", body: "Ready for the next focus session?", category: ID.breakDone)
    }

    private func post(title: String, body: String, category: String) {
        guard let center = center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        center.removeAllDeliveredNotifications()
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let name: Notification.Name
        switch response.actionIdentifier {
        case ID.extend: name = Notifier.extendRequested
        case ID.takeBreak: name = Notifier.breakRequested
        case ID.startFocus: name = Notifier.focusRequested
        default: name = Notifier.openRequested
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil)
        }
        completionHandler()
    }
}
