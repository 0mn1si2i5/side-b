import Foundation

enum MusicPlatform: String, CaseIterable, Hashable, Codable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case qqMusic = "QQ 音乐"
    case neteaseMusic = "网易云音乐"

    var displayName: String {
        rawValue
    }

    var apiValue: String {
        switch self {
        case .appleMusic:
            return "apple_music"
        case .spotify:
            return "spotify"
        case .qqMusic:
            return "qq_music"
        case .neteaseMusic:
            return "netease_music"
        }
    }

    var iconAssetName: String {
        switch self {
        case .appleMusic:
            return "PlatformAppleMusic"
        case .spotify:
            return "PlatformSpotify"
        case .qqMusic:
            return "PlatformQQMusic"
        case .neteaseMusic:
            return "PlatformNeteaseMusic"
        }
    }

    init?(apiValue: String) {
        switch apiValue {
        case "apple_music":
            self = .appleMusic
        case "spotify":
            self = .spotify
        case "qq_music":
            self = .qqMusic
        case "netease_music":
            self = .neteaseMusic
        default:
            self.init(rawValue: apiValue)
        }
    }
}
