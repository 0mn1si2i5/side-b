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

    init(
        initialMessages: [Message],
        resolver: MusicResolverService = ResolverServiceFactory.makeDefaultService()
    ) {
        self.messages = initialMessages.sorted { $0.sentAt < $1.sentAt }
        self.resolver = resolver
    }

    func sendResolvedTrackMessage(senderName: String = "You") {
        let normalizedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLink.isEmpty else { return }

        isSending = true
        linkResolutionState = .resolving
        linkResolutionMessage = "Resolving song link..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let response = self.resolver.resolveMetadata(request: ResolverRequest(rawLink: normalizedLink))

            DispatchQueue.main.async {
                self.finishResolvedTrackMessage(response: response, senderName: senderName)
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
            linkResolutionMessage = "This link is not supported yet. Paste a Spotify, Apple Music, or 网易云音乐 track link."
            return
        case .missingResourceID:
            linkResolutionState = .failed
            linkResolutionMessage = "Could not extract a track ID from this link."
            return
        case .parsed:
            break
        }

        if response.metadataStatus == .fallbackMock {
            linkResolutionState = .failed
            if let diagnosticMessage = response.diagnosticMessage, !diagnosticMessage.isEmpty {
                linkResolutionMessage = "Could not resolve this song. \(diagnosticMessage)"
            } else {
                linkResolutionMessage = "Could not resolve this song."
            }
            return
        }

        let newMessage = Message(
            senderName: senderName,
            text: "Shared a song link",
            track: response.resolvedTrack.track,
            sentAt: Date()
        )

        messages.append(newMessage)
        linkInput = ""
        isShowingLinkInput = false
        quotedTrack = nil

        switch response.resolutionSource {
        case .remote:
            linkResolutionState = .resolved
            linkResolutionMessage = nil
        case .fallbackMock:
            linkResolutionState = .failed
            linkResolutionMessage = "Could not resolve or match this song."
        case .mockLocal:
            linkResolutionState = .resolved
            linkResolutionMessage = nil
        }
    }
}
