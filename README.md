# Recall

> macOS 原生剪贴板历史管理工具。本地优先、隐私安全、极简 Apple HIG 设计。

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 核心特性

- 📋 **全局监听** —— 后台静默监听 NSPasteboard，文本 / 链接 / 图片 / 文件 / 收藏自动分类
- ⚡ **极速唤起** —— 默认 `⌥⌘C` 220ms 滑入面板，**可自定义快捷键**
- 🎯 **自动粘贴** —— 双击 / Enter 直接插入到任意输入框（AX + CGEvent ⌘V 降级链）
- 📌 **钉住模式** —— 避免误点击外部自动关闭
- ⭐ **收藏** —— 永久收藏重要条目（不被自动清理），独立入口查看
- 📁 **Files 分类** —— 复制 Finder 里的 PDF / Word / txt / 视频等文件，Recall 记录系统图标 + 完整路径
- 📝 **Snippets 触发词** —— 把常用文本存为 snippet，输入 `/trigger ` 自动展开
- 🧹 **批量操作** —— Cmd+Click 多选 → 批量复制 / 删除
- 🎨 **极简主题** —— 8 种高亮色 + 强制明暗模式 + Liquid Glass 风格
- 🔒 **本地优先 + 备份隔离** —— 所有数据存本地，零网络请求；store / 图片文件**排除 iCloud + Time Machine 备份**，避免敏感剪贴板内容外溢到备份磁盘
- 🧽 **自动清理** —— Settings 里可设保留 7 天 / 30 天 / 无限期（收藏 / Snippet 永不被清）

## 🏗 架构

```
Recall/
├── App/
│   └── AppEnvironment.swift         # 全局依赖容器
├── Core/
│   ├── Common.swift                 # Logger / RelativeTime / URL Safety
│   └── UserDefaultsKeys.swift       # UserDefaults 键名集中
├── Models/
│   ├── ClipItem.swift               # @Model 实体（含 isFavorite / isSnippet / triggerWord）
│   ├── ClipContentType.swift        # 分类枚举（text/image/link/file/snippet）
│   └── ClipStorageLocation.swift    # 文件路径 + 排除备份
├── Services/
│   ├── PasteboardMonitor.swift      # 0.5s 轮询 + debounce
│   ├── ClipItemBuilder.swift        # pasteboard → 分类（含文件扩展名白名单）
│   ├── ClipStore.swift              # SwiftData 封装（upsert / favorite / retention）
│   ├── ImageThumbnailActor.swift    # actor 异步大图缩略图
│   ├── SnippetService.swift         # Snippet 触发词匹配 + 5s 缓存
│   ├── PasteService.swift           # AX + CGEvent 降级链
│   └── PermissionCenter.swift       # 权限轮询
├── Persistence/
│   └── RecallStoreSchema.swift      # ModelContainer 工厂
├── ViewModels/
│   └── ListViewModel.swift          # 列表 VM（filter/dateRange/searchText/snippets）
├── Window/
│   ├── RecallPanel.swift            # NSPanel 子类
│   ├── RecallPanelController.swift  # 业务控制器（show/hide/click-outside/esc）
│   ├── PanelLayout.swift            # 布局计算（docking + adjacent frame）
│   └── PanelDockPosition.swift      # 4 个停靠方向
├── Hotkey/
│   ├── GlobalHotkeyCenter.swift     # Carbon 热键
│   └── ShortcutRecorder.swift       # 录制 UI
├── Hover/
│   └── PreviewCoordinator.swift     # hover preview popover
├── Onboarding/
│   ├── OnboardingView.swift         # 引导 UI
│   └── OnboardingController.swift   # 引导 NSWindow
├── Snippets/
│   ├── SnippetsView.swift           # Snippet 管理 UI
│   ├── SnippetsController.swift     # Snippet 弹窗控制器
│   └── SnippetsWindow.swift         # 毛玻璃样式容器
├── Views/
│   ├── RecallRootView.swift
│   ├── ClipRow.swift / ClipCard.swift
│   ├── CategoryTabs.swift           # All/Text/Image/Link/File + Favorites
│   ├── DateFilterChips.swift        # Anytime/Today/Past week/Past month
│   ├── BatchActionBar.swift         # 多选时底部批量操作栏
│   ├── EmptyStateView.swift         # 各分类空状态
│   ├── FileIconView.swift           # 系统文件图标
│   ├── PermissionBanner.swift       # 权限缺失 / Secure Input 提示
│   ├── SearchField.swift            # 搜索框
│   ├── SnippetTriggerSheet.swift    # 创建/编辑 Snippet sheet
│   ├── ThumbnailView.swift          # 图片缩略图
│   └── SettingsRootView.swift       # 设置中心
├── Theme/
│   ├── AccentPalette.swift          # 8 种高亮色
│   └── ThemeSettings.swift          # @Observable 单例
├── Assets.xcassets/
│   └── AppIcon.appiconset/          # 1024×1024
├── scripts/
│   ├── gen_icon.swift               # 图标生成脚本
│   └── diagnose_screens.swift       # 多屏诊断工具
└── RecallApp.swift                  # @main
```

## 🔧 技术栈

| 层 | 选型 | 原因 |
|---|---|---|
| UI | SwiftUI 主导 + AppKit 兜底 | 极简现代 + 无窗口失控 |
| 窗口 | NSPanel + NSHostingController | borderless + 滑入动画 + 不抢主窗口焦点 |
| 数据 | SwiftData (macOS 26+) | 零迁移成本 + 类型安全 + 轻量级迁移 |
| 全局热键 | Carbon HIToolbox (零依赖) | 比 KeyboardShortcuts 包更轻 |
| 自动粘贴 | AX API + CGEvent ⌘V 降级链 | Secure Input 兜底 |
| 链接抓取 | **无**（零网络请求铁律） | 仅本地解析 `linkHost` |
| 日志 | os.Logger | 替代 print，性能更好 |

## ⚙️ 系统要求

- **macOS 26.0+ (Tahoe)** —— 最低部署目标
- **Apple Silicon / Intel x86_64**
- **辅助功能权限** —— 自动粘贴需要
- **输入监控权限** —— 全局快捷键 / click-outside 监听需要

## 🔨 构建

```bash
# 安装 xcodegen（一次性）
brew install xcodegen

# 生成 .xcodeproj（新增/删除 swift 文件后必须重跑）
xcodegen generate

# 构建
xcodebuild -project Recall.xcodeproj -scheme Recall -configuration Debug build

# 启动
open /Users/$USER/Library/Developer/Xcode/DerivedData/Recall-*/Build/Products/Debug/Recall.app
```

## 🔐 权限申请

第一次启动：
1. 引导页第二页会引导你授权**辅助功能**
2. macOS 弹窗 → 打开**系统设置 → 隐私与安全 → 辅助功能** → 勾选 Recall

辅助功能未授权时：
- 自动粘贴 → 降级为仅复制 + ⌘V 模拟（Secure Input 模式下失败）
- 仍可手动粘贴（Cmd+V）使用 Recall

## 🛡 隐私

- ✅ **零网络请求**（Recall 本身不发任何 outbound request；打开链接走 `NSWorkspace.shared.open` 交给系统）
- ✅ 数据存 `~/Library/Application Support/Recall/`，SwiftData + 外置图片
- ✅ **备份隔离**：每个 store / image 文件**排除 iCloud / Time Machine 备份**，敏感剪贴板内容不会被备份磁盘带走
- ⚠️ **未做磁盘加密**：数据库与图片以明文存于本地。同一用户身份下运行的其他进程（包括恶意软件）可直接读取。如需更强保障，请使用 FileVault 全盘加密或考虑应用层加密扩展
- ✅ 卸载 app = 全部数据删除（无云同步、无遥测）
- ✅ 全局热键、click-outside 监听需要 macOS 权限授权

## 📜 许可

MIT License. 详见 [LICENSE](LICENSE).
