import Foundation
import SwiftUI
import AppKit
import os.log

// MARK: - Logger

/// Global unified logger. Release uses .info, Debug uses .debug.
enum AppLog {
    static let general   = Logger(subsystem: "com.recall.app", category: "general")
    static let store     = Logger(subsystem: "com.recall.app", category: "store")
    static let paste     = Logger(subsystem: "com.recall.app", category: "paste")
    static let hotkey    = Logger(subsystem: "com.recall.app", category: "hotkey")
    static let window    = Logger(subsystem: "com.recall.app", category: "window")
}

// MARK: - Relative Time

/// Format: "just now" / "5m ago" / "2h ago" / "3d ago" / "2024-01-15".
enum RelativeTime {
    static func string(from date: Date, now: Date = .now) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60        { return "just now" }
        if interval < 3_600     { return "\(Int(interval / 60))m ago" }
        if interval < 86_400    { return "\(Int(interval / 3_600))h ago" }
        if interval < 604_800   { return "\(Int(interval / 86_400))d ago" }
        return Self.absoluteFormatter.string(from: date)
    }

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - Content Type Style

/// Centralizes the style attributes needed at the UI layer for ClipContentType.
extension ClipContentType {
    var shortLabel: String {
        switch self {
        case .text:    return "Text"
        case .image:   return "Image"
        case .link:    return "Link"
        case .file:    return "File"
        case .snippet: return "Snippet"
        }
    }

    var iconName: String {
        switch self {
        case .text:    return "text.alignleft"
        case .image:   return "photo"
        case .link:    return "link"
        case .file:    return "doc"
        case .snippet: return "text.book.closed"
        }
    }
}

// MARK: - URL Safety

extension URL {
    /// Only allow http/https — guards against malicious schemes like `javascript:` / `file://`.
    var isSafeWeb: Bool {
        guard let scheme = self.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

// MARK: - View Extensions

// MARK: - Image Thumbnail (sync version, for small images on the main thread)

enum Thumbnail {
    /// Synchronously generate a thumbnail on the main thread (for small images; large images go through an actor).
    static func makeSync(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        let original = bitmap.size
        let maxSide = ClipStorageLocation.thumbnailMaxPixel
        let scale = min(1.0, maxSide / max(original.width, original.height))
        let target = NSSize(
            width: max(1, floor(original.width * scale)),
            height: max(1, floor(original.height * scale))
        )

        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: original),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let rTiff = resized.tiffRepresentation,
              let rBitmap = NSBitmapImageRep(data: rTiff) else { return nil }
        return rBitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: ClipStorageLocation.thumbnailJPEGQuality]
        )
    }
}
