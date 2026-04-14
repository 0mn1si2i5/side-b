import Combine
import Foundation

enum LinkResolutionState: Equatable {
    case idle
    case resolving
    case resolved
    case fallbackMock
    case failed
}

final class RoomDetailViewModel: ObservableObject {
    @Published var messages: [Message]
    @Published var draftText = ""
    @Published var linkInput = ""
    @Published var quotedTrack: Track?
    @Published var isShowingLinkInput = false
    @Published var isSending = false
    @Published private(set) var linkResolutionState: LinkResolutionState = .idle
    @Published private(set) var linkResolutionMessage: String?

    private let resolver: MusicResolverService
    private let persistenceStore: PlatformLinkPersistenceStore

    init(
        initialMessages: [Message],
        persistenceStore: PlatformLinkPersistenceStore = .shared,
        resolver: MusicResolverService = ResolverServiceFactory.makeDefaultService()
    ) {
        self.persistenceStore = persistenceStore
        self.messages = initialMessages
            .sorted { $0.sentAt < $1.sentAt }
            .map { message in
                guard let track = message.track, let restoredTrack = persistenceStore.restore(track: track) else {
                    return message
                }
                return message.updatingTrack(restoredTrack)
            }
        self.resolver = resolver
    }

    func sendResolvedTrackMessage(senderName: String = "You") {
        let normalizedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLink.isEmpty else { return }

        isSending = true
        linkResolutionState = .resolving
        linkResolutionMessage = "正在解析歌曲链接..."

        Task { @MainActor in
            do {
                let response = try await resolver.resolveMetadata(request: ResolverRequest(rawLink: normalizedLink))
                finishResolvedTrackMessage(response: response, senderName: senderName)
            } catch {
                linkResolutionState = .failed
                linkResolutionMessage = "解析失败：\(error.localizedDescription)"
                isSending = false
            }
        }
    }

    func sendTextMessage(senderName: String = "You") {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        beginSendingState()

        let newMessage = Message(
            senderName: senderName,
            text: trimmedDraft,
            track: quotedTrack,
            sentAt: Date()
        )

        messages.append(newMessage)
        draftText = ""
        quotedTrack = nil
    }

    func startQuoting(track: Track) {
        quotedTrack = track
        isShowingLinkInput = false
    }

    func clearQuotedTrack() {
        quotedTrack = nil
    }

    func updateTrack(_ track: Track, forMessageID messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index] = messages[index].updatingTrack(track)
        persistenceStore.save(track: track)
    }

    func clearLinkResolutionFeedback() {
        linkResolutionState = .idle
        linkResolutionMessage = nil
    }

    func toggleLinkInput() {
        isShowingLinkInput.toggle()
        if isShowingLinkInput {
            quotedTrack = nil
        } else {
            linkInput = ""
            clearLinkResolutionFeedback()
        }
    }

    private func beginSendingState() {
        isSending = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isSending = false
        }
    }

    private func finishResolvedTrackMessage(response: ResolverResponse, senderName: String) {
        defer { isSending = false }

        switch response.parsingResult {
        case .unsupportedLink:
            linkResolutionState = .failed
            linkResolutionMessage = "暂不支持该链接，请粘贴 Spotify、Apple Music、网易云音乐或 QQ 音乐的歌曲链接"
            return
        case .missingResourceID:
            linkResolutionState = .failed
            linkResolutionMessage = "无法从链接中提取歌曲 ID"
            return
        case .parsed:
            break
        }

        if response.metadataStatus == .fallbackMock {
            linkResolutionState = .failed
            if let diagnosticMessage = response.diagnosticMessage, !diagnosticMessage.isEmpty {
                linkResolutionMessage = "无法解析该歌曲。\(diagnosticMessage)"
            } else {
                linkResolutionMessage = "无法解析该歌曲"
            }
            return
        }

        let resolvedTrack = persistenceStore.restore(track: response.resolvedTrack.track) ?? response.resolvedTrack.track
        let newMessage = Message(
            senderName: senderName,
            text: nil as String?,
            track: resolvedTrack,
            sentAt: Date()
        )

        messages.append(newMessage)
        persistenceStore.save(track: resolvedTrack)
        TrackCache.shared.save(track: resolvedTrack)
        if let identity = resolvedTrack.persistenceIdentity {
            RecentlyResolvedStore.shared.add(identity)
        }
        linkInput = ""
        isShowingLinkInput = false
        quotedTrack = nil

        switch response.resolutionSource {
        case .remote:
            linkResolutionState = .resolved
            linkResolutionMessage = nil
        case .fallbackMock:
            linkResolutionState = .failed
            linkResolutionMessage = "无法解析或匹配该歌曲"
        case .mockLocal:
            linkResolutionState = .resolved
            linkResolutionMessage = nil
        }
    }
}
