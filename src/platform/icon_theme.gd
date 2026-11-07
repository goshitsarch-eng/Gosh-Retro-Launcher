class_name IconTheme
extends RefCounted
## freedesktop.org icon lookup for `.desktop` `Icon=` names (a pragmatic subset of the Icon Theme
## spec): searches the XDG icon directories for <theme>/<size>/<category>/<name>.{svg,png} (and the
## KDE <theme>/<category>/<size>/ layout) plus the flat /usr/share/pixmaps. The first SVG found
## wins (it rasterizes crisply at 128 px); otherwise the smallest PNG >= 128 px, then the largest
## smaller PNG. XPM is not supported.

const THEME_FALLBACKS := ["hicolor", "Adwaita", "breeze", "Papirus", "gnome", "oxygen", "elementary", "Yaru"]
const CATEGORIES := ["apps", "applications", "mimetypes", "places", "categories", "devices", "actions"]
const WANTED_SIZE := 128
const SCALABLE := 100000


## Icon search roots in priority order (existing or not; callers filter).
static func default_roots() -> Array:
	var roots := []
	var home := OS.get_environment("HOME")
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home == "" and home != "":
		data_home = home.path_join(".local/share")
	if data_home != "":
		roots.append(data_home.path_join("icons"))
	if home != "":
		roots.append(home.path_join(".icons"))
	var dirs := OS.get_environment("XDG_DATA_DIRS")
	if dirs == "":
		dirs = "/usr/local/share:/usr/share"
	for d in dirs.split(":", false):
		roots.append(String(d).path_join("icons"))
	roots.append("/usr/share/pixmaps")
	if home != "":
		roots.append(home.path_join(".local/share/flatpak/exports/share/icons"))
	roots.append("/var/lib/flatpak/exports/share/icons")
	return roots


## The user's configured GTK icon theme (best effort), or "".
static func configured_theme() -> String:
	var cfg := OS.get_environment("XDG_CONFIG_HOME")
	if cfg == "" and OS.get_environment("HOME") != "":
		cfg = OS.get_environment("HOME").path_join(".config")
	if cfg == "":
		return ""
	for rel in ["gtk-3.0/settings.ini", "gtk-4.0/settings.ini"]:
		var p := cfg.path_join(rel)
		if not FileAccess.file_exists(p):
			continue
		for line in FileAccess.get_file_as_string(p).split("\n"):
			var l := String(line).strip_edges()
			if l.begins_with("gtk-icon-theme-name"):
				var eq := l.find("=")
				if eq > 0:
					return l.substr(eq + 1).strip_edges().trim_prefix('"').trim_suffix('"')
	return ""


## "48x48", "48", "48@2x" -> 48; "scalable" -> SCALABLE; anything else -> 0.
static func dir_size(dir_name: String) -> int:
	if dir_name == "scalable":
		return SCALABLE
	var base := dir_name.split("@")[0]
	if base.contains("x"):
		base = base.split("x")[0]
	return int(base) if base.is_valid_int() else 0


## Candidates for `stem` below one theme directory: [{path, size, svg}].
static func scan_theme(theme_dir: String, stem: String) -> Array:
	var out := []
	for sd in DirAccess.get_directories_at(theme_dir):
		var size := dir_size(sd)
		if size > 0:  # <theme>/<size>/<category>/
			for cat in CATEGORIES:
				_check(out, theme_dir.path_join(sd).path_join(cat), stem, size)
		elif CATEGORIES.has(sd):  # <theme>/<category>/<size>/
			var cat_dir := theme_dir.path_join(sd)
			for sz_dir in DirAccess.get_directories_at(cat_dir):
				var sz := dir_size(sz_dir)
				if sz > 0:
					_check(out, cat_dir.path_join(sz_dir), stem, sz)
	return out


static func _check(out: Array, dir: String, stem: String, size: int) -> void:
	var svg := dir.path_join(stem + ".svg")
	if FileAccess.file_exists(svg):
		out.append({"path": svg, "size": size, "svg": true})
	var png := dir.path_join(stem + ".png")
	if FileAccess.file_exists(png):
		out.append({"path": png, "size": size, "svg": false})


## Picks the winner among candidates (see class comment).
static func choose(candidates: Array) -> String:
	for c in candidates:
		if c.svg:
			return c.path
	var big := ""
	var big_size := 0x7fffffff
	var small := ""
	var small_size := -1
	for c in candidates:
		var size: int = c.size
		if size >= WANTED_SIZE:
			if size < big_size:
				big = c.path
				big_size = size
		elif size > small_size:
			small = c.path
			small_size = size
	return big if big != "" else small


## Returns the best image path for `icon_name` or "". `roots` / `themes` are injectable for tests.
static func find_icon(icon_name: String, roots: Array = [], themes: Array = []) -> String:
	if icon_name == "" or icon_name.contains("/") or icon_name.contains(".."):
		return ""
	if roots.is_empty():
		roots = default_roots()
	var theme_list := themes.duplicate()
	if theme_list.is_empty():
		var configured := configured_theme()
		if configured != "":
			theme_list.append(configured)
		theme_list.append_array(THEME_FALLBACKS)
	var stem := icon_name
	for ext in [".png", ".svg", ".svgz", ".xpm"]:
		if stem.ends_with(ext):
			stem = stem.trim_suffix(ext)
			break
	var candidates := []
	for root in roots:
		if not DirAccess.dir_exists_absolute(root):
			continue
		_check_flat(candidates, root, stem)
		for t in theme_list:
			var td := String(root).path_join(t)
			if DirAccess.dir_exists_absolute(td):
				candidates.append_array(scan_theme(td, stem))
	return choose(candidates)


## Flat pixmap-style directory: size unknown, so PNGs rank as small.
static func _check_flat(out: Array, dir: String, stem: String) -> void:
	var svg := dir.path_join(stem + ".svg")
	if FileAccess.file_exists(svg):
		out.append({"path": svg, "size": 0, "svg": true})
	var png := dir.path_join(stem + ".png")
	if FileAccess.file_exists(png):
		out.append({"path": png, "size": 0, "svg": false})
