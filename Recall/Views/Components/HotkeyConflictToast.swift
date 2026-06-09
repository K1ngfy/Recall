import SwiftUI
import AppKit

/// Data for the global hotkey conflict hint
struct HotkeyConflictToast: Equatable {
    let keyCode: Int
    let modifiers: Int
    let shownAt: Date

    static func == (lhs: HotkeyConflictToast, rhs: HotkeyConflictToast) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

/// Hotkey conflict toast view
struct HotkeyConflictToastView: View {
    let toast: HotkeyConflictToast
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(Strings.HotkeyConflict.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(Strings.HotkeyConflict.subtitle(displayShortcut))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Button(Strings.HotkeyConflict.change, action: onOpenSettings)
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.orange.opacity(0.4), lineWidth: 0.5)
        )
    }

    /// Convert the Carbon modifier mask to a human-readable string
    private var displayShortcut: String {
        var parts: [String] = []
        let m = toast.modifiers
        if m & 0x08 != 0 { parts.append("⌃") }  // control
        if m & 0x01 != 0 { parts.append("⇧") }  // shift
        if m & 0x04 != 0 { parts.append("⌥") }  // option
        if m & 0x02 != 0 { parts.append("⌘") }  // command
        // Simplified keyCode → character mapping (only common keys)
        let keyName: String
        switch toast.keyCode {
        case 9:  keyName = "V"
        case 0:  keyName = "A"
        case 11: keyName = "B"
        case 1:  keyName = "S"
        case 2:  keyName = "D"
        case 3:  keyName = "F"
        case 5:  keyName = "G"
        case 49: keyName = "Space"
        default: keyName = "\(toast.keyCode)"
        }
        return parts.joined() + keyName
    }
}

/// Observes the `recallHotkeyConflict` notification, packages the info as toast data and
/// puts it into the binding. Auto-clears after 5s.
@MainActor
final class HotkeyConflictObserver {
    private var task: Task<Void, Never>?

    func attach(to binding: Binding<HotkeyConflictToast?>) {
        NotificationCenter.default.addObserver(
            forName: .recallHotkeyConflict,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let keyCode = info["keyCode"] as? Int,
                  let modifiers = info["modifiers"] as? Int else { return }
            Task { @MainActor in
                self?.show(toast: HotkeyConflictToast(
                    keyCode: keyCode, modifiers: modifiers, shownAt: .now
                ), binding: binding)
            }
        }
    }

    private func show(toast: HotkeyConflictToast, binding: Binding<HotkeyConflictToast?>) {
        binding.wrappedValue = toast
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            // Only clear the same toast (matching keyCode + modifiers) so a fresh conflict
            // within the 5s window isn't accidentally dismissed.
            if binding.wrappedValue == toast {
                binding.wrappedValue = nil
            }
        }
    }
}
