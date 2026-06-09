import SwiftUI

/// Hex string → Color parser.
///
/// Accepts (case-insensitive, optional `#` prefix):
/// - `#RRGGBB` / `RRGGBB`     — 24-bit RGB
/// - `#RGB`     / `RGB`         — 12-bit RGB (each digit is automatically expanded to two, e.g. `f0a` → `ff00aa`)
/// - `#RRGGBBAA` / `RRGGBBAA`  — 32-bit RGBA
///
/// Returns nil on parse failure (caller should provide a fallback).
enum HexColor {
    /// Parse a hex string into a SwiftUI Color; returns nil on failure.
    static func parse(_ raw: String) -> Color? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        // Length must be 3, 6, or 8.
        guard s.count == 3 || s.count == 6 || s.count == 8 else { return nil }
        // Must all be 0-9 / a-f.
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard s.unicodeScalars.allSatisfy(allowed.contains) else { return nil }

        let expanded: String
        if s.count == 3 {
            // #RGB → #RRGGBB.
            expanded = s.map { "\($0)\($0)" }.joined()
        } else {
            expanded = s
        }

        var hex: UInt64 = 0
        guard Scanner(string: expanded).scanHexInt64(&hex) else { return nil }

        let r, g, b, a: Double
        if expanded.count == 6 {
            r = Double((hex >> 16) & 0xFF) / 255.0
            g = Double((hex >> 8)  & 0xFF) / 255.0
            b = Double( hex        & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((hex >> 24) & 0xFF) / 255.0
            g = Double((hex >> 16) & 0xFF) / 255.0
            b = Double((hex >> 8)  & 0xFF) / 255.0
            a = Double( hex        & 0xFF) / 255.0
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    /// Encode a Color back into a #RRGGBB string (used to display user input).
    static func format(_ color: Color) -> String {
        #if canImport(AppKit)
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
        let r = Int(round(ns.redComponent   * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent  * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#000000"
        #endif
    }
}
