import SwiftUI
import AppKit

// MARK: - Coordinator

/// Global hover preview state.
@MainActor
@Observable
final class PreviewCoordinator {
    static let shared = PreviewCoordinator()

    var activeItemID: UUID?
    var popoverHovered: Bool = false

    func shouldShow(for item: ClipItemViewData) -> Bool {
        activeItemID == item.id
    }

    func activate(_ item: ClipItemViewData) {
        activeItemID = item.id
    }

    /// 6.9 显式点击触发:同一项二次点击关闭(toggle 直觉),不同项点击切换到新项
    func toggle(_ item: ClipItemViewData) {
        if activeItemID == item.id {
            deactivateAll()
        } else {
            activeItemID = item.id
        }
    }

    /// Called when the row's hover ends: only close if the popover is also not hovered.
    func deactivateIfNoHover(_ item: ClipItemViewData) {
        if activeItemID == item.id && !popoverHovered {
            activeItemID = nil
        }
    }

    func deactivateAll() {
        activeItemID = nil
        popoverHovered = false
    }
}

// MARK: - Modifier

/// Hover preview popover.
///
/// 6.9 设计:
/// - **popover binding 始终挂**——这样点击左侧 icon 的显式触发能正常显示
/// - **`.onHover` 由 Settings 开关控制**——用户关闭 hover 自动预览时,
///   只是不再自动响应鼠标悬停,显式点击仍可弹出
/// 关闭逻辑:row onHover(false) → 等 0.2s → 若 popover 也未 hover,则关
struct HoverPreviewModifier: ViewModifier {
    let item: ClipItemViewData
    @State private var workItem: DispatchWorkItem?
    @Bindable private var coordinator = PreviewCoordinator.shared
    @AppStorage(UserDefaultsKeys.Preview.hoverEnabled) private var hoverEnabled: Bool = true

    func body(content: Content) -> some View {
        Group {
            if hoverEnabled {
                content.onHover { hovering in
                    handleHover(hovering)
                }
            } else {
                content
            }
        }
        .popover(isPresented: Binding(
            get: { coordinator.shouldShow(for: item) },
            set: { newValue in
                // 6.9 race fix:仅当 activeItemID 仍 == 当前 item.id 时才 deactivate。
                // 否则当用户从 A 切到 B(toggle 直接设 activeItemID=B.id),
                // SwiftUI 调 A.setter(false) 准备关闭 A 的 popover,
                // 若无脑 deactivateAll 会把刚设的 B.id 也清掉,B 永远开不出来。
                if !newValue && coordinator.activeItemID == item.id {
                    coordinator.deactivateAll()
                }
            }
        ), arrowEdge: arrowEdge) {
            HoverPreviewContent(item: item)
                .onHover { hovering in
                    coordinator.popoverHovered = hovering
                    if !hovering {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if !coordinator.popoverHovered {
                                coordinator.deactivateAll()
                            }
                        }
                    }
                }
                .interactiveDismissDisabled(true)
        }
    }

    private var arrowEdge: Edge {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.Panel.dockPosition) ?? PanelDockPosition.right.rawValue
        let pos = PanelDockPosition(rawValue: raw) ?? .right
        switch pos {
        case .left:   return .leading
        case .right:  return .trailing
        case .top:    return .top
        case .bottom: return .bottom
        // center 模式面板悬浮屏中央，hover preview 走右侧贴合，与 right 一致最自然
        case .center: return .trailing
        }
    }

    private func handleHover(_ hovering: Bool) {
        workItem?.cancel()
        if hovering {
            let work = DispatchWorkItem { coordinator.activate(item) }
            workItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        } else {
            let work = DispatchWorkItem { coordinator.deactivateIfNoHover(item) }
            workItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }
    }
}

extension View {
    func hoverPreview(for item: ClipItemViewData) -> some View {
        modifier(HoverPreviewModifier(item: item))
    }
}

// MARK: - Content

/// Popover inner view.
struct HoverPreviewContent: View {
    let item: ClipItemViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider().opacity(0.3)
            content
        }
        .padding(12)
        .frame(width: 480, height: 260, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: item.contentType.iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(item.contentType.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(item.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.contentType {
        case .text:
            ScrollView {
                Text(item.textContent ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
        case .link:
            linkOpenView
        case .image:
            imageView
        case .file:
            fileView
        case .snippet:
            snippetView
        }
    }

    @ViewBuilder
    private var fileView: some View {
        let path = item.textContent ?? ""
        let url = URL(fileURLWithPath: path)
        let exists = FileManager.default.fileExists(atPath: path)
        VStack(spacing: 12) {
            FileIconView(path: path, size: 96)
            VStack(spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if !exists {
                Text(Strings.Hover.fileMoved)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var imageView: some View {
        if let path = item.imageRelativePath,
           let img = NSImage(contentsOf: ClipStorageLocation.imageDirectory.appendingPathComponent(path)) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else if let data = item.thumbnailData, let img = NSImage(data: data) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Text(Strings.Hover.imageUnavailable)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var snippetView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Strings.SnippetSheet.editTitle())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let t = item.triggerWord {
                        Text("/\(t)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(item.usageCount)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(Strings.Hover.usesSuffix)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            Divider().opacity(0.3)
            Text(item.textContent ?? "")
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    private var linkOpenView: some View {
        let urlString = item.textContent ?? ""
        let url = URL(string: urlString)
        return VStack(spacing: 14) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.accentColor)

            Text(item.linkTitle ?? urlString)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal, 8)

            if let host = item.linkHost {
                Text(host)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Button {
                if let url, url.isSafeWeb {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.system(size: 12))
                    Text(Strings.Hover.openInBrowser)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 0.5)
                )
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(Strings.Hover.linkOpenHint)
            .disabled(url == nil)

            Text(Strings.Hover.linkOpenHint)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
