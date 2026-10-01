import XCTest
@testable import Challengr

/// Sounds, Einstellungen und Backend-Adressen.
final class AppSettingsTests: XCTestCase {

    private var savedSound: Any?
    private var savedMusic: Any?
    private var savedNotifications: Any?

    override func setUp() {
        savedSound = UserDefaults.standard.object(forKey: SoundManager.soundEnabledKey)
        savedMusic = UserDefaults.standard.object(forKey: SoundManager.musicEnabledKey)
        savedNotifications = UserDefaults.standard.object(forKey: NotificationManager.notificationsEnabledKey)
    }

    override func tearDown() {
        restore(savedSound, SoundManager.soundEnabledKey)
        restore(savedMusic, SoundManager.musicEnabledKey)
        SoundManager.shared.setAppActive(false)
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

    func testIncomingChallengeHasItsOwnSound() {
        XCTAssertEqual(SoundEffect.challengeIncoming.rawValue, "GIFT_04")
        let others = SoundEffect.allCases.filter { $0 != .challengeIncoming }.map(\.rawValue)
        XCTAssertFalse(others.contains("GIFT_04"), "Challenge-Sound wird sonst nirgends verwendet")
    }

    func testWinSoundIsTheRisingJingle() {
        // JINGLE_01 fällt in der Tonhöhe ab und klang nach Niederlage
        XCTAssertEqual(SoundEffect.win.rawValue, "JINGLE_06")
        XCTAssertNotEqual(SoundEffect.win, SoundEffect.lose)
    }

    // MARK: - Hintergrundmusik

    func testBackgroundTrackIsInTheApp() {
        XCTAssertTrue(SoundManager.shared.isBackgroundTrackAvailable, "Datei fehlt: \(SoundManager.backgroundTrack).mp3")
    }

    func testMusicFollowsSwitchAndAppState() {
        UserDefaults.standard.removeObject(forKey: SoundManager.musicEnabledKey)
        XCTAssertTrue(SoundManager.shared.isMusicEnabled, "Standard: Musik an")

        SoundManager.shared.setAppActive(true)
        XCTAssertTrue(SoundManager.shared.isMusicPlaying, "Musik läuft, solange die App aktiv ist")

        SoundManager.shared.setRecordingActive(true)
        XCTAssertFalse(SoundManager.shared.isMusicPlaying, "Mikrofon-Challenge pausiert die Musik")
        SoundManager.shared.setRecordingActive(false)
        XCTAssertTrue(SoundManager.shared.isMusicPlaying)

        UserDefaults.standard.set(false, forKey: SoundManager.musicEnabledKey)
        SoundManager.shared.updateMusic()
        XCTAssertFalse(SoundManager.shared.isMusicPlaying, "Schalter aus → Musik aus")

        UserDefaults.standard.set(true, forKey: SoundManager.musicEnabledKey)
        SoundManager.shared.updateMusic()
        SoundManager.shared.setAppActive(false)
        XCTAssertFalse(SoundManager.shared.isMusicPlaying, "App im Hintergrund → Musik aus")
    }

    func testSettingsViewUsesTheSameKeys() {
        // SettingsView speichert unter diesen Schlüsseln (@AppStorage)
        XCTAssertEqual(SoundManager.soundEnabledKey, "isSoundEnabled")
        XCTAssertEqual(SoundManager.musicEnabledKey, "isMusicEnabled")
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
