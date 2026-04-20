import SwiftUI

struct PlaylistListView: View {
    @State private var viewModel = PlaylistListViewModel()

    private var displayRecentlyResolved: [Track] {
        if viewModel.showAllRecentlyResolved {
            return viewModel.recentlyResolved
        } else {
            return Array(viewModel.recentlyResolved.prefix(3))
        }
    }

    private var hasMoreRecentlyResolved: Bool {
        viewModel.recentlyResolved.count > 3
    }

    var body: some View {
        NavigationStack {
            List {
                linkInputSection

                if !viewModel.recentlyResolved.isEmpty {
                    recentlyResolvedSection
                }

                Section {
                    ForEach(viewModel.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.headline)

                                Text("\(playlist.trackEntries.count) 首歌曲")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deletePlaylists)
                } header: {
                    Text("我的歌单")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("歌曲")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateSheet, onDismiss: {
                viewModel.refreshPlaylists()
            }) {
                CreatePlaylistView { _ in
                    viewModel.refreshPlaylists()
                }
            }
            .sheet(isPresented: $viewModel.showingAddToPlaylistSheet) {
                if let track = viewModel.selectedTrackForPlaylist {
                    AddToPlaylistView(track: track, isPresented: $viewModel.showingAddToPlaylistSheet) { playlist in
                        viewModel.addSuccessMessage = "已添加到「\(playlist.name)」"
                        viewModel.showAddSuccessToast = true
                        viewModel.refreshPlaylists()
                    }
                }
            }
            .alert("解析失败", isPresented: $viewModel.showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .toast(isPresented: $viewModel.showAddSuccessToast, message: viewModel.addSuccessMessage)
            .onAppear {
                viewModel.refreshPlaylists()
                viewModel.loadRecentlyResolved()
            }
        }
    }

    // MARK: - Link Input Section

    private var linkInputSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("添加歌曲")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)

                        TextField("粘贴音乐链接", text: $viewModel.linkInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(viewModel.isResolving)
                            .submitLabel(.go)
                            .onSubmit {
                                viewModel.resolveLink()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(action: viewModel.resolveLink) {
                        if viewModel.isResolving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("解析")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isResolving)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Recently Resolved Section

    private var recentlyResolvedSection: some View {
        Section {
            ForEach(displayRecentlyResolved) { track in
                RecentlyResolvedRowView(
                    track: track,
                    onAddToPlaylist: {
                        viewModel.selectedTrackForPlaylist = track
                        viewModel.showingAddToPlaylistSheet = true
                    },
                    onTrackUpdated: { updatedTrack in
                        viewModel.updateRecentlyResolvedTrack(updatedTrack)
                    }
                )
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        viewModel.selectedTrackForPlaylist = track
                        viewModel.showingAddToPlaylistSheet = true
                    } label: {
                        Label("加入歌单", systemImage: "plus.circle")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.removeRecentlyResolved(track)
                    } label: {
                        Label("移除", systemImage: "trash")
                    }
                }
            }

            if hasMoreRecentlyResolved {
                Button {
                    withAnimation {
                        viewModel.showAllRecentlyResolved.toggle()
                    }
                } label: {
                    Text(viewModel.showAllRecentlyResolved ? "收起" : "查看全部 (\(viewModel.recentlyResolved.count))")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("最近解析")
        }
    }
}

// MARK: - Recently Resolved Row View

private struct RecentlyResolvedRowView: View {
    let track: Track
    let onAddToPlaylist: () -> Void
    let onTrackUpdated: (Track) -> Void

    var body: some View {
        NavigationLink {
            SongDetailView(track: track, onTrackUpdated: onTrackUpdated)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))

                    if let artworkURL = track.artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(track.sourcePlatformName)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlaylistListView()
}
