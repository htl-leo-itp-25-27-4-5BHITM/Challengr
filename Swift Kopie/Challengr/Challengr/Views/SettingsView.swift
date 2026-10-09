import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let auth: KeycloakAuthService
    
    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    @AppStorage("isMusicEnabled") private var isMusicEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    /// Stand vom Server (nil = noch nicht geladen)
    @State private var isInvisible: Bool? = nil
    @State private var privacyError: String? = nil
    private let playerService = PlayerLocationService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Töne & Musik")) {
                    Toggle(isOn: $isSoundEnabled) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text("Soundeffekte")
                        }
                    }
                    
                    Toggle(isOn: $isMusicEnabled) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                            Text("Hintergrundmusik")
                        }
                    }
                    .onChange(of: isMusicEnabled) { _, _ in
                        SoundManager.shared.updateMusic()
                    }
                }
                
                Section(header: Text("Benachrichtigungen")) {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.red)
                            Text("Mitteilungen")
                        }
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            NotificationManager.shared.requestAuthorizationIfNeeded()
                        }
                    }
                }
                
                Section(header: Text("Privatsphäre"),
                        footer: Text("Andere sehen dich nur in der Nähe (bis 300 m) und nur ungefähr (ca. 50 m genau). Unsichtbar tauchst du bei niemandem auf der Karte auf.")) {
                    Toggle(isOn: Binding(get: { isInvisible ?? false }, set: { setInvisible($0) })) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.purple)
                            Text("Unsichtbar auf der Karte")
                        }
                    }
                    .disabled(isInvisible == nil || auth.playerId == nil)
                    if let privacyError {
                        Text(privacyError).font(.caption).foregroundColor(.red)
                    }
                }

                Section(header: Text("Account")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Angemeldet als:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(auth.playerName)
                            .font(.headline)
                    }
                    
                    Button(role: .destructive) {
                        dismiss()
                        
                        // Wait a fraction of a second so the dismiss animation can finish
                        // before the root view transitions out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            auth.logout()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.forward")
                            Text("Abmelden")
                        }
                    }
                }
                
                Section(header: Text("Über")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .task { await loadVisibility() }
            .navigationBarItems(trailing: Button("Fertig") {
                dismiss()
            })
        }
    }

    private func loadVisibility() async {
        guard let id = auth.playerId, let me = try? await playerService.loadPlayerById(id: id) else { return }
        isInvisible = me.invisible ?? false
    }

    private func setInvisible(_ invisible: Bool) {
        guard let id = auth.playerId else { return }
        let previous = isInvisible
        isInvisible = invisible
        privacyError = nil
        Task {
            do {
                let me = try await playerService.setInvisible(id: id, invisible: invisible)
                isInvisible = me.invisible ?? invisible
            } catch {
                isInvisible = previous
                privacyError = "Konnte nicht gespeichert werden – bitte nochmal versuchen."
            }
        }
    }
}
