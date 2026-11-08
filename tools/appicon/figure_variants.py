#!/usr/bin/env python3
"""Vergleicht Liegestütz-Silhouetten-Varianten (groß und klein) auf einem Bogen.

Körperachse bleibt gerade; Stützen (Arm, Beine) stehen senkrecht auf der
Bodenlinie - so liest die Form als Stützposition statt als "liegend".
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4
W, H = 1200, 560

HEAD_F = (352, 194, 48)
NECK_F = ([(392, 212), (440, 236)], 40)
BODY_F = ([(458, 244), (770, 312)], 58)
LEGS_F = [([(770, 312), (890, 334), (995, 358)], 42)]
FOOT_F = [([(995, 358), (1022, 412)], 34)]
ARM_F = [([(486, 258), (482, 404)], 40)]
HAND_F = [(478, 414, 22)]

VARIANTS = {
    "F Arm gerade": {
        "head": HEAD_F, "neck": NECK_F, "body": BODY_F,
        "legs": LEGS_F, "feet": FOOT_F, "arms": ARM_F, "hands": HAND_F,
        "ground": None,
    },
    "G Arm gebeugt": {
        "head": HEAD_F, "neck": NECK_F, "body": BODY_F,
        "legs": LEGS_F, "feet": FOOT_F,
        "arms": [([(486, 258), (534, 340), (486, 404)], 42)],
        "hands": [(482, 414, 22)],
        "ground": None,
    },
    "H gebeugt + Boden": {
        "head": HEAD_F, "neck": NECK_F, "body": BODY_F,
        "legs": LEGS_F, "feet": FOOT_F,
        "arms": [([(486, 258), (534, 340), (486, 404)], 42)],
        "hands": [(482, 414, 22)],
        "ground": ([(446, 438), (1046, 438)], 14),
    },
    "I flacher, Kopf tief": {
        "head": (336, 214, 46), "neck": ([(376, 232), (428, 254)], 38),
        "body": ([(444, 260), (766, 320)], 56),
        "legs": [([(766, 320), (886, 342), (992, 366)], 40)],
        "feet": [([(992, 366), (1018, 418)], 32)],
        "arms": [([(474, 274), (470, 414)], 38), ([(500, 268), (496, 408)], 38)],
        "hands": [(466, 422, 21), (492, 416, 21)],
        "ground": None,
    },
}


def stroke(d, pts, width):
    pts = [(x * S, y * S) for x, y in pts]
    d.line(pts, fill=255, width=width * S, joint="curve")
    r = width * S / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)


def render(geo):
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)
    for pts, w in geo["legs"]:
        stroke(d, pts, w)
    for pts, w in geo["feet"]:
        stroke(d, pts, w)
    pts, w = geo["body"]
    stroke(d, pts, w)
    for pts, w in geo["arms"]:
        stroke(d, pts, w)
    for hx, hy, hr in geo["hands"]:
        d.ellipse([(hx - hr) * S, (hy - hr) * S, (hx + hr) * S, (hy + hr) * S], fill=255)
    pts, w = geo["neck"]
    stroke(d, pts, w)
    cx, cy, r = geo["head"]
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)
    if geo["ground"]:
        pts, w = geo["ground"]
        stroke(d, pts, w)
    mask = mask.resize((W, H), Image.LANCZOS)
    glyph = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    glyph.putalpha(mask)
    return glyph.crop(mask.getbbox())


def font():
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 16)
    except OSError:
        return ImageFont.load_default()


def main():
    tiles = [(name, render({**VARIANTS[name]})) for name in VARIANTS]
    row_h, pad = 210, 18
    big_w, small = 520, 110
    sheet = Image.new("RGB", (big_w + small + 3 * pad + 210, row_h * len(tiles) + pad), (14, 16, 26))
    d = ImageDraw.Draw(sheet)
    f = font()
    for i, (name, glyph) in enumerate(tiles):
        y = pad + i * row_h
        sc = big_w / glyph.width
        big = glyph.resize((big_w, max(1, int(glyph.height * sc))), Image.LANCZOS)
        sm = glyph.resize((small, max(1, int(glyph.height * small / glyph.width))), Image.LANCZOS)
        sheet.paste(big, (pad, y + (row_h - pad - big.height) // 2), big)
        x2 = pad + big_w + pad
        sheet.paste(sm, (x2, y + (row_h - pad - sm.height) // 2), sm)
        d.text((x2 + small + pad, y + row_h // 2 - 8), name, fill=(205, 210, 224), font=f)
        d.line([0, y + row_h - 6, sheet.width, y + row_h - 6], fill=(34, 38, 52))
    out = os.path.join(HERE, "figure-variants.png")
    sheet.save(out)
    print(f"geschrieben: {out} {sheet.size}")


if __name__ == "__main__":
    main()
