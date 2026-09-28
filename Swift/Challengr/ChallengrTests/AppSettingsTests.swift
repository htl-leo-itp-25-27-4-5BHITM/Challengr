import XCTest
@testable import Challengr

/// Sounds, Einstellungen und Backend-Adressen.
final class AppSettingsTests: XCTestCase {

    private var savedSound: Any?
    private var savedNotifications: Any?

    override func setUp() {
        savedSound = UserDefaults.standard.object(forKey: SoundManager.soundEnabledKey)
        savedNotifications = UserDefaults.standard.object(forKey: NotificationManager.notificationsEnabledKey)
    }

    override func tearDown() {
        restore(savedSound, SoundManager.soundEnabledKey)
        restore(savedNotifications, NotificationManager.notificationsEnabledKey)
    }

    private func restore(_ value: Any?, _ key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    // MARK: - Sounds

    func testEverySoundEffectFileIsInTheApp() {
        for effect in SoundEffect.allCases {
            XCTAssertTrue(SoundManager.shared.isAvailable(effect), "Datei fehlt: \(effect.rawValue).mp3 (\(effect))")
        }
    }

    func testSoundSwitchIsRespected() {
        UserDefaults.standard.removeObject(forKey: SoundManager.soundEnabledKey)
        XCTAssertTrue(SoundManager.shared.isEnabled, "Standard: Sound an")

        UserDefaults.standard.set(false, forKey: SoundManager.soundEnabledKey)
        XCTAssertFalse(SoundManager.shared.isEnabled)
        SoundManager.shared.play(.tap) // darf bei ausgeschaltetem Sound nicht abstürzen
    }

    func testSettingsViewUsesTheSameKeys() {
        // SettingsView speichert unter diesen Schlüsseln (@AppStorage)
        XCTAssertEqual(SoundManager.soundEnabledKey, "isSoundEnabled")
        XCTAssertEqual(NotificationManager.notificationsEnabledKey, "notificationsEnabled")
    }

    // MARK: - Mitteilungen

    func testNotificationSwitchIsRespected() {
        UserDefaults.standard.removeObject(forKey: NotificationManager.notificationsEnabledKey)
        XCTAssertTrue(NotificationManager.shared.isEnabled)

        UserDefaults.standard.set(false, forKey: NotificationManager.notificationsEnabledKey)
        XCTAssertFalse(NotificationManager.shared.isEnabled)
    }

    // MARK: - Backend-Adressen

    func testApiUrls() {
        XCTAssertEqual(BackendConfig.apiURL("api/challenges").absoluteString,
                       "https://it220257.cloud.htl-leonding.ac.at/api/challenges")
        XCTAssertEqual(BackendConfig.apiURL("/api/players").absoluteString,
                       "https://it220257.cloud.htl-leonding.ac.at/api/players", "Führender Slash wird entfernt")
    }

    func testWebSocketUrlUsesSecureSocketAndEncodesId() {
        let url = BackendConfig.gameWebSocketURL(playerId: "a b&c")
        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.path, "/ws/game")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "playerId" })?.value, "a b&c")
    }
}
