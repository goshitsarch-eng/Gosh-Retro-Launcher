class_name IcoFile
extends RefCounted
## Decoder for Windows .ico files and for the raw icon images stored in PE resources (RT_ICON).
## Godot cannot load ICO/DIB data natively, so BMP/DIB entries (1/4/8/16/24/32 bpp, with the
## 1-bit AND mask) are decoded here; PNG entries go through Image.load_png_from_buffer.
## Everything returns null / [] on malformed input and never raises.

const PNG_SIGNATURE := [0x89, 0x50, 0x4E, 0x47]
const MAX_DIM := 1024


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func _u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


static func _i32(b: PackedByteArray, o: int) -> int:
	var v := _u32(b, o)
	return v - 0x100000000 if v >= 0x80000000 else v


static func is_png(data: PackedByteArray) -> bool:
	return data.size() > 8 and data[0] == 0x89 and data[1] == 0x50 and data[2] == 0x4E and data[3] == 0x47


static func is_ico(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 6 and bytes[0] == 0 and bytes[1] == 0 and bytes[2] == 1 and bytes[3] == 0 and _u16(bytes, 4) > 0


## ICONDIR entries: [{width, height, bpp, size, offset}] (width/height 0 means 256).
static func parse_entries(bytes: PackedByteArray) -> Array:
	var out := []
	if not is_ico(bytes):
		return out
	var count := _u16(bytes, 4)
	for i in count:
		var o := 6 + i * 16
		if o + 16 > bytes.size():
			break
		var w := bytes[o]
		var h := bytes[o + 1]
		var size := _u32(bytes, o + 8)
		var offset := _u32(bytes, o + 12)
		if size <= 0 or offset < 6 or offset + size > bytes.size():
			continue
		out.append({
			"width": 256 if w == 0 else w,
			"height": 256 if h == 0 else h,
			"bpp": _u16(bytes, o + 6),
			"size": size,
			"offset": offset,
		})
	return out


## Largest-first ordering shared by ICO files and PE icon groups.
static func compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var aa := int(a.width) * int(a.height)
	var ba := int(b.width) * int(b.height)
	if aa != ba:
		return aa > ba
	return int(a.bpp) > int(b.bpp)


## Decodes the largest decodable image of an .ico file, or null.
static func best_image(bytes: PackedByteArray) -> Image:
	var entries := parse_entries(bytes)
	entries.sort_custom(compare_entries)
	for e in entries:
		var img := decode_image_data(bytes.slice(int(e.offset), int(e.offset) + int(e.size)))
		if img != null:
			return img
	return null


## One icon image: PNG or DIB (BITMAPINFOHEADER + pixels + optional AND mask).
static func decode_image_data(data: PackedByteArray) -> Image:
	if is_png(data):
		var img := Image.new()
		if img.load_png_from_buffer(data) == OK and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			return img
		return null
	return decode_dib(data)


static func decode_dib(d: PackedByteArray) -> Image:
	if d.size() < 40:
		return null
	var header_size := _u32(d, 0)
	if header_size < 40 or header_size > d.size():
		return null
	var w := _i32(d, 4)
	var raw_h := _i32(d, 8)
	var bpp := _u16(d, 14)
	var compression := _u32(d, 16)
	var clr_used := _u32(d, 32)
	if w <= 0 or w > MAX_DIM or raw_h == 0 or absi(raw_h) > MAX_DIM * 2:
		return null
	if not [1, 4, 8, 16, 24, 32].has(bpp):
		return null
	if compression != 0 and compression != 3:
		return null  # RLE-compressed icon bitmaps do not occur in practice
	var top_down := raw_h < 0
	var height := absi(raw_h)
	var palette_count := 0
	if bpp <= 8:
		palette_count = clr_used if clr_used > 0 else (1 << bpp)
		palette_count = mini(palette_count, 1 << bpp)
	var pos := header_size
	var masks := [0x7C00, 0x03E0, 0x001F]  # 5-5-5 default for 16 bpp
	if compression == 3:
		if header_size == 40:
			if pos + 12 > d.size():
				return null
			masks = [_u32(d, pos), _u32(d, pos + 4), _u32(d, pos + 8)]
			pos += 12
		elif header_size >= 52:
			masks = [_u32(d, 40), _u32(d, 44), _u32(d, 48)]
	var palette := PackedInt32Array()
	if palette_count > 0:
		if pos + palette_count * 4 > d.size():
			return null
		for i in palette_count:
			palette.append((d[pos + i * 4 + 2] << 16) | (d[pos + i * 4 + 1] << 8) | d[pos + i * 4])
		pos += palette_count * 4
	var stride := ((w * bpp + 31) / 32) * 4
	var mask_stride := ((w + 31) / 32) * 4
	var real_h := height
	var has_mask := false
	var half := height / 2
	# ICO bitmaps store XOR+AND heights (2*h); a height equal to the width is a plain DIB.
	if height == 2 * w or (height != w and d.size() >= pos + (stride + mask_stride) * half):
		real_h = half
		has_mask = true
	if real_h <= 0 or pos + stride * real_h > d.size():
		return null
	var mask_pos := pos + stride * real_h
	if has_mask and mask_pos + mask_stride * real_h > d.size():
		has_mask = false

	var out := PackedByteArray()
	out.resize(w * real_h * 4)
	var any_alpha := false
	for row in real_h:
		var src_row := (row if top_down else real_h - 1 - row)
		var rp := pos + src_row * stride
		var op := row * w * 4
		match bpp:
			32:
				for x in w:
					var s := rp + x * 4
					var a := d[s + 3]
					if a != 0:
						any_alpha = true
					out[op] = d[s + 2]
					out[op + 1] = d[s + 1]
					out[op + 2] = d[s]
					out[op + 3] = a
					op += 4
			24:
				for x in w:
					var s := rp + x * 3
					out[op] = d[s + 2]
					out[op + 1] = d[s + 1]
					out[op + 2] = d[s]
					out[op + 3] = 255
					op += 4
			16:
				for x in w:
					var v := _u16(d, rp + x * 2)
					var rr := _expand_mask(v, masks[0])
					var gg := _expand_mask(v, masks[1])
					var bb := _expand_mask(v, masks[2])
					out[op] = rr
					out[op + 1] = gg
					out[op + 2] = bb
					out[op + 3] = 255
					op += 4
			8:
				for x in w:
					var c := _pal(palette, d[rp + x])
					out[op] = (c >> 16) & 0xff
					out[op + 1] = (c >> 8) & 0xff
					out[op + 2] = c & 0xff
					out[op + 3] = 255
					op += 4
			4:
				for x in w:
					var byte := d[rp + (x >> 1)]
					var idx := (byte >> 4) if (x & 1) == 0 else (byte & 0x0f)
					var c4 := _pal(palette, idx)
					out[op] = (c4 >> 16) & 0xff
					out[op + 1] = (c4 >> 8) & 0xff
					out[op + 2] = c4 & 0xff
					out[op + 3] = 255
					op += 4
			1:
				for x in w:
					var bit := (d[rp + (x >> 3)] >> (7 - (x & 7))) & 1
					var c1 := _pal(palette, bit)
					out[op] = (c1 >> 16) & 0xff
					out[op + 1] = (c1 >> 8) & 0xff
					out[op + 2] = c1 & 0xff
					out[op + 3] = 255
					op += 4
	# AND mask: 1 = transparent. 32-bpp images carry their own alpha unless it is all zero.
	if has_mask and (bpp != 32 or not any_alpha):
		for row in real_h:
			var src_row2 := (row if top_down else real_h - 1 - row)
			var mp := mask_pos + src_row2 * mask_stride
			for x in w:
				var m := (d[mp + (x >> 3)] >> (7 - (x & 7))) & 1
				var o := (row * w + x) * 4 + 3
				if m == 1:
					out[o] = 0
				elif bpp == 32:
					out[o] = 255
	return Image.create_from_data(w, real_h, false, Image.FORMAT_RGBA8, out)


static func _pal(palette: PackedInt32Array, idx: int) -> int:
	return palette[idx] if idx < palette.size() else 0


static func _expand_mask(v: int, mask: int) -> int:
	if mask == 0:
		return 0
	var shift := 0
	var m := mask
	while (m & 1) == 0:
		m >>= 1
		shift += 1
	var bits := 0
	while (m & 1) == 1:
		m >>= 1
		bits += 1
	var comp := (v & mask) >> shift
	if bits >= 8:
		return comp >> (bits - 8)
	return (comp * 255) / ((1 << bits) - 1)
