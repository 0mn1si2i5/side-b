import Foundation
import os

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

        return productionBaseURL
    }
}

// MARK: - Auth Service Factory

enum AuthServiceFactory {
    private static let logger = Logger(subsystem: "com.sideb.app", category: "ServiceFactory")

    static func makeDefaultService() -> (any AuthServiceProtocol)? {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockAuthService()
            #else
            logger.error("AuthServiceFactory: SIDEB_API_BASE_URL not configured. Cannot create auth service.")
            return nil
            #endif
        }

        return RemoteAuthService(baseURL: baseURL)
    }
}

// MARK: - WebSocket Service Factory

enum WebSocketServiceFactory {
    private static let logger = Logger(subsystem: "com.sideb.app", category: "ServiceFactory")

    static func makeDefaultService() -> (any WebSocketServiceProtocol)? {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockWebSocketService()
            #else
            logger.error("WebSocketServiceFactory: SIDEB_API_BASE_URL not configured. Cannot create WebSocket service.")
            return nil
            #endif
        }

        return RemoteWebSocketService(baseURL: baseURL)
    }
}

// MARK: - Room Service Factory

enum RoomServiceFactory {
    private static let logger = Logger(subsystem: "com.sideb.app", category: "ServiceFactory")

    static func makeDefaultService() -> (any RoomServiceProtocol)? {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockRoomService()
            #else
            logger.error("RoomServiceFactory: SIDEB_API_BASE_URL not configured. Cannot create room service.")
            return nil
            #endif
        }

        return RemoteRoomService(baseURL: baseURL)
    }
}

// MARK: - Message Service Factory

enum MessageServiceFactory {
    private static let logger = Logger(subsystem: "com.sideb.app", category: "ServiceFactory")

    static func makeDefaultService() -> (any MessageServiceProtocol)? {
        guard let baseURL = APIConfiguration.baseURL else {
            #if DEBUG
            return MockMessageService()
            #else
            logger.error("MessageServiceFactory: SIDEB_API_BASE_URL not configured. Cannot create message service.")
            return nil
            #endif
        }

        return RemoteMessageService(baseURL: baseURL)
    }
}
