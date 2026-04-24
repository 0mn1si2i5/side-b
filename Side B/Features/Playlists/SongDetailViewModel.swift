import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "SongDetailViewModel")

struct PlatformSlot: Hashable {
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

@MainActor
@Observable
final class SongDetailViewModel {
    var displayTrack: Track
    var platformFeedbackMessage = ""
    var isShowingPlatformFeedback = false
    var showingAddToPlaylistSheet = false
    var showAddSuccessToast = false
    var addSuccessMessage = ""

    private let resolver: any MusicResolverService
    private let persistenceStore: PlatformLinkPersistenceStore
    private let onTrackUpdated: ((Track) -> Void)?
    private let navigationService: PlatformNavigationService

    init(
        track: Track,
        resolver: any MusicResolverService = ResolverServiceFactory.makeDefaultService()!,
        persistenceStore: PlatformLinkPersistenceStore = .shared,
        onTrackUpdated: ((Track) -> Void)? = nil,
        navigationService: PlatformNavigationService = DefaultPlatformNavigationService()
    ) {
        self.displayTrack = track
        self.resolver = resolver
        self.persistenceStore = persistenceStore
        self.onTrackUpdated = onTrackUpdated
        self.navigationService = navigationService
    }

    // MARK: - Computed Properties

    var platformSlots: [PlatformSlot] {
        MusicPlatform.allCases.map { platform in
            let state = displayTrack.platformLinkState(for: platform)
            let link = displayTrack.platformLink(for: platform)
            return PlatformSlot(platform: platform, state: state, link: link)
        }
    }

    var platformSlotRows: [[PlatformSlot]] {
        stride(from: 0, to: platformSlots.count, by: 2).map { index in
            Array(platformSlots[index..<min(index + 2, platformSlots.count)])
        }
    }

    // MARK: - Platform Link Resolution

    func resolvePendingPlatformLinksIfNeeded() {
        let pendingPlatforms = MusicPlatform.allCases.filter { platform in
            platform != displayTrack.sourcePlatform && shouldResolvePlatformLink(for: platform)
        }

        guard !pendingPlatforms.isEmpty else { return }

        let track = displayTrack
        for platform in pendingPlatforms {
            displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        }

        Task { [weak self] in
            guard let self else { return }
            let resolver = self.resolver
            await withTaskGroup(of: (MusicPlatform, SinglePlatformLinkResolutionResponse?).self) { group in
                for platform in pendingPlatforms {
                    group.addTask {
                        do {
                            let result = try await resolver.resolvePlatformLink(for: track, targetPlatform: platform)
                            return (platform, result)
                        } catch {
                            logger.error("resolvePlatformLink failed: \(error)")
                            return (platform, nil)
                        }
                    }
                }

                for await (platform, result) in group {
                    guard let result else { continue }
                    let updatedTrack = self.displayTrack.updatingPlatformLink(
                        result.platformLink,
                        state: result.state,
                        for: platform
                    )
                    self.displayTrack = updatedTrack
                    self.persistenceStore.save(track: updatedTrack)
                    self.onTrackUpdated?(updatedTrack)
                }
            }
        }
    }

    func shouldResolvePlatformLink(for platform: MusicPlatform) -> Bool {
        let state = displayTrack.platformLinkState(for: platform)
        return state == .idle || state == .failed
    }

    func requestPlatformLink(for platform: MusicPlatform, using track: Track) {
        displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        Task { [weak self] in
            guard let self else { return }
            let result: SinglePlatformLinkResolutionResponse
            do {
                result = try await resolver.resolvePlatformLink(for: track, targetPlatform: platform)
            } catch {
                logger.error("resolvePlatformLink failed: \(error)")
                displayTrack = displayTrack.updatingPlatformLinkState(.failed, for: platform)
                return
            }
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

    func hydrateDisplayTrackFromPersistence() {
        guard let persistedTrack = persistenceStore.restore(track: displayTrack) else { return }
        displayTrack = persistedTrack
        onTrackUpdated?(persistedTrack)
    }

    // MARK: - Platform Slot Interaction

    func handlePlatformSlotTap(_ slot: PlatformSlot) -> PlatformSlotTapAction {
        switch slot.state {
        case .ready:
            guard let link = slot.link else { return .none }

            if navigationService.destinationURL(for: link.platform, track: displayTrack) != nil || link.isSource {
                return .openURL(link.destinationURL)
            } else {
                return .showFeedback("\(link.platformName) 暂不支持跳转")
            }
        case .failed, .idle:
            return .retry(slot.platform)
        case .loading, .unavailable:
            return .none
        }
    }

    func retryPlatformLinkResolution(for platform: MusicPlatform) {
        guard platform != displayTrack.sourcePlatform else { return }
        displayTrack = displayTrack.updatingPlatformLinkState(.loading, for: platform)
        requestPlatformLink(for: platform, using: displayTrack)
    }
}

// MARK: - Tap Action Enum

enum PlatformSlotTapAction {
    case none
    case openURL(URL)
    case showFeedback(String)
    case retry(MusicPlatform)
}