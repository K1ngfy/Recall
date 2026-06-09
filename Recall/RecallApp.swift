import SwiftUI
import SwiftData
import AppKit
import Carbon.HIToolbox

@main
struct RecallApp: App {
    @State private var theme = ThemeSettings.shared

    init() {
        // 0) Apply language preference: must take effect before Foundation initializes Bundle,
        //    so it must be set as the very first line of init().
        if let langRaw = UserDefaults.standard.string(forKey: UserDefaultsKeys.App.language),
           let lang = AppLanguage(rawValue: langRaw),
           let code = lang.appleLanguageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }

        // 1) 6.7 Apply "exclude from backup + FileProtection.complete" tags to legacy files.
        //    Runs once on the first launch after upgrade, and then on every launch — unlock is very fast.
        ClipStorageLocation.applyProtectionToExistingFiles()

        // 1) Start pasteboard monitor.
        AppEnvironment.shared.pasteboardMonitor.onNewItem = { result in
            ClipStore.shared.upsert(result)
        }
        AppEnvironment.shared.pasteboardMonitor.start()

        // 2) Register global hotkey (reads the custom value from UserDefaults, defaults to ⌥⌘V).
        let keyCode = UserDefaults.standard.object(forKey: UserDefaultsKeys.Hotkey.keyCode) as? UInt32 ?? UInt32(kVK_ANSI_V)
        let mods    = UserDefaults.standard.object(forKey: UserDefaultsKeys.Hotkey.modifiers) as? UInt32 ?? UInt32(cmdKey | optionKey)
        AppEnvironment.shared.hotkeyCenter.registerCustom(keyCode: keyCode, modifiers: mods) {
            AppEnvironment.shared.panelController.toggle()
        }

        // 3) After NSApp is ready, bind the panel weak reference + show onboarding.
        DispatchQueue.main.async {
            PanelLayout.markAppReady()      // Unlocks the lock-screen detection.
            AppEnvironment.shared.bindRecallPanel()
            OnboardingController.shared.showIfNeeded()
        }
    }

    var body: some Scene {
        // Onboarding is managed directly via AppKit NSWindow (not Window scene — unstable on macOS 26).

        MenuBarExtra(Strings.appName, systemImage: "doc.on.clipboard") {
            Button(Strings.MenuBar.show) { AppEnvironment.shared.panelController.toggle() }
            Divider()
            Button(Strings.MenuBar.welcome) { OnboardingController.shared.showForced() }
            Divider()
            Button(Strings.MenuBar.settings) { openSettings() }
            Divider()
            Button(Strings.MenuBar.quit) { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)

        // Before 6.7 we used a SwiftUI Settings scene + raised its level afterwards, but in practice
        // the SwiftUI Settings window can still be covered by a .floating panel on some macOS 26 paths.
        // Switched to fully self-managed: use AppKit NSWindow + level=.modalPanel (100), always above .floating (3).
        // See SettingsWindowController.

        // ⌘F globally focuses the search field. Recall is LSUIElement=true so the menu bar is hidden,
        // but CommandMenu still responds to key events dispatched by KeyboardShortcut.
        // See the FocusedValueKey bridge in SearchField.swift.
        .commands {
            CommandMenu("Edit") {
                FindInRecallButton()
            }
        }
    }

    private func openSettings() {
        // 6.7 Switched to self-managed NSWindow — level = .modalPanel is always above the .floating main panel.
        SettingsWindowController.shared.show()
    }
}

/// ⌘F button: gets the current SearchField's focus binding from FocusedValue,
/// sets it to true to trigger focus. If the panel is not yet shown, falls back to opening the panel.
private struct FindInRecallButton: View {
    @FocusedValue(\.recallSearchFocus) private var focusBinding

    var body: some View {
        Button(Strings.Settings.findInRecall) {
            if let focusBinding {
                focusBinding.wrappedValue = true
            } else {
                AppEnvironment.shared.panelController.show()
            }
        }
        .keyboardShortcut("f", modifiers: .command)
    }
}
