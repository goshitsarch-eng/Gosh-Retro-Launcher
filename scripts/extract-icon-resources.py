#!/usr/bin/env python3
"""Extract icon resources from PE (Win95 shell32.dll/explorer.exe) and NE
(Win 3.x/95 user.exe, progman.exe, moricons.dll, app exes) binaries to PNGs.

Usage: python scripts/extract-icon-resources.py <binary> <outdir>
Reads only the user's own licensed media; output goes to the gitignored
assets/*-rtm-local packs after ID mapping. No Microsoft bytes are stored in
this repository.
"""
import struct
import sys
from pathlib import Path
from PIL import Image


def dib_to_image(data: bytes) -> Image.Image:
    """Convert icon DIB data (BITMAPINFOHEADER + pixels + AND mask) to RGBA."""
    bi_size, bi_width, bi_height2, bi_planes, bi_bpp = struct.unpack_from('<IiiHH', data, 0)
    height = bi_height2 // 2
    width = bi_width
    compression = struct.unpack_from('<I', data, 12)[0]
    clr_used = struct.unpack_from('<I', data, 32)[0] if bi_size >= 40 else 0
    palette_entries = clr_used if clr_used else (1 << bi_bpp if bi_bpp <= 8 else 0)
    palette = []
    off = bi_size
    for i in range(palette_entries):
        b, g, r, _ = struct.unpack_from('<BBBB', data, off + i * 4)
        palette.append((r, g, b))
    pix_off = bi_size + palette_entries * 4
    img = Image.new('RGBA', (width, height))
    px = img.load()

    if bi_bpp == 32:
        row_size = width * 4
        and_off = pix_off + row_size * height
        for y in range(height):
            for x in range(width):
                o = pix_off + (height - 1 - y) * row_size + x * 4
                b, g, r, a = data[o:o + 4]
                px[x, y] = (r, g, b, a if a else 255)
        return img

    if bi_bpp == 24:
        row_size = (width * 3 + 3) & ~3
    elif bi_bpp == 8:
        row_size = (width + 3) & ~3
    elif bi_bpp == 4:
        row_size = ((width + 1) // 2 + 3) & ~3
    elif bi_bpp == 1:
        row_size = ((width + 7) // 8 + 3) & ~3
    else:
        raise ValueError(f'unsupported bpp {bi_bpp}')

    and_row = ((width + 31) // 32) * 4
    and_off = pix_off + row_size * height

    for y in range(height):
        row = height - 1 - y
        for x in range(width):
            o = pix_off + row * row_size
            if bi_bpp == 24:
                b, g, r = data[o + x * 3:o + x * 3 + 3]
            elif bi_bpp == 8:
                r, g, b = palette[data[o + x]]
            elif bi_bpp == 4:
                byte = data[o + x // 2]
                idx = (byte >> 4) if x % 2 == 0 else (byte & 0x0F)
                r, g, b = palette[idx]
            else:
                byte = data[o + x // 8]
                idx = (byte >> (7 - x % 8)) & 1
                r, g, b = palette[idx]
            mask_byte = data[and_off + row * and_row + x // 8]
            masked = (mask_byte >> (7 - x % 8)) & 1
            px[x, y] = (r, g, b, 0 if masked else 255)
    return img


def parse_group(data: bytes):
    """Parse GRPICONDIR; returns list of (width, height, bpp, res_id)."""
    _, id_type, count = struct.unpack_from('<HHH', data, 0)
    out = []
    for i in range(count):
        o = 6 + i * 14
        w, h, _cc, _rsv, planes, bpp, _size, res_id = struct.unpack_from('<BBBBHHIH', data, o)
        out.append((w or 256, h or 256, bpp, res_id))
    return out


def extract_pe(path: Path):
    data = path.read_bytes()
    pe_off = struct.unpack_from('<I', data, 0x3C)[0]
    num_sections = struct.unpack_from('<H', data, pe_off + 6)[0]
    opt_size = struct.unpack_from('<H', data, pe_off + 20)[0]
    opt_off = pe_off + 24
    rsrc_rva, _ = struct.unpack_from('<II', data, opt_off + opt_size - 8 * 6 + 8)  # data dir[2]
    # data directory starts at opt_off+96 for PE32; entry 2 = resources
    rsrc_rva = struct.unpack_from('<I', data, opt_off + 96 + 2 * 8)[0]
    sec_off = opt_off + opt_size
    sections = []
    for i in range(num_sections):
        o = sec_off + i * 40
        name = data[o:o + 8].rstrip(b'\0').decode('ascii', 'replace')
        vsize, vaddr, rawsize, rawoff = struct.unpack_from('<IIII', data, o + 8)
        sections.append((name, vaddr, vsize, rawoff, rawsize))

    def rva_to_off(rva):
        for name, vaddr, vsize, rawoff, rawsize in sections:
            if vaddr <= rva < vaddr + max(vsize, rawsize):
                return rawoff + (rva - vaddr)
        raise ValueError(f'rva {rva:x} not mapped')

    rsrc_off = rva_to_off(rsrc_rva)
    icons = {}   # id -> data
    groups = {}  # id -> parsed list

    def walk(dir_off, type_id=None, res_id=None):
        _, _, _, _, num_named, num_id = struct.unpack_from('<IIHHHH', data, dir_off)
        entries = num_named + num_id
        for i in range(entries):
            eoff = dir_off + 16 + i * 8
            name, offset = struct.unpack_from('<II', data, eoff)
            is_dir = offset & 0x80000000
            target = rsrc_off + (offset & 0x7FFFFFFF)
            if type_id is None:
                walk(target, (name & 0xFFFF) if not name & 0x80000000 else None)
            elif is_dir:
                walk(target, type_id, (name & 0xFFFF) if not name & 0x80000000 else None)
            else:
                data_rva, size, _cp, _ = struct.unpack_from('<IIII', data, target)
                blob = data[rva_to_off(data_rva):rva_to_off(data_rva) + size]
                if type_id == 3 and res_id is not None:
                    icons[res_id] = blob
                elif type_id == 14 and res_id is not None:
                    groups[res_id] = parse_group(blob)

    walk(rsrc_off)
    return groups, icons


def extract_ne(path: Path):
    data = path.read_bytes()
    ne_off = struct.unpack_from('<I', data, 0x3C)[0]
    rsrc_off = ne_off + struct.unpack_from('<H', data, ne_off + 0x24)[0]
    align = struct.unpack_from('<H', data, rsrc_off)[0]
    icons = {}
    groups = {}
    pos = rsrc_off + 2
    while True:
        type_id, count, _ = struct.unpack_from('<HHI', data, pos)
        if type_id == 0:
            break
        pos += 8
        for _ in range(count):
            rn_off, rn_len, _, rn_id, _ = struct.unpack_from('<HHHHI', data, pos)
            pos += 12
            start = rn_off << align
            blob = data[start:start + (rn_len << align)]
            tid = type_id & 0x3FF
            if type_id & 0x8000 and tid == 3:
                icons[rn_id & 0x7FFF if rn_id & 0x8000 else rn_id] = blob
            elif type_id & 0x8000 and tid == 14:
                groups[rn_id & 0x7FFF if rn_id & 0x8000 else rn_id] = parse_group(blob)
    return groups, icons


def main():
    binary = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    head = binary.read_bytes()[:2]
    if head != b'MZ':
        print('not MZ'); return
    pe_off = struct.unpack_from('<I', binary.read_bytes(), 0x3C)[0]
    sig = binary.read_bytes()[pe_off:pe_off + 2]
    if sig == b'PE':
        groups, icons = extract_pe(binary)
    elif sig == b'NE':
        groups, icons = extract_ne(binary)
    else:
        print(f'unknown sig {sig}'); return
    for gid, images in sorted(groups.items()):
        for (w, h, bpp, res_id) in images:
            blob = icons.get(res_id)
            if blob is None:
                print(f'group {gid}: missing image id {res_id}')
                continue
            try:
                img = dib_to_image(blob)
            except Exception as exc:
                print(f'group {gid} image {res_id}: {exc}')
                continue
            img.save(outdir / f'{binary.stem.lower()}-{gid}-{w}x{h}-{bpp}bpp.png')
    print(f'{binary.name}: {len(groups)} groups -> {outdir}')


if __name__ == '__main__':
    main()
