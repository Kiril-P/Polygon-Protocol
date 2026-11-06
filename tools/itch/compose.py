#!/usr/bin/env python3
"""Put the title on the generated key art (docs/media/itch/source, made with an image model: no text in the art).

    python3 tools/itch/compose.py        # writes docs/media/itch/{cover,banner,social}.png

Title: Chakra Petch Bold Italic, plain white with a soft shadow (no neon glow, which read as generic).
"""
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "media" / "itch" / "source"
OUT = ROOT / "docs" / "media" / "itch"
FONTS = ROOT / "build" / "fonts"
GF = "https://github.com/google/fonts/raw/main/ofl/chakrapetch/"
SS = 2


def font(name, size):
    p = FONTS / name
    if not p.exists():
        FONTS.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(GF + name, p)
    return ImageFont.truetype(str(p), size)


def spaced(img, cx, cy, text, f, fill, spacing, shadow=None, anchor_left=False):
    d = ImageDraw.Draw(img)
    widths = [d.textlength(c, font=f) for c in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x0 = cx if anchor_left else cx - total / 2
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        x = x0
        for c, w in zip(text, widths):
            sd.text((x + shadow[0], cy + shadow[1]), c, font=f, fill=(0, 0, 0, 215), anchor="lm")
            x += w + spacing
        sh = sh.filter(ImageFilter.GaussianBlur(shadow[2]))
        img.paste(sh, (0, 0), sh)
        d = ImageDraw.Draw(img)
    x = x0
    for c, w in zip(text, widths):
        d.text((x, cy), c, font=f, fill=fill, anchor="lm")
        x += w + spacing
    return total


def titled(name, size, cx, ty, tsize, tag_y=None, tag_size=0):
    img = Image.open(SRC / name).convert("RGB")
    big = img.resize((size[0] * SS, size[1] * SS), Image.LANCZOS)
    spaced(big, cx * SS, ty * SS, "POLYGON PROTOCOL", font("ChakraPetch-BoldItalic.ttf", tsize * SS), (246, 251, 255), tsize * SS * 0.07, shadow=(0, 3 * SS, 4 * SS))
    if tag_y:
        spaced(big, cx * SS, tag_y * SS, "EVOLVE  /  DASH  /  SURVIVE", font("ChakraPetch-Bold.ttf", tag_size * SS), (150, 226, 255), tag_size * SS * 0.32, shadow=(0, 2 * SS, 3 * SS))
    return big.resize(size, Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    titled("cover-3.png", (630, 500), 315, 64, 52).save(OUT / "cover.png", optimize=True)
    titled("banner-1.png", (1600, 400), 860, 182, 60, 240, 20).save(OUT / "banner.png", optimize=True)
    titled("social-1.png", (1200, 630), 590, 215, 50, 262, 18).save(OUT / "social.png", optimize=True)
    print("ok")
