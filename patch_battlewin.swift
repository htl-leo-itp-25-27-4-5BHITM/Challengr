import SwiftUI

struct BattleWinView: View {
    // MARK: - Input (Eingaben)
    let data: BattleResultData
    let onClose: () -> Void

    // MARK: - Animation States
    @State private var appearScale: CGFloat = 0.6
    @State private var appearOpacity: Double = 0.0
    @State private var titleScale: CGFloat = 1.0

    // MARK: - Body (UI-Aufbau)
    var body: some View {
// ...existing code...
