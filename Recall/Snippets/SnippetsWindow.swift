import SwiftUI

/// Style outer layer of the Snippets popover: identical to RecallPanel.
/// - regularMaterial + primary 5% fallback.
/// - 0.5pt stroke.
/// - Unified 4-corner 18pt radius.
/// - Explicit .frame(width:height:) locks SwiftUI body size to prevent
///   NSHostingController from shrinking the window to header width via intrinsic content size.
/// - clipShape fallback ensures all 4 corners are clipped to the rounded radius.
struct SnippetsWindow<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: () -> Content

    init(
        size: CGSize,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.content = content
    }

    /// 18pt radius matches RecallPanel / GlassPanelBackground defaults.
    private let cornerRadius: CGFloat = 18

    private var roundedShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        let theme = ThemeSettings.shared
        ZStack(alignment: .topLeading) {
            // From 6.7 onwards, responds to theme color together with the main panel — reads theme.resolvedBackgroundStyle().
            // Uses the same helper to keep the snippet popover visually consistent with the main panel.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.resolvedBackgroundStyle())
            // Fallback: primary 4% in both light/dark.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
            // Stroke.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            // Top layer: business content.
            content()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(roundedShape)
        // Tint injection: Color.accentColor inside content stays in sync with the theme color.
        .tint(theme.resolvedAccentColor)
    }
}
