import SwiftUI

/// 6.8 收藏弹框：填写标题 + 分类（自由文本，可从已有分类一键回填）。
///
/// 设计取舍：
/// - 分类用「TextField + 已有分类 chips」而非弹出式 picker——所有已有分类
///   直接可见，输入新分类即创建，避免 SwiftUI 在 macOS 上 ComboBox 缺位的问题。
/// - 标题为空时仍允许保存：UI 自动 fallback 到内容预览，符合"快速收藏"语义。
/// - 已收藏 → 编辑模式：左下角显示 Remove from Favorites；未收藏 → 创建模式。
struct FavoriteSheet: View {
    let item: ClipItemViewData
    /// 当前所有已存在的分类（来自 ListViewModel.availableFavoriteCategories）
    let existingCategories: [String]
    let onDismiss: () -> Void

    @State private var title: String
    @State private var category: String
    @State private var isCategoryPickerOpen = false
    private let isExistingFavorite: Bool

    init(
        item: ClipItemViewData,
        existingCategories: [String],
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.existingCategories = existingCategories
        self.onDismiss = onDismiss
        self._title    = State(initialValue: item.favoriteTitle ?? "")
        self._category = State(initialValue: item.favoriteCategory ?? "")
        self.isExistingFavorite = item.isFavorite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().opacity(0.3)

            titleField
            categoryField
            contentPreview

            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(isExistingFavorite
                 ? Strings.FavoriteSheet.editTitle
                 : Strings.FavoriteSheet.createTitle)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.FavoriteSheet.titleLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(Strings.FavoriteSheet.titlePlaceholder, text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .onSubmit(save)
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.FavoriteSheet.categoryLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            // TextField 内嵌一个下拉触发按钮:点击弹出 popover 显示已有分类列表;
            // popover 锚定到整行 bottom 边,确保从输入框正下方展开而不是从 chevron 飘到右侧屏外。
            HStack(spacing: 6) {
                TextField(Strings.FavoriteSheet.categoryPlaceholder, text: $category)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(save)
                Button {
                    isCategoryPickerOpen.toggle()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(existingCategories.isEmpty ? .tertiary : .secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(existingCategories.isEmpty)
                .help(existingCategories.isEmpty
                      ? Strings.FavoriteSheet.categoryHint
                      : Strings.FavoriteSheet.categoryPickHelp)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            // 关键:把 popover 挂在 HStack 整体上,锚点 = 整行 bounds,
            // arrowEdge = .top 让弹窗出现在 TextField 正下方居中
            .popover(
                isPresented: $isCategoryPickerOpen,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                categoryPickerPopover
            }

            if existingCategories.isEmpty {
                Text(Strings.FavoriteSheet.categoryHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 下拉项列表;独立 view 避免 popover closure 内嵌过深
    private var categoryPickerPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(existingCategories, id: \.self) { name in
                    Button {
                        category = name
                        isCategoryPickerOpen = false
                    } label: {
                        HStack {
                            Text(name)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                            Spacer()
                            if isCurrentCategory(name) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PickerRowButtonStyle())
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 240)
        .frame(maxHeight: 240)
    }

    private func isCurrentCategory(_ name: String) -> Bool {
        let trimmed = category.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
            && name.trimmingCharacters(in: .whitespaces)
                   .caseInsensitiveCompare(trimmed) == .orderedSame
    }

    // MARK: - Content preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.FavoriteSheet.contentPreview)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(previewText)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 90)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    private var previewText: String {
        switch item.contentType {
        case .text, .snippet:
            return item.textContent ?? ""
        case .link:
            return item.linkTitle.map { "\($0)\n\(item.textContent ?? "")" } ?? (item.textContent ?? "")
        case .image:
            return "Image · \(item.contentHash.prefix(8))"
        case .file:
            return item.textContent ?? ""
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if isExistingFavorite {
                Button(Strings.FavoriteSheet.remove, role: .destructive) {
                    ClipStore.shared.unfavorite(item.id)
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Button(Strings.FavoriteSheet.cancel) { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Button(isExistingFavorite
                   ? Strings.FavoriteSheet.save
                   : Strings.FavoriteSheet.create) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func save() {
        ClipStore.shared.setFavorite(
            id: item.id,
            title: title,
            category: category
        )
        onDismiss()
    }
}

/// popover 行 hover 高亮 — 仿 macOS NSMenu 风格(hover accent + 鼠标松开后立即触发动作)
private struct PickerRowButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color.accentColor.opacity(0.22)
                            : (isHovered ? Color.accentColor.opacity(0.14) : .clear)
                    )
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}
