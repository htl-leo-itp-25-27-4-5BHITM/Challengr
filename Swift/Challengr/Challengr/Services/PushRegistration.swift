import UIKit
import UserNotifications
import Combine

/// Push-Benachrichtigungen (APNs): Gerät beim Server anmelden, beim Abschalten/Abmelden wieder abmelden
/// und merken, worauf getippt wurde – die Karte öffnet dann die passende Stelle.
/// Der Server pusht nur, wenn die App zu ist; offen zeigt sie alles selbst.
final class PushRegistration: ObservableObject {
    static let shared = PushRegistration()

    /// Wie `PushService.Kind` im Backend
    enum Kind: String {
        case challenge = "CHALLENGE", gift = "GIFT", friendRequest = "FRIEND_REQUEST", friendAccepted = "FRIEND_ACCEPTED"
    }

    /// Zuletzt angetippte Mitteilung (die Karte reagiert darauf und setzt sie zurück)
    @Published var opened: Kind? = nil
    private(set) var token: String?

    /// Entwickler-Builds gehen an Apples Test-Server
    static var sandbox: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func kind(from userInfo: [AnyHashable: Any]) -> Kind? {
        (userInfo["kind"] as? String).flatMap(Kind.init(rawValue:))
    }

    /// Bei jedem Start (nach erteilter Erlaubnis) – iOS liefert dann das aktuelle Token
    func registerForPush() {
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        Task { await upload(hex) }
    }

    /// Mitteilungen aus oder abgemeldet: der Server schickt an dieses Gerät nichts mehr
    func unregister() {
        guard let token else { return }
        var request = URLRequest(url: BackendConfig.apiURL("api/push/token/\(token)"))
        request.httpMethod = "DELETE"
        Task { _ = try? await API.data(for: request) }
    }

    private func upload(_ token: String) async {
        struct Device: Encodable { let token: String; let topic: String; let sandbox: Bool }
        var request = URLRequest(url: BackendConfig.apiURL("api/push/token"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Device(token: token, topic: Bundle.main.bundleIdentifier ?? "",
                                                            sandbox: Self.sandbox))
        _ = try? await API.data(for: request)
    }
}

/// Nimmt das Push-Token von iOS entgegen (SwiftUI hat dafür keinen eigenen Weg).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Früh setzen, damit auch ein Tipp auf die Mitteilung bei geschlossener App ankommt
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistration.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 Push nicht verfügbar:", error.localizedDescription)
    }
}
