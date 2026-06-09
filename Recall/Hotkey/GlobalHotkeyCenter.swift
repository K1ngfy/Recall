import AppKit
import Carbon.HIToolbox

/// Global hotkey center: based on Carbon RegisterEventHotKey.
@MainActor
final class GlobalHotkeyCenter {

    /// C pointer reference (Sendable); uses nonisolated(unsafe) to allow deinit access.
    /// Usage constraint: must be accessed on the main thread.
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var handler:   EventHandlerRef?
    private nonisolated(unsafe) var onTrigger: (() -> Void)?

    private static let signature: OSType = 0x52434C4C   // 'RCLL'
    private static let hotKeyID:   UInt32 = 1

    /// Register with a user-defined keyCode + modifiers.
    func registerCustom(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) {
        register(keyCode: keyCode, modifiers: modifiers, onTrigger: onTrigger)
    }

    func register(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData else { return noErr }
                let center = Unmanaged<GlobalHotkeyCenter>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if status == noErr && hkID.id == GlobalHotkeyCenter.hotKeyID {
                    DispatchQueue.main.async {
                        center.onTrigger?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            opaqueSelf,
            &handler
        )

        let hkID = EventHotKeyID(
            signature: GlobalHotkeyCenter.signature,
            id: GlobalHotkeyCenter.hotKeyID
        )
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            AppLog.hotkey.error("RegisterEventHotKey failed: OSStatus=\(status, privacy: .public)")
            // Notify the app: hotkey is occupied, the UI layer will show a one-time banner.
            NotificationCenter.default.post(
                name: .recallHotkeyConflict,
                object: nil,
                userInfo: ["keyCode": Int(keyCode), "modifiers": Int(modifiers)]
            )
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let h = handler    { RemoveEventHandler(h) }
        hotKeyRef = nil
        handler   = nil
    }

    deinit {
        // Synchronously unload the Carbon hotkey: the class is marked @MainActor, so deinit runs on the main thread
        // (deinit on a main-actor-isolated type is synchronous), and Carbon APIs can be called directly.
        if let r = hotKeyRef { UnregisterEventHotKey(r) }
        if let h = handler    { RemoveEventHandler(h) }
        hotKeyRef = nil
        handler = nil
        onTrigger = nil
    }
}

extension Notification.Name {
    /// Emitted by GlobalHotkeyCenter when the global hotkey is occupied by another app.
    static let recallHotkeyConflict = Notification.Name("Recall.hotkeyConflict")
}
