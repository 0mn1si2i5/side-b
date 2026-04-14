import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PlaylistListView()
                .tabItem {
                    Label("Playlist", systemImage: "music.note.list")
                }

            NavigationStack {
                RoomsListView()
            }
            .tabItem {
                Label("Rooms", systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationStack {
                ProfileTabView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}

#Preview {
    RootView()
}
