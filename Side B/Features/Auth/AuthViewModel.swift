import Foundation

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?

    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol = AuthServiceFactory.makeDefaultService()) {
        self.authService = authService
    }

    func login(username: String, password: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            errorMessage = "请输入用户名"
            return
        }
        guard !trimmedPassword.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await authService.login(username: trimmedUsername, password: trimmedPassword)
            let user = try await authService.getCurrentUser()
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = localizedErrorMessage(error)
        }

        isLoading = false
    }

    func register(username: String, password: String, displayName: String, avatarName: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            errorMessage = "请输入用户名"
            return
        }
        guard !trimmedPassword.isEmpty else {
            errorMessage = "请输入密码"
            return
        }
        guard !trimmedDisplayName.isEmpty else {
            errorMessage = "请输入显示名称"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await authService.register(
                username: trimmedUsername,
                password: trimmedPassword,
                displayName: trimmedDisplayName,
                avatarName: avatarName
            )
            let user = try await authService.getCurrentUser()
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = localizedErrorMessage(error)
        }

        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .notAuthenticated:
                return "未登录或登录已过期"
            case .invalidHTTPResponse:
                return "服务器响应异常"
            case .unsuccessfulStatusCode(let code):
                switch code {
                case 401:
                    return "用户名或密码错误"
                case 409:
                    return "该用户名已被注册"
                default:
                    return "请求失败（\(code)）"
                }
            case .malformedPayload:
                return "服务器数据格式异常"
            case .tokenStorageFailed:
                return "本地存储失败，请重试"
            case .invalidBaseURL:
                return "服务器地址配置错误"
            }
        }
        return error.localizedDescription
    }
}