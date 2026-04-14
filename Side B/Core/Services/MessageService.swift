import Foundation

protocol MessageServiceProtocol {
    func fetchMessages(roomId: UUID) async throws -> [Message]
    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?) async throws -> Message
    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message
    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction
}

enum MessageServiceError: Error {
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int)
    case malformedPayload
    case notAuthenticated
}

// MARK: - Remote

struct RemoteMessageService: MessageServiceProtocol {
    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        baseURL: URL,
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    func fetchMessages(roomId: UUID) async throws -> [Message] {
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.uuidString)/messages", method: "GET"
        )
        try validate(response: response)
        let dtos = try decoder.decode([MessageDTO].self, from: data)
        return dtos.compactMap { $0.toDomain() }
    }

    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?) async throws -> Message {
        let trackDataString = try trackData.map { track in
            let payload = TrackPayload(from: track)
            let jsonData = try encoder.encode(payload)
            return String(data: jsonData, encoding: .utf8)
        } ?? nil

        let body = CreateMessageBody(
            contentType: contentType,
            textContent: textContent,
            trackData: trackDataString
        )
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.uuidString)/messages", method: "POST", body: body
        )
        try validate(response: response)
        let dto = try decoder.decode(MessageDTO.self, from: data)
        guard let message = dto.toDomain() else {
            throw MessageServiceError.malformedPayload
        }
        return message
    }

    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message {
        try await sendMessage(roomId: roomId, contentType: "song", textContent: nil, trackData: track)
    }

    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction {
        let body = AddEmojiBody(emoji: emoji)
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.uuidString)/messages/\(messageId.uuidString)/reactions",
            method: "POST",
            body: body
        )
        try validate(response: response)
        return try decoder.decode(EmojiReaction.self, from: data)
    }

    // MARK: - Private Helpers

    private func sendRequest(
        path: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let token = tokenStore.load() else {
            throw MessageServiceError.notAuthenticated
        }

        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessageServiceError.invalidHTTPResponse
        }

        return (data, httpResponse)
    }

    private func validate(response: HTTPURLResponse) throws {
        guard (200...299).contains(response.statusCode) else {
            throw MessageServiceError.unsuccessfulStatusCode(response.statusCode)
        }
    }
}

// MARK: - Mock

struct MockMessageService: MessageServiceProtocol {
    func fetchMessages(roomId: UUID) async throws -> [Message] {
        MockData.messages
    }

    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?) async throws -> Message {
        if contentType == "song", let track = trackData {
            return Message(senderName: "You", track: track, sentAt: Date())
        }
        return Message(senderName: "You", text: textContent ?? "", sentAt: Date())
    }

    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message {
        Message(senderName: "You", track: track, sentAt: Date())
    }

    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction {
        EmojiReaction(messageId: messageId, userId: UUID(), emoji: emoji)
    }
}

// MARK: - Private DTOs

private struct MessageDTO: Decodable {
    let id: String
    let roomId: String
    let senderId: String
    let contentType: String
    let textContent: String?
    let trackData: String?
    let replyToId: String?
    let createdAt: String

    func toDomain() -> Message? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: createdAt) ?? Date()

        let text: String? = contentType == "text" ? textContent : nil
        let track: Track? = contentType == "song" ? parseTrackData() : nil

        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            senderName: senderId,
            text: text,
            track: track,
            sentAt: date
        )
    }

    private func parseTrackData() -> Track? {
        guard let trackData else { return nil }
        guard let data = trackData.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TrackPayload.self, from: data).toTrack()
    }
}

private struct TrackPayload: Codable {
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

private struct CreateMessageBody: Encodable {
    let contentType: String
    let textContent: String?
    let trackData: String?
}

private struct AddEmojiBody: Encodable {
    let emoji: String
}
