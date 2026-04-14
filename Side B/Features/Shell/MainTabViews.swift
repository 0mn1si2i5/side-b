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
    private let navigationService: PlatformNavigationService = MockPlatformNavigationService()
    private let resolver: any MusicResolverService
    private let persistenceStore: PlatformLinkPersistenceStore
    private let onTrackUpdated: ((Track) -> Void)?
    @State private var displayTrack: Track
    @State private var platformFeedbackMessage = ""
    @State private var isShowingPlatformFeedback = false
    @State private var showingAddToPlaylistSheet = false
    @State private var showAddSuccessToast = false
    @State private var addSuccessMessage = ""
    @Environment(\.openURL) private var openURL

    init(
        track: Track,
        resolver: any MusicResolverService = ResolverServiceFactory.makeDefaultService(),
        persistenceStore: PlatformLinkPersistenceStore = .shared,
        onTrackUpdated: ((Track) -> Void)? = nil
    ) {
        self.resolver = resolver
        self.persistenceStore = persistenceStore
        self.onTrackUpdated = onTrackUpdated
        _displayTrack = State(initialValue: track)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                artworkSection

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTrack.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(displayTrack.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let albumTitle = displayTrack.albumTitle {
                        Text("专辑：\(albumTitle)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Text("来源：\(displayTrack.sourcePlatformName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("打开方式")
                        .font(.headline)

                    ForEach(platformSlotRows, id: \.self) { row in
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
                    showingAddToPlaylistSheet = true
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
        .navigationTitle(displayTrack.title)
        .navigationBarTitleDisplayMode(.inline)
.alert("即将上线", isPresented: $isShowingPlatformFeedback) {
                    Button("好的", role: .cancel) {}
        } message: {
            Text(platformFeedbackMessage)
        }
        .task(id: displayTrack.id) {
            hydrateDisplayTrackFromPersistence()
            resolvePendingPlatformLinksIfNeeded()
        }
        .sheet(isPresented: $showingAddToPlaylistSheet) {
            AddToPlaylistView(track: displayTrack, isPresented: $showingAddToPlaylistSheet) { playlist in
                addSuccessMessage = "已添加到「\(playlist.name)」"
                showAddSuccessToast = true
            }
        }
        .toast(isPresented: $showAddSuccessToast, message: addSuccessMessage)
    }

    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.secondary.opacity(0.15))

            if let artworkURL = displayTrack.artworkURL {
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

    private func showPlatformFeedback(for platformLink: PlatformLink) {
        let destinationURL = platformLink.destinationURL

        guard navigationService.destinationURL(for: platformLink.platform, track: displayTrack) != nil || platformLink.isSource else {
            platformFeedbackMessage = "\(platformLink.platformName) 暂不支持跳转"
            isShowingPlatformFeedback = true
            return
        }

        openURL(destinationURL) { accepted in
            if !accepted {
                platformFeedbackMessage = "无法打开\(platformLink.platformName)"
                isShowingPlatformFeedback = true
            }
        }
    }

    private var platformSlots: [PlatformSlot] {
        MusicPlatform.allCases.map { platform in
            let state = displayTrack.platformLinkState(for: platform)
            let link = displayTrack.platformLink(for: platform)
            return PlatformSlot(platform: platform, state: state, link: link)
        }
    }

    private var platformSlotRows: [[PlatformSlot]] {
        stride(from: 0, to: platformSlots.count, by: 2).map { index in
            Array(platformSlots[index..<min(index + 2, platformSlots.count)])
        }
    }

    private func resolvePendingPlatformLinksIfNeeded() {
        let pendingPlatforms = MusicPlatform.allCases.filter { platform in
            platform != displayTrack.sourcePlatform && shouldResolvePlatformLink(for: platform)
        }

        guard !pendingPlatforms.isEmpty else { return }

        let track = displayTrack
        for platform in pendingPlatforms {
            displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        }

        for platform in pendingPlatforms {
            requestPlatformLink(for: platform, using: track)
        }
    }

    private func shouldResolvePlatformLink(for platform: MusicPlatform) -> Bool {
        let state = displayTrack.platformLinkState(for: platform)
        return state == .idle || state == .failed
    }

    private func handlePlatformSlotTap(_ slot: PlatformSlot) {
        switch slot.state {
        case .ready:
            guard let link = slot.link else { return }
            showPlatformFeedback(for: link)
        case .failed:
            retryPlatformLinkResolution(for: slot.platform)
        case .idle:
            retryPlatformLinkResolution(for: slot.platform)
        case .loading, .unavailable:
            break
        }
    }

    private func retryPlatformLinkResolution(for platform: MusicPlatform) {
        guard platform != displayTrack.sourcePlatform else { return }
        displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        requestPlatformLink(for: platform, using: displayTrack)
    }

    private func requestPlatformLink(for platform: MusicPlatform, using track: Track) {
        displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        Task { @MainActor in
            let result = try? await resolver.resolvePlatformLink(for: track, targetPlatform: platform)
            guard let result else { return }
            let updatedTrack = displayTrack.updatingPlatformLink(
                result.platformLink,
                state: result.state,
                for: platform
            )
            displayTrack = updatedTrack
            persistenceStore.save(track: updatedTrack)
            onTrackUpdated?(updatedTrack)
        }
    }

    private func hydrateDisplayTrackFromPersistence() {
        guard let persistedTrack = persistenceStore.restore(track: displayTrack) else { return }
        displayTrack = persistedTrack
        onTrackUpdated?(persistedTrack)
    }
}

private struct PlatformSlot: Hashable {
    let platform: MusicPlatform
    let state: PlatformLinkLoadState
    let link: PlatformLink?

    var title: String {
        switch state {
        case .ready:
            return platform.displayName
        case .loading:
            return "\(platform.displayName) 匹配中"
        case .unavailable:
            return "\(platform.displayName) 暂未匹配"
        case .failed:
            return "\(platform.displayName) 重试"
        case .idle:
            return "\(platform.displayName) 待获取"
        }
    }

    var isEnabled: Bool {
        state == .ready || state == .failed || state == .idle
    }

    var isLoading: Bool {
        state == .loading
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
