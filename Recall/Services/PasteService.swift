import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

/// Auto-paste service: upgrades "copy to clipboard" into
/// "copy + insert at the cursor position".
///
/// Fallback chain:
/// 1. AX direct write to focused element value (most reliable, but many apps
///    don't support it)
/// 2. Write clipboard + simulate ⌘V (best compatibility, but blocked by
///    Secure Input)
/// 3. Write clipboard only + prompt the user to paste manually (fallback)
@MainActor
final class PasteService {

    static let shared = PasteService()

    /// Main entry point: paste text at the current focus position.
    /// - Parameter hidePanelAfter: hide the main panel after a successful paste
    @discardableResult
    func paste(text: String, hidePanelAfter: Bool = true) -> Bool {
        // 0) Secure Input guard: fall back to copy-only + hint
        if IsSecureEventInputEnabled() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return false
        }

        // 1) Prefer AX (insert at cursor)
        if PermissionCenter.shared.axiOSTrusted, tryWriteViaAX(text: text) {
            if hidePanelAfter {
                AppEnvironment.shared.panelController.hide()
            }
            return true
        }

        // 2) Write clipboard + simulate ⌘V
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        simulateCmdV()

        if hidePanelAfter {
            AppEnvironment.shared.panelController.hide()
        }
        return true
    }

    /// 6.5 real snippet auto-expand:
    /// 1) Delete the trigger word the user just typed (AX delete N chars
    ///    before cursor)
    /// 2) Write the snippet's full content at the cursor position
    /// Failure fallback: write clipboard only
    /// - Parameter triggerLength: number of characters to delete (=trigger.count)
    @discardableResult
    func expandSnippet(triggerLength: Int, snippetText: String) -> Bool {
        // Secure Input fallback
        if IsSecureEventInputEnabled() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippetText, forType: .string)
            return false
        }

        // 1) Delete the trigger word
        deleteBackwardCharacters(count: triggerLength)

        // 2) Write snippet content
        if PermissionCenter.shared.axiOSTrusted, tryWriteViaAX(text: snippetText) {
            return true
        }

        // Fallback: write clipboard + simulate ⌘V
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippetText, forType: .string)
        // Undo the deletion just performed (press ⌘Z) so the user can
        // ⌘V manually.
        simulateUndo()
        simulateCmdV()
        return true
    }

    /// Simulate the backspace key N times
    private func deleteBackwardCharacters(count: Int) {
        let keyCode: CGKeyCode = 51  // kVK_Delete = backspace
        guard count > 0 else { return }
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return }
        // 30ms interval to avoid being dropped by the target app for being too fast.
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) { [weak self] in
                guard self != nil else { return }
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    /// Simulate ⌘Z
    private func simulateUndo() {
        let zKey: CGKeyCode = 6  // kVK_ANSI_Z
        let cmdFlag: CGEventFlags = .maskCommand
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: zKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: zKey, keyDown: false)
        else { return }
        keyDown.flags = cmdFlag
        keyUp.flags = cmdFlag
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            keyDown.post(tap: .cghidEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - AX Path

    private func tryWriteViaAX(text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        guard let focused = focusedElement(systemWide: systemWide) else { return false }

        // Priority 1: kAXSelectedTextAttribute - insert at cursor/selection
        // (preserves existing content)
        var selRef: CFTypeRef?
        let selStatus = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selRef)
        if selStatus == .success {
            // Element supports the selected-text setter — insert at cursor
            let cfText = text as CFTypeRef
            let setStatus = AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, cfText)
            if setStatus == .success { return true }
        }

        // Priority 2: kAXValueAttribute - some elements only support the
        // value setter.
        // Note: the value setter **overwrites** the entire content. Only use
        // it when AXValue exists and SelectedText does not.
        var valueRef: CFTypeRef?
        let valueStatus = AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef)
        if valueStatus == .success, (valueRef as? String) != nil {
            // Compatible with AXValue: overwrite the entire value
            // This case is rare (typically single-line input fields)
            let cfText = text as CFTypeRef
            let setStatus = AXUIElementSetAttributeValue(focused, kAXValueAttribute as CFString, cfText)
            return setStatus == .success
        }

        return false
    }

    private func focusedElement(systemWide: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &ref
        )
        guard status == .success, let axValue = ref else { return nil }
        return unsafeDowncast(axValue as AnyObject, to: AXUIElement.self)
    }

    // MARK: - CGEvent Cmd+V

    private func simulateCmdV() {
        let vKeyCode: CGKeyCode = 9
        let cmdFlag: CGEventFlags = .maskCommand

        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: false
        ) else { return }

        keyDown.flags = cmdFlag
        keyUp.flags = cmdFlag

        // Post after a delay—do not Thread.sleep and block the main thread.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            keyDown.post(tap: .cghidEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}
