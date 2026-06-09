import SwiftUI
import Carbon.HIToolbox
import AppKit

/// Recall settings center
struct SettingsRootView: View {
    @Bindable private var theme = ThemeSettings.shared
    @State private var retention: RetentionOption = RetentionOption.load()
    @State private var dockPosition: PanelDockPosition = DockPositionOption.load()
    @State private var customHexInput: String = ThemeSettings.shared.customAccentHex ?? ""
    @State private var language: AppLanguage = Self.loadLanguage()
    @State private var showLanguageRestartHint = false
    @State private var selectedTab: SettingsTab = .general
    /// 6.9 Storage tab 的"一键清空"二次确认 alert
    @State private var showClearAllConfirm = false
    /// 6.9 Storage tab 的"已清除 N 项"短暂 toast 文案,3 秒后清空
    @State private var clearAllToast: String?
    /// 6.9 Hover 预览开关:与 HoverPreviewModifier 共享同一个 @AppStorage key
    @AppStorage(UserDefaultsKeys.Preview.hoverEnabled) private var hoverPreviewEnabled: Bool = true

    private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
        case general, appearance, storage, hotkey
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .general:    return Strings.Settings.tabGeneral
            case .appearance: return Strings.Settings.tabAppearance
            case .storage:    return Strings.Settings.tabStorage
            case .hotkey:     return Strings.Settings.tabHotkey
            }
        }
        var systemImage: String {
            switch self {
            case .general:    return "gear"
            case .appearance: return "paintbrush"
            case .storage:    return "tray.full"
            case .hotkey:     return "command"
            }
        }
    }

    private static func loadLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.App.language) ?? ""
        return AppLanguage(rawValue: raw) ?? .system
    }

    var body: some View {
        // Before 6.7 we used SwiftUI TabView + tabItem expecting macOS to auto-render
        // a tab bar, but the self-managed NSHostingController lacks window context,
        // so the tab bar didn't render — only the first page showed.
        // Switched to a manual Picker(.segmented) tab switch: works under any window context,
        // and is visually more compact (and better looking) than the SwiftUI default tab bar.
        VStack(spacing: 0) {
            tabBar
            Divider().opacity(0.3)
            Group {
                switch selectedTab {
                case .general:    generalTab
                case .appearance: appearanceTab
                case .storage:    storageTab
                case .hotkey:     hotkeyTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 440, minHeight: 320)
    }

    private var tabBar: some View {
        // 6.7.2: horizontal HStack keeps icon + label on the same line
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 18)    // 6.7.2: enlarged top spacing
        .padding(.bottom, 10)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = (selectedTab == tab)
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {                       // 6.7.2: same row
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(tab.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
                    .padding(.horizontal, 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section(Strings.Settings.dockPosition) {
                Picker("Position", selection: $dockPosition) {
                    ForEach(PanelDockPosition.allCases) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: dockPosition) { _, new in
                    DockPositionOption.save(new)
                    AppEnvironment.shared.panelController.setDockPosition(new)
                }
            }
            Section(Strings.Settings.language) {
                Picker(Strings.Settings.languageRow, selection: $language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .onChange(of: language) { _, new in
                    UserDefaults.standard.set(new.rawValue, forKey: UserDefaultsKeys.App.language)
                    showLanguageRestartHint = true
                }
                if showLanguageRestartHint {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(Strings.Settings.languageRestartHint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(Strings.Settings.restartNow) {
                            // Restart Recall itself to apply the new language.
                            //
                            // Why not use NSWorkspace.openApplication(Bundle.main.bundleURL)?
                            //   In a Debug build the .app path lives in DerivedData/.../Recall.app,
                            //   which isn't registered with LaunchServices — openApplication silently fails.
                            //
                            // The right approach is to invoke the system /usr/bin/open -n:
                            //   - `-n` forces a new instance
                            //   - Going through the system `open` command takes LaunchServices'
                            //     fallback path, which works for both dev and release.
                            //   - Process.run() blocks until exec is launched; terminate after it returns.
                            let task = Process()
                            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                            task.arguments = ["-n", Bundle.main.bundleURL.path]
                            do {
                                try task.run()
                            } catch {
                                AppLog.general.error("Failed to spawn open: \(error.localizedDescription, privacy: .public)")
                            }
                            NSApp.terminate(nil)
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
            // 6.9 Hover preview 行为开关
            Section(Strings.Settings.hoverPreviewSection) {
                Toggle(Strings.Settings.hoverPreviewToggle, isOn: $hoverPreviewEnabled)
                Text(Strings.Settings.hoverPreviewDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appearanceTab: some View {
        Form {
            Section(Strings.Settings.theme) {
                themeGrid
                opacitySlider
                if theme.theme == .custom {
                    customHexSection
                }
            }
            Section(Strings.Settings.appearanceSection) {
                Picker(Strings.Settings.appearanceMode, selection: $theme.forcedScheme) {
                    ForEach(ForcedScheme.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            // Live preview: apply the current accent to a few representative spots in the main panel,
            // so changing the Picker above updates them instantly and you can see where it takes effect.
            Section(Strings.Settings.preview) {
                VStack(alignment: .leading, spacing: 10) {
                    // 1) Snippet trigger word label (matches SnippetRow)
                    HStack(spacing: 8) {
                        Text("/test")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.18))
                            )
                        Text(Strings.Settings.previewTriggerWord)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    // 2) Selected-state pill (matches DateFilterChips / CategoryTabs)
                    HStack(spacing: 8) {
                        Text(Strings.Tab.all)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.18))
                            )
                        Text(Strings.Settings.previewSelectedTab)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    // 3) Primary action button (matches SnippetTriggerSheet Create)
                    HStack(spacing: 8) {
                        Button(Strings.SnippetSheet.create) {}
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Text(Strings.Settings.previewPrimaryAction)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            Section(Strings.Settings.appearanceSection) {
                Picker(Strings.Settings.appearanceMode, selection: $theme.forcedScheme) {
                    ForEach(ForcedScheme.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
        // Key: inject the current accent into this tab's tint environment
        // so that Color.accentColor inside the Section tracks the user's choice live.
        .tint(theme.resolvedAccentColor)
    }

    /// Theme preset grid — 3-column layout; each cell is a mini preview (rounded rect + accent dot)
    private var themeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ], spacing: 8) {
            ForEach(PanelTheme.allCases) { t in
                themeCard(t)
            }
        }
    }

    private func themeCard(_ t: PanelTheme) -> some View {
        let isSelected = theme.theme == t
        return Button {
            theme.theme = t
        } label: {
            VStack(spacing: 4) {
                // Mini preview: rounded rect + matching background
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(previewBackground(for: t))
                    .frame(height: 36)
                    .overlay(
                        // Accent color dot
                        Circle()
                            .fill(t == .custom && theme.customAccentHex != nil
                                  ? (HexColor.parse(theme.customAccentHex ?? "") ?? t.accent)
                                  : t.accent)
                            .frame(width: 10, height: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2),
                                          lineWidth: isSelected ? 1.5 : 0.5)
                    )
                Text(themeDisplayName(t))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            // 6.8 fix: Custom 主题的 background = Color.clear,SwiftUI 中透明 fill 不参与
            // hit-test → 整张卡片点了没反应。强制把 label 的整个 frame 当 hit area。
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 主题卡片的预览底色。.custom 走特殊路径:
    /// - 用户填了 customBackgroundHex → 用 hex 色实际预览
    /// - 没填 → 用浅灰占位(代替 Color.clear),既给 hit-test 实色,又视觉上像"待自定义"
    private func previewBackground(for t: PanelTheme) -> AnyShapeStyle {
        if t == .custom {
            if let hex = theme.customBackgroundHex, let color = HexColor.parse(hex) {
                return AnyShapeStyle(color.opacity(0.85))
            }
            return AnyShapeStyle(Color.primary.opacity(0.06))
        }
        return t.background(opacity: 0.85)
    }

    /// Opacity slider 0.5 - 1.0. With the .system theme + regularMaterial there is no visual change;
    /// it's mainly for the gradient themes — sliding to 0.5 reveals the desktop wallpaper.
    private var opacitySlider: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Slider(value: Binding(
                get: { theme.panelOpacity },
                set: { theme.panelOpacity = $0 }
            ), in: 0.5...1.0)
            Text(String(format: "%.0f%%", theme.panelOpacity * 100))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.top, 4)
    }

    /// Hex dual input for the Custom theme: accent + background
    private var customHexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            customHexInputRow(
                title: Strings.Settings.customAccent,
                placeholder: "#FF6B6B",
                text: Binding(
                    get: { theme.customAccentHex ?? "" },
                    set: { theme.customAccentHex = $0.isEmpty ? nil : $0 }
                )
            )
            customHexInputRow(
                title: Strings.Settings.customBackground,
                placeholder: "#1E1B4B",
                text: Binding(
                    get: { theme.customBackgroundHex ?? "" },
                    set: { theme.customBackgroundHex = $0.isEmpty ? nil : $0 }
                )
            )
        }
        .padding(.top, 6)
    }

    private func customHexInputRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = trimmed.isEmpty || HexColor.parse(trimmed) != nil
        return HStack(spacing: 8) {
            // Live preview swatch
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isValid && !trimmed.isEmpty
                      ? (HexColor.parse(trimmed) ?? .gray)
                      : Color.gray.opacity(0.2))
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isValid ? Color.secondary.opacity(0.2) : .red.opacity(0.6), lineWidth: 0.5)
                )
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            if !isValid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 11))
            }
        }
    }

    private func themeDisplayName(_ t: PanelTheme) -> String {
        switch t {
        case .system:     return Strings.Settings.themeSystem
        case .aurora:     return Strings.Settings.themeAurora
        case .sunset:     return Strings.Settings.themeSunset
        case .ocean:      return Strings.Settings.themeOcean
        case .forest:     return Strings.Settings.themeForest
        case .graphite:   return Strings.Settings.themeGraphite
        case .custom:     return Strings.Settings.themeCustom
        }
    }

    private var storageTab: some View {
        Form {
            Section(Strings.Settings.retention) {
                Picker("Keep history for", selection: $retention) {
                    ForEach(RetentionOption.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .onChange(of: retention) { _, new in
                    RetentionOption.save(new)
                }
                Text(Strings.Settings.retentionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 6.8 一键清空:destructive 操作走 .alert 二次确认,不在主流程里直接执行。
            Section(Strings.Settings.resetSection) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Strings.Settings.clearAllDataDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(role: .destructive) {
                            showClearAllConfirm = true
                        } label: {
                            Label(Strings.Settings.clearAllData, systemImage: "trash")
                        }
                        if let toast = clearAllToast {
                            Text(toast)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert(Strings.Settings.clearAllDataConfirmTitle, isPresented: $showClearAllConfirm) {
            Button(Strings.Settings.clearAllDataConfirmAction, role: .destructive) {
                let removed = ClipStore.shared.wipeAll()
                withAnimation(.easeOut(duration: 0.2)) {
                    clearAllToast = Strings.Settings.clearAllDataToast(removed)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        clearAllToast = nil
                    }
                }
            }
            Button(Strings.Settings.clearAllDataCancel, role: .cancel) { }
        } message: {
            Text(Strings.Settings.clearAllDataConfirmMessage)
        }
    }

    private var hotkeyTab: some View {
        Form {
            Section(Strings.Settings.hotkeyTitle) {
                LabeledContent(Strings.Settings.hotkeyShowHide) {
                    HStack(spacing: 8) {
                        ShortcutRecorder(
                            keyCode: $customKeyCode,
                            modifiers: $customModifiers
                        )
                        .onChange(of: customKeyCode) { _, _ in saveHotkey() }
                        .onChange(of: customModifiers) { _, _ in saveHotkey() }

                        Button(Strings.Settings.hotkeyReset) {
                            customKeyCode = Int(kVK_ANSI_C)
                            customModifiers = Int(cmdKey | optionKey)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                Text(Strings.Settings.hotkeyHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @AppStorage(UserDefaultsKeys.Hotkey.keyCode) private var customKeyCode: Int = Int(kVK_ANSI_C)
    @AppStorage(UserDefaultsKeys.Hotkey.modifiers) private var customModifiers: Int = Int(cmdKey | optionKey)

    private func saveHotkey() {
        AppEnvironment.shared.hotkeyCenter.registerCustom(
            keyCode: UInt32(customKeyCode),
            modifiers: UInt32(customModifiers)
        ) {
            AppEnvironment.shared.panelController.toggle()
        }
    }
}

// MARK: - Persistence helpers

enum RetentionOption: String, CaseIterable, Identifiable, Codable {
    case oneDay, sevenDays, thirtyDays, forever
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneDay:     return "1 day"
        case .sevenDays:  return "7 days"
        case .thirtyDays: return "30 days"
        case .forever:    return "Forever"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .oneDay:     return 86_400
        case .sevenDays:  return 604_800
        case .thirtyDays: return 2_592_000
        case .forever:    return nil
        }
    }

    static let key = "retention.option"
    static func load() -> RetentionOption {
        let raw = UserDefaults.standard.string(forKey: key) ?? RetentionOption.sevenDays.rawValue
        return RetentionOption(rawValue: raw) ?? .sevenDays
    }
    static func save(_ v: RetentionOption) {
        UserDefaults.standard.set(v.rawValue, forKey: key)
    }
}

enum DockPositionOption {
    static let key = UserDefaultsKeys.Panel.dockPosition
    static func load() -> PanelDockPosition {
        let raw = UserDefaults.standard.string(forKey: key) ?? PanelDockPosition.right.rawValue
        return PanelDockPosition(rawValue: raw) ?? .right
    }
    static func save(_ v: PanelDockPosition) {
        UserDefaults.standard.set(v.rawValue, forKey: key)
    }
}
