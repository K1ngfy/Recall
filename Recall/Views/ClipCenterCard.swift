import SwiftUI

/// 6.8 center 模式专用卡片。
///
/// 与 ClipRow / ClipCard 的关系:
/// - ClipRow:左右侧栏窄面板的紧凑单行(36pt 缩略图 + 双行文本)
/// - ClipCard:top/bottom 横向 bento 的迷你卡(160×170)
/// - ClipCenterCard:**center 大面板专用** —— 双列网格里的"舒展卡片"
///   面板宽 ~900pt → 每列 ~430pt,卡片高 160-180pt,
///   利用横向空间让缩略图、标题、内容、元数据各占其位。
///
/// 视觉差异化:
/// - 收藏项加 accent 边框 + 顶部 ★ 浮标 + 底部分类胶囊
/// - 图片走整卡缩略图大图模式;其他类型走"左缩略图 + 右文本"双栏
struct ClipCenterCard: View {
    let item: ClipItemViewData
    let isSelected: Bool
    let isMultiSelected: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onMakeSnippet: () -> Void
    let onEditFavorite: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleMulti: () -> Void

    @State private var isHovered = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            mainContent
            Spacer(minLength: 2)
            footer
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 104)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            // 收藏项右上角 star 浮标(无论 hover 都显示)
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
            }
        }
        .overlay(alignment: .center) {
            if showCopiedToast {
                CopiedToast(compact: false)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .hoverPreview(for: item)
        .contextMenu { contextMenuItems }
        // 6.9 fix: .onTapGesture 替代 .gesture(TapGesture()),让内部 Button
        // (leading icon 包的 click-preview 触发器)的 hit-test 自然胜出。
        .onTapGesture(count: 1) {
            if NSEvent.modifierFlags.contains(.command) {
                onToggleMulti()
            } else {
                onSelect()
            }
        }
        .onTapGesture(count: 2) { onActivate() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            // Multi-select checkbox(hover 时出现,多选态常驻)
            Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: isMultiSelected ? .semibold : .regular))
                .foregroundStyle(isMultiSelected ? Color.accentColor : .secondary)
                .opacity(isMultiSelected || isHovered ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onToggleMulti() }

            Image(systemName: typeIcon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected || isMultiSelected ? Color.accentColor : .secondary)
            Text(typeLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected || isMultiSelected ? Color.accentColor : .secondary)

            Spacer()

            Text(relativeTimeString(from: item.createdAt))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            // 6.8 ★ 浮标已在右上角,这里不再重复
            if item.contentType == .text || item.contentType == .snippet {
                snippetButton
            }
            favoriteButton
            copyButton
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        switch item.contentType {
        case .image:
            imageContent
        default:
            // 通用"缩略图/图标 + 右文本"双栏
            HStack(alignment: .top, spacing: 10) {
                // 6.9 左侧 icon 点击 → 切换预览(独立于 Settings 的 hover 开关)
                Button {
                    PreviewCoordinator.shared.toggle(item)
                } label: {
                    leadingThumb
                }
                .buttonStyle(.plain)
                .help("Show preview")
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryText)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    if let body = secondaryText {
                        Text(body)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    /// image:整张卡片以大缩略图为主体,标题压在缩略图下方
    private var imageContent: some View {
        HStack(spacing: 10) {
            // 6.9 图片缩略图点击 → 切换预览
            Button {
                PreviewCoordinator.shared.toggle(item)
            } label: {
                ThumbnailView(data: item.thumbnailData, size: 56)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Show preview")
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text(item.contentHash.prefix(12))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// 左侧 44pt 缩略图/图标块
    @ViewBuilder
    private var leadingThumb: some View {
        switch item.contentType {
        case .text:
            iconBubble("text.alignleft", accent: false)
        case .link:
            linkBadge
        case .file:
            FileIconView(path: item.textContent ?? "", size: 36)
                .frame(width: 44, height: 44)
        case .snippet:
            iconBubble("text.book.closed", accent: true)
        case .image:
            EmptyView()    // image 走 imageContent
        }
    }

    /// 链接:首字母圆形 badge
    private var linkBadge: some View {
        let letter = (item.linkTitle ?? item.linkHost ?? item.textContent ?? "?")
            .trimmingCharacters(in: .whitespaces)
            .prefix(1)
            .uppercased()
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
            Text(String(letter))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private func iconBubble(_ symbol: String, accent: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(accent ? Color.accentColor : .secondary)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 6) {
            if let cat = item.favoriteCategory?.trimmingCharacters(in: .whitespaces),
               !cat.isEmpty {
                Text(cat)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
            }
            if item.usageCount > 0 {
                Label("\(item.usageCount)×", systemImage: "arrow.up.left.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
        }
    }

    // MARK: - Background / border

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isMultiSelected ? Color.accentColor.opacity(0.18) :
                isSelected     ? Color.accentColor.opacity(0.12) :
                isHovered      ? Color.primary.opacity(0.07) :
                                 Color.primary.opacity(0.04)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isMultiSelected || isSelected ? Color.accentColor.opacity(0.5)
                : item.isFavorite             ? Color.accentColor.opacity(0.35)
                                              : Color.secondary.opacity(0.15),
                lineWidth: (isSelected || isMultiSelected || item.isFavorite) ? 1 : 0.5
            )
    }

    // MARK: - Buttons

    private var copyButton: some View {
        HoverIconButton(
            systemName: "square.on.square",
            isVisible: true,
            size: 18,
            activeTint: .secondary,
            help: "Copy to clipboard"
        ) {
            onCopy()
            flashCopiedToast()
        }
    }

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

    private func flashCopiedToast() {
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
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

    // MARK: - Text helpers

    private var primaryText: String {
        // 收藏项已填 title → 主标题用 title
        if let t = item.favoriteTitle?.trimmingCharacters(in: .whitespaces), !t.isEmpty {
            return t
        }
        switch item.contentType {
        case .text:
            return (item.textContent ?? "")
                .replacingOccurrences(of: "\n", with: " ")
        case .link:
            return item.linkTitle ?? item.linkHost
                ?? (item.textContent ?? "").replacingOccurrences(of: "\n", with: " ")
        case .image:
            return "Image"
        case .file:
            return URL(fileURLWithPath: item.textContent ?? "").lastPathComponent
        case .snippet:
            let trigger = item.triggerWord.map { "/\($0)" } ?? ""
            return "\(trigger) \(item.textContent ?? "")".trimmingCharacters(in: .whitespaces)
        }
    }

    private var secondaryText: String? {
        // 收藏项 title 占了主行 → 副行展示内容预览
        let isFavoriteWithTitle = !((item.favoriteTitle ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
        switch item.contentType {
        case .text, .snippet:
            if isFavoriteWithTitle {
                return item.textContent?.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            // 非收藏:主行已经是内容,不再重复
            return nil
        case .link:
            return item.linkHost ?? item.textContent
        case .file:
            return URL(fileURLWithPath: item.textContent ?? "")
                .deletingLastPathComponent().path
        case .image:
            return nil
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
        if interval < 60   { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
