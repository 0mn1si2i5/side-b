import Foundation
import Security

enum AuthPreferenceKeys {
    static let rememberPassword = "sideb.auth.rememberPassword"
    static let lastUsername = "sideb.auth.lastUsername"
}

struct StoredLoginCredential: Codable {
    let username: String
    let password: String
}

final class KeychainCredentialStore {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "com.sideb.auth",
        account: String = "rememberedLogin"
    ) {
        self.service = service
        self.account = account
    }

    func save(username: String, password: String) throws {
        let credential = StoredLoginCredential(username: username, password: password)
        let data = try encoder.encode(credential)

        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthServiceError.tokenStorageFailed
        }
    }

    func load() -> StoredLoginCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? decoder.decode(StoredLoginCredential.self, from: data)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
