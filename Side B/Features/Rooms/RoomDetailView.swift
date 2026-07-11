import SwiftUI

struct RoomDetailView: View {
    let room: Room
    private let onDissolved: () -> Void
    @State private var viewModel: RoomDetailViewModel
    @Environment(AuthState.self) private var authState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var pendingIncomingMessageCount = 0
    @State private var isAtBottom = true
    @State private var didScrollToInitialMessages = false
    @State private var shouldPreserveComposerFocusAfterSend = false
    @State private var linkFeedbackDismissTask: Task<Void, Never>?
    @FocusState private var isComposerFocused: Bool

    init(room: Room, onDissolved: @escaping () -> Void = {}) {
        self.room = room
        self.onDissolved = onDissolved
        _viewModel = State(initialValue: RoomDetailViewModel(room: room))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                roomAtmosphereBackground

                VStack(spacing: 0) {
                    topBar

                    ZStack {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            loadingView
                        } else if viewModel.messages.isEmpty {
                            emptyRoomView
                        } else {
                            messageList(proxy: proxy)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                connectionBanner
            }
            .safeAreaInset(edge: .bottom) {
                messageComposer
            }
            .overlay(alignment: .bottomTrailing) {
                if pendingIncomingMessageCount > 0 {
                    Button {
                        withAnimation {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                        pendingIncomingMessageCount = 0
                    } label: {
                        Text("新消息 \(pendingIncomingMessageCount) 条")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 82)
                }
            }
            .onAppear {
                didScrollToInitialMessages = false
                pendingIncomingMessageCount = 0
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .alert("操作失败", isPresented: Binding(
                get: { viewModel.actionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.actionErrorMessage = nil
                    }
                }
            )) {
                Button("确定", role: .cancel) {
                    viewModel.actionErrorMessage = nil
                }
            } message: {
                Text(viewModel.actionErrorMessage ?? "")
            }
            .onChange(of: viewModel.linkResolutionState) { _, state in
                scheduleLinkFeedbackDismissIfNeeded(for: state)
            }
            .onChange(of: viewModel.isSending) { _, isSending in
                if !isSending {
                    restoreComposerFocusAfterSendIfNeeded()
                }
            }
            .onChange(of: isComposerFocused) { _, isFocused in
                if !isFocused && viewModel.isSending {
                    shouldPreserveComposerFocusAfterSend = false
                }
            }
            .onChange(of: viewModel.hasLoadedInitialMessages) { _, hasLoaded in
                guard hasLoaded else { return }
                scrollToInitialBottomIfNeeded(proxy: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: .sideBRoomDissolved)) { notification in
                guard let dissolvedRoomID = notification.userInfo?[RoomNotificationKey.roomID] as? UUID,
                      dissolvedRoomID == viewModel.room.id else {
                    return
                }
                onDissolved()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .sideBGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer(minLength: 12)

            VStack(spacing: 3) {
                Text(viewModel.room.name)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle = roomSubtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            NavigationLink {
                RoomManagementView(
                    room: viewModel.room,
                    onRoomUpdated: { updatedRoom in
                        viewModel.applyRoomUpdate(updatedRoom)
                    }
                ) {
                    onDissolved()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .sideBGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("房间管理")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var roomSubtitle: String? {
        let memberCount = max(viewModel.room.memberUsernames.count, viewModel.room.memberIDs.count)
        let songCount = Set(viewModel.messages.compactMap { $0.track?.persistenceIdentity }).count
        if songCount > 0 && memberCount > 0 {
            return "\(songCount) 首歌 · \(memberCount) 位成员"
        }
        if memberCount > 0 {
            return "\(memberCount) 位成员"
        }
        return nil
    }

    private var roomAtmosphereBackground: some View {
        GeometryReader { proxy in
            ZStack {
                if let artworkURL = latestArtworkURL {
                    CachedArtworkImage(url: artworkURL, placeholderFontSize: 1)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.20)
                        .clipped()
                        .blur(radius: 52, opaque: true)
                        .saturation(0.46)
                        .opacity(colorScheme == .dark ? 0.50 : 0.58)
                } else {
                    LinearGradient(
                        colors: fallbackBackgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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

    private var latestArtworkURL: URL? {
        viewModel.messages.reversed().compactMap { $0.track?.artworkURL }.first
            ?? viewModel.room.latestTrack?.artworkURL
    }

    private var fallbackBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black,
                Color(white: 0.15),
                Color(white: 0.06)
            ]
        }
        return [
            Color(white: 0.94),
            Color(white: 0.88),
            Color(white: 0.97)
        ]
    }

    private var backgroundOverlayColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.64),
                Color.black.opacity(0.46),
                Color.black.opacity(0.70)
            ]
        }
        return [
            Color.white.opacity(0.42),
            Color.white.opacity(0.30),
            Color.white.opacity(0.56)
        ]
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("加载中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyRoomView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("还没有消息")
                .font(.headline)

            Text("发送文字或分享一首歌，开始这个房间。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch viewModel.connectionState {
        case .connecting:
            EmptyView()
        case .disconnected:
            if !viewModel.isLoading {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("连接断开")
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
        case .connected:
            EmptyView()
        }
    }

    private func messageList(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                    MessageRowView(
                        message: message,
                        showsMetadata: shouldShowMetadata(for: index),
                        isGroupedWithNextMessage: isGroupedWithNextMessage(for: index),
                        isCurrentUser: isMessageFromCurrentUser(message),
                        onTrackUpdated: { track in
                            viewModel.updateTrack(track, forMessageID: message.id)
                        },
                        onQuoteTrack: { track in
                            viewModel.startQuoting(track: track)
                        },
                        onReply: {
                            viewModel.replyToMessage(message)
                        },
                        onEmojiReaction: { emoji in
                            viewModel.addEmojiReaction(to: message.id, emoji: emoji)
                        },
                        onFindOriginalMessage: { id in
                            viewModel.messages.first(where: { $0.id == id })
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, shouldShowMetadata(for: index) ? 10 : 3)
                    .padding(.bottom, isGroupedWithNextMessage(for: index) ? 3 : 10)
                }

                Color.clear
                    .frame(height: 1)
                    .id("bottom-anchor")
                    .onAppear {
                        isAtBottom = true
                        pendingIncomingMessageCount = 0
                    }
                    .onDisappear {
                        isAtBottom = false
                    }
            }
            .padding(.top, 10)
        }
        .scrollContentBackground(.hidden)
        .onChange(of: viewModel.messages.count) { _, _ in
            guard let latestMessage = viewModel.messages.last else { return }

            if viewModel.hasLoadedInitialMessages && !didScrollToInitialMessages {
                scrollToInitialBottomIfNeeded(proxy: proxy)
                return
            }

            if isMessageFromCurrentUser(latestMessage) {
                withAnimation {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
                pendingIncomingMessageCount = 0
            } else if isAtBottom {
                withAnimation {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
                pendingIncomingMessageCount = 0
            } else {
                pendingIncomingMessageCount += 1
            }
        }
    }

    private func scrollToInitialBottomIfNeeded(proxy: ScrollViewProxy) {
        guard !didScrollToInitialMessages, !viewModel.messages.isEmpty else { return }
        didScrollToInitialMessages = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
            pendingIncomingMessageCount = 0
            isAtBottom = true
        }
    }

    private func isMessageFromCurrentUser(_ message: Message) -> Bool {
        guard let currentUser = authState.currentUser else {
            return message.senderName == "You"
        }
        if let senderID = message.senderID, senderID == currentUser.id {
            return true
        }
        return message.senderName == currentUser.username || message.senderName == "You"
    }

    private var messageComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.linkResolutionState != .idle {
                linkResolutionFeedback
            }

            if let replyPreview = viewModel.replyToMessagePreview {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("回复")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(replyPreview)
                            .font(.footnote)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        viewModel.cancelReply()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SideBVisualStyle.surfaceBorder, lineWidth: 1)
                }
            }

            if let quotedTrack = viewModel.quotedTrack {
                HStack(spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("回复歌曲")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(quotedTrack.title) - \(quotedTrack.artistName)")
                            .font(.footnote)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        viewModel.clearQuotedTrack()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SideBVisualStyle.surfaceBorder, lineWidth: 1)
                }
            }

            HStack(spacing: 12) {
                Button {
                    let shouldRestoreFocus = isComposerFocused
                    viewModel.toggleLinkInput()
                    if shouldRestoreFocus {
                        isComposerFocused = true
                    }
                } label: {
                    Image(systemName: viewModel.isShowingLinkInput ? "message" : "link")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .frame(width: 42, height: 42)
                .sideBGlassCircle()

                TextField(
                    viewModel.isShowingLinkInput ? "粘贴音乐链接" : "发送消息",
                    text: activeComposerTextBinding,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .textInputAutocapitalization(viewModel.isShowingLinkInput ? .never : .sentences)
                .autocorrectionDisabled(viewModel.isShowingLinkInput)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SideBVisualStyle.surfaceBorder, lineWidth: 1)
                }
                .focused($isComposerFocused)
                .frame(minHeight: 44)
                .submitLabel(.send)
                .onSubmit {
                    submitComposer()
                }

                Button(viewModel.isShowingLinkInput ? "分享" : "发送") {
                    submitComposer()
                }
                .buttonStyle(.plain)
                .fontWeight(.medium)
                .frame(minWidth: 58, minHeight: 42)
                .background(composerActionButtonColor.opacity(isComposerActionEnabled ? 1 : 0.12))
                .foregroundStyle(isComposerActionEnabled ? Color.white : Color.secondary)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(SideBVisualStyle.surfaceBorder, lineWidth: isComposerActionEnabled ? 0 : 1)
                }
                .disabled(!isComposerActionEnabled)
                .overlay {
                    if viewModel.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 18, y: 9)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var linkResolutionFeedback: some View {
        HStack(spacing: 10) {
            if viewModel.linkResolutionState == .resolving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: feedbackIconName)
                    .font(.caption)
            }

            Text(feedbackMessage)
                .font(.footnote)
                .foregroundStyle(feedbackForegroundColor)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(feedbackBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var activeComposerText: String {
        viewModel.isShowingLinkInput ? viewModel.linkInput : viewModel.draftText
    }

    private var isComposerActionEnabled: Bool {
        !activeComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    private var composerActionButtonColor: Color {
        isComposerActionEnabled ? .sideBLinkBlue : Color.secondary
    }

    private var activeComposerTextBinding: Binding<String> {
        Binding(
            get: { activeComposerText },
            set: { newValue in
                if viewModel.isShowingLinkInput {
                    viewModel.linkInput = newValue
                } else {
                    viewModel.draftText = newValue
                }
            }
        )
    }

    private func shouldShowMetadata(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index]
        let previous = viewModel.messages[index - 1]
        return current.senderName != previous.senderName || isMessageFromCurrentUser(current) != isMessageFromCurrentUser(previous)
    }

    private func isGroupedWithNextMessage(for index: Int) -> Bool {
        guard index < viewModel.messages.count - 1 else { return false }
        let current = viewModel.messages[index]
        let next = viewModel.messages[index + 1]
        return next.senderName == current.senderName && isMessageFromCurrentUser(current) == isMessageFromCurrentUser(next)
    }

    private func submitComposer() {
        let shouldKeepFocus = isComposerFocused
        shouldPreserveComposerFocusAfterSend = shouldKeepFocus
        if viewModel.isShowingLinkInput {
            viewModel.sendResolvedTrackMessage()
        } else {
            viewModel.sendTextMessage()
        }
        if shouldKeepFocus {
            isComposerFocused = true
        }
    }

    private func restoreComposerFocusAfterSendIfNeeded() {
        guard shouldPreserveComposerFocusAfterSend else { return }
        shouldPreserveComposerFocusAfterSend = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            isComposerFocused = true
        }
    }

    private func scheduleLinkFeedbackDismissIfNeeded(for state: LinkResolutionState) {
        linkFeedbackDismissTask?.cancel()
        guard state != .idle, state != .resolving else { return }

        linkFeedbackDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.clearLinkResolutionFeedback()
            }
        }
    }

    private var feedbackMessage: String {
        viewModel.linkResolutionMessage ?? defaultFeedbackMessage
    }

    private var defaultFeedbackMessage: String {
        switch viewModel.linkResolutionState {
        case .idle:
            return ""
        case .resolving:
            return "正在解析歌曲链接..."
        case .resolved:
            return "歌曲解析成功"
        case .fallbackMock:
            return "解析器不可用，已发送备用歌曲卡片"
        case .failed:
            return "无法解析该歌曲链接"
        }
    }

    private var feedbackIconName: String {
        switch viewModel.linkResolutionState {
        case .idle, .resolving:
            return "clock"
        case .resolved:
            return "checkmark.circle.fill"
        case .fallbackMock:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var feedbackBackgroundColor: Color {
        switch viewModel.linkResolutionState {
        case .idle:
            return .clear
        case .resolving:
            return Color.secondary.opacity(0.12)
        case .resolved:
            return Color.green.opacity(0.12)
        case .fallbackMock:
            return Color.orange.opacity(0.14)
        case .failed:
            return Color.red.opacity(0.12)
        }
    }

    private var feedbackForegroundColor: Color {
        switch viewModel.linkResolutionState {
        case .idle:
            return .secondary
        case .resolving:
            return .secondary
        case .resolved:
            return .green
        case .fallbackMock:
            return .orange
        case .failed:
            return .red
        }
    }
}
