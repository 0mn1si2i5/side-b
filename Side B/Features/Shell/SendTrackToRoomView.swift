import SwiftUI

struct SendTrackToRoomView: View {
    let track: Track
    @Binding var isPresented: Bool
    var onSent: ((Room) -> Void)?

    @State private var viewModel = SendTrackToRoomViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("加载聊天室...")
                case .failed(let message):
                    ContentUnavailableView(
                        "无法加载聊天室",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded(let rooms):
                    if rooms.isEmpty {
                        ContentUnavailableView(
                            "暂无聊天室",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("先创建一个聊天室，再发送歌曲。")
                        )
                    } else {
                        List(rooms) { room in
                            Button {
                                viewModel.send(track: track, to: room) {
                                    onSent?(room)
                                    isPresented = false
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(room.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("\(room.memberUsernames.count) 人")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if viewModel.sendingRoomID == room.id {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .disabled(viewModel.sendingRoomID != nil)
                        }
                    }
                }
            }
            .navigationTitle("发送到聊天室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .alert("发送失败", isPresented: $viewModel.showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                viewModel.loadRoomsIfNeeded()
            }
        }
    }
}

enum SendTrackToRoomState {
    case idle
    case loading
    case loaded([Room])
    case failed(String)
}

@MainActor
@Observable
final class SendTrackToRoomViewModel {
    var state: SendTrackToRoomState = .idle
    var sendingRoomID: UUID?
    var showErrorAlert = false
    var errorMessage = ""

    private let roomService: any RoomServiceProtocol
    private let messageService: any MessageServiceProtocol

    init(
        roomService: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService(),
        messageService: any MessageServiceProtocol = MessageServiceFactory.makeDefaultService()
    ) {
        self.roomService = roomService
        self.messageService = messageService
    }

    func loadRoomsIfNeeded() {
        if case .idle = state {
            loadRooms()
        }
    }

    private func loadRooms() {
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                state = .loaded(try await roomService.fetchRooms())
            } catch {
                state = .failed(localizedErrorMessage(for: error))
            }
        }
    }

    func send(track: Track, to room: Room, onSuccess: @escaping () -> Void) {
        sendingRoomID = room.id
        Task { [weak self] in
            guard let self else { return }
            do {
                let sentMessage = try await messageService.sendSongMessage(roomId: room.id, track: track)
                if let sentTrack = sentMessage.track {
                    PlatformLinkPersistenceStore.shared.save(track: sentTrack)
                    TrackCache.shared.save(track: sentTrack)
                    if let identity = sentTrack.persistenceIdentity {
                        RecentlyResolvedStore.shared.add(identity)
                    }
                } else {
                    PlatformLinkPersistenceStore.shared.save(track: track)
                    TrackCache.shared.save(track: track)
                    if let identity = track.persistenceIdentity {
                        RecentlyResolvedStore.shared.add(identity)
                    }
                }
                sendingRoomID = nil
                onSuccess()
            } catch {
                sendingRoomID = nil
                errorMessage = localizedErrorMessage(for: error)
                showErrorAlert = true
            }
        }
    }
}
