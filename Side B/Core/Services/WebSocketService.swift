import Combine
import Foundation

// MARK: - Connection State

enum WebSocketConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

// MARK: - Protocol

protocol WebSocketServiceProtocol {
    var connectionState: WebSocketConnectionState { get }
    var onMessageReceived: ((Message) -> Void)? { get set }
    var onEmojiReactionReceived: ((EmojiReaction) -> Void)? { get set }
    var onRoomUpdated: ((Room) -> Void)? { get set }
    var onConnectionStateChanged: ((WebSocketConnectionState) -> Void)? { get set }

    func connect(toRoom roomId: UUID) async
    func disconnect()
    func send(text: String) async throws
}

// MARK: - Errors

enum WebSocketServiceError: Error {
    case notConnected
    case invalidURL
    case authenticationRequired
    case encodingFailed
}

// MARK: - Remote Implementation

final class RemoteWebSocketService: WebSocketServiceProtocol {
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected

    var onMessageReceived: ((Message) -> Void)?
    var onEmojiReactionReceived: ((EmojiReaction) -> Void)?
    var onRoomUpdated: ((Room) -> Void)?
    var onConnectionStateChanged: ((WebSocketConnectionState) -> Void)?

    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private let session: URLSession

    private var webSocketTask: URLSessionWebSocketTask?
    private var currentRoomId: UUID?
    private var receiveTask: Task<Void, Never>?

    private var retryCount = 0
    private let maxRetries = 3
    private var reconnectTask: Task<Void, Never>?

    init(
        baseURL: URL,
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    func connect(toRoom roomId: UUID) async {
        cancelReconnect()
        disconnect()

        currentRoomId = roomId
        retryCount = 0

        await establishConnection(toRoom: roomId)
    }

    func disconnect() {
        cancelReconnect()
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: Data())
        webSocketTask = nil
        currentRoomId = nil
        retryCount = 0
        setConnectionState(.disconnected)
    }

    func send(text: String) async throws {
        guard let task = webSocketTask, connectionState == .connected else {
            throw WebSocketServiceError.notConnected
        }
        try await task.send(.string(text))
    }

    // MARK: - Connection

    private func establishConnection(toRoom roomId: UUID) async {
        guard let token = tokenStore.load() else {
            setConnectionState(.disconnected)
            return
        }

        let wsURL = buildWebSocketURL(roomId: roomId, token: token)
        guard let url = wsURL else {
            setConnectionState(.disconnected)
            return
        }

        setConnectionState(.connecting)

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        do {
            let firstMessage = try await task.receive()
            if case .string(let text) = firstMessage {
                handleRawMessage(text)
            }
            setConnectionState(.connected)
            retryCount = 0
            startReceiving()
        } catch {
            task.cancel(with: .abnormalClosure, reason: Data())
            webSocketTask = nil
            setConnectionState(.disconnected)
            scheduleReconnect()
        }
    }

    // MARK: - URL Construction

    private func buildWebSocketURL(roomId: UUID, token: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        guard let host = components?.host else { return nil }

        let scheme = components?.scheme == "https" ? "wss" : "ws"
        let port = components?.port

        let path = "/ws/rooms/\(roomId.uuidString)"

        components = URLComponents()
        components?.scheme = scheme
        components?.host = host
        components?.path = path
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        if let port {
            components?.port = port
        }

        return components?.url
    }

    // MARK: - Receiving

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self, let task = self.webSocketTask else { return }

            do {
                while !Task.isCancelled {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.handleRawMessage(text)
                    case .data:
                        break
                    @unknown default:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.handleDisconnection()
                }
            }
        }
    }

    // MARK: - Message Handling

    private func handleRawMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let json: [String: Any]?
        do {
            json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("[WebSocketService] JSON parse failed:", error)
            return
        }
        guard let json, let type = json["type"] as? String else { return }

        switch type {
        case "new_message":
            handleNewMessage(json)
        case "emoji_reaction":
            handleEmojiReaction(json)
        case "room_updated":
            handleRoomUpdated(json)
        case "connected":
            break
        default:
            break
        }
    }

    private func handleNewMessage(_ json: [String: Any]) {
        guard let dataDict = json["data"] as? [String: Any] else { return }

        let id = UUID(uuidString: dataDict["id"] as? String ?? "") ?? UUID()
        let senderId = dataDict["senderId"] as? String ?? ""
        let senderName = dataDict["senderName"] as? String ?? senderId
        let contentType = dataDict["contentType"] as? String ?? "text"
        let textContent = dataDict["textContent"] as? String
        let trackData = dataDict["trackData"] as? String
        let createdAtStr = dataDict["createdAt"] as? String ?? ""

        let track: Track? = trackData.flatMap { parseTrackData($0) }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sentAt = dateFormatter.date(from: createdAtStr) ?? Date()

        let contentTypeEnum = MessageType(rawValue: contentType) ?? .text
        let message = Message(
            id: id,
            senderName: senderName,
            senderID: UUID(uuidString: senderId),
            contentType: contentTypeEnum,
            text: contentTypeEnum == .text ? textContent : nil,
            track: track,
            sentAt: sentAt
        )

        onMessageReceived?(message)
    }

    private func handleEmojiReaction(_ json: [String: Any]) {
        guard let dataDict = json["data"] as? [String: Any] else { return }

        let id = UUID(uuidString: dataDict["id"] as? String ?? "") ?? UUID()
        let messageId = UUID(uuidString: dataDict["messageId"] as? String ?? "") ?? UUID()
        let userId = UUID(uuidString: dataDict["userId"] as? String ?? "") ?? UUID()
        let emoji = dataDict["emoji"] as? String ?? ""
        let createdAtStr = dataDict["createdAt"] as? String ?? ""

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt = dateFormatter.date(from: createdAtStr) ?? Date()

        let reaction = EmojiReaction(
            id: id,
            messageId: messageId,
            userId: userId,
            emoji: emoji,
            createdAt: createdAt
        )

        onEmojiReactionReceived?(reaction)
    }

    private func handleRoomUpdated(_ json: [String: Any]) {
        guard let dataDict = json["data"] as? [String: Any] else { return }

        let id = UUID(uuidString: dataDict["id"] as? String ?? "") ?? UUID()
        let name = dataDict["name"] as? String ?? ""
        let type = RoomType(rawValue: dataDict["type"] as? String ?? "group") ?? .group
        let createdBy = UUID(uuidString: dataDict["createdBy"] as? String ?? "") ?? UUID()
        let isActive = dataDict["isActive"] as? Bool ?? true
        let memberUsernames = dataDict["memberUsernames"] as? [String] ?? []

        let room = Room(
            id: id,
            name: name,
            type: type,
            memberUsernames: memberUsernames,
            createdBy: createdBy,
            isActive: isActive
        )

        onRoomUpdated?(room)
    }

    private func parseTrackData(_ jsonString: String) -> Track? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let trackDTO: WebSocketTrackDTO
        do {
            trackDTO = try JSONDecoder().decode(WebSocketTrackDTO.self, from: data)
        } catch {
            print("[WebSocketService] track decode failed:", error)
            return nil
        }

        return trackDTO.toTrack()
    }

    // MARK: - Reconnection

    private func handleDisconnection() {
        webSocketTask?.cancel(with: .abnormalClosure, reason: Data())
        webSocketTask = nil
        setConnectionState(.disconnected)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard retryCount < maxRetries, let roomId = currentRoomId else { return }

        let delay = pow(2.0, Double(retryCount)) // 1s, 2s, 4s
        retryCount += 1

        reconnectTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                print("[WebSocketService] sleep cancelled:", error)
            }
            guard !Task.isCancelled, let self else { return }
            await self.establishConnection(toRoom: roomId)
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    // MARK: - State

    private func setConnectionState(_ state: WebSocketConnectionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.connectionState = state
            self.onConnectionStateChanged?(state)
        }
    }
}

// MARK: - WebSocket Track DTO

private struct WebSocketTrackDTO: Decodable {
    let title: String?
    let artist: String?
    let album: String?
    let coverURL: String?
    let sourcePlatform: String?
    let sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case title, artist, album
        case coverURL = "coverUrl"
        case sourcePlatform, sourceURL = "sourceUrl"
    }

    func toTrack() -> Track? {
        guard let title, let artist else { return nil }

        let platform = sourcePlatform.flatMap { MusicPlatform(rawValue: $0) } ?? .spotify
        let platformLink = sourceURL.flatMap { URL(string: $0) }.map {
            PlatformLink(platform: platform, destinationURL: $0, isSource: true)
        }

        return Track(
            title: title,
            artistName: artist,
            albumTitle: album,
            sourcePlatform: platform,
            sourceURL: sourceURL.flatMap { URL(string: $0) },
            platformLinks: platformLink.map { [$0] } ?? [],
            artworkURL: coverURL.flatMap { URL(string: $0) }
        )
    }
}

// MARK: - Mock Implementation

final class MockWebSocketService: WebSocketServiceProtocol {
    var connectionState: WebSocketConnectionState = .disconnected

    var onMessageReceived: ((Message) -> Void)?
    var onEmojiReactionReceived: ((EmojiReaction) -> Void)?
    var onRoomUpdated: ((Room) -> Void)?
    var onConnectionStateChanged: ((WebSocketConnectionState) -> Void)?

    func connect(toRoom roomId: UUID) async {
        connectionState = .connected
    }

    func disconnect() {
        connectionState = .disconnected
    }

    func send(text: String) async throws {
        let message = Message(
            senderName: "You",
            text: text,
            sentAt: Date()
        )
        onMessageReceived?(message)
    }
}
