import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum SideBVisualStyle {
    static let appAppearanceStorageKey = "sideb.appAppearance"
    static let linkBlue = Color(red: 0.18, green: 0.47, blue: 0.95)
    static let disabledOpacity = 0.34
    static let surfaceBorder = Color.primary.opacity(0.10)
    static let surfaceShadow = Color.black.opacity(0.08)
}

extension ShapeStyle where Self == Color {
    static var sideBLinkBlue: Color { SideBVisualStyle.linkBlue }
}

extension View {
    func sideBGlassSurface(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: SideBVisualStyle.surfaceShadow, radius: 14, y: 7)
    }

    func sideBGlassCircle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(color: SideBVisualStyle.surfaceShadow, radius: 10, y: 5)
    }

    func sideBAuthFieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
