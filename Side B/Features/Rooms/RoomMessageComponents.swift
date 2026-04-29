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
                                .foregroundStyle(.primary.opacity(0.72))
                        }

                        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.82))

                        if isCurrentUser {
                            Text(message.senderName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary.opacity(0.72))
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
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isCurrentUser ? Color.primary.opacity(0.035) : Color.white.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.045), radius: 8, y: 3)
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
                            isCurrentUser: isCurrentUser
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
                .fill(Color.secondary.opacity(0.65))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(originalMessage.senderName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if let text = originalMessage.text {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if let track = originalMessage.track {
                    Text("🎵 \(track.title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var replyQuotePlaceholder: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.secondary.opacity(0.65))
                .frame(width: 3)

            Text("引用的消息")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
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
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
        }
    }
}

struct CompactSongAttachmentView: View {
    let track: Track
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 14) {
            artworkThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(track.sourcePlatformName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.sideBLinkBlue)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minWidth: 260, maxWidth: 330)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isCurrentUser ? 0.08 : 0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
    }

    private var artworkThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)

            if let artworkURL = track.artworkURL {
                CachedArtworkImage(url: artworkURL, placeholderFontSize: 14)
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var placeholderArtwork: some View {
        Image(systemName: "music.note")
            .font(.footnote)
            .foregroundStyle(isCurrentUser ? .white.opacity(0.85) : .secondary)
    }
}
