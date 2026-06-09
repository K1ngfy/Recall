#!/usr/bin/env swift
// 诊断多屏配置——不需要 Recall 跑起来，直接用 Swift 打印
import AppKit

print("=== NSScreen 诊断 ===")
print("屏幕数: \(NSScreen.screens.count)")
for (i, s) in NSScreen.screens.enumerated() {
    let isMain = (s == NSScreen.main) ? " [主屏]" : ""
    print("屏幕[\(i)]\(isMain):")
    print("  frame:        \(s.frame)")
    print("  visibleFrame: \(s.visibleFrame)")
    print("  backingScaleFactor: \(s.backingScaleFactor)")
    print("  localizedName: \(s.localizedName)")
}
print()
print("NSScreen.main: \(String(describing: NSScreen.main))")
print()
let mouse = NSEvent.mouseLocation
print("Mouse 位置: \(mouse)")
if let s = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
    print("Mouse 所在屏: \(s.localizedName)")
} else {
    print("Mouse 不在任何屏")
}
