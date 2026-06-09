import SwiftUI

/// Category tabs: All / Text / Images / Links / Files  |  Favorites
/// - 5 content-type tabs sit inside a capsule container on the left
/// - The Favorites entry lives on the right as a separate capsule, visually distinct from the "type" group
/// - compact: side narrow panel shows only icons
struct CategoryTabs: View {
    @Binding var selection: ListViewModel.Filter
    var compact: Bool = false
    @Namespace private var ns

    private let typeTabs: [ListViewModel.Filter] = [
        .all,
        .category(.text),
        .category(.image),
        .category(.link),
        .category(.file)
    ]

    var body: some View {
        HStack(spacing: 6) {
            // Content type group
            HStack(spacing: compact ? 4 : 4) {
                ForEach(typeTabs) { tab in
                    tabButton(tab, inGroup: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.45))
            )

            // Favorites entry: standalone capsule (visually distinct from the "type" group)
            tabButton(.favorites, inGroup: false)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary.opacity(0.45))
                )
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: ListViewModel.Filter, inGroup: Bool) -> some View {
        let isSelected = (tab == selection)
        let isFavorite = (tab == .favorites)
        // Favorites always shows icon only; type buttons also show icon only in compact mode
        let iconOnly = compact || isFavorite

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 11, weight: .medium))
                if !iconOnly {
                    Text(tab.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, iconOnly ? 0 : 12)
            .padding(.vertical, 6)
            .frame(
                minWidth:  iconOnly ? (isFavorite ? 28 : nil) : 60,
                maxWidth:  (compact && inGroup) ? .infinity : nil,
                minHeight: 28
            )
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? Color.primary : .secondary)
            .background(
                Group {
                    if isSelected {
                        // Selected state uses accentColor uniformly, no more jarring yellow.
                        // The inner/outer capsule containers each have their own matchedGeometry namespace
                        // — prevents the indicator from "flying" between inner and outer capsules
                        // when toggling favorites.
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.accentColor.opacity(0.20))
                            .matchedGeometryEffect(
                                id: inGroup ? "typeIndicator" : "favIndicator",
                                in: ns
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .help(tab.displayName)
    }
}
