import SwiftUI

struct RoomsListView: View {
    @Binding var navigationPath: [Room]
    @State private var viewModel = RoomsListViewModel()
    @State private var showingRoomActions = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.loadRooms()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let rooms):
                if rooms.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无房间")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    roomsList(rooms: rooms)
                }
            }

        }
        .task {
            if case .idle = viewModel.state {
                viewModel.loadRooms()
            }
        }
        .navigationTitle("房间")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingRoomActions = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.primary)
            }
        }
        .sheet(isPresented: $showingRoomActions, onDismiss: {
            if case .loaded = viewModel.state {
                viewModel.loadRooms()
            }
        }) {
            NavigationStack {
                CreateRoomView {
                    viewModel.refreshRooms()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sideBRoomDissolved)) { notification in
            guard let dissolvedRoomID = notification.userInfo?[RoomNotificationKey.roomID] as? UUID else {
                return
            }
            navigationPath.removeAll()
            viewModel.removeRoom(id: dissolvedRoomID)
            viewModel.refreshRooms()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sideBRoomUpdated)) { _ in
            viewModel.refreshRooms()
        }
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(room: room) {
                navigationPath.removeAll()
                viewModel.removeRoom(id: room.id)
                viewModel.refreshRooms()
            }
        }
    }

    private func roomsList(rooms: [Room]) -> some View {
        List(rooms) { room in
            NavigationLink(value: room) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(room.name)
                            .font(.headline)

                        Text("\(room.memberUsernames.count) 人")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.14))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }

                    Text("房间号 \(room.roomCode)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)

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
    }
}
