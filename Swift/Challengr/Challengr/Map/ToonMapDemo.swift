#if DEBUG
import SwiftUI
import MapKit

/// Nur Entwickler-Builds: Cartoon-Karte ohne Login ansehen (Start mit AUDIT_TOON_DEMO=1).
/// Schule mit ein paar Figuren und Hotspots, Karte dreht sich langsam (Leistungstest).
struct ToonMapDemo: View {
    @State private var heading = 0.0
    @State private var distance = 700.0
    @State private var failed: String?
    private let school = CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138)

    private var camera: MapCamera {
        MapCamera(centerCoordinate: school, distance: distance, heading: heading, pitch: MapView.mapPitch)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ToonMapView(camera: camera, pins: pins, circles: circles) { failed = $0 }
                .ignoresSafeArea()
            if let failed {
                Text("Fehler: \(failed)").padding().background(.red).foregroundStyle(.white)
            }
        }
        .task {
            let env = ProcessInfo.processInfo.environment
            if let d = env["AUDIT_TOON_DISTANCE"].flatMap(Double.init) { distance = d }
            guard env["AUDIT_TOON_SPIN"] != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                heading = (heading + 0.4).truncatingRemainder(dividingBy: 360)
            }
        }
    }

    private var pins: [ToonPin] {
        let characters: [GameCharacter] = [.merlo, .kage, .sirBrecht, .lyra, .kai, .ragnar]
        var list = characters.enumerated().map { i, c in
            let a = Double(i) / Double(characters.count) * 2 * .pi
            let coord = CLLocationCoordinate2D(latitude: school.latitude + 0.0009 * sin(a), longitude: school.longitude + 0.0013 * cos(a))
            return ToonPin(id: c.rawValue, coordinate: coord, label: c.displayName, priority: 1,
                           content: AnyView(MapCharacterPin(character: c, ringColor: .challengrRed, seed: c.rawValue)))
        }
        list.append(ToonPin(id: "spot", coordinate: CLLocationCoordinate2D(latitude: 48.2702, longitude: 14.2530), label: "Volksgarten",
                            content: AnyView(HotspotMarker(name: "Park", checkedIn: false, symbol: "tree.fill"))))
        list.append(ToonPin(id: "me", coordinate: school, label: "Du", priority: 2,
                            content: AnyView(MapCharacterPin(character: .crashDummy, ringColor: .challengrYellow, sonar: true, seed: "me"))))
        return list
    }

    private var circles: [ToonCircle] {
        [ToonCircle(id: "range", center: school, radius: 200, kind: .range),
         ToonCircle(id: "spot", center: CLLocationCoordinate2D(latitude: 48.2702, longitude: 14.2530), radius: 80, kind: .hotspot)]
    }
}
#endif
