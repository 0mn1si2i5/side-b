import Foundation

// MARK: - Shared API Base URL Configuration

enum APIConfiguration {
    private static let environmentKey = "SIDEB_API_BASE_URL"
    private static let userDefaultsKey = "SideB_APIBaseURL"

    /// Programmatically override the API base URL at runtime.
    /// Takes precedence over environment variables and UserDefaults.
    static var configuredBaseURL: URL?

    /// Save a base URL to UserDefaults for production use without Xcode env vars.
    static func persistBaseURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: userDefaultsKey)
    }

    static var baseURL: URL? {
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

        return nil
    }
}

// MARK: - Auth Service Factory

enum AuthServiceFactory {
    static func makeDefaultService() -> any AuthServiceProtocol {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockAuthService()
            #else
            fatalError("SIDEB_API_BASE_URL must be set in production")
            #endif
        }

        return RemoteAuthService(baseURL: baseURL)
    }
}

// MARK: - WebSocket Service Factory

enum WebSocketServiceFactory {
    static func makeDefaultService() -> any WebSocketServiceProtocol {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockWebSocketService()
            #else
            fatalError("SIDEB_API_BASE_URL must be set in production")
            #endif
        }

        return RemoteWebSocketService(baseURL: baseURL)
    }
}

// MARK: - Room Service Factory

enum RoomServiceFactory {
    static func makeDefaultService() -> any RoomServiceProtocol {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockRoomService()
            #else
            fatalError("SIDEB_API_BASE_URL must be set in production")
            #endif
        }

        return RemoteRoomService(baseURL: baseURL)
    }
}

// MARK: - Message Service Factory

enum MessageServiceFactory {
    static func makeDefaultService() -> any MessageServiceProtocol {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockMessageService()
            #else
            fatalError("SIDEB_API_BASE_URL must be set in production")
            #endif
        }

        return RemoteMessageService(baseURL: baseURL)
    }
}
