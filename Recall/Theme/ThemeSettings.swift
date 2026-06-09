import SwiftUI
import Observation

/// User-visible appearance settings. @AppStorage routes through UserDefaults, avoiding a separate SwiftData stream.
/// State changes automatically re-render SwiftUI views; external SwiftUI environment is injected via .tint / .preferredColorScheme.
@MainActor
@Observable
final class ThemeSettings {
    static let shared = ThemeSettings()

    /// Theme preset. Default = .system (follows macOS light/dark + regularMaterial).
    var theme: PanelTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    /// Panel background opacity 0.5 - 1.0 (no visual change in .regularMaterial mode; mainly for gradient themes).
    var panelOpacity: Double {
        didSet {
            let clamped = min(1.0, max(0.5, panelOpacity))
            if clamped != panelOpacity { panelOpacity = clamped; return }
            UserDefaults.standard.set(panelOpacity, forKey: Keys.panelOpacity)
        }
    }
    /// Custom accent hex (used only when theme == .custom). nil = fallback to theme.accent.
    /// Validated on write — invalid hex is not persisted.
    var customAccentHex: String? {
        didSet {
            if let hex = customAccentHex, HexColor.parse(hex) != nil {
                UserDefaults.standard.set(hex, forKey: Keys.customAccent)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.customAccent)
            }
        }
    }
    /// Custom panel background color (used only when theme == .custom).
    var customBackgroundHex: String? {
        didSet {
            if let hex = customBackgroundHex, HexColor.parse(hex) != nil {
                UserDefaults.standard.set(hex, forKey: Keys.customBackground)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.customBackground)
            }
        }
    }
    var forcedScheme: ForcedScheme {
        didSet { UserDefaults.standard.set(forcedScheme.rawValue, forKey: Keys.scheme) }
    }

    /// Currently effective accent color — customAccentHex takes priority, otherwise theme.accent.
    var resolvedAccentColor: Color {
        if theme == .custom, let hex = customAccentHex, let color = HexColor.parse(hex) {
            return color
        }
        return theme.accent
    }

    /// Currently effective panel background style.
    func resolvedBackgroundStyle() -> AnyShapeStyle {
        if theme == .custom, let hex = customBackgroundHex, let color = HexColor.parse(hex) {
            return AnyShapeStyle(color.opacity(panelOpacity))
        }
        return theme.background(opacity: panelOpacity)
    }

    private enum Keys {
        static let theme            = "theme.theme"
        static let customAccent     = "theme.customAccent"
        static let customBackground = "theme.customBackground"
        static let panelOpacity     = "theme.panelOpacity"
        static let scheme           = "theme.forcedScheme"
    }

    private init() {
        let themeRaw = UserDefaults.standard.string(forKey: Keys.theme) ?? PanelTheme.system.rawValue
        self.theme = PanelTheme(rawValue: themeRaw) ?? .system

        let savedHex = UserDefaults.standard.string(forKey: Keys.customAccent)
        self.customAccentHex = (savedHex.flatMap(HexColor.parse)) != nil ? savedHex : nil

        let savedBg = UserDefaults.standard.string(forKey: Keys.customBackground)
        self.customBackgroundHex = (savedBg.flatMap(HexColor.parse)) != nil ? savedBg : nil

        let opacity = UserDefaults.standard.object(forKey: Keys.panelOpacity) as? Double
        self.panelOpacity = opacity.map { min(1.0, max(0.5, $0)) } ?? 1.0

        let schemeRaw = UserDefaults.standard.string(forKey: Keys.scheme) ?? ForcedScheme.system.rawValue
        self.forcedScheme = ForcedScheme(rawValue: schemeRaw) ?? .system
    }
}

/// Forced light/dark mode.
enum ForcedScheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Follow System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Value passed to SwiftUI .preferredColorScheme. nil for .system means follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
