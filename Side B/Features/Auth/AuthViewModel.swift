import Foundation

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?

    private let authService: any AuthServiceProtocol
    private weak var authState: AuthState?

    init(
        authService: any AuthServiceProtocol = AuthServiceFactory.makeDefaultService(),
        authState: AuthState? = nil
    ) {
        self.authService = authService
        self.authState = authState
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
            authState?.handleAuthenticationSuccess(user: user)
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
            authState?.handleAuthenticationSuccess(user: user)
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
            return error.localizedDescription
        }
    }
}