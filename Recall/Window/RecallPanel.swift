import AppKit

/// Borderless, dockable, floating-level NSPanel.
///
/// Key design: use lockedSize to anchor the panel's size and a
/// NSWindowDelegate windowDidEndLiveResize hook to check and force-restore.
@MainActor
final class RecallPanel: NSPanel {

    private var lockedSize: NSSize
    private weak var sizeGuard: SizeGuard?

    init(contentRect: NSRect) {
        self.lockedSize = contentRect.size
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Must run after super.init
        level                = .floating
        isFloatingPanel      = true
        hidesOnDeactivate    = false
        isMovableByWindowBackground = false
        isMovable            = false
        backgroundColor      = .clear
        hasShadow            = true
        isOpaque             = false
        collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Lock the size
        self.minSize = lockedSize
        self.maxSize = lockedSize

        // Critical: observe every resize source (including SwiftUI's
        // internal setFrame:).
        // Use an NSTimer polling frame size at 1/30s to prevent SwiftUI
        // from stretching it.
        let guard_ = SizeGuard(panel: self, lockedSize: lockedSize)
        self.sizeGuard = guard_

        if let contentView = self.contentView {
            contentView.wantsLayer = true
            contentView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        }
    }

    /// Allow the controller to update lockedSize when switching dock direction.
    func updateLockedSize(_ newSize: NSSize) {
        lockedSize = newSize
        self.minSize = newSize
        self.maxSize = newSize
        // Sync to SizeGuard
        sizeGuard?.lockedSize = newSize
        // Apply the new size immediately
        var newFrame = self.frame
        newFrame.size = newSize
        super.setFrame(newFrame, display: true)
    }

    // Intercept SwiftUI's attempts to change contentSize
    override func setContentSize(_ size: NSSize) {
        super.setContentSize(lockedSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Observe the panel's `frameDidChangeNotification`—only corrects once when
/// the size actually drifts. Replaces the 30Hz Timer poll: event-driven,
/// zero steady-state CPU cost.
@MainActor
private final class SizeGuard {
    nonisolated(unsafe) weak var panel: NSPanel?
    nonisolated(unsafe) var lockedSize: NSSize
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(panel: NSPanel, lockedSize: NSSize) {
        self.panel = panel
        self.lockedSize = lockedSize
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            self.tick(panel: panel)
        }
    }

    deinit {
        // deinit runs in a non-isolated context; use nonisolated(unsafe) to bypass Sendable checks.
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        observer = nil
    }

    private func tick(panel: NSPanel) {
        let current = panel.frame.size
        // Allowed deviation ≤ 1pt (animation transitions)
        if abs(current.width - lockedSize.width) > 1 ||
           abs(current.height - lockedSize.height) > 1 {
            // SwiftUI stretched / shrunk it—force restore (preserve origin)
            var fixed = panel.frame
            fixed.size = lockedSize
            panel.setFrame(fixed, display: true)
        }
    }
}
