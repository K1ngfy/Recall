import SwiftUI

/// 6.5 snippet create/edit popover
/// - Title: "Create Snippet"
/// - Field: triggerWord (required, 2-32 chars)
/// - Preview: snippet content
/// - Save: calls SnippetService.promoteToSnippet
struct SnippetTriggerSheet: View {
    let item: ClipItemViewData
    let onDismiss: () -> Void
    @State private var trigger: String = ""
    @State private var isExistingSnippet: Bool

    init(item: ClipItemViewData, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
        self._trigger = State(initialValue: item.triggerWord ?? "")
        self._isExistingSnippet = State(initialValue: item.isSnippet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isExistingSnippet ? Strings.SnippetSheet.editTitle() : Strings.SnippetSheet.createTitle())
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.3)

            // Trigger word input
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.SnippetSheet.triggerWord)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("/")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    TextField(Strings.SnippetSheet.triggerPlaceholder, text: $trigger)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .onChange(of: trigger) { _, new in
                            // Filter out invalid characters while typing
                            let filtered = new.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != new {
                                trigger = String(filtered.prefix(32))
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                Text(Strings.SnippetSheet.triggerHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Snippet content preview
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.SnippetSheet.contentPreview)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(item.textContent ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            // Button area
            HStack {
                if isExistingSnippet {
                    Button(Strings.SnippetSheet.remove, role: .destructive) {
                        SnippetService.demoteFromSnippet(item)
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button(Strings.SnippetSheet.cancel) { onDismiss() }
                    .buttonStyle(.bordered)
                Button(isExistingSnippet ? Strings.SnippetSheet.save : Strings.SnippetSheet.create) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(!isValid)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var isValid: Bool {
        !trigger.isEmpty && trigger.count >= 2
    }

    private func save() {
        SnippetService.promoteToSnippet(item, trigger: trigger)
        onDismiss()
    }
}
