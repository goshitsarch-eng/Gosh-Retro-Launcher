#!/usr/bin/env python3
"""Draws the four PNG built-in icons (default, folder, question, program-manager).

The base64 PNGs embedded in the legacy src/renderer/src/utils/icons.ts have corrupt zlib data
(they never rendered; the Electron UI always used the shell-specific icon sets instead), so they
are redrawn here as 32x32, 16-colour Windows 3.x style pixel art:

    python3 tools/make_builtin_pngs.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "builtin_icons")

BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
SILVER = (192, 192, 192, 255)
GRAY = (128, 128, 128, 255)
NAVY = (0, 0, 128, 255)
BLUE = (0, 0, 255, 255)
YELLOW = (255, 255, 0, 255)
OLIVE = (128, 128, 0, 255)
CYAN = (0, 255, 255, 255)
RED = (255, 0, 0, 255)
CLEAR = (0, 0, 0, 0)


def canvas():
    img = Image.new("RGBA", (32, 32), CLEAR)
    return img, ImageDraw.Draw(img)


def default_icon():
    img, d = canvas()
    d.rectangle([7, 3, 25, 29], fill=WHITE, outline=BLACK)
    d.polygon([(19, 3), (25, 9), (19, 9)], fill=SILVER, outline=BLACK)
    d.line([(19, 3), (25, 9)], fill=BLACK)
    d.rectangle([9, 5, 17, 5], fill=CLEAR)
    for y in (13, 17, 21, 25):
        d.line([(10, y), (22 if y != 25 else 17, y)], fill=NAVY)
    d.line([(8, 29), (26, 29)], fill=GRAY)
    d.line([(26, 10), (26, 29)], fill=GRAY)
    return img


def folder_icon():
    img, d = canvas()
    d.rectangle([3, 7, 13, 11], fill=OLIVE, outline=BLACK)
    d.rectangle([3, 11, 28, 26], fill=YELLOW, outline=BLACK)
    d.line([(4, 12), (27, 12)], fill=WHITE)
    d.line([(4, 26), (28, 26)], fill=BLACK)
    d.line([(29, 12), (29, 27)], fill=GRAY)
    return img


def question_icon():
    img, d = canvas()
    d.ellipse([3, 3, 28, 28], fill=BLUE, outline=BLACK)
    d.ellipse([5, 5, 26, 26], outline=CYAN)
    glyph = [
        (12, 10, 19, 11), (11, 11, 12, 13), (19, 11, 20, 14),
        (18, 14, 19, 16), (15, 16, 17, 18), (15, 19, 17, 20), (15, 22, 17, 24),
    ]
    for x0, y0, x1, y1 in glyph:
        d.rectangle([x0, y0, x1, y1], fill=WHITE)
    return img


def app_icon():
    img, d = canvas()
    d.rectangle([2, 4, 29, 27], fill=SILVER, outline=BLACK)
    d.rectangle([3, 5, 28, 9], fill=NAVY)
    d.rectangle([24, 6, 27, 8], fill=SILVER)
    d.rectangle([4, 6, 6, 8], fill=YELLOW)
    d.rectangle([5, 12, 26, 25], fill=WHITE, outline=GRAY)
    d.ellipse([12, 14, 20, 22], fill=CYAN, outline=BLUE)
    d.line([(3, 27), (30, 27)], fill=GRAY)
    return img


for name, fn in (("default", default_icon), ("folder", folder_icon), ("question", question_icon),
                 ("program-manager", app_icon)):
    fn().save(os.path.join(OUT, name + ".png"))
    print("wrote", name + ".png")
