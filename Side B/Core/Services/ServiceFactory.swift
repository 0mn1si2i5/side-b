import Foundation

// MARK: - Shared API Base URL Configuration

enum APIConfiguration {
    private static let environmentKey = "SIDEB_API_BASE_URL"
    private static let userDefaultsKey = "SideB_APIBaseURL"
    private static let productionBaseURL = URL(string: "https://sideb.omnis1215.org")!

    /// Programmatically override the API base URL at runtime.
    /// Takes precedence over environment variables and UserDefaults.
    static var configuredBaseURL: URL?

    /// Save a base URL to UserDefaults for local testing or custom deployments.
    static func persistBaseURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: userDefaultsKey)
    }

    static var baseURL: URL {
        if let configured = configuredBaseURL {
            return configured
        }

        if let envString = ProcessInfo.processInfo.environment[environmentKey],
           let url = URL(string: envString) {
            return url
        }

        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           let url = URL(string: saved) {
            return url
        }

        return productionBaseURL
    }
}

// MARK: - Auth Service Factory

enum AuthServiceFactory {
    static func makeDefaultService() -> any AuthServiceProtocol {
        let baseURL = APIConfiguration.baseURL
        return RemoteAuthService(baseURL: baseURL)
    }
}

// MARK: - WebSocket Service Factory

enum WebSocketServiceFactory {
    static func makeDefaultService() -> any WebSocketServiceProtocol {
        let baseURL = APIConfiguration.baseURL
        return RemoteWebSocketService(baseURL: baseURL)
    }
}

// MARK: - Room Service Factory

enum RoomServiceFactory {
    static func makeDefaultService() -> any RoomServiceProtocol {
        let baseURL = APIConfiguration.baseURL
        return RemoteRoomService(baseURL: baseURL)
    }
}

// MARK: - Message Service Factory

enum MessageServiceFactory {
    static func makeDefaultService() -> any MessageServiceProtocol {
        let baseURL = APIConfiguration.baseURL
        return RemoteMessageService(baseURL: baseURL)
    }
}
