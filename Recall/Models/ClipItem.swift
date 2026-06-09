import Foundation
import SwiftData

/// SwiftData entity.
/// - Does not store raw image Data; only the thumbnail and the original's
///   relative path
/// - createdAt is indexed for time-based cleanup
/// - contentHash is used for deduplication
@Model
final class ClipItem {
    @Attribute(.unique) var id: UUID

    var createdAt: Date

    var contentTypeRaw: String

    /// Used for text / link. For link type, this field holds URL.absoluteString.
    var textContent: String?

    /// Link type: fetched page title (async)
    var linkTitle: String?
    /// Link type: hostname
    var linkHost: String?

    /// Image type: thumbnail JPEG Data
    var thumbnailData: Data?

    /// Image type: original filename under imageDirectory
    var imageRelativePath: String?

    // Do not mark .unique—duplicate contentHash happens often (the clipboard
    // poll writes the same content many times), and SwiftData **crashes**
    // (fatalError) on insert with a duplicate .unique value.
    // Use a plain indexed property instead; the upsert path in ClipStore
    // dedupes manually.
    var contentHash: String

    // 6.5 snippet fields
    var isSnippet: Bool = false
    /// Trigger word: when the user types `tt` + space, Recall auto-replaces
    /// it with `textContent`.
    var triggerWord: String?
    /// Snippet usage count
    var usageCount: Int = 0

    // 6.7 favorite field
    /// Favorited items are exempt from retention cleanup and are quickly
    /// reachable via the favorites entry.
    var isFavorite: Bool = false

    /// 6.8 收藏元数据：用户自定义标题。仅在 isFavorite == true 时有意义；nil 表示
    /// 用户使用了快速收藏（未填弹框），UI 自行 fallback 到 textContent / linkTitle。
    var favoriteTitle: String? = nil
    /// 6.8 收藏元数据：用户分类（自由文本，单选）。nil 视为"未分类"。
    /// 不抽独立 @Model：保持 SwiftData schema 简单；已有分类直接从所有 favorite item
    /// 的 distinct(favoriteCategory) 推导。
    var favoriteCategory: String? = nil

    var contentType: ClipContentType {
        isSnippet ? .snippet : (ClipContentType(rawValue: contentTypeRaw) ?? .text)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        contentType: ClipContentType,
        textContent: String? = nil,
        linkTitle: String? = nil,
        linkHost: String? = nil,
        thumbnailData: Data? = nil,
        imageRelativePath: String? = nil,
        contentHash: String,
        isSnippet: Bool = false,
        triggerWord: String? = nil,
        isFavorite: Bool = false,
        favoriteTitle: String? = nil,
        favoriteCategory: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentTypeRaw = contentType.rawValue
        self.textContent = textContent
        self.linkTitle = linkTitle
        self.linkHost = linkHost
        self.thumbnailData = thumbnailData
        self.imageRelativePath = imageRelativePath
        self.contentHash = contentHash
        self.isSnippet = isSnippet
        self.triggerWord = triggerWord
        self.isFavorite = isFavorite
        self.favoriteTitle = favoriteTitle
        self.favoriteCategory = favoriteCategory
    }
}
