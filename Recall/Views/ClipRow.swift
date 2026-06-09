import SwiftUI
import AppKit

/// A single clipboard entry. Text/link/image/snippet each have a different layout.
struct ClipRow: View {
    let item: ClipItemViewData
    let isSelected: Bool
    let isMultiSelected: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onToggleMulti: () -> Void
    let onMakeSnippet: () -> Void
    /// 6.8 起 ⭐ 按钮无论是否已收藏一律弹 FavoriteSheet（编辑标题/分类/移除）。
    /// onToggleFavorite 仅保留给 contextMenu 的「Remove from Favorites」快速路径。
    let onEditFavorite: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false
    @State private var showCopiedToast = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if isMultiSelected { checkbox }
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                // 6.8 收藏项已填 title 时：副行多一段内容预览（截断）
                if showsFavoriteSubtitle, let subtitle = favoriteSubtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Text(relativeTimeString(from: item.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    if let category = item.favoriteCategory,
                       !category.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("·")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                        Text(category)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.accentColor.opacity(0.85))
                    }
                    if item.usageCount > 0 {
                        Text("·")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                        Text("used \(item.usageCount)×")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            // 6.5 snippet action button (only text type can be promoted to snippet)
            if item.contentType == .text || item.contentType == .snippet {
                snippetButton
            }
            // 6.7 favorite button (all types can be favorited)
            favoriteButton
            copyButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundFill)
        )
        .contentShape(Rectangle())
        .hoverPreview(for: item)
        .contextMenu {
            contextMenuItems
        }
        .overlay(alignment: .trailing) {
            if showCopiedToast {
                copiedToast
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .gesture(
            TapGesture(count: 1).onEnded {
                // Cmd+Click goes to the multi-select branch; regular Click goes to the single-select branch.
                // Use NSEvent.modifierFlags to distinguish (the macOS SwiftUI .modifiers(.command)
                // fires together with the single click, so it feels like "deselect").
                if NSEvent.modifierFlags.contains(.command) {
                    onToggleMulti()
                } else {
                    onSelect()
                }
            }
        )
        .gesture(
            TapGesture(count: 2).onEnded { onActivate() }
        )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Copy") { onCopy() }
        // 6.8 add 也走弹框（让用户立刻填 title/category）；remove 保持一键
        if item.isFavorite {
            Button("Edit Favorite…") { onEditFavorite() }
            Button("Remove from Favorites") { onToggleFavorite() }
        } else {
            Button("Add to Favorites…") { onEditFavorite() }
        }
        if item.contentType == .text || item.contentType == .snippet {
            Button(item.isSnippet ? "Edit Snippet…" : "Make Snippet…") {
                onMakeSnippet()
            }
        }
        if item.isSnippet {
            Divider()
            Button("Remove Snippet", role: .destructive) {
                SnippetService.demoteFromSnippet(item)
            }
        }
    }

    private var backgroundFill: Color {
        if isMultiSelected { return Color.accentColor.opacity(0.30) }
        if isSelected     { return Color.accentColor.opacity(0.22) }
        if isHovered      { return Color.primary.opacity(0.05) }
        return .clear
    }

    private var checkbox: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.accentColor)
    }

    private var copyButton: some View {
        HoverIconButton(
            systemName: "square.on.square",
            isVisible: isHovered || isSelected,
            size: 22,
            activeTint: .secondary,
            help: "Copy to clipboard"
        ) {
            onCopy()
            flashCopiedToast()
        }
    }

    /// 6.7 favorite star button: matches the snippet button style exactly (uses accentColor)
    /// 6.8 起点击行为变为弹 FavoriteSheet（editing），不再直接 toggle
    private var favoriteButton: some View {
        HoverIconButton(
            systemName: "star",
            activeSystemName: "star.fill",
            isActive: item.isFavorite,
            isVisible: item.isFavorite || isHovered || isSelected,
            size: 22,
            activeTint: .accentColor,
            help: item.isFavorite ? "Edit Favorite" : "Add to Favorites"
        ) {
            onEditFavorite()
        }
    }

    /// 6.5 snippet bolt button: shown on hover
    private var snippetButton: some View {
        HoverIconButton(
            systemName: "bolt",
            activeSystemName: "bolt.fill",
            isActive: item.isSnippet,
            isVisible: isHovered || isSelected,
            size: 22,
            activeTint: .accentColor,
            help: item.isSnippet ? "Edit Snippet" : "Make this into a Snippet"
        ) {
            onMakeSnippet()
        }
    }

    private var copiedToast: some View {
        CopiedToast(compact: false)
            .padding(.trailing, 32)
    }

    private func flashCopiedToast() {
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch item.contentType {
        case .image:
            ThumbnailView(data: item.thumbnailData, size: 36)
        case .text:
            iconBubble("text.alignleft", accent: false)
        case .link:
            linkBadge
        case .file:
            FileIconView(path: item.textContent ?? "")
        case .snippet:
            iconBubble("text.book.closed", accent: true)
        }
    }

    /// Round icon showing the first letter of a link
    private var linkBadge: some View {
        let letter = (item.linkTitle ?? item.linkHost ?? item.textContent ?? "?")
            .trimmingCharacters(in: .whitespaces)
            .prefix(1)
            .uppercased()
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
            Text(String(letter))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 36, height: 36)
    }

    @ViewBuilder
    private func iconBubble(_ symbol: String, accent: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
            Image(systemName: symbol)
                .foregroundStyle(accent ? Color.accentColor : .secondary)
                .font(.system(size: 16, weight: .regular))
        }
        .frame(width: 36, height: 36)
    }

    private var primaryText: String {
        // 6.8 收藏项已填 title → 主行展示 title（覆盖原内容预览，让 favorites 一眼可辨）
        if let t = item.favoriteTitle?.trimmingCharacters(in: .whitespaces), !t.isEmpty {
            return t
        }
        switch item.contentType {
        case .text:
            return (item.textContent ?? "").replacingOccurrences(of: "\n", with: " ")
        case .link:
            return item.linkTitle ?? item.linkHost ?? (item.textContent ?? "").replacingOccurrences(of: "\n", with: " ")
        case .image:
            return "Image · \(item.contentHash.prefix(8))"
        case .file:
            // Show file name + parent directory (truncated) so the user can tell things like
            // /Users/x/Downloads/foo.pdf apart at a glance.
            let url = URL(fileURLWithPath: item.textContent ?? "")
            let name = url.lastPathComponent
            let parent = url.deletingLastPathComponent().lastPathComponent
            return parent.isEmpty ? name : "\(name)  ·  \(parent)"
        case .snippet:
            let trigger = item.triggerWord.map { "/\($0)" } ?? ""
            return "\(trigger) \(item.textContent ?? "")".trimmingCharacters(in: .whitespaces)
        }
    }

    /// 6.8 主行被 favoriteTitle 占用时,副行展示一段内容预览
    private var showsFavoriteSubtitle: Bool {
        guard let t = item.favoriteTitle?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return false }
        return favoriteSubtitle != nil
    }

    private var favoriteSubtitle: String? {
        switch item.contentType {
        case .text, .snippet:
            let s = (item.textContent ?? "").replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        case .link:
            return item.linkHost ?? item.textContent
        case .file:
            let url = URL(fileURLWithPath: item.textContent ?? "")
            return url.lastPathComponent.isEmpty ? nil : url.lastPathComponent
        case .image:
            return nil
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60        { return "just now" }
        if interval < 3600      { return "\(Int(interval / 60))m ago" }
        if interval < 86400     { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
