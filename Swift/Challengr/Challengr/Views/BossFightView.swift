import SwiftUI
import CoreMotion
import Combine

/// Kampf gegen den Riss-Wächter: Tippen und Schütteln machen Schaden, beim Riss-Schlag ausweichen,
/// im Finale schreien alle gleichzeitig. Allein ist er nicht zu schaffen.
struct BossFightView: View {
    @ObservedObject var model: BossFightModel
    let socket: GameSocketService
    let onClose: () -> Void

    @StateObject private var shake = BossShakeCounter()
    @StateObject private var meter = SoundMeter()
    @State private var pendingUnits = 0
    @State private var tapScale = 1.0
    @State private var dodgedSlam: Date?
    @State private var screamSent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sendTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: false)) { context in
            let now = context.date
            ZStack {
                background
                VStack(spacing: 14) {
                    header(now: now)
                    hpBar
                    bossImage(now: now)
                    Spacer(minLength: 0)
                    controls(now: now)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if let deadline = model.slamDeadline, deadline > now, dodgedSlam != deadline, isFighting {
                    slamOverlay(deadline: deadline, now: now)
                }
            }
        }
        .onReceive(sendTimer) { _ in flushHits() }
        .onReceive(shake.$count) { total in
            guard isFighting, total > 0 else { return }
            pendingUnits += 1
        }
        .onChange(of: model.stage) { _, stage in
            switch stage {
            case .fight, .rage: shake.start()
            case .finale: shake.stop(); startScream()
            default: shake.stop(); meter.stop()
            }
        }
        .onAppear {
            socket.sendBossJoin(bossId: model.bossId)
            if isFighting { shake.start() }
        }
        .onDisappear { shake.stop(); meter.stop() }
    }

    private var isFighting: Bool { model.stage == .fight || model.stage == .rage }

    // MARK: - Teile

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.12, green: 0.04, blue: 0.22), model.stage == .rage ? Color(red: 0.35, green: 0.02, blue: 0.12) : .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private func header(now: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RISS-WÄCHTER")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(RiftBoss.purple)
                Text(stageTitle)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let end = model.fightEndsAt, isFighting || model.stage == .finale {
                    Text(timeLeft(until: end, now: now))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Label("\(model.fighters)", systemImage: "person.2.fill")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundColor(.white.opacity(0.6))
            }
            .accessibilityLabel("Kampf verlassen")
        }
    }

    private var stageTitle: String {
        switch model.stage {
        case .waiting: return "WARTET AUF MITSTREITER"
        case .fight: return "ANGRIFF!"
        case .rage: return model.roared ? "ER BRÜLLT ZURÜCK – RASEREI!" : "RASEREI!"
        case .finale: return "FINALE – ALLE SCHREIEN!"
        case .won: return "BESIEGT!"
        case .escaped: return "ENTKOMMEN"
        case .rejected: return "KEIN ZUTRITT"
        }
    }

    private var hpBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [RiftBoss.purple, .challengrYellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, Double(model.hp) / Double(max(1, model.maxHp))))))
                    .animation(.easeOut(duration: 0.25), value: model.hp)
                Text("\(model.hp) / \(model.maxHp)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 18)
        .accessibilityLabel("Lebenspunkte \(model.hp) von \(model.maxHp)")
    }

    private func bossImage(now: Date) -> some View {
        let t = now.timeIntervalSinceReferenceDate
        let wobble = reduceMotion ? 0 : (model.stage == .rage ? sin(t * 30) * 4 : sin(t * 2) * 2)
        return Image(RiftBoss.imageName)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 300)
            .offset(x: wobble)
            .scaleEffect(model.stage == .finale ? 1.08 : 1)
            .shadow(color: (model.stage == .rage ? Color.red : RiftBoss.purple).opacity(0.8), radius: 30)
            .modifier(HitShake(trigger: model.hitFlash))
            .animation(reduceMotion ? nil : .linear(duration: 0.3), value: model.hitFlash)
            .opacity(model.stage == .escaped ? 0.25 : 1)
    }

    @ViewBuilder
    private func controls(now: Date) -> some View {
        switch model.stage {
        case .waiting:
            infoCard(title: "Allein ist er nicht zu schaffen",
                     text: "\(model.fighters)/\(model.minFighters) Kämpfer – hol jemanden dazu! Der Kampf startet, sobald ihr zu zweit seid.")
        case .fight, .rage:
            VStack(spacing: 8) {
                Text("Tippen und Handy schütteln!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Button {
                    pendingUnits += 1
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { tapScale = 0.9 }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.08)) { tapScale = 1 }
                } label: {
                    Text("SCHLAG!")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.challengrDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .background(RoundedRectangle(cornerRadius: 26).fill(Color.challengrYellow))
                        .scaleEffect(tapScale)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .heavy), trigger: pendingUnits)
            }
        case .finale:
            VStack(spacing: 8) {
                Text("SCHREIT ALLE GLEICHZEITIG!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.challengrYellow)
                ProgressView(value: Double(max(0, meter.level + 60)), total: 60)
                    .tint(.challengrYellow)
                if let deadline = model.finaleDeadline {
                    Text("noch \(max(0, Int(ceil(deadline.timeIntervalSince(now))))) s")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.08)))
        case let .won(shards, coins):
            VStack(spacing: 10) {
                infoCard(title: "DER RISS-WÄCHTER IST GEFALLEN!", text: "+\(shards) Riss-Splitter · +\(coins) Coins")
                GamePrimaryButton(title: "Weiter", color: .challengrYellow, action: onClose)
            }
        case .escaped:
            VStack(spacing: 10) {
                infoCard(title: "Er ist entkommen …", text: "Er lacht und verschwindet im Riss. Beim nächsten Mal mit mehr Leuten!")
                GamePrimaryButton(title: "Zurück", color: .white, action: onClose)
            }
        case let .rejected(reason):
            VStack(spacing: 10) {
                infoCard(title: "Kein Zutritt", text: reason)
                GamePrimaryButton(title: "Zurück", color: .white, action: onClose)
            }
        }
    }

    private func infoCard(title: String, text: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.08)))
    }

    private func slamOverlay(deadline: Date, now: Date) -> some View {
        ZStack {
            Color.red.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("RISS-SCHLAG!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Button {
                    socket.sendBossDodge(bossId: model.bossId)
                    dodgedSlam = deadline
                } label: {
                    Text("AUSWEICHEN!")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.horizontal, 30).padding(.vertical, 22)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.warning, trigger: deadline)
                Text(String(format: "%.1f s", max(0, deadline.timeIntervalSince(now))))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Aktionen

    private func flushHits() {
        guard isFighting, pendingUnits > 0 else { return }
        socket.sendBossHit(bossId: model.bossId, units: pendingUnits)
        pendingUnits = 0
    }

    private func startScream() {
        guard !screamSent else { return }
        meter.start()
        let deadline = model.finaleDeadline ?? Date().addingTimeInterval(6)
        Task {
            // zweimal melden: der Server nimmt den lautesten Wert
            try? await Task.sleep(for: .seconds(max(0.5, deadline.timeIntervalSinceNow - 2)))
            socket.sendBossScream(bossId: model.bossId, db: Double(meter.getMaxLevel()))
            try? await Task.sleep(for: .seconds(1.2))
            socket.sendBossScream(bossId: model.bossId, db: Double(meter.getMaxLevel()))
            meter.stop()
            screamSent = false
        }
        screamSent = true
    }

    private func timeLeft(until end: Date, now: Date) -> String {
        let s = max(0, Int(end.timeIntervalSince(now)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Kurzes Rütteln bei jedem Treffer.
private struct HitShake: GeometryEffect {
    var trigger: Int
    var animatableData: CGFloat
    init(trigger: Int) { self.trigger = trigger; animatableData = CGFloat(trigger) }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 4) * 6, y: 0))
    }
}

/// Zählt kräftige Schüttler (Beschleunigung über 2,2 g, höchstens ~6 pro Sekunde).
/// `nonisolated` wie `BossFightModel` (Absturz beim Freigeben sonst).
nonisolated final class BossShakeCounter: ObservableObject {
    @Published var count = 0
    private let motion = CMMotionManager()
    private var last = Date.distantPast

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 30
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            let g = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            let now = Date()
            if g > 2.2, now.timeIntervalSince(self.last) > 0.15 {
                self.last = now
                self.count += 1
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }
}
