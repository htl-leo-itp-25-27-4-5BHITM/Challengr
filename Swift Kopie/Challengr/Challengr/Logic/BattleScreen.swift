//
//  BattleScreen.swift
//  Challengr
//

import Foundation

/// Which battle view opens for a challenge (Welche Battle-Ansicht zu welcher Challenge gehört).
/// Pure logic so it can be unit-tested; MapView only switches over the result.
enum BattleScreen: Equatable {
    case knowledge
    case checkInSpot
    case sprint
    case loudness
    case camera
    case compass
    case shake
    case pushup
    /// Normal battle with timer, afterwards both players vote.
    case generic

    static func forChallenge(category: String, name: String) -> BattleScreen {
        if category == "Wissen" { return .knowledge }
        guard category == "iPhone" else { return .generic }

        let lower = name.lowercased()
        if name.contains("Check-In-Spot") { return .checkInSpot }
        if name.contains("Sprint-Challenge") { return .sprint }
        if name.contains("Schrei-Challenge") { return .loudness }
        if lower.contains("kamera") || lower.contains("camera") || lower.contains("foto") { return .camera }
        if lower.contains("compass") || lower.contains("kompass") { return .compass }
        if lower.contains("shake") || lower.contains("schüttel") { return .shake }
        if lower.contains("liegest") || lower.contains("pushup") { return .pushup }
        return .generic
    }
}
