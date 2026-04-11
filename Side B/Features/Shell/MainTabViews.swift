import SwiftUI

struct HomeTabView: View {
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

struct RoomsListView: View {
    let rooms = MockData.rooms

    var body: some View {
        List(rooms) { room in
            NavigationLink {
                RoomDetailView(room: room)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name)
                        .font(.headline)

                    if let latestTrack = room.latestTrack {
                        Text("\(latestTrack.title) · \(latestTrack.artistName)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    if let latestMessagePreview = room.latestMessagePreview {
                        Text(latestMessagePreview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle("Rooms")
    }
}

struct RoomDetailView: View {
    let room: Room
    let messages = MockData.messages

    var body: some View {
        List {
            if let latestTrack = room.latestTrack {
                Section("Now in Room") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latestTrack.title)
                            .font(.headline)

                        Text(latestTrack.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Messages") {
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message.senderName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let text = message.text {
                            Text(text)
                                .font(.body)
                        }

                        if let track = message.track {
                            Text("\(track.title) · \(track.artistName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileTabView: View {
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
