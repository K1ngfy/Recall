import SwiftUI
import AppKit

/// Uses NSWorkspace to fetch the system icon for a file / folder. SwiftUI Image(nsImage:) renders it directly.
/// - size: output icon size (default 36)
struct FileIconView: View {
    let path: String
    var size: CGFloat = 36

    private var icon: NSImage? {
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
