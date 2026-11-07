#!/usr/bin/env python3
"""Derives the system-tray icons in assets/icons/ from resources/icon.png.

    python3 tools/make_tray_icons.py

tray-win.png / tray-linux.png: 32x32 colour, tray-mac.png: 22x22 colour. Godot's StatusIndicator
cannot flag a macOS "template" image, so a coloured icon (visible on both light and dark menu
bars) is used instead of the Electron build's tray-macTemplate.png.
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "resources", "icon.png")
OUT = os.path.join(ROOT, "assets", "icons")

# The artwork sits inside generous transparent/white margins: crop to the window frame first.
CROP = (56, 70, 456, 426)


def main() -> int:
    img = Image.open(SRC).convert("RGBA")
    # Treat the white page margin as transparent so the tray icon has no square background.
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 245 and g > 245 and b > 245:
                px[x, y] = (255, 255, 255, 0)
    cropped = img.crop(CROP)
    side = max(cropped.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))
    os.makedirs(OUT, exist_ok=True)
    for name, size in (("tray-win.png", 32), ("tray-linux.png", 32), ("tray-mac.png", 22)):
        square.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
        print("wrote", os.path.join("assets", "icons", name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
