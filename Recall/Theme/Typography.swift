import SwiftUI

/// Recall font size / weight / line-height constants.
/// `.font(.system(size: 9))` scattered across views should prefer these definitions
/// to reduce duplication and keep consistency. Future Dynamic Type / a11y changes can be done in one place.
enum T {
    static let tiny    = CGFloat(9)    // Tiny badges, timestamps.
    static let caption = CGFloat(10)   // Subtext, small numbers.
    static let small   = CGFloat(11)   // Descriptions, thumbnails.
    static let body    = CGFloat(13)   // Main list text.
    static let title   = CGFloat(14)   // Empty state title.
}

/// Inline mini button corner radius.
enum R {
    static let iconBubbleOuter: CGFloat = 6
    static let iconBubbleInner: CGFloat = 4
}
