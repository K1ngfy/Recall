import SwiftUI

/// "Copied" transient hint. Shared by ClipCard/ClipRow; compact mode is used in 200x170 cards.
/// Callers position it with .overlay(alignment: ...).
struct CopiedToast: View {
    let compact: Bool

    private var iconFont: CGFloat { compact ? 9 : 10 }
    private var textFont: CGFloat { compact ? 10 : 11 }
    private var hPad: CGFloat       { compact ? 7 : 9 }
    private var vPad: CGFloat       { compact ? 4 : 5 }

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            Image(systemName: "checkmark")
                .font(.system(size: iconFont, weight: .bold))
            Text(Strings.Toast.copied)
                .font(.system(size: textFont, weight: .medium))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(Capsule().fill(.regularMaterial))
        .overlay(
            Capsule().strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 0.5)
        )
    }
}
