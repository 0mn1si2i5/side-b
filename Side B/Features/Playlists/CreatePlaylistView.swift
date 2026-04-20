import SwiftUI

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playlistName: String = ""
    @State private var viewModel = CreatePlaylistViewModel()
    
    let onCreated: (Playlist) -> Void
    
    private var isCreateEnabled: Bool {
        !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("歌单名称", text: $playlistName)
                }
            }
            .navigationTitle("新建歌单")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createPlaylist()
                    }
                    .disabled(!isCreateEnabled)
                }
            }
        }
    }
    
    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let playlist = viewModel.createPlaylist(name: trimmedName)
        onCreated(playlist)
        dismiss()
    }
}

#if DEBUG
struct CreatePlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlaylistView(onCreated: { _ in })
    }
}
#endif
