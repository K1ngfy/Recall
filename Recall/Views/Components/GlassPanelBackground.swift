import SwiftUI

/// Shared frosted-glass background for RecallPanel / SnippetsWindow.
/// 18pt corner radius + regularMaterial + 4% primary fallback + 0.5pt border.
struct GlassPanelBackground: View {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    private var rounded: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            rounded.fill(.regularMaterial)
            rounded.fill(Color.primary.opacity(0.04))
        }
        .overlay(
            rounded.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
