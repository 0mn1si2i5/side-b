import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @State private var trackEntries: [PlaylistTrackEntry] = []
    @State private var entryTracks: [String: Track] = [:]
    @State private var isRefreshing = false
    @State private var showingRenameSheet = false
    @State private var renameText = ""
    @State private var showingDeleteConfirmation = false
    @State private var currentPlaylist: Playlist
    @Environment(\.dismiss) private var dismiss

    init(playlist: Playlist) {
        self.playlist = playlist
        _currentPlaylist = State(initialValue: playlist)
        _renameText = State(initialValue: playlist.name)
    }

    var body: some View {
        List {
            if trackEntries.isEmpty {
                emptyStateView
            } else {
                ForEach(sortedTrackEntries) { entry in
                    NavigationLink {
                        SongDetailView(track: resolvedTrack(for: entry) ?? Track(
                            title: "Unknown Song",
                            artistName: "Unknown Artist",
                            sourcePlatform: .spotify,
                            sourcePlatformID: entry.trackID
                        ))
                    } label: {
                        PlaylistSongRowView(
                            entry: entry,
                            track: resolvedTrack(for: entry)
                        )
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteTrackEntry(entry)
                        } label: {
                            Label("移除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            isRefreshing = true
            loadTrackEntries()
            isRefreshing = false
        }
        .navigationTitle(currentPlaylist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingRenameSheet = true
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("移除歌单", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("重命名歌单", isPresented: $showingRenameSheet) {
            TextField("歌单名称", text: $renameText)
            Button("取消", role: .cancel) {
                renameText = currentPlaylist.name
            }
            Button("确定") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if let updated = PlaylistStore.shared.renamePlaylist(currentPlaylist, to: trimmed) {
                    currentPlaylist = updated
                }
            }
        } message: {
            Text("输入新的歌单名称")
        }
        .alert("移除歌单", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("移除", role: .destructive) {
                if !currentPlaylist.isDefault {
                    _ = PlaylistStore.shared.deletePlaylist(currentPlaylist)
                    dismiss()
                }
            }
        } message: {
            Text("确定要移除「\(currentPlaylist.name)」吗？移除后无法恢复。")
        }
        .onAppear {
            loadTrackEntries()
        }
    }

    private var sortedTrackEntries: [PlaylistTrackEntry] {
        trackEntries.sorted { $0.addedAt > $1.addedAt }
    }

    private var emptyStateView: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("暂无歌曲")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("从歌曲卡片中添加歌曲到此歌单")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func loadTrackEntries() {
        trackEntries = PlaylistStore.shared.getTrackEntries(for: currentPlaylist)
        resolveTracksForEntries()
    }

    private func resolveTracksForEntries() {
        var tracks: [String: Track] = [:]
        for entry in trackEntries {
            if let cachedTrack = TrackCache.shared.track(for: entry.trackID) {
                tracks[entry.trackID] = cachedTrack
            } else if let mockTrack = MockData.track(forTrackID: entry.trackID) {
                tracks[entry.trackID] = mockTrack
            }
        }
        entryTracks = tracks
    }

    private func resolvedTrack(for entry: PlaylistTrackEntry) -> Track? {
        entryTracks[entry.trackID]
    }

    private func deleteTrackEntry(_ entry: PlaylistTrackEntry) {
        if PlaylistStore.shared.removeTrack(entry, from: currentPlaylist) {
            loadTrackEntries()
        }
    }
}

private struct PlaylistSongRowView: View {
    let entry: PlaylistTrackEntry
    let track: Track?

    var body: some View {
        HStack(spacing: 12) {
            artworkView

            VStack(alignment: .leading, spacing: 4) {
                Text(track?.title ?? "Unknown Song")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(track?.artistName ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let track = track {
                    Text(track.sourcePlatformName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))

            if let artworkURL = track?.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderIcon
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .font(.system(size: 20))
            .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PlaylistDetailView(playlist: MockData.playlists[1])
    }
}
#endif
