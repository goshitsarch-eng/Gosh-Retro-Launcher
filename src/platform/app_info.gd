class_name AppInfoReader
extends RefCounted
## Port of src/main/ipc/appInfoHandlers.ts: derives {name, path, icon?, win31Icon?, workingDir?,
## arguments?} for a file the user dropped or browsed. Godot cannot ask the OS for a file's icon
## (Electron's app.getFileIcon), so icons are extracted here: PE resources, .ico, .icns, .app
## bundles, freedesktop themes for .desktop files, and plain images. Never raises; when nothing
## can be extracted the icon keys are simply absent.

const IMAGE_EXTENSIONS := [".png", ".jpg", ".jpeg", ".gif", ".ico", ".icns", ".webp", ".bmp", ".svg", ".tga"]


## Node's path.extname: "" for no dot or a leading-dot-only name (".bashrc"), else ".ext".
static func extname(path: String) -> String:
	var file := path.get_file()
	var i := file.rfind(".")
	if i <= 0:
		return ""
	return file.substr(i)


## Node's path.basename(path, ext) (suffix removed case-sensitively like Node when `ext` is given).
static func basename(path: String, ext: String = "") -> String:
	var file := path.get_file()
	if ext != "" and file.length() > ext.length() and file.ends_with(ext):
		return file.substr(0, file.length() - ext.length())
	return file


## Case-insensitive variant used for the extension we matched ourselves (".LNK", ".Desktop").
static func _basename_ci(path: String, ext: String) -> String:
	var file := path.get_file()
	if ext != "" and file.length() > ext.length() and file.to_lower().ends_with(ext.to_lower()):
		return file.substr(0, file.length() - ext.length())
	return file


## Node's path.dirname for both separators ("C:\\x.exe" -> "C:\\", "/x" -> "/", "x" -> ".").
static func dirname(path: String) -> String:
	var sep := maxi(path.rfind("/"), path.rfind("\\"))
	if sep < 0:
		return "."
	if sep == 0:
		return path.substr(0, 1)
	var dir := path.substr(0, sep)
	if dir.length() == 2 and dir[1] == ":":
		return dir + path[sep]
	return dir


static func is_absolute(path: String) -> bool:
	if path.begins_with("/") or path.begins_with("\\\\"):
		return true
	return path.length() >= 3 and path[1] == ":" and (path[2] == "\\" or path[2] == "/")


## `os_name` is "win32" | "darwin" | "linux" ("" = this machine); injectable for tests.
static func get_app_info(file_path: String, os_name: String = "") -> Dictionary:
	var os := os_name if os_name != "" else Launcher.platform()
	var ext := extname(file_path).to_lower()
	if os == "win32":
		return _windows_info(file_path, ext)
	if os == "linux" and ext == ".desktop":
		return _desktop_info(file_path)
	var info := {"name": basename(file_path, extname(file_path)), "path": file_path}
	info.merge(load_best_icon(file_path, os))
	if ext != "":
		info["workingDir"] = dirname(file_path)
	return info


static func _windows_info(file_path: String, ext: String) -> Dictionary:
	if ext == ".lnk":
		var details := LnkFile.read(file_path)
		if not details.is_empty():
			var target := String(details.get("target", ""))
			if target == "":
				target = file_path
			var info := {"name": _basename_ci(file_path, ".lnk"), "path": target}
			var icons := load_best_icon(target, "win32")
			if icons.is_empty() and String(details.get("icon", "")) != "":
				icons = load_best_icon(String(details.icon), "win32")
			info.merge(icons)
			var cwd := String(details.get("cwd", ""))
			info["workingDir"] = cwd if cwd != "" else dirname(target)
			if String(details.get("args", "")) != "":
				info["arguments"] = details.args
			return info
	var out := {"name": basename(file_path, extname(file_path)), "path": file_path}
	out.merge(load_best_icon(file_path, "win32"))
	out["workingDir"] = dirname(file_path)
	return out


static func _desktop_info(file_path: String) -> Dictionary:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {"name": _basename_ci(file_path, ".desktop"), "path": file_path}
	var parsed := DesktopEntry.to_app_info(f.get_as_text(), file_path)
	var icon_name := String(parsed.get("icon_name", ""))
	parsed.erase("icon_name")
	var img: Image = null
	if icon_name != "":
		var icon_path := icon_name if is_absolute(icon_name) else IconTheme.find_icon(icon_name)
		if icon_path != "":
			img = _image_for_path(icon_path)
	parsed.merge(IconImage.icons_from_image(img))
	return parsed


## {icon, win31Icon} (PNG data URLs) or {} (loadBestIcon).
static func load_best_icon(path: String, os_name: String = "") -> Dictionary:
	return IconImage.icons_from_image(best_image(path, os_name))


## Best available source image for any file or bundle, or null.
static func best_image(path: String, os_name: String = "") -> Image:
	var os := os_name if os_name != "" else Launcher.platform()
	if AppBundle.is_bundle_path(path):
		return AppBundle.icon_image(path)
	var img := _image_for_path(path)
	if img != null:
		return img
	if os == "linux" and FileAccess.file_exists(path):
		# Plain Linux executables: use a theme icon named after the program (e.g. /usr/bin/firefox).
		var ext := extname(path)
		if ext == "" or ext.to_lower() == ".sh" or ext.to_lower() == ".appimage":
			var theme_icon := IconTheme.find_icon(basename(path, ext))
			if theme_icon != "":
				return _image_for_path(theme_icon)
	return null


## Image file, ICO/ICNS, or PE resource icon.
static func _image_for_path(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var ext := extname(path).to_lower()
	if IMAGE_EXTENSIONS.has(ext):
		var img := IconImage.load_file(path)
		if img != null:
			return img
	return _pe_if_mz(path)


static func _pe_if_mz(path: String) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 0x40:
		return null
	var head := f.get_buffer(2)
	f.close()
	if head.size() == 2 and head[0] == 0x4D and head[1] == 0x5A:
		return PeIcon.load_image(path)
	return null
