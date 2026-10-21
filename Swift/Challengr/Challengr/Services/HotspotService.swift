import Foundation
import CoreLocation

/// Check-in-Punkt vom Backend: fest (die Schule) oder ein Ort aus OpenStreetMap (Park, Museum, Brunnen …).
struct HotspotDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let points: Int
    let firstOfDayBonus: Int
    let checkedInToday: Bool
    let checkinsToday: Int
    /// "school" oder "landmark" (nil bei alten Servern = fester Hotspot)
    var kind: String? = nil
    /// park, museum, fountain, library, square, monument, castle, theatre, viewpoint, attraction, zoo, stadium
    var category: String? = nil

    var isLandmark: Bool { kind == "landmark" }

    /// Symbol für die Art des Ortes
    var symbol: String {
        switch category {
        case "park":       return "tree.fill"
        case "museum":     return "building.columns.fill"
        case "fountain":   return "drop.fill"
        case "library":    return "books.vertical.fill"
        case "square":     return "square.grid.3x3.fill"
        case "monument":   return "building.fill"
        case "castle":     return "crown.fill"
        case "theatre":    return "theatermasks.fill"
        case "viewpoint":  return "binoculars.fill"
        case "zoo":        return "pawprint.fill"
        case "stadium":    return "sportscourt.fill"
        case "attraction": return "star.fill"
        default:           return isLandmark ? "mappin.circle.fill" : "graduationcap.fill"
        }
    }

    /// Unterzeile im Popup
    var kindText: String {
        guard isLandmark else { return "HOTSPOT · 1 CHECK-IN PRO TAG" }
        let name: String
        switch category {
        case "park": name = "PARK"
        case "museum": name = "MUSEUM"
        case "fountain": name = "BRUNNEN"
        case "library": name = "BIBLIOTHEK"
        case "square": name = "PLATZ"
        case "monument": name = "BAUWERK"
        case "castle": name = "BURG & SCHLOSS"
        case "theatre": name = "KULTUR"
        case "viewpoint": name = "AUSSICHT"
        case "zoo": name = "ZOO"
        case "stadium": name = "STADION"
        default: name = "SEHENSWÜRDIGKEIT"
        }
        return "\(name) · 1 CHECK-IN PRO TAG"
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct HotspotCheckinResult: Codable, Equatable {
    let hotspotId: String
    let points: Int
    let firstOfDay: Bool
    let totalPoints: Int
}

enum HotspotError: LocalizedError, Equatable {
    case tooFar, alreadyCheckedIn, dailyLimit, failed(Int)

    var errorDescription: String? {
        switch self {
        case .tooFar:           return "Du bist zu weit weg – geh näher hin."
        case .alreadyCheckedIn: return "Heute schon eingecheckt – morgen wieder!"
        case .dailyLimit:       return "Heute schon 5 Orte besucht – morgen geht's weiter!"
        case .failed(let code): return "Check-in hat nicht geklappt (\(code))."
        }
    }
}

final class HotspotService {
    private let baseURL = BackendConfig.apiURL("api/hotspots")

    func load(playerId: String) async throws -> [HotspotDTO] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        let (data, _) = try await API.data(from: components.url!)
        return try JSONDecoder().decode([HotspotDTO].self, from: data)
    }

    func checkin(hotspotId: String, playerId: String, coordinate: CLLocationCoordinate2D) async throws -> HotspotCheckinResult {
        var request = URLRequest(url: baseURL.appendingPathComponent(hotspotId).appendingPathComponent("checkin"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "playerId": playerId, "latitude": coordinate.latitude, "longitude": coordinate.longitude
        ])
        let (data, response) = try await API.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200..<300: return try JSONDecoder().decode(HotspotCheckinResult.self, from: data)
        case 403:       throw HotspotError.tooFar
        case 409:       throw HotspotError.alreadyCheckedIn
        case 429:       throw HotspotError.dailyLimit
        default:        throw HotspotError.failed(code)
        }
    }
}

/// Was der Hotspot-Popup anzeigt (testbar).
enum HotspotState: Equatable {
    case checkedIn
    case inRange
    case tooFar(meters: Int)
    case noLocation

    static func of(_ hotspot: HotspotDTO, playerAt coordinate: CLLocationCoordinate2D?) -> HotspotState {
        if hotspot.checkedInToday { return .checkedIn }
        guard let coordinate else { return .noLocation }
        let d = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: hotspot.latitude, longitude: hotspot.longitude))
        return d <= hotspot.radiusMeters ? .inRange : .tooFar(meters: Int(d.rounded()))
    }
}

/// Wann man wieder einchecken kann: ab Mitternacht österreichischer Zeit (wie am Server).
enum HotspotSchedule {
    static let zone = TimeZone(identifier: "Europe/Vienna")!

    static func nextCheckin(after now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return calendar.startOfDay(for: tomorrow)
    }

    /// "7 Std 12 Min", "12 Min", "gleich"
    static func remainingText(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h) Std \(m) Min" }
        if m > 0 { return "\(m) Min" }
        return "gleich"
    }

    /// Kurz für den Marker: "7:12" bzw. "0:05"
    static func shortText(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    /// Orte neu laden? Nach 2 Minuten (der Server lädt neue Gegenden im Hintergrund) oder nach 400 m Weg.
    static func shouldReload(loadedAt: Date, from: CLLocationCoordinate2D?, now: Date = Date(),
                             position: CLLocationCoordinate2D?) -> Bool {
        if now.timeIntervalSince(loadedAt) > 120 { return true }
        guard let from, let position else { return false }
        return CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: position.latitude, longitude: position.longitude)) > 400
    }

    /// Nach Mitternacht sind die "heute schon eingecheckt"-Daten vom Server veraltet.
    static func isStale(loadedAt: Date, now: Date = Date()) -> Bool {
        now >= nextCheckin(after: loadedAt)
    }
}
