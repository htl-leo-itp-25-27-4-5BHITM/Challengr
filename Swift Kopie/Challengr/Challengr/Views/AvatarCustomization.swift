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
    let category: AvatarCategory
}

/// Central place for available 2D avatar presets.
/// Note: currently only `playerBoy` + `playerGirl` exist in assets.
enum AvatarPresets {
    static let all: [AvatarPreset] = [
        AvatarPreset(id: "boy", title: "Boy", imageName: "playerBoy", category: .outfits),
        AvatarPreset(id: "girl", title: "Girl", imageName: "playerGirl", category: .outfits)
    ]

    static func presets(for category: AvatarCategory) -> [AvatarPreset] {
        all.filter { $0.category == category }
    }

    static func preset(withId id: String) -> AvatarPreset? {
        all.first { $0.id == id }
    }

    static let defaultPresetId = "boy"

    /// Reads the persisted preset id and returns its `imageName`.
    /// Useful in views where we don't want to own an `ObservableObject`.
    static func persistedImageName() -> String {
        let id = UserDefaults.standard.string(forKey: AvatarCustomizationStore.presetKey)
            ?? defaultPresetId
        return preset(withId: id)?.imageName
            ?? preset(withId: defaultPresetId)!.imageName
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
