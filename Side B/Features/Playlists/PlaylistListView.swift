import SwiftUI

struct PlaylistListView: View {
    @State private var playlists: [Playlist] = []
    @State private var showingCreateSheet = false
    @State private var linkInput = ""
    @State private var isResolving = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var recentlyResolved: [Track] = []
    @State private var showAllRecentlyResolved = false
    @State private var showingAddToPlaylistSheet = false
    @State private var selectedTrackForPlaylist: Track?
    @State private var showAddSuccessToast = false
    @State private var addSuccessMessage = ""
    private let resolver = ResolverServiceFactory.makeDefaultService()

    private var displayRecentlyResolved: [Track] {
        if showAllRecentlyResolved {
            return recentlyResolved
        } else {
            return Array(recentlyResolved.prefix(3))
        }
    }

    private var hasMoreRecentlyResolved: Bool {
        recentlyResolved.count > 3
    }

    var body: some View {
        NavigationStack {
            List {
                linkInputSection

                if !recentlyResolved.isEmpty {
                    recentlyResolvedSection
                }

                Section {
                    ForEach(playlists) { playlist in
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
                    .onDelete(perform: deletePlaylists)
                } header: {
                    Text("我的歌单")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("歌单")
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
            .sheet(isPresented: $showingAddToPlaylistSheet) {
                if let track = selectedTrackForPlaylist {
                    AddToPlaylistView(track: track, isPresented: $showingAddToPlaylistSheet) { playlist in
                        addSuccessMessage = "已添加到「\(playlist.name)」"
                        showAddSuccessToast = true
                        refreshPlaylists()
                    }
                }
            }
            .alert("解析失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toast(isPresented: $showAddSuccessToast, message: addSuccessMessage)
            .onAppear {
                refreshPlaylists()
                loadRecentlyResolved()
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

                        TextField("粘贴音乐链接", text: $linkInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isResolving)
                            .submitLabel(.go)
                            .onSubmit {
                                resolveLink()
                            }
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
                            Text("解析")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving)
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
                        selectedTrackForPlaylist = track
                        showingAddToPlaylistSheet = true
                    }
                )
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        selectedTrackForPlaylist = track
                        showingAddToPlaylistSheet = true
                    } label: {
                        Label("加入歌单", systemImage: "plus.circle")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeRecentlyResolved(track)
                    } label: {
                        Label("移除", systemImage: "trash")
                    }
                }
            }

            if hasMoreRecentlyResolved {
                Button {
                    withAnimation {
                        showAllRecentlyResolved.toggle()
                    }
                } label: {
                    Text(showAllRecentlyResolved ? "收起" : "查看全部 (\(recentlyResolved.count))")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("最近解析")
        }
    }

    // MARK: - Actions

    private func resolveLink() {
        let trimmedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return }

        isResolving = true

        DispatchQueue.global(qos: .userInitiated).async {
            let response = resolver.resolveMetadata(request: ResolverRequest(rawLink: trimmedLink))

            DispatchQueue.main.async {
                isResolving = false

                switch response.parsingResult {
                case .unsupportedLink:
                    errorMessage = "无法识别该链接，请粘贴 Spotify、Apple Music、网易云音乐或 QQ 音乐的歌曲链接"
                    showErrorAlert = true
                    return
                case .missingResourceID:
                    errorMessage = "无法从链接中提取歌曲 ID"
                    showErrorAlert = true
                    return
                case .parsed:
                    break
                }

                if response.metadataStatus == .fallbackMock {
                    errorMessage = "无法解析该歌曲，请检查链接是否正确"
                    showErrorAlert = true
                    return
                }

                let track = response.resolvedTrack.track
                if !track.title.isEmpty {
                    TrackCache.shared.save(track: track)
                    RecentlyResolvedStore.shared.add(track.persistenceIdentity ?? "")

                    recentlyResolved.insert(track, at: 0)

                    if recentlyResolved.count > 50 {
                        recentlyResolved = Array(recentlyResolved.prefix(50))
                    }

                    linkInput = ""

                    resolvePlatformLinksAsync(for: track)
                } else {
                    errorMessage = "无法解析该链接，请检查链接是否正确"
                    showErrorAlert = true
                }
            }
        }
    }

    private func resolvePlatformLinksAsync(for track: Track) {
        let nonSourcePlatforms = MusicPlatform.allCases.filter { $0 != track.sourcePlatform }
        let pendingPlatforms = nonSourcePlatforms.filter { platform in
            let state = track.platformLinkState(for: platform)
            return state == .idle || state == .failed
        }

        guard !pendingPlatforms.isEmpty else { return }

        for platform in pendingPlatforms {
            DispatchQueue.global(qos: .utility).async {
                let result = resolver.resolvePlatformLink(for: track, targetPlatform: platform)

                DispatchQueue.main.async {
                    if let index = recentlyResolved.firstIndex(where: { $0.id == track.id }) {
                        let updatedTrack = recentlyResolved[index].updatingPlatformLink(
                            result.platformLink,
                            state: result.state,
                            for: platform
                        )
                        recentlyResolved[index] = updatedTrack
                        TrackCache.shared.save(track: updatedTrack)
                    }
                }
            }
        }
    }

    private func loadRecentlyResolved() {
        let identities = RecentlyResolvedStore.shared.allEntries()
        var tracks: [Track] = []
        for identity in identities {
            if let track = TrackCache.shared.track(for: identity) {
                tracks.append(track)
            } else if let mockTrack = MockData.track(forTrackID: identity) {
                tracks.append(mockTrack)
            }
        }
        recentlyResolved = tracks
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

    private func refreshPlaylists() {
        playlists = PlaylistStore.shared.loadPlaylists()
    }

    private func removeRecentlyResolved(_ track: Track) {
        recentlyResolved.removeAll { $0.id == track.id }
        if let identity = track.persistenceIdentity {
            RecentlyResolvedStore.shared.remove(identity: identity)
        }
    }
}

// MARK: - Recently Resolved Row View

private struct RecentlyResolvedRowView: View {
    let track: Track
    let onAddToPlaylist: () -> Void

    var body: some View {
        NavigationLink {
            SongDetailView(track: track)
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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    VStack {
                        Spacer()

                        Text(message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(.bottom, 60)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}

#Preview {
    PlaylistListView()
}