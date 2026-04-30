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

    func updatePreferredPlatform(_ platform: MusicPlatform?) async throws -> User

    func updateProfile(displayName: String?, avatarName: String?) async throws -> User

    func logout() async throws

    func clearStoredToken()

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

// MARK: - Error Classification

enum AppErrorCategory {
    case networkUnavailable
    case serverError
    case authError
    case notFound
    case unknown
}

func classifyError(_ error: Error) -> AppErrorCategory {
    let nsError = error as NSError

    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed,
             .cannotFindHost, .cannotConnectToHost, .timedOut:
            return .networkUnavailable
        default:
            break
        }
    }

    if nsError.domain == NSURLErrorDomain {
        let code = nsError.code
        if code == NSURLErrorNotConnectedToInternet ||
            code == NSURLErrorNetworkConnectionLost ||
            code == NSURLErrorTimedOut ||
            code == NSURLErrorCannotFindHost ||
            code == NSURLErrorCannotConnectToHost ||
            code == NSURLErrorDNSLookupFailed {
            return .networkUnavailable
        }
    }

    let statusCode = extractStatusCode(from: error)
    if let statusCode {
        switch statusCode {
        case 401:
            return .authError
        case 404:
            return .notFound
        case 500...599:
            return .serverError
        default:
            break
        }
    }

    if let authError = error as? AuthServiceError {
        switch authError {
        case .notAuthenticated: return .authError
        case .invalidHTTPResponse: return .serverError
        default: break
        }
    }

    if let roomError = error as? RoomServiceError {
        switch roomError {
        case .notAuthenticated: return .authError
        case .invalidHTTPResponse: return .serverError
        default: break
        }
    }

    if let messageError = error as? MessageServiceError {
        switch messageError {
        case .notAuthenticated: return .authError
        case .invalidHTTPResponse: return .serverError
        default: break
        }
    }

    return .unknown
}

func localizedErrorMessage(for error: Error) -> String {
    let category = classifyError(error)
    switch category {
    case .networkUnavailable:
        return "网络不可用，请检查网络连接"
    case .serverError:
        return "服务器错误，请稍后重试"
    case .authError:
        return "登录已过期，请重新登录"
    case .notFound:
        return "未找到请求的资源"
    case .unknown:
        if let authError = error as? AuthServiceError {
            switch authError {
            case .malformedPayload:
                return "服务器数据格式异常"
            case .tokenStorageFailed:
                return "本地存储失败，请重试"
            case .invalidBaseURL:
                return "服务器地址配置错误"
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

private func extractStatusCode(from error: Error) -> Int? {
    if let authError = error as? AuthServiceError,
       case .unsuccessfulStatusCode(let code) = authError {
        return code
    }
    if let roomError = error as? RoomServiceError,
       case .unsuccessfulStatusCode(let code, _) = roomError {
        return code
    }
    if let messageError = error as? MessageServiceError,
       case .unsuccessfulStatusCode(let code, _) = messageError {
        return code
    }
    return nil
}
