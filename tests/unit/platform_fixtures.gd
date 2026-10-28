class_name PlatformFixtures
extends RefCounted
## Synthetic binary fixtures for the platform tests: ICO/DIB images, PE files with icon resources,
## ICNS archives and binary plists. The encoders live here (not in src/) because the app only reads these formats.


## Builds a DIB (header + palette/pixels + AND mask) from an RGBA8 image.
## bpp: 32 (BGRA), 24, 8 (needs <=256 distinct colours) or 1 (needs <=2).
static func build_dib(img: Image, bpp: int = 32, with_mask: bool = true) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var pal: Array[Color] = []
	if bpp <= 8:
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				c.a = 1.0
				if not pal.has(c):
					pal.append(c)
	var stride := ((w * bpp + 31) / 32) * 4
	var mask_stride := ((w + 31) / 32) * 4
	var out := PackedByteArray()
	var head := PackedByteArray()
	head.resize(40)
	head.encode_u32(0, 40)
	head.encode_s32(4, w)
	head.encode_s32(8, h * 2 if with_mask else h)
	head.encode_u16(12, 1)
	head.encode_u16(14, bpp)
	if bpp <= 8:
		head.encode_u32(32, pal.size())
	out.append_array(head)
	if bpp <= 8:
		for c in pal:
			out.append(c.b8)
			out.append(c.g8)
			out.append(c.r8)
			out.append(0)
	for row in range(h - 1, -1, -1):
		var line := PackedByteArray()
		line.resize(stride)
		for x in w:
			var c := img.get_pixel(x, row)
			match bpp:
				32:
					line[x * 4] = c.b8
					line[x * 4 + 1] = c.g8
					line[x * 4 + 2] = c.r8
					line[x * 4 + 3] = c.a8
				24:
					line[x * 3] = c.b8
					line[x * 3 + 1] = c.g8
					line[x * 3 + 2] = c.r8
				8:
					line[x] = pal.find(Color(c.r, c.g, c.b, 1.0))
				1:
					if pal.find(Color(c.r, c.g, c.b, 1.0)) == 1:
						line[x >> 3] = line[x >> 3] | (0x80 >> (x & 7))
		out.append_array(line)
	if with_mask:
		for row in range(h - 1, -1, -1):
			var mline := PackedByteArray()
			mline.resize(mask_stride)
			for x in w:
				if img.get_pixel(x, row).a8 < 128:
					mline[x >> 3] = mline[x >> 3] | (0x80 >> (x & 7))
			out.append_array(mline)
	return out


## Builds an .ico from [{image: Image, png: bool, bpp: int}] entries.
static func build_ico(entries: Array) -> PackedByteArray:
	var datas := []
	for e in entries:
		var img: Image = e.image
		if e.get("png", false):
			datas.append(img.save_png_to_buffer())
		else:
			datas.append(build_dib(img, int(e.get("bpp", 32))))
	var out := PackedByteArray()
	out.resize(6 + entries.size() * 16)
	out.encode_u16(2, 1)
	out.encode_u16(4, entries.size())
	var offset := out.size()
	for i in entries.size():
		var img2: Image = entries[i].image
		var o := 6 + i * 16
		out[o] = 0 if img2.get_width() >= 256 else img2.get_width()
		out[o + 1] = 0 if img2.get_height() >= 256 else img2.get_height()
		out.encode_u16(o + 4, 1)
		out.encode_u16(o + 6, 32 if entries[i].get("png", false) else int(entries[i].get("bpp", 32)))
		out.encode_u32(o + 8, datas[i].size())
		out.encode_u32(o + 12, offset)
		offset += datas[i].size()
	for dd in datas:
		out.append_array(dd)
	return out



## Builds a minimal but structurally valid PE32(+) image whose .rsrc holds the given icon groups.
## groups: Array of Array[{image: Image, png: bool, bpp: int}] (one icon group each).
static func build_pe(groups: Array, pe32_plus: bool = false) -> PackedByteArray:
	# Collect RT_ICON blobs and group directories.
	var icon_blobs := []
	var group_blobs := []
	var next_id := 1
	for g in groups:
		var grp := PackedByteArray()
		grp.resize(6)
		grp.encode_u16(2, 1)
		grp.encode_u16(4, g.size())
		for e in g:
			var img: Image = e.image
			var blob: PackedByteArray
			var bpp := 32
			if e.get("png", false):
				blob = img.save_png_to_buffer()
			else:
				bpp = int(e.get("bpp", 32))
				blob = build_dib(img, bpp)
			icon_blobs.append(blob)
			var ge := PackedByteArray()
			ge.resize(14)
			ge[0] = 0 if img.get_width() >= 256 else img.get_width()
			ge[1] = 0 if img.get_height() >= 256 else img.get_height()
			ge.encode_u16(4, 1)
			ge.encode_u16(6, bpp)
			ge.encode_u32(8, blob.size())
			ge.encode_u16(12, next_id)
			next_id += 1
			grp.append_array(ge)
		group_blobs.append(grp)
	# Resource tree layout (all offsets relative to the section start).
	# root dir -> type dirs -> name dirs -> language dirs -> data entries -> data.
	var n_icons := icon_blobs.size()
	var n_groups := group_blobs.size()
	var tree := PackedByteArray()
	var root_off := 0
	var root_size := 16 + 2 * 8
	var icon_type_off := root_size
	var icon_type_size := 16 + n_icons * 8
	var group_type_off := icon_type_off + icon_type_size
	var group_type_size := 16 + n_groups * 8
	var lang_base := group_type_off + group_type_size
	# every leaf has: lang dir (16+8) + data entry (16)
	var leaf_size := 24 + 16
	var data_entries_base := lang_base
	var total_leaves := n_icons + n_groups
	var data_base := data_entries_base + total_leaves * leaf_size
	data_base = (data_base + 3) & ~3
	tree.resize(data_base)
	# root: type entries sorted by id (3 then 14)
	tree.encode_u16(14, 2)
	tree.encode_u32(16, RT_ICON)
	tree.encode_u32(20, 0x80000000 | icon_type_off)
	tree.encode_u32(24, RT_GROUP_ICON)
	tree.encode_u32(28, 0x80000000 | group_type_off)
	tree.encode_u16(icon_type_off + 14, n_icons)
	tree.encode_u16(group_type_off + 14, n_groups)
	var blobs := []
	blobs.append_array(icon_blobs)
	blobs.append_array(group_blobs)
	var data_cursor := data_base
	var data_chunks := PackedByteArray()
	var section_rva := 0x1000
	for i in total_leaves:
		var leaf_off := data_entries_base + i * leaf_size
		var is_icon := i < n_icons
		var res_id := (i + 1) if is_icon else (i - n_icons + 1)
		var type_dir := icon_type_off if is_icon else group_type_off
		var slot := (i if is_icon else i - n_icons)
		tree.encode_u32(type_dir + 16 + slot * 8, res_id)
		tree.encode_u32(type_dir + 20 + slot * 8, 0x80000000 | leaf_off)
		# language dir with one id entry (lang 1033)
		tree.encode_u16(leaf_off + 14, 1)
		tree.encode_u32(leaf_off + 16, 1033)
		tree.encode_u32(leaf_off + 20, leaf_off + 24)
		# data entry
		var de := leaf_off + 24
		var blob: PackedByteArray = blobs[i]
		tree.encode_u32(de, section_rva + data_cursor)
		tree.encode_u32(de + 4, blob.size())
		data_chunks.append_array(blob)
		var pad := (4 - (blob.size() % 4)) % 4
		for _p in pad:
			data_chunks.append(0)
		data_cursor += blob.size() + pad
	var rsrc := tree
	rsrc.append_array(data_chunks)
	# PE container
	var opt_size := 240 if pe32_plus else 224
	var headers_size := 0x80 + 24 + opt_size + 40
	var file_align := 0x200
	var raw_ptr := (headers_size + file_align - 1) / file_align * file_align
	var raw_size := (rsrc.size() + file_align - 1) / file_align * file_align
	var pe := PackedByteArray()
	pe.resize(raw_ptr)
	pe[0] = 0x4D
	pe[1] = 0x5A
	pe.encode_u32(0x3C, 0x80)
	var p := 0x80
	pe[p] = 0x50
	pe[p + 1] = 0x45
	pe.encode_u16(p + 4, 0x8664 if pe32_plus else 0x14C)
	pe.encode_u16(p + 6, 1)
	pe.encode_u16(p + 20, opt_size)
	var opt := p + 24
	pe.encode_u16(opt, 0x20B if pe32_plus else 0x10B)
	var dd_start := opt + (112 if pe32_plus else 96)
	pe.encode_u32(dd_start - 4, 16)
	pe.encode_u32(dd_start + 16, section_rva)
	pe.encode_u32(dd_start + 20, rsrc.size())
	var sec := opt + opt_size
	var name := ".rsrc".to_ascii_buffer()
	for i in name.size():
		pe[sec + i] = name[i]
	pe.encode_u32(sec + 8, rsrc.size())
	pe.encode_u32(sec + 12, section_rva)
	pe.encode_u32(sec + 16, raw_size)
	pe.encode_u32(sec + 20, raw_ptr)
	var padded := rsrc.duplicate()
	padded.resize(raw_size)
	pe.append_array(padded)
	return pe



static func _put_be32(b: PackedByteArray, o: int, v: int) -> void:
	b[o] = (v >> 24) & 0xff
	b[o + 1] = (v >> 16) & 0xff
	b[o + 2] = (v >> 8) & 0xff
	b[o + 3] = v & 0xff


static func icns_element(type: String, data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(8)
	var t := type.to_ascii_buffer()
	for i in 4:
		out[i] = t[i]
	_put_be32(out, 4, 8 + data.size())
	out.append_array(data)
	return out


static func icns_build(elements: Array) -> PackedByteArray:
	var body := PackedByteArray()
	for e in elements:
		body.append_array(e)
	var out := PackedByteArray()
	out.resize(8)
	out[0] = 0x69
	out[1] = 0x63
	out[2] = 0x6E
	out[3] = 0x73
	_put_be32(out, 4, 8 + body.size())
	out.append_array(body)
	return out


## Encodes a byte plane with the same RLE the decoder reads (runs >= 3, literals up to 128).
static func icns_pack_rle(plane: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	var n := plane.size()
	while i < n:
		var run := 1
		while i + run < n and plane[i + run] == plane[i] and run < 130:
			run += 1
		if run >= 3:
			out.append(run + 125)
			out.append(plane[i])
			i += run
		else:
			var lit_end := i
			while lit_end < n and lit_end - i < 128:
				var r := 1
				while lit_end + r < n and plane[lit_end + r] == plane[lit_end] and r < 3:
					r += 1
				if r >= 3:
					break
				lit_end += 1
			if lit_end == i:
				lit_end = i + 1
			out.append(lit_end - i - 1)
			out.append_array(plane.slice(i, lit_end))
			i = lit_end
	return out



## Writes a flat string/int/bool dictionary as bplist00 (enough for fixtures).
static func plist_binary(values: Dictionary) -> PackedByteArray:
	var objects: Array = []  # each: PackedByteArray body
	var key_refs := []
	var val_refs := []
	for k in values:
		key_refs.append(objects.size())
		objects.append(_bplist_string(String(k)))
		val_refs.append(objects.size())
		var v: Variant = values[k]
		if v is bool:
			objects.append(PackedByteArray([0x09 if v else 0x08]))
		elif v is int:
			objects.append(PackedByteArray([0x10, v & 0xff]))
		else:
			objects.append(_bplist_string(String(v)))
	var dict_index := objects.size()
	var dict := PackedByteArray()
	var n := values.size()
	dict.append(0xD0 | n if n < 15 else 0xDF)
	if n >= 15:
		dict.append(0x10)
		dict.append(n)
	for r in key_refs:
		dict.append(r)
	for r in val_refs:
		dict.append(r)
	objects.append(dict)
	var out := "bplist00".to_ascii_buffer()
	var offsets := []
	for o in objects:
		offsets.append(out.size())
		out.append_array(o)
	var table_off := out.size()
	for off in offsets:
		out.append(off)  # offsets fit one byte in fixtures
	var trailer := PackedByteArray()
	trailer.resize(32)
	trailer[6] = 1
	trailer[7] = 1
	trailer[15] = objects.size()
	trailer[23] = dict_index
	trailer[31] = table_off & 0xff
	trailer[30] = (table_off >> 8) & 0xff
	out.append_array(trailer)
	return out


static func _bplist_string(s: String) -> PackedByteArray:
	var raw := s.to_ascii_buffer()
	var out := PackedByteArray()
	if raw.size() < 15:
		out.append(0x50 | raw.size())
	else:
		out.append(0x5F)
		out.append(0x10)
		out.append(raw.size())
	out.append_array(raw)
	return out


# ----------------------------------------------------------------------------- misc helpers

static func tmp_dir() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-plat-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


static func rm_rf(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for d in dir.get_directories():
		rm_rf(path.path_join(d))
	DirAccess.remove_absolute(path)


static func write_bytes(path: String, bytes: PackedByteArray) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	return path


static func write_text(path: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


## Four coloured quadrants (red, green, blue, yellow); the top-left 2x2 block is transparent.
static func quad(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var h := size / 2
	img.fill_rect(Rect2i(0, 0, h, h), Color8(255, 0, 0))
	img.fill_rect(Rect2i(h, 0, size - h, h), Color8(0, 255, 0))
	img.fill_rect(Rect2i(0, h, h, size - h), Color8(0, 0, 255))
	img.fill_rect(Rect2i(h, h, size - h, size - h), Color8(255, 255, 0))
	img.fill_rect(Rect2i(0, 0, 2, 2), Color(0, 0, 0, 0))
	return img


## Minimal MS-SHLLINK file: LinkInfo with a local base path + optional working dir / arguments.
static func build_lnk(target: String, cwd: String = "", args: String = "") -> PackedByteArray:
	var flags := 0x2 | 0x80  # HasLinkInfo | IsUnicode
	if cwd != "":
		flags |= 0x10
	if args != "":
		flags |= 0x20
	var out := PackedByteArray()
	out.resize(0x4c)
	out.encode_u32(0, 0x4c)
	out.encode_u32(0x14, flags)
	var base := target.to_ascii_buffer()
	var info := PackedByteArray()
	info.resize(0x1c)
	info.encode_u32(0, 0x1c + base.size() + 2)
	info.encode_u32(4, 0x1c)
	info.encode_u32(8, 1)
	info.encode_u32(0x10, 0x1c)
	info.encode_u32(0x18, 0x1c + base.size() + 1)
	info.append_array(base)
	info.append(0)
	info.append(0)
	out.append_array(info)
	for s in [cwd, args]:
		if String(s) != "":
			var w := PackedByteArray()
			w.resize(2)
			w.encode_u16(0, String(s).length())
			for i in String(s).length():
				var c := PackedByteArray()
				c.resize(2)
				c.encode_u16(0, String(s).unicode_at(i))
				w.append_array(c)
			out.append_array(w)
	return out
