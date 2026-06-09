import Foundation

/// The "semantic category" of clipboard content—decoupled from
/// NSPasteboard.PasteboardType.
/// UI style attributes (iconName / shortLabel) live in Core/Common.swift.
enum ClipContentType: String, Codable, CaseIterable, Identifiable {
    case text
    case image
    case link
    case file
    case snippet

    var id: String { rawValue }

    /// English fallback (used internally by Common.swift and SwiftData
    /// migration—keeps backward compatibility).
    var displayName: String {
        switch self {
        case .text:    return "Text"
        case .image:   return "Images"
        case .link:    return "Links"
        case .file:    return "Files"
        case .snippet: return "Snippets"
        }
    }

    /// Localized display name—UI should use this; falls back to displayName
    /// when the localized string is missing.
    var localizedDisplayName: String {
        switch self {
        case .text:    return Strings.Tab.text
        case .image:   return Strings.Tab.images
        case .link:    return Strings.Tab.links
        case .file:    return Strings.Tab.files
        case .snippet: return Strings.Tab.snippets
        }
    }
}
