import AppKit
import SwiftUI

/// AppKit layer managing the Snippets popover — same borderless + frosted glass style as RecallPanel.
@MainActor
final class SnippetsController {
    static let shared = SnippetsController()

    private var window: NSWindow?
    private nonisolated(unsafe) var clickOutsideMonitor: Any?

    /// Popover height matches the panel when docked to the side (capped at 800).
    private static let sideWidth: CGFloat = 480
    private static let sideHeightCap: CGFloat = 800

    /// Default size when docked to top/bottom.
    private static let flatSize = NSSize(width: 480, height: 420)

    func show(viewModel: ListViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = AppEnvironment.shared.recallPanel
        let dock  = AppEnvironment.shared.panelController.dockPosition

        // 1) Compute target size based on dock direction.
        let size = self.size(for: dock, panel: panel)

        // 2) Borderless + frosted glass: matches RecallPanel style.
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.level                = .floating
        win.isMovableByWindowBackground = true
        win.backgroundColor      = .clear
        win.isOpaque             = false
        win.hasShadow            = true
        win.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.minSize              = size
        win.maxSize              = size

        // 3) Position.
        if let panel, panel.isVisible {
            let screen = panel.screen ?? PanelLayout.activeScreen() ?? NSScreen.main
            if let screen {
                let frame = PanelLayout.frameAdjacent(
                    to: panel.frame,
                    on: screen,
                    size: size,
                    alignTop: !dock.isHorizontal
                )
                win.setFrame(frame, display: false)
            }
        } else if let screen = PanelLayout.activeScreen() ?? NSScreen.main {
            let visible = screen.visibleFrame
            win.setFrameOrigin(NSPoint(
                x: visible.midX - size.width  / 2,
                y: visible.midY - size.height / 2
            ))
        }

        // 4) Content: SnippetsWindow provides frosted glass + unified 4-corner radius.
        let content = SnippetsWindow(size: size) {
            SnippetsView(viewModel: viewModel) { [weak self] in
                self?.close()
            }
        }
        // Key: explicitly set the hosting view's frame and stretch the contentView to the target size;
        // otherwise NSHostingController will use the SwiftUI body's intrinsic size and shrink the window to header width.
        let hosting = NSHostingController(rootView: content)
        hosting.view.frame = NSRect(origin: .zero, size: size)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        win.contentViewController = hosting
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win

        startClickOutsideMonitor()
    }

    func close() {
        stopClickOutsideMonitor()
        window?.close()
        window = nil
    }

    /// Compute popover size based on dock direction.
    /// - Side (left/right): height = min(panel.height, 800), top-aligned.
    /// - Top/bottom: fixed 480x420.
    private func size(for dock: PanelDockPosition, panel: RecallPanel?) -> NSSize {
        if dock.isHorizontal { return Self.flatSize }
        guard let panel, panel.isVisible else { return Self.flatSize }
        let h = min(panel.frame.height, Self.sideHeightCap)
        return NSSize(width: Self.sideWidth, height: h)
    }

    // MARK: - Click outside (same as RecallPanel)

    /// Click anywhere outside Snippets to close it.
    private func startClickOutsideMonitor() {
        guard clickOutsideMonitor == nil else { return }
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.window?.isVisible == true else { return }
            let mouse = NSEvent.mouseLocation
            if let frame = self.window?.frame, !frame.contains(mouse) {
                self.close()
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let m = clickOutsideMonitor {
            NSEvent.removeMonitor(m)
            clickOutsideMonitor = nil
        }
    }
}
