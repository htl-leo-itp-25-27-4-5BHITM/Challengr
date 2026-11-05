import SwiftUI

/// "…"-Menü an fremden Spielern: Melden oder Blockieren (Apple-Regel 1.2).
struct PlayerSafetyMenu: View {
    let playerId: String
    let playerName: String
    /// Nach erfolgreichem Blockieren (z. B. Popup schließen, Spieler von der Karte nehmen)
    var onBlocked: () -> Void = {}
    var tint: Color = .challengrBlack
    /// Runder Knopf im Spiel-Look (dunkle Ansichten) statt des iOS-Standardsymbols
    var gameStyle = false

    @State private var showReport = false
    @State private var confirmBlock = false
    @State private var info: String? = nil

    var body: some View {
        Menu {
            Button {
                showReport = true
            } label: {
                Label("Melden", systemImage: "exclamationmark.bubble")
            }
            Button(role: .destructive) {
                confirmBlock = true
            } label: {
                Label("Blockieren", systemImage: "hand.raised.fill")
            }
        } label: {
            if gameStyle {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(GameStyle.panelFill))
                    .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
                    .contentShape(Circle())
            } else {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .accessibilityLabel("Optionen für \(playerName)")
        .confirmationDialog("\(playerName) blockieren?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Blockieren", role: .destructive) { block() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ihr seht euch nicht mehr auf der Karte, könnt euch nicht herausfordern und keine Freundschaft schließen. In den Einstellungen kannst du das wieder aufheben.")
        }
        .sheet(isPresented: $showReport) {
            ReportPlayerSheet(playerId: playerId, playerName: playerName) { info = $0 }
        }
        .alert(info ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func block() {
        Task {
            do {
                try await SafetyService().block(playerId: playerId)
                onBlocked()
            } catch {
                info = "Blockieren hat nicht geklappt – bitte nochmal versuchen."
            }
        }
    }
}

/// Meldung mit Grund und optionalem Text.
struct ReportPlayerSheet: View {
    let playerId: String
    let playerName: String
    let onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .beleidigung
    @State private var comment = ""
    @State private var isSending = false
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Warum meldest du \(playerName)?")) {
                    Picker("Grund", selection: $reason) {
                        ForEach(ReportReason.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section(header: Text("Was ist passiert? (optional)"),
                        footer: Text("Das Team sieht sich jede Meldung an. Der gemeldete Spieler erfährt nicht, wer ihn gemeldet hat.")) {
                    TextField("Kurz beschreiben …", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let error {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("Spieler melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sendet …" : "Melden") { send() }
                        .disabled(isSending)
                }
            }
        }
    }

    private func send() {
        isSending = true
        error = nil
        Task {
            do {
                try await SafetyService().report(playerId: playerId, reason: reason, comment: comment)
                dismiss()
                onDone("Danke! Deine Meldung ist beim Team angekommen.")
            } catch {
                isSending = false
                self.error = "Senden fehlgeschlagen – bitte nochmal versuchen."
            }
        }
    }
}

/// Einstellungen → Blockierte Spieler (wieder freigeben).
struct BlockedPlayersView: View {
    @State private var players: [BlockedPlayerDTO] = []
    @State private var loaded = false

    var body: some View {
        List {
            if loaded && players.isEmpty {
                Text("Du hast niemanden blockiert.").foregroundColor(.secondary)
            }
            ForEach(players) { player in
                HStack {
                    Text(player.name)
                    Spacer()
                    Button("Freigeben") { unblock(player) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Blockierte Spieler")
        .task { await load() }
    }

    private func load() async {
        players = (try? await SafetyService().blockedPlayers()) ?? []
        loaded = true
    }

    private func unblock(_ player: BlockedPlayerDTO) {
        Task {
            try? await SafetyService().unblock(playerId: player.id)
            await load()
        }
    }
}
