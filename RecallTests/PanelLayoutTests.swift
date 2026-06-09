import XCTest
import AppKit
@testable import Recall

/// `PanelLayout.frameAdjacent` 的回归测试。
///
/// 测的是「弹窗怎么贴 anchor 摆放」的几何正确性——所有几何都从 visibleFrame
/// 推导，所以只要 anchor + screen 这两个 NSRect 输入覆盖，函数本身是纯计算可测。
///
/// 覆盖：
/// - 4 个停靠方向：左右两侧空间足够时优先水平
/// - 单侧能塞下 / 两侧都能塞下时的选择策略
/// - 垂直方向兜底：水平塞不下时上下
/// - 全部塞不下：屏内居中
/// - clamp 行为：超出屏内安全区时夹回
/// - alignTop 顶边对齐
@MainActor
final class PanelLayoutTests: XCTestCase {

    // MARK: - Fixtures

    /// 模拟一个 1440x900 屏，左下原点 (0, 0)
    private var fakeScreen: NSScreen { NSScreen.main! }

    /// 让 anchor 居中放 800x600 屏中央
    private var anchorCentered: NSRect {
        let s = fakeScreen.visibleFrame
        return NSRect(
            x: s.midX - 200, y: s.midY - 300,
            width: 400, height: 600
        )
    }

    /// anchor 贴屏右边缘——左侧有大空间，右侧无空间
    private var anchorRightEdge: NSRect {
        let s = fakeScreen.visibleFrame
        return NSRect(
            x: s.maxX - 400 - PanelLayout.edgeInset,
            y: s.midY - 300,
            width: 400, height: 600
        )
    }

    /// anchor 贴屏左边缘——右侧有大空间，左侧无空间
    private var anchorLeftEdge: NSRect {
        let s = fakeScreen.visibleFrame
        return NSRect(
            x: s.minX + PanelLayout.edgeInset,
            y: s.midY - 300,
            width: 400, height: 600
        )
    }

    // MARK: - Horizontal placement

    func test_两侧足够时_选空间更大一侧() {
        // anchor 居中放置时左右空间差不多
        let r = PanelLayout.frameAdjacent(
            to: anchorCentered,
            on: fakeScreen,
            size: NSSize(width: 200, height: 200),
            alignTop: false
        )
        // 选中的那一侧必然满足"anchor + popoverGap + size"的几何关系
        // 由于左右空间相等，函数选第一个匹配的分支——断言"r 不和 anchor 相交"
        XCTAssertFalse(r.intersects(anchorCentered))
        XCTAssertTrue(fakeScreen.visibleFrame.contains(r))
    }

    func test_anchor贴右边缘_弹窗放左侧() {
        // anchor 右边没有 gap，必须放左边
        let r = PanelLayout.frameAdjacent(
            to: anchorRightEdge,
            on: fakeScreen,
            size: NSSize(width: 200, height: 200),
            alignTop: false
        )
        // 弹窗右边 = anchor 左 x - popoverGap
        let expectedRightX = anchorRightEdge.minX - PanelLayout.popoverGap
        XCTAssertEqual(r.maxX, expectedRightX, accuracy: 0.5)
    }

    func test_anchor贴左边缘_弹窗放右侧() {
        // anchor 左边没有 gap，必须放右边
        let r = PanelLayout.frameAdjacent(
            to: anchorLeftEdge,
            on: fakeScreen,
            size: NSSize(width: 200, height: 200),
            alignTop: false
        )
        let expectedLeftX = anchorLeftEdge.maxX + PanelLayout.popoverGap
        XCTAssertEqual(r.minX, expectedLeftX, accuracy: 0.5)
    }

    // MARK: - alignTop

    func test_alignTop_top对齐到anchor顶边() {
        let r = PanelLayout.frameAdjacent(
            to: anchorRightEdge,
            on: fakeScreen,
            size: NSSize(width: 200, height: 200),
            alignTop: true
        )
        // 顶边对齐：弹窗 maxY = anchor maxY
        XCTAssertEqual(r.maxY, anchorRightEdge.maxY, accuracy: 0.5)
    }

    func test_default居中对齐() {
        let r = PanelLayout.frameAdjacent(
            to: anchorRightEdge,
            on: fakeScreen,
            size: NSSize(width: 200, height: 200),
            alignTop: false
        )
        // 默认居中：弹窗 midY = anchor midY
        XCTAssertEqual(r.midY, anchorRightEdge.midY, accuracy: 0.5)
    }

    // MARK: - Vertical fallback

    func test_水平塞不下时退到垂直方向() {
        // 构造 anchor 贴屏右 + 紧贴屏顶——左侧 + 上方都无空间
        // 但至少下方有空间
        let s = fakeScreen.visibleFrame
        let bigAnchor = NSRect(
            x: s.maxX - 400, y: s.midY - 50,  // 紧贴屏右
            width: 400, height: s.height * 0.6  // 占了屏高 60%
        )
        // 给一个塞不下水平空间的尺寸（要求 width > 左侧空间）
        let leftSpace = bigAnchor.minX - s.minX - PanelLayout.popoverGap
        let tooWide = NSSize(width: leftSpace + 50, height: 200)
        let r = PanelLayout.frameAdjacent(to: bigAnchor, on: fakeScreen, size: tooWide)
        // 水平塞不下，应该尝试垂直；如果垂直也不行，兜底居中
        // 这里验证返回的 frame 一定在 visibleFrame 内
        XCTAssertTrue(s.contains(r))
        // 弹窗不与 anchor 相交
        XCTAssertFalse(r.intersects(bigAnchor))
    }

    // MARK: - Edge clamping

    func test_clamp到屏安全区内() {
        // 模拟一种会触发 clamp 的情形：构造 anchor 偏左下，给一个正常尺寸
        let s = fakeScreen.visibleFrame
        let anchor = NSRect(
            x: s.minX + PanelLayout.edgeInset,
            y: s.minY + PanelLayout.verticalInset,
            width: 200, height: 200
        )
        // 弹窗要放 anchor 右侧、顶对齐——但 size + gap 可能让弹窗超出右边界
        let bigSize = NSSize(
            width: s.width - 100,  // 几乎占满屏宽
            height: 200
        )
        let r = PanelLayout.frameAdjacent(
            to: anchor, on: fakeScreen, size: bigSize, alignTop: true
        )
        // clamp 后应该完全在 visibleFrame 内
        XCTAssertTrue(s.contains(r))
    }

    // MARK: - Size clamping

    func test_超大size被夹到屏内() {
        // 测 size 比屏还大时会不会撑爆
        let r = PanelLayout.frameAdjacent(
            to: anchorCentered,
            on: fakeScreen,
            size: NSSize(width: 99999, height: 99999)
        )
        XCTAssertTrue(fakeScreen.visibleFrame.contains(r))
        XCTAssertLessThanOrEqual(r.width, fakeScreen.visibleFrame.width)
    }

    // MARK: - Center dock

    /// .center 模式：computeFrame 应把面板放在 visibleFrame 几何中心
    func test_center_frame居中于屏可视区() {
        PanelLayout.markAppReady()
        let size = PanelLayout.computeSize(for: .center)
        let rect = PanelLayout.computeFrame(position: .center, size: size)
        let visible = fakeScreen.visibleFrame

        XCTAssertEqual(rect.midX, visible.midX, accuracy: 0.5)
        XCTAssertEqual(rect.midY, visible.midY, accuracy: 0.5)
        XCTAssertTrue(visible.contains(rect))
    }

    /// .center 模式：computeSize 走「16:9 + 屏面积 30%」算式
    func test_center_size_十六比九() {
        PanelLayout.markAppReady()
        let size = PanelLayout.computeSize(for: .center)
        let ratio = size.width / size.height
        // 16/9 ≈ 1.7778；允许 ±0.02 漂移（小屏 clamp 后保持比例）
        XCTAssertEqual(ratio, 16.0 / 9.0, accuracy: 0.02)
    }

    /// .center 模式：面板面积约等于屏可视区 30%（误差容忍 5pt²/㎡）
    func test_center_size_面积约30pct() {
        PanelLayout.markAppReady()
        let size = PanelLayout.computeSize(for: .center)
        let visible = fakeScreen.visibleFrame
        let actualRatio = (size.width * size.height) / (visible.width * visible.height)
        // 普通屏不触发 clamp,误差仅来自 sqrt 浮点;非常窄/扁屏被 clamp 时该测试不适用
        // 但 NSScreen.main 是合理屏,可信任。
        XCTAssertEqual(actualRatio, PanelLayout.centerAreaRatio, accuracy: 0.005)
    }

    /// .center 模式：animatedStartFrame 与终态帧相同,
    /// 入场仅由 alphaValue 0→1 承担,避免位置抖动
    func test_center_animatedStartFrame等于终态() {
        let target = NSRect(x: 100, y: 100, width: 480, height: 600)
        let start = PanelLayout.animatedStartFrame(from: target, position: .center)
        XCTAssertEqual(start, target)
    }
}
