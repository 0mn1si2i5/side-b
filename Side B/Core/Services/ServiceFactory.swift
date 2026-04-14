import Foundation

enum AuthServiceFactory {
    private static let environmentBaseURLKey = "SIDEB_API_BASE_URL"

    static func makeDefaultService() -> any AuthServiceProtocol {
        guard
            let baseURLString = ProcessInfo.processInfo.environment[environmentBaseURLKey],
            let baseURL = URL(string: baseURLString)
        else {
            return MockAuthService()
        }

        return RemoteAuthService(baseURL: baseURL)
    }
}
