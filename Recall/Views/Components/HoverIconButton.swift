import SwiftUI

/// Small square button that fades in on hover inside list rows.
/// Replaces the ad-hoc 22pt / 18pt rounded button implementations scattered across
/// ClipRow/ClipCard/SnippetRow/RecallRootView.
///
/// - size: 18 (card / extra-small) / 22 (row) / 30 (toolbar)
/// - isActive: in the active state swaps the icon color (filled vs outline) + background fill
/// - isVisible: only fully opaque on hover/selected; falls back to 0.3 opacity otherwise
struct HoverIconButton: View {
    let systemName: String
    let activeSystemName: String?      // nil = don't swap icon
    let isActive: Bool
    let isVisible: Bool
    let size: CGFloat
    let activeTint: Color              // icon + background color used when isActive
    let help: String
    let action: () -> Void

    init(
        systemName: String,
        activeSystemName: String? = nil,
        isActive: Bool = false,
        isVisible: Bool = true,
        size: CGFloat = 22,
        activeTint: Color = .accentColor,
        help: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.activeSystemName = activeSystemName
        self.isActive = isActive
        self.isVisible = isVisible
        self.size = size
        self.activeTint = activeTint
        self.help = help
        self.action = action
    }

    private var icon: String {
        isActive ? (activeSystemName ?? systemName) : systemName
    }

    private var fontSize: CGFloat {
        switch size {
        case 18: return 9
        case 22: return 11
        case 30: return 13
        default: return 11
        }
    }

    private var cornerRadius: CGFloat {
        size <= 18 ? 4 : 6
    }

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(isActive ? activeTint : .secondary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isActive ? activeTint.opacity(0.18) : Color.primary.opacity(0.04))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .opacity(isVisible ? 1 : 0.3)
    }
}
