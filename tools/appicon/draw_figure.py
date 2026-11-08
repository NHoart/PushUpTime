#!/usr/bin/env python3
"""Zeichnet eine Liegestütz-Silhouette (Seitenansicht, Stützposition) als Alpha-Maske.

Kompakte Stützposition: gerader Körper, senkrechter Arm unter der Brust,
Beine nach hinten ausgestreckt, Zehen und Hand auf einem kurzen Bodenstrich.
Ergebnis: tools/appicon/custom-pushup.png (Alpha = Form) + Vorschauen.
"""
import os

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4  # Supersampling

W, H = 1200, 560

# --- Geometrie in Design-Koordinaten, Bodenlinie y = 448
GROUND = 448
HEAD = (348, 200, 52)              # cx, cy, r
NECK = ([(390, 218), (446, 244)], 42)
BODY = ([(452, 250), (716, 300)], 62)          # Schulter -> Hüfte
LEGS = ([(716, 300), (846, 322), (952, 342)], 46)
SHIN = ([(952, 342), (968, 420)], 38)          # Unterschenkel/Fuß aufgestellt
ARM = ([(488, 264), (526, 344), (492, 406)], 44)   # Schulter -> Ellbogen -> Hand
HAND = (488, 424, 24)
FLOOR = ([(470, GROUND), (1010, GROUND)], 14, 150)  # Bodenstrich, halbtransparent


def stroke(draw, pts, width):
    pts = [(x * S, y * S) for x, y in pts]
    draw.line(pts, fill=255, width=width * S, joint="curve")
    r = width * S / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=255)


def build():
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)

    for pts, width in (LEGS, SHIN, BODY, ARM):
        stroke(d, pts, width)
    hx, hy, hr = HAND
    d.ellipse([(hx - hr) * S, (hy - hr) * S, (hx + hr) * S, (hy + hr) * S], fill=255)
    stroke(d, *NECK)
    cx, cy, r = HEAD
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)

    floor = Image.new("L", (W * S, H * S), 0)
    pts, width, alpha = FLOOR
    stroke(ImageDraw.Draw(floor), pts, width)
    floor = floor.point(lambda p: int(p * alpha / 255))
    mask = ImageChops.lighter(mask, floor)

    return mask.resize((W, H), Image.LANCZOS)


def main():
    mask = build()
    glyph = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    glyph.putalpha(mask)
    glyph = glyph.crop(mask.getbbox())
    glyph.save(os.path.join(HERE, "custom-pushup.png"))

    pad = 36
    prev = Image.new("RGB", (glyph.width + 2 * pad, glyph.height + 2 * pad), (14, 16, 26))
    prev.paste(glyph, (pad, pad), glyph)
    prev.save(os.path.join(HERE, "custom-pushup-preview.png"))

    sizes = [180, 120, 80, 60]
    strip = Image.new("RGB", (sum(sizes) + 10 * (len(sizes) + 1), 200), (14, 16, 26))
    x = 10
    for s in sizes:
        h = max(1, int(glyph.height * s / glyph.width))
        small = glyph.resize((s, h), Image.LANCZOS)
        strip.paste(small, (x, 10 + (190 - h) // 2), small)
        x += s + 10
    strip.save(os.path.join(HERE, "custom-pushup-sizes.png"))
    print(f"geschrieben: custom-pushup.png {glyph.size}")


if __name__ == "__main__":
    main()
