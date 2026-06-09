import Foundation

/// Global dependency container. Injects PanelController / HotkeyCenter.
/// Annotated with @MainActor because its members (PanelController / HotkeyCenter) are also MainActor-isolated;
/// Swift 6 strict concurrency requires the container to be initialized synchronously on the MainActor.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let pasteboardMonitor: PasteboardMonitor
    let panelController:   RecallPanelController
    let hotkeyCenter:      GlobalHotkeyCenter

    /// Global unique RecallPanel weak reference — used by hover preview to locate row screen coordinates.
    weak var recallPanel: RecallPanel?

    private init() {
        self.pasteboardMonitor = PasteboardMonitor(interval: 0.5, debounce: 0.15)
        self.panelController   = RecallPanelController()
        self.hotkeyCenter      = GlobalHotkeyCenter()
        // recallPanel weak reference is deferred until NSApp is fully initialized.
        // Reading panelController.panel at the end of init would trigger the NSWindow initialization chain.
    }

    /// Called after NSApp is ready — also restores the last saved dock position.
    func bindRecallPanel() {
        self.recallPanel = self.panelController.panel

        // The panel is constructed with .right by default at startup, but the user may have set it to top/bottom/left last time.
        // Actively read the dock position from UserDefaults and call setDockPosition to let the panel recompute size + frame.
        if let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.Panel.dockPosition),
           let pos = PanelDockPosition(rawValue: raw),
           pos != .right {
            self.panelController.setDockPosition(pos)
        }
    }
}
