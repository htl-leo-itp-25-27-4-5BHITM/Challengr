import Foundation

struct BattleMetricPair<T> {
    let winner: T
    let loser: T
}

struct BattleMetrics {
    let sprint: BattleMetricPair<Double>?
    let loudness: BattleMetricPair<Double>?
    let compass: BattleMetricPair<Double>?
    let shake: BattleMetricPair<Int>?
    let pushup: BattleMetricPair<Int>?
}

struct BattleResultData {
    let winnerName: String
    let winnerAvatar: String   // später: Bildname
    let winnerPointsDelta: Int

    let loserName: String
    let loserAvatar: String
    let loserPointsDelta: Int

    let trashTalk: String      // nur im Lose-Screen angezeigt
    let metrics: BattleMetrics?
}
