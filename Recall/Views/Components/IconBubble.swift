import SwiftUI

/// 36x36 rounded icon container. Shared by ClipRow / SnippetsView / SnippetRow.
/// - accent: true → icon uses accentColor on an 18% accent background; false → secondary on 4% primary
struct IconBubble: View {
    let systemName: String
    var accent: Bool = false
    var cornerRadius: CGFloat = 6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(accent ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
            Image(systemName: systemName)
                .foregroundStyle(accent ? Color.accentColor : .secondary)
                .font(.system(size: 16, weight: .regular))
        }
        .frame(width: 36, height: 36)
    }
}
