import Foundation

enum MusicPlatform: String, CaseIterable, Hashable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case qqMusic = "QQ 音乐"
    case neteaseMusic = "网易云音乐"

    var displayName: String {
        rawValue
    }
}
