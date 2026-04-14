import SwiftUI

enum AvatarService {

    static let availableAvatars: [String] = [
        "avatar_1", "avatar_2", "avatar_3", "avatar_4",
        "avatar_5", "avatar_6", "avatar_7", "avatar_8",
        "avatar_9", "avatar_10", "avatar_11", "avatar_12",
    ]

    struct AvatarConfig {
        let symbolName: String
        let backgroundColor: Color
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