import SwiftUI

struct AddToPlaylistView: View {
    let track: Track
    @Binding var isPresented: Bool

    @State private var playlists: [Playlist] = []
    @State private var showDuplicateAlert = false
    @State private var selectedPlaylistName: String = ""

    private let playlistStore = PlaylistStore.shared

    var body: some View {
        NavigationView {
            List(playlists) { playlist in
                PlaylistRow(
                    playlist: playlist,
                    onTap: { addTrack(to: playlist) }
                )
            }
            .listStyle(.plain)
            .navigationTitle("添加到歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadPlaylists()
            }
            .alert("提示", isPresented: $showDuplicateAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("该歌曲已在「\(selectedPlaylistName)」中")
            }
        }
    }

    private func loadPlaylists() {
        playlists = playlistStore.loadPlaylists()
    }

    private func addTrack(to playlist: Playlist) {
        guard let trackID = track.persistenceIdentity else {
            return
        }

        let success = playlistStore.addTrack(trackID, to: playlist)

        if success {
            isPresented = false
        } else {
            selectedPlaylistName = playlist.name
            showDuplicateAlert = true
        }
    }
}

private struct PlaylistRow: View {
    let playlist: Playlist
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text("\(playlist.trackEntries.count) 首歌曲")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var isPresented = true

        var body: some View {
            AddToPlaylistView(
                track: Track(
                    title: "测试歌曲",
                    artistName: "测试艺人",
                    sourcePlatform: .spotify
                ),
                isPresented: $isPresented
            )
        }
    }

    return PreviewContainer()
}
