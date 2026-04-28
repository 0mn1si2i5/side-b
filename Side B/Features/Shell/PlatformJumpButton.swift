import SwiftUI

struct PlatformJumpButton: View {
    let platform: MusicPlatform
    let isEnabled: Bool
    let isLoading: Bool
    var showsTitle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Image(platform.iconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .scaleEffect(platform.iconDisplayScale)
                        .saturation(isEnabled ? 1 : 0)
                        .opacity(isEnabled ? 1 : SideBVisualStyle.disabledOpacity)

                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(7)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                if showsTitle {
                    Text(platform.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 68 : 64)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(platform.displayName)
    }
}

private extension MusicPlatform {
    var iconDisplayScale: CGFloat {
        switch self {
        case .appleMusic:
            return 0.96
        case .spotify:
            return 1.55
        case .qqMusic:
            return 0.96
        case .neteaseMusic:
            return 0.98
        }
    }
}
