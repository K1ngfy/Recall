import XCTest
@testable import Recall

/// `SnippetService.matchTrigger` 的回归测试。
///
/// 覆盖：
/// - trigger 长度边界（3-20 字符）
/// - 字符集白名单（[a-z0-9_-]）
/// - 大小写不敏感
/// - 末尾空白（空格 / 换行 / tab）容忍
/// - 跨类型 snippet 过滤（只匹配 isSnippet=true 的项）
/// - 多个 snippet 中取第一个 trigger 命中的
@MainActor
final class SnippetServiceTests: XCTestCase {

    // MARK: - Fixtures

    private func makeItem(id: UUID = UUID(), trigger: String?, isSnippet: Bool = true) -> ClipItemViewData {
        ClipItemViewData(
            id: id,
            createdAt: .now,
            contentType: isSnippet ? .snippet : .text,
            textContent: "snippet body for \(trigger ?? "nil")",
            linkTitle: nil,
            linkHost: nil,
            thumbnailData: nil,
            imageRelativePath: nil,
            contentHash: "hash-\(trigger ?? "nil")",
            isSnippet: isSnippet,
            triggerWord: trigger,
            usageCount: 0,
            isFavorite: false,
            favoriteTitle: nil,
            favoriteCategory: nil
        )
    }

    // MARK: - Length boundaries

    func test_tooShort_returnsNil() {
        // 1 字符：低于 2 下限
        let items = [makeItem(trigger: "a")]
        XCTAssertNil(SnippetService.matchTrigger(in: "a ", allItems: items))
    }

    func test_minLength_two_accepts() {
        // 2 字符：6.5 起的下界，保留 6.7 升级兼容性
        let items = [makeItem(trigger: "ab")]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "ab ", allItems: items))
    }

    func test_maxLength_thirtyTwo_accepts() {
        let items = [makeItem(trigger: String(repeating: "a", count: 32))]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "\(String(repeating: "a", count: 32)) ", allItems: items))
    }

    func test_tooLong_returnsNil() {
        // 33 字符：超出 32 上限
        let items = [makeItem(trigger: String(repeating: "a", count: 33))]
        XCTAssertNil(SnippetService.matchTrigger(in: "\(String(repeating: "a", count: 33)) ", allItems: items))
    }

    // MARK: - Character set whitelist

    func test_lettersDigitsUnderscoreDash_accepted() {
        let items = [makeItem(trigger: "tt_2024")]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "tt_2024 ", allItems: items))
    }

    func test_dot_rejected() {
        let items = [makeItem(trigger: "a.b")]
        XCTAssertNil(SnippetService.matchTrigger(in: "a.b ", allItems: items))
    }

    func test_unicode_rejected() {
        // 中文 / emoji 不在白名单内
        let items = [makeItem(trigger: "签名")]
        XCTAssertNil(SnippetService.matchTrigger(in: "签名 ", allItems: items))
    }

    func test_uppercase_normalized() {
        // 触发词统一 lowercase 后比较
        let items = [makeItem(trigger: "tt")]
        let result = SnippetService.matchTrigger(in: "TT ", allItems: items)
        XCTAssertEqual(result?.triggerWord, "tt")
    }

    // MARK: - Trailing whitespace tolerance

    func test_trailingSpace_matches() {
        let items = [makeItem(trigger: "tt")]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "tt ", allItems: items))
    }

    func test_trailingNewline_matches() {
        let items = [makeItem(trigger: "tt")]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "tt\n", allItems: items))
    }

    func test_trailingTab_matches() {
        let items = [makeItem(trigger: "tt")]
        XCTAssertNotNil(SnippetService.matchTrigger(in: "tt\t", allItems: items))
    }

    // MARK: - Item filtering

    func test_nonSnippetItemIgnored() {
        // isSnippet=false 的项即便 triggerWord 相同也不命中
        let items = [makeItem(trigger: "tt", isSnippet: false)]
        XCTAssertNil(SnippetService.matchTrigger(in: "tt ", allItems: items))
    }

    func test_emptyItems_returnsNil() {
        XCTAssertNil(SnippetService.matchTrigger(in: "tt ", allItems: []))
    }

    func test_mixedItems_picksFirstMatch() {
        let id1 = UUID()
        let id2 = UUID()
        let items = [
            makeItem(id: id1, trigger: "first"),
            makeItem(id: id2, trigger: "second"),
        ]
        let result = SnippetService.matchTrigger(in: "second ", allItems: items)
        XCTAssertEqual(result?.id, id2)
    }

    // MARK: - Empty / boundary inputs

    func test_emptyText_returnsNil() {
        let items = [makeItem(trigger: "tt")]
        XCTAssertNil(SnippetService.matchTrigger(in: "", allItems: items))
    }

    func test_whitespaceOnlyText_returnsNil() {
        let items = [makeItem(trigger: "tt")]
        XCTAssertNil(SnippetService.matchTrigger(in: "   \n\t  ", allItems: items))
    }

    func test_noTrailingTrigger_returnsNil() {
        // "hello world" 末尾没有触发词
        let items = [makeItem(trigger: "tt")]
        XCTAssertNil(SnippetService.matchTrigger(in: "hello world", allItems: items))
    }
}
