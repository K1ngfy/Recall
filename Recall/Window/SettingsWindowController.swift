import AppKit
import SwiftUI

/// Self-managed Settings window—fully decoupled from the SwiftUI Settings
/// scene.
///
/// **Why**: SwiftUI's `Settings { ... }` scene window level is system-managed;
/// on macOS 26 it gets covered by the main panel (RecallPanel) at .floating
/// level, making the settings invisible while configuring.
/// A self-managed NSWindow with explicit `level = .modalPanel` (100) stays
/// on top.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    /// Show the settings window (bring to front if already shown; never create duplicates)
    func show() {
        if let existing = window {
            // Already exists: bring to front + activate
            existing.level = .modalPanel
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        showNew()
    }

    /// Close the settings window
    func close() {
        window?.close()
        window = nil
    }

    private func showNew() {
        let style: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        // 6.7.2: enlarged window, 560x540 to give content more breathing room
        let contentSize = NSSize(width: 560, height: 540)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        // 6.7.2 switched to titleVisibility=.hidden—the title text disappears
        // but the traffic lights stay.
        // Set title to "" + titleVisibility=hidden together to fully hide the
        // "Settings" text.
        win.title = ""
        win.titleVisibility = .hidden
        // Critical 1: bump level to .modalPanel (100), above RecallPanel's .floating (3)
        win.level = .modalPanel
        // Critical 2: transparent titlebar so the window looks like a card
        win.titlebarAppearsTransparent = true
        // Critical 3: become the key window to receive keyboard events
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        // Only set the lower bound, not the upper bound
        win.minSize = NSSize(width: 520, height: 420)
        // SwiftUI content
        win.contentViewController = NSHostingController(rootView: SettingsRootView())

        // Center
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let winSize = win.frame.size
            win.setFrameOrigin(NSPoint(
                x: visible.midX - winSize.width / 2,
                y: visible.midY - winSize.height / 2
            ))
        } else {
            win.center()
        }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }
}
