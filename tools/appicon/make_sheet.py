#!/usr/bin/env python3
"""Baut einen Kontaktbogen aus den gerenderten SF-Symbol-Kandidaten."""
import glob
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TILE_W, TILE_H, LABEL = 300, 260, 26
COLS = 6
BG = (14, 16, 26)


def font():
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        try:
            return ImageFont.truetype(path, 15)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    paths = sorted(glob.glob(os.path.join(HERE, "cand-*.png")))
    if not paths:
        raise SystemExit("keine Kandidaten gefunden")
    rows = (len(paths) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * TILE_W, rows * (TILE_H + LABEL)), BG)
    d = ImageDraw.Draw(sheet)
    f = font()
    for i, p in enumerate(paths):
        glyph = Image.open(p).convert("RGBA")
        bbox = glyph.getchannel("A").getbbox()
        if bbox:
            glyph = glyph.crop(bbox)
        w, h = glyph.size
        scale = min((TILE_W - 26) / w, (TILE_H - 26) / h)
        glyph = glyph.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
        white = Image.new("RGBA", glyph.size, (255, 255, 255, 255))
        white.putalpha(glyph.getchannel("A"))
        col, row = i % COLS, i // COLS
        x = col * TILE_W
        y = row * (TILE_H + LABEL)
        d.rectangle([x, y, x + TILE_W - 1, y + TILE_H + LABEL - 1], outline=(40, 44, 60))
        sheet.paste(white, (x + (TILE_W - glyph.width) // 2, y + (TILE_H - glyph.height) // 2), white)
        name = os.path.basename(p)[len("cand-"):-len(".png")]
        d.text((x + 8, y + TILE_H + 5), name.replace("figure.", ""), fill=(210, 214, 226), font=f)
    sheet.save(os.path.join(HERE, "candidates-sheet.png"))
    print(f"geschrieben: candidates-sheet.png {sheet.size} ({len(paths)} Kandidaten)")


if __name__ == "__main__":
    main()
