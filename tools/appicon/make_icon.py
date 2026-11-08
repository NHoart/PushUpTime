#!/usr/bin/env python3
"""Erzeugt das Liquid-Glass-App-Icon für PushUpTime.

Rendert bei 4x Übergröße (4096 px) und skaliert auf 1024 px herunter.
Aufruf aus dem Projektwurzelverzeichnis:

    python3 tools/appicon/make_icon.py

Ergebnis: PushUpTime/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
sowie Vorschaubilder in tools/appicon/preview-*.png
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

BASE = 1024
SS = 4                       # Supersampling
N = BASE * SS
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ICONSET = os.path.join(ROOT, "PushUpTime", "Assets.xcassets", "AppIcon.appiconset")
SYMBOL = os.path.join(HERE, "custom-pushup.png")


def px(v):
    """Koordinaten im 1024er Raster in Supersampling-Pixel umrechnen."""
    return int(round(v * SS))


def layer():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def lerp3(c1, c2, t):
    return tuple(c1[i] + (c2[i] - c1[i]) * t for i in range(3))


def glow_mask(cx, cy, rx, ry, power=2.0):
    """Weiche radiale Maske, bei 200x200 berechnet und hochskaliert."""
    low = 200
    im = Image.new("L", (low, low), 0)
    pix = im.load()
    for y in range(low):
        v = (y + 0.5) / low
        for x in range(low):
            u = (x + 0.5) / low
            d = math.hypot((u - cx) / rx, (v - cy) / ry)
            if d < 1.0:
                pix[x, y] = int(255 * ((1.0 - d) ** power))
    return im.filter(ImageFilter.GaussianBlur(1.4)).resize((N, N), Image.BICUBIC)


def screen_color(base, mask, color, strength=1.0):
    """Additives Licht: Maske mit Farbe screen-blenden."""
    m = Image.eval(mask, lambda p: max(0, min(255, int(p * strength))))
    rgb = Image.merge("RGB", (m, m, m))
    return ImageChops.screen(base, ImageChops.multiply(Image.new("RGB", (N, N), color), rgb))


def shade(base, mask, color, strength=1.0):
    """Abdunkeln: Maske mit Farbe multiplizieren."""
    m = Image.eval(mask, lambda p: max(0, min(255, int(p * strength))))
    rgb = Image.merge("RGB", (m, m, m))
    return ImageChops.multiply(base, rgb)


def circle_mask(cx, cy, r):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse(
        [px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=255
    )
    return m


def gradient_mask(top_value, bottom_value, steepness=1.0):
    """Vertikaler Alpha-Verlauf (oben top_value, unten bottom_value)."""
    low = 128
    im = Image.new("L", (low, low), 0)
    pix = im.load()
    for y in range(low):
        v = (y + 0.5) / low
        for x in range(low):
            u = (x + 0.5) / low
            t = min(1.0, max(0.0, (1.0 - steepness) * v + steepness * (0.55 * u + 0.45 * v)))
            pix[x, y] = max(0, min(255, int(top_value + (bottom_value - top_value) * t)))
    return im.resize((N, N), Image.BICUBIC)


def arc_point(cx, cy, r, angle):
    rad = math.radians(angle)
    return cx + r * math.cos(rad), cy + r * math.sin(rad)


def draw_arc(im, cx, cy, r, width, start, sweep, c1, c2):
    """Bogen mit Farbverlauf und runden Endkappen."""
    d = ImageDraw.Draw(im)
    bbox = [px(cx - r), px(cy - r), px(cx + r), px(cy + r)]
    steps = 150
    for i in range(steps):
        t0 = start + sweep * i / steps
        t1 = start + sweep * (i + 1) / steps
        col = tuple(int(round(c)) for c in lerp3(c1, c2, i / (steps - 1)))
        d.arc(bbox, t0, t1 + 1.2, fill=col + (255,), width=px(width))
    for t, col in ((start, c1), (start + sweep, c2)):
        c = tuple(int(round(v)) for v in col)
        ex, ey = arc_point(cx, cy, r, t)
        d.ellipse(
            [px(ex - width / 2), px(ey - width / 2),
             px(ex + width / 2), px(ey + width / 2)],
            fill=c + (255,),
        )


def background():
    """Dunkle Mitte, farbiges Licht an den Rändern – gibt dem Glas Tiefe."""
    low = 320
    im = Image.new("RGB", (low, low))
    pix = im.load()
    top = (30, 21, 88)
    bottom = (7, 9, 30)
    for y in range(low):
        v = y / (low - 1)
        for x in range(low):
            u = x / (low - 1)
            t = min(1.0, max(0.0, 0.26 * u + 0.74 * v))
            pix[x, y] = tuple(int(round(c)) for c in lerp3(top, bottom, t))
    img = im.resize((N, N), Image.BICUBIC)

    img = screen_color(img, glow_mask(0.16, 0.88, 0.72, 0.62, 1.7), (24, 112, 255), 1.05)
    img = screen_color(img, glow_mask(0.88, 0.10, 0.62, 0.54, 1.7), (120, 56, 255), 0.85)
    img = screen_color(img, glow_mask(0.96, 0.84, 0.42, 0.42, 2.0), (255, 52, 138), 0.55)
    img = screen_color(img, glow_mask(0.04, 0.16, 0.30, 0.28, 2.0), (110, 200, 255), 0.30)

    # Mitte abdunkeln, damit die weiße Figur klar liest
    center_dark = glow_mask(0.5, 0.48, 0.52, 0.52, 1.0)
    factor = Image.eval(center_dark, lambda p: 255 - int(p * 0.34))
    img = ImageChops.multiply(img, Image.merge("RGB", (factor, factor, factor)))
    return img


def build():
    cx, cy, R = 512.0, 512.0, 344.0
    lens = circle_mask(cx, cy, R)

    img = background().convert("RGBA")

    # --- Lichtbrechung: Hintergrund in der Linse vergrößert, je Farbkanal
    #     minimal anders (chromatische Kante wie bei echter Glasoptik)
    def refract(scale):
        half = R / scale
        part = img.convert("RGB").crop(
            (px(cx - half), px(cy - half), px(cx + half), px(cy + half))
        )
        part = part.resize((px(2 * R), px(2 * R)), Image.BICUBIC)
        canvas = Image.new("RGB", (N, N), (0, 0, 0))
        canvas.paste(part, (px(cx - R), px(cy - R)))
        return canvas

    channels = [refract(1.068).split()[0], refract(1.075).split()[1], refract(1.082).split()[2]]
    lens_fill = Image.merge("RGB", channels)
    lens_fill = ImageEnhance.Brightness(lens_fill).enhance(1.20)
    lens_fill = ImageEnhance.Color(lens_fill).enhance(1.14)
    lens_fill = lens_fill.filter(ImageFilter.GaussianBlur(px(1.0)))
    lens_fill = Image.blend(lens_fill, Image.new("RGB", (N, N), (255, 255, 255)), 0.05)
    img = Image.composite(lens_fill, img.convert("RGB"), lens).convert("RGBA")

    # --- Milchglas-Tönung: oben etwas mehr Licht als unten
    tint = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    tint.putalpha(ImageChops.multiply(gradient_mask(26, 4, 0.22), lens))
    img = Image.alpha_composite(img, tint)

    # --- Licht, das innen an der Glaswand entlangläuft
    edge_glow = layer()
    ImageDraw.Draw(edge_glow).ellipse(
        [px(cx - R + 2), px(cy - R + 2), px(cx + R - 2), px(cy + R - 2)],
        outline=(255, 255, 255, 62), width=px(20),
    )
    edge_glow = edge_glow.filter(ImageFilter.GaussianBlur(px(9)))
    edge_glow.putalpha(ImageChops.multiply(edge_glow.getchannel("A"), lens))
    img = Image.alpha_composite(img, edge_glow)

    # --- Schlagschatten des Glaskörpers
    body_shadow = layer()
    ImageDraw.Draw(body_shadow).ellipse(
        [px(cx - R), px(cy - R + 12), px(cx + R), px(cy + R + 12)],
        fill=(2, 4, 18, 140),
    )
    body_shadow = body_shadow.filter(ImageFilter.GaussianBlur(px(16)))
    img = Image.alpha_composite(img, body_shadow)

    # --- Schmale dunkle Kante innen: Glasdicke
    inner_shade = layer()
    ImageDraw.Draw(inner_shade).ellipse(
        [px(cx - R + 1), px(cy - R + 1), px(cx + R - 1), px(cy + R - 1)],
        outline=(2, 6, 24, 150), width=px(9),
    )
    inner_shade = inner_shade.filter(ImageFilter.GaussianBlur(px(6)))
    inner_shade.putalpha(ImageChops.multiply(inner_shade.getchannel("A"), lens))
    img = Image.alpha_composite(img, inner_shade)

    # --- Kräftige Lichtkante unten innen (Kaustik)
    caustic = layer()
    ImageDraw.Draw(caustic).arc(
        [px(cx - R + 13), px(cy - R + 13), px(cx + R - 13), px(cy + R - 13)],
        34, 146, fill=(206, 240, 255, 135), width=px(4.5),
    )
    caustic = caustic.filter(ImageFilter.GaussianBlur(px(4)))
    caustic.putalpha(ImageChops.multiply(caustic.getchannel("A"), lens))
    img = Image.alpha_composite(img, caustic)

    # --- Weicher Reflex oben links
    glare = layer()
    ImageDraw.Draw(glare).ellipse(
        [px(cx - 250), px(cy - 296), px(cx + 40), px(cy - 46)],
        fill=(255, 255, 255, 42),
    )
    glare = glare.filter(ImageFilter.GaussianBlur(px(40)))
    glare.putalpha(ImageChops.multiply(glare.getchannel("A"), lens))
    img = Image.alpha_composite(img, glare)

    # --- Liegestütz-Figur: reines Weiß, flacher Schatten
    src = Image.open(SYMBOL).convert("RGBA")
    src = src.crop(src.getchannel("A").getbbox())
    target_w = px(600)
    target_h = int(round(src.height * target_w / src.width))
    glyph = src.resize((target_w, target_h), Image.LANCZOS)
    mask = glyph.getchannel("A")
    gx = px(cx) - target_w // 2
    gy = px(cy + 8) - target_h // 2

    shadow = layer()
    sh = Image.new("RGBA", (target_w, target_h), (3, 7, 24, 60))
    sh.putalpha(mask)
    shadow.alpha_composite(sh, (gx + px(3), gy + px(7)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(10)))
    img = Image.alpha_composite(img, shadow)

    white = Image.new("RGB", (target_w, target_h), (255, 255, 255))
    pale = Image.new("RGB", (target_w, target_h), (226, 242, 255))
    fade = Image.linear_gradient("L").resize((target_w, target_h), Image.BICUBIC)
    fade = fade.point(lambda p: int(p * 0.5))
    fig = Image.composite(pale, white, fade).convert("RGBA")
    fig.putalpha(mask)
    img.alpha_composite(fig, (gx, gy))

    # --- Fortschrittsring auf dem Glasrand: gedämpfte Spur, heller Bogen
    ring_r = R - 1.5
    track = layer()
    ImageDraw.Draw(track).ellipse(
        [px(cx - ring_r), px(cy - ring_r), px(cx + ring_r), px(cy + ring_r)],
        outline=(255, 255, 255, 60), width=px(2.4),
    )
    img = Image.alpha_composite(img, track)

    progress = layer()
    draw_arc(progress, cx, cy, ring_r, 8.5, -90, 268,
             (255, 255, 255), (168, 233, 255))
    halo = progress.filter(ImageFilter.GaussianBlur(px(15)))
    halo.putalpha(Image.eval(halo.getchannel("A"), lambda p: int(p * 0.5)))
    halo_cyan = Image.new("RGBA", (N, N), (120, 226, 255, 0))
    halo_cyan.putalpha(halo.getchannel("A"))
    img = Image.alpha_composite(img, halo_cyan)
    img = Image.alpha_composite(img, progress)

    # --- Globaler Glanz oben + Vignette
    sheen = layer()
    ImageDraw.Draw(sheen).ellipse(
        [px(-320), px(-620), px(1300), px(470)], fill=(255, 255, 255, 14)
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(px(100)))
    img = Image.alpha_composite(img, sheen)

    rgb = img.convert("RGB")
    # radial_gradient: 0 in der Mitte, 255 am Rand
    vig = Image.radial_gradient("L").resize((N, N), Image.BICUBIC)
    factor = Image.eval(vig, lambda p: 255 - int(p * 0.26))
    rgb = ImageChops.multiply(rgb, Image.merge("RGB", (factor, factor, factor)))

    # --- Feines Korn gegen Banding
    noise = Image.effect_noise((BASE, BASE), 14).convert("RGB").resize((N, N), Image.NEAREST)
    rgb = Image.blend(rgb, ImageChops.overlay(rgb, noise), 0.045)

    return rgb.resize((BASE, BASE), Image.LANCZOS)


def write_previews(icon):
    icon.resize((760, 760), Image.LANCZOS).save(os.path.join(HERE, "view-icon.png"), optimize=True)
    sizes = (180, 120, 80, 60)
    tiles = [(s, icon.resize((s, s), Image.LANCZOS)) for s in sizes]
    sheet = Image.new("RGB", (180 * len(tiles) + 20 * (len(tiles) + 1), 220), (32, 34, 40))
    x = 20
    for s, tile in tiles:
        sheet.paste(tile, (x, (220 - s) // 2))
        x += s + 20
    sheet.save(os.path.join(HERE, "preview-sizes.png"))


def main():
    icon = build()
    os.makedirs(ICONSET, exist_ok=True)
    out = os.path.join(ICONSET, "AppIcon-1024.png")
    icon.save(out, "PNG")
    write_previews(icon)
    print("geschrieben:", out, icon.size, icon.mode)


if __name__ == "__main__":
    main()
