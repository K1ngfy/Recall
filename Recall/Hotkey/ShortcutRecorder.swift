import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Hotkey recording component. Click to enter "recording" mode, then press any key + modifier combination to save.
@MainActor
struct ShortcutRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if !isRecording { startRecording() }
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text("Press any key combo…")
                        .foregroundStyle(.secondary)
                } else {
                    Text(displayString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isRecording ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: isRecording ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Click to record a new shortcut")
        .onDisappear { stopRecording() }
    }

    private var displayString: String {
        if keyCode == 0 { return "Not set" }
        var parts: [String] = []
        let mods = UInt32(modifiers)
        if mods & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        if mods & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if mods & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(keyCodeToString(UInt32(keyCode)))
        return parts.joined()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                Task { @MainActor in self.stopRecording() }
                return nil
            }
            let mods = event.modifierFlags.carbonFlags
            if mods == 0 {
                return nil
            }
            Task { @MainActor in
                self.keyCode = Int(event.keyCode)
                self.modifiers = Int(mods)
                self.stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var f: UInt32 = 0
        if contains(.command) { f |= UInt32(cmdKey) }
        if contains(.option)  { f |= UInt32(optionKey) }
        if contains(.shift)   { f |= UInt32(shiftKey) }
        if contains(.control) { f |= UInt32(controlKey) }
        return f
    }
}

func keyCodeToString(_ code: UInt32) -> String {
    switch code {
    case UInt32(kVK_ANSI_A): return "A"
    case UInt32(kVK_ANSI_B): return "B"
    case UInt32(kVK_ANSI_C): return "C"
    case UInt32(kVK_ANSI_D): return "D"
    case UInt32(kVK_ANSI_E): return "E"
    case UInt32(kVK_ANSI_F): return "F"
    case UInt32(kVK_ANSI_G): return "G"
    case UInt32(kVK_ANSI_H): return "H"
    case UInt32(kVK_ANSI_I): return "I"
    case UInt32(kVK_ANSI_J): return "J"
    case UInt32(kVK_ANSI_K): return "K"
    case UInt32(kVK_ANSI_L): return "L"
    case UInt32(kVK_ANSI_M): return "M"
    case UInt32(kVK_ANSI_N): return "N"
    case UInt32(kVK_ANSI_O): return "O"
    case UInt32(kVK_ANSI_P): return "P"
    case UInt32(kVK_ANSI_Q): return "Q"
    case UInt32(kVK_ANSI_R): return "R"
    case UInt32(kVK_ANSI_S): return "S"
    case UInt32(kVK_ANSI_T): return "T"
    case UInt32(kVK_ANSI_U): return "U"
    case UInt32(kVK_ANSI_V): return "V"
    case UInt32(kVK_ANSI_W): return "W"
    case UInt32(kVK_ANSI_X): return "X"
    case UInt32(kVK_ANSI_Y): return "Y"
    case UInt32(kVK_ANSI_Z): return "Z"
    case UInt32(kVK_ANSI_0): return "0"
    case UInt32(kVK_ANSI_1): return "1"
    case UInt32(kVK_ANSI_2): return "2"
    case UInt32(kVK_ANSI_3): return "3"
    case UInt32(kVK_ANSI_4): return "4"
    case UInt32(kVK_ANSI_5): return "5"
    case UInt32(kVK_ANSI_6): return "6"
    case UInt32(kVK_ANSI_7): return "7"
    case UInt32(kVK_ANSI_8): return "8"
    case UInt32(kVK_ANSI_9): return "9"
    case UInt32(kVK_Space): return "Space"
    case UInt32(kVK_Return): return "↩"
    case UInt32(kVK_Tab): return "⇥"
    case UInt32(kVK_Delete): return "⌫"
    case UInt32(kVK_ForwardDelete): return "⌦"
    case UInt32(kVK_UpArrow): return "↑"
    case UInt32(kVK_DownArrow): return "↓"
    case UInt32(kVK_LeftArrow): return "←"
    case UInt32(kVK_RightArrow): return "→"
    case UInt32(kVK_F1): return "F1"
    case UInt32(kVK_F2): return "F2"
    case UInt32(kVK_F3): return "F3"
    case UInt32(kVK_F4): return "F4"
    case UInt32(kVK_F5): return "F5"
    case UInt32(kVK_F6): return "F6"
    case UInt32(kVK_F7): return "F7"
    case UInt32(kVK_F8): return "F8"
    case UInt32(kVK_F9): return "F9"
    case UInt32(kVK_F10): return "F10"
    case UInt32(kVK_F11): return "F11"
    case UInt32(kVK_F12): return "F12"
    default: return "Key(\(code))"
    }
}
