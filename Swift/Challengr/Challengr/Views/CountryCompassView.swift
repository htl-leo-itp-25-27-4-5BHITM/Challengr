import SwiftUI
import CoreLocation

/// Länder-Kompass: Ein Land wird angezeigt, man dreht sich in seine Richtung und tippt „Hier!“.
/// Wer weniger Grad danebenliegt, gewinnt. Beide bekommen dasselbe Land (aus der Battle-Nummer).
struct CountryCompassView: View {
    let battleId: Int64
    let socket: GameSocketService
    /// Eigener Standort (für die echte Richtung zur Hauptstadt)
    let position: CLLocationCoordinate2D?
    let onClose: () -> Void

    static let seconds = 15

    @StateObject private var compass = CompassManager()
    @State private var remaining = CountryCompassView.seconds
    @State private var locked: Double?
    @State private var sent = false
    @State private var timer: Timer?

    private var country: Country { ChallengeSeed.country(battleId: battleId) }
    /// Ohne Standort: Richtung von der Schule aus (Spieler stehen ohnehin nah beieinander)
    private var origin: CLLocationCoordinate2D { position ?? CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138) }
    private var target: Double { country.bearing(from: origin) }

    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            VStack(spacing: 22) {
                Text("LÄNDER-KOMPASS")
                    .font(.system(size: 15, weight: .black, design: .rounded)).tracking(2)
                    .foregroundColor(.challengrYellow)

                Text(country.flag).font(.system(size: 96))
                Text(country.name.uppercased())
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Hauptstadt: \(country.capital)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(GameStyle.secondaryText)

                if let locked {
                    reveal(yours: locked)
                } else {
                    Text("Halte dein Handy flach vor dir und dreh dich, bis es genau Richtung \(country.name) zeigt.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text("\(remaining)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(remaining <= 3 ? .challengrRed : .white)
                        .monospacedDigit()
                    Spacer()
                    GamePrimaryButton(title: "Hier!", color: .challengrGreen) { lock() }
                        .padding(.horizontal, 32)
                }
                Spacer(minLength: 20)
            }
            .padding(.top, 30)
        }
        .onAppear { start() }
        .onDisappear { timer?.invalidate() }
    }

    /// Auflösung: deine Richtung (gelb) und die richtige (grün) auf einer Kompassrose.
    private func reveal(yours: Double) -> some View {
        let off = angleBetween(yours, target)
        return VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 2).frame(width: 190, height: 190)
                Text("N").font(.system(size: 14, weight: .black)).foregroundColor(.challengrRed).offset(y: -110)
                needle(color: .challengrGreen).rotationEffect(.degrees(target))
                needle(color: .challengrYellow).rotationEffect(.degrees(yours))
                Circle().fill(Color.white).frame(width: 10, height: 10)
            }
            .frame(width: 230, height: 230)
            HStack(spacing: 18) {
                Label("Richtig", systemImage: "circle.fill").foregroundColor(.challengrGreen)
                Label("Du", systemImage: "circle.fill").foregroundColor(.challengrYellow)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            Text("\(Int(off.rounded()))° daneben")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(off < 20 ? .challengrGreen : .white)
        }
    }

    private func needle(color: Color) -> some View {
        Capsule().fill(color).frame(width: 6, height: 90).offset(y: -45)
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                remaining -= 1
                if (1...3).contains(remaining) { SoundManager.shared.play(.countdownTick) }
                if remaining <= 0 { lock() }
            }
        }
    }

    private func lock() {
        guard locked == nil else { return }
        timer?.invalidate()
        SoundManager.shared.play(.countdownGo)
        let heading = compass.heading
        locked = heading
        let deviation = angleBetween(heading, target)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !sent else { return }
            sent = true
            socket.sendMetricResult(type: "country-result", battleId: battleId, field: "deviation", value: deviation)
            onClose()
        }
    }
}
