import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Wir erzeugen 80 kleine Konfetti-Teile
                ForEach(0..<80, id: \.self) { _ in
                    ConfettiPiece()
                        // Starten oben über dem Rand, fallen nach ganz unten
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: animate ? geometry.size.height + 100 : -100
                        )
                        .animation(
                            .linear(duration: Double.random(in: 2.5...5.0))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...2.0)),
                            value: animate
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false) // Damit man durch das Konfetti durchklicken kann
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    @State private var rotation: Double = Double.random(in: 0...360)
    @State private var spin3D: Double = 0
    
    let colors: [Color] = [.challengrRed, .challengrYellow, .challengrGreen, .blue, .purple, .pink, .orange]
    let size: CGFloat = CGFloat.random(in: 8...16)
    let color: Color
    
    init() {
        self.color = colors.randomElement() ?? .yellow
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            // Längliches Konfetti
            .frame(width: size, height: size * 1.5)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(spin3D), axis: (x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1), z: 0))
            .onAppear {
                // Zweiseitige Drehung (Papiertaumeln)
                withAnimation(
                    .linear(duration: Double.random(in: 1...3))
                    .repeatForever(autoreverses: false)
                ) {
                    rotation += 360
                }
                
                withAnimation(
                    .linear(duration: Double.random(in: 0.5...1.5))
                    .repeatForever(autoreverses: true)
                ) {
                    spin3D = 180
                }
            }
    }
}
