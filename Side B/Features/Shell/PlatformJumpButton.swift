import SwiftUI

struct PlatformJumpButton: View {
    let platform: MusicPlatform
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 52, height: 52)

                Image(platform.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .saturation(isEnabled ? 1 : 0)
                    .opacity(isEnabled ? 1 : 0.38)

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(7)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(platform.displayName)
    }
}
