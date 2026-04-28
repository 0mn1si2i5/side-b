import SwiftUI

struct RoomsListView: View {
    @State private var viewModel = RoomsListViewModel()
    @State private var showingCreateRoom = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("加载中...")
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
                    showingCreateRoom = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateRoom, onDismiss: {
            if case .loaded = viewModel.state {
                viewModel.loadRooms()
            }
        }) {
            NavigationStack {
                CreateRoomView()
            }
        }
    }

    private func roomsList(rooms: [Room]) -> some View {
        List(rooms) { room in
            NavigationLink {
                RoomDetailView(room: room)
            } label: {
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
