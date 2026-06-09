import Foundation
import AppKit
import ApplicationServices
import Carbon

/// Permission center: aggregates all macOS permission states Recall needs.
@MainActor
@Observable
final class PermissionCenter {

    static let shared = PermissionCenter()

    var axiOSTrusted: Bool = false
    var isSecureInputActive: Bool = false

    private nonisolated(unsafe) var pollTimer: Timer?

    private init() {
        refreshAll()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isSecureInputActive = IsSecureEventInputEnabled()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    deinit {
        pollTimer?.invalidate()
    }

    @discardableResult
    func refreshAX() -> Bool {
        // kAXTrustedCheckOptionPrompt is actually the string literal
        // "AXTrustedCheckOptionPrompt".
        // Avoid Swift 6 strict-concurrency checks on the Unmanaged<CFString>
        // global.
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanFalse as CFBoolean] as CFDictionary
        axiOSTrusted = AXIsProcessTrustedWithOptions(opts)
        return axiOSTrusted
    }

    func refreshAll() {
        refreshAX()
        isSecureInputActive = IsSecureEventInputEnabled()
    }

    /// Actively request AX permission—shows the system authorization prompt.
    func requestAXWithPrompt() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue as CFBoolean] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshAX()
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
