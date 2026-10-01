//
//  SoundManager.swift
//  Challengr
//

import AVFoundation

/// All sound effects used in the app (Alle Soundeffekte der App).
/// Raw value = filename in the Sounds folder without ".mp3".
enum SoundEffect: String, CaseIterable {
    case tap              = "CLICK_01"
    case challengeSent    = "CLICK_02"
    case challengeIncoming = "GIFT_04"    // kräftig steigend, fällt auf
    case challengeAccepted = "SWOSH_02"
    case challengeClosed  = "TRASH_03"   // abgelehnt / abgebrochen / abgelaufen
    case battleStart      = "SWOSH_01"
    case countdownTick    = "COUNTER_01"
    case countdownGo      = "COUNTER_02"
    case win              = "JINGLE_06"   // steigende Melodie (JINGLE_01 fällt ab und klang nach Niederlage)
    case lose             = "TRASH_01"
    case purchase         = "COIN_02"
    case purchaseFailed   = "TRASH_05"
    case giftSent         = "GIFT_01"
    case giftClaimed      = "GIFT_02"
    case friendRequest    = "JINGLE_04"
    case friendAccepted   = "JINGLE_03"
}

// MARK: - Sound Manager (Global)
final class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()

    /// Same key as the "Soundeffekte" toggle in SettingsView.
    static let soundEnabledKey = "isSoundEnabled"

    /// Same key as the "Hintergrundmusik" toggle in SettingsView.
    static let musicEnabledKey = "isMusicEnabled"

    /// Looping background track (Sounds/MUSIC, Dateiname ohne Endung).
    static let backgroundTrack = "background_track_v1"
    static let musicVolume: Float = 0.25

    // Several players so short effects can overlap (z.B. Klick + Jingle).
    private var activePlayers: [AVAudioPlayer] = []
    private var sessionConfigured = false

    // Background music (Hintergrundmusik)
    private var musicPlayer: AVAudioPlayer?
    private var appIsActive = false
    private var musicPausedForRecording = false

    // Indexes every .mp3/.m4a shipped in the app bundle by filename (without extension),
    // regardless of which subfolder it lives in. Avoids depending on a fixed
    // subdirectory path, which differs between the simulator, device and every
    // developer's machine.
    private lazy var soundURLsByName: [String: URL] = Self.indexBundleSounds()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.soundEnabledKey) as? Bool ?? true
    }

    var isMusicEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.musicEnabledKey) as? Bool ?? true
    }

    /// Is the background track in the app bundle? (für Tests)
    var isBackgroundTrackAvailable: Bool {
        soundURLsByName[Self.backgroundTrack] != nil
    }

    var isMusicPlaying: Bool { musicPlayer?.isPlaying ?? false }

    // MARK: - Background music (Hintergrundmusik)

    /// App kommt in den Vordergrund / geht in den Hintergrund.
    func setAppActive(_ active: Bool) {
        appIsActive = active
        updateMusic()
    }

    /// Mikrofon-Challenges pausieren die Musik, damit sie nicht mitgemessen wird.
    func setRecordingActive(_ recording: Bool) {
        musicPausedForRecording = recording
        if !recording {
            // SoundMeter hat die Session auf Aufnahme umgestellt – zurück auf Wiedergabe
            sessionConfigured = false
        }
        updateMusic()
    }

    /// Startet oder pausiert die Musik je nach Einstellung und App-Zustand.
    func updateMusic() {
        let run = { [weak self] in
            guard let self else { return }
            let shouldPlay = self.isMusicEnabled && self.appIsActive && !self.musicPausedForRecording
            if shouldPlay {
                // Läuft schon Musik einer anderen App (z.B. Spotify), nicht drüberspielen.
                if self.musicPlayer?.isPlaying != true, AVAudioSession.sharedInstance().isOtherAudioPlaying { return }
                self.startMusic()
            } else {
                self.musicPlayer?.pause()
            }
        }
        if Thread.isMainThread { run() } else { DispatchQueue.main.async(execute: run) }
    }

    private func startMusic() {
        guard !musicPausedForRecording else { return }
        configureSessionIfNeeded()
        if musicPlayer == nil {
            guard let url = soundURLsByName[Self.backgroundTrack],
                  let player = try? AVAudioPlayer(contentsOf: url) else {
                print("❌ Background track not found in bundle: \(Self.backgroundTrack)")
                return
            }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            musicPlayer = player
        }
        guard let player = musicPlayer, !player.isPlaying else { return }
        player.play()
        player.setVolume(Self.musicVolume, fadeDuration: 1.5)
    }

    /// Is the file for this effect in the app bundle? (für Tests)
    func isAvailable(_ effect: SoundEffect) -> Bool {
        soundURLsByName[effect.rawValue] != nil
    }

    func play(_ effect: SoundEffect) {
        playSound(effect.rawValue)
    }

    func playSound(_ filename: String) {
        guard isEnabled else { return }

        let play = { [weak self] in
            guard let self else { return }
            self.configureSessionIfNeeded()

            guard let url = self.soundURLsByName[filename] else {
                print("❌ Sound file not found in bundle: \(filename)")
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                player.play()
                self.activePlayers.append(player)
            } catch {
                print("❌ Error playing sound:", error)
            }
        }

        if Thread.isMainThread { play() } else { DispatchQueue.main.async(execute: play) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.activePlayers.removeAll { $0 === player }
        }
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        do {
            // Short effects mix with the user's music instead of stopping it.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            sessionConfigured = true
        } catch {
            print("❌ Audio Session error:", error)
        }
    }

    private static func indexBundleSounds() -> [String: URL] {
        guard let resourceURL = Bundle.main.resourceURL else { return [:] }

        var result: [String: URL] = [:]
        let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            guard ["mp3", "m4a"].contains(url.pathExtension.lowercased()) else { continue }
            result[url.deletingPathExtension().lastPathComponent] = url
        }

        return result
    }
}
