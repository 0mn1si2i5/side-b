import SwiftUI

struct SongDetailView: View {
    @State private var viewModel: SongDetailViewModel
    @Environment(\.openURL) private var openURL

    init(
        track: Track,
        resolver: any MusicResolverService = ResolverServiceFactory.makeDefaultService()!,
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
            VStack(alignment: .leading, spacing: 16) {
                artworkSection
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)

                trackInfoSection

                VStack(alignment: .leading, spacing: 8) {
                    Text("打开方式")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(viewModel.platformSlots, id: \.platform) { slot in
                            PlatformJumpButton(
                                platform: slot.platform,
                                isEnabled: slot.isEnabled,
                                isLoading: slot.isLoading
                            ) {
                                handlePlatformSlotTap(slot)
                            }
                        }
                    }
                }
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

    private var trackInfoSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Text(viewModel.displayTrack.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    viewModel.showingAddToPlaylistSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加到歌单")
            }

            Text(viewModel.displayTrack.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let albumTitle = viewModel.displayTrack.albumTitle {
                Text(albumTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
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
