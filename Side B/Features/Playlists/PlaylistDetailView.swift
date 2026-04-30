import SwiftUI

struct PlaylistDetailView: View {
    @State private var viewModel: PlaylistDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(playlist: Playlist) {
        _viewModel = State(initialValue: PlaylistDetailViewModel(playlist: playlist))
    }

    var body: some View {
        List {
            if viewModel.trackEntries.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.sortedTrackEntries) { entry in
                    NavigationLink {
                        SongDetailView(track: viewModel.resolvedTrack(for: entry) ?? Track(
                            title: "Unknown Song",
                            artistName: "Unknown Artist",
                            sourcePlatform: .spotify,
                            sourcePlatformID: entry.trackID
                        ))
                    } label: {
                        PlaylistSongRowView(
                            entry: entry,
                            track: viewModel.resolvedTrack(for: entry)
                        )
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteTrackEntry(entry)
                        } label: {
                            Label("移除", systemImage: "trash")
                        }
                        .tint(Color(.systemRed))
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.isRefreshing = true
            viewModel.loadTrackEntries()
            viewModel.isRefreshing = false
        }
        .navigationTitle(viewModel.currentPlaylist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.showingRenameSheet = true
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.showingDeleteConfirmation = true
                    } label: {
                        Label("移除歌单", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("重命名歌单", isPresented: $viewModel.showingRenameSheet) {
            TextField("歌单名称", text: $viewModel.renameText)
            Button("取消", role: .cancel) {
                viewModel.resetRenameText()
            }
            Button("确定") {
                viewModel.renamePlaylist(to: viewModel.renameText)
            }
        } message: {
            Text("输入新的歌单名称")
        }
        .alert("移除歌单", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("移除", role: .destructive) {
                if viewModel.deletePlaylist() {
                    dismiss()
                }
            }
        } message: {
            Text("确定要移除「\(viewModel.currentPlaylist.name)」吗？移除后无法恢复。")
        }
        .onAppear {
            viewModel.loadTrackEntries()
        }
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
                        .foregroundStyle(.sideBLinkBlue)
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
                CachedArtworkImage(url: artworkURL, placeholderFontSize: 20)
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
        PlaylistDetailView(playlist: MockData.playlists[1]) // Preview mock data
    }
}
#endif
