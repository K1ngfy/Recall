import SwiftUI
import SwiftData

/// Recall main panel root view. HIG-style list + frosted glass + category tabs + search.
struct RecallRootView: View {
    @State private var viewModel = ListViewModel()
    @State private var selectedID: UUID?
    @State private var snippetSheetItem: ClipItemViewData?
    /// 6.8 收藏弹框触发态;item 非 nil 时弹 sheet
    @State private var favoriteSheetItem: ClipItemViewData?
    @State private var hotkeyConflictToast: HotkeyConflictToast?
    @FocusState private var searchFocused: Bool
    @Bindable private var theme = ThemeSettings.shared
    @Bindable private var permissions = PermissionCenter.shared
    // Before 6.7 we used @Environment(\.openSettings) bound to the SwiftUI Settings scene.
    // After removing the scene the env value no longer fires, so we switched to
    // a self-managed SettingsWindowController.
    // (Don't declare @Environment(\.openSettings) here — it would be misleading.)
    @AppStorage(UserDefaultsKeys.Panel.dockPosition) private var dockPositionRaw: String = PanelDockPosition.right.rawValue
    @AppStorage(UserDefaultsKeys.Panel.pinned) private var isPinned: Bool = false

    /// Observes when the global hotkey is taken by another app — shows a one-shot toast that auto-dismisses after 5s.
    private let hotkeyConflictObserver = HotkeyConflictObserver()

    private var dockPosition: PanelDockPosition {
        PanelDockPosition(rawValue: dockPositionRaw) ?? .right
    }

    private var isHorizontal: Bool {
        dockPosition.isHorizontal
    }

    /// 6.8 收藏分类条是否要渲染（有分类或有未分类的收藏才有意义）
    private var showFavoriteChips: Bool {
        !viewModel.availableFavoriteCategories.isEmpty || viewModel.hasUncategorizedFavorites
    }

    var body: some View {
        Group {
            panelContent
        }
        .tint(theme.resolvedAccentColor)
        .preferredColorScheme(theme.forcedScheme.colorScheme)
        .onAppear {
            permissions.refreshAll()
            hotkeyConflictObserver.attach(to: $hotkeyConflictToast)
        }
        .overlay(alignment: .bottom) {
            if let toast = hotkeyConflictToast {
                HotkeyConflictToastView(toast: toast) {
                    SettingsWindowController.shared.show()
                    hotkeyConflictToast = nil
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: hotkeyConflictToast)
        .onChange(of: isPinned) { _, newValue in
            if let panel = AppEnvironment.shared.recallPanel, panel.isVisible {
                NotificationCenter.default.post(name: .recallPanelPinChanged, object: newValue)
            }
        }
        // Recompute panel size when the dock position changes (previous bug: dockPosition changed but panel size didn't).
        .onChange(of: dockPosition) { _, newValue in
            AppEnvironment.shared.panelController.setDockPosition(newValue)
        }
        .sheet(item: $snippetSheetItem) { item in
            SnippetTriggerSheet(item: item) {
                snippetSheetItem = nil
            }
        }
        .sheet(item: $favoriteSheetItem) { item in
            FavoriteSheet(
                item: item,
                existingCategories: viewModel.availableFavoriteCategories
            ) {
                favoriteSheetItem = nil
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        ZStack {
            // Self-drawn background: follows ThemeSettings theme switching (system / aurora / sunset / ...).
            // Opacity is multiplied onto the layer via .opacity.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.resolvedBackgroundStyle())

            // Fallback: 4% primary in both light and dark — guarantees minimum readability in both modes
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))

            // 1px hairline border to strengthen the edge
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)

            VStack(spacing: 0) {
                header
                if !viewModel.selectedIDs.isEmpty {
                    BatchActionBar(viewModel: viewModel)
                }
                // In horizontal mode, if BatchActionBar is already attached in the header area
                // (wide screen for top/bottom dock), checking it again here would duplicate it —
                // leave that to BatchActionBar itself.
                PermissionBanner(permissions: permissions)
                // Top/bottom dock: date chips merge into the header (more compact)
                // Left/right dock: date chips get their own row (user preference: time above type)
                if !isHorizontal {
                    DateFilterChips(selection: $viewModel.dateRange)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }
                CategoryTabs(selection: $viewModel.filter, compact: !isHorizontal)
                    .padding(.horizontal, 14)
                    // In side mode leave an 8pt gap between the two rows so they don't touch;
                    // in horizontal mode keep separation from the header/banner.
                    .padding(.top, isHorizontal ? 10 : 8)
                    .padding(.bottom, 8)
                // 6.8 收藏分类标签条:仅在 favorites tab 且存在分类/未分类时显示
                if viewModel.filter == .favorites,
                   showFavoriteChips {
                    FavoriteCategoryChips(
                        selection: $viewModel.favoriteCategoryFilter,
                        categories: viewModel.availableFavoriteCategories,
                        hasUncategorized: viewModel.hasUncategorizedFavorites
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                content
                    .frame(maxHeight: .infinity)
            }
        }
        // Important: don't set maxWidth/.infinity — let SwiftUI use panel.lockedSize as the intrinsic size.
        // Previously, .frame(maxWidth: .infinity) made the SwiftUI contentView stretch to the screen width,
        // which made NSHostingView internally blow up the panel's physical frame.
        .frame(maxHeight: nil)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            brandMark
            SearchField(
                text: $viewModel.searchText,
                isFocused: $searchFocused,
                matchCount: viewModel.filteredItems.count
            )
            // In top/bottom dock, put the date chips on the same row as the search field
            if isHorizontal {
                DateFilterChips(selection: $viewModel.dateRange)
                    .fixedSize()
            }
            countBadge
            snippetsManagerButton
            pinButton
            settingsButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var snippetsManagerButton: some View {
        HoverIconButton(
            systemName: "text.book.closed",
            isVisible: true,
            size: 22,
            activeTint: .secondary,
            help: "Manage Snippets"
        ) {
            SnippetsController.shared.show(viewModel: viewModel)
        }
    }

    private var pinButton: some View {
        HoverIconButton(
            systemName: "pin",
            activeSystemName: "pin.fill",
            isActive: isPinned,
            isVisible: true,
            size: 22,
            activeTint: .accentColor,
            help: isPinned ? "Unpin (panel will close on outside click)" : "Pin panel open"
        ) {
            isPinned.toggle()
        }
    }

    private var brandMark: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.accentColor)
            Text(Strings.appName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var settingsButton: some View {
        HoverIconButton(
            systemName: "gearshape",
            isVisible: true,
            size: 22,
            activeTint: .secondary,
            help: Strings.Panel.settings
        ) {
            // 6.7 switch to a self-managed NSWindow: SwiftUI's @Environment(\.openSettings)
            // is bound to the Settings scene; once the scene is removed that env value no longer fires.
            // Just call the controller directly.
            SettingsWindowController.shared.show()
        }
    }

    private var countBadge: some View {
        Text("\(viewModel.filteredItems.count)")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .monospacedDigit()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.filteredItems.isEmpty {
            emptyState
        } else {
            if isHorizontal {
                horizontalContent
            } else if dockPosition == .center {
                centerContent
            } else {
                verticalContent
            }
        }
    }

    /// top/bottom dock:横向 bento 卡阵
    private var horizontalContent: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    ClipCard(
                        item: item,
                        isSelected: item.id == selectedID,
                        isMultiSelected: viewModel.selectedIDs.contains(item.id),
                        onSelect: { selectedID = item.id },
                        onActivate: {
                            selectedID = item.id
                            viewModel.activateAndPaste(item)
                        },
                        onCopy: {
                            selectedID = item.id
                            viewModel.copyOnly(item)
                        },
                        onMakeSnippet: {
                            selectedID = item.id
                            snippetSheetItem = item
                        },
                        onEditFavorite: {
                            selectedID = item.id
                            favoriteSheetItem = item
                        },
                        onToggleFavorite: {
                            ClipStore.shared.toggleFavorite(item.id)
                        },
                        onToggleMulti: {
                            viewModel.toggleSelection(item.id)
                        }
                    )
                    .id(item.id)
                }
                Color.clear.frame(width: 20, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity)
        .frame(height: nil)
    }

    /// 6.8 center dock:双列大卡片网格(利用 ~900pt 大宽度)
    private var centerContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(viewModel.filteredItems) { item in
                    ClipCenterCard(
                        item: item,
                        isSelected: item.id == selectedID,
                        isMultiSelected: viewModel.selectedIDs.contains(item.id),
                        onSelect: { selectedID = item.id },
                        onActivate: {
                            selectedID = item.id
                            viewModel.activateAndPaste(item)
                        },
                        onCopy: {
                            selectedID = item.id
                            viewModel.copyOnly(item)
                        },
                        onMakeSnippet: {
                            selectedID = item.id
                            snippetSheetItem = item
                        },
                        onEditFavorite: {
                            selectedID = item.id
                            favoriteSheetItem = item
                        },
                        onToggleFavorite: {
                            ClipStore.shared.toggleFavorite(item.id)
                        },
                        onToggleMulti: {
                            viewModel.toggleSelection(item.id)
                        }
                    )
                    .id(item.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
    }

    /// left/right dock:窄面板单列 row
    private var verticalContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.filteredItems) { item in
                    ClipRow(
                        item: item,
                        isSelected: item.id == selectedID,
                        isMultiSelected: viewModel.selectedIDs.contains(item.id),
                        onSelect: {
                            selectedID = item.id
                        },
                        onActivate: {
                            selectedID = item.id
                            viewModel.activateAndPaste(item)
                        },
                        onCopy: {
                            selectedID = item.id
                            viewModel.copyOnly(item)
                        },
                        onToggleMulti: {
                            viewModel.toggleSelection(item.id)
                        },
                        onMakeSnippet: {
                            selectedID = item.id
                            snippetSheetItem = item
                        },
                        onEditFavorite: {
                            selectedID = item.id
                            favoriteSheetItem = item
                        },
                        onToggleFavorite: {
                            ClipStore.shared.toggleFavorite(item.id)
                        }
                    )
                    .id(item.id)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        let kind: EmptyStateView.Kind = {
            if !viewModel.searchText.isEmpty {
                return .noSearchResults(query: viewModel.searchText)
            }
            switch viewModel.filter {
            case .all:
                return .noHistory
            case .favorites:
                return .noFavorites
            case .category(let t):
                return .noCategory(t)
            }
        }()
        return EmptyStateView(kind: kind)
    }

    private var filterCategory: ClipContentType? {
        switch viewModel.filter {
        case .all, .favorites: return nil
        case .category(let t): return t
        }
    }
}
