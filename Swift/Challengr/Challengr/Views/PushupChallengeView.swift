import SwiftUI
import ARKit
import CoreMotion
import Combine

class PushupManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var reps = 0
    @Published var isWarning = false
    @Published var warningMessage = ""
    @Published var faceDistance: Float = 0.0
    
    private var session = ARSession()
    private var motionManager = CMMotionManager()
    private var isDown = false
    private var timer: Timer?
    
    func start() {
        // Face Tracking starten
        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.isWarning = true
                self.warningMessage = "Dein iPhone unterstützt kein Face-Tracking (TrueDepth nötig)."
            }
            return
        }
        
        let config = ARFaceTrackingConfiguration()
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Anti-Cheat: Geräte-Bewegung und Neigung (Pitch/Roll) überprüfen
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            // Wenn man xArbitraryZVertical benutzt, muss das Gerät vorher wissen wie "Z" steht.
            // Es ist sicherer, das normale Device-Verhalten zu nehmen und gravity zu prüfen!
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion else { return }
                
                // Anstelle von Attitude prüfen wir direkt den 3D-Gravitations-Vektor der Erde:
                // Wenn das Handy flach am Boden auf dem Rücken liegt, ist die Gravitation primär auf der Z-Achse (~ -1.0)
                // x und y (Neigung) sollten relativ klein sein (nahe 0.0)
                let gravX = abs(motion.gravity.x)
                let gravY = abs(motion.gravity.y)
                let gravZ = motion.gravity.z  // Normal ist ca. -1.0 wenn screen oben ist
                
                // Beschleunigung überprüfen (sollte sich fast nicht bewegen)
                let accelX = abs(motion.userAcceleration.x)
                let accelY = abs(motion.userAcceleration.y)
                let accelZ = abs(motion.userAcceleration.z)
                
                DispatchQueue.main.async {
                    // Toleranz bei Gravitation: X und Y (kippen) maximal 0.65 G
                    // Toleranz Gravitation Z: weniger restriktiv (damit auch Hüllen nicht stören)
                    if gravX > 0.65 || gravY > 0.65 || gravZ > -0.2 {
                        self.isWarning = true
                        self.warningMessage = "CHEATING: Lege das Handy auf den Boden! (Gravitation nicht richtig)"
                    } else if accelX > 0.8 || accelY > 0.8 || accelZ > 0.8 {
                        self.isWarning = true
                        self.warningMessage = "CHEATING: Das Handy wird bewegt!"
                    } else {
                        self.isWarning = false
                    }
                }
            }
        }
    }
    
    func stop() {
        session.pause()
        motionManager.stopDeviceMotionUpdates()
        timer?.invalidate()
    }
    
    func startTimer(onTick: @escaping () -> Void) {
        timer?.invalidate()
        // Der runloop mode .common erlaubt dem Timer auch zu triggern, wenn die UI beschäftigt ist
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                onTick()
            }
        }
        if let currentTimer = timer {
            RunLoop.main.add(currentTimer, forMode: .common)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Wir suchen das Gesicht
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        
        // Abstand vom Gesicht zur Kamera berechnen
        let transform = faceAnchor.transform
        let x = transform.columns.3.x
        let y = transform.columns.3.y
        let z = transform.columns.3.z
        
        let distance = sqrt(x*x + y*y + z*z) // Distanz in Metern
        
        DispatchQueue.main.async {
            self.faceDistance = distance
            
            // Liegestütz Zähl-Logik (aber nicht zählen wenn er gerade schummelt)
            if !self.isWarning {
                if distance < 0.25 && !self.isDown {
                    self.isDown = true
                    // Unten angekommen
                } else if distance > 0.35 && self.isDown {
                    self.isDown = false
                    // Wieder oben -> Zählen!
                    self.reps += 1
                }
            } else {
                // Wenn er beim Cheaten hoch oder runter geht, setzen wir das Event zurück
                // damit er keinen gratis rep bekommt wenn er das Handy aufhebt.
                self.isDown = false 
            }
        }
    }
}

struct PushupChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void
    
    @StateObject private var manager = PushupManager()
    @State private var timeRemaining = 30
    @State private var isFinished = false
    
    var body: some View {
        ZStack {
            Color.challengrDark.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("LIEGESTÜTZ CHALLENGE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.challengrYellow)
                    .padding(.top, 40)
                
                Text("Lege das Handy auf den Boden unters Gesicht! Gehe unter 25cm Abstand.")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if manager.isWarning {
                    Text(manager.warningMessage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(Color.challengrRed)
                        .cornerRadius(12)
                        .transition(.scale)
                }

                // Kameraabstand Anzeige immer sichtbar
                VStack {
                    Text("\(String(format: "%.1f", manager.faceDistance * 100)) cm")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(manager.faceDistance < 0.25 ? .challengrGreen : .challengrYellow)
                    Text("AKTUELLER ABSTAND")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Rep Counter
                ZStack {
                    Circle()
                        .stroke(Color.challengrYellow.opacity(0.3), lineWidth: 15)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(manager.reps, 30)) / 30.0)
                        .stroke(Color.challengrYellow, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: manager.reps)
                    
                    VStack {
                        Text("\(manager.reps)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("REPS")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.challengrYellow)
                    }
                }
                .frame(width: 250, height: 250)
                
                Spacer()
                
                Text(isFinished ? "ZEIT ABGELAUFEN!" : "00:\(String(format: "%02d", timeRemaining))")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(timeRemaining <= 5 ? .challengrRed : .white)
                
                if isFinished {
                    GamePrimaryButton(title: "ERGEBNIS SENDEN", color: .challengrGreen) {
                        socket.sendPushupResult(battleId: battleId, reps: manager.reps)
                        onClose() // the map view will handle 'result Pending' -> 'Win/Lose'
                    }
                    .padding(.bottom, 30)
                } else {
                    GamePrimaryButton(title: "AUFGEBEN", color: .challengrSurface) {
                        manager.stop()
                        socket.sendUpdateBattleStatus(battleId: battleId, status: "DONE_SURRENDER")
                        onClose()
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            manager.start()
            manager.startTimer {
                if !isFinished {
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    } else {
                        isFinished = true
                        manager.stop()
                    }
                }
            }
        }
        .onDisappear {
            manager.stop()
        }
    }
}
