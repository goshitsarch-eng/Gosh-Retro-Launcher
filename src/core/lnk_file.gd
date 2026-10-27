class_name LnkFile
extends RefCounted
## Minimal MS-SHLLINK (.lnk) reader replacing Electron's shell.readShortcutLink.
## Returns {target, cwd, args, icon} or {} when the file is not a usable shortcut.


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func _u32(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


static func _cstr(b: PackedByteArray, o: int) -> String:
	var e := o
	while e < b.size() and b[e] != 0:
		e += 1
	return b.slice(o, e).get_string_from_utf8() if e > o else ""


static func _wstr(b: PackedByteArray, o: int, chars: int) -> String:
	var s := ""
	for i in chars:
		if o + i * 2 + 1 >= b.size():
			break
		s += char(_u16(b, o + i * 2))
	return s


static func read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var b := f.get_buffer(mini(f.get_length(), 1 << 20))
	return parse(b)


static func parse(b: PackedByteArray) -> Dictionary:
	if b.size() < 0x4c or _u32(b, 0) != 0x4c:
		return {}
	var flags := _u32(b, 0x14)
	var off := 0x4c
	if flags & 0x1:  # HasLinkTargetIDList
		if off + 2 > b.size():
			return {}
		off += 2 + _u16(b, off)
	var target := ""
	if flags & 0x2:  # HasLinkInfo
		if off + 0x1c > b.size():
			return {}
		var info_size := _u32(b, off)
		var info_flags := _u32(b, off + 8)
		var local_base_off := _u32(b, off + 0x10)
		var suffix_off := _u32(b, off + 0x18)
		if info_flags & 0x1 and local_base_off > 0:
			target = _cstr(b, off + local_base_off)
			if suffix_off > 0:
				target += _cstr(b, off + suffix_off)
		off += info_size
	var unicode := (flags & 0x80) != 0
	var strings := {}
	for pair in [[0x4, "name"], [0x8, "relative"], [0x10, "cwd"], [0x20, "args"], [0x40, "icon"]]:
		if flags & int(pair[0]):
			if off + 2 > b.size():
				break
			var count := _u16(b, off)
			off += 2
			if unicode:
				strings[pair[1]] = _wstr(b, off, count)
				off += count * 2
			else:
				strings[pair[1]] = b.slice(off, off + count).get_string_from_ascii()
				off += count
	if target.is_empty():
		return {}
	return {"target": target, "cwd": strings.get("cwd", ""), "args": strings.get("args", ""), "icon": strings.get("icon", "")}
