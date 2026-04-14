import Foundation

protocol AuthServiceProtocol {
    func register(
        username: String,
        password: String,
        displayName: String,
        avatarName: String
    ) async throws -> AuthToken

    func login(username: String, password: String) async throws -> AuthToken

    func getCurrentUser() async throws -> User

    func logout() async throws

    var isLoggedIn: Bool { get }
}

enum AuthServiceError: Error {
    case invalidBaseURL
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int)
    case malformedPayload
    case notAuthenticated
    case tokenStorageFailed
}
