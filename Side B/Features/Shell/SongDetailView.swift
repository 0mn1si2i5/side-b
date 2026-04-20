import SwiftUI

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
