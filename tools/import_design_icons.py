#!/usr/bin/env python3
"""Import the Claude Design icons95/ set into assets/win95.

The design ships every icon as an exact 2x nearest-neighbor enlargement of the
native source (large 64 -> 32, small 32 -> 16). This tool verifies that, stores the
native 1x source and regenerates the strict 2x/3x/4x variants the asset tests expect.

usage: import_design_icons.py <design-dir>   (the folder holding icons95/, iconsmac/ and iconsbe/)
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "win95")


def native(path: str, expect: int) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (expect, expect):
        sys.exit(f"{path}: expected {expect}x{expect}, got {im.size}")
    half = Image.new("RGBA", (expect // 2, expect // 2))
    src, dst = im.load(), half.load()
    for y in range(expect // 2):
        for x in range(expect // 2):
            p = src[x * 2, y * 2]
            if not (p == src[x * 2 + 1, y * 2] == src[x * 2, y * 2 + 1] == src[x * 2 + 1, y * 2 + 1]):
                sys.exit(f"{path}: not a 2x nearest-neighbor enlargement")
            dst[x, y] = p
    return half


def write(family: str, name: str, base: Image.Image) -> None:
    n = base.size[0]
    out = os.path.join(ROOT, family)
    os.makedirs(out, exist_ok=True)
    for factor in (1, 2, 3, 4):
        img = base if factor == 1 else base.resize((n * factor, n * factor), Image.NEAREST)
        img.save(os.path.join(out, f"{name}-{n * factor}.png"), optimize=True)


# The design's "note" is the alert speech balloon; assets/mac/*/note.png is the sticky-note icon.
MAC_RENAMES = {"note": "info"}


def import_mac(design: str) -> int:
    """iconsmac/<id>-64.png -> assets/mac/large/<id>.png (32px native), <id>-32.png -> small/<id>.png (16px)."""
    count = 0
    src = os.path.join(design, "iconsmac")
    for f in sorted(os.listdir(src)):
        stem, _, rest = f.rpartition("-")
        size = {"64.png": 64, "32.png": 32}.get(rest)
        if size is None:
            continue
        fam = "large" if size == 64 else "small"
        out = os.path.join(ROOT, "..", "mac", fam)
        os.makedirs(out, exist_ok=True)
        name = MAC_RENAMES.get(stem, stem)
        native(os.path.join(src, f), size).save(os.path.join(out, name + ".png"), optimize=True)
        count += 1
    return count


def import_be(design: str) -> int:
    """iconsbe/*.png are 64px smooth (anti-aliased) icons; copied unchanged to assets/be/."""
    import shutil
    src = os.path.join(design, "iconsbe")
    out = os.path.join(ROOT, "..", "be")
    os.makedirs(out, exist_ok=True)
    names = [f for f in sorted(os.listdir(src)) if f.endswith(".png")]
    for f in names:
        shutil.copyfile(os.path.join(src, f), os.path.join(out, f))
    return len(names)


def main() -> None:
    design = sys.argv[1]
    src = os.path.join(design, "icons95")
    count = 0
    for family, size, suffix in (("large", 64, "-64.png"), ("small", 32, "-32.png")):
        d = os.path.join(src, family)
        for f in sorted(os.listdir(d)):
            if f.endswith(suffix):
                write(family, f[: -len(suffix)], native(os.path.join(d, f), size))
                count += 1
    print(f"imported {count} Win95 icons, {import_mac(design)} Mac icons, {import_be(design)} BeOS icons")


if __name__ == "__main__":
    main()
