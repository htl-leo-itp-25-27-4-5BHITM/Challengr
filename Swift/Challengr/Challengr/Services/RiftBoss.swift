import SwiftUI
import CoreLocation
import Combine

/// Riss-Wächter – übermächtiger Co-op-Boss (Backend: `control.RiftBossService`).
/// Taucht an einem öffentlichen Ort auf, allein nicht zu schaffen: mindestens zwei Spieler müssen beitreten.
struct BossView: Codable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let place: String
    let latitude: Double
    let longitude: Double
    let hp: Int
    let maxHp: Int
    let phase: String
    let fighters: Int
    let minFighters: Int
    let expiresAt: String
    var fightEndsAt: String? = nil

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var hpFraction: Double { maxHp > 0 ? Double(hp) / Double(maxHp) : 0 }
    var expiresDate: Date? { RiftBoss.date(expiresAt) }
}

struct BossNearby: Codable, Equatable {
    let bosses: [BossView]
    let shards: Int
}

enum RiftBoss {
    /// So nah muss man am Riss sein, um beizutreten (wie `JOIN_RADIUS_M`)
    static let joinRadius: CLLocationDistance = 250
    static let purple = Color(red: 0.7, green: 0.36, blue: 1.0)
    static let imageName = "RissWaechter"
    static let mapSheetName = "RissWaechterMapSheet"

    static func date(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return ISO8601DateFormatter.chaos.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    static func load() async throws -> BossNearby {
        let (data, response) = try await API.data(from: BackendConfig.apiURL("api/bosses/nearby"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return BossNearby(bosses: [], shards: 0) }
        return try JSONDecoder().decode(BossNearby.self, from: data)
    }
}

/// Nachrichten vom Server während des Kampfs.
enum BossMessage: Equatable {
    case state(bossId: Int64, hp: Int, maxHp: Int, phase: String, fighters: Int, minFighters: Int, fightEndsAt: Date?)
    case phase(bossId: Int64, phase: String, roar: Bool)
    case slam(bossId: Int64, ms: Int)
    case finale(bossId: Int64, seconds: Double)
    case end(bossId: Int64, defeated: Bool, shards: Int, coins: Int)
    case rejected(bossId: Int64, reason: String)

    init?(json: [String: Any]) {
        guard let type = json["type"] as? String, let id = (json["bossId"] as? NSNumber)?.int64Value else { return nil }
        let int = { (k: String) in (json[k] as? NSNumber)?.intValue ?? 0 }
        switch type {
        case "boss-state":
            self = .state(bossId: id, hp: int("hp"), maxHp: int("maxHp"), phase: json["phase"] as? String ?? "WAITING",
                          fighters: int("fighters"), minFighters: int("minFighters"), fightEndsAt: RiftBoss.date(json["fightEndsAt"] as? String))
        case "boss-phase":
            self = .phase(bossId: id, phase: json["phase"] as? String ?? "", roar: json["roar"] as? Bool ?? false)
        case "boss-slam":
            self = .slam(bossId: id, ms: int("ms"))
        case "boss-finale":
            self = .finale(bossId: id, seconds: (json["seconds"] as? NSNumber)?.doubleValue ?? 6)
        case "boss-end":
            self = .end(bossId: id, defeated: json["result"] as? String == "DEFEATED", shards: int("shards"), coins: int("coins"))
        case "boss-rejected":
            self = .rejected(bossId: id, reason: json["reason"] as? String ?? "")
        default:
            return nil
        }
    }

    var bossId: Int64 {
        switch self {
        case .state(let id, _, _, _, _, _, _), .phase(let id, _, _), .slam(let id, _), .finale(let id, _),
             .end(let id, _, _, _), .rejected(let id, _): return id
        }
    }
}

/// Zustand eines Kampfs in der App.
/// Bewusst `nonisolated` wie `AvatarCustomizationStore`: sonst stürzt das Freigeben ab (malloc-Fehler im deinit).
nonisolated final class BossFightModel: ObservableObject {
    enum Stage: Equatable { case waiting, fight, rage, finale, won(shards: Int, coins: Int), escaped, rejected(String) }

    let bossId: Int64
    @Published var hp: Int
    @Published var maxHp: Int
    @Published var fighters = 1
    @Published var minFighters = 2
    @Published var stage: Stage = .waiting
    @Published var fightEndsAt: Date?
    /// Riss-Schlag: bis wann man ausweichen muss
    @Published var slamDeadline: Date?
    /// Finale: bis wann alle schreien müssen
    @Published var finaleDeadline: Date?
    /// Zähler für Wackeln/Blitz bei jedem Treffer
    @Published var hitFlash = 0
    @Published var roared = false

    init(boss: BossView) {
        bossId = boss.id
        hp = boss.hp
        maxHp = boss.maxHp
        fighters = boss.fighters
        minFighters = boss.minFighters
    }

    func apply(_ message: BossMessage, now: Date = Date()) {
        guard message.bossId == bossId else { return }
        switch message {
        case let .state(_, hp, maxHp, phase, fighters, minFighters, fightEndsAt):
            if hp < self.hp { hitFlash += 1 }
            self.hp = hp
            self.maxHp = maxHp
            self.fighters = fighters
            self.minFighters = minFighters
            self.fightEndsAt = fightEndsAt ?? self.fightEndsAt
            if case .won = stage { return }
            if stage == .escaped { return }
            switch phase {
            case "FIGHT": stage = .fight
            case "RAGE": if stage != .finale { stage = .rage }
            case "FINALE": stage = .finale
            default: stage = .waiting
            }
        case let .phase(_, phase, roar):
            roared = roar
            if phase == "RAGE" { stage = .rage; finaleDeadline = nil }
        case let .slam(_, ms):
            slamDeadline = now.addingTimeInterval(Double(ms) / 1000)
        case let .finale(_, seconds):
            stage = .finale
            slamDeadline = nil
            finaleDeadline = now.addingTimeInterval(seconds)
        case let .end(_, defeated, shards, coins):
            stage = defeated ? .won(shards: shards, coins: coins) : .escaped
            slamDeadline = nil
            finaleDeadline = nil
        case let .rejected(_, reason):
            stage = .rejected(reason)
        }
    }
}

/// Riss-Wächter auf der Karte: großes Sprite über einem violetten Riss, Lebensbalken und Kämpfer-Zahl.
struct BossMapPin: View {
    let boss: BossView

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.5 : (sin(t * 3) + 1) / 2
            VStack(spacing: 4) {
                VStack(spacing: 2) {
                    Text("RISS-WÄCHTER")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    ProgressView(value: boss.hpFraction)
                        .tint(RiftBoss.purple)
                        .frame(width: 80)
                    Text("\(boss.fighters)/\(boss.minFighters) Kämpfer")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.7)))

                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(RadialGradient(colors: [RiftBoss.purple.opacity(0.9), .clear], center: .center, startRadius: 2, endRadius: 70))
                        .frame(width: 140 + 20 * pulse, height: (140 + 20 * pulse) * MapVibe.groundRatio)
                    if let frame = MapSprites.frame(sheet: RiftBoss.mapSheetName, at: reduceMotion ? 0 : Int(t * 8)) {
                        Image(uiImage: frame)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .offset(y: -8)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Riss-Wächter bei \(boss.place), \(boss.fighters) von \(boss.minFighters) Kämpfern")
    }
}

extension MapSprites {
    private static var sheetCache: [String: [UIImage]] = [:]

    /// Einzelbilder eines beliebigen Sprite-Sheets (z. B. Boss) mit `GameCharacter.mapSheetFrames` Bildern.
    static func frame(sheet name: String, at index: Int) -> UIImage? {
        if sheetCache[name] == nil, let sheet = UIImage(named: name)?.cgImage {
            let count = GameCharacter.mapSheetFrames, w = sheet.width / count
            sheetCache[name] = (0..<count).compactMap { i in
                sheet.cropping(to: CGRect(x: i * w, y: 0, width: w, height: sheet.height)).map { UIImage(cgImage: $0) }
            }
        }
        guard let frames = sheetCache[name], !frames.isEmpty else { return nil }
        return frames[index % frames.count]
    }
}
