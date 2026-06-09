import Foundation

/// Centralized UserDefaults keys.
///
/// **Why**: In early Recall code, the same key was read/written across 3-5 files (panel.dockPosition in 5 places,
/// panel.pinned in 2, hotkey.* in 2), so after a UI change the service could keep holding a stale value —
/// a frequent source of sync bugs. After centralization, all new keys must go through here.
///
/// **How to apply**: `@AppStorage(UserDefaultsKeys.Panel.dockPosition)` / `UserDefaults.standard.string(forKey: UserDefaultsKeys.Panel.dockPosition)`.
enum UserDefaultsKeys {

    enum Panel {
        /// One of "left" / "right" / "top" / "bottom".
        static let dockPosition = "panel.dockPosition"
        /// Bool, pin mode toggle.
        static let pinned       = "panel.pinned"
    }

    enum Onboarding {
        /// Bool, whether Onboarding is complete.
        static let completed = "onboarding.completed"
    }

    enum Hotkey {
        /// Int, Carbon virtual key code.
        static let keyCode    = "hotkey.keyCode"
        /// Int, Carbon modifier mask.
        static let modifiers  = "hotkey.modifiers"
    }

    enum App {
        /// "en" / "zh-Hans" / "system".
        static let language = "app.language"
    }

    enum Preview {
        /// Bool, 6.9: 是否启用 Hover 预览弹窗。默认 true(向后兼容历史行为)。
        static let hoverEnabled = "preview.hoverEnabled"
    }
}
