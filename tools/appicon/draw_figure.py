#!/usr/bin/env python3
"""Zeichnet eine Liegestütz-Silhouette (Seitenansicht, Stützposition) als Alpha-Maske.

Ergebnis: tools/appicon/custom-pushup.png  (weißes Glyph auf transparentem Grund,
Alpha = Form) sowie tools/appicon/custom-pushup-preview.png (auf dunklem Grund).
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4  # Supersampling

W, H = 1200, 560

# --- Geometrie in Design-Koordinaten (Grundlinie der Hände/Füße ca. y=470)
GROUND = 470
HEAD = (372, 214, 66)            # cx, cy, r
NECK = [(404, 236), (444, 252)]  # Hals: Kopf -> Schulter
NECK_W = 58
BODY = [(475, 272), (720, 316)]  # Schulter -> Hüfte
BODY_W = 92
LEGS = [(720, 316), (845, 352), (930, 392)]
LEG_W = 72
FOOT = [(930, 392), (985, 446)]  # Ferse -> Zehen auf dem Boden
FOOT_W = 56
ARM = [(470, 268), (520, 372), (462, 440)]  # Schulter -> Ellbogen -> Hand
ARM_W = 60
HAND = (452, 450, 32)


def stroke(draw, pts, width):
    draw.line(pts, fill=255, width=width, joint="curve")
    r = width / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=255)


def build():
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)

    def sc(pts):
        return [(x * S, y * S) for x, y in pts]

    # Beine, Fuß, Körper, Arm, Hand, Hals, Kopf - alles in Weiß
    stroke(d, sc(LEGS), LEG_W * S)
    stroke(d, sc(FOOT), FOOT_W * S)
    stroke(d, sc(BODY), BODY_W * S)
    stroke(d, sc(ARM), ARM_W * S)
    hx, hy, hr = HAND
    d.ellipse([(hx - hr) * S, (hy - hr) * S, (hx + hr) * S, (hy + hr) * S], fill=255)
    stroke(d, sc(NECK), NECK_W * S)
    cx, cy, r = HEAD
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)

    return mask.resize((W, H), Image.LANCZOS)


def main():
    mask = build()
    bbox = mask.getbbox()
    glyph = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    glyph.putalpha(mask)
    glyph = glyph.crop(bbox)
    glyph.save(os.path.join(HERE, "custom-pushup.png"))

    pad = 40
    prev = Image.new("RGB", (glyph.width + 2 * pad, glyph.height + 2 * pad), (14, 16, 26))
    prev.paste(glyph, (pad, pad), glyph)
    prev.save(os.path.join(HERE, "custom-pushup-preview.png"))

    # Kleine Größen prüfen (so wie das Glyph später im Icon sitzt)
    sizes = [180, 120, 80, 60]
    strip = Image.new("RGB", (sum(sizes) + 10 * (len(sizes) + 1), 190), (14, 16, 26))
    x = 10
    for s in sizes:
        sc = s / glyph.width
        small = glyph.resize((s, max(1, int(glyph.height * sc))), Image.LANCZOS)
        strip.paste(small, (x, 10 + (180 - small.height) // 2), small)
        x += s + 10
    strip.save(os.path.join(HERE, "custom-pushup-sizes.png"))
    print(f"geschrieben: custom-pushup.png {glyph.size}")


if __name__ == "__main__":
    main()
