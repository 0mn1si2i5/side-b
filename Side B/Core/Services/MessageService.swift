import Foundation

protocol MessageServiceProtocol {
    func fetchMessages(roomId: UUID, limit: Int, before: UUID?) async throws -> [Message]
    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?, replyToId: UUID?) async throws -> Message
    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message
    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction
}

enum MessageServiceError: Error {
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int, URL)
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

    func fetchMessages(roomId: UUID, limit: Int = 50, before: UUID? = nil) async throws -> [Message] {
        var path = "/api/rooms/\(roomId.sideBPathID)/messages?limit=\(limit)"
        if let before {
            path += "&before=\(before.sideBPathID)"
        }
        let (data, response) = try await sendRequest(path: path, method: "GET")
        try validate(response: response)
        let dtos = try decoder.decode([MessageDTO].self, from: data)
        return dtos.compactMap { $0.toDomain() }
    }

    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?, replyToId: UUID?) async throws -> Message {
        let trackDataString = try trackData.map { track in
            let payload = TrackPayload(from: track)
            let jsonData = try encoder.encode(payload)
            return String(data: jsonData, encoding: .utf8)
        } ?? nil

        let body = CreateMessageBody(
            contentType: contentType,
            textContent: textContent,
            trackData: trackDataString,
            replyToId: replyToId?.sideBPathID
        )
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.sideBPathID)/messages", method: "POST", body: body
        )
        try validate(response: response)
        let dto = try decoder.decode(MessageDTO.self, from: data)
        guard let message = dto.toDomain() else {
            throw MessageServiceError.malformedPayload
        }
        return message
    }

    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message {
        try await sendMessage(roomId: roomId, contentType: "song", textContent: nil, trackData: track, replyToId: nil)
    }

    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction {
        let body = AddEmojiBody(emoji: emoji)
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.sideBPathID)/messages/\(messageId.sideBPathID)/reactions",
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

        let url = baseURL.appendingSideBPath(path)
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
            throw MessageServiceError.unsuccessfulStatusCode(response.statusCode, response.url ?? baseURL)
        }
    }
}

// MARK: - Mock

struct MockMessageService: MessageServiceProtocol {
    func fetchMessages(roomId: UUID, limit: Int = 50, before: UUID? = nil) async throws -> [Message] {
        []
    }

    func sendMessage(roomId: UUID, contentType: String, textContent: String?, trackData: Track?, replyToId: UUID?) async throws -> Message {
        if contentType == "song", let track = trackData {
            return Message(senderName: "You", track: track, replyToMessageID: replyToId, sentAt: Date())
        }
        return Message(senderName: "You", text: textContent ?? "", replyToMessageID: replyToId, sentAt: Date())
    }

    func sendSongMessage(roomId: UUID, track: Track) async throws -> Message {
        Message(senderName: "You", track: track, sentAt: Date())
    }

    func addEmojiReaction(roomId: UUID, messageId: UUID, emoji: String) async throws -> EmojiReaction {
        EmojiReaction(messageId: messageId, userId: UUID(), emoji: emoji)
    }
}
