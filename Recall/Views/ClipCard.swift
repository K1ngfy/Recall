import SwiftUI

/// Bento card used when docked at the top/bottom. 200x170 compact layout, slight lift on hover.
/// Since 6.7 multi-select is supported: Cmd+Click toggles multi-select / checkbox at top corner / accent highlight.
struct ClipCard: View {
    let item: ClipItemViewData
    let isSelected: Bool
    let isMultiSelected: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onMakeSnippet: () -> Void
    /// 6.8 起 ⭐ 按钮一律弹 FavoriteSheet
    let onEditFavorite: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleMulti: () -> Void

    @State private var isHovered = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top label strip
            // 6.9 fix: 160pt 卡片宽塞不下 7 个元素,之前 typeLabel "Text" 被压成 Te/xt,
            // timestamp "7m ago" 压成 7m/ag/o。优化:
            // 1) 删 typeLabel(icon 已表达类别)
            // 2) timestamp 加 fixedSize + lineLimit(1) 防竖排
            // 3) copyButton 仅 hover/selected 时显示,空闲态留出宽度
            HStack(spacing: 3) {
                // Multi-select checkbox: always visible when selected, hover-only otherwise.
                // Use Image + onTapGesture instead of Button to avoid clashing with the outer TapGesture.
                Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: isMultiSelected ? .semibold : .regular))
                    .foregroundStyle(isMultiSelected ? Color.accentColor : .secondary)
                    .opacity(isMultiSelected || isHovered ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleMulti() }

                Image(systemName: typeIcon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected || isMultiSelected ? Color.accentColor : .secondary)
                Spacer(minLength: 4)
                Text(relativeTimeString(from: item.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    // 6.9 fix: 之前用 .fixedSize 防"7m/ag/o"竖排,但 fixedSize 会
                    // 在 hover 全按钮显示时把 spacer 压成负值,挤出右侧按钮。
                    // 改用 layoutPriority(1):优先让 timestamp 拿到所需宽度,
                    // 不够时仍能 truncate(…) —— 既不会竖排,也不会撑爆 HStack。
                    .layoutPriority(1)
                if item.contentType == .text || item.contentType == .snippet {
                    snippetButton
                }
                favoriteButton
                copyButton
            }
            .padding(.bottom, 6)

            // Body
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(width: 160, height: 170)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    isMultiSelected ? Color.accentColor.opacity(0.30) :
                    isSelected    ? Color.accentColor.opacity(0.18) :
                    isHovered     ? Color.primary.opacity(0.08) :
                                    Color.primary.opacity(0.04)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isMultiSelected ? Color.accentColor.opacity(0.6) :
                    isSelected     ? Color.accentColor.opacity(0.6) :
                                     Color.secondary.opacity(0.15),
                    lineWidth: (isSelected || isMultiSelected) ? 1 : 0.5
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .hoverPreview(for: item)
        .contextMenu {
            Button("Copy") { onCopy() }
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
        // 6.9 fix: .onTapGesture 替代 .gesture(TapGesture()),让任何内部 Button
        // (未来加 click-preview 时)能自然抢到 hit-test。
        .onTapGesture(count: 1) {
            if NSEvent.modifierFlags.contains(.command) {
                onToggleMulti()
            } else {
                onSelect()
            }
        }
        .onTapGesture(count: 2) { onActivate() }
    }

    private var copyButton: some View {
        HoverIconButton(
            systemName: "square.on.square",
            isActive: isSelected,
            isVisible: isHovered || isSelected,
            size: 18,
            activeTint: .accentColor,
            help: "Copy to clipboard"
        ) {
            onCopy()
            flashCopiedToast()
        }
    }

    private var copiedToast: some View {
        CopiedToast(compact: true)
            .padding(.top, 22)
    }

    private func flashCopiedToast() {
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    /// 6.7 favorite star button (small-size variant, uses accentColor)
    /// 6.8 起点击弹 FavoriteSheet 而非直接 toggle
    private var favoriteButton: some View {
        HoverIconButton(
            systemName: "star",
            activeSystemName: "star.fill",
            isActive: item.isFavorite,
            isVisible: item.isFavorite || isHovered,
            size: 18,
            activeTint: .accentColor,
            help: item.isFavorite ? "Edit Favorite" : "Add to Favorites"
        ) {
            onEditFavorite()
        }
    }

    /// 6.5 snippet bolt button (small-size variant)
    private var snippetButton: some View {
        HoverIconButton(
            systemName: "bolt",
            activeSystemName: "bolt.fill",
            isActive: item.isSnippet,
            isVisible: isHovered,
            size: 18,
            activeTint: .accentColor,
            help: item.isSnippet ? "Edit Snippet" : "Make this into a Snippet"
        ) {
            onMakeSnippet()
        }
    }

    @ViewBuilder
    private var content: some View {
        // 6.8 在 horizontal 卡片模式下:已收藏且填了 title 的项走专属布局,
        // 让 favorite 在 bento 卡阵中视觉上一眼可辨,而不是仅靠 ⭐ 图标。
        if let favTitle = favoriteTitleTrimmed {
            favoriteContent(title: favTitle)
        } else {
            defaultContent
        }
    }

    /// 6.8 收藏专属布局:大标题 + 内容截断 + 分类胶囊
    @ViewBuilder
    private func favoriteContent(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let subtitle = favoriteSubtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if let cat = item.favoriteCategory?.trimmingCharacters(in: .whitespaces),
               !cat.isEmpty {
                Text(cat)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.18))
                    )
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var favoriteTitleTrimmed: String? {
        guard let t = item.favoriteTitle?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }

    private var favoriteSubtitle: String? {
        switch item.contentType {
        case .text, .snippet:
            return (item.textContent ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        case .link:
            return item.linkHost ?? item.textContent
        case .file:
            return URL(fileURLWithPath: item.textContent ?? "").lastPathComponent
        case .image:
            return nil
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        switch item.contentType {
        case .image:
            VStack(alignment: .leading, spacing: 6) {
                ThumbnailView(data: item.thumbnailData, size: 80)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(item.textContent ?? "Image")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        case .text:
            Text(item.textContent ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .link:
            VStack(alignment: .leading, spacing: 4) {
                // Large linkTitle (if we scraped it)
                if let title = item.linkTitle {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                // Small gray linkHost or URL
                Text(item.linkHost ?? item.textContent ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                // Bottom hint
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                        .font(.system(size: 9))
                    Text("Double-click to open in browser")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        case .file:
            VStack(alignment: .leading, spacing: 6) {
                FileIconView(path: item.textContent ?? "", size: 56)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(URL(fileURLWithPath: item.textContent ?? "").lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(URL(fileURLWithPath: item.textContent ?? "").deletingLastPathComponent().path)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9))
                    Text("Double-click to reveal in Finder")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        case .snippet:
            VStack(alignment: .leading, spacing: 6) {
                if let trigger = item.triggerWord {
                    Text("/\(trigger)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                }
                Text(item.textContent ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.circle")
                        .font(.system(size: 9))
                    Text("Used \(item.usageCount) times")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var typeIcon: String {
        switch item.contentType {
        case .text:    return "text.alignleft"
        case .image:   return "photo"
        case .link:    return "link"
        case .file:    return "doc"
        case .snippet: return "text.book.closed"
        }
    }

    private var typeLabel: String {
        switch item.contentType {
        case .text:    return "Text"
        case .image:   return "Image"
        case .link:    return "Link"
        case .file:    return "File"
        case .snippet: return "Snippet"
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
