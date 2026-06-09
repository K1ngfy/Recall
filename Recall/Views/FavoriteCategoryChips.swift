import SwiftUI

/// 6.8 收藏分类标签条。
///
/// 设计：
/// - 始终显示 All;尾部仅在存在未分类收藏时显示 Uncategorized;中间是按字母排好序的分类名
/// - 使用 FlowLayout 自动换行:窄面板（left/right/center）chips 多时多行展开,
///   宽面板（top/bottom）通常一行能放下。不丢失任何分类,不依赖横向滚动手势
/// - 选中态走 accentColor,与 DateFilterChips 保持一致
/// - 由外层决定渲染时机:当且仅当 (categories 非空 || hasUncategorized) 时插入
struct FavoriteCategoryChips: View {
    @Binding var selection: ListViewModel.FavoriteCategoryFilter
    let categories: [String]
    let hasUncategorized: Bool

    @Namespace private var ns

    var body: some View {
        ChipFlowLayout(spacing: 4, lineSpacing: 4) {
            chip(label: Strings.FavoriteChips.all, value: .all)
            ForEach(categories, id: \.self) { name in
                chip(label: name, value: .named(name))
            }
            if hasUncategorized {
                chip(label: Strings.FavoriteChips.uncategorized, value: .uncategorized)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func chip(label: String, value: ListViewModel.FavoriteCategoryFilter) -> some View {
        let isSelected = (value == selection)
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = value
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minHeight: 22)
                .contentShape(Rectangle())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                                .matchedGeometryEffect(id: "favCatIndicator", in: ns)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

/// 简易 FlowLayout(macOS 14+ Layout protocol):chips 横向排列,
/// 当前行放不下时换到下一行。无需任何缓存——chips 数量很小,O(n) 重排可接受。
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        return arrange(subviews: subviews, width: width).total
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews: subviews, width: bounds.width)
        for (index, subview) in subviews.enumerated() {
            let origin = layout.origins[index]
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    /// 单次扫描:计算每个 chip 的左上角坐标 + 整体 bounding box
    private func arrange(subviews: Subviews, width: CGFloat) -> (total: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            // 当前行已经放过东西且放不下了 → 换行
            if cursorX > 0 && cursorX + size.width > width {
                cursorX = 0
                cursorY += lineHeight + lineSpacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: cursorX, y: cursorY))
            cursorX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxRowWidth = max(maxRowWidth, cursorX - spacing)
        }
        return (
            CGSize(width: maxRowWidth, height: cursorY + lineHeight),
            origins
        )
    }
}
