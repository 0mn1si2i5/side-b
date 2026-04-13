import SwiftUI

struct RoomDetailView: View {
    let room: Room
    @StateObject private var viewModel: RoomDetailViewModel
    @State private var pendingIncomingMessageCount = 0
    @State private var isAtBottom = true

    init(room: Room) {
        self.room = room
        _viewModel = StateObject(
            wrappedValue: RoomDetailViewModel(initialMessages: MockData.messages)
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        MessageRowView(
                            message: message,
                            showsMetadata: shouldShowMetadata(for: index),
                            isGroupedWithNextMessage: isGroupedWithNextMessage(for: index),
                            onTrackUpdated: { track in
                                viewModel.updateTrack(track, forMessageID: message.id)
                            },
                            onQuoteTrack: { track in
                                viewModel.startQuoting(track: track)
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
            .navigationTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
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
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let latestMessage = viewModel.messages.last else { return }

                if latestMessage.senderName == "You" {
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
            .onAppear {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
                pendingIncomingMessageCount = 0
            }
        }
    }

    private var messageComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.linkResolutionState != .idle {
                linkResolutionFeedback
            }

            if let quotedTrack = viewModel.quotedTrack {
                HStack(spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to song")
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
                } label: {
                    Image(systemName: viewModel.isShowingLinkInput ? "message" : "link")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isShowingLinkInput ? .blue : .gray)

                Group {
                    if viewModel.isShowingLinkInput {
                        TextField("Paste a music link", text: $viewModel.linkInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isSending)
                            .submitLabel(.send)
                            .onSubmit {
                                submitComposer()
                            }
                    } else {
                        TextField("Send a message", text: $viewModel.draftText)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isSending)
                            .submitLabel(.send)
                            .onSubmit {
                                submitComposer()
                            }
                    }
                }

                Button(viewModel.isShowingLinkInput ? "Share" : "Send") {
                    submitComposer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                .overlay {
                    if viewModel.isSending {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)

                            Text(viewModel.isShowingLinkInput ? "Sharing" : "Sending")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
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
        return viewModel.messages[index - 1].senderName != viewModel.messages[index].senderName
    }

    private func isGroupedWithNextMessage(for index: Int) -> Bool {
        guard index < viewModel.messages.count - 1 else { return false }
        return viewModel.messages[index + 1].senderName == viewModel.messages[index].senderName
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
            return "Resolving song link..."
        case .resolved:
            return "Song resolved."
        case .fallbackMock:
            return "Resolver unavailable. Sent a fallback song card."
        case .failed:
            return "Could not resolve this song link."
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
            return Color.blue.opacity(0.12)
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
            return .blue
        case .resolved:
            return .green
        case .fallbackMock:
            return .orange
        case .failed:
            return .red
        }
    }
}
