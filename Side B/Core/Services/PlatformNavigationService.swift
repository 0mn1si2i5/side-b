import Foundation

protocol PlatformNavigationService {
    func destinationURL(for platformName: String, track: Track) -> URL?
}

struct MockPlatformNavigationService: PlatformNavigationService {
    func destinationURL(for platformName: String, track: Track) -> URL? {
        let query = "\(track.title) \(track.artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        guard let query else { return nil }

        switch platformName {
        case "Apple Music":
            return URL(string: "https://music.apple.com/us/search?term=\(query)")
        case "Spotify":
            return URL(string: "https://open.spotify.com/search/\(query)")
        case "QQ 音乐":
            return URL(string: "https://y.qq.com/n/ryqq/search?w=\(query)")
        case "网易云音乐":
            return URL(string: "https://music.163.com/#/search/m/?s=\(query)&type=1")
        default:
            return nil
        }
    }
}
