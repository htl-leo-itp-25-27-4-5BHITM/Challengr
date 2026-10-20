import Foundation
import SwiftUI

/// Spielbare 3D-Figuren. Jede Figur gibt es als SceneKit-Modell (`Characters/<sceneName>.scn`)
/// und als daraus gerendertes Bild (ganze Figur + Brustbild für runde Avatare).
/// Die Ids (rawValue) und Freischalt-Regeln müssen zum Backend passen (`CharacterCatalog`).
enum GameCharacter: String, CaseIterable, Identifiable {
    // Start-Figuren (von Anfang an frei)
    case junge = "junge"
    case maedchen = "maedchen"
    // Roster (freischaltbar)
    case sirBrecht = "sir-brecht"
    case ragnar = "ragnar"
    case hayato = "hayato"
    case kage = "kage"
    case kai = "kai"
    case merlo = "merlo"
    case lyra = "lyra"
    case kaeptnRex = "kaeptn-rex"
    // Event-Belohnungen (nur solange das Event läuft)
    case crashDummy = "crash-dummy"

    /// Start-Figur, bis man im Figuren-Editor eine andere wählt.
    static let own: GameCharacter = .junge

    /// Die aktuell gewählte Figur (lokal gespeichert und mit dem Server abgeglichen).
    static var current: GameCharacter { AvatarPresets.persistedPreset().character ?? own }

    /// Ersatz, wenn der Server die Figur eines Gegners nicht kennt (z.B. alte App-Version).
    static var opponent: GameCharacter { current == .junge ? .maedchen : .junge }

    /// Figur zu einer Id vom Server; unbekannt oder nil → nil.
    static func from(serverId: String?) -> GameCharacter? {
        serverId.flatMap(GameCharacter.init(rawValue:))
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .junge:     return "Junge"
        case .maedchen:  return "Mädchen"
        case .sirBrecht: return "Sir Brecht"
        case .ragnar:    return "Ragnar"
        case .hayato:    return "Hayato"
        case .kage:      return "Kage"
        case .kai:       return "Kai"
        case .merlo:     return "Merlo"
        case .lyra:      return "Lyra"
        case .kaeptnRex: return "Käpt'n Rex"
        case .crashDummy: return "Crash-Test-Dummy"
        }
    }

    /// Klasse und Rolle, wie im Figuren-Roster.
    var tagline: String {
        switch self {
        case .junge, .maedchen: return "Starter · Allrounder"
        case .sirBrecht:        return "Ritter · Tank"
        case .ragnar:           return "Wikinger · Berserker"
        case .hayato:           return "Samurai · Duellant"
        case .kage:             return "Ninja · Assassine"
        case .kai:              return "Streetfighter · Allrounder"
        case .merlo:            return "Magier · Wissen"
        case .lyra:             return "Waldläuferin · Ausdauer"
        case .kaeptnRex:        return "Pirat · Glücksritter"
        case .crashDummy:       return "Beta-Tester · Event"
        }
    }

    /// Wofür man die Figur bekommt (der Server prüft das verbindlich).
    var requirement: UnlockRequirement {
        switch self {
        case .junge, .maedchen: return .none
        case .sirBrecht:        return .wins(1)
        case .ragnar:           return .wins(3)
        case .merlo:            return .knowledgeWins(3)
        case .lyra:             return .checkins(5)
        // Rang-Belohnungen der Trophy Road (Grenzen wie im Backend, reference-data.sql)
        case .kaeptnRex:        return .rank("Contender", trophies: 350)
        case .hayato:           return .rank("Tryhard", trophies: 600)
        case .kai:              return .rank("Brawler", trophies: 950)
        case .kage:             return .rank("Dueler", trophies: 1400)
        case .crashDummy:       return .event("Beta-Event")
        }
    }

    var sceneName: String {
        switch self {
        case .junge:     return "Junge"
        case .maedchen:  return "Maedchen"
        case .sirBrecht: return "SirBrecht"
        case .ragnar:    return "Ragnar"
        case .hayato:    return "Hayato"
        case .kage:      return "Kage"
        case .kai:       return "Kai"
        case .merlo:     return "Merlo"
        case .lyra:      return "Lyra"
        case .kaeptnRex: return "Rex"
        case .crashDummy: return "Dummy"
        }
    }

    /// Farbe der Figur – Hintergrund hinter runden Avataren (statt durchsichtig).
    var themeColor: Color {
        switch self {
        case .junge:     return Color(red: 0.98, green: 0.78, blue: 0.20)
        case .maedchen:  return Color(red: 0.86, green: 0.25, blue: 0.27)
        case .sirBrecht: return Color(red: 0.42, green: 0.55, blue: 0.75)
        case .ragnar:    return Color(red: 0.85, green: 0.50, blue: 0.20)
        case .hayato:    return Color(red: 0.80, green: 0.15, blue: 0.20)
        case .kage:      return Color(red: 0.30, green: 0.25, blue: 0.55)
        case .kai:       return Color(red: 0.95, green: 0.40, blue: 0.25)
        case .merlo:     return Color(red: 0.50, green: 0.30, blue: 0.85)
        case .lyra:      return Color(red: 0.30, green: 0.68, blue: 0.40)
        case .kaeptnRex: return Color(red: 0.20, green: 0.50, blue: 0.60)
        case .crashDummy: return Color(red: 0.90, green: 0.68, blue: 0.10)
        }
    }

    /// Ganze Figur (für Karten, Trophy Road).
    var imageName: String { sceneName }

    /// Brustbild (für runde Avatare wie Popups und Profil).
    var avatarImageName: String { sceneName + "Avatar" }

    /// Animation für die Karte: aus dem 3D-Modell gerendert (schräg von oben), Bilder nebeneinander.
    var mapSheetName: String { sceneName + "MapSheet" }
    static let mapSheetFrames = 16

    /// Figuren, die man auf der Trophy Road beim Rang mit dieser Trophäen-Grenze bekommt.
    static func rankRewards(atTrophies min: Int) -> [GameCharacter] {
        GameCharacter.allCases.filter {
            if case .rank(_, let n) = $0.requirement { return n == min }
            return false
        }
    }
}

/// Freischalt-Bedingung einer Figur – gleiche Typen wie im Backend (`CharacterCatalog.Requirement`).
enum UnlockRequirement: Equatable {
    case none
    case wins(Int)
    case knowledgeWins(Int)
    case checkins(Int)
    /// Rang auf der Trophy Road (einmal erreicht – bleibt frei, auch wenn man wieder abrutscht)
    case rank(String, trophies: Int)
    /// Belohnung eines Events (Aufgaben → Events) – bleibt nach dem Abholen für immer
    case event(String)

    var required: Int {
        switch self {
        case .none: return 0
        case .event: return 1
        case .wins(let n), .knowledgeWins(let n), .checkins(let n), .rank(_, let n): return n
        }
    }


    /// z.B. "3 Siege", "5 Check-ins" – für gesperrte Figuren im Editor.
    func text(progress: Int? = nil) -> String {
        let p = progress.map { "\(min($0, required))/" } ?? ""
        switch self {
        case .none:                 return "Frei"
        case .wins(let n):          return "\(p)\(n) \(n == 1 && progress == nil ? "Sieg" : "Siege")"
        case .knowledgeWins(let n): return "\(p)\(n) Quiz-Siege"
        case .checkins(let n):      return "\(p)\(n) Check-ins"
        case .rank(let name, let n): return progress == nil ? "Rang \(name)" : "Rang \(name) · \(p)\(n)"
        case .event(let name):      return name
        }
    }
}
