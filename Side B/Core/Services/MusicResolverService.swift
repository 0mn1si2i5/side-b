import Foundation

protocol MusicResolverService {
    func resolveTrack(from link: String) -> Track
}

struct MockMusicResolverService: MusicResolverService {
    func resolveTrack(from link: String) -> Track {
        let normalizedLink = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedLink.contains("spotify") {
            return MockData.tracks[0]
        }

        if normalizedLink.contains("163.com") || normalizedLink.contains("netease") {
            return MockData.tracks[1]
        }

        if normalizedLink.contains("apple") {
            return MockData.tracks[2]
        }

        return MockData.tracks[0]
    }
}
