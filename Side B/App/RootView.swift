import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                RoomsView()
            }
            .tabItem {
                Label("Rooms", systemImage: "music.note.list")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}

private struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Side B")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A cross-platform music sharing inbox for friends.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("Home")
    }
}

private struct RoomsView: View {
    let mockRooms = [
        "Late Night Loop",
        "Side B Club",
        "Daily Finds"
    ]

    var body: some View {
        List(mockRooms, id: \.self) { room in
            NavigationLink(room) {
                RoomDetailPlaceholderView(roomName: room)
            }
        }
        .navigationTitle("Rooms")
    }
}

private struct RoomDetailPlaceholderView: View {
    let roomName: String

    var body: some View {
        VStack(spacing: 12) {
            Text(roomName)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Room detail placeholder")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))

            Text("Your Profile")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Shared songs, saved tracks, and listening activity will appear here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    RootView()
}