import SwiftUI

/// Polished empty-state illustration. Covers 6 cases:
/// - no data: clipboard has no entries / the category has no entries
/// - no search results: query has no matches
/// - favorites empty / snippets empty: side entry is empty
struct EmptyStateView: View {
    let kind: Kind
    /// 6.9 compact 模式:horizontal(top/bottom)和 center dock 下面板较矮,
    /// 默认 140pt illustration 占太大比例,启用此模式后整体缩小一档。
    var compact: Bool = false

    enum Kind {
        case noHistory                                // globally empty
        case noCategory(ClipContentType)              // a specific category is empty
        case noFavorites                              // Favorites entry is empty
        case noSearchResults(query: String)           // search has no results

        var iconName: String {
            switch self {
            case .noHistory:                   return "doc.on.clipboard"
            case .noCategory(.text):           return "text.alignleft"
            case .noCategory(.image):          return "photo"
            case .noCategory(.link):           return "link"
            case .noCategory(.file):           return "doc"
            case .noCategory(.snippet):        return "text.book.closed"
            case .noFavorites:                 return "star"
            case .noSearchResults:             return "magnifyingglass"
            }
        }

        var title: String {
            switch self {
            case .noHistory:           return Strings.Empty.noHistoryTitle()
            case .noCategory(.text):   return Strings.Empty.noTextTitle()
            case .noCategory(.image):  return Strings.Empty.noImagesTitle()
            case .noCategory(.link):   return Strings.Empty.noLinksTitle()
            case .noCategory(.file):   return Strings.Empty.noFilesTitle()
            case .noCategory(.snippet): return Strings.Empty.noSnippetsTitle()
            case .noFavorites:         return Strings.Empty.noFavoritesTitle()
            case .noSearchResults:     return Strings.Empty.noSearchResultsTitle()
            }
        }

        var subtitle: String {
            switch self {
            case .noHistory:           return Strings.Empty.noHistorySubtitle()
            case .noCategory(.text):   return Strings.Empty.noTextSubtitle()
            case .noCategory(.image):  return Strings.Empty.noImagesSubtitle()
            case .noCategory(.link):   return Strings.Empty.noLinksSubtitle()
            case .noCategory(.file):   return Strings.Empty.noFilesSubtitle()
            case .noCategory(.snippet): return Strings.Empty.noSnippetsSubtitle()
            case .noFavorites:         return Strings.Empty.noFavoritesSubtitle()
            case .noSearchResults:     return Strings.Empty.noSearchResultsSubtitle()
            }
        }
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 18) {
            Spacer(minLength: 0)
            illustration
            VStack(spacing: compact ? 3 : 6) {
                Text(kind.title)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.subtitle)
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, compact ? 24 : 32)
                    .lineLimit(compact ? 2 : nil)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Gradient circle + large icon (replaces a single SF Symbol for a more refined look)
    private var illustration: some View {
        let outer: CGFloat = compact ? 76 : 140
        let inner: CGFloat = compact ? 48 : 84
        let icon:  CGFloat = compact ? 22 : 36
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.0)],
                        center: .center,
                        startRadius: compact ? 12 : 20,
                        endRadius:   compact ? 40 : 70
                    )
                )
                .frame(width: outer, height: outer)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.20), Color.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: inner, height: inner)

            Image(systemName: kind.iconName)
                .font(.system(size: icon, weight: .light))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: outer, height: outer)   // 固定容器尺寸,防止 RadialGradient 撑出
    }
}
