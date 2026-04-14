import SwiftUI

struct MessageRowView: View {
    let message: Message
    let showsMetadata: Bool
    let isGroupedWithNextMessage: Bool
    let isCurrentUser: Bool
    let onTrackUpdated: (Track) -> Void
    let onQuoteTrack: (Track) -> Void
    let onReply: () -> Void
    let onEmojiReaction: (String) -> Void
    let onFindOriginalMessage: (UUID) -> Message?

    @State private var showingAddToPlaylistSheet = false
    @State private var selectedTrack: Track? = nil
    @State private var showAddSuccessToast = false
    @State private var addSuccessMessage = ""

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

                if message.replyToMessageID != nil || message.text != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let replyID = message.replyToMessageID,
                           let originalMessage = onFindOriginalMessage(replyID) {
                            replyQuoteBlock(originalMessage: originalMessage)
                        } else if message.replyToMessageID != nil {
                            replyQuotePlaceholder
                        }

                        if let text = message.text {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(isCurrentUser ? .white : .primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if let track = message.track {
                    NavigationLink {
                        SongDetailView(
                            track: track,
                            onTrackUpdated: onTrackUpdated
                        )
                    } label: {
                        CompactSongAttachmentView(
                            track: track,
                            isCurrentUser: isCurrentUser,
                            onAddToPlaylist: {
                                selectedTrack = track
                                showingAddToPlaylistSheet = true
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !message.emojiReactions.isEmpty {
                    EmojiReactionsView(
                        reactions: message.emojiReactions,
                        isCurrentUser: isCurrentUser
                    )
                    .padding(.top, 2)
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 44)
            }
        }
        .sheet(isPresented: $showingAddToPlaylistSheet) {
            if let track = selectedTrack {
                AddToPlaylistView(track: track, isPresented: $showingAddToPlaylistSheet) { playlist in
                    addSuccessMessage = "已添加到「\(playlist.name)」"
                    showAddSuccessToast = true
                }
            }
        }
        .toast(isPresented: $showAddSuccessToast, message: addSuccessMessage)
        .contextMenu {
            Button {
                onReply()
            } label: {
                Label("引用回复", systemImage: "arrow.turn.up.left")
            }

            Divider()

            Button {
                onEmojiReaction("👍")
            } label: {
                Text("👍")
            }

            Button {
                onEmojiReaction("❤️")
            } label: {
                Text("❤️")
            }

            Button {
                onEmojiReaction("🎵")
            } label: {
                Text("🎵")
            }

            Button {
                onEmojiReaction("🔥")
            } label: {
                Text("🔥")
            }
        }
    }
private func replyQuoteBlock(originalMessage: Message) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(isCurrentUser ? 0.7 : 1))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(originalMessage.senderName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isCurrentUser ? .white.opacity(0.8) : .secondary)

                if let text = originalMessage.text {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(2)
                } else if let track = originalMessage.track {
                    Text("🎵 \(track.title)")
                        .font(.caption2)
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isCurrentUser ? Color.white.opacity(0.15) : Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var replyQuotePlaceholder: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(isCurrentUser ? 0.7 : 1))
                .frame(width: 3)

            Text("引用的消息")
                .font(.caption2)
                .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isCurrentUser ? Color.white.opacity(0.15) : Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmojiReactionsView: View {
    let reactions: [EmojiReaction]
    let isCurrentUser: Bool

    private var groupedReactions: [(emoji: String, count: Int)] {
        let counts = Dictionary(grouping: reactions, by: { $0.emoji })
            .mapValues { $0.count }
        return counts.map { (emoji: $0.key, count: $0.value) }.sorted { $0.emoji < $1.emoji }
    }

    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(groupedReactions, id: \.emoji) { group in
                    HStack(spacing: 2) {
                        Text(group.emoji)
                            .font(.caption2)
                        Text("\(group.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isCurrentUser
                                  ? Color.white.opacity(0.2)
                                  : Color(.tertiarySystemBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isCurrentUser
                                    ? Color.white.opacity(0.15)
                                    : Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                }
            }
        }
    }
}

struct CompactSongAttachmentView: View {
    let track: Track
    let isCurrentUser: Bool
    var onAddToPlaylist: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            artworkThumbnail

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

            if let onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
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

    private var artworkThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrentUser ? Color.white.opacity(0.18) : Color.secondary.opacity(0.12))

            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderArtwork: some View {
        Image(systemName: "music.note")
            .font(.footnote)
            .foregroundStyle(isCurrentUser ? .white.opacity(0.85) : .secondary)
    }
}
