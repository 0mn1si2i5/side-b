import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @State private var trackEntries: [PlaylistTrackEntry] = []
    @State private var entryTracks: [String: Track] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if trackEntries.isEmpty {
                emptyStateView
            } else {
                ForEach(sortedTrackEntries) { entry in
                    NavigationLink {
                        if let track = resolvedTrack(for: entry) {
                            SongDetailView(track: track)
                        }
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
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(trackEntries.count) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

                Text("No songs yet")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Add songs to this playlist from song cards")
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
        trackEntries = PlaylistStore.shared.getTrackEntries(for: playlist)
        resolveTracksForEntries()
    }

    private func resolveTracksForEntries() {
        var tracks: [String: Track] = [:]
        for entry in trackEntries {
            if let track = MockData.track(forTrackID: entry.trackID) {
                tracks[entry.trackID] = track
            }
        }
        entryTracks = tracks
    }

    private func resolvedTrack(for entry: PlaylistTrackEntry) -> Track? {
        entryTracks[entry.trackID]
    }

    private func deleteTrackEntry(_ entry: PlaylistTrackEntry) {
        if PlaylistStore.shared.removeTrack(entry, from: playlist) {
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
