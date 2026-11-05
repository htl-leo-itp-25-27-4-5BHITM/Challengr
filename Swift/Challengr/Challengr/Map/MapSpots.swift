import CoreLocation

/// Gedränge auf der Karte: Der Server rundet Positionen auf ~50 m, auf dem Schulhof stehen also viele
/// Spieler auf demselben Punkt (und oft genau hinter der eigenen Figur). Wenige werden im Kreis aufgefächert,
/// bei vielen gibt es eine Figur mit Zahl, die eine Liste "Spieler hier" öffnet. Reine Rechenlogik (testbar).
enum MapSpots {
    /// So nah = derselbe Fleck
    static let sameSpotMeters: CLLocationDistance = 25
    /// Bis so viele (ohne einen selbst) werden aufgefächert, darüber Figur mit Zahl
    static let fanLimit = 5
    /// Abstand der aufgefächerten Figuren vom Mittelpunkt, auf dem Bildschirm
    static let fanRadiusPoints: Double = 46
    /// Grobe Umrechnung Kamera-Abstand → Meter pro Bildschirmpunkt (Karte gekippt, Hochformat)
    static let metersPerPointPerDistance: Double = 0.0014

    /// Ein Fleck mit mehreren Spielern; `ownSpot` = um die eigene Figur herum
    struct Spot: Equatable {
        let center: CLLocationCoordinate2D
        var playerIds: [String]
        var ownSpot = false

        var isCrowd: Bool { playerIds.count > MapSpots.fanLimit }

        static func == (a: Spot, b: Spot) -> Bool {
            a.playerIds == b.playerIds && a.ownSpot == b.ownSpot
                && a.center.latitude == b.center.latitude && a.center.longitude == b.center.longitude
        }
    }

    /// Wie die Spieler gerade gezeigt werden
    struct Layout {
        /// Verschobene Position je Spieler (aufgefächert); fehlt = an seiner echten Position
        var positions: [String: CLLocationCoordinate2D] = [:]
        /// Flecken mit Gedränge: Figur mit Zahl, öffnet die Liste
        var crowds: [Crowd] = []
        /// Spieler, die in einem Gedränge stecken (bekommen keinen eigenen Pin)
        var hidden: Set<String> = []
    }

    struct Crowd: Equatable, Identifiable {
        let coordinate: CLLocationCoordinate2D
        let playerIds: [String]

        var id: String { playerIds.joined(separator: ",") }

        static func == (a: Crowd, b: Crowd) -> Bool {
            a.playerIds == b.playerIds && a.coordinate.latitude == b.coordinate.latitude
                && a.coordinate.longitude == b.coordinate.longitude
        }
    }

    /// Spieler zu Flecken zusammenfassen; Reihenfolge nach ID, damit beim Aktualisieren nichts herumspringt.
    static func spots(players: [(id: String, coordinate: CLLocationCoordinate2D)],
                      own: CLLocationCoordinate2D?) -> [Spot] {
        var spots: [Spot] = []
        if let own { spots.append(Spot(center: own, playerIds: [], ownSpot: true)) }
        for p in players.sorted(by: { $0.id < $1.id }) {
            if let i = spots.firstIndex(where: { distance($0.center, p.coordinate) <= sameSpotMeters }) {
                spots[i].playerIds.append(p.id)
            } else {
                spots.append(Spot(center: p.coordinate, playerIds: [p.id]))
            }
        }
        return spots.filter { $0.playerIds.count > ($0.ownSpot ? 0 : 1) }
    }

    /// Wo jeder Pin hin soll – `cameraDistance` hält den Abstand auf dem Bildschirm gleich, egal wie weit gezoomt ist.
    static func layout(players: [(id: String, coordinate: CLLocationCoordinate2D)],
                       own: CLLocationCoordinate2D?, cameraDistance: CLLocationDistance) -> Layout {
        var layout = Layout()
        let meters = fanRadiusPoints * metersPerPointPerDistance * cameraDistance
        for spot in spots(players: players, own: own) {
            if spot.isCrowd {
                // Figur mit Zahl: auf fremdem Fleck in der Mitte, bei einem selbst daneben
                let at = spot.ownSpot ? offset(spot.center, meters: meters, angle: 0) : spot.center
                layout.crowds.append(Crowd(coordinate: at, playerIds: spot.playerIds))
                layout.hidden.formUnion(spot.playerIds)
                continue
            }
            // Kreis um den Mittelpunkt (bei einem selbst: um die eigene Figur); mehr Spieler → etwas weiter
            let n = spot.playerIds.count
            let radius = meters * max(1, Double(n) / 4)
            for (i, id) in spot.playerIds.enumerated() {
                let angle = Double(i) / Double(n) * 2 * .pi
                layout.positions[id] = offset(spot.center, meters: radius, angle: angle)
            }
        }
        return layout
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Punkt `meters` vom Mittelpunkt entfernt; Winkel 0 = Osten (rechts), dann gegen den Uhrzeigersinn
    static func offset(_ c: CLLocationCoordinate2D, meters: Double, angle: Double) -> CLLocationCoordinate2D {
        let dLat = meters * sin(angle) / 111_320
        let dLon = meters * cos(angle) / (111_320 * cos(c.latitude * .pi / 180))
        return CLLocationCoordinate2D(latitude: c.latitude + dLat, longitude: c.longitude + dLon)
    }
}
