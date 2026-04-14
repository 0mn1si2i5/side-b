import SwiftUI

struct MessageRowView: View {
    let message: Message
    let showsMetadata: Bool
    let isGroupedWithNextMessage: Bool
    let onTrackUpdated: (Track) -> Void
    let onQuoteTrack: (Track) -> Void

    @State private var showingAddToPlaylistSheet = false
    @State private var selectedTrack: Track? = nil

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
                            SongDetailView(
                                track: track,
                                onTrackUpdated: onTrackUpdated
                            )
                        } label: {
                            CompactSongAttachmentView(track: track, isCurrentUser: isCurrentUser)
                        }
                        .buttonStyle(.plain)

                        if !isGroupedWithNextMessage {
                            HStack {
                                Button {
                                    onQuoteTrack(track)
                                } label: {
                                    Label("引用歌曲", systemImage: "quote.bubble")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    selectedTrack = track
                                    showingAddToPlaylistSheet = true
                                } label: {
                                    Label("加入歌单", systemImage: "plus.circle")
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
        .sheet(isPresented: $showingAddToPlaylistSheet) {
            if let track = selectedTrack {
                AddToPlaylistView(
                    track: track,
                    isPresented: $showingAddToPlaylistSheet
                )
            }
        }
    }
}

struct CompactSongAttachmentView: View {
    let track: Track
    let isCurrentUser: Bool

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
