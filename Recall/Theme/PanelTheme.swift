import SwiftUI

/// Recall main panel theme presets.
///
/// Each theme provides:
/// - `accent: Color`        — Primary highlight color (for .tint / selected state / icon).
/// - `background: AnyShapeStyle` — Panel background (plain / gradient / user custom).
/// - `displayName: String`  — UI display name (i18n goes through Strings).
enum PanelTheme: String, CaseIterable, Identifiable, Codable {
    case system      // Follows macOS light/dark + regularMaterial.
    case aurora      // Blue-purple gradient.
    case sunset      // Orange-pink gradient.
    case ocean       // Blue-cyan gradient.
    case forest      // Green-cyan gradient.
    case graphite    // Dark gray monochrome.
    case custom      // User hex + opacity.

    var id: String { rawValue }

    /// Whether the user needs to provide hex + opacity (only for .custom).
    var isCustomizable: Bool { self == .custom }

    /// Primary highlight color — for use with .tint().
    var accent: Color {
        switch self {
        case .system:     return .blue
        case .aurora:     return Color(red: 0.55, green: 0.40, blue: 0.95)  // Purple.
        case .sunset:     return Color(red: 0.98, green: 0.55, blue: 0.30)  // Orange.
        case .ocean:      return Color(red: 0.20, green: 0.65, blue: 0.95)  // Blue.
        case .forest:     return Color(red: 0.30, green: 0.75, blue: 0.50)  // Green.
        case .graphite:   return Color(red: 0.55, green: 0.55, blue: 0.58)  // Gray.
        case .custom:     return .blue  // Placeholder; reads customHex at runtime.
        }
    }

    /// Panel background — used as the background for panelContent at the top of RecallRootView.
    /// Uses AnyShapeStyle because LinearGradient / Material have incompatible protocols.
    /// Opacity is uniformly scaled by ThemeSettings.panelOpacity.
    func background(opacity: Double) -> AnyShapeStyle {
        switch self {
        case .system:
            return AnyShapeStyle(.regularMaterial)
        case .aurora:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.40, green: 0.30, blue: 0.85).opacity(opacity),
                        Color(red: 0.85, green: 0.45, blue: 0.85).opacity(opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .sunset:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.45, blue: 0.30).opacity(opacity),
                        Color(red: 1.00, green: 0.65, blue: 0.55).opacity(opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .ocean:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.45, blue: 0.85).opacity(opacity),
                        Color(red: 0.30, green: 0.75, blue: 0.85).opacity(opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .forest:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.55, blue: 0.40).opacity(opacity),
                        Color(red: 0.40, green: 0.75, blue: 0.60).opacity(opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .graphite:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.20, blue: 0.22).opacity(opacity),
                        Color(red: 0.35, green: 0.35, blue: 0.38).opacity(opacity),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .custom:
            return AnyShapeStyle(Color.clear)  // Placeholder — custom is rendered from customHex.
        }
    }
}
