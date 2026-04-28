import SwiftUI

struct RoomDetailView: View {
    let room: Room
    @State private var viewModel: RoomDetailViewModel
    @Environment(AuthState.self) private var authState
    @State private var pendingIncomingMessageCount = 0
    @State private var isAtBottom = true
    @FocusState private var focusedComposerField: ComposerField?

    private enum ComposerField {
        case message
        case link
    }

    init(room: Room) {
        self.room = room
        _viewModel = State(initialValue: RoomDetailViewModel(roomId: room.id))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                    errorView(message: errorMessage)
                } else {
                    messageList(proxy: proxy)
                }
            }
            .navigationTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RoomManagementView(room: room)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("房间管理")
                }
            }
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
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
                pendingIncomingMessageCount = 0
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .alert("操作失败", isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.messages.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
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

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                viewModel.errorMessage = nil
                viewModel.onAppear()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch viewModel.connectionState {
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("连接中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
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
                .background(Color(.systemBackground))
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
            .padding(.top, 8)
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            guard let latestMessage = viewModel.messages.last else { return }

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
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.toggleLinkInput()
                    let nextField: ComposerField = viewModel.isShowingLinkInput ? .link : .message
                    DispatchQueue.main.async {
                        focusedComposerField = nextField
                    }
                } label: {
                    Image(systemName: viewModel.isShowingLinkInput ? "message" : "link")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isShowingLinkInput ? .primary : .gray)

                Group {
                    if viewModel.isShowingLinkInput {
                        TextField("粘贴音乐链接", text: $viewModel.linkInput, axis: .vertical)
                            .lineLimit(1...5)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedComposerField, equals: .link)
                            .frame(minHeight: 44)
                            .disabled(viewModel.isSending)
                            .submitLabel(.send)
                            .onSubmit {
                                submitComposer()
                            }
                    } else {
                        TextField("发送消息", text: $viewModel.draftText, axis: .vertical)
                            .lineLimit(1...5)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedComposerField, equals: .message)
                            .frame(minHeight: 44)
                            .disabled(viewModel.isSending)
                            .submitLabel(.send)
                            .onSubmit {
                                submitComposer()
                            }
                    }
                }

                Button(viewModel.isShowingLinkInput ? "分享" : "发送") {
                    submitComposer()
                }
                .buttonStyle(.bordered)
                .disabled(activeComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                .overlay {
                    if viewModel.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.regularMaterial)
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

            if viewModel.linkResolutionState != .resolving {
                Button {
                    viewModel.clearLinkResolutionFeedback()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(feedbackForegroundColor.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(feedbackBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var activeComposerText: String {
        viewModel.isShowingLinkInput ? viewModel.linkInput : viewModel.draftText
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
        if viewModel.isShowingLinkInput {
            viewModel.sendResolvedTrackMessage()
        } else {
            viewModel.sendTextMessage()
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
