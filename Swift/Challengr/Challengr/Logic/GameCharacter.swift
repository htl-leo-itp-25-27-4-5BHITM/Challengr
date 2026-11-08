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
    case frost = "frost"
    // Skins (andere Optik einer Figur, eigenes Modell)
    case sirBrechtBlitz = "sir-brecht-blitz"
    case kaeptnRexJaeger = "kaeptn-rex-jaeger"
    case ragnarKristall = "ragnar-kristall"
    // Geheim (nirgends angekündigt)
    case glitch = "glitch"

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

    /// Bei Skins die Figur, zu der der Skin gehört (eigenes Modell, gleiche Rivalen).
    var skinOf: GameCharacter? {
        switch self {
        case .sirBrechtBlitz: return .sirBrecht
        case .kaeptnRexJaeger: return .kaeptnRex
        case .ragnarKristall: return .ragnar
        default: return nil
        }
    }

    var isSkin: Bool { skinOf != nil }

    /// Grundfigur (Skins → ihre Figur, sonst die Figur selbst).
    var base: GameCharacter { skinOf ?? self }

    /// Skins dieser Figur.
    var skins: [GameCharacter] { GameCharacter.allCases.filter { $0.skinOf == self } }

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
        case .frost:     return "Frost"
        case .sirBrechtBlitz: return "Blitzritter"
        case .kaeptnRexJaeger: return "Kopfgeldjäger"
        case .ragnarKristall: return "Kristall-Ragnar"
        case .glitch:    return "Glitch"
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
        case .frost:            return "Eis-Boarderin · Event"
        case .sirBrechtBlitz:   return "Legendärer Skin · Sir Brecht"
        case .kaeptnRexJaeger:  return "Mythischer Skin · Käpt'n Rex"
        case .ragnarKristall:   return "Boss-Skin · Ragnar"
        case .glitch:           return "Geheim · Fehler im System"
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
        case .frost:            return .event("Winter-Event")
        case .sirBrechtBlitz:   return .rank("Challengr", trophies: 2000)
        case .kaeptnRexJaeger:  return .bounties(5)
        case .ragnarKristall:   return .shards(60)
        case .glitch:           return .secret
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
        case .frost:     return "Frost"
        case .sirBrechtBlitz: return "SirBrechtBlitz"
        case .kaeptnRexJaeger: return "RexJaeger"
        case .ragnarKristall: return "RagnarKristall"
        case .glitch:    return "Glitch"
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
        case .frost:     return Color(red: 0.25, green: 0.55, blue: 0.85)
        case .sirBrechtBlitz: return Color(red: 0.16, green: 0.13, blue: 0.22)
        case .kaeptnRexJaeger: return Color(red: 0.45, green: 0.06, blue: 0.12)
        case .ragnarKristall: return Color(red: 0.42, green: 0.22, blue: 0.7)
        case .glitch:    return Color(red: 0.25, green: 0.1, blue: 0.45)
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
    /// Kassierte Kopfgelder (mythischer Skin)
    case bounties(Int)
    /// Riss-Splitter aus Riss-Wächter-Kämpfen (Boss-Skins)
    case shards(Int)
    /// Geheimnis – Bedingung wird nicht verraten
    case secret

    var required: Int {
        switch self {
        case .none: return 0
        case .event, .secret: return 1
        case .wins(let n), .knowledgeWins(let n), .checkins(let n), .rank(_, let n), .bounties(let n), .shards(let n): return n
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
        case .bounties(let n):      return "\(p)\(n) Kopfgelder"
        case .shards(let n):        return "\(p)\(n) Riss-Splitter"
        case .secret:               return "???"
        case .rank(let name, let n): return progress == nil ? "Rang \(name)" : "Rang \(name) · \(p)\(n)"
        case .event(let name):      return name
        }
    }
}
