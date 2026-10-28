class_name IcnsFile
extends RefCounted
## Apple .icns reader. Supports every PNG-payload element (icp4..icp6, ic07..ic14, ic04/ic05 when
## stored as PNG), the legacy planar RLE RGB types (is32/il32/ih32/it32 + 8-bit masks
## s8mk/l8mk/h8mk/t8mk) and the ARGB RLE types (ic04/ic05). JPEG-2000 payloads are skipped
## because Godot has no decoder for them.

## Legacy RGB element -> [pixel size, mask element]
const LEGACY := {
	"is32": [16, "s8mk"],
	"il32": [32, "l8mk"],
	"ih32": [48, "h8mk"],
	"it32": [128, "t8mk"],
}
## ARGB-RLE elements -> pixel size
const ARGB := {"ic04": 16, "ic05": 32}


static func _be32(b: PackedByteArray, o: int) -> int:
	return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


static func _tag(b: PackedByteArray, o: int) -> String:
	return b.slice(o, o + 4).get_string_from_ascii()


static func is_icns(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 8 and _tag(bytes, 0) == "icns"


## [{type, data}] for every well-formed element.
static func parse_elements(bytes: PackedByteArray) -> Array:
	var out := []
	if not is_icns(bytes):
		return out
	var total := mini(_be32(bytes, 4), bytes.size())
	var pos := 8
	while pos + 8 <= total:
		var length := _be32(bytes, pos + 4)
		if length < 8 or pos + length > total:
			break
		out.append({"type": _tag(bytes, pos), "data": bytes.slice(pos + 8, pos + length)})
		pos += length
	return out


static func _is_jp2(data: PackedByteArray) -> bool:
	return data.size() > 12 and data[4] == 0x6A and data[5] == 0x50 and data[6] == 0x20 and data[7] == 0x20


## Largest decodable image (PNG payloads first, then legacy RLE), or null.
static func best_image(bytes: PackedByteArray) -> Image:
	var elements := parse_elements(bytes)
	if elements.is_empty():
		return null
	var best: Image = null
	var by_type := {}
	for e in elements:
		by_type[e.type] = e.data
		if IcoFile.is_png(e.data):
			var img := Image.new()
			if img.load_png_from_buffer(e.data) == OK and not img.is_empty():
				if best == null or img.get_width() * img.get_height() > best.get_width() * best.get_height():
					img.convert(Image.FORMAT_RGBA8)
					best = img
	if best != null:
		return best
	for key in ARGB:
		if by_type.has(key) and not IcoFile.is_png(by_type[key]) and not _is_jp2(by_type[key]):
			var argb := decode_argb(by_type[key], int(ARGB[key]))
			if argb != null and (best == null or argb.get_width() > best.get_width()):
				best = argb
	for key in LEGACY:
		if not by_type.has(key):
			continue
		var size: int = LEGACY[key][0]
		if best != null and best.get_width() >= size:
			continue
		var rgb := decode_legacy(by_type[key], size, by_type.get(LEGACY[key][1], PackedByteArray()))
		if rgb != null:
			best = rgb
	return best


## Apple's packbits variant: n < 128 -> copy n+1 literals, n >= 128 -> repeat next byte n-125 times.
## Returns the decoded bytes or an empty array when the stream is truncated.
static func unpack_rle(data: PackedByteArray, start: int, expected: int) -> Dictionary:
	var out := PackedByteArray()
	var pos := start
	while out.size() < expected and pos < data.size():
		var n := data[pos]
		pos += 1
		if n < 128:
			var count := n + 1
			if pos + count > data.size():
				return {}
			out.append_array(data.slice(pos, pos + count))
			pos += count
		else:
			if pos >= data.size():
				return {}
			var value := data[pos]
			pos += 1
			for _i in n - 125:
				out.append(value)
	if out.size() < expected:
		return {}
	out.resize(expected)
	return {"data": out, "next": pos}


## it32/il32/is32/ih32 element: three RLE planes (R, G, B); it32 has 4 leading zero bytes.
static func decode_legacy(data: PackedByteArray, size: int, mask: PackedByteArray) -> Image:
	var pixels := size * size
	var pos := 0
	if size == 128 and data.size() >= 4 and data[0] == 0 and data[1] == 0 and data[2] == 0 and data[3] == 0:
		pos = 4
	var planes := []
	if data.size() == pixels * 3:  # some writers store the planes uncompressed
		for p in 3:
			planes.append(data.slice(pos + p * pixels, pos + (p + 1) * pixels))
	else:
		for _p in 3:
			var plane := unpack_rle(data, pos, pixels)
			if plane.is_empty():
				return null
			planes.append(plane.data)
			pos = plane.next
	var out := PackedByteArray()
	out.resize(pixels * 4)
	var has_mask := mask.size() >= pixels
	for i in pixels:
		out[i * 4] = planes[0][i]
		out[i * 4 + 1] = planes[1][i]
		out[i * 4 + 2] = planes[2][i]
		out[i * 4 + 3] = mask[i] if has_mask else 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, out)


## ic04/ic05: "ARGB" magic followed by four RLE planes (A, R, G, B).
static func decode_argb(data: PackedByteArray, size: int) -> Image:
	if data.size() < 4 or _tag(data, 0) != "ARGB":
		return null
	var pixels := size * size
	var pos := 4
	var planes := []
	for _p in 4:
		var plane := unpack_rle(data, pos, pixels)
		if plane.is_empty():
			return null
		planes.append(plane.data)
		pos = plane.next
	var out := PackedByteArray()
	out.resize(pixels * 4)
	for i in pixels:
		out[i * 4] = planes[1][i]
		out[i * 4 + 1] = planes[2][i]
		out[i * 4 + 2] = planes[3][i]
		out[i * 4 + 3] = planes[0][i]
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, out)
