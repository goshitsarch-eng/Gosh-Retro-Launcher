class_name Win31Drop
extends RefCounted
## Pure helpers for OS file drops onto a group window (ItemGrid.tsx handleDrop semantics).


## ProgramItem payload (without id) for ProgramStore.add_item from Platform.get_app_info(). Falls
## back to the file name without extension when the info carries no name/path.
static func item_from_app_info(path: String, info: Dictionary) -> Dictionary:
	var name := String(info.get("name", ""))
	if name == "":
		name = path.get_file().get_basename()
	var icon := String(info.get("icon", ""))
	var item := {
		"name": name,
		"path": String(info.get("path", "")) if String(info.get("path", "")) != "" else path,
		"icon": icon if icon != "" else "default",
		"workingDir": String(info.get("workingDir", "")),
		"launchGroup": 0,
	}
	var w := String(info.get("win31Icon", ""))
	if w != "":
		item["win31Icon"] = w
	var args := String(info.get("arguments", ""))
	if args != "":
		item["arguments"] = args
	return item
