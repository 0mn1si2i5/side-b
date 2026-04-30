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
    private let credentialStore: KeychainCredentialStore
    private let userDefaults: UserDefaults

    init(
        authService: any AuthServiceProtocol = AuthServiceFactory.makeDefaultService(),
        credentialStore: KeychainCredentialStore = KeychainCredentialStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.credentialStore = credentialStore
        self.userDefaults = userDefaults
    }

    func checkAuthStatus() async {
        errorMessage = nil

        guard authService.isLoggedIn else {
            await attemptRememberedLogin()
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

            if classifyError(error) == .authError {
                authService.clearStoredToken()
                await attemptRememberedLogin(keepsLoading: true)
            } else {
                errorMessage = "自动登录失败：\(localizedErrorMessage(for: error))"
            }
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
        credentialStore.delete()
        userDefaults.set(false, forKey: AuthPreferenceKeys.rememberPassword)
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }

    private func attemptRememberedLogin(keepsLoading: Bool = false) async {
        guard userDefaults.bool(forKey: AuthPreferenceKeys.rememberPassword),
              let credential = credentialStore.load()
        else {
            isAuthenticated = false
            currentUser = nil
            if !keepsLoading {
                isLoading = false
            }
            return
        }

        if !keepsLoading {
            isLoading = true
        }

        do {
            _ = try await authService.login(username: credential.username, password: credential.password)
            let user = try await authService.getCurrentUser()
            currentUser = user
            isAuthenticated = true
            errorMessage = nil
        } catch {
            authService.clearStoredToken()
            if classifyError(error) == .authError {
                credentialStore.delete()
                userDefaults.set(false, forKey: AuthPreferenceKeys.rememberPassword)
                userDefaults.removeObject(forKey: AuthPreferenceKeys.lastUsername)
            } else {
                errorMessage = "自动登录失败：\(localizedErrorMessage(for: error))"
            }
            currentUser = nil
            isAuthenticated = false
        }

        if !keepsLoading {
            isLoading = false
        }
    }
}
