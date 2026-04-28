import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "RemoteAuthService")

struct RemoteAuthService: AuthServiceProtocol {
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

    var isLoggedIn: Bool {
        tokenStore.hasToken
    }

    func register(
        username: String,
        password: String,
        displayName: String,
        avatarName: String
    ) async throws -> AuthToken {
        let body = RegisterRequestBody(
            username: username,
            password: password,
            displayName: displayName,
            avatarName: avatarName
        )
        let (data, response) = try await sendRequest(
            path: "/api/auth/register",
            body: body
        )
        try validate(response: response)
        let authResponse = try decoder.decode(AuthResponseBody.self, from: data)
        try tokenStore.save(token: authResponse.token)
        return AuthToken(
            accessToken: authResponse.token,
            tokenType: "bearer",
            expiresIn: 86400,
            userId: UUID(uuidString: authResponse.user.id) ?? { logger.warning("Invalid UUID string: \(authResponse.user.id)"); return UUID() }()
        )
    }

    func login(username: String, password: String) async throws -> AuthToken {
        let body = LoginRequestBody(username: username, password: password)
        let (data, response) = try await sendRequest(
            path: "/api/auth/login",
            body: body
        )
        try validate(response: response)
        let authResponse = try decoder.decode(AuthResponseBody.self, from: data)
        try tokenStore.save(token: authResponse.token)
        return AuthToken(
            accessToken: authResponse.token,
            tokenType: "bearer",
            expiresIn: 86400,
            userId: UUID(uuidString: authResponse.user.id) ?? { logger.warning("Invalid UUID string: \(authResponse.user.id)"); return UUID() }()
        )
    }

    func getCurrentUser() async throws -> User {
        guard let token = tokenStore.load() else {
            throw AuthServiceError.notAuthenticated
        }
        let (data, response) = try await sendRequest(
            path: "/api/auth/me",
            method: "GET",
            token: token
        )
        try validate(response: response)
        let userBody = try decoder.decode(UserResponseBody.self, from: data)
        return userBody.toDomain()
    }

    func updatePreferredPlatform(_ platform: MusicPlatform?) async throws -> User {
        guard let token = tokenStore.load() else {
            throw AuthServiceError.notAuthenticated
        }
        let platformValue = platform?.apiValue
        let body = UpdateProfileRequestBody(preferredPlatform: platformValue)
        let (data, response) = try await sendRequest(
            path: "/api/auth/me",
            method: "PUT",
            body: body,
            token: token
        )
        try validate(response: response)
        let userBody = try decoder.decode(UserResponseBody.self, from: data)
        return userBody.toDomain()
    }

    func logout() async throws {
        tokenStore.delete()
    }

    private func sendRequest(
        path: String,
        method: String = "POST",
        body: Encodable? = nil,
        token: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidHTTPResponse
        }

        return (data, httpResponse)
    }

    private func validate(response: HTTPURLResponse) throws {
        guard (200...299).contains(response.statusCode) else {
            throw AuthServiceError.unsuccessfulStatusCode(response.statusCode)
        }
    }
}

private struct UpdateProfileRequestBody: Encodable {
    let preferredPlatform: String?
}

private struct RegisterRequestBody: Encodable {
    let username: String
    let password: String
    let displayName: String
    let avatarName: String
}

private struct LoginRequestBody: Encodable {
    let username: String
    let password: String
}

private struct AuthResponseBody: Decodable {
    let user: UserResponseBody
    let token: String
}

private struct UserResponseBody: Decodable {
    let id: String
    let username: String
    let displayName: String
    let avatarName: String
    let preferredPlatform: String?

    func toDomain() -> User {
        User(
            id: UUID(uuidString: id) ?? { logger.warning("Invalid UUID string: \(id)"); return UUID() }(),
            username: username,
            displayName: displayName,
            avatarName: avatarName,
            preferredPlatform: preferredPlatform.flatMap { MusicPlatform(apiValue: $0) }
        )
    }
}
