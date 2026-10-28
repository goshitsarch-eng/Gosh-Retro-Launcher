class_name IconImage
extends RefCounted
## Image helpers for imported application icons: sniffing loader, 128x128 PNG data URL,
## and the 32x32 Windows-for-Workgroups palette quantization (port of paletteLimitedIcon
## in src/main/ipc/appInfoHandlers.ts).

## The fixed 16-colour WfW palette (identical order to WFW_PALETTE in the TS source).
const WFW_PALETTE := [
	[0, 0, 0], [128, 128, 128], [192, 192, 192], [255, 255, 255],
	[0, 0, 128], [0, 0, 255], [0, 128, 0], [0, 128, 128],
	[128, 0, 0], [128, 0, 128], [128, 128, 0], [255, 0, 0],
	[0, 255, 0], [255, 255, 0], [0, 255, 255], [255, 0, 255],
]

const ICON_SIZE := 128
const WIN31_SIZE := 32
const ALPHA_CUTOFF := 16
const MAX_IMAGE_BYTES := 64 * 1024 * 1024


## Index into WFW_PALETTE of the nearest colour (squared RGB distance, first wins on ties).
static func nearest_index(r: int, g: int, b: int) -> int:
	var best := 0
	var distance := 0x7fffffff
	for i in WFW_PALETTE.size():
		var c: Array = WFW_PALETTE[i]
		var dr := r - int(c[0])
		var dg := g - int(c[1])
		var db := b - int(c[2])
		var d := dr * dr + dg * dg + db * db
		if d < distance:
			distance = d
			best = i
	return best


## Replaces every pixel with alpha >= 16 by its nearest palette colour (alpha untouched).
## Operates on an RGBA8 copy; the input image is not modified.
static func quantize_to_wfw(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var data := out.get_data()
	var cache := {}
	var i := 0
	var n := data.size()
	while i + 3 < n:
		if data[i + 3] >= ALPHA_CUTOFF:
			var key := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			var idx: int
			if cache.has(key):
				idx = cache[key]
			else:
				idx = nearest_index(data[i], data[i + 1], data[i + 2])
				cache[key] = idx
			var c: Array = WFW_PALETTE[idx]
			data[i] = c[0]
			data[i + 1] = c[1]
			data[i + 2] = c[2]
		i += 4
	return Image.create_from_data(out.get_width(), out.get_height(), false, Image.FORMAT_RGBA8, data)


## Scales to a square canvas of `size` (aspect preserved, centred, transparent padding).
static func fit_square(img: Image, size: int) -> Image:
	var src := img.duplicate() as Image
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	if w <= 0 or h <= 0:
		return null
	if w == size and h == size:
		return src
	# Bleed colour into transparent pixels so Lanczos does not darken the edges.
	src.fix_alpha_edges()
	var scale := float(size) / float(maxi(w, h))
	var nw := maxi(1, int(roundf(w * scale)))
	var nh := maxi(1, int(roundf(h * scale)))
	src.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	if nw == size and nh == size:
		return src
	var canvas := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(src, Rect2i(0, 0, nw, nh), Vector2i((size - nw) / 2, (size - nh) / 2))
	return canvas


static func to_data_url(img: Image) -> String:
	return "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())


## {icon: 128x128 PNG data URL, win31Icon: 32x32 palette-limited PNG data URL} or {} for null/empty.
static func icons_from_image(img: Image) -> Dictionary:
	if img == null or img.is_empty():
		return {}
	var full := fit_square(img, ICON_SIZE)
	var small := fit_square(img, WIN31_SIZE)
	if full == null or small == null:
		return {}
	return {
		"icon": to_data_url(full),
		"win31Icon": to_data_url(quantize_to_wfw(small)),
	}


## Loads any bitmap/vector format by sniffing magic bytes (the extension is only a hint, which
## makes mislabelled files and extension-less icon names work). Returns null on failure.
static func load_any(bytes: PackedByteArray, svg_size: int = ICON_SIZE) -> Image:
	if bytes.size() < 4 or bytes.size() > MAX_IMAGE_BYTES:
		return null
	if IcoFile.is_png(bytes):
		return _finish(_try(bytes, "load_png_from_buffer"))
	if bytes[0] == 0xFF and bytes[1] == 0xD8:
		return _finish(_try(bytes, "load_jpg_from_buffer"))
	if bytes.size() > 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return _finish(_try(bytes, "load_webp_from_buffer"))
	if bytes[0] == 0x42 and bytes[1] == 0x4D:
		return _finish(_try(bytes, "load_bmp_from_buffer"))
	if IcoFile.is_ico(bytes):
		return IcoFile.best_image(bytes)
	if IcnsFile.is_icns(bytes):
		return IcnsFile.best_image(bytes)
	if _looks_like_svg(bytes):
		return load_svg(bytes, svg_size)
	# Last resort for TGA and anything else Godot can sniff.
	return _finish(_try(bytes, "load_tga_from_buffer"))


static func _try(bytes: PackedByteArray, method: String) -> Image:
	var img := Image.new()
	if img.call(method, bytes) != OK:
		return null
	return img


static func _finish(img: Image) -> Image:
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _looks_like_svg(bytes: PackedByteArray) -> bool:
	var head := bytes.slice(0, mini(bytes.size(), 1024)).get_string_from_utf8()
	return head.contains("<svg") or (head.begins_with("<?xml") and head.contains("svg"))


## Rasterizes an SVG so that its larger side is `target` pixels.
static func load_svg(bytes: PackedByteArray, target: int = ICON_SIZE) -> Image:
	var probe := Image.new()
	if probe.load_svg_from_buffer(bytes, 1.0) != OK or probe.is_empty():
		return null
	var longest := maxi(probe.get_width(), probe.get_height())
	if longest <= 0:
		return null
	var img := Image.new()
	if img.load_svg_from_buffer(bytes, float(target) / float(longest)) != OK or img.is_empty():
		return probe
	img.convert(Image.FORMAT_RGBA8)
	return img


static func load_file(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_IMAGE_BYTES:
		return null
	return load_any(f.get_buffer(f.get_length()))
