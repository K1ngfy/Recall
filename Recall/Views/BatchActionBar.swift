import SwiftUI

/// 6.6 batch action bar: shown below the header when selected count > 0
struct BatchActionBar: View {
    @Bindable var viewModel: ListViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text("\(viewModel.selectedIDs.count) selected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            actionButton("doc.on.doc", "Copy") {
                viewModel.copyBatch()
            }

            actionButton("trash", "Delete", role: .destructive) {
                viewModel.deleteBatch()
            }

            actionButton("xmark", "Clear") {
                viewModel.clearSelection()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Color.accentColor.opacity(0.10)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 0.5)
        }
    }

    private func actionButton(
        _ icon: String,
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}
