import Foundation

/// Einstellung „Cartoon-Karte“ (Einstellungen → Karte).
enum ToonMapSettings {
    static let key = "useToonMap"
    /// Standard: Cartoon-Karte an – fällt bei Ladefehlern automatisch auf die Apple-Karte zurück
    static let defaultOn = true
}
