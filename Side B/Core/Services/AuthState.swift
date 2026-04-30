import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "AuthState")

@MainActor
@Observable
final class AuthState {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?

    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol = AuthServiceFactory.makeDefaultService()!) {
        self.authService = authService
    }

    func checkAuthStatus() async {
        guard authService.isLoggedIn else {
            isAuthenticated = false
            currentUser = nil
            return
        }

        isLoading = true

        do {
            let user = try await authService.getCurrentUser()
            currentUser = user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
            errorMessage = "自动登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func handleAuthenticationSuccess(user: User) {
        currentUser = user
        isAuthenticated = true
    }

    func updatePreferredPlatform(_ platform: MusicPlatform?) async {
        do {
            let user = try await authService.updatePreferredPlatform(platform)
            currentUser = user
        } catch {
            errorMessage = "更新偏好平台失败：\(error.localizedDescription)"
        }
    }

    func updateProfile(displayName: String?, avatarName: String?) async -> Bool {
        do {
            let user = try await authService.updateProfile(displayName: displayName, avatarName: avatarName)
            currentUser = user
            return true
        } catch {
            errorMessage = "更新个人资料失败：\(error.localizedDescription)"
            return false
        }
    }

    func logout() async {
        do {
            try await authService.logout()
        } catch {
            logger.error("logout failed: \(error)")
        }
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }
}
