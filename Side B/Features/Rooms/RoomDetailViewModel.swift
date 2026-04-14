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
    @Published var messages: [Message] = []
    @Published var draftText = ""
    @Published var linkInput = ""
    @Published var quotedTrack: Track?
    @Published var isShowingLinkInput = false
    @Published var isSending = false
    @Published var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var linkResolutionState: LinkResolutionState = .idle
    @Published private(set) var linkResolutionMessage: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var replyToMessageID: UUID?
    @Published var replyToMessagePreview: String?

    private let roomId: UUID
    private let resolver: MusicResolverService
    private let persistenceStore: PlatformLinkPersistenceStore
    private let messageService: MessageServiceProtocol
    private var webSocketService: WebSocketServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        roomId: UUID,
        initialMessages: [Message] = [],
        persistenceStore: PlatformLinkPersistenceStore = .shared,
        resolver: MusicResolverService = ResolverServiceFactory.makeDefaultService(),
        messageService: MessageServiceProtocol = MessageServiceFactory.makeDefaultService(),
        webSocketService: WebSocketServiceProtocol = WebSocketServiceFactory.makeDefaultService()
    ) {
        self.roomId = roomId
        self.persistenceStore = persistenceStore
        self.resolver = resolver
        self.messageService = messageService
        self.webSocketService = webSocketService

        self.messages = initialMessages
            .sorted { $0.sentAt < $1.sentAt }
            .map { message in
                guard let track = message.track, let restoredTrack = persistenceStore.restore(track: track) else {
                    return message
                }
                return message.updatingTrack(restoredTrack)
            }

        setupWebSocketCallbacks()
        observeConnectionState()
    }

    func onAppear() {
        Task { @MainActor in
            await loadInitialMessages()
            await webSocketService.connect(toRoom: roomId)
        }
    }

    func onDisappear() {
        webSocketService.disconnect()
    }

    private func loadInitialMessages() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await messageService.fetchMessages(roomId: roomId)
            messages = fetched
                .sorted { $0.sentAt < $1.sentAt }
                .map { message in
                    guard let track = message.track, let restoredTrack = persistenceStore.restore(track: track) else {
                        return message
                    }
                    return message.updatingTrack(restoredTrack)
                }
        } catch {
            errorMessage = "加载消息失败，请稍后重试"
        }
        isLoading = false
    }

    private func setupWebSocketCallbacks() {
        webSocketService.onMessageReceived = { [weak self] message in
            DispatchQueue.main.async {
                self?.handleIncomingMessage(message)
            }
        }

        webSocketService.onEmojiReactionReceived = { [weak self] reaction in
            DispatchQueue.main.async {
                self?.handleIncomingEmojiReaction(reaction)
            }
        }

        webSocketService.onRoomUpdated = { _ in
        }
    }

    private func observeConnectionState() {
        if let remoteService = webSocketService as? RemoteWebSocketService {
            remoteService.$connectionState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.connectionState = state
                }
                .store(in: &cancellables)
        }
    }

    private func handleIncomingMessage(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }

        errorMessage = nil

        var messageToInsert = message
        if let track = message.track, let restoredTrack = persistenceStore.restore(track: track) {
            messageToInsert = message.updatingTrack(restoredTrack)
        }

        messages.append(messageToInsert)
        messages.sort { $0.sentAt < $1.sentAt }
    }

    private func handleIncomingEmojiReaction(_ reaction: EmojiReaction) {
        guard let _ = messages.firstIndex(where: { $0.id == reaction.messageId }) else { return }
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

        if connectionState == .connected {
            Task {
                try? await webSocketService.send(text: trimmedDraft)
            }
        }
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

    func replyToMessage(_ message: Message) {
        replyToMessageID = message.id
        let preview: String
        if let text = message.text, !text.isEmpty {
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            preview = "\(message.senderName): \(firstLine)"
        } else if let track = message.track {
            preview = "\(message.senderName): 🎵 \(track.title)"
        } else {
            preview = message.senderName
        }
        replyToMessagePreview = preview
    }

    func cancelReply() {
        replyToMessageID = nil
        replyToMessagePreview = nil
    }

    func addEmojiReaction(to messageId: UUID, emoji: String) {
        Task { @MainActor in
            do {
                let reaction = try await messageService.addEmojiReaction(roomId: roomId, messageId: messageId, emoji: emoji)
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].emojiReactions.append(reaction)
                }
            } catch {
                // Silently ignore emoji reaction failures
            }
        }
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