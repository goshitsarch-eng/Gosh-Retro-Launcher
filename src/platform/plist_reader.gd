class_name PlistReader
extends RefCounted
## Minimal property-list reader for macOS Info.plist files: XML plists (top-level dict of
## string/integer/real/true/false values) and binary `bplist00` files (string/int/real/bool/
## dict/array/data). Returns {} for anything unreadable.


static func parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() >= 8 and bytes.slice(0, 6).get_string_from_ascii() == "bplist":
		var v: Variant = _parse_binary(bytes)
		return v if v is Dictionary else {}
	return _parse_xml(bytes.get_string_from_utf8())


static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > 8 * 1024 * 1024:
		return {}
	return parse(f.get_buffer(f.get_length()))


# ------------------------------------------------------------------ XML

static func _xml_unescape(s: String) -> String:
	return s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&apos;", "'").replace("&amp;", "&")


static func _parse_xml(text: String) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	# Top-level key/value pairs only: nested containers are skipped by the lazy scalar match.
	re.compile("<key>([^<]*)</key>\\s*(?:<string>([^<]*)</string>|<string\\s*/>|<integer>\\s*(-?\\d+)\\s*</integer>|<real>([^<]*)</real>|<(true|false)\\s*/>)")
	for m in re.search_all(text):
		var key := _xml_unescape(m.get_string(1))
		if out.has(key):
			continue
		if m.get_string(2) != "" or m.get_string(0).contains("<string"):
			out[key] = _xml_unescape(m.get_string(2))
		elif m.get_string(3) != "":
			out[key] = int(m.get_string(3))
		elif m.get_string(4) != "":
			out[key] = float(m.get_string(4))
		elif m.get_string(5) != "":
			out[key] = m.get_string(5) == "true"
	return out


# ------------------------------------------------------------------ binary

static func _be(b: PackedByteArray, o: int, n: int) -> int:
	var v := 0
	for i in n:
		v = (v << 8) | b[o + i]
	return v


static func _parse_binary(b: PackedByteArray) -> Variant:
	if b.size() < 8 + 32:
		return null
	var t := b.size() - 32
	var offset_size := b[t + 6]
	var ref_size := b[t + 7]
	var count := _be(b, t + 8, 8)
	var top := _be(b, t + 16, 8)
	var table := _be(b, t + 24, 8)
	if offset_size < 1 or offset_size > 8 or ref_size < 1 or ref_size > 8 or count <= 0 or count > 100000:
		return null
	if table + count * offset_size > t:
		return null
	var offsets := []
	for i in count:
		offsets.append(_be(b, table + i * offset_size, offset_size))
	return _read_object(b, offsets, ref_size, top, 0)


static func _read_length(b: PackedByteArray, pos: int, info: int) -> Array:
	# -> [length, data_start]
	if info != 0xF:
		return [info, pos + 1]
	if pos + 1 >= b.size():
		return [0, pos + 1]
	var size_marker := b[pos + 1]
	var n := 1 << (size_marker & 0x0f)
	if pos + 2 + n > b.size():
		return [0, pos + 2]
	return [_be(b, pos + 2, n), pos + 2 + n]


static func _read_object(b: PackedByteArray, offsets: Array, ref_size: int, index: int, depth: int) -> Variant:
	if depth > 16 or index < 0 or index >= offsets.size():
		return null
	var pos: int = offsets[index]
	if pos < 8 or pos >= b.size():
		return null
	var marker := b[pos]
	var type := marker >> 4
	var info := marker & 0x0f
	match type:
		0x0:
			if info == 0x8:
				return false
			if info == 0x9:
				return true
			return null
		0x1:
			var n := 1 << info
			if pos + 1 + n > b.size() or n > 8:
				return null
			return _be(b, pos + 1, n)
		0x2:
			var n2 := 1 << info
			if n2 == 8 and pos + 9 <= b.size():
				return b.slice(pos + 1, pos + 9).decode_double(0)
			if n2 == 4 and pos + 5 <= b.size():
				return b.slice(pos + 1, pos + 5).decode_float(0)
			return null
		0x4:
			var l := _read_length(b, pos, info)
			return b.slice(l[1], mini(l[1] + l[0], b.size()))
		0x5:
			var l2 := _read_length(b, pos, info)
			return b.slice(l2[1], mini(l2[1] + l2[0], b.size())).get_string_from_ascii()
		0x6:
			var l3 := _read_length(b, pos, info)
			var s := ""
			var end := mini(l3[1] + l3[0] * 2, b.size())
			var p: int = l3[1]
			while p + 1 < end:
				s += char((b[p] << 8) | b[p + 1])
				p += 2
			return s
		0xA:
			var l4 := _read_length(b, pos, info)
			var arr := []
			for i in l4[0]:
				var ro: int = l4[1] + i * ref_size
				if ro + ref_size > b.size():
					break
				arr.append(_read_object(b, offsets, ref_size, _be(b, ro, ref_size), depth + 1))
			return arr
		0xD:
			var l5 := _read_length(b, pos, info)
			var dict := {}
			for i in l5[0]:
				var ko: int = l5[1] + i * ref_size
				var vo: int = l5[1] + (l5[0] + i) * ref_size
				if vo + ref_size > b.size():
					break
				var k: Variant = _read_object(b, offsets, ref_size, _be(b, ko, ref_size), depth + 1)
				if k is String:
					dict[k] = _read_object(b, offsets, ref_size, _be(b, vo, ref_size), depth + 1)
			return dict
	return null
