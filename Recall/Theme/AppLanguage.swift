import Foundation

/// Application languages supported by Recall.
///
/// Runtime switching overrides UserDefaults `AppleLanguages` — Apple's Foundation reads this key when
/// initializing the Bundle on the next launch to determine the language preference. Strings are cached
/// for the current launch, so changes take effect after restart.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    /// Follow the macOS system setting.
    case system
    case english          = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:            return "Follow System"
        case .english:           return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    /// Value written to AppleLanguages; system = nil (do not override system).
    var appleLanguageCode: String? {
        switch self {
        case .system:            return nil
        case .english:           return "en"
        case .simplifiedChinese: return "zh-Hans"
        }
    }
}
