import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeTabView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                RoomsListView()
            }
            .tabItem {
                Label("Rooms", systemImage: "music.note.list")
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
