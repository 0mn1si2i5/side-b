import SwiftUI

enum RoomsListState {
    case idle
    case loading
    case loaded([Room])
    case failed(String)
}

@Observable
final class RoomsListViewModel {
    var state: RoomsListState = .idle

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()) {
        self.service = service
    }

    func loadRooms() {
        state = .loading
        Task { @MainActor in
            do {
                let rooms = try await service.fetchRooms()
                state = .loaded(rooms)
            } catch {
                state = .failed(localizedErrorMessage(for: error))
            }
        }
    }
}

struct HomeTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Side B")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("跨平台音乐分享，让朋友听到你喜欢的歌")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("首页")
    }
}

struct RoomsListView: View {
    @State private var viewModel = RoomsListViewModel()
    @State private var showingCreateRoom = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("加载中...")
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.loadRooms()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            case .loaded(let rooms):
                if rooms.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无房间")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    roomsList(rooms: rooms)
                }
            }
        }
        .task {
            if case .idle = viewModel.state {
                viewModel.loadRooms()
            }
        }
        .navigationTitle("聊天室")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateRoom = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateRoom, onDismiss: {
            if case .loaded = viewModel.state {
                viewModel.loadRooms()
            }
        }) {
            NavigationStack {
                CreateRoomView()
            }
        }
    }

    private func roomsList(rooms: [Room]) -> some View {
        List(rooms) { room in
            NavigationLink {
                RoomDetailView(room: room)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(room.name)
                            .font(.headline)

                        if room.type == .direct {
                            Text("私聊")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

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
    }
}

struct SongDetailView: View {
    @State private var viewModel: SongDetailViewModel
    @Environment(\.openURL) private var openURL

    init(
        track: Track,
        resolver: any MusicResolverService = ResolverServiceFactory.makeDefaultService(),
        persistenceStore: PlatformLinkPersistenceStore = .shared,
        onTrackUpdated: ((Track) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: SongDetailViewModel(
            track: track,
            resolver: resolver,
            persistenceStore: persistenceStore,
            onTrackUpdated: onTrackUpdated
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                artworkSection

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.displayTrack.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(viewModel.displayTrack.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let albumTitle = viewModel.displayTrack.albumTitle {
                        Text("专辑：\(albumTitle)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Text("来源：\(viewModel.displayTrack.sourcePlatformName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("打开方式")
                        .font(.headline)

                    ForEach(viewModel.platformSlotRows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.platform) { slot in
                                PlatformJumpButton(
                                    title: slot.title,
                                    isEnabled: slot.isEnabled,
                                    isLoading: slot.isLoading
                                ) {
                                    handlePlatformSlotTap(slot)
                                }
                            }
                        }
                    }
                }

                Button {
                    viewModel.showingAddToPlaylistSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("添加到歌单")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .navigationTitle(viewModel.displayTrack.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("即将上线", isPresented: $viewModel.isShowingPlatformFeedback) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.platformFeedbackMessage)
        }
        .task(id: viewModel.displayTrack.id) {
            viewModel.hydrateDisplayTrackFromPersistence()
            viewModel.resolvePendingPlatformLinksIfNeeded()
        }
        .sheet(isPresented: $viewModel.showingAddToPlaylistSheet) {
            AddToPlaylistView(track: viewModel.displayTrack, isPresented: $viewModel.showingAddToPlaylistSheet) { playlist in
                viewModel.addSuccessMessage = "已添加到「\(playlist.name)」"
                viewModel.showAddSuccessToast = true
            }
        }
        .toast(isPresented: $viewModel.showAddSuccessToast, message: viewModel.addSuccessMessage)
    }

    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.secondary.opacity(0.15))

            if let artworkURL = viewModel.displayTrack.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func handlePlatformSlotTap(_ slot: PlatformSlot) {
        let action = viewModel.handlePlatformSlotTap(slot)
        switch action {
        case .none:
            break
        case .openURL(let url):
            openURL(url) { accepted in
                if !accepted {
                    viewModel.platformFeedbackMessage = "无法打开\(slot.link?.platformName ?? "")"
                    viewModel.isShowingPlatformFeedback = true
                }
            }
        case .showFeedback(let message):
            viewModel.platformFeedbackMessage = message
            viewModel.isShowingPlatformFeedback = true
        case .retry(let platform):
            viewModel.retryPlatformLinkResolution(for: platform)
        }
    }
}

struct PlatformJumpButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(isEnabled ? .gray : .secondary)
        .disabled(!isEnabled || isLoading)
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
    @Environment(AuthState.self) private var authState

    var body: some View {
        List {
            if let user = authState.currentUser {
                Section {
                    HStack(spacing: 16) {
                        let avatarConfig = AvatarService.config(for: user.avatarName)
                        Image(systemName: avatarConfig.symbolName)
                            .font(.system(size: 48))
                            .foregroundStyle(avatarConfig.backgroundColor)
                            .frame(width: 64, height: 64)
                            .background(avatarConfig.backgroundColor.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let platform = user.preferredPlatform {
                                Text("常用平台：\(platform.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authState.logout() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("我的")
    }
}
