import AppKit
import SwiftUI

/// AppKit layer directly manages the onboarding window — SwiftUI Window scene on macOS 26
/// has unstable defaultLaunchBehavior, so we use NSWindowController for full control.
@MainActor
final class OnboardingController {
    static let shared = OnboardingController()

    private var window: NSWindow?

    func showIfNeeded(force: Bool = false) {
        // Skip if already shown.
        if let existing = window, existing.isVisible { return }

        let completed = UserDefaults.standard.bool(forKey: UserDefaultsKeys.Onboarding.completed)
        if completed && !force { return }

        showWindow()
    }

    /// Force show regardless of the completed flag (used by menu bar "Show Welcome…").
    func showForced() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        showWindow()
    }

    private func showWindow() {
        // 6.7 Single-page Apple HIG style: remove titlebar decoration, fixed size.
        let style: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let contentSize = NSSize(width: 560, height: 540)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        // Use a localized title; transparent titlebar so the window looks like a card.
        win.title = Strings.appName
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        // Lock size — layout is already computed, resizing would break it.
        win.minSize = contentSize
        win.maxSize = contentSize
        win.contentViewController = NSHostingController(rootView: OnboardingView())

        // Center: use the middle of visibleFrame (excludes menu bar / Dock).
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let winSize = win.frame.size
            win.setFrameOrigin(NSPoint(
                x: visible.midX - winSize.width / 2,
                y: visible.midY - winSize.height / 2
            ))
        } else {
            win.center()  // Fallback.
        }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func close() {
        window?.close()
        window = nil
    }
}
