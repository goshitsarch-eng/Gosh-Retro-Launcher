#!/usr/bin/env python3
"""Diff two PNGs with the original harness rule and write a side-by-side/diff image.

usage: compare.py actual.png baseline.png [--diff out.png]
exit 0 when sizes match and <= 0.5% of pixels differ by > 20 per channel.
"""
import sys
import numpy as np
from PIL import Image

def main() -> int:
    a_path, b_path = sys.argv[1], sys.argv[2]
    diff_path = sys.argv[sys.argv.index("--diff") + 1] if "--diff" in sys.argv else None
    a = Image.open(a_path).convert("RGB")
    b = Image.open(b_path).convert("RGB")
    if a.size != b.size:
        print(f"size mismatch: actual {a.size} vs baseline {b.size}")
        return 1
    aa = np.asarray(a).astype(int)
    bb = np.asarray(b).astype(int)
    bad = (np.abs(aa - bb) > 20).any(axis=2)
    ratio = bad.mean()
    print(f"visual difference: {ratio * 100:.3f}% ({int(bad.sum())} px)")
    if diff_path:
        out = np.concatenate([aa, bb, np.where(bad[..., None], [255, 0, 255], aa // 3 + 80)], axis=1)
        Image.fromarray(out.astype("uint8")).save(diff_path)
    return 0 if ratio <= 0.005 else 1

if __name__ == "__main__":
    sys.exit(main())
