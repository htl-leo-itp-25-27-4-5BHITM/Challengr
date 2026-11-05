import Foundation
import CoreLocation

/// Gleicher „Zufall“ für beide Spieler eines Battles: aus der Battle-Nummer abgeleitet.
/// So bekommen beide dasselbe Land, denselben Zielwinkel, dieselbe Zielzeit und dieselben Wartezeiten.
struct ChallengeSeed {
    private var state: UInt64

    init(battleId: Int64, salt: UInt64 = 0) {
        state = UInt64(bitPattern: battleId) &* 0x9E37_79B9_7F4A_7C15 &+ salt &+ 0x1234_5678
    }

    /// SplitMix64 – auf jedem Gerät identisch (Swift's Zufall ist es nicht).
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(in range: Range<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(next() % 1_000_000) / 1_000_000 * (range.upperBound - range.lowerBound)
    }

    /// Zielwinkel der Kompass-Challenge
    static func compassTarget(battleId: Int64) -> Int {
        var s = ChallengeSeed(battleId: battleId, salt: 1)
        return s.int(in: 0..<360)
    }

    /// Land der Länder-Kompass-Challenge
    static func country(battleId: Int64) -> Country {
        var s = ChallengeSeed(battleId: battleId, salt: 2)
        return Country.all[s.int(in: 0..<Country.all.count)]
    }

    /// Wartezeiten bis „grün“ im Reaktions-Test (3 Runden, 1,5–4 s)
    static func reactionDelays(battleId: Int64) -> [Double] {
        var s = ChallengeSeed(battleId: battleId, salt: 3)
        return (0..<ReactionRules.rounds).map { _ in s.double(in: 1.5...4.0) }
    }

    /// Zielzeit des Zeitgefühls (5–10 s)
    static func timingTarget(battleId: Int64) -> Int {
        var s = ChallengeSeed(battleId: battleId, salt: 4)
        return [5, 6, 7, 8, 10][s.int(in: 0..<5)]
    }
}

/// Ein Land mit seiner Hauptstadt (dorthin zeigt man).
struct Country: Equatable {
    let name: String
    let flag: String
    let capital: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    /// Gut bekannte Länder rund um die Welt (Richtungen bunt gemischt).
    static let all: [Country] = [
        Country(name: "Italien", flag: "🇮🇹", capital: "Rom", latitude: 41.90, longitude: 12.50),
        Country(name: "Frankreich", flag: "🇫🇷", capital: "Paris", latitude: 48.86, longitude: 2.35),
        Country(name: "Spanien", flag: "🇪🇸", capital: "Madrid", latitude: 40.42, longitude: -3.70),
        Country(name: "England", flag: "🇬🇧", capital: "London", latitude: 51.51, longitude: -0.13),
        Country(name: "Deutschland", flag: "🇩🇪", capital: "Berlin", latitude: 52.52, longitude: 13.40),
        Country(name: "Polen", flag: "🇵🇱", capital: "Warschau", latitude: 52.23, longitude: 21.01),
        Country(name: "Griechenland", flag: "🇬🇷", capital: "Athen", latitude: 37.98, longitude: 23.73),
        Country(name: "Türkei", flag: "🇹🇷", capital: "Ankara", latitude: 39.93, longitude: 32.86),
        Country(name: "Schweden", flag: "🇸🇪", capital: "Stockholm", latitude: 59.33, longitude: 18.07),
        Country(name: "Norwegen", flag: "🇳🇴", capital: "Oslo", latitude: 59.91, longitude: 10.75),
        Country(name: "Island", flag: "🇮🇸", capital: "Reykjavík", latitude: 64.15, longitude: -21.94),
        Country(name: "Portugal", flag: "🇵🇹", capital: "Lissabon", latitude: 38.72, longitude: -9.14),
        Country(name: "Ägypten", flag: "🇪🇬", capital: "Kairo", latitude: 30.04, longitude: 31.24),
        Country(name: "Marokko", flag: "🇲🇦", capital: "Rabat", latitude: 34.02, longitude: -6.83),
        Country(name: "Südafrika", flag: "🇿🇦", capital: "Pretoria", latitude: -25.75, longitude: 28.19),
        Country(name: "Kenia", flag: "🇰🇪", capital: "Nairobi", latitude: -1.29, longitude: 36.82),
        Country(name: "USA", flag: "🇺🇸", capital: "Washington", latitude: 38.91, longitude: -77.04),
        Country(name: "Kanada", flag: "🇨🇦", capital: "Ottawa", latitude: 45.42, longitude: -75.70),
        Country(name: "Mexiko", flag: "🇲🇽", capital: "Mexiko-Stadt", latitude: 19.43, longitude: -99.13),
        Country(name: "Brasilien", flag: "🇧🇷", capital: "Brasília", latitude: -15.79, longitude: -47.88),
        Country(name: "Argentinien", flag: "🇦🇷", capital: "Buenos Aires", latitude: -34.60, longitude: -58.38),
        Country(name: "Japan", flag: "🇯🇵", capital: "Tokio", latitude: 35.68, longitude: 139.69),
        Country(name: "China", flag: "🇨🇳", capital: "Peking", latitude: 39.90, longitude: 116.41),
        Country(name: "Indien", flag: "🇮🇳", capital: "Neu-Delhi", latitude: 28.61, longitude: 77.21),
        Country(name: "Australien", flag: "🇦🇺", capital: "Canberra", latitude: -35.28, longitude: 149.13),
        Country(name: "Russland", flag: "🇷🇺", capital: "Moskau", latitude: 55.76, longitude: 37.62),
        Country(name: "Thailand", flag: "🇹🇭", capital: "Bangkok", latitude: 13.76, longitude: 100.50),
        Country(name: "Saudi-Arabien", flag: "🇸🇦", capital: "Riad", latitude: 24.71, longitude: 46.68),
    ]

    /// Richtung (0° = Norden, 90° = Osten) vom Standort zur Hauptstadt – auf dem kürzesten Weg über die Erde.
    func bearing(from c: CLLocationCoordinate2D) -> Double {
        let φ1 = c.latitude * .pi / 180, φ2 = latitude * .pi / 180
        let Δλ = (longitude - c.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }
}

/// Kleinster Winkel zwischen zwei Richtungen (0–180°).
func angleBetween(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

/// Regeln des Reaktions-Tests.
enum ReactionRules {
    static let rounds = 3
    /// Zu früh getippt oder gar nicht: diese Zeit zählt für die Runde
    static let penaltyMs = 1000.0
    /// Wer nach so langer Zeit nicht tippt, bekommt die Strafzeit
    static let maxWaitMs = 2000.0

    static func average(_ times: [Double]) -> Double {
        guard !times.isEmpty else { return penaltyMs }
        return times.reduce(0, +) / Double(times.count)
    }
}
