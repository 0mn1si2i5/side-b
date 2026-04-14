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

enum WebSocketServiceFactory {
    private static let environmentBaseURLKey = "SIDEB_API_BASE_URL"

    static func makeDefaultService() -> any WebSocketServiceProtocol {
        guard
            let baseURLString = ProcessInfo.processInfo.environment[environmentBaseURLKey],
            let baseURL = URL(string: baseURLString)
        else {
            return MockWebSocketService()
        }

        return RemoteWebSocketService(baseURL: baseURL)
    }
}

enum RoomServiceFactory {
    private static let environmentBaseURLKey = "SIDEB_API_BASE_URL"

    static func makeDefaultService() -> any RoomServiceProtocol {
        guard
            let baseURLString = ProcessInfo.processInfo.environment[environmentBaseURLKey],
            let baseURL = URL(string: baseURLString)
        else {
            return MockRoomService()
        }

        return RemoteRoomService(baseURL: baseURL)
    }
}

enum MessageServiceFactory {
    private static let environmentBaseURLKey = "SIDEB_API_BASE_URL"

    static func makeDefaultService() -> any MessageServiceProtocol {
        guard
            let baseURLString = ProcessInfo.processInfo.environment[environmentBaseURLKey],
            let baseURL = URL(string: baseURLString)
        else {
            return MockMessageService()
        }

        return RemoteMessageService(baseURL: baseURL)
    }
}
