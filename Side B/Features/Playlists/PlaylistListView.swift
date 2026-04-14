import SwiftUI

struct PlaylistListView: View {
    @State private var playlists: [Playlist] = []
    @State private var showingCreateSheet = false
    @State private var linkInput = ""
    @State private var isResolving = false
    @State private var showAddToPlaylistSheet = false
    @State private var resolvedTrack: Track?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    private let resolver = ResolverServiceFactory.makeDefaultService()

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistList
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                refreshPlaylists()
            }) {
                CreatePlaylistView { _ in
                    refreshPlaylists()
                }
            }
            .sheet(isPresented: $showAddToPlaylistSheet) {
                if let track = resolvedTrack {
                    AddToPlaylistView(track: track, isPresented: $showAddToPlaylistSheet)
                }
            }
            .alert("解析失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                refreshPlaylists()
            }
        }
    }

    private var playlistList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("添加歌曲")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                            
                            TextField("粘贴音乐链接", text: $linkInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .disabled(isResolving)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        Button(action: resolveLink) {
                            if isResolving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("添加")
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                ForEach(playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.name)
                                .font(.headline)

                            Text("\(playlist.trackEntries.count) songs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deletePlaylists)
            } header: {
                Text("我的歌单")
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func resolveLink() {
        let trimmedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return }
        
        isResolving = true

        DispatchQueue.global(qos: .userInitiated).async {
            let track = resolver.resolveTrack(from: trimmedLink)

            DispatchQueue.main.async {
                isResolving = false

                if !track.title.isEmpty {
                    resolvedTrack = track
                    showAddToPlaylistSheet = true
                    linkInput = ""
                } else {
                    errorMessage = "无法解析该链接，请检查链接是否正确"
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            let playlist = playlists[index]
            if !playlist.isDefault {
                _ = PlaylistStore.shared.deletePlaylist(playlist)
            }
        }
        refreshPlaylists()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Playlists Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create your first playlist to start organizing your favorite songs.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private func refreshPlaylists() {
        playlists = PlaylistStore.shared.loadPlaylists()
    }
}

#Preview {
    PlaylistListView()
}
