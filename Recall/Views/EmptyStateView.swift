import SwiftUI

/// Polished empty-state illustration. Covers 6 cases:
/// - no data: clipboard has no entries / the category has no entries
/// - no search results: query has no matches
/// - favorites empty / snippets empty: side entry is empty
struct EmptyStateView: View {
    let kind: Kind

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
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            illustration
                .fixedSize()
            VStack(spacing: 6) {
                Text(kind.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Gradient circle + large icon (replaces a single SF Symbol for a more refined look)
    private var illustration: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.20), Color.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 84, height: 84)

            Image(systemName: kind.iconName)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.accentColor)
        }
    }
}
