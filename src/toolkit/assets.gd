class_name Assets
extends RefCounted
## Texture cache for bundled and user-supplied images. All textures are nearest-filtered by
## the project default; external files are loaded as ImageTexture.

static var _cache := {}

## Custom icons are 128x128 (or 32x32) PNGs; anything above this is not an icon.
const MAX_DATA_URL_PIXELS := 4096 * 4096


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			t = load(path)
		else:
			t = _from_image_file(path)
	else:
		t = _from_image_file(path)
	_cache[path] = t
	return t


static func _from_image_file(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null  # optional files (local icon packs, stale user paths) are expected to be absent
	if not path.begins_with("res://"):
		# User-referenced file (stored icon path): check its declared size before decoding it.
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null or f.get_length() > IconImage.MAX_IMAGE_BYTES \
				or not IconImage.size_ok(f.get_buffer(mini(f.get_length(), 64 * 1024)), IconImage.MAX_IMAGE_PIXELS):
			return null
		f.close()
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


## Decodes a "data:image/...;base64,..." URL (custom icons stored in the data file).
static func from_data_url(url: String) -> Texture2D:
	if _cache.has(url):
		return _cache[url]
	var t: Texture2D = null
	var comma := url.find(",")
	if url.begins_with("data:") and comma > 0:
		var header := url.substr(5, comma - 5)
		var payload := url.substr(comma + 1)
		var bytes: PackedByteArray
		if header.contains(";base64"):
			bytes = Marshalls.base64_to_raw(payload)
		else:
			bytes = payload.uri_decode().to_utf8_buffer()
		var img := Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		# Data URLs come from the store (and therefore from imported files) and are decoded on
		# every start: a few bytes declaring a huge canvas must not allocate it.
		if not IconImage.size_ok(bytes, MAX_DATA_URL_PIXELS) \
				or (header.begins_with("image/svg") and not IconImage.svg_size_ok(bytes, MAX_DATA_URL_PIXELS)):
			_cache[url] = null
			return null
		if header.begins_with("image/png"):
			err = img.load_png_from_buffer(bytes)
		elif header.begins_with("image/jpeg"):
			err = img.load_jpg_from_buffer(bytes)
		elif header.begins_with("image/webp"):
			err = img.load_webp_from_buffer(bytes)
		elif header.begins_with("image/svg"):
			err = img.load_svg_from_buffer(bytes)
		elif header.begins_with("image/bmp"):
			err = img.load_bmp_from_buffer(bytes)
		if err != OK:
			for loader in ["load_png_from_buffer", "load_jpg_from_buffer", "load_webp_from_buffer"]:
				if img.call(loader, bytes) == OK:
					err = OK
					break
		if err == OK and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_cache[url] = t
	return t


static func clear_external() -> void:
	for k in _cache.keys():
		if not String(k).begins_with("res://"):
			_cache.erase(k)
