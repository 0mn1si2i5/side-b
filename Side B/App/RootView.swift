import SwiftUI

struct RootView: View {
    @State private var authState = AuthState()

    var body: some View {
        Group {
            if authState.isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView(viewModel: AuthViewModel(authState: authState))
                }
            }
        }
        .environment(authState)
        .task {
            await authState.checkAuthStatus()
        }
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
                Label("聊天室", systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationStack {
                ProfileTabView()
            }
            .tabItem {
                Label("我的", systemImage: "person")
            }
        }
    }
}

#Preview {
    RootView()
}
