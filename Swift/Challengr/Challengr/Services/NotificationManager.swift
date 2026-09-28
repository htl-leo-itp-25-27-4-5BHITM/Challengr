//
//  NotificationManager.swift
//  Challengr
//

import UIKit
import UserNotifications

/// Local notifications (Lokale Mitteilungen) for events that arrive while the app
/// is in the background, e.g. a challenge right after the user switched apps.
///
/// Note: this is not remote push. When iOS suspends the app the WebSocket closes,
/// so events only arrive while the app is still alive (open or recently backgrounded).
/// Real push needs an APNs key + backend sender (see SwiftDocumentation).
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Same key as the "Mitteilungen" toggle in SettingsView.
    static let notificationsEnabledKey = "notificationsEnabled"

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
    }

    /// Asks for permission once (only if the user did not switch notifications off).
    func requestAuthorizationIfNeeded() {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error { print("🔔 Notification permission error:", error) }
                print("🔔 Notifications granted:", granted)
            }
        }
    }

    /// Shows a notification only when the app is not in the foreground
    /// (im Vordergrund zeigt die App eigene Popups/Banner).
    func notifyIfInBackground(title: String, body: String, identifier: String = UUID().uuidString) {
        guard isEnabled else { return }

        DispatchQueue.main.async {
            guard UIApplication.shared.applicationState != .active else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("🔔 Notification error:", error) }
            }
        }
    }

    func removeNotification(identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Background time (Verbindung kurz offen halten)

    /// Keeps the app (and its WebSocket) alive for the ~30s iOS allows after
    /// backgrounding, so a challenge sent in that window still gets through.
    func beginBackgroundWindow() {
        DispatchQueue.main.async {
            guard self.backgroundTask == .invalid else { return }
            self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ChallengrSocket") { [weak self] in
                self?.endBackgroundWindow()
            }
        }
    }

    func endBackgroundWindow() {
        DispatchQueue.main.async {
            guard self.backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App is in foreground: in-app UI already shows the event.
        completionHandler([])
    }
}
