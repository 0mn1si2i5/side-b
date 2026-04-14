import Foundation

struct AuthToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}