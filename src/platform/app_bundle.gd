class_name AppBundle
extends RefCounted
## macOS .app bundle icon lookup: Contents/Info.plist -> CFBundleIconFile -> Contents/Resources/<file>.icns.


static func is_bundle_path(path: String) -> bool:
	return path.to_lower().trim_suffix("/").ends_with(".app")


## Absolute path of the bundle's icns file or "".
static func icon_path(app_dir: String) -> String:
	var dir := app_dir.trim_suffix("/")
	var resources := dir.path_join("Contents/Resources")
	var plist := PlistReader.parse_file(dir.path_join("Contents/Info.plist"))
	var names := []
	for key in ["CFBundleIconFile", "CFBundleIconName"]:
		var v: Variant = plist.get(key)
		if v is String and String(v) != "":
			names.append(String(v))
	for n in names:
		var file := String(n)
		var candidates := [file] if file.get_extension() != "" else [file + ".icns", file]
		for c in candidates:
			var p := resources.path_join(c)
			if FileAccess.file_exists(p):
				return p
	# Fall back to the first .icns in Resources (stable alphabetical order).
	var found := []
	for f in DirAccess.get_files_at(resources):
		if f.to_lower().ends_with(".icns"):
			found.append(f)
	found.sort()
	if not found.is_empty():
		return resources.path_join(found[0])
	return ""


static func icon_image(app_dir: String) -> Image:
	var p := icon_path(app_dir)
	if p == "":
		return null
	return IconImage.load_file(p)
