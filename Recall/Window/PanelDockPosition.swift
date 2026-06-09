import Foundation

/// Main panel dock position
enum PanelDockPosition: String, CaseIterable, Identifiable, Codable {
    case left, right, top, bottom, center
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:   return "Left"
        case .right:  return "Right"
        case .top:    return "Top"
        case .bottom: return "Bottom"
        case .center: return "Center"
        }
    }

    /// 是否走横向 bento 布局（top / bottom 才用）。center 走和侧边一致的纵向列表，
    /// 视觉上更像「悬浮小窗口」而非屏幕宽度的横向条。
    var isHorizontal: Bool {
        self == .top || self == .bottom
    }

    /// 建议尺寸；top/bottom 由控制器动态拉伸到屏宽，
    /// left/right 拉伸到屏高，center 保持自身固定尺寸不拉伸。
    var defaultSize: (width: CGFloat, height: CGFloat) {
        switch self {
        case .left, .right:  return (360, 520)
        case .top, .bottom:  return (520, 320)
        case .center:        return (480, 600)
        }
    }
}
