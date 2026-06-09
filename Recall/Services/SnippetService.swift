import Foundation
import SwiftData

/// 6.5 Snippet service: trigger-word matching + usage count increment
@MainActor
enum SnippetService {
    /// Called on hit: increment usageCount + write back to SwiftData
    static func recordUsage(_ item: ClipItemViewData) {
        update(itemID: item.id) { $0.usageCount += 1 }
    }

    /// 6.5 trigger-word matching: when the user copies "tt ", return the
    /// matching snippet.
    /// Match rule: the copied string ends with "trigger " or "trigger\n" or
    /// "trigger\t".
    /// - trigger length 2-32 (preserves backward compatibility from 6.5:
    ///   existing triggers like "tt" / "hi" keep working)
    /// - trigger charset [a-z0-9_-] (prevents false hits from odd unicode /
    ///   punctuation)
    static func matchTrigger(in text: String, allItems: [ClipItemViewData]) -> ClipItemViewData? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trigger = trimmed.replacingOccurrences(of: " ", with: "").lowercased()
        guard trigger.count >= 2, trigger.count <= 32 else { return nil }
        // Charset whitelist—avoid false hits from odd unicode / punctuation.
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "_-"))
        guard trigger.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return allItems.first { item in
            guard item.isSnippet else { return false }
            return item.triggerWord?.lowercased() == trigger
        }
    }

    /// Cache all snippets—for fast lookup during the pasteboard tick.
    private static var cache: [ClipItemViewData] = []
    private static var cacheTime: Date = .distantPast

    /// 6.8 给外部写入路径(如 ClipStore.wipeAll / 批量删除)的缓存失效入口。
    /// 不直接清 cache 数组——下次 allSnippets() 调用会因 cacheTime 过期而自然重建。
    static func invalidateCache() {
        cacheTime = .distantPast
    }

    static func allSnippets() -> [ClipItemViewData] {
        if Date.now.timeIntervalSince(cacheTime) < 5 { return cache }
        // SwiftData #Predicate on macOS 26 has limited support for bool
        // fields, so fall back to in-memory filtering: fetch all and filter.
        let descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = (try? ClipStore.shared.context.fetch(descriptor)) ?? []
        cache = models
            .filter { $0.isSnippet }
            .map { model in
                ClipItemViewData(
                    id: model.id,
                    createdAt: model.createdAt,
                    contentType: .snippet,
                    textContent: model.textContent,
                    linkTitle: nil, linkHost: nil,
                    thumbnailData: nil, imageRelativePath: nil,
                    contentHash: model.contentHash,
                    isSnippet: true,
                    triggerWord: model.triggerWord,
                    usageCount: model.usageCount,
                    isFavorite: model.isFavorite,
                    favoriteTitle: model.favoriteTitle,
                    favoriteCategory: model.favoriteCategory
                )
            }
        cacheTime = .now
        return cache
    }

    /// Create a snippet: promote the currently selected ClipItem to a snippet.
    static func promoteToSnippet(_ item: ClipItemViewData, trigger: String) {
        update(itemID: item.id) { model in
            model.isSnippet = true
            model.triggerWord = trigger
        }
    }

    /// Remove snippet status
    static func demoteFromSnippet(_ item: ClipItemViewData) {
        update(itemID: item.id) { model in
            model.isSnippet = false
            model.triggerWord = nil
        }
    }

    /// Generic helper: fetch by id + mutate + save + invalidate cache
    private static func update(itemID: UUID, _ mutate: (ClipItem) -> Void) {
        guard let target = SwiftDataFetch.firstByID(
            ClipItem.self, keyPath: \.id, id: itemID,
            in: ClipStore.shared.context
        ) else { return }
        mutate(target)
        do {
            try ClipStore.shared.context.save()
        } catch {
            AppLog.store.error("SnippetService save failed: \(error.localizedDescription, privacy: .public)")
        }
        // Invalidate the cache after writing so the next allSnippets() returns fresh data.
        cacheTime = .distantPast
        NotificationCenter.default.post(name: ClipStore.didChangeNotification, object: nil)
    }
}
