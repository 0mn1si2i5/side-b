import SwiftUI

struct HomeTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Side B")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A cross-platform music sharing inbox for friends.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("Home")
    }
}

struct RoomsListView: View {
    let rooms = MockData.rooms

    var body: some View {
        List(rooms) { room in
            NavigationLink {
                RoomDetailView(room: room)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name)
                        .font(.headline)

                    if let latestTrack = room.latestTrack {
                        Text("\(latestTrack.title) · \(latestTrack.artistName)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    if let latestMessagePreview = room.latestMessagePreview {
                        Text(latestMessagePreview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle("Rooms")
    }
}

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
                } else {
                    if isAtBottom {
                        withAnimation {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                        pendingIncomingMessageCount = 0
                    } else {
                        pendingIncomingMessageCount += 1
                    }
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
}

struct SongDetailView: View {
    private let platformDisplayOrder = ["Apple Music", "Spotify", "QQ 音乐", "网易云音乐"]
    let track: Track
    @State private var platformFeedbackMessage = ""
    @State private var isShowingPlatformFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(track.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let albumTitle = track.albumTitle {
                        Text("Album: \(albumTitle)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Text("Source: \(track.sourcePlatformName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Lyrics")
                        .font(.headline)

                    Text("Mock lyrics preview")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("City lights blur into morning\nWe keep the chorus for the ride home\nThis section stays static until real lyrics arrive")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Open In")
                        .font(.headline)

                    ForEach(platformButtonRows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { platformName in
                                PlatformJumpButton(title: platformName) {
                                    showPlatformFeedback(for: platformName)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Coming Soon", isPresented: $isShowingPlatformFeedback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(platformFeedbackMessage)
        }
    }

    private func showPlatformFeedback(for platformName: String) {
        platformFeedbackMessage = "Jumping to \(platformName) is not available yet in this mock build."
        isShowingPlatformFeedback = true
    }

    private var platformButtonRows: [[String]] {
        stride(from: 0, to: platformDisplayOrder.count, by: 2).map { index in
            Array(platformDisplayOrder[index..<min(index + 2, platformDisplayOrder.count)])
        }
    }
}

struct PlatformJumpButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
}

struct SongCardView: View {
    let track: Track

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let albumTitle = track.albumTitle {
                    Text(albumTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(track.sourcePlatformName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MessageRowView: View {
    let message: Message
    let showsMetadata: Bool
    let isGroupedWithNextMessage: Bool
    let onQuoteTrack: (Track) -> Void

    private var isCurrentUser: Bool {
        message.senderName == "You"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isCurrentUser {
                Spacer(minLength: 44)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                if showsMetadata {
                    HStack(spacing: 8) {
                        if !isCurrentUser {
                            Text(message.senderName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if isCurrentUser {
                            Text(message.senderName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }

                if let text = message.text {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if let track = message.track {
                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink {
                            SongDetailView(track: track)
                        } label: {
                            CompactSongAttachmentView(track: track, isCurrentUser: isCurrentUser)
                        }
                        .buttonStyle(.plain)

                        if !isGroupedWithNextMessage {
                            HStack {
                                Button {
                                    onQuoteTrack(track)
                                } label: {
                                    Label("Quote song", systemImage: "quote.bubble")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, -2)
                        }
                    }
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 44)
            }
        }
    }
}

struct CompactSongAttachmentView: View {
    let track: Track
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill((isCurrentUser ? Color.white.opacity(0.18) : Color.secondary.opacity(0.12)))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.footnote)
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.85) : .secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(isCurrentUser ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)

                Text(track.sourcePlatformName)
                    .font(.caption2)
                    .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(isCurrentUser ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.88))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentUser ? Color.accentColor.opacity(0.32) : Color.black.opacity(0.12),
                    lineWidth: 1.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(isCurrentUser ? 0.04 : 0.03), radius: 4, y: 1)
    }
}

struct ProfileTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))

            Text("Your Profile")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Shared songs, saved tracks, and listening activity will appear here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("Profile")
    }
}
