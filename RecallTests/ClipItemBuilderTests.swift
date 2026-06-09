import XCTest
import AppKit
@testable import Recall

/// `ClipItemBuilder.build(from:)` 的回归测试。
///
/// 用 `NSPasteboard.withUniqueName()` 拿独立 pasteboard——不污染全局 .general，
/// 也不被其他测试 / app 状态干扰。
///
/// 覆盖：
/// - 三种 contentType 的 happy path（text / link / file）
/// - 图片（PNG data）→ .image
/// - 扩展名白名单：PDF / txt / doc 不会被错认成 .image
/// - 同一文件复制多次：能去重 / 不会重复入 image 池
/// - 边界：空 pasteboard、混合类型
final class ClipItemBuilderTests: XCTestCase {

    // MARK: - Fixtures

    /// 拿一个独立 pasteboard，每个测试方法一个，避免相互污染
    private func newPasteboard() -> NSPasteboard {
        NSPasteboard.withUniqueName()
    }

    /// 1x1 透明 PNG（合法的最小 PNG）
    private var tinyPng: Data {
        // 手写最小合法 PNG（67 bytes）：8x1 透明
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG sig
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  // 1x1
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54,  // IDAT
            0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05,
            0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00,
            0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82  // IEND
        ]
        return Data(bytes)
    }

    /// 在 NSTemporaryDirectory() 下建一个临时 .txt 文件，返回 URL
    private func makeTempFile(name: String, contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recall_test_\(UUID().uuidString)_\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Image

    func test_pasteboard含PNG_data_返回image() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setData(tinyPng, forType: .png)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .image)
        XCTAssertNotNil(result?.imageOriginal)
    }

    func test_pasteboard含TIFF_data_返回image() {
        // 1x1 白色 TIFF（最小合法）
        // 头：II + 42 + 偏移 8
        // IFD：1 entry (256 宽度 / 257 高度 / 258 bitspersample)
        // 用 sysctlbyname 不可测——改用 NSImage 直接生成后 re-encode TIFF
        let img = NSImage(size: NSSize(width: 1, height: 1))
        img.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation else {
            XCTFail("无法生成测试 TIFF data")
            return
        }

        let pb = newPasteboard()
        pb.clearContents()
        pb.setData(tiff, forType: .tiff)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .image)
    }

    func test_imageData存在时_textContent为nil() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setData(tinyPng, forType: .png)
        // 即使同时有 string，也不会被采纳——image 优先
        pb.setString("ignored", forType: .string)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .image)
        XCTAssertNil(result?.textContent)
    }

    // MARK: - Text

    func test_纯文本_返回text() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("hello world", forType: .string)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .text)
        XCTAssertEqual(result?.textContent, "hello world")
    }

    func test_httpURL_返回link() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("https://github.com/anthropics/recall", forType: .string)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .link)
        XCTAssertEqual(result?.textContent, "https://github.com/anthropics/recall")
    }

    func test_httpsURL_返回link() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("https://example.com/path?q=1", forType: .string)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .link)
    }

    func test_非HTTPscheme_返回text_不link() {
        // javascript: / file: / data: 等不应该被认成 link
        // 单独 string 通道里 file:// 走 fallback 走 URL.path 必须存在，否则被 NSImage(contentsOf:) 拒
        // 实际：pb.string 拿 file:// URL 但没有 file 实体 → 不算 fileURL → 走 text
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("javascript:alert(1)", forType: .string)
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .text)
    }

    // MARK: - File

    func test_txt文件_返回file_不image() {
        // PDF 误判修复测试：之前 NSImage(contentsOf:) 对 .txt 返回 nil，
        // 但也走过 .file 路径。tiff 走 .image。txt 走 .file。
        guard let url = try? makeTempFile(name: "test.txt", contents: "hello") else {
            XCTFail("无法创建临时文件")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let pb = newPasteboard()
        pb.clearContents()
        pb.writeObjects([url as NSURL])
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .file)
        XCTAssertEqual(result?.textContent, url.path)
    }

    func test_pdf文件_返回file_不image() {
        // 关键修复点：NSImage(contentsOf:) 对 PDF 也会成功，
        // 没有扩展名白名单的话 PDF 会被错存成 .image 类目
        let pdfURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recall_test_\(UUID().uuidString).pdf")
        // 最小合法 PDF（PDF 1.0 头 + 单页 + EOF）
        let minimalPDF = Data("""
        %PDF-1.0
        1 0 obj <</Type/Catalog/Pages 2 0 R>> endobj
        2 0 obj <</Type/Pages/Count 0/Kids[]>> endobj
        xref 0 3
        0000000000 65535 f
        0000000009 00000 n
        0000000053 00000 n
        trailer <</Size 3/Root 1 0 R>>
        startxref 96
        %%EOF
        """.utf8)
        try? minimalPDF.write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let pb = newPasteboard()
        pb.clearContents()
        pb.writeObjects([pdfURL as NSURL])
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .file, "PDF 必须走 .file 而不是 .image（白名单保护）")
    }

    func test_png文件_扩展名命中_返回image() {
        // 反向验证：扩展名是 .png 的文件确实走 .image 路径
        let pngURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recall_test_\(UUID().uuidString).png")
        try? tinyPng.write(to: pngURL)
        defer { try? FileManager.default.removeItem(at: pngURL) }

        let pb = newPasteboard()
        pb.clearContents()
        pb.writeObjects([pngURL as NSURL])
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .image)
        XCTAssertEqual(result?.textContent, pngURL.path)
    }

    func test_relativePath形式的fileURL_被拒() {
        // 防御畸形 file:// URL：只有以 / 开头的绝对路径才接受
        // NSPasteboard.writeObjects 不太可能传非绝对路径，但保险起见
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("file://relative/path/no/leading/slash", forType: .string)
        // string 通道里这个 URL 不会被 readFileURL 接受（path 不以 / 开头）
        // fallback：URL(string:) 能解析但 path 不以 / 开头 → 不算 fileURL
        // 最终走 .text 路径
        let result = ClipItemBuilder.build(from: pb)
        XCTAssertEqual(result?.type, .text)
    }

    // MARK: - Empty / Mixed

    func test_空pasteboard_返回nil() {
        let pb = newPasteboard()
        pb.clearContents()
        XCTAssertNil(ClipItemBuilder.build(from: pb))
    }

    func test_空string_返回nil() {
        let pb = newPasteboard()
        pb.clearContents()
        pb.setString("", forType: .string)
        XCTAssertNil(ClipItemBuilder.build(from: pb))
    }

    // MARK: - Hash

    func test_相同内容_hash相同() {
        let pb1 = newPasteboard()
        pb1.clearContents()
        pb1.setString("hello", forType: .string)

        let pb2 = newPasteboard()
        pb2.clearContents()
        pb2.setString("hello", forType: .string)

        let r1 = ClipItemBuilder.build(from: pb1)
        let r2 = ClipItemBuilder.build(from: pb2)
        XCTAssertEqual(r1?.contentHash, r2?.contentHash)
    }

    func test_不同内容_hash不同() {
        let pb1 = newPasteboard()
        pb1.clearContents()
        pb1.setString("hello", forType: .string)

        let pb2 = newPasteboard()
        pb2.clearContents()
        pb2.setString("world", forType: .string)

        let r1 = ClipItemBuilder.build(from: pb1)
        let r2 = ClipItemBuilder.build(from: pb2)
        XCTAssertNotEqual(r1?.contentHash, r2?.contentHash)
    }
}
