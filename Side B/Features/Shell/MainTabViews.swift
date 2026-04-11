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

struct SongDetailView: View {
    private let platformDisplayOrder = ["Apple Music", "Spotify", "QQ 音乐", "网易云音乐"]
    let track: Track
    @State private var platformFeedbackMessage = ""
    @State private var isShowingPlatformFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(track.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let albumTitle = track.albumTitle {
                        Text("Album: \(albumTitle)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Text("Source: \(track.sourcePlatformName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Lyrics")
                        .font(.headline)

                    Text("Mock lyrics preview")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("City lights blur into morning\nWe keep the chorus for the ride home\nThis section stays static until real lyrics arrive")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Open In")
                        .font(.headline)

                    ForEach(platformButtonRows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { platformName in
                                PlatformJumpButton(title: platformName) {
                                    showPlatformFeedback(for: platformName)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Coming Soon", isPresented: $isShowingPlatformFeedback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(platformFeedbackMessage)
        }
    }

    private func showPlatformFeedback(for platformName: String) {
        platformFeedbackMessage = "Jumping to \(platformName) is not available yet in this mock build."
        isShowingPlatformFeedback = true
    }

    private var platformButtonRows: [[String]] {
        stride(from: 0, to: platformDisplayOrder.count, by: 2).map { index in
            Array(platformDisplayOrder[index..<min(index + 2, platformDisplayOrder.count)])
        }
    }
}

struct PlatformJumpButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
}

struct SongCardView: View {
    let track: Track

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let albumTitle = track.albumTitle {
                    Text(albumTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(track.sourcePlatformName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
