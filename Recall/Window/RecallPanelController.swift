import AppKit
import SwiftUI

/// Main panel "business controller": show/hide animation, dock position,
/// click-outside monitor.
/// Layout calculation is split out into PanelLayout.swift.
@MainActor
final class RecallPanelController {

    let panel: RecallPanel
    private let hosting: NSHostingController<RecallRootView>
    private var isAnimating = false
    private nonisolated(unsafe) var clickOutsideMonitor: Any?

    private(set) var dockPosition: PanelDockPosition

    init() {
        // Read the last dock position from UserDefaults to avoid the panel's
        // physical size being out of sync with the dockPosition seen by the
        // SwiftUI body.
        let savedDock = UserDefaults.standard
            .string(forKey: UserDefaultsKeys.Panel.dockPosition)
            .flatMap(PanelDockPosition.init(rawValue:)) ?? .right
        self.dockPosition = savedDock

        let initialSize = PanelLayout.computeSize(for: savedDock)
        self.panel = RecallPanel(contentRect: NSRect(origin: .zero, size: initialSize))
        self.hosting = NSHostingController(rootView: RecallRootView())
        self.hosting.view.frame = NSRect(origin: .zero, size: initialSize)
        self.hosting.view.wantsLayer = true
        self.hosting.view.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        self.hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        self.panel.contentViewController = self.hosting

        // Observe pinned-state changes
        NotificationCenter.default.addObserver(
            forName: .recallPanelPinChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, let pinned = note.object as? Bool else { return }
            if pinned {
                self.stopClickOutsideMonitor()
            } else if self.panel.isVisible {
                self.startClickOutsideMonitor()
            }
        }

        // 6.2.3: observe display-configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    /// Display-configuration change: recompute frame and re-anchor.
    private func handleScreenParametersChanged() {
        AppLog.window.info("screen parameters changed, re-anchoring panel")
        let newSize = PanelLayout.computeSize(for: dockPosition)
        panel.updateLockedSize(newSize)
        let newFrame = PanelLayout.computeFrame(position: dockPosition, size: newSize)
        // If not currently visible, don't force it to show; only update the internal cached size.
        if panel.isVisible {
            panel.setFrame(newFrame, display: true)
        }
    }

    deinit {
        if let m = clickOutsideMonitor {
            NSEvent.removeMonitor(m)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        guard !panel.isVisible, !isAnimating else { return }
        // 6.2.2: every show recomputes based on the "active screen" so it
        // follows the user's current position.
        let size = PanelLayout.computeSize(for: dockPosition)
        panel.updateLockedSize(size)
        let finalFrame = PanelLayout.computeFrame(position: dockPosition, size: size)

        let startFrame = PanelLayout.animatedStartFrame(from: finalFrame, position: dockPosition)
        panel.setFrame(startFrame, display: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        isAnimating = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.panel.setFrame(finalFrame, display: true)
                self.isAnimating = false
                PermissionCenter.shared.refreshAX()
                self.startClickOutsideMonitor()
            }
        }
    }

    func hide() {
        guard panel.isVisible, !isAnimating else { return }
        stopClickOutsideMonitor()

        let startFrame = panel.frame
        let endFrame   = PanelLayout.animatedStartFrame(from: startFrame, position: dockPosition)

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().alphaValue = 0
            self.panel.animator().setFrame(endFrame, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel.orderOut(nil)
                self?.isAnimating = false
            }
        })
    }

    func setDockPosition(_ pos: PanelDockPosition) {
        guard pos != dockPosition else { return }
        dockPosition = pos
        if panel.isVisible {
            let newSize = PanelLayout.computeSize(for: pos)
            panel.updateLockedSize(newSize)
            let rect = PanelLayout.computeFrame(position: pos, size: newSize)
            panel.animator().setFrame(rect, display: true)
        }
    }

    // MARK: - Click outside / Esc

    private func startClickOutsideMonitor() {
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.Panel.pinned) { return }
        guard clickOutsideMonitor == nil else { return }
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            switch event.type {
            case .leftMouseDown, .rightMouseDown:
                let mouse = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouse) {
                    self.hide()
                }
            case .keyDown:
                // Esc closes the panel (even when pinned—Esc is an explicit action, not an "accidental" tap)
                if event.keyCode == 53 /* kVK_Escape */ {
                    self.hide()
                }
            default: break
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

extension Notification.Name {
    static let recallPanelPinChanged = Notification.Name("RecallPanel.pinChanged")
}
