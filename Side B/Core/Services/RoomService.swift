import Foundation

protocol RoomServiceProtocol {
    func fetchRooms() async throws -> [Room]
    func createRoom(name: String, type: String, memberUsername: String) async throws -> Room
    func renameRoom(id: UUID, newName: String) async throws -> Room
    func addMember(roomId: UUID, username: String) async throws -> Room
    func dissolveRoom(id: UUID) async throws
    func fetchRoomMessages(roomId: UUID) async throws -> [Message]
}

enum RoomServiceError: Error {
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int)
    case malformedPayload
    case notAuthenticated
}

// MARK: - Remote

struct RemoteRoomService: RoomServiceProtocol {
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

    func fetchRooms() async throws -> [Room] {
        let (data, response) = try await sendRequest(path: "/api/rooms", method: "GET")
        try validate(response: response)
        let dtos = try decoder.decode([RoomDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }

    func createRoom(name: String, type: String, memberUsername: String) async throws -> Room {
        let body = CreateRoomBody(name: name, type: type, memberUsernames: [memberUsername])
        let (data, response) = try await sendRequest(path: "/api/rooms", method: "POST", body: body)
        try validate(response: response)
        let dto = try decoder.decode(RoomDTO.self, from: data)
        return dto.toDomain()
    }

    func renameRoom(id: UUID, newName: String) async throws -> Room {
        let body = RenameRoomBody(name: newName)
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(id.uuidString)", method: "PUT", body: body
        )
        try validate(response: response)
        let dto = try decoder.decode(RoomDTO.self, from: data)
        return dto.toDomain()
    }

    func addMember(roomId: UUID, username: String) async throws -> Room {
        let body = AddMemberBody(username: username)
        let (_, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.uuidString)/members", method: "POST", body: body
        )
        try validate(response: response)
        return try await fetchRoom(id: roomId)
    }

    func dissolveRoom(id: UUID) async throws {
        let (_, response) = try await sendRequest(
            path: "/api/rooms/\(id.uuidString)", method: "DELETE"
        )
        try validate(response: response)
    }

    func fetchRoomMessages(roomId: UUID) async throws -> [Message] {
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(roomId.uuidString)/messages", method: "GET"
        )
        try validate(response: response)
        let dtos = try decoder.decode([MessageDTO].self, from: data)
        return dtos.compactMap { $0.toDomain() }
    }

    // MARK: - Private Helpers

    private func fetchRoom(id: UUID) async throws -> Room {
        let (data, response) = try await sendRequest(
            path: "/api/rooms/\(id.uuidString)", method: "GET"
        )
        try validate(response: response)
        let dto = try decoder.decode(RoomDTO.self, from: data)
        return dto.toDomain()
    }

    private func sendRequest(
        path: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let token = tokenStore.load() else {
            throw RoomServiceError.notAuthenticated
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
            throw RoomServiceError.invalidHTTPResponse
        }

        return (data, httpResponse)
    }

    private func validate(response: HTTPURLResponse) throws {
        guard (200...299).contains(response.statusCode) else {
            throw RoomServiceError.unsuccessfulStatusCode(response.statusCode)
        }
    }
}

// MARK: - Mock

struct MockRoomService: RoomServiceProtocol {
    func fetchRooms() async throws -> [Room] {
        MockData.rooms
    }

    func createRoom(name: String, type: String, memberUsername: String) async throws -> Room {
        Room(name: name)
    }

    func renameRoom(id: UUID, newName: String) async throws -> Room {
        Room(id: id, name: newName)
    }

    func addMember(roomId: UUID, username: String) async throws -> Room {
        MockData.rooms.first { $0.id == roomId } ?? Room(name: "Room")
    }

    func dissolveRoom(id: UUID) async throws {
        // No-op for mock
    }

    func fetchRoomMessages(roomId: UUID) async throws -> [Message] {
        MockData.messages
    }
}

// MARK: - Private DTOs

private struct RoomDTO: Decodable {
    let id: String
    let name: String?
    let type: String
    let createdBy: String
    let createdAt: String
    let isActive: Bool

    func toDomain() -> Room {
        Room(
            id: UUID(uuidString: id) ?? UUID(),
            name: name ?? "Unnamed Room",
            type: RoomType(rawValue: type) ?? .group,
            memberIDs: [],
            createdBy: UUID(uuidString: createdBy) ?? UUID(),
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            isActive: isActive
        )
    }
}

private struct CreateRoomBody: Encodable {
    let name: String
    let type: String
    let memberUsernames: [String]
}

private struct RenameRoomBody: Encodable {
    let name: String
}

private struct AddMemberBody: Encodable {
    let username: String
}

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

        let contentTypeEnum = MessageType(rawValue: contentType) ?? .text
        let text: String? = contentTypeEnum == .text ? textContent : nil
        let track: Track? = contentTypeEnum == .song ? parseTrackData() : nil

        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            senderName: senderId,
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
        return try? JSONDecoder().decode(TrackPayload.self, from: data).toTrack()
    }
}

private struct TrackPayload: Decodable {
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
