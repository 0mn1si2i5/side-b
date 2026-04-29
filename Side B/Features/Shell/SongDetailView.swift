import SwiftUI

struct SongDetailView: View {
    @State private var viewModel: SongDetailViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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
        ZStack {
            atmosphereBackground

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    backButton
                    Spacer(minLength: 0)
                }
                .padding(.top, 26)

                HStack {
                    Spacer(minLength: 0)

                    artworkSection
                        .containerRelativeFrame(.horizontal) { width, _ in
                            width - 36
                        }
                        .aspectRatio(1, contentMode: .fit)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                trackInfoSection

                platformGlassCard
                    .padding(.top, 26)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 64)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .contentShape(Rectangle())
        .simultaneousGesture(edgeSwipeDismissGesture)
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
        .sheet(isPresented: $viewModel.showingSendToRoomSheet) {
            SendTrackToRoomView(track: viewModel.displayTrack, isPresented: $viewModel.showingSendToRoomSheet) { room in
                viewModel.addSuccessMessage = "已发送到「\(room.name)」"
                viewModel.showAddSuccessToast = true
            }
        }
        .toast(isPresented: $viewModel.showAddSuccessToast, message: viewModel.addSuccessMessage)
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .offset(y: 18)
        .accessibilityLabel("返回")
    }

    private var atmosphereBackground: some View {
        GeometryReader { proxy in
            ZStack {
                if let artworkURL = viewModel.displayTrack.artworkURL {
                    CachedArtworkImage(url: artworkURL, placeholderFontSize: 1)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.18)
                        .clipped()
                        .blur(radius: 50, opaque: true)
                        .saturation(0.48)
                        .opacity(colorScheme == .dark ? 0.52 : 0.60)
                }

                LinearGradient(
                    colors: backgroundOverlayColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOverlayColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.62),
                Color.black.opacity(0.46),
                Color.black.opacity(0.70)
            ]
        }
        return [
            Color.white.opacity(0.42),
            Color.white.opacity(0.30),
            Color.white.opacity(0.58)
        ]
    }

    private var platformGlassCard: some View {
        ZStack(alignment: .trailing) {
            platformLinksContent

            if viewModel.shouldShowMissingPlatformLinksRetry {
                retryMissingPlatformLinksButton
                    .offset(x: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, viewModel.shouldShowMissingPlatformLinksRetry ? 30 : 10)
        .animation(.easeInOut(duration: 0.18), value: viewModel.shouldShowMissingPlatformLinksRetry)
    }

    private var platformLinksContent: some View {
        HStack(spacing: 0) {
            let slots = viewModel.platformSlots
            ForEach(slots.indices, id: \.self) { index in
                let slot = slots[index]

                PlatformJumpButton(
                    platform: slot.platform,
                    isEnabled: slot.isEnabled,
                    isLoading: slot.isLoading,
                    showsTitle: false
                ) {
                    handlePlatformSlotTap(slot)
                }

                if index < slots.index(before: slots.endIndex) {
                    Rectangle()
                        .fill(SideBVisualStyle.glassDivider)
                        .frame(width: 1, height: 52)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 92)
        .sideBProminentGlassSurface(cornerRadius: 32)
    }

    private var retryMissingPlatformLinksButton: some View {
        Button {
            viewModel.retryMissingPlatformLinks()
        } label: {
            ZStack {
                if viewModel.isRetryingMissingPlatformLinks {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 42, height: 42)
            .sideBGlassCircle()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRetryingMissingPlatformLinks)
        .accessibilityLabel("重新获取缺失平台链接")
    }

    private func glassCircleButton(systemName: String, size: CGFloat = 46, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.39, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .sideBGlassCircle()
        }
        .buttonStyle(.plain)
    }

    private var floatingActionButtons: some View {
        HStack(spacing: 13) {
            glassCircleButton(systemName: "plus", size: 46) {
                viewModel.showingAddToPlaylistSheet = true
            }
            .accessibilityLabel("添加到歌单")

            glassCircleButton(systemName: "paperplane.fill", size: 46) {
                viewModel.showingSendToRoomSheet = true
            }
            .accessibilityLabel("发送到聊天室")
        }
    }

    private var trackInfoSection: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.displayTrack.title)
                    .font(.system(size: 23, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.displayTrack.artistName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 9)

                if let albumTitle = viewModel.displayTrack.albumTitle {
                    Text(albumTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 5)
                }
            }
            .padding(.top, 12)

            Spacer(minLength: 8)

            floatingActionButtons
                .padding(.top, 1)
        }
    }

    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.thinMaterial)

            if let artworkURL = viewModel.displayTrack.artworkURL {
                CachedArtworkImage(url: artworkURL, placeholderFontSize: 48)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10), radius: 16, y: 10)
    }

    private var edgeSwipeDismissGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                let startedNearLeadingEdge = value.startLocation.x < 44
                let isHorizontalSwipe = value.translation.width > 90 && abs(value.translation.height) < 70
                if startedNearLeadingEdge && isHorizontalSwipe {
                    dismiss()
                }
            }
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
