import Foundation

/// Platform-agnostic color representation for avatar backgrounds.
/// Convert to SwiftUI Color via `swiftUIColor` computed property.
struct AvatarBackgroundColor {
    let red: Double
    let green: Double
    let blue: Double

    /// Predefined colors matching the original SwiftUI Color values
    static let blue    = AvatarBackgroundColor(red: 0.0, green: 0.478, blue: 1.0)
    static let purple  = AvatarBackgroundColor(red: 0.686, green: 0.321, blue: 0.871)
    static let green   = AvatarBackgroundColor(red: 0.204, green: 0.78, blue: 0.349)
    static let orange  = AvatarBackgroundColor(red: 1.0, green: 0.584, blue: 0.0)
    static let pink    = AvatarBackgroundColor(red: 1.0, green: 0.176, blue: 0.333)
    static let teal    = AvatarBackgroundColor(red: 0.0, green: 0.663, blue: 0.624)
    static let indigo  = AvatarBackgroundColor(red: 0.345, green: 0.337, blue: 0.839)
    static let red     = AvatarBackgroundColor(red: 1.0, green: 0.231, blue: 0.188)
    static let mint    = AvatarBackgroundColor(red: 0.0, green: 0.78, blue: 0.745)
    static let yellow  = AvatarBackgroundColor(red: 1.0, green: 0.8, blue: 0.0)
    static let cyan    = AvatarBackgroundColor(red: 0.0, green: 0.745, blue: 0.745)
    static let brown   = AvatarBackgroundColor(red: 0.635, green: 0.518, blue: 0.369)
    static let gray    = AvatarBackgroundColor(red: 0.557, green: 0.557, blue: 0.576)
}

enum AvatarService {

    static let availableAvatars: [String] = [
        "avatar_1", "avatar_2", "avatar_3", "avatar_4",
        "avatar_5", "avatar_6", "avatar_7", "avatar_8",
        "avatar_9", "avatar_10", "avatar_11", "avatar_12",
    ]

    struct AvatarConfig {
        let symbolName: String
        let backgroundColor: AvatarBackgroundColor
    }

    private static let configs: [String: AvatarConfig] = [
        "avatar_1":  AvatarConfig(symbolName: "person.circle.fill",       backgroundColor: .blue),
        "avatar_2":  AvatarConfig(symbolName: "person.crop.circle.fill",    backgroundColor: .purple),
        "avatar_3":  AvatarConfig(symbolName: "figure.walk.circle.fill",    backgroundColor: .green),
        "avatar_4":  AvatarConfig(symbolName: "person.wave.2.circle.fill",  backgroundColor: .orange),
        "avatar_5":  AvatarConfig(symbolName: "person.fill.circle",         backgroundColor: .pink),
        "avatar_6":  AvatarConfig(symbolName: "face.smiling.inverse",       backgroundColor: .teal),
        "avatar_7":  AvatarConfig(symbolName: "star.circle.fill",           backgroundColor: .indigo),
        "avatar_8":  AvatarConfig(symbolName: "heart.circle.fill",         backgroundColor: .red),
        "avatar_9":  AvatarConfig(symbolName: "leaf.circle.fill",          backgroundColor: .mint),
        "avatar_10": AvatarConfig(symbolName: "bolt.circle.fill",          backgroundColor: .yellow),
        "avatar_11": AvatarConfig(symbolName: "moon.circle.fill",           backgroundColor: .cyan),
        "avatar_12": AvatarConfig(symbolName: "sun.max.circle.fill",       backgroundColor: .brown),
    ]

    static func config(for name: String) -> AvatarConfig {
        configs[name] ?? AvatarConfig(symbolName: "person.circle.fill", backgroundColor: .gray)
    }
}
