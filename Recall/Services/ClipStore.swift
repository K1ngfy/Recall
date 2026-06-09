import Foundation
import SwiftData

/// SwiftData write wrapper. Sync writes run on @MainActor; async tasks can
/// use a detached Task.
@MainActor
final class ClipStore {
    /// Posted after a write. ListViewModel observes it to refresh the list.
    static let didChangeNotification = Notification.Name("ClipStore.didChange")

    private let container: ModelContainer
    var context: ModelContext { container.mainContext }

    /// Safe query entry point for ViewModels
    func fetchAll<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    static let shared = ClipStore()

    private init() {
        self.container = RecallStoreSchema.makeContainer()
        // Run a cleanup pass on launch
        cleanupByRetention()
        // Run cleanup once per hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupByRetention()
            }
        }
    }

    /// Persist a Builder result. Returns whether a new item was actually
    /// created (false means a dedup hit).
    @discardableResult
    func upsert(_ result: ClipItemBuilder.Result) -> Bool {
        let hash = result.contentHash
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.createdAt = .now
            do {
                try context.save()
            } catch {
                AppLog.store.error("upsert (dedup) save failed: \(error.localizedDescription, privacy: .public)")
            }
            return false
        }

        let item: ClipItem
        let imageData: Data?
        let imageFilename: String?
        let needsBackgroundThumb: Bool

        switch result.type {
        case .image:
            guard let image = result.imageOriginal,
                  let tiff = image.tiffRepresentation else {
                return false
            }
            let filename = "\(hash).png"
            imageData = tiff
            imageFilename = filename
            // Large images (>1MB) generate the thumbnail asynchronously;
            // the main thread does not block.
            if tiff.count > 1_000_000 {
                needsBackgroundThumb = true
                item = ClipItem(
                    contentType: .image,
                    thumbnailData: nil,    // placeholder
                    imageRelativePath: filename,
                    contentHash: hash
                )
            } else {
                needsBackgroundThumb = false
                let thumb = Thumbnail.makeSync(from: image)
                item = ClipItem(
                    contentType: .image,
                    thumbnailData: thumb,
                    imageRelativePath: filename,
                    contentHash: hash
                )
            }
        case .text:
            imageData = nil
            imageFilename = nil
            needsBackgroundThumb = false
            item = ClipItem(
                contentType: .text,
                textContent: result.textContent,
                contentHash: hash
            )
        case .link:
            imageData = nil
            imageFilename = nil
            needsBackgroundThumb = false
            item = ClipItem(
                contentType: .link,
                textContent: result.textContent,
                linkHost: URL(string: result.textContent ?? "")?.host,
                contentHash: hash
            )
        case .file:
            // File path is stored in textContent; imageRelativePath stays empty.
            imageData = nil
            imageFilename = nil
            needsBackgroundThumb = false
            item = ClipItem(
                contentType: .file,
                textContent: result.textContent,
                contentHash: hash
            )
        case .snippet:
            // Snippets are not auto-created from the clipboard; the user
            // explicitly promotes them in the UI.
            return false
        }

        // Wrap insert + save in do/catch so a failure does not leave dirty
        // data in the context.
        do {
            context.insert(item)
            try context.save()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)

            // 6.7 privacy: after every write, re-apply exclude-from-backup
            // and FileProtection xattr to store + shm + wal files.
            // SQLite WAL mode may discard and recreate -wal / -shm at
            // checkpoint, so we re-tag at the end of every upsert to make
            // sure new files also carry the attributes.
            ClipStorageLocation.reapplyStoreXattr()

            // Note: link type does not fetch title / favicon / OpenGraph.
            // Product requires Recall to make zero network requests—all
            // display info (host, URL) is parsed locally from textContent;
            // no outbound request is made.
            // linkTitle is kept for future manual annotation; model migration
            // does not drop it.

            // Generate thumbnail / write original image asynchronously
            if needsBackgroundThumb, let tiff = imageData, let filename = imageFilename {
                let itemID = item.id
                Task.detached(priority: .utility) {
                    let thumb = await ImageThumbnailActor.shared.makeThumbnail(tiff: tiff)
                    _ = await ImageThumbnailActor.shared.writeOriginal(tiff: tiff, filename: filename)
                    await MainActor.run {
                        let d = FetchDescriptor<ClipItem>(
                            predicate: #Predicate { $0.id == itemID }
                        )
                        if let it = (try? ClipStore.shared.context.fetch(d))?.first,
                           let thumb {
                            it.thumbnailData = thumb
                            do {
                                try ClipStore.shared.context.save()
                            } catch {
                                AppLog.store.error("background thumb save failed: \(error.localizedDescription, privacy: .public)")
                            }
                            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
                        }
                    }
                }
            }
            return true
        } catch {
            context.delete(item)
            AppLog.store.error("insert failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Remove expired items per the retention setting.
    /// - Skips isFavorite (user-pinned) and isSnippet (named quick-text); both
    ///   are treated as long-lived assets.
    func cleanupByRetention() {
        let seconds = RetentionOption.load().seconds
        guard seconds != nil else { return }     // "forever" skips cleanup
        let cutoff = Date.now.addingTimeInterval(-seconds!)
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate {
                $0.createdAt < cutoff && !$0.isFavorite && !$0.isSnippet
            }
        )
        guard let expired = try? context.fetch(descriptor), !expired.isEmpty else { return }

        // Delete database rows
        for item in expired {
            // Synchronously delete the original image on disk
            if let path = item.imageRelativePath {
                let url = ClipStorageLocation.imageDirectory.appendingPathComponent(path)
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(item)
        }
        do {
            try context.save()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        } catch {
            AppLog.store.error("cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 6.7 favorite toggle:仅翻转 isFavorite,**保留** favoriteTitle / favoriteCategory。
    /// 6.8 此前会清空 metadata,但 contextMenu 的"Remove from Favorites"是快速误触路径,
    /// 静默销毁用户填的标题/分类是数据丢失 bug。改为保留——再次收藏时弹框可继续编辑。
    func toggleFavorite(_ id: UUID) {
        guard let item = SwiftDataFetch.firstByID(
            ClipItem.self, keyPath: \.id, id: id, in: context
        ) else { return }
        item.isFavorite.toggle()
        // 不再清空 favoriteTitle / favoriteCategory:用户填写的元数据应跨"取消-再收藏"循环保留
        do {
            try context.save()
        } catch {
            AppLog.store.error("toggleFavorite save failed: \(error.localizedDescription, privacy: .public)")
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 6.8 显式收藏:写入用户指定的 title + category(任一可空),
    /// 同时把 isFavorite 标 true。用于 FavoriteSheet 的「Save」路径。
    /// - Parameters:
    ///   - title: 用户填的标题,空白被规范为 nil
    ///   - category: 用户填的分类,空白被规范为 nil;trim 后区分大小写保留原样
    func setFavorite(id: UUID, title: String?, category: String?) {
        guard let item = SwiftDataFetch.firstByID(
            ClipItem.self, keyPath: \.id, id: id, in: context
        ) else { return }
        item.isFavorite = true
        item.favoriteTitle = normalize(title)
        item.favoriteCategory = normalize(category)
        do {
            try context.save()
        } catch {
            AppLog.store.error("setFavorite save failed: \(error.localizedDescription, privacy: .public)")
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 6.8 取消收藏:仅置 isFavorite=false,**保留** favoriteTitle / favoriteCategory,
    /// 让"再次收藏"能恢复上次的标题与分类。用于 FavoriteSheet 的「Remove」路径。
    /// 真正想销毁元数据请用 setFavorite(id:, title: nil, category: nil)（明确意图）。
    func unfavorite(_ id: UUID) {
        guard let item = SwiftDataFetch.firstByID(
            ClipItem.self, keyPath: \.id, id: id, in: context
        ) else { return }
        item.isFavorite = false
        // 不清空 favoriteTitle / favoriteCategory:见 toggleFavorite 注释
        do {
            try context.save()
        } catch {
            AppLog.store.error("unfavorite save failed: \(error.localizedDescription, privacy: .public)")
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 6.8 已有分类列表：当前所有 isFavorite item 的 distinct favoriteCategory，
    /// 用于 sheet 的 autocomplete 与 chips 的标签列表。已按字母升序排列。
    func allFavoriteCategories() -> [String] {
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.isFavorite == true }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let names = items.compactMap { $0.favoriteCategory }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// trim + 空串归一为 nil
    private func normalize(_ s: String?) -> String? {
        guard let s else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 6.8 一键清空:删除所有 ClipItem + 外置图片文件。
    /// 包括收藏、Snippets,无差别清除。调用方必须先做 UI 二次确认。
    /// 返回被删除的条目数,供 UI toast 反馈。
    @discardableResult
    func wipeAll() -> Int {
        let descriptor = FetchDescriptor<ClipItem>()
        guard let items = try? context.fetch(descriptor) else { return 0 }
        let count = items.count

        // 同步删外置图片(数据库记录之外的副作用文件)
        for item in items {
            if let path = item.imageRelativePath {
                let url = ClipStorageLocation.imageDirectory.appendingPathComponent(path)
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(item)
        }
        do {
            try context.save()
            AppLog.store.info("wipeAll removed \(count, privacy: .public) items")
        } catch {
            AppLog.store.error("wipeAll save failed: \(error.localizedDescription, privacy: .public)")
        }

        // 兜底:把 Images 目录里残留的"孤儿 PNG"也清掉(以防数据库与磁盘漂移)。
        // 6.8 fix:**只删 Recall 写入模式的文件**(*.png 且是 regular file),
        // 跳过子目录 / .DS_Store / 用户或将来其他功能放入的文件,避免数据丢失。
        if let leftovers = try? FileManager.default.contentsOfDirectory(
            at: ClipStorageLocation.imageDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) {
            for url in leftovers {
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                guard url.pathExtension.lowercased() == "png" else { continue }
                try? FileManager.default.removeItem(at: url)
            }
        }

        // 6.8 fix:作废 SnippetService 的 5 秒缓存,避免清空后短窗口内
        // 触发词仍能匹配到已删除的 snippet 并粘贴幽灵内容。
        SnippetService.invalidateCache()

        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return count
    }
}
