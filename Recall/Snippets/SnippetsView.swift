import SwiftUI

/// 6.5 Unified snippet management view.
/// - Size is determined by the outer NSWindow (matches main panel height when docked to side).
/// - onClose is handled by SnippetsController.close().
struct SnippetsView: View {
    @Bindable var viewModel: ListViewModel
    let onClose: () -> Void
    @State private var snippetSheetItem: ClipItemViewData?
    @State private var searchText: String = ""

    var filtered: [ClipItemViewData] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.snippets }
        return viewModel.snippets.filter { item in
            (item.triggerWord?.lowercased().contains(q) ?? false) ||
            (item.textContent?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if viewModel.snippets.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    noResults
                } else {
                    snippetList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.loadSnippets() }
        .sheet(item: $snippetSheetItem) { item in
            SnippetTriggerSheet(item: item) {
                snippetSheetItem = nil
                viewModel.loadSnippets()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                Text(Strings.Snippets.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(viewModel.snippets.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            // Search field — same style as the Recall main panel.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(Strings.Snippets.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var snippetList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {                          // Matches Recall main panel row spacing.
                ForEach(filtered) { snippet in
                    SnippetRow(
                        snippet: snippet,
                        onEdit: { snippetSheetItem = snippet },
                        onDelete: { viewModel.deleteSnippets([snippet.id]) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(Strings.Empty.noSnippetsTitle())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(Strings.Empty.noSnippetsSubtitle())
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(Strings.Empty.noSearchResultsTitle())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SnippetRow: View {
    let snippet: ClipItemViewData
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            // icon — same as ClipRow: 36x36 quaternary 5% background, 11pt font.
            iconBubble
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 5) {
                    Text("/\(snippet.triggerWord ?? "?")")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                    if snippet.usageCount > 0 {
                        Text("·")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                        Text("\(snippet.usageCount)× \(Strings.Hover.usesSuffix)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            if isHovered {
                HStack(spacing: 4) {
                    actionButton(systemImage: "pencil", help: "Edit trigger", action: onEdit)
                    actionButton(systemImage: "trash", help: "Delete snippet", tint: .red, action: onDelete)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            // Double-click to quick-copy.
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(snippet.textContent ?? "", forType: .string)
        }
    }

    /// 6.5 Style aligned with ClipRow: 36x36 rounded icon.
    private var iconBubble: some View {
        IconBubble(systemName: "text.book.closed", accent: true)
    }

    /// Hover rounded square button (matches ClipRow copyButton).
    private func actionButton(systemImage: String, help: String, tint: Color = .secondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var primaryText: String {
        let body = snippet.textContent ?? ""
        return body.replacingOccurrences(of: "\n", with: " ")
    }
}
