import SwiftUI
import Combine

// Lightweight local avatar customization (Fall B: presets only)

enum AvatarCategory: String, CaseIterable, Identifiable {
    case outfits = "Outfits"
    case hats = "Hüte"
    case pants = "Hose"
    case shoes = "Schuhe"

    var id: String { rawValue }
}

struct AvatarPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let imageName: String
    /// Brustbild für runde Avatare (Map-Pin, Profil).
    let avatarImageName: String
    let category: AvatarCategory
    /// 3D-Figur, falls das Preset eine ist.
    var character: GameCharacter? = nil
}

/// Central place for available avatar presets.
/// Outfits sind die 3D-Figuren dieses App-Builds (siehe `GameCharacter.own`).
enum AvatarPresets {
    static let all: [AvatarPreset] = [GameCharacter.own].map { character in
        AvatarPreset(
            id: character.rawValue,
            title: character.displayName,
            imageName: character.imageName,
            avatarImageName: character.avatarImageName,
            category: .outfits,
            character: character
        )
    }

    static func presets(for category: AvatarCategory) -> [AvatarPreset] {
        all.filter { $0.category == category }
    }

    static func preset(withId id: String) -> AvatarPreset? {
        all.first { $0.id == id }
    }

    static let defaultPresetId = GameCharacter.own.rawValue

    /// Persisted preset; falls back to the default (e.g. for old 2D preset ids).
    static func persistedPreset() -> AvatarPreset {
        let id = UserDefaults.standard.string(forKey: AvatarCustomizationStore.presetKey)
            ?? defaultPresetId
        return preset(withId: id) ?? preset(withId: defaultPresetId)!
    }

    /// Reads the persisted preset id and returns its `imageName`.
    /// Useful in views where we don't want to own an `ObservableObject`.
    static func persistedImageName() -> String {
        persistedPreset().imageName
    }

    /// Brustbild des gespeicherten Presets (für runde Avatare).
    static func persistedAvatarImageName() -> String {
        persistedPreset().avatarImageName
    }
}

final class AvatarCustomizationStore: ObservableObject {
    static let presetKey = "avatarPresetId"

    private var storedPresetId: String {
        get {
            UserDefaults.standard.string(forKey: Self.presetKey) ?? AvatarPresets.defaultPresetId
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.presetKey)
        }
    }

    @Published var selectedPresetId: String

    init() {
        // Don't access `storedPresetId` (computed) before `selectedPresetId` is initialized.
        let initial = UserDefaults.standard.string(forKey: Self.presetKey) ?? AvatarPresets.defaultPresetId
        self.selectedPresetId = initial
    }

    var selectedPreset: AvatarPreset {
        AvatarPresets.preset(withId: selectedPresetId)
            ?? AvatarPresets.preset(withId: AvatarPresets.defaultPresetId)!
    }

    func load() {
        selectedPresetId = storedPresetId
    }

    func save() {
        storedPresetId = selectedPresetId
    }
}
