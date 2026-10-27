class_name Grp
extends RefCounted
## Windows 3.x Program Manager .GRP codec. Port of src/shared/win31Grp.ts.

const HEADER_SIZE := 32
const ITEM_SIZE := 20
const MAX_ITEMS := 512
const PMCC := [0x50, 0x4d, 0x43, 0x43]

## Windows-1252 0x80..0x9F -> Unicode code points (0 = undefined, falls back to the C1 control).
const CP1252_HIGH := [
	0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
	0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
]


## Error carrier (GDScript has no exceptions): parse returns {"ok":false,"error":...}.
static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _u16(b: PackedByteArray, o: int) -> int:
	return b[o] | (b[o + 1] << 8)


static func _i16(b: PackedByteArray, o: int) -> int:
	var v := _u16(b, o)
	return v - 0x10000 if v >= 0x8000 else v


static func _put_u16(b: PackedByteArray, o: int, v: int) -> void:
	b[o] = v & 0xff
	b[o + 1] = (v >> 8) & 0xff


static func _decode_cp1252(bytes: PackedByteArray) -> String:
	var s := ""
	for c in bytes:
		if c >= 0x80 and c <= 0x9f and CP1252_HIGH[c - 0x80] != 0:
			s += char(CP1252_HIGH[c - 0x80])
		else:
			s += char(c)
	return s


static func _read_cstring(bytes: PackedByteArray, offset: int) -> String:
	if offset <= 0 or offset >= bytes.size():
		return ""
	var end := offset
	while end < bytes.size() and bytes[end] != 0:
		end += 1
	return _decode_cp1252(bytes.slice(offset, end)).strip_edges()


static func _encode_ansi(value: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in value.length():
		var code := value.unicode_at(i)
		out.append(code if code <= 0xff else 0x3f)
	out.append(0)
	return out


static func split_legacy_command(command: String) -> Dictionary:
	var value := command.strip_edges()
	if value.is_empty():
		return {"path": "", "arguments": ""}
	if value.begins_with('"'):
		var closing := value.find('"', 1)
		if closing > 0:
			return {"path": value.substr(1, closing - 1), "arguments": value.substr(closing + 1).strip_edges()}
	var re := RegEx.new()
	re.compile("(?i)^(.+?\\.(?:exe|com|bat|cmd|pif))(?:\\s+(.*))?$")
	var m := re.search(value)
	if m:
		return {"path": m.get_string(1), "arguments": m.get_string(2) if m.get_start(2) >= 0 else ""}
	var sep := -1
	for i in value.length():
		if " \t\r\n".contains(value[i]):
			sep = i
			break
	if sep < 0:
		return {"path": value, "arguments": ""}
	return {"path": value.substr(0, sep), "arguments": value.substr(sep + 1).strip_edges()}


## Returns {"ok":true,"group":Dictionary} or {"ok":false,"error":String}.
static func parse(input: PackedByteArray) -> Dictionary:
	if input.size() < HEADER_SIZE:
		return _fail("The file is too small to be a Program Manager group.")
	for i in 4:
		if input[i] != PMCC[i]:
			return _fail("The file does not contain a PMCC Program Manager group header.")
	var declared := _u16(input, 6)
	var file_size := declared if (declared >= HEADER_SIZE and declared <= input.size()) else input.size()
	var bytes := input.slice(0, file_size)
	var count := _u16(bytes, 30)
	if count > MAX_ITEMS or HEADER_SIZE + count * 2 > file_size:
		return _fail("The Program Manager group has an invalid item table.")
	var group_name := _read_cstring(bytes, _u16(bytes, 22))
	if group_name.is_empty():
		group_name = "Imported Group"
	var left := _i16(bytes, 10)
	var top := _i16(bytes, 12)
	var right := _i16(bytes, 14)
	var bottom := _i16(bytes, 16)
	var dws := Types.default_window_state()
	var width := maxi(150, (right - left) if right > left else int(dws.width))
	var height := maxi(92, (bottom - top) if bottom > top else int(dws.height))
	var show_command := _u16(bytes, 8)
	var group_state := {
		"x": maxi(0, left),
		"y": maxi(0, top),
		"width": width,
		"height": height,
		"minimized": show_command == 2 or show_command == 6,
		"maximized": show_command == 3,
	}
	var items := []
	for index in count:
		var item_offset := _u16(bytes, HEADER_SIZE + index * 2)
		if item_offset < HEADER_SIZE or item_offset + ITEM_SIZE > file_size:
			continue
		var name := _read_cstring(bytes, _u16(bytes, item_offset + 14))
		if name.is_empty():
			name = "Program %d" % (index + 1)
		var command := _read_cstring(bytes, _u16(bytes, item_offset + 16))
		var icon_path := _read_cstring(bytes, _u16(bytes, item_offset + 18))
		var parsed := split_legacy_command(command)
		if String(parsed.path).is_empty():
			continue
		var item := {
			"id": Types.make_id(),
			"name": name,
			"path": parsed.path,
			"arguments": parsed.arguments,
			"workingDir": "",
			"icon": "default",
		}
		if not icon_path.is_empty() and icon_path != parsed.path:
			item["win31Icon"] = "default"
		item["win31Position"] = {
			"x": maxi(0, _i16(bytes, item_offset)),
			"y": maxi(0, _i16(bytes, item_offset + 2)),
		}
		items.append(item)
	return {
		"ok": true,
		"group": {
			"id": Types.make_id(),
			"name": group_name,
			"icon": "group",
			"windowState": group_state.duplicate(true),
			"shellWindowState": Types.create_shell_window_state(group_state),
			"items": items,
		},
	}


static func _command_for(item: Dictionary) -> String:
	var path := String(item.get("path", ""))
	var quoted := '"%s"' % path if (path.contains(" ") or path.contains("\t")) else path
	var args := String(item.get("arguments", "")).strip_edges()
	return "%s %s" % [quoted, args] if not args.is_empty() else quoted


static func _clamp16(v: float, lo: int, hi: int) -> int:
	return clampi(int(roundf(v)), lo, hi)


## Returns {"ok":true,"bytes":PackedByteArray} or {"ok":false,"error":String}.
static func serialize(group: Dictionary) -> Dictionary:
	var items: Array = group.get("items", [])
	if items.size() > MAX_ITEMS:
		return _fail("A .GRP file can contain at most %d items." % MAX_ITEMS)
	var table_size := HEADER_SIZE + items.size() * 2
	var item_base := table_size + (table_size % 2)
	var item_offsets := []
	for i in items.size():
		item_offsets.append(item_base + i * ITEM_SIZE)
	var chunk := PackedByteArray()
	chunk.resize(item_base + items.size() * ITEM_SIZE)

	var append_string := func(value: String) -> int:
		if chunk.size() % 2 == 1:
			chunk.append(0)
		var offset := chunk.size()
		chunk.append_array(_encode_ansi(value))
		return offset

	var group_name_offset: int = append_string.call(String(group.get("name", "")))
	var strings := []
	for item in items:
		strings.append({
			"name": append_string.call(String(item.get("name", ""))),
			"command": append_string.call(_command_for(item)),
			"icon": append_string.call(String(item.get("path", ""))),
		})
	if chunk.size() % 2 == 1:
		chunk.append(0)
	if chunk.size() > 0xffff:
		return _fail("The group is too large for the Windows 3.x .GRP format.")
	var out := chunk
	for i in 4:
		out[i] = PMCC[i]
	_put_u16(out, 6, out.size())
	var shell_states: Variant = group.get("shellWindowState")
	var state: Dictionary = shell_states.win31 if (Jsonx.is_obj(shell_states) and Jsonx.is_obj(shell_states.get("win31"))) else group.get("windowState", Types.default_window_state())
	var minimized: bool = state.get("minimized", false)
	var maximized: bool = state.get("maximized", false)
	_put_u16(out, 8, 2 if minimized else (3 if maximized else 1))
	var sx := float(state.get("x", 0))
	var sy := float(state.get("y", 0))
	_put_u16(out, 10, _clamp16(sx, -32768, 32767) & 0xffff)
	_put_u16(out, 12, _clamp16(sy, -32768, 32767) & 0xffff)
	_put_u16(out, 14, _clamp16(sx + float(state.get("width", 0)), -32768, 32767) & 0xffff)
	_put_u16(out, 16, _clamp16(sy + float(state.get("height", 0)), -32768, 32767) & 0xffff)
	_put_u16(out, 18, 0)
	_put_u16(out, 20, 0)
	_put_u16(out, 22, group_name_offset)
	_put_u16(out, 24, 32)
	_put_u16(out, 26, 32)
	_put_u16(out, 28, 1)
	_put_u16(out, 30, items.size())
	for index in items.size():
		var item: Dictionary = items[index]
		var offset: int = item_offsets[index]
		_put_u16(out, HEADER_SIZE + index * 2, offset)
		var pos: Variant = item.get("win31Position")
		var px: float = float(pos.x) if Jsonx.is_obj(pos) else float((index % 5) * 75)
		var py: float = float(pos.y) if Jsonx.is_obj(pos) else float((index / 5) * 72)
		_put_u16(out, offset, _clamp16(px, 0, 32767))
		_put_u16(out, offset + 2, _clamp16(py, 0, 32767))
		for o in [4, 6, 8, 10, 12]:
			_put_u16(out, offset + o, 0)
		_put_u16(out, offset + 14, strings[index].name)
		_put_u16(out, offset + 16, strings[index].command)
		_put_u16(out, offset + 18, strings[index].icon)
	# Program Manager validates that the unsigned 16-bit word sum is zero.
	var sum := 0
	var o2 := 0
	while o2 < out.size():
		var hi := out[o2 + 1] if o2 + 1 < out.size() else 0
		sum = (sum + (out[o2] | (hi << 8))) & 0xffff
		o2 += 2
	_put_u16(out, 4, (-sum) & 0xffff)
	return {"ok": true, "bytes": out}
