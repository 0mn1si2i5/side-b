import SwiftUI

extension AvatarBackgroundColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct AvatarSelectionView: View {

    @Binding var selectedAvatar: String

    private let columns = [
        GridItem(.adaptive(minimum: 52, maximum: 64), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AvatarService.availableAvatars, id: \.self) { name in
                avatarCell(name: name)
            }
        }
        .padding(.vertical, 4)
    }

    private func avatarCell(name: String) -> some View {
        let config = AvatarService.config(for: name)
        let isSelected = selectedAvatar == name

        return Button {
            selectedAvatar = name
        } label: {
            Circle()
                .fill(config.backgroundColor.swiftUIColor.opacity(0.2))
                .overlay {
                    Image(systemName: config.symbolName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(config.backgroundColor.swiftUIColor)
                        .padding(12)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.7), lineWidth: 3)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selected = "avatar_1"
        var body: some View {
            AvatarSelectionView(selectedAvatar: $selected)
        }
    }
    return PreviewWrapper()
}
