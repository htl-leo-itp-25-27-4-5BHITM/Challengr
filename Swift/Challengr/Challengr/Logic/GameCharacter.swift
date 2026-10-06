import Foundation

/// Spielbare 3D-Figuren. Jede Figur gibt es als SceneKit-Modell (`Characters/<sceneName>.scn`)
/// und als daraus gerendertes Bild (ganze Figur + Brustbild für runde Avatare).
/// Die Ids (rawValue) und Freischalt-Regeln müssen zum Backend passen (`CharacterCatalog`).
enum GameCharacter: String, CaseIterable, Identifiable {
    case sirBrecht = "sir-brecht"
    case ragnar = "ragnar"
    case hayato = "hayato"

    /// Start-Figur dieses App-Builds, bis man eine andere wählt. Swift = Sir Brecht, Swift Kopie = Ragnar.
    static let own: GameCharacter = .sirBrecht

    /// Die aktuell gewählte Figur (lokal gespeichert und mit dem Server abgeglichen).
    static var current: GameCharacter { AvatarPresets.persistedPreset().character ?? own }

    /// Ersatz, wenn der Server die Figur eines Gegners nicht kennt (z.B. alte App-Version).
    static var opponent: GameCharacter { current == .sirBrecht ? .ragnar : .sirBrecht }

    /// Figur zu einer Id vom Server; unbekannt oder nil → nil.
    static func from(serverId: String?) -> GameCharacter? {
        serverId.flatMap(GameCharacter.init(rawValue:))
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sirBrecht: return "Sir Brecht"
        case .ragnar:    return "Ragnar"
        case .hayato:    return "Hayato"
        }
    }

    /// Klasse und Rolle, wie im Figuren-Roster.
    var tagline: String {
        switch self {
        case .sirBrecht: return "Ritter · Tank"
        case .ragnar:    return "Wikinger · Berserker"
        case .hayato:    return "Samurai · Duellant"
        }
    }

    /// Gewonnene Battles, ab denen die Figur wählbar ist (der Server prüft das verbindlich).
    var winsRequired: Int {
        switch self {
        case .sirBrecht, .ragnar: return 0
        case .hayato:             return 3
        }
    }

    var sceneName: String {
        switch self {
        case .sirBrecht: return "SirBrecht"
        case .ragnar:    return "Ragnar"
        case .hayato:    return "Hayato"
        }
    }

    /// Ganze Figur (für Karten, Trophy Road).
    var imageName: String { sceneName }

    /// Brustbild (für runde Avatare wie Popups und Profil).
    var avatarImageName: String { sceneName + "Avatar" }

    /// Animation für die Karte: aus dem 3D-Modell gerendert (schräg von oben), Bilder nebeneinander.
    var mapSheetName: String { sceneName + "MapSheet" }
    static let mapSheetFrames = 16
}
