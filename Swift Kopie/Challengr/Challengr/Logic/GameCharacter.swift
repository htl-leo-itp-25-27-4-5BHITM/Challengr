import Foundation

/// Spielbare 3D-Figuren. Jede Figur gibt es als SceneKit-Modell (`Characters/<sceneName>.scn`)
/// und als daraus gerendertes Bild (ganze Figur + Brustbild für runde Avatare).
enum GameCharacter: String, CaseIterable, Identifiable {
    case sirBrecht = "sir-brecht"
    case ragnar = "ragnar"

    /// Figur dieses App-Builds. Swift = Sir Brecht, Swift Kopie = Ragnar.
    static let own: GameCharacter = .ragnar

    /// Den echten Charakter des Gegners kennt der Server nicht – er bekommt die jeweils andere Figur.
    static var opponent: GameCharacter { own == .sirBrecht ? .ragnar : .sirBrecht }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sirBrecht: return "Sir Brecht"
        case .ragnar:    return "Ragnar"
        }
    }

    var sceneName: String {
        switch self {
        case .sirBrecht: return "SirBrecht"
        case .ragnar:    return "Ragnar"
        }
    }

    /// Ganze Figur (für Karten, Trophy Road).
    var imageName: String { sceneName }

    /// Brustbild (für runde Avatare wie Popups und Profil).
    var avatarImageName: String { sceneName + "Avatar" }

    /// Animation für die Karte: aus dem 3D-Modell gerendert (schräg von oben), Bilder nebeneinander.
    var mapSheetName: String { sceneName + "MapSheet" }
    static let mapSheetFrames = 16

    /// Charakter für einen Spielernamen in Ergebnis-Screens.
    static func forPlayer(_ playerName: String, ownPlayerName: String) -> GameCharacter {
        playerName == ownPlayerName ? own : opponent
    }
}
