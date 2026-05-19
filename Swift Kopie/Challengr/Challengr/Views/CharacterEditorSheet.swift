import SwiftUI

struct CharacterEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AvatarCustomizationStore

    @State private var selectedCategory: AvatarCategory = .outfits
    @State private var detent: PresentationDetent = .large

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text("CHARAKTER")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(2)

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

                Image(store.selectedPreset.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            }
            .frame(height: 210)
            .padding(.horizontal, 20)

            // Category picker
            Picker("Kategorie", selection: $selectedCategory) {
                ForEach(AvatarCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Items grid
            ScrollView {
                if selectedCategory == .outfits {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AvatarPresets.presets(for: .outfits)) { preset in
                            presetTile(preset)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.secondary)

                        Text("KOMMT BALD")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(Color.secondary)

                        Text("Für \(selectedCategory.rawValue) brauchen wir noch eigene 2D-Bilder.\nAktuell kannst du nur Outfits (Boy/Girl) auswählen.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 10)
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    store.load()
                    dismiss()
                } label: {
                    Text("ABBRECHEN")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)

                GamePrimaryButton(title: "Speichern", color: .challengrGreen) {
                    store.save()
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .onAppear {
            // Always start in Outfits so the user can pick Boy/Girl immediately.
            selectedCategory = .outfits
            store.load()
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .background(Color(.systemGroupedBackground))
    }

    private func presetTile(_ preset: AvatarPreset) -> some View {
        let isSelected = store.selectedPresetId == preset.id

        return Button {
            store.selectedPresetId = preset.id
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground))

                    Image(preset.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                }
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.challengrYellow : Color.black.opacity(0.06), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)

                Text(preset.title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
    }
}
