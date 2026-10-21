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
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    /// Spielname vom Server (kann vom Keycloak-Benutzernamen abweichen)
    @State private var ownName: String? = nil
    @State private var showRename = false
    @State private var newName = ""
    @State private var renameMessage: String? = nil
    @AppStorage(ToonMapSettings.key) private var useToonMap = ToonMapSettings.defaultOn
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
                    // beim Einschalten hört man gleich, dass es wieder Töne gibt
                    .onChange(of: isSoundEnabled) { _, _ in SoundManager.shared.play(.click) }
                    
                    Toggle(isOn: $isMusicEnabled) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                            Text("Hintergrundmusik")
                        }
                    }
                    .onChange(of: isMusicEnabled) { _, _ in
                        SoundManager.shared.play(.click)
                        SoundManager.shared.updateMusic()
                    }
                }
                
                Section(header: Text("Karte"),
                        footer: Text("Die Cartoon-Karte nutzt Kartendaten von OpenStreetMap. Lädt sie nicht, zeigt die App automatisch die Apple-Karte.")) {
                    Toggle(isOn: $useToonMap) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.green)
                            Text("Cartoon-Karte")
                        }
                    }
                    .onChange(of: useToonMap) { _, _ in SoundManager.shared.play(.click) }
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
                        SoundManager.shared.play(.click)
                        if enabled {
                            NotificationManager.shared.requestAuthorizationIfNeeded()
                        }
                    }
                }
                
                Section(header: Text("Privatsphäre"),
                        footer: Text("Andere sehen dich nur in der Nähe (bis 300 m) und nur ungefähr (ca. 50 m genau). Unsichtbar tauchst du bei niemandem auf der Karte auf.")) {
                    Toggle(isOn: Binding(get: { isInvisible ?? false }, set: { SoundManager.shared.play(.click); setInvisible($0) })) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.purple)
                            Text("Unsichtbar auf der Karte")
                        }
                    }
                    .disabled(isInvisible == nil || auth.playerId == nil)
                    Link(destination: BackendConfig.privacyPolicyURL) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            Text("Datenschutzerklärung")
                        }
                    }
                    NavigationLink {
                        BlockedPlayersView()
                            .onAppear { SoundManager.shared.play(.click) }
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.red)
                            Text("Blockierte Spieler")
                        }
                    }
                    if let privacyError {
                        Text(privacyError).font(.caption).foregroundColor(.red)
                    }
                }

                Section(header: Text("Account")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Dein Name im Spiel")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(ownName ?? auth.playerName)
                                .font(.headline)
                        }
                        Spacer()
                        Button("Ändern") {
                            SoundManager.shared.play(.click)
                            newName = ownName ?? auth.playerName
                            showRename = true
                        }
                        .disabled(ownName == nil)
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
                
                Section(footer: Text("Löscht dein Konto, deine Punkte, Trophäen, Figuren, Freunde und Check-ins endgültig. Vergangene Battles bleiben bei deinen Gegnern nur anonym als „Gelöschter Spieler“.")) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(isDeleting ? "Wird gelöscht …" : "Konto löschen")
                        }
                    }
                    .disabled(isDeleting || auth.playerId == nil)
                    if let deleteError {
                        Text(deleteError).font(.caption).foregroundColor(.red)
                    }
                }
                .confirmationDialog("Konto wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Endgültig löschen", role: .destructive) { deleteAccount() }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("Das kann nicht rückgängig gemacht werden.")
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
            // Spiel-Look wie Profil und Freunde: dunkel, Gelb als Akzent
            .scrollContentBackground(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .tint(.challengrYellow)
            .task { await loadVisibility() }
            .alert("Name ändern", isPresented: $showRename) {
                TextField("Neuer Name", text: $newName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Speichern") { rename() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("3–20 Zeichen: Buchstaben, Zahlen, Leerzeichen, _ . und -")
            }
            .alert(renameMessage ?? "", isPresented: Binding(get: { renameMessage != nil },
                                                             set: { if !$0 { renameMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .navigationBarItems(trailing: Button("Fertig") {
                SoundManager.shared.play(.click)
                dismiss()
            })
        }
        .environment(\.colorScheme, .dark)
    }

    private func deleteAccount() {
        isDeleting = true
        deleteError = nil
        Task {
            do {
                try await playerService.deleteOwnAccount()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { auth.accountDeleted() }
            } catch {
                isDeleting = false
                deleteError = "Löschen fehlgeschlagen – bitte später nochmal versuchen."
            }
        }
    }

    private func loadVisibility() async {
        guard let id = auth.playerId, let me = try? await playerService.loadPlayerById(id: id) else { return }
        isInvisible = me.invisible ?? false
        ownName = me.name
    }

    private func rename() {
        let wanted = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = auth.playerId, !wanted.isEmpty, wanted != ownName else { return }
        Task {
            do {
                let me = try await playerService.rename(id: id, to: wanted)
                ownName = me.name
                renameMessage = "Du heißt jetzt „\(me.name)“."
            } catch {
                renameMessage = error.localizedDescription
            }
        }
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
