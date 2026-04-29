import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "ServiceDTOs")

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
    let platformLinks: [PlatformLinkPayload]

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
        case platformLinks = "platform_links"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case artist
        case artistName
        case album
        case albumTitle
        case durationMS
        case sourcePlatform
        case sourcePlatformID
        case sourceURL
        case sourceUrl
        case artworkURL
        case artworkUrl
        case coverURL
        case coverUrl
        case platformLinks
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
        self.platformLinks = track.platformLinks.map { PlatformLinkPayload(platformLink: $0) }
    }

    init(from decoder: Decoder) throws {
        let snake = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)

        title = try snake.decode(String.self, forKey: .title)
        artistName = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .artistName,
            legacyKeys: [.artistName, .artist]
        ) ?? ""
        albumTitle = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .albumTitle,
            legacyKeys: [.albumTitle, .album]
        )
        durationMS = try Self.decodeDurationMS(snake: snake, legacy: legacy)
        sourcePlatform = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .sourcePlatform,
            legacyKeys: [.sourcePlatform]
        ) ?? MusicPlatform.spotify.rawValue
        sourcePlatformID = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .sourcePlatformID,
            legacyKeys: [.sourcePlatformID]
        )
        sourceURL = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .sourceURL,
            legacyKeys: [.sourceURL, .sourceUrl]
        )
        isrc = try snake.decodeIfPresent(String.self, forKey: .isrc)
        artworkURL = try Self.decodeString(
            snake,
            legacy,
            snakeKey: .artworkURL,
            legacyKeys: [.artworkURL, .artworkUrl, .coverURL, .coverUrl]
        )
        platformLinks = try Self.decodePlatformLinks(snake: snake, legacy: legacy)
    }

    func toTrack() -> Track {
        let platform = MusicPlatform(rawValue: sourcePlatform) ?? MusicPlatform(apiValue: sourcePlatform) ?? .spotify
        var links = platformLinks.compactMap { $0.toPlatformLink() }
        if let sourceLink = sourceURL.flatMap({ URL(string: $0) }),
           !links.contains(where: { $0.platform == platform }) {
            links.append(PlatformLink(platform: platform, destinationURL: sourceLink, isSource: true))
        }

        return Track(
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            durationMS: durationMS,
            sourcePlatform: platform,
            sourcePlatformID: sourcePlatformID,
            sourceURL: sourceURL.flatMap { URL(string: $0) },
            isrc: isrc,
            platformLinks: links,
            artworkURL: artworkURL.flatMap { URL(string: $0) }
        )
    }

    private static func decodeString(
        _ snake: KeyedDecodingContainer<CodingKeys>,
        _ legacy: KeyedDecodingContainer<LegacyCodingKeys>,
        snakeKey: CodingKeys,
        legacyKeys: [LegacyCodingKeys]
    ) throws -> String? {
        if let value = try snake.decodeIfPresent(String.self, forKey: snakeKey) {
            return value
        }

        for key in legacyKeys {
            if let value = try legacy.decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }

        return nil
    }

    private static func decodeDurationMS(
        snake: KeyedDecodingContainer<CodingKeys>,
        legacy: KeyedDecodingContainer<LegacyCodingKeys>
    ) throws -> Int? {
        if let value = try snake.decodeIfPresent(Int.self, forKey: .durationMS) {
            return value
        }
        return try legacy.decodeIfPresent(Int.self, forKey: .durationMS)
    }

    private static func decodePlatformLinks(
        snake: KeyedDecodingContainer<CodingKeys>,
        legacy: KeyedDecodingContainer<LegacyCodingKeys>
    ) throws -> [PlatformLinkPayload] {
        if let value = try snake.decodeIfPresent([PlatformLinkPayload].self, forKey: .platformLinks) {
            return value
        }
        return try legacy.decodeIfPresent([PlatformLinkPayload].self, forKey: .platformLinks) ?? []
    }
}

struct PlatformLinkPayload: Codable {
    let platform: String
    let destinationURL: String
    let isSource: Bool

    enum CodingKeys: String, CodingKey {
        case platform
        case destinationURL = "destination_url"
        case isSource = "is_source"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case destinationURL
        case destinationUrl
        case isSource
    }

    init(platformLink: PlatformLink) {
        platform = platformLink.platform.rawValue
        destinationURL = platformLink.destinationURL.absoluteString
        isSource = platformLink.isSource
    }

    init(from decoder: Decoder) throws {
        let snake = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        platform = try snake.decode(String.self, forKey: .platform)
        if let snakeDestination = try snake.decodeIfPresent(String.self, forKey: .destinationURL) {
            destinationURL = snakeDestination
        } else if let legacyDestination = try legacy.decodeIfPresent(String.self, forKey: .destinationURL) {
            destinationURL = legacyDestination
        } else {
            destinationURL = try legacy.decodeIfPresent(String.self, forKey: .destinationUrl) ?? ""
        }

        if let snakeIsSource = try snake.decodeIfPresent(Bool.self, forKey: .isSource) {
            isSource = snakeIsSource
        } else {
            isSource = try legacy.decodeIfPresent(Bool.self, forKey: .isSource) ?? false
        }
    }

    func toPlatformLink() -> PlatformLink? {
        guard
            let musicPlatform = MusicPlatform(rawValue: platform) ?? MusicPlatform(apiValue: platform),
            let url = URL(string: destinationURL)
        else {
            return nil
        }
        return PlatformLink(platform: musicPlatform, destinationURL: url, isSource: isSource)
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

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func toDomain() -> Message? {
        let date = Self.dateFormatter.date(from: createdAt) ?? Date()

        let contentTypeEnum = MessageType(rawValue: contentType) ?? .text
        let text: String? = contentTypeEnum == .text ? textContent : nil
        let track: Track? = contentTypeEnum == .song ? parseTrackData() : nil

        return Message(
            id: UUID(uuidString: id) ?? { logger.warning("Invalid UUID string: \(id)"); return UUID() }(),
            senderName: senderName,
            senderID: UUID(uuidString: senderId).map { $0 },
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
            logger.warning("Track data decode failed: \(error)")
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
