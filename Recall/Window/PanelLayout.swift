import AppKit

/// Panel layout calculation: in-screen safe area, dock direction, clamp logic.
///
/// During early startup NSApp is not yet ready and NSEvent.mouseLocation is
/// NSPoint! — force-unwrapping nil will fatalError. Every method in this
/// module that needs NSApp state must first call the isReady guard.
enum PanelLayout {

    /// In-screen edge insets. verticalInset is 24pt—when docking at top/bottom
    /// this leaves 6pt of margin for the 18pt corner radius, otherwise the
    /// corners get clipped by the screen edge / menu bar / Dock and the panel
    /// looks like a sharp rectangle.
    static let edgeInset: CGFloat = 16
    static let verticalInset: CGFloat = 24

    /// Whether NSApp is ready. Returns false on the first ask (early startup);
    /// returns true from then on.
    @MainActor
    private static var _isAppReady = false
    @MainActor
    static var isAppReady: Bool { _isAppReady }

    /// Mark NSApp as ready. Call at the end of RecallApp.init or before the first show().
    @MainActor
    static func markAppReady() {
        _isAppReady = true
    }

    /// Resolve the "active screen"—in multi-screen setups this is where
    /// Recall appears.
    /// Priority:
    /// 1. The screen of the current key window (the app the user is using)
    /// 2. The screen the mouse is on (when there's no key window)
    /// 3. The main screen (the menu bar's screen; always present)
    @MainActor
    static func activeScreen() -> NSScreen? {
        // During early startup, fall back directly to the main screen—
        // avoids triggering NSEvent.mouseLocation force-unwrap.
        guard isAppReady else { return NSScreen.main }
        if let kwScreen = screenForKeyWindow() {
            return kwScreen
        }
        return screenForMouse() ?? NSScreen.main
    }

    /// The screen the mouse is on (fallback)
    @MainActor
    static func screenForMouse() -> NSScreen? {
        // NSEvent.mouseLocation is NSPoint!—force-unwrap during early
        // startup will fatalError.
        // Use objc perform to call the getter and avoid the compiler's
        // IUO warning.
        // Note: activeScreen() already guards with isAppReady; this is just
        // the last-resort fallback.
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }

    /// The screen of the current key window—only used during the show phase.
    @MainActor
    static func screenForKeyWindow() -> NSScreen? {
        guard let kw = NSApp.keyWindow else { return nil }
        return kw.screen
    }

    /// The screen's "safe visible frame": excludes menu bar + Dock.
    @MainActor
    static func safeVisibleFrame(of screen: NSScreen) -> NSRect {
        screen.visibleFrame
    }

    /// Compute panel size: stretch to screen width for top/bottom; fill
    /// screen height for left/right; for **center**, target a 16:9 panel
    /// occupying ~30% of the visible screen area (clamped into the safe
    /// area for tiny screens).
    /// - Important: calling this during early startup only uses the main
    ///   screen's size—full NSApp state is not required.
    @MainActor
    static func computeSize(for position: PanelDockPosition) -> NSSize {
        guard let screen = isAppReady ? activeScreen() : NSScreen.main else {
            return NSSize(width: 360, height: 520)
        }
        let visible = screen.visibleFrame

        if position.isHorizontal {
            return NSSize(
                width: visible.width - edgeInset * 2,
                height: position.defaultSize.height
            )
        } else if position == .center {
            // center 目标:16:9 比例,面板面积 = visible 面积 × 30%。
            // 设 W = 16k, H = 9k → 144 k² = 0.30 × visW × visH → k = √(...)
            // 这样在任何屏尺寸/纵横比下都能产出"屏中央的等比悬浮窗"。
            let targetArea = visible.width * visible.height * centerAreaRatio
            let k = (targetArea / 144).squareRoot()
            var w = 16 * k
            var h = 9 * k
            // 兜底:特别窄的竖屏 / 超扁屏可能算出超界,clamp 同时保 16:9
            let maxW = visible.width  - edgeInset * 2
            let maxH = visible.height - verticalInset * 2
            if w > maxW { w = maxW; h = w * 9 / 16 }
            if h > maxH { h = maxH; w = h * 16 / 9 }
            // 下限保护:小屏不至于缩到不可读
            w = max(320, w)
            h = max(180, h)
            return NSSize(width: w, height: h)
        } else {
            return NSSize(
                width: position.defaultSize.width,
                height: max(360, visible.height - verticalInset * 2)
            )
        }
    }

    /// center 模式面板的目标面积占可视屏的比例。改这里就改 center 的体型。
    static let centerAreaRatio: CGFloat = 0.30

    /// Pure-compute finalRect: combines the in-screen safe area, dock direction, and clamp.
    @MainActor
    static func computeFrame(position: PanelDockPosition, size: NSSize) -> NSRect {
        guard let screen = isAppReady ? activeScreen() : NSScreen.main else { return .zero }
        let visible = screen.visibleFrame

        // Step 1: clamp size into the safe area
        let maxW = max(240, visible.width - edgeInset * 2)
        let maxH = max(240, visible.height - verticalInset * 2)
        let finalSize = NSSize(
            width:  min(size.width,  maxW),
            height: min(size.height, maxH)
        )

        // Step 2: compute the ideal rect for the dock direction
        let idealRect: NSRect
        switch position {
        case .left:
            idealRect = NSRect(
                x: visible.minX + edgeInset,
                y: visible.midY - finalSize.height / 2,
                width: finalSize.width, height: finalSize.height
            )
        case .right:
            idealRect = NSRect(
                x: visible.maxX - finalSize.width - edgeInset,
                y: visible.midY - finalSize.height / 2,
                width: finalSize.width, height: finalSize.height
            )
        case .top:
            idealRect = NSRect(
                x: visible.midX - finalSize.width / 2,
                y: visible.maxY - finalSize.height - verticalInset,
                width: finalSize.width, height: finalSize.height
            )
        case .bottom:
            idealRect = NSRect(
                x: visible.midX - finalSize.width / 2,
                y: visible.minY + verticalInset,
                width: finalSize.width, height: finalSize.height
            )
        case .center:
            idealRect = NSRect(
                x: visible.midX - finalSize.width  / 2,
                y: visible.midY - finalSize.height / 2,
                width: finalSize.width, height: finalSize.height
            )
        }

        // Step 3: clamp Y
        let minY = visible.minY + verticalInset
        let maxY = visible.maxY - finalSize.height
        let clampedY = max(minY, min(idealRect.minY, maxY))

        return NSRect(
            x: idealRect.minX,
            y: clampedY,
            width: finalSize.width,
            height: finalSize.height
        )
    }

    /// Starting frame for slide-in / slide-out animation
    static func animatedStartFrame(from rect: NSRect, position: PanelDockPosition) -> NSRect {
        let offset: CGFloat = 40
        switch position {
        case .left:   return NSRect(x: rect.minX - offset, y: rect.minY, width: rect.width, height: rect.height)
        case .right:  return NSRect(x: rect.minX + offset, y: rect.minY, width: rect.width, height: rect.height)
        case .top:    return NSRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: rect.height)
        case .bottom: return NSRect(x: rect.minX, y: rect.minY - offset, width: rect.width, height: rect.height)
        case .center:
            // center 没有"从哪个方向滑入"，让起始帧 = 终态帧——
            // 由 alphaValue 0→1 单独承担入场动画，避免位置抖动。
            return rect
        }
    }

    /// Visual gap between popover and anchor (RecallPanel)
    static let popoverGap: CGFloat = 8

    /// Compute popover frame: prefer horizontal (attach to anchor's left /
    /// right), fall back to vertical (above / below) when there isn't enough
    /// room, and finally center on the anchor's screen when neither fits.
    /// - Parameters:
    ///   - anchor: panel frame the popover is attaching to
    ///   - screen: target screen
    ///   - size: target popover size
    ///   - alignTop: when placing on the left / right, whether to align the
    ///     top edges (true makes it look attached; recommended when docking
    ///     to a panel)
    @MainActor
    static func frameAdjacent(
        to anchor: NSRect,
        on screen: NSScreen,
        size: NSSize,
        alignTop: Bool = false
    ) -> NSRect {
        let visible = screen.visibleFrame

        // 1) Clamp size into the safe area
        let maxW = max(240, visible.width - edgeInset * 2)
        let maxH = max(240, visible.height - verticalInset * 2)
        let finalSize = NSSize(
            width:  min(size.width,  maxW),
            height: min(size.height, maxH)
        )

        // 2) Remaining space in each direction
        let leftSpace   = anchor.minX - visible.minX
        let rightSpace  = visible.maxX - anchor.maxX
        let topSpace    = visible.maxY - anchor.maxY
        let bottomSpace = anchor.minY - visible.minY

        // 3) Horizontal: pick the side with more room, only if it can fit
        let canLeft  = leftSpace  >= finalSize.width  + popoverGap
        let canRight = rightSpace >= finalSize.width  + popoverGap
        if canLeft && canRight {
            let rect = leftSpace >= rightSpace
                ? leftRect(of: anchor, size: finalSize, alignTop: alignTop)
                : rightRect(of: anchor, size: finalSize, alignTop: alignTop)
            return clamp(rect, in: visible)
        } else if canRight {
            return clamp(rightRect(of: anchor, size: finalSize, alignTop: alignTop), in: visible)
        } else if canLeft {
            return clamp(leftRect(of: anchor, size: finalSize, alignTop: alignTop), in: visible)
        }

        // 4) Vertical: above / below
        let canTop    = topSpace    >= finalSize.height + popoverGap
        let canBottom = bottomSpace >= finalSize.height + popoverGap
        if canTop && canBottom {
            let rect = topSpace >= bottomSpace ? topRect(of: anchor, size: finalSize) : bottomRect(of: anchor, size: finalSize)
            return clamp(rect, in: visible)
        } else if canBottom {
            return clamp(bottomRect(of: anchor, size: finalSize), in: visible)
        } else if canTop {
            return clamp(topRect(of: anchor, size: finalSize), in: visible)
        }

        // 5) Fallback: center on the screen
        return NSRect(
            x: visible.midX - finalSize.width  / 2,
            y: visible.midY - finalSize.height / 2,
            width:  finalSize.width,
            height: finalSize.height
        )
    }

    // MARK: - Candidate rects

    @MainActor
    private static func leftRect(of anchor: NSRect, size: NSSize, alignTop: Bool = false) -> NSRect {
        let y: CGFloat = alignTop ? anchor.maxY - size.height : anchor.midY - size.height / 2
        return NSRect(
            x: anchor.minX - popoverGap - size.width,
            y: y,
            width: size.width, height: size.height
        )
    }

    @MainActor
    private static func rightRect(of anchor: NSRect, size: NSSize, alignTop: Bool = false) -> NSRect {
        let y: CGFloat = alignTop ? anchor.maxY - size.height : anchor.midY - size.height / 2
        return NSRect(
            x: anchor.maxX + popoverGap,
            y: y,
            width: size.width, height: size.height
        )
    }

    @MainActor
    private static func topRect(of anchor: NSRect, size: NSSize) -> NSRect {
        NSRect(
            x: anchor.midX - size.width / 2,
            y: anchor.maxY + popoverGap,
            width: size.width, height: size.height
        )
    }

    @MainActor
    private static func bottomRect(of anchor: NSRect, size: NSSize) -> NSRect {
        NSRect(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - popoverGap - size.height,
            width: size.width, height: size.height
        )
    }

    /// Clamp rect into the visible frame (without changing its size).
    @MainActor
    private static func clamp(_ rect: NSRect, in visible: NSRect) -> NSRect {
        let minX = visible.minX + edgeInset
        let maxX = max(minX, visible.maxX - rect.width  - edgeInset)
        let minY = visible.minY + verticalInset
        let maxY = max(minY, visible.maxY - rect.height - verticalInset)
        return NSRect(
            x: min(max(rect.minX, minX), maxX),
            y: min(max(rect.minY, minY), maxY),
            width:  rect.width,
            height: rect.height
        )
    }
}
