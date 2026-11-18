class_name DataTransfer
extends RefCounted
## Wording and helpers for the global Export All / Import All commands every shell offers. The file
## is the whole launcher (program groups and items, launch groups and their names, settings and
## workspace profiles); ProgramStore.export_to / import_from do the work and Platform.export_all /
## import_data pick the file.

const EXPORT_TITLE := "Export All Programs"
const IMPORT_TITLE := "Import All Programs"
const IMPORT_CONFIRM := "Importing replaces all your program groups, programs, launch groups and settings with the contents of the file.\n\nYour current setup is backed up first, so you can get it back from Backups in Launcher Tools."


## "program-manager-export-2026-11-17.json" for `date` ({year, month, day}, default today).
static func default_export_name(date: Dictionary = {}) -> String:
	var d := date if not date.is_empty() else Time.get_date_dict_from_system()
	return "program-manager-export-%04d-%02d-%02d.json" % [int(d.year), int(d.month), int(d.day)]


## Status line for Platform.export_all()'s result; "" when the user canceled.
static func export_status(result: Dictionary) -> String:
	if result.get("success", false):
		return "Exported everything to %s." % String(result.get("path", "")).get_file()
	if result.get("canceled", false):
		return ""
	var err := String(result.get("error", ""))
	return err if err != "" else "The export file could not be written."


## Status line for Platform.import_data()'s result; "" when the user canceled.
static func import_status(result: Dictionary) -> String:
	if result.get("success", false):
		var details := repair_summary(int(result.get("normalized", 0)), int(result.get("shortcutsCleared", 0)))
		return "Imported everything. Your previous setup was backed up." + (" " + details if details != "" else "")
	var err := String(result.get("error", ""))
	if err == "Canceled":
		return ""
	return err if err != "" else "Import failed."


## "2 stored values were repaired and 1 shortcut key was cleared (...)." or "".
static func repair_summary(normalized: int, shortcuts_cleared: int) -> String:
	var parts := []
	if normalized > 0:
		parts.append("%d stored %s repaired" % [normalized, "value was" if normalized == 1 else "values were"])
	if shortcuts_cleared > 0:
		parts.append("%d shortcut %s cleared (shortcut keys need Ctrl, Alt, Shift or Meta)" % [shortcuts_cleared,
			"key was" if shortcuts_cleared == 1 else "keys were"])
	if parts.is_empty():
		return ""
	return " and ".join(parts) + "."
