// gen_icon.swift
// 用 Swift 运行时绘制 Recall 应用图标，输出 1024×1024 PNG。
// 运行：swift scripts/gen_icon.swift

import AppKit
import Foundation

final class IconRenderer {
    let size: CGFloat

    init(size: CGFloat) {
        self.size = size
    }

    func render() -> NSImage? {
        let s = size
        let img = NSImage(size: NSSize(width: s, height: s))
        img.lockFocus()
        defer { img.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

        // ---------- 1) 渐变背景 ----------
        let bgColors = [
            NSColor(red: 0.20, green: 0.18, blue: 0.55, alpha: 1.0).cgColor,
            NSColor(red: 0.42, green: 0.30, blue: 0.80, alpha: 1.0).cgColor,
            NSColor(red: 0.65, green: 0.30, blue: 0.85, alpha: 1.0).cgColor
        ]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: bgColors as CFArray,
            locations: [0.0, 0.55, 1.0]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: s, y: s),
            options: []
        )

        // ---------- 2) 顶部柔光 ----------
        let highlight = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.22).cgColor,
                NSColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(
            highlight,
            startCenter: CGPoint(x: s * 0.5, y: s * 0.95),
            startRadius: 0,
            endCenter: CGPoint(x: s * 0.5, y: s * 0.95),
            endRadius: s * 0.7,
            options: []
        )

        // ---------- 3) 剪贴板主体 ----------
        let clipW = s * 0.52
        let clipH = s * 0.66
        let clipX = (s - clipW) / 2
        let clipY = (s - clipH) / 2 - s * 0.02
        let clipRect = NSRect(x: clipX, y: clipY, width: clipW, height: clipH)
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipW * 0.14, yRadius: clipW * 0.14)
        NSColor.white.withAlphaComponent(0.96).setFill()
        clipPath.fill()

        // 剪贴板顶部夹子
        let clipW2 = clipW * 0.35
        let clipH2 = clipH * 0.10
        let clipX2 = clipX + (clipW - clipW2) / 2
        let clipY2 = clipY + clipH - clipH2
        let clipPath2 = NSBezierPath(roundedRect: NSRect(x: clipX2, y: clipY2, width: clipW2, height: clipH2), xRadius: 4, yRadius: 4)
        NSColor.white.withAlphaComponent(0.95).setFill()
        clipPath2.fill()
        // 夹子阴影
        NSColor.black.withAlphaComponent(0.08).setFill()
        clipPath2.fill()

        // ---------- 4) 文本行 ----------
        let lineX = clipX + clipW * 0.13
        let lineR = clipW * 0.74
        let lineTopY = clipY + clipH * 0.66
        let lineH = clipH * 0.06
        let lineSpacing = lineH * 1.8
        let lineColors: [NSColor] = [
            NSColor(red: 0.40, green: 0.30, blue: 0.75, alpha: 1.0),
            NSColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0),
            NSColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 1.0),
            NSColor(red: 0.85, green: 0.45, blue: 0.55, alpha: 1.0)
        ]
        for i in 0..<4 {
            let y = lineTopY - CGFloat(i) * lineSpacing
            let w = lineR * (i == 1 ? 0.65 : (i == 3 ? 0.55 : 1.0))
            let rect = NSRect(x: lineX, y: y, width: w, height: lineH)
            let path = NSBezierPath(roundedRect: rect, xRadius: lineH / 2, yRadius: lineH / 2)
            lineColors[i].withAlphaComponent(0.78).setFill()
            path.fill()
        }

        // ---------- 5) 回旋箭头（左下）暗示 history ----------
        let ringRadius = s * 0.13
        let ringCenter = CGPoint(x: s * 0.28, y: s * 0.27)
        let ringLineWidth = ringRadius * 0.18

        ctx.saveGState()
        ctx.setLineWidth(ringLineWidth)
        ctx.setLineCap(.round)
        NSColor.white.withAlphaComponent(0.85).setStroke()

        // 画 270° 弧（从底部往上右）
        let startAngle: CGFloat = .pi * 1.25   // 225°
        let endAngle: CGFloat   = .pi * 0.0    // 0°
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: ringCenter,
            radius: ringRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        ctx.addPath(arc.cgPath)
        ctx.strokePath()

        // 箭头
        let arrowSize = ringRadius * 0.32
        let arrowTip = CGPoint(
            x: ringCenter.x + ringRadius * cos(endAngle),
            y: ringCenter.y + ringRadius * sin(endAngle)
        )
        let arrowPath = NSBezierPath()
        arrowPath.move(to: CGPoint(x: arrowTip.x + arrowSize * 0.6, y: arrowTip.y))
        arrowPath.line(to: arrowTip)
        arrowPath.line(to: CGPoint(x: arrowTip.x, y: arrowTip.y + arrowSize * 0.6))
        NSColor.white.withAlphaComponent(0.9).setStroke()
        arrowPath.lineWidth = ringLineWidth * 0.95
        arrowPath.stroke()
        ctx.restoreGState()

        // ---------- 6) 高光叠加（顶部） ----------
        let topHighlight = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.18).cgColor,
                NSColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray,
            locations: [0.0, 0.5]
        )!
        ctx.saveGState()
        let topRect = NSRect(x: 0, y: s * 0.55, width: s, height: s * 0.45)
        ctx.clip(to: topRect)
        ctx.drawLinearGradient(
            topHighlight,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: 0, y: s * 0.5),
            options: []
        )
        ctx.restoreGState()

        return img
    }
}

// ---------- 保存 PNG ----------
func savePNG(_ image: NSImage, to url: URL, size: CGFloat) throws {
    let s = size
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(s),
        pixelsHigh: Int(s),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!
    rep.size = NSSize(width: s, height: s)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    image.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
    print("✓ \(url.path) (\(Int(s))x\(Int(s)))")
}

// ---------- 主流程 ----------
let outDir = URL(fileURLWithPath: "/Users/ricklee/code/Recall/Recall/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// 渲染一次 1024
let master = IconRenderer(size: 1024).render()!

// macOS AppIcon 需要 16, 32, 64, 128, 256, 512, 1024
let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    let img = IconRenderer(size: s).render()!
    try savePNG(img, to: outDir.appendingPathComponent("icon_\(Int(s))x\(Int(s)).png"), size: s)
}

// 主 AppIcon 用 1024
try savePNG(master, to: outDir.appendingPathComponent("AppIcon.png"), size: 1024)

print("\n所有图标生成完成。")
