class_name PeIcon
extends RefCounted
## Extracts the application icon from a Windows PE image (.exe/.dll/.scr/.ocx/...):
## walks IMAGE_RESOURCE_DIRECTORY for RT_GROUP_ICON / RT_ICON, picks the first icon group
## (what Explorer shows), chooses its largest decodable entry (PNG-in-ICO or BMP/DIB with
## AND mask) and returns an RGBA Image. Works on any OS (a Wine user may pick a .exe on Linux).
## Only the resource section is read from disk, so multi-hundred-MB installers stay cheap.

const RT_ICON := 3
const RT_GROUP_ICON := 14
const MAX_RSRC_READ := 64 * 1024 * 1024
const MAX_ENTRIES := 4096


## Source abstraction: whole buffer or an open file; both expose size() and read_range().
class Source:
	var bytes := PackedByteArray()
	var file: FileAccess = null
	var length := 0

	func size() -> int:
		return length

	func read_range(offset: int, count: int) -> PackedByteArray:
		if offset < 0 or count <= 0 or offset >= length:
			return PackedByteArray()
		count = mini(count, length - offset)
		if file != null:
			file.seek(offset)
			return file.get_buffer(count)
		return bytes.slice(offset, offset + count)


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func _u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


## Best application icon of the PE file at `path`, or null.
static func load_image(path: String) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var src := Source.new()
	src.file = f
	src.length = f.get_length()
	return _image_from_source(src)


static func image_from_bytes(pe: PackedByteArray) -> Image:
	var src := Source.new()
	src.bytes = pe
	src.length = pe.size()
	return _image_from_source(src)


static func _image_from_source(src: Source) -> Image:
	var rs := _read_resource_section(src)
	if rs.is_empty():
		return null
	var res := _collect_icon_resources(rs.data, rs.rva)
	for group in res.groups:
		var img := _best_from_group(group, res.icons)
		if img != null:
			return img
	return null


## {data: PackedByteArray (resource section from its start), rva: int} or {}.
static func _read_resource_section(src: Source) -> Dictionary:
	var dos := src.read_range(0, 0x40)
	if dos.size() < 0x40 or dos[0] != 0x4D or dos[1] != 0x5A:
		return {}
	var pe_off := _u32(dos, 0x3C)
	if pe_off < 0x40 or pe_off > src.size() - 24:
		return {}
	var hdr := src.read_range(pe_off, 24 + 240 + 40 * 96)
	if hdr.size() < 24 or hdr[0] != 0x50 or hdr[1] != 0x45 or hdr[2] != 0 or hdr[3] != 0:
		return {}
	var num_sections := _u16(hdr, 6)
	var size_opt := _u16(hdr, 20)
	var opt := 24
	if opt + 2 > hdr.size():
		return {}
	var magic := _u16(hdr, opt)
	var dd_start := 0
	if magic == 0x10B:
		dd_start = opt + 96
	elif magic == 0x20B:
		dd_start = opt + 112
	else:
		return {}
	var num_dirs_off := dd_start - 4
	if dd_start + 8 * 3 > hdr.size() or _u32(hdr, num_dirs_off) < 3:
		return {}
	var rsrc_rva := _u32(hdr, dd_start + 16)
	if rsrc_rva == 0:
		return {}
	var sec_table := opt + size_opt
	if num_sections > 96:
		num_sections = 96
	for i in num_sections:
		var so := sec_table + i * 40
		if so + 40 > hdr.size():
			break
		var va := _u32(hdr, so + 12)
		var vsize := _u32(hdr, so + 8)
		var raw_size := _u32(hdr, so + 16)
		var raw_ptr := _u32(hdr, so + 20)
		var span := maxi(vsize, raw_size)
		if rsrc_rva >= va and rsrc_rva < va + span:
			var start := raw_ptr + (rsrc_rva - va)
			var avail := raw_size - (rsrc_rva - va)
			if avail <= 0:
				return {}
			# Data entries may live after the nominal directory size inside the section, so read
			# the rest of the section (bounded) rather than only rsrc_size bytes.
			var want := mini(avail, MAX_RSRC_READ)
			var data := src.read_range(start, want)
			if data.size() < 16:
				return {}
			return {"data": data, "rva": rsrc_rva}
	return {}


## Entries of the resource directory at `off`: [{id, named, target, is_dir}].
static func _dir_entries(rs: PackedByteArray, off: int) -> Array:
	var out := []
	if off < 0 or off + 16 > rs.size():
		return out
	var n := mini(_u16(rs, off + 12) + _u16(rs, off + 14), MAX_ENTRIES)
	for i in n:
		var eo := off + 16 + i * 8
		if eo + 8 > rs.size():
			break
		var name := _u32(rs, eo)
		var target := _u32(rs, eo + 4)
		out.append({
			"id": name & 0x7fffffff,
			"named": (name & 0x80000000) != 0,
			"target": target & 0x7fffffff,
			"is_dir": (target & 0x80000000) != 0,
		})
	return out


## Reads the first data leaf below a (sub)directory entry. Returns the raw resource bytes or empty.
static func _leaf_data(rs: PackedByteArray, rva_base: int, entry: Dictionary) -> PackedByteArray:
	var node := entry
	var depth := 0
	while node.is_dir and depth < 4:
		var kids := _dir_entries(rs, int(node.target))
		if kids.is_empty():
			return PackedByteArray()
		node = kids[0]
		depth += 1
	if node.is_dir:
		return PackedByteArray()
	var de := int(node.target)
	if de + 16 > rs.size():
		return PackedByteArray()
	var rva := _u32(rs, de)
	var size := _u32(rs, de + 4)
	var rel := rva - rva_base
	if rel < 0 or size <= 0 or rel + size > rs.size():
		return PackedByteArray()
	return rs.slice(rel, rel + size)


## {groups: [PackedByteArray in resource order], icons: {id: PackedByteArray}}
static func _collect_icon_resources(rs: PackedByteArray, rva_base: int) -> Dictionary:
	var groups := []
	var icons := {}
	for t in _dir_entries(rs, 0):
		if t.named or not t.is_dir:
			continue
		if t.id == RT_ICON:
			for e in _dir_entries(rs, int(t.target)):
				var data := _leaf_data(rs, rva_base, e)
				if not data.is_empty() and not e.named:
					icons[e.id] = data
		elif t.id == RT_GROUP_ICON:
			for e2 in _dir_entries(rs, int(t.target)):
				var gdata := _leaf_data(rs, rva_base, e2)
				if not gdata.is_empty():
					groups.append(gdata)
	return {"groups": groups, "icons": icons}


## GRPICONDIR: 6-byte header + 14-byte entries (width, height, colors, 0, planes, bpp, bytes, id).
static func _best_from_group(group: PackedByteArray, icons: Dictionary) -> Image:
	if group.size() < 6 or _u16(group, 2) != 1:
		return null
	var count := mini(_u16(group, 4), 256)
	var entries := []
	for i in count:
		var o := 6 + i * 14
		if o + 14 > group.size():
			break
		var w := group[o]
		var h := group[o + 1]
		entries.append({
			"width": 256 if w == 0 else w,
			"height": 256 if h == 0 else h,
			"bpp": _u16(group, o + 6),
			"id": _u16(group, o + 12),
		})
	entries.sort_custom(IcoFile.compare_entries)
	for e in entries:
		if not icons.has(e.id):
			continue
		var img := IcoFile.decode_image_data(icons[e.id])
		if img != null:
			return img
	return null
