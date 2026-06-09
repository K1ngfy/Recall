import Foundation

/// Centralized access layer for Recall user-visible strings.
///
/// - Views must not hardcode user-visible text (e.g. `Text("...")` / `Button("...")`).
/// - Always access via `Strings.xxx` indirection.
/// - Actual text lives in `Resources/{lang}.lproj/Localizable.strings`,
///   and falls back to `defaultValue` (English) when missing.
/// - To add a new language in the future: just add `Resources/xx.lproj/Localizable.strings`, no code change required.
enum Strings {
    // MARK: - App
    static let appName = String(localized: "app.name", defaultValue: "Recall")

    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle   = String(localized: "onboarding.welcome.title",   defaultValue: "Welcome to Recall")
        static let welcomeSubtitle = String(localized: "onboarding.welcome.subtitle", defaultValue: "Your clipboard history, always one keystroke away.")
        static let welcomeBody    = String(localized: "onboarding.welcome.body",    defaultValue: "Double-click an item to insert it at your cursor. No more ⌘C ⌘V dance.")
        static let autopasteTitle  = String(localized: "onboarding.autopaste.title",  defaultValue: "Auto-paste, anywhere")
        static let autopasteBody   = String(localized: "onboarding.autopaste.body",   defaultValue: "Grant Recall access in System Settings → Privacy & Security → Accessibility to enable auto-paste.")
        static let customizeTitle  = String(localized: "onboarding.customize.title",  defaultValue: "Make it yours")
        static let customizeBody   = String(localized: "onboarding.customize.body",   defaultValue: "Press ⌘, to open Settings later. Customize hotkey, accent color, dock position, and more.")
        static let continue_       = String(localized: "onboarding.continue",         defaultValue: "Get Started")
        static let next            = String(localized: "onboarding.next",            defaultValue: "Next")
        static let openSettings    = String(localized: "onboarding.openSettings",    defaultValue: "Open Settings")
        // 6.9 onboarding 底部"以后再说"按钮 - 替代之前误用的 Strings.MenuBar.welcome
        static let close           = String(localized: "onboarding.close",           defaultValue: "Close")
    }

    // MARK: - Menu Bar
    enum MenuBar {
        static let show     = String(localized: "menubar.show",     defaultValue: "Show Recall")
        static let welcome  = String(localized: "menubar.welcome",  defaultValue: "Show Welcome…")
        static let settings = String(localized: "menubar.settings", defaultValue: "Settings…")
        static let quit     = String(localized: "menubar.quit",     defaultValue: "Quit Recall")
    }

    // MARK: - Settings
    enum Settings {
        static let tabGeneral    = String(localized: "settings.tab.general",    defaultValue: "General")
        static let tabAppearance = String(localized: "settings.tab.appearance", defaultValue: "Appearance")
        static let tabStorage    = String(localized: "settings.tab.storage",    defaultValue: "Storage")
        static let tabHotkey     = String(localized: "settings.tab.hotkey",     defaultValue: "Hotkey")

        static let dockPosition     = String(localized: "settings.dockPosition",     defaultValue: "Dock Position")
        static let dockPositionLeft = String(localized: "settings.dockPosition.left", defaultValue: "Left")
        static let dockPositionRight = String(localized: "settings.dockPosition.right", defaultValue: "Right")
        static let dockPositionTop = String(localized: "settings.dockPosition.top", defaultValue: "Top")
        static let dockPositionBottom = String(localized: "settings.dockPosition.bottom", defaultValue: "Bottom")
        static let dockPositionCenter = String(localized: "settings.dockPosition.center", defaultValue: "Center")

        static let language        = String(localized: "settings.language",            defaultValue: "Language")
        static let languageRow     = String(localized: "settings.language.row",        defaultValue: "App language")
        static let languageRestartHint = String(localized: "settings.language.restartHint", defaultValue: "Restart Recall to apply the new language.")
        static let restartNow      = String(localized: "settings.language.restartNow", defaultValue: "Restart Now")

        static let accentColor     = String(localized: "settings.accentColor",     defaultValue: "Accent Color")
        static let accentColorRow  = String(localized: "settings.accentColor.color", defaultValue: "Color")
        static let theme           = String(localized: "settings.theme",           defaultValue: "Panel Theme")
        static let themeSystem     = String(localized: "settings.theme.system",    defaultValue: "System")
        static let themeAurora     = String(localized: "settings.theme.aurora",    defaultValue: "Aurora")
        static let themeSunset     = String(localized: "settings.theme.sunset",    defaultValue: "Sunset")
        static let themeOcean      = String(localized: "settings.theme.ocean",     defaultValue: "Ocean")
        static let themeForest     = String(localized: "settings.theme.forest",    defaultValue: "Forest")
        static let themeGraphite   = String(localized: "settings.theme.graphite",  defaultValue: "Graphite")
        static let themeCustom     = String(localized: "settings.theme.custom",    defaultValue: "Custom")
        static let customAccent    = String(localized: "settings.customAccent",    defaultValue: "Accent color")
        static let customBackground = String(localized: "settings.customBackground", defaultValue: "Background color")

        static let appearanceMode = String(localized: "settings.appearance.mode",  defaultValue: "Mode")
        static let followSystem   = String(localized: "settings.appearance.followSystem", defaultValue: "Follow System")
        static let light           = String(localized: "settings.appearance.light", defaultValue: "Light")
        static let dark            = String(localized: "settings.appearance.dark",  defaultValue: "Dark")
        static let appearanceSection = String(localized: "settings.appearance", defaultValue: "Appearance")
        static let preview         = String(localized: "settings.appearance.preview", defaultValue: "Preview")
        static let previewTriggerWord = String(localized: "settings.appearance.preview.triggerWord", defaultValue: "trigger word")
        static let previewSelectedTab = String(localized: "settings.appearance.preview.selectedTab", defaultValue: "selected tab")
        static let previewPrimaryAction = String(localized: "settings.appearance.preview.primaryAction", defaultValue: "primary action")

        static let retention           = String(localized: "settings.retention",         defaultValue: "Retention")
        static let retentionDescription = String(localized: "settings.retention.description", defaultValue: "Items older than the selected duration are automatically cleaned up on app launch and every hour.")

        // 6.8 Storage tab 一键清空
        static let resetSection               = String(localized: "settings.reset.section",               defaultValue: "Reset")
        static let clearAllData               = String(localized: "settings.clearAllData",                defaultValue: "Clear All Data")
        static let clearAllDataDescription    = String(localized: "settings.clearAllData.description",    defaultValue: "Permanently remove all clipboard history, favorites, snippets, and images stored by Recall.")
        static let clearAllDataConfirmTitle   = String(localized: "settings.clearAllData.confirm.title",  defaultValue: "Clear all Recall data?")
        static let clearAllDataConfirmMessage = String(localized: "settings.clearAllData.confirm.message", defaultValue: "This will permanently remove all clipboard history, favorites, snippets, and stored images. This action cannot be undone.")
        static let clearAllDataConfirmAction  = String(localized: "settings.clearAllData.confirm.action", defaultValue: "Clear All Data")
        static let clearAllDataCancel         = String(localized: "settings.clearAllData.cancel",         defaultValue: "Cancel")
        static func clearAllDataToast(_ n: Int) -> String {
            String(localized: "settings.clearAllData.toast", defaultValue: "Cleared \(n) items")
                .replacingOccurrences(of: "%lld", with: "\(n)")
        }

        static let hotkeyTitle         = String(localized: "settings.hotkey.title",         defaultValue: "Global Hotkey")
        static let hotkeyShowHide      = String(localized: "settings.hotkey.showHide",      defaultValue: "Show/Hide Recall")
        static let hotkeyPlaceholder   = String(localized: "settings.hotkey.recorderPlaceholder", defaultValue: "Press any key combo…")
        static let hotkeyReset         = String(localized: "settings.hotkey.reset",         defaultValue: "Reset")
        static let hotkeyHint          = String(localized: "settings.hotkey.hint",          defaultValue: "Click the key combo to record a new shortcut. ESC to cancel. A modifier key is required.")

        static let findInRecall        = String(localized: "settings.findInRecall", defaultValue: "Find in Recall")

        // 6.9 Hover preview toggle
        static let hoverPreviewSection     = String(localized: "settings.hoverPreview.section",     defaultValue: "Hover Preview")
        static let hoverPreviewToggle      = String(localized: "settings.hoverPreview.toggle",      defaultValue: "Show preview on hover")
        static let hoverPreviewDescription = String(localized: "settings.hoverPreview.description", defaultValue: "Hover any clip for 0.5s to peek the full content. Disable to keep the panel quieter when scanning many rows.")
    }

    // MARK: - Panel / Header
    enum Panel {
        static let pin             = String(localized: "panel.pin",         defaultValue: "Pin")
        static let unpin           = String(localized: "panel.unpin",       defaultValue: "Unpin (panel will close on outside click)")
        static let pinHelp         = String(localized: "panel.pinned",      defaultValue: "Pin panel open")
        static let unpinHelp       = String(localized: "panel.unpinned",    defaultValue: "Unpin (panel will close on outside click)")
        static let manageSnippets  = String(localized: "panel.manageSnippets", defaultValue: "Manage Snippets")
        static let settings        = String(localized: "panel.settings",     defaultValue: "Settings")
        static let searchPlaceholder = String(localized: "panel.searchPlaceholder", defaultValue: "Search clipboard")
        static let editSnippet     = String(localized: "panel.editSnippet", defaultValue: "Edit Snippet")
        static let makeSnippet     = String(localized: "panel.makeSnippet", defaultValue: "Make this into a Snippet")
        static let copy            = String(localized: "panel.copy",        defaultValue: "Copy to clipboard")
    }

    // MARK: - Tabs / Filter
    enum Tab {
        static let all      = String(localized: "tab.all",      defaultValue: "All")
        static let text     = String(localized: "tab.text",     defaultValue: "Text")
        static let images   = String(localized: "tab.images",   defaultValue: "Images")
        static let links    = String(localized: "tab.links",    defaultValue: "Links")
        static let files    = String(localized: "tab.files",    defaultValue: "Files")
        static let snippets = String(localized: "tab.snippets", defaultValue: "Snippets")
        static let favorites = String(localized: "tab.favorites", defaultValue: "Favorites")
    }

    enum DateRange {
        static let anytime   = String(localized: "date.anytime",   defaultValue: "Anytime")
        static let today     = String(localized: "date.today",     defaultValue: "Today")
        static let pastWeek  = String(localized: "date.pastWeek",  defaultValue: "Past week")
        static let pastMonth = String(localized: "date.pastMonth", defaultValue: "Past month")
    }

    /// "%lld selected" — multi-select counter.
    static func multiSelectCount(_ n: Int) -> String {
        String(localized: "multiSelect.count", defaultValue: "\(n) selected")
            .replacingOccurrences(of: "%lld", with: "\(n)")
    }

    // MARK: - Empty states
    enum Empty {
        static func noHistoryTitle()       -> String { String(localized: "empty.noHistory.title",       defaultValue: "No clipboard history yet") }
        static func noHistorySubtitle()    -> String { String(localized: "empty.noHistory.subtitle",    defaultValue: "Copy text, links, or images anywhere to start building your history") }
        static func noTextTitle()          -> String { String(localized: "empty.noText.title",          defaultValue: "No text copied yet") }
        static func noTextSubtitle()       -> String { String(localized: "empty.noText.subtitle",       defaultValue: "Copy some text to see it appear here") }
        static func noImagesTitle()        -> String { String(localized: "empty.noImages.title",        defaultValue: "No images copied yet") }
        static func noImagesSubtitle()     -> String { String(localized: "empty.noImages.subtitle",     defaultValue: "Copy an image from any app to see it appear here") }
        static func noLinksTitle()         -> String { String(localized: "empty.noLinks.title",         defaultValue: "No links copied yet") }
        static func noLinksSubtitle()      -> String { String(localized: "empty.noLinks.subtitle",      defaultValue: "Copy a URL to see it appear here") }
        static func noFilesTitle()         -> String { String(localized: "empty.noFiles.title",         defaultValue: "No files copied yet") }
        static func noFilesSubtitle()      -> String { String(localized: "empty.noFiles.subtitle",      defaultValue: "Copy a file from Finder to see it appear here") }
        static func noSnippetsTitle()      -> String { String(localized: "empty.noSnippets.title",      defaultValue: "No snippets yet") }
        static func noSnippetsSubtitle()   -> String { String(localized: "empty.noSnippets.subtitle",   defaultValue: "Click the ⚡ on a text row in All to create a snippet") }
        static func noFavoritesTitle()     -> String { String(localized: "empty.noFavorites.title",     defaultValue: "No favorites yet") }
        static func noFavoritesSubtitle()  -> String { String(localized: "empty.noFavorites.subtitle",  defaultValue: "Click the ☆ on any item to keep it forever") }
        static func noSearchResultsTitle() -> String { String(localized: "empty.noSearchResults.title", defaultValue: "No matches found") }
        static func noSearchResultsSubtitle() -> String { String(localized: "empty.noSearchResults.subtitle", defaultValue: "Try a different search keyword or clear the search field") }
    }

    // MARK: - Snippet sheet
    enum SnippetSheet {
        static func createTitle()   -> String { String(localized: "sheet.snippet.create",   defaultValue: "Create Snippet") }
        static func editTitle()     -> String { String(localized: "sheet.snippet.edit",     defaultValue: "Edit Snippet") }
        static let triggerWord      = String(localized: "sheet.snippet.triggerWord", defaultValue: "Trigger word")
        static let triggerPlaceholder = String(localized: "sheet.snippet.triggerWordPlaceholder", defaultValue: "tt")
        static let triggerHint      = String(localized: "sheet.snippet.triggerHint", defaultValue: "Type this word + space in any app to expand the snippet.")
        static let contentPreview   = String(localized: "sheet.snippet.contentPreview", defaultValue: "Content preview")
        static let cancel           = String(localized: "sheet.snippet.cancel",     defaultValue: "Cancel")
        static let create           = String(localized: "sheet.snippet.createAction", defaultValue: "Create")
        static let save             = String(localized: "sheet.snippet.save",       defaultValue: "Save")
        static let remove           = String(localized: "sheet.snippet.remove",     defaultValue: "Remove Snippet")
    }

    // MARK: - Favorite sheet (6.8)
    enum FavoriteSheet {
        static let createTitle        = String(localized: "sheet.favorite.create", defaultValue: "Add to Favorites")
        static let editTitle          = String(localized: "sheet.favorite.edit",   defaultValue: "Edit Favorite")
        static let titleLabel         = String(localized: "sheet.favorite.title",        defaultValue: "Title")
        static let titlePlaceholder   = String(localized: "sheet.favorite.titlePlaceholder", defaultValue: "Optional — defaults to the clip itself")
        static let categoryLabel      = String(localized: "sheet.favorite.category",         defaultValue: "Category")
        static let categoryPlaceholder = String(localized: "sheet.favorite.categoryPlaceholder", defaultValue: "Type a category name (or pick from below)")
        static let categoryHint       = String(localized: "sheet.favorite.categoryHint",     defaultValue: "Categories you create will appear here next time.")
        static let categoryPickHelp   = String(localized: "sheet.favorite.categoryPickHelp", defaultValue: "Pick from existing categories")
        static let contentPreview     = String(localized: "sheet.favorite.contentPreview",   defaultValue: "Content")
        static let cancel             = String(localized: "sheet.favorite.cancel",   defaultValue: "Cancel")
        static let create             = String(localized: "sheet.favorite.save",     defaultValue: "Add Favorite")
        static let save               = String(localized: "sheet.favorite.update",   defaultValue: "Save")
        static let remove             = String(localized: "sheet.favorite.remove",   defaultValue: "Remove from Favorites")
    }

    // MARK: - Favorite category chips (6.8)
    enum FavoriteChips {
        static let all           = String(localized: "favoriteChips.all",           defaultValue: "All")
        static let uncategorized = String(localized: "favoriteChips.uncategorized", defaultValue: "Uncategorized")
    }

    // MARK: - Context menu
    enum Ctx {
        static let copy            = String(localized: "context.copy", defaultValue: "Copy")
        static let addFavorite     = String(localized: "context.addFavorite", defaultValue: "Add to Favorites")
        static let removeFavorite  = String(localized: "context.removeFavorite", defaultValue: "Remove from Favorites")
        static let makeSnippet     = String(localized: "context.makeSnippet", defaultValue: "Make Snippet…")
        static let editSnippet     = String(localized: "context.editSnippet", defaultValue: "Edit Snippet…")
        static let removeSnippet   = String(localized: "context.removeSnippet", defaultValue: "Remove Snippet")
    }

    // MARK: - Hotkey conflict
    enum HotkeyConflict {
        static let title    = String(localized: "hotkeyConflict.title", defaultValue: "Hotkey conflict")
        /// "⌘%@ is already taken by another app" format string.
        static func subtitle(_ shortcut: String) -> String {
            String(localized: "hotkeyConflict.subtitle", defaultValue: "⌘%@ is already taken by another app")
                .replacingOccurrences(of: "%@", with: shortcut)
        }
        static let change = String(localized: "hotkeyConflict.change", defaultValue: "Change…")
    }

    // MARK: - Hover preview
    enum Hover {
        static let openInBrowser  = String(localized: "hover.link.openInBrowser", defaultValue: "Open in Browser")
        static let usesSuffix     = String(localized: "hover.snippet.uses",        defaultValue: "uses")
        static let imageUnavailable = String(localized: "hover.imageUnavailable", defaultValue: "Image unavailable")
        static let fileMoved      = String(localized: "hover.fileMoved",           defaultValue: "File no longer at this path")
        static let fileOpenHint   = String(localized: "hover.fileOpenHint",        defaultValue: "Double-click to reveal in Finder")
        static let linkOpenHint   = String(localized: "hover.linkOpenHint",        defaultValue: "Double-click to open in browser")
    }

    // MARK: - Snippets window
    enum Snippets {
        static let title             = String(localized: "snippets.title",             defaultValue: "Snippets")
        static let searchPlaceholder = String(localized: "snippets.searchPlaceholder", defaultValue: "Search snippets")
        /// "Used N times" format string.
        static func usedTimes(_ n: Int) -> String {
            String(localized: "snippets.usedTimes", defaultValue: "Used \(n) times")
                .replacingOccurrences(of: "%lld", with: "\(n)")
        }
        /// "/trigger" trigger word prefix.
        static func triggerHint(_ word: String) -> String {
            "/" + word
        }
    }

    // MARK: - Toasts
    enum Toast {
        static let copied = String(localized: "toast.copied", defaultValue: "Copied")
    }

    // MARK: - Errors
    static let errorTitle = String(localized: "error.title", defaultValue: "Error")
}
