import Combine
import Foundation

final class RoomDetailViewModel: ObservableObject {
    @Published var messages: [Message]
    @Published var draftText = ""
    @Published var linkInput = ""
    @Published var quotedTrack: Track?
    @Published var isShowingLinkInput = false
    @Published var isSending = false

    private let resolver: MusicResolverService

    init(
        initialMessages: [Message],
        resolver: MusicResolverService = MockMusicResolverService()
    ) {
        self.messages = initialMessages.sorted { $0.sentAt < $1.sentAt }
        self.resolver = resolver
    }

    func sendResolvedTrackMessage(senderName: String = "You") {
        let normalizedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLink.isEmpty else { return }

        beginSendingState()

        let resolvedTrack = resolver.resolveTrack(from: normalizedLink)
        let newMessage = Message(
            senderName: senderName,
            text: "Shared a song link",
            track: resolvedTrack,
            sentAt: Date()
        )

        messages.append(newMessage)
        linkInput = ""
        isShowingLinkInput = false
        quotedTrack = nil
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

    func toggleLinkInput() {
        isShowingLinkInput.toggle()
        if isShowingLinkInput {
            quotedTrack = nil
        } else {
            linkInput = ""
        }
    }

    private func beginSendingState() {
        isSending = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isSending = false
        }
    }
}
