import SwiftUI
import MapKit
import MapLibre
import Combine

// Cartoon-Karte (MapLibre + OpenStreetMap-Daten von OpenFreeMap, Stil in ToonMapStyle.json).
// Sicher gebaut: die Kamera kommt weiter aus MapView (gleiche Logik wie bei der Apple-Karte),
// die Karte selbst nimmt keine Berührungen an (Gesten macht MapView), Figuren und Hotspots sind
// die gleichen SwiftUI-Pins – nur auf die Karte umgerechnet. Lädt der Stil nicht, meldet sie
// `onFailure` und MapView zeigt wieder die Apple-Karte.

/// Ein Pin über der Karte (unten mittig auf der Koordinate, wie `Annotation(anchor: .bottom)`).
struct ToonPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    /// Name unter dem Pin (wie bei MapKit-Annotationen); leer = keiner
    var label: String = ""
    /// höher = weiter vorne (eigener Spieler)
    var priority: Int = 0
    let content: AnyView
}

/// Ein Kreis auf dem Boden (Reichweite, Hotspot-Radius) – von MapLibre gezeichnet, liegt also schräg mit der Karte.
struct ToonCircle: Equatable {
    enum Kind { case range, hotspot }
    let id: String
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let kind: Kind

    static func == (a: ToonCircle, b: ToonCircle) -> Bool {
        a.id == b.id && a.kind == b.kind && a.radius == b.radius
            && a.center.latitude == b.center.latitude && a.center.longitude == b.center.longitude
    }
}

/// Namen, die sich überlappen würden: der weniger wichtige (bzw. weiter hinten liegende) wird ausgeblendet.
enum ToonLabels {
    static let width: CGFloat = 110, height: CGFloat = 18

    static func hidden(_ pins: [(id: String, point: CGPoint, priority: Int)]) -> Set<String> {
        var shown: [(CGRect, Int)] = []
        var hidden = Set<String>()
        // wichtige und vordere zuerst
        for pin in pins.sorted(by: { ($0.priority, $0.point.y) > ($1.priority, $1.point.y) }) {
            let rect = CGRect(x: pin.point.x - width / 2, y: pin.point.y, width: width, height: height)
            if shown.contains(where: { $0.0.intersects(rect) }) {
                hidden.insert(pin.id)
            } else {
                shown.append((rect, pin.priority))
            }
        }
        return hidden
    }
}

/// Umrechnung MapKit-Kamera ↔ MapLibre (testbar).
enum ToonCamera {
    /// MapKit-Abstand → MapLibre-Zoomstufe. Abgestimmt am Prototyp: 700 m ≈ Zoom 16,4
    /// (doppelter Abstand = eine Zoomstufe weniger), damit beide Karten gleich viel zeigen.
    static let referenceDistance: CLLocationDistance = 700
    static let referenceZoom = 16.4

    static func zoom(distance: CLLocationDistance) -> Double {
        referenceZoom - log2(max(distance, 1) / referenceDistance)
    }

    /// Kreis als Vieleck (für MapLibre), Punkte im Uhrzeigersinn.
    static func polygon(center: CLLocationCoordinate2D, radius: CLLocationDistance, points: Int = 48) -> [CLLocationCoordinate2D] {
        let dLat = radius / 111_320
        let dLon = radius / (111_320 * max(0.01, cos(center.latitude * .pi / 180)))
        return (0...points).map { i in
            let a = Double(i) / Double(points) * 2 * .pi
            return CLLocationCoordinate2D(latitude: center.latitude + dLat * sin(a), longitude: center.longitude + dLon * cos(a))
        }
    }
}

/// Hält die MapLibre-Ansicht und meldet, wenn sich der Kartenausschnitt bewegt (Pins neu platzieren).
@MainActor
final class ToonMapProjector: ObservableObject {
    @Published private(set) var tick = 0
    weak var mapView: MLNMapView?

    func changed() { tick &+= 1 }

    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard let mapView else { return nil }
        return mapView.convert(coordinate, toPointTo: mapView)
    }
}

struct ToonMapView: View {
    /// Kamera aus MapView (MapKit-Werte: Abstand, Neigung, Richtung)
    let camera: MapCamera?
    let pins: [ToonPin]
    let circles: [ToonCircle]
    var night: Double = 0
    var onFailure: (String) -> Void = { _ in }

    @StateObject private var projector = ToonMapProjector()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ToonMapRepresentable(camera: camera, circles: circles, projector: projector, onFailure: onFailure)
                    .allowsHitTesting(false)
                // Fläche, die Berührungen annimmt – sonst kämen Wischen/Zoomen nur an, wenn man eine Figur trifft
                Color.clear
                    .contentShape(Rectangle())

                // Nachts dunkler (die Apple-Karte hat einen Nachtmodus, MapLibre bekommt eine Abdunklung)
                if night > 0.01 {
                    Color(red: 0.04, green: 0.06, blue: 0.2).opacity(0.45 * night)
                        .allowsHitTesting(false)
                }

                pinLayer(size: geo.size)

                // Quellenangabe (Pflicht für OpenStreetMap-Daten)
                Text("© OpenFreeMap © OpenStreetMap")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.6)))
                    .position(x: 95, y: geo.size.height - 22)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Pins an ihre Bildschirmposition setzen; hinten (oben am Bildschirm) zuerst, damit vordere davor liegen.
    @ViewBuilder
    private func pinLayer(size: CGSize) -> some View {
        let _ = projector.tick
        let placed: [(ToonPin, CGPoint)] = pins.compactMap { pin in
            guard let p = projector.point(for: pin.coordinate),
                  p.x > -80, p.x < size.width + 80, p.y > -40, p.y < size.height + 160 else { return nil }
            return (pin, p)
        }
        .sorted { ($0.1.y, $0.0.priority) < ($1.1.y, $1.0.priority) }
        let hiddenLabels = ToonLabels.hidden(placed.map { (id: $0.0.id, point: $0.1, priority: $0.0.priority) })

        ForEach(placed, id: \.0.id) { pin, point in
            VStack(spacing: 1) {
                pin.content
                if !pin.label.isEmpty, !hiddenLabels.contains(pin.id) {
                    Text(pin.label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.challengrDark)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(.white.opacity(0.75)))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            // Fuß der Figur auf der Koordinate (Name hängt darunter)
            .alignmentGuide(VerticalAlignment.center) { d in
                d[.bottom] - (pin.label.isEmpty || hiddenLabels.contains(pin.id) ? 0 : 16)
            }
            .frame(width: 0, height: 0)
            .position(point)
        }
    }
}

/// MapLibre-Ansicht, die meldet, wenn sie ihre (neue) Größe bekommt – die Kamera hängt von der Größe ab.
final class ToonMLNMapView: MLNMapView {
    var onResize: ((ToonMLNMapView) -> Void)?
    private var lastSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize, bounds.width > 0, bounds.height > 0 else { return }
        lastSize = bounds.size
        onResize?(self)
    }
}

/// Prüft, ob die Cartoon-Karte wirklich Kartendaten zeigt.
@MainActor
enum ToonMapHealth {
    /// Wartezeiten zwischen den Prüfungen (zusammen 20 s)
    static let checkSeconds: [Double] = [8, 12]

    /// Irgendein Kartenelement (Straße, Fläche, Gewässer, Gebäude) im Bild?
    static func hasMapContent(_ mapView: MLNMapView) -> Bool {
        guard let style = mapView.style else { return false }
        let ids = Set(style.layers.compactMap { layer -> String? in
            (layer as? MLNVectorStyleLayer)?.sourceIdentifier == "o" ? layer.identifier : nil
        })
        guard !ids.isEmpty else { return false }
        return !mapView.visibleFeatures(in: mapView.bounds, styleLayerIdentifiers: ids).isEmpty
    }
}

/// Die eigentliche MapLibre-Ansicht.
private struct ToonMapRepresentable: UIViewRepresentable {
    let camera: MapCamera?
    let circles: [ToonCircle]
    let projector: ToonMapProjector
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(projector: projector, onFailure: onFailure) }

    func makeUIView(context: Context) -> ToonMLNMapView {
        MLNLoggingConfiguration.shared.loggingLevel = .error
        var styleURL = Bundle.main.url(forResource: "ToonMapStyle", withExtension: "json")
        #if DEBUG
        // Test des Sicherheitsnetzes: Kartenserver nicht erreichbar
        if ProcessInfo.processInfo.environment["AUDIT_TOON_BADSERVER"] != nil, let url = styleURL,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let broken = FileManager.default.temporaryDirectory.appendingPathComponent("ToonMapStyleBroken.json")
            try? text.replacingOccurrences(of: "tiles.openfreemap.org", with: "nicht-erreichbar.invalid")
                .write(to: broken, atomically: true, encoding: .utf8)
            styleURL = broken
        }
        #endif
        let view = ToonMLNMapView(frame: .zero, styleURL: styleURL)
        view.onResize = { [weak coordinator = context.coordinator] view in coordinator?.applyCamera(to: view, animated: false) }
        view.delegate = context.coordinator
        // Gesten macht MapView (gleich wie bei der Apple-Karte) – hier nichts
        view.isUserInteractionEnabled = false
        view.isScrollEnabled = false
        view.isZoomEnabled = false
        view.isRotateEnabled = false
        view.isPitchEnabled = false
        view.logoView.isHidden = true
        view.attributionButton.isHidden = true   // Quellenangabe zeigt ToonMapView selbst
        view.compassView.isHidden = true
        view.showsUserLocation = false
        view.minimumZoomLevel = 12
        view.maximumZoomLevel = 19
        view.maximumPitch = 60
        projector.mapView = view
        if styleURL == nil { onFailure("Kartenstil fehlt im App-Paket") }
        return view
    }

    func updateUIView(_ view: ToonMLNMapView, context: Context) {
        let coordinator = context.coordinator
        if let camera, coordinator.lastCamera.map({ !Self.same($0, camera) }) ?? true {
            coordinator.lastCamera = camera
            let animated = context.transaction.animation != nil && !context.transaction.disablesAnimations
            coordinator.applyCamera(to: view, animated: animated)
        }
        coordinator.circles = circles
        coordinator.applyCircles(to: view)
    }

    static func same(_ a: MapCamera, _ b: MapCamera) -> Bool {
        abs(a.centerCoordinate.latitude - b.centerCoordinate.latitude) < 1e-7
            && abs(a.centerCoordinate.longitude - b.centerCoordinate.longitude) < 1e-7
            && abs(a.distance - b.distance) < 0.5 && abs(a.heading - b.heading) < 0.05 && abs(a.pitch - b.pitch) < 0.05
    }

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        let projector: ToonMapProjector
        let onFailure: (String) -> Void
        var lastCamera: MapCamera?
        var circles: [ToonCircle] = []
        private var appliedCircles: [ToonCircle]? = nil
        private var rangeSource: MLNShapeSource?
        private var hotspotSource: MLNShapeSource?

        init(projector: ToonMapProjector, onFailure: @escaping (String) -> Void) {
            self.projector = projector
            self.onFailure = onFailure
        }

        /// Kamera setzen – erst wenn die Ansicht eine Größe hat (sonst rechnet MapLibre die Zoomstufe falsch).
        func applyCamera(to view: MLNMapView, animated: Bool) {
            guard let camera = lastCamera, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let altitude = MLNAltitudeForZoomLevel(ToonCamera.zoom(distance: camera.distance), camera.pitch,
                                                   camera.centerCoordinate.latitude, view.bounds.size)
            let target = MLNMapCamera(lookingAtCenter: camera.centerCoordinate, altitude: altitude,
                                      pitch: camera.pitch, heading: camera.heading)
            if animated {
                view.setCamera(target, withDuration: 0.35, animationTimingFunction: CAMediaTimingFunction(name: .easeOut))
            } else {
                view.setCamera(target, animated: false)
            }
            projector.changed()
        }

        nonisolated func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MainActor.assumeIsolated {
                addCircleLayers(to: style)
                appliedCircles = nil
                applyCircles(to: mapView)
                projector.changed()
                startWatchdog(mapView)
            }
        }

        /// Wächter: Ist der Kartenserver nicht erreichbar, meldet MapLibre keinen Fehler, sondern zeigt nur
        /// eine leere Fläche. Ist nach 8 s (und nochmal 12 s später) nichts von der Karte zu sehen → Apple-Karte.
        private var watchdog: Task<Void, Never>?

        private func startWatchdog(_ mapView: MLNMapView) {
            watchdog?.cancel()
            watchdog = Task { [weak self, weak mapView] in
                for wait in ToonMapHealth.checkSeconds {
                    try? await Task.sleep(for: .seconds(wait))
                    guard !Task.isCancelled, let self, let mapView else { return }
                    if ToonMapHealth.hasMapContent(mapView) { return }
                }
                guard !Task.isCancelled, let self else { return }
                self.onFailure("Kartenserver nicht erreichbar")
            }
        }

        deinit { watchdog?.cancel() }

        nonisolated func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            let message = error.localizedDescription
            MainActor.assumeIsolated { onFailure(message) }
        }

        nonisolated func mapViewRegionIsChanging(_ mapView: MLNMapView) {
            MainActor.assumeIsolated { projector.changed() }
        }

        nonisolated func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            MainActor.assumeIsolated { projector.changed() }
        }

        /// Zwei Quellen (Reichweite rot gestrichelt, Hotspots gelb) unter die Gebäude legen.
        private func addCircleLayers(to style: MLNStyle) {
            let range = MLNShapeSource(identifier: "challengr-range", shape: nil, options: nil)
            let hotspots = MLNShapeSource(identifier: "challengr-hotspots", shape: nil, options: nil)
            style.addSource(range)
            style.addSource(hotspots)
            rangeSource = range
            hotspotSource = hotspots

            let rangeFill = MLNFillStyleLayer(identifier: "challengr-range-fill", source: range)
            rangeFill.fillColor = NSExpression(forConstantValue: UIColor(Color.challengrRed).withAlphaComponent(0.12))
            let rangeLine = MLNLineStyleLayer(identifier: "challengr-range-line", source: range)
            rangeLine.lineColor = NSExpression(forConstantValue: UIColor(Color.challengrRed).withAlphaComponent(0.8))
            rangeLine.lineWidth = NSExpression(forConstantValue: 2.5)
            rangeLine.lineDashPattern = NSExpression(forConstantValue: [4, 2.4])

            let spotFill = MLNFillStyleLayer(identifier: "challengr-hotspot-fill", source: hotspots)
            spotFill.fillColor = NSExpression(forConstantValue: UIColor(Color.challengrYellow).withAlphaComponent(0.25))
            let spotLine = MLNLineStyleLayer(identifier: "challengr-hotspot-line", source: hotspots)
            spotLine.lineColor = NSExpression(forConstantValue: UIColor(Color.challengrYellow))
            spotLine.lineWidth = NSExpression(forConstantValue: 2)

            // unter die 3D-Gebäude, damit Häuser die Kreise verdecken wie in echt
            if let buildings = style.layer(withIdentifier: "bld") {
                for layer in [rangeFill, rangeLine, spotFill, spotLine] { style.insertLayer(layer, below: buildings) }
            } else {
                for layer in [rangeFill, rangeLine, spotFill, spotLine] { style.addLayer(layer) }
            }
        }

        /// Kreise nur neu setzen, wenn sie sich geändert haben (spart Arbeit bei jedem Standort-Update).
        func applyCircles(to view: MLNMapView) {
            guard let rangeSource, let hotspotSource, appliedCircles != circles else { return }
            appliedCircles = circles
            func shape(_ kind: ToonCircle.Kind) -> MLNShapeCollectionFeature {
                let polygons = circles.filter { $0.kind == kind }.map { c -> MLNPolygonFeature in
                    var coords = ToonCamera.polygon(center: c.center, radius: c.radius)
                    return MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                }
                return MLNShapeCollectionFeature(shapes: polygons)
            }
            rangeSource.shape = shape(.range)
            hotspotSource.shape = shape(.hotspot)
        }
    }
}
