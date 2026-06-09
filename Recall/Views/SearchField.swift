import SwiftUI

/// Apple HIG-style search field. Rounded corners + magnifying glass + clear button.
/// 6.4 enhancements:
/// - ⌘F to focus (exposed to the main menu via `.focusedSceneValue(\.recallSearchFocus, $isFocused)`,
///   see RecallApp's Commands for details)
/// - Esc to clear
/// - "N matches" hint
struct SearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let matchCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium))

            TextField(Strings.Panel.searchPlaceholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit { /* keep focus on enter */ }
                // Esc clears the query (keeps focus so the user can keep typing)
                .onKeyPress(.escape) {
                    if !text.isEmpty {
                        text = ""
                        return .handled
                    }
                    return .ignored
                }

            if !text.isEmpty {
                matchIndicator
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        // Expose the focus binding to the scene-level ⌘F command
        .focusedSceneValue(\.recallSearchFocus, $isFocused)
    }

    @ViewBuilder
    private var matchIndicator: some View {
        if matchCount > 0 {
            Text("\(matchCount)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        } else {
            Text("0")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// FocusedValue key exposed to the AppKit main menu's ⌘F.
/// Works with `Commands` + `CommandMenu` + `KeyboardShortcut("f", modifiers: .command)` to enable global focus.
struct RecallSearchFocusKey: FocusedValueKey {
    typealias Value = FocusState<Bool>.Binding
}

extension FocusedValues {
    var recallSearchFocus: RecallSearchFocusKey.Value? {
        get { self[RecallSearchFocusKey.self] }
        set { self[RecallSearchFocusKey.self] = newValue }
    }
}
