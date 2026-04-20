import Foundation

// MARK: - Track Payload

struct TrackPayload: Codable {
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let sourcePlatform: String
    let sourcePlatformID: String?
    let sourceURL: String?
    let isrc: String?
    let artworkURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case artistName = "artist_name"
        case albumTitle = "album_title"
        case durationMS = "duration_ms"
        case sourcePlatform = "source_platform"
        case sourcePlatformID = "source_platform_id"
        case sourceURL = "source_url"
        case isrc
        case artworkURL = "artwork_url"
    }

    init(from track: Track) {
        self.title = track.title
        self.artistName = track.artistName
        self.albumTitle = track.albumTitle
        self.durationMS = track.durationMS
        self.sourcePlatform = track.sourcePlatform.rawValue
        self.sourcePlatformID = track.sourcePlatformID
        self.sourceURL = track.sourceURL?.absoluteString
        self.isrc = track.isrc
        self.artworkURL = track.artworkURL?.absoluteString
    }

    func toTrack() -> Track {
        Track(
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            durationMS: durationMS,
            sourcePlatform: MusicPlatform(rawValue: sourcePlatform) ?? .spotify,
            sourcePlatformID: sourcePlatformID,
            sourceURL: sourceURL.flatMap { URL(string: $0) },
            isrc: isrc,
            artworkURL: artworkURL.flatMap { URL(string: $0) }
        )
    }
}

// MARK: - Message DTO

struct MessageDTO: Decodable {
    let id: String
    let roomId: String
    let senderId: String
    let senderName: String
    let contentType: String
    let textContent: String?
    let trackData: String?
    let replyToId: String?
    let createdAt: String

    func toDomain() -> Message? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: createdAt) ?? Date()

        let contentTypeEnum = MessageType(rawValue: contentType) ?? .text
        let text: String? = contentTypeEnum == .text ? textContent : nil
        let track: Track? = contentTypeEnum == .song ? parseTrackData() : nil

        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            senderName: senderName,
            senderID: UUID(uuidString: senderId),
            contentType: contentTypeEnum,
            text: text,
            track: track,
            replyToMessageID: replyToId.flatMap { UUID(uuidString: $0) },
            sentAt: date
        )
    }

    private func parseTrackData() -> Track? {
        guard let trackData else { return nil }
        guard let data = trackData.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(TrackPayload.self, from: data).toTrack()
        } catch {
            print("[ServiceDTOs] track decode failed:", error)
            return nil
        }
    }
}

// MARK: - Create Message Body

struct CreateMessageBody: Encodable {
    let contentType: String
    let textContent: String?
    let trackData: String?
    let replyToId: String?
}

// MARK: - Add Emoji Body

struct AddEmojiBody: Encodable {
    let emoji: String
}
