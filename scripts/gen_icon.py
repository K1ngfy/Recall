#!/usr/bin/env python3
"""Generate Recall's app icon: minimalist geometric design.

Design language (per user request "简约的几何图案"):
- Rounded square background (macOS auto-applies the squircle mask; we still
  design inside a 1024x1024 canvas with a soft 180pt corner radius)
- Subtle vertical gradient (top lighter, bottom darker) for depth
- Three horizontal "history entries" representing the clipboard stack
  - Two smaller, faded, offset behind (older entries)
  - One larger, accent-colored, on top (latest/active)
- Accent color: indigo/blue (matches Recall's default theme)

The geometry is intentionally simple: 3 stacked rounded rectangles. This
echoes "recall = look back at history" without literal clipboard imagery.
"""
from PIL import Image, ImageDraw
import os

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "Recall", "Assets.xcassets", "AppIcon.appiconset",
)
OUT_DIR = os.path.normpath(OUT_DIR)

SIZE = 1024
CORNER_RADIUS = 230   # ~22.5% — close to macOS squircle, slightly tighter for design clarity

# Indigo / blue palette
BG_TOP    = (102, 116, 240)   # softer indigo
BG_BOTTOM = ( 64,  78, 200)   # deeper indigo

# Three history rows
ENTRY_BG       = (255, 255, 255, 230)  # semi-transparent white
ENTRY_BG_OLD   = (255, 255, 255, 130)
ENTRY_BG_OLDER = (255, 255, 255,  80)
ACCENT         = (245, 101,  98)      # warm coral — the "latest" entry

ROUND = 56  # corner radius of the inner history rectangles

def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Rounded square background with vertical gradient.
    #    macOS will further apply its own squircle mask; this is the
    #    design intent that shows through the mask.
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t)
        bg_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    # Apply rounded square alpha
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=CORNER_RADIUS, fill=255
    )
    bg.putalpha(mask)
    img.paste(bg, (0, 0), bg)

    draw = ImageDraw.Draw(img)

    # 2. Three stacked history rows. Center-anchored horizontally, slightly
    #    below center vertically so the visual mass feels grounded.
    cx = size // 2
    cy = int(size * 0.52)
    row_h   = int(size * 0.13)        # latest row height
    gap     = int(size * 0.045)       # vertical spacing between rows
    w_latest  = int(size * 0.62)     # widest (front)
    w_mid     = int(size * 0.50)
    w_oldest  = int(size * 0.38)     # narrowest (back)

    def row(cy_offset, w, h, color):
        x0 = cx - w // 2
        y0 = cy + cy_offset - h // 2
        x1 = cx + w // 2
        y1 = cy + cy_offset + h // 2
        draw.rounded_rectangle([x0, y0, x1, y1], radius=ROUND, fill=color)

    # 3. Back row (oldest) — smallest, most faded
    row(cy_offset=-(row_h + gap), w=w_oldest, h=row_h, color=ENTRY_BG_OLDER)
    # 4. Middle row — slightly larger
    row(cy_offset=0, w=w_mid, h=row_h, color=ENTRY_BG_OLD)
    # 5. Front row (latest) — accent colored, largest
    row(cy_offset=row_h + gap, w=w_latest, h=row_h, color=ACCENT)

    return img

def main():
    targets = [
        ("icon_16x16.png",   16),
        ("icon_32x32.png",   32),
        ("icon_64x64.png",   64),
        ("icon_128x128.png", 128),
        ("icon_256x256.png", 256),
        ("icon_512x512.png", 512),
        ("icon_1024x1024.png", 1024),
    ]
    base = make_icon(SIZE)
    for name, sz in targets:
        out = base.resize((sz, sz), Image.LANCZOS)
        path = os.path.join(OUT_DIR, name)
        out.save(path, "PNG")
        print(f"  wrote {path}")
    print("done.")

if __name__ == "__main__":
    main()
