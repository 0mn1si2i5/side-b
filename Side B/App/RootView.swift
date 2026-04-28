import SwiftUI

struct RootView: View {
    @State private var authState = AuthState()
    @AppStorage(SideBVisualStyle.appAppearanceStorageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue

    private var isConfigured: Bool {
        APIConfiguration.baseURL != nil && ResolverServiceFactory.isConfigured
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }

    var body: some View {
        Group {
            if !isConfigured {
                ConfigurationErrorView()
            } else if authState.isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView(viewModel: AuthViewModel(authState: authState))
                }
            }
        }
        .environment(authState)
        .tint(.primary)
        .preferredColorScheme(appAppearance.colorScheme)
        .task {
            guard isConfigured else { return }
            await authState.checkAuthStatus()
        }
    }
}

struct ConfigurationErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("配置错误")
                .font(.title2.bold())
            Text("未设置 API 地址。请在环境变量中配置 SIDEB_API_BASE_URL，或在设置中指定服务器地址。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            PlaylistListView()
                .tabItem {
                    Label("歌曲", systemImage: "music.note.list")
                }

            NavigationStack {
                RoomsListView()
            }
            .tabItem {
                Label("房间", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                ProfileTabView()
            }
            .tabItem {
                Label("设置", systemImage: "slider.horizontal.3")
            }
        }
    }
}

#Preview {
    RootView()
}
