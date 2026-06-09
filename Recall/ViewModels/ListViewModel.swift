import Foundation
import SwiftUI
import SwiftData
import AppKit
import Observation

/// "Value type" snapshot of list items. SwiftUI doesn't need to repeatedly go through SwiftData @Model's KVO bridge when rebuilding inside a LazyVStack.
struct ClipItemViewData: Identifiable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    let contentType: ClipContentType
    let textContent: String?
    let linkTitle: String?
    let linkHost: String?
    let thumbnailData: Data?
    let imageRelativePath: String?
    let contentHash: String
    let isSnippet: Bool
    let triggerWord: String?
    let usageCount: Int
    let isFavorite: Bool
    /// 6.8 用户为收藏项填的标题；nil = 未填，UI 自行 fallback。
    let favoriteTitle: String?
    /// 6.8 用户为收藏项填的分类；nil = 未分类。
    let favoriteCategory: String?
}

/// List ViewModel:
/// - Observes ClipStore change notifications, triggers async refresh.
/// - Exposes category-filtered items.
/// - Handles the "copy back to clipboard" action.
@MainActor
@Observable
final class ListViewModel {

    enum Filter: Hashable, Identifiable {
        case all
        case category(ClipContentType)
        case favorites

        var id: String {
            switch self {
            case .all: return "all"
            case .category(let t): return t.rawValue
            case .favorites: return "favorites"
            }
        }

        var displayName: String {
            switch self {
            case .all: return Strings.Tab.all
            case .category(let t): return t.localizedDisplayName
            case .favorites: return Strings.Tab.favorites
            }
        }

        var symbolName: String {
            switch self {
            case .all: return "tray.full"
            case .category(let t): return t.iconName
            case .favorites: return "star.fill"
            }
        }
    }

    private(set) var items: [ClipItemViewData] = []
    var filter: Filter = .all {
        didSet {
            applyFilter()
        }
    }
    var searchText: String = "" {
        didSet {
            if oldValue != searchText {
                applyFilter()
            }
        }
    }

    // MARK: 6.4 Advanced search

    /// Date range filter.
    enum DateRange: String, CaseIterable, Identifiable, Codable {
        case anytime, today, week, month
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .anytime: return Strings.DateRange.anytime
            case .today:   return Strings.DateRange.today
            case .week:    return Strings.DateRange.pastWeek
            case .month:   return Strings.DateRange.pastMonth
            }
        }
    }
    var dateRange: DateRange = .anytime {
        didSet { if oldValue != dateRange { applyFilter() } }
    }

    // MARK: 6.8 Favorite category filter

    /// 收藏分类筛选条件。只在 filter == .favorites 时生效；切到其他 filter 时
    /// 不重置（用户来回切 tab 时保持选择），但 chips 自身只在 favorites tab 渲染。
    enum FavoriteCategoryFilter: Equatable, Hashable {
        case all
        case uncategorized
        case named(String)

        /// chips 复用 Identifiable 时的稳定 id
        var id: String {
            switch self {
            case .all: return "__all__"
            case .uncategorized: return "__none__"
            case .named(let n): return "n:\(n)"
            }
        }
    }
    var favoriteCategoryFilter: FavoriteCategoryFilter = .all {
        didSet { if oldValue != favoriteCategoryFilter { applyFilter() } }
    }

    /// 当前所有收藏项的分类标签（去重 + 字母升序）。供 chips 渲染。
    var availableFavoriteCategories: [String] {
        let names = allItems
            .filter { $0.isFavorite }
            .compactMap { $0.favoriteCategory }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// 收藏项里是否存在"未分类"的项。chips 用它决定要不要渲染 Uncategorized 标签。
    var hasUncategorizedFavorites: Bool {
        allItems.contains { $0.isFavorite && ($0.favoriteCategory?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }
    }

    /// Multi-select.
    var selectedIDs: Set<UUID> = []

    /// 6.5 Snippet list.
    var snippets: [ClipItemViewData] = []

    func loadSnippets() {
        snippets = SnippetService.allSnippets()
            .sorted { $0.usageCount > $1.usageCount }
    }

    func deleteSnippets(_ ids: Set<UUID>) {
        for id in ids {
            if let snippet = snippets.first(where: { $0.id == id }) {
                SnippetService.demoteFromSnippet(snippet)
            }
        }
        loadSnippets()
    }

    /// All entries (unfiltered), used as the source data for refresh.
    private var allItems: [ClipItemViewData] = []

    private nonisolated(unsafe) var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: ClipStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Already on the main queue.
            self?.refresh()
        }
    }

    deinit {
        if let o = observer { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Public

    func refresh() {
        let descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = (try? ClipStore.shared.fetchAll(descriptor)) ?? []
        allItems = models.map { model in
            ClipItemViewData(
                id: model.id,
                createdAt: model.createdAt,
                contentType: model.contentType,
                textContent: model.textContent,
                linkTitle: model.linkTitle,
                linkHost: model.linkHost,
                thumbnailData: model.thumbnailData,
                imageRelativePath: model.imageRelativePath,
                contentHash: model.contentHash,
                isSnippet: model.isSnippet,
                triggerWord: model.triggerWord,
                usageCount: model.usageCount,
                isFavorite: model.isFavorite,
                favoriteTitle: model.favoriteTitle,
                favoriteCategory: model.favoriteCategory
            )
        }

        // 6.8 fix:multi-select 残留 id 清理。store 被外部清空(wipeAll / 批量删除 /
        // retention cleanup)后,selectedIDs 里可能残留已经不存在的 UUID,导致
        // BatchActionBar 计数虚高、selectAll/clearSelection 操作幽灵条目。
        // 与最新 id 集求交,保证 selectedIDs 永远是 allItems 的子集。
        if !selectedIDs.isEmpty {
            let validIDs = Set(allItems.map { $0.id })
            selectedIDs.formIntersection(validIDs)
        }

        applyFilter()
    }

    /// Filtered current list.
    var filteredItems: [ClipItemViewData] { items }

    /// Copy back to system clipboard on click (does not simulate paste).
    func copyToPasteboard(_ item: ClipItemViewData) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.contentType {
        case .text, .link, .snippet:
            if let s = item.textContent {
                pb.setString(s, forType: .string)
            }
        case .image:
            if let path = item.imageRelativePath {
                let url = ClipStorageLocation.imageDirectory.appendingPathComponent(path)
                if let data = try? Data(contentsOf: url) {
                    // Use NSPasteboardItem + setData to write PNG/TIFF data directly,
                    // avoiding NSImage NSSecureCoding warnings.
                    let item = NSPasteboardItem()
                    item.setData(data, forType: .png)
                    pb.writeObjects([item])
                }
            }
        case .file:
            // Write file URL — Finder / most apps can get the file reference directly when pasting.
            if let path = item.textContent {
                pb.writeObjects([URL(fileURLWithPath: path) as NSURL])
            }
        }
    }

    /// Double-click / Enter → copy + auto-paste at the current cursor.
    /// Text / link go through PasteService; images / files are only copied to the clipboard.
    /// Double-clicking a file additionally triggers "open with default app" (pasting into Finder is meaningless).
    func activateAndPaste(_ item: ClipItemViewData) {
        switch item.contentType {
        case .text, .link, .snippet:
            if let s = item.textContent {
                _ = PasteService.shared.paste(text: s, hidePanelAfter: true)
            }
        case .image:
            copyToPasteboard(item)
        case .file:
            copyToPasteboard(item)
            if let path = item.textContent {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        }
    }

    /// Copy only (no auto-paste), used for the copy button.
    func copyOnly(_ item: ClipItemViewData) {
        copyToPasteboard(item)
    }

    // MARK: - 6.6 Batch operations

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    func selectAll() {
        selectedIDs = Set(filteredItems.map { $0.id })
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    /// Batch copy (join multiple lines with \n; skip file category, don't mix into text).
    func copyBatch() {
        let items = filteredItems.filter { selectedIDs.contains($0.id) }
        guard !items.isEmpty else { return }
        let combined = items
            .compactMap { item -> String? in
                switch item.contentType {
                case .text, .link, .snippet: return item.textContent
                case .image, .file: return nil
                }
            }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)
        AppLog.paste.info("Batch copied \(items.count) items, \(combined.count) chars")
    }

    /// Batch delete.
    func deleteBatch() {
        let ids = selectedIDs
        let descriptor = FetchDescriptor<ClipItem>()
        guard let models = try? ClipStore.shared.context.fetch(descriptor) else { return }
        let toDelete = models.filter { ids.contains($0.id) }
        for m in toDelete {
            if let path = m.imageRelativePath {
                let url = ClipStorageLocation.imageDirectory.appendingPathComponent(path)
                try? FileManager.default.removeItem(at: url)
            }
            ClipStore.shared.context.delete(m)
        }
        do {
            try ClipStore.shared.context.save()
        } catch {
            AppLog.store.error("batch delete save failed: \(error.localizedDescription, privacy: .public)")
        }
        clearSelection()
        NotificationCenter.default.post(name: ClipStore.didChangeNotification, object: nil)
    }

    // MARK: - Private

    private func applyFilter() {
        var source = allItems

        // Category filter.
        switch filter {
        case .all: break
        case .category(let t): source = source.filter { $0.contentType == t }
        case .favorites:
            source = source.filter { $0.isFavorite }
            // 6.8 在 favorites 分支下再叠一层分类筛选
            switch favoriteCategoryFilter {
            case .all: break
            case .uncategorized:
                source = source.filter {
                    ($0.favoriteCategory?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
                }
            case .named(let name):
                let target = name.trimmingCharacters(in: .whitespaces)
                source = source.filter {
                    ($0.favoriteCategory?.trimmingCharacters(in: .whitespaces)) == target
                }
            }
        }

        // Date range filter.
        if let cutoff = dateRange.cutoffDate {
            source = source.filter { $0.createdAt >= cutoff }
        }

        // Search (fuzzy match: substring hit on any of textContent / linkTitle / linkHost).
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            source = source.filter { item in
                let candidates: [String?] = [
                    item.textContent,
                    item.linkTitle,
                    item.linkHost,
                    // File type: textContent is a path; searching by file name should also match.
                    (item.contentType == .file) ? URL(fileURLWithPath: item.textContent ?? "").lastPathComponent : nil
                ]
                return candidates.contains { ($0 ?? "").lowercased().contains(q) }
            }
        }

        items = source
    }
}

// MARK: - 6.4 DateRange

extension ListViewModel.DateRange {
    /// Corresponding cutoff time; nil = no limit.
    var cutoffDate: Date? {
        let now = Date()
        switch self {
        case .anytime: return nil
        case .today:   return Calendar.current.startOfDay(for: now)
        case .week:    return now.addingTimeInterval(-7 * 86_400)
        case .month:   return now.addingTimeInterval(-30 * 86_400)
        }
    }
}
