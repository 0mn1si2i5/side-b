import Foundation

struct MockAuthService: AuthServiceProtocol {
    private let tokenStore: KeychainTokenStore

    private let mockUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        username: "mockuser",
        displayName: "Mock User",
        avatarName: "avatar_1"
    )

    private let mockToken = AuthToken(
        accessToken: "mock-jwt-token",
        tokenType: "bearer",
        expiresIn: 86400,
        userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    )

    init(tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.tokenStore = tokenStore
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
        try tokenStore.save(token: mockToken.accessToken)
        return mockToken
    }

    func login(username: String, password: String) async throws -> AuthToken {
        try tokenStore.save(token: mockToken.accessToken)
        return mockToken
    }

    func getCurrentUser() async throws -> User {
        guard tokenStore.hasToken else {
            throw AuthServiceError.notAuthenticated
        }
        return mockUser
    }

    func updatePreferredPlatform(_ platform: MusicPlatform?) async throws -> User {
        User(
            id: mockUser.id,
            username: mockUser.username,
            displayName: mockUser.displayName,
            avatarName: mockUser.avatarName,
            preferredPlatform: platform
        )
    }

    func logout() async throws {
        tokenStore.delete()
    }
}
