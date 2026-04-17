import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let auth: KeycloakAuthService
    
    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    @AppStorage("isMusicEnabled") private var isMusicEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

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
                }
                
                Section(header: Text("Benachrichtigungen")) {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.red)
                            Text("Mitteilungen")
                        }
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
            .navigationBarItems(trailing: Button("Fertig") {
                dismiss()
            })
        }
    }
}
