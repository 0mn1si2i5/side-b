import Foundation

protocol PlatformNavigationService {
    func destinationURL(for platform: MusicPlatform, track: Track) -> URL?
}

struct MockPlatformNavigationService: PlatformNavigationService {
    func destinationURL(for platform: MusicPlatform, track: Track) -> URL? {
        let query = "\(track.title) \(track.artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        guard let query else { return nil }

        switch platform {
        case .appleMusic:
            return URL(string: "https://music.apple.com/us/search?term=\(query)")
        case .spotify:
            return URL(string: "https://open.spotify.com/search/\(query)")
        case .qqMusic:
            return URL(string: "https://y.qq.com/n/ryqq/search?w=\(query)")
        case .neteaseMusic:
            return URL(string: "https://music.163.com/#/search/m/?s=\(query)&type=1")
        }
    }
}
