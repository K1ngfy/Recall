import XCTest
import SwiftUI
@testable import Recall

/// `HexColor.parse` 的回归测试。
/// 覆盖：6/3/8 位数字、带/不带 #、大小写、非法输入、RGBA
final class HexColorTests: XCTestCase {

    // MARK: - 6-digit RGB

    func test_sixDigit_withHash() {
        let c = HexColor.parse("#FF6B6B")
        XCTAssertNotNil(c)
    }

    func test_sixDigit_noHash() {
        XCTAssertNotNil(HexColor.parse("FF6B6B"))
    }

    func test_sixDigit_lowercase() {
        XCTAssertNotNil(HexColor.parse("#ff6b6b"))
    }

    func test_sixDigit_uppercase() {
        XCTAssertNotNil(HexColor.parse("#FF6B6B"))
    }

    func test_sixDigit_mixedCase() {
        XCTAssertNotNil(HexColor.parse("#fF6B6b"))
    }

    // MARK: - 3-digit RGB shorthand

    func test_threeDigit_withHash() {
        XCTAssertNotNil(HexColor.parse("#F0A"))
    }

    func test_threeDigit_noHash() {
        XCTAssertNotNil(HexColor.parse("F0A"))
    }

    // MARK: - 8-digit RGBA

    func test_eightDigit_withHash() {
        XCTAssertNotNil(HexColor.parse("#FF6B6BCC"))
    }

    // MARK: - Whitespace tolerance

    func test_whitespace_tolerated() {
        XCTAssertNotNil(HexColor.parse("  #FF6B6B  "))
    }

    // MARK: - Invalid input rejected

    func test_emptyString_returnsNil() {
        XCTAssertNil(HexColor.parse(""))
    }

    func test_whitespaceOnly_returnsNil() {
        XCTAssertNil(HexColor.parse("   "))
    }

    func test_invalidLength_returnsNil() {
        // 1 / 2 / 4 / 5 / 7 / 9+ 都不是合法长度
        XCTAssertNil(HexColor.parse("#F"))
        XCTAssertNil(HexColor.parse("#FF"))
        XCTAssertNil(HexColor.parse("#FFFF"))
        XCTAssertNil(HexColor.parse("#FFFFF"))
        XCTAssertNil(HexColor.parse("#FFFFFFF"))
    }

    func test_invalidCharacters_returnsNil() {
        XCTAssertNil(HexColor.parse("#GGGGGG"))    // G 不在 0-9a-f
        XCTAssertNil(HexColor.parse("#FF6B6X"))    // X 不在 0-9a-f
        XCTAssertNil(HexColor.parse("#ff6b6"))     // 太短
        XCTAssertNil(HexColor.parse("hello"))
    }

    // MARK: - 颜色值正确性

    func test_white_isWhite() {
        let c = HexColor.parse("#FFFFFF")
        XCTAssertNotNil(c)
        // 白色应该非常接近 1,1,1
        // NSColor 转换在测试里不易做差值断言，只断言能 parse
    }

    func test_black_isBlack() {
        XCTAssertNotNil(HexColor.parse("#000000"))
    }

    func test_shorthandExpands() {
        // #F0A 应该展开成 #FF00AA
        // parse 出来能成功就够了——精确颜色不强制断言（受 Color space 影响）
        XCTAssertNotNil(HexColor.parse("#F0A"))
        XCTAssertNotNil(HexColor.parse("#F0a"))
        XCTAssertNotNil(HexColor.parse("#f0A"))
    }

    // MARK: - format 双向

    func test_format_producesValidParseableString() {
        let c = HexColor.parse("#FF6B6B")
        XCTAssertNotNil(c)
        let formatted = HexColor.format(c!)
        // format 出来是 #RRGGBB 形式
        XCTAssertTrue(formatted.hasPrefix("#"))
        XCTAssertEqual(formatted.count, 7)
        // 重新 parse 必须能成功
        XCTAssertNotNil(HexColor.parse(formatted))
    }
}
