import SwiftUI
import AppKit

/// Thumbnail: JPEG Data → NSImage → Image. The long edge of a thumbnail is ≤ 256pt, SwiftUI Image decodes directly.
struct ThumbnailView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.quaternary)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 0.35))
            )
    }
}
