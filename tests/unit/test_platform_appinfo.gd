extends TestCase
## App info rules (appInfoHandlers.ts), .desktop / .lnk parsing, filter tables, freedesktop icon lookup.

func test_node_path_helpers() -> void:
	expect_eq(AppInfoReader.extname("/a/b/Doom.EXE"), ".EXE")
	expect_eq(AppInfoReader.extname("/a/.bashrc"), "")
	expect_eq(AppInfoReader.extname("/a/noext"), "")
	expect_eq(AppInfoReader.basename("C:\\Games\\Doom.exe", ".exe"), "Doom")
	expect_eq(AppInfoReader.basename("/a/b/tool", ""), "tool")
	expect_eq(AppInfoReader.basename("/a/b/Doom.EXE", ".exe"), "Doom.EXE", "Node basename is case-sensitive")
	expect_eq(AppInfoReader.dirname("C:\\Games\\Doom.exe"), "C:\\Games")
	expect_eq(AppInfoReader.dirname("C:\\doom.exe"), "C:\\")
	expect_eq(AppInfoReader.dirname("/x"), "/")
	expect_eq(AppInfoReader.dirname("/a/b/c"), "/a/b")
	expect_eq(AppInfoReader.dirname("file"), ".")
	expect(AppInfoReader.is_absolute("/usr/x.png"))
	expect(AppInfoReader.is_absolute("C:\\x.png"))
	expect(not AppInfoReader.is_absolute("icon-name"))


func test_desktop_entry_exec_rules() -> void:
	var t := "[Desktop Entry]\nName=Firefox\nName[de]=Feuerfuchs\nExec=/usr/bin/firefox %u --new-window\nIcon=firefox\n[Desktop Action x]\nName=Other\nExec=ignored\n"
	var i := DesktopEntry.to_app_info(t, "/usr/share/applications/firefox.desktop")
	expect_eq(i.name, "Firefox")
	expect_eq(i.path, "/usr/bin/firefox")
	expect_eq(i.arguments, "--new-window")
	expect_eq(i.icon_name, "firefox")
	expect(not i.has("workingDir"))
	var q := DesktopEntry.to_app_info('[Desktop Entry]\nExec="/opt/My App/run" --flag %U\n', "/x/my.desktop")
	expect_eq(q.path, "/opt/My App/run")
	expect_eq(q.arguments, "--flag")
	expect_eq(q.name, "my", "name falls back to the file stem")
	var e := DesktopEntry.to_app_info("[Desktop Entry]\nExec=env FOO=1 prog -x\nPath=/work\n", "/x/e.desktop")
	expect_eq(e.path, "env")
	expect_eq(e.arguments, "FOO=1 prog -x")
	expect_eq(e.workingDir, "/work")
	var none := DesktopEntry.to_app_info("[Desktop Entry]\nName=NoExec\n", "/x/n.desktop")
	expect_eq(none.path, "/x/n.desktop", "no Exec: path is the .desktop file")
	var cr := DesktopEntry.to_app_info("[Desktop Entry]\r\nName=Crlf\r\nExec=run %f\r\n", "/x/c.desktop")
	expect_eq(cr.name, "Crlf")
	expect_eq(cr.path, "run")
	expect(not cr.has("arguments"))
	var ignore_before := DesktopEntry.to_app_info("Exec=wrong\n[Desktop Entry]\nExec=right\n", "/x/z.desktop")
	expect_eq(ignore_before.path, "right")


func test_get_app_info_desktop_with_absolute_icon() -> void:
	var dir := PlatformFixtures.tmp_dir()
	PlatformFixtures.quad(48).save_png(dir.path_join("pic.png"))
	var f := PlatformFixtures.write_text(dir.path_join("demo.desktop"), "[Desktop Entry]\nName=Demo\nExec=/usr/bin/demo --x\nIcon=%s\n" % dir.path_join("pic.png"))
	var info := AppInfoReader.get_app_info(f, "linux")
	expect_eq(info.name, "Demo")
	expect_eq(info.path, "/usr/bin/demo")
	expect_eq(info.arguments, "--x")
	expect(String(info.get("icon", "")).begins_with("data:image/png;base64,"))
	expect(String(info.get("win31Icon", "")).begins_with("data:image/png;base64,"))
	expect(not info.has("icon_name"))
	PlatformFixtures.rm_rf(dir)


func test_get_app_info_desktop_theme_icon_and_missing_file() -> void:
	var dir := PlatformFixtures.tmp_dir()
	var old := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", dir.path_join("data"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("data/icons/hicolor/64x64/apps"))
	PlatformFixtures.quad(64).save_png(dir.path_join("data/icons/hicolor/64x64/apps/pmtest.png"))
	var f := PlatformFixtures.write_text(dir.path_join("t.desktop"), "[Desktop Entry]\nName=T\nExec=t\nIcon=pmtest\n")
	var info := AppInfoReader.get_app_info(f, "linux")
	expect(info.has("icon"), "icon found via XDG_DATA_HOME theme lookup")
	OS.set_environment("XDG_DATA_HOME", old)
	var miss := AppInfoReader.get_app_info(dir.path_join("nope.desktop"), "linux")
	expect_eq(miss, {"name": "nope", "path": dir.path_join("nope.desktop")})
	PlatformFixtures.rm_rf(dir)


func test_get_app_info_plain_files_linux_mac() -> void:
	var dir := PlatformFixtures.tmp_dir()
	PlatformFixtures.quad(32).save_png(dir.path_join("photo.png"))
	var info := AppInfoReader.get_app_info(dir.path_join("photo.png"), "linux")
	expect_eq(info.name, "photo")
	expect_eq(info.path, dir.path_join("photo.png"))
	expect_eq(info.workingDir, dir)
	expect(info.has("icon") and info.has("win31Icon"))
	var script := PlatformFixtures.write_text(dir.path_join("run-me"), "#!/bin/sh\n")
	var s := AppInfoReader.get_app_info(script, "linux")
	expect_eq(s.name, "run-me")
	expect(not s.has("workingDir"), "no extension: no working dir (TS: undefined)")
	expect(not s.has("icon"))
	var sh := PlatformFixtures.write_text(dir.path_join("tool.sh"), "#!/bin/sh\n")
	var h := AppInfoReader.get_app_info(sh, "darwin")
	expect_eq(h.name, "tool")
	expect_eq(h.workingDir, dir)
	PlatformFixtures.rm_rf(dir)


func test_get_app_info_pe_and_ico_and_bundle() -> void:
	var dir := PlatformFixtures.tmp_dir()
	var pe := PlatformFixtures.build_pe([[{"image": PlatformFixtures.quad(32), "bpp": 32}]])
	var exe := PlatformFixtures.write_bytes(dir.path_join("Setup.exe"), pe)
	var info := AppInfoReader.get_app_info(exe, "win32")
	expect_eq(info.name, "Setup")
	expect_eq(info.path, exe)
	expect_eq(info.workingDir, dir)
	expect(info.has("icon"), "icon from PE resources")
	var win31 := Assets.from_data_url(info.win31Icon).get_image()
	expect_eq(win31.get_size(), Vector2i(32, 32))
	# The same exe on Linux (Wine users) still yields an icon.
	expect(AppInfoReader.get_app_info(exe, "linux").has("icon"))
	var ico := PlatformFixtures.write_bytes(dir.path_join("x.ico"), PlatformFixtures.build_ico([{"image": PlatformFixtures.quad(32), "bpp": 8}]))
	expect(AppInfoReader.get_app_info(ico, "darwin").has("icon"))
	var app := dir.path_join("Cool.app")
	PlatformFixtures.write_text(app.path_join("Contents/Info.plist"), "<plist><dict><key>CFBundleIconFile</key><string>i</string></dict></plist>")
	PlatformFixtures.write_bytes(app.path_join("Contents/Resources/i.icns"), PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic07", PlatformFixtures.quad(128).save_png_to_buffer())]))
	var a := AppInfoReader.get_app_info(app, "darwin")
	expect_eq(a.name, "Cool")
	expect_eq(a.workingDir, dir)
	expect(a.has("icon"), "icon from .app bundle")
	# Garbage with an exe name: info without icons, never a crash.
	var bad := PlatformFixtures.write_bytes(dir.path_join("bad.exe"), PackedByteArray([1, 2, 3, 4]))
	var b := AppInfoReader.get_app_info(bad, "win32")
	expect_eq(b.name, "bad")
	expect(not b.has("icon"))
	PlatformFixtures.rm_rf(dir)


func test_windows_lnk_rules() -> void:
	var dir := PlatformFixtures.tmp_dir()
	# target = a real icon-bearing file so the icon comes from the target
	var target := PlatformFixtures.write_bytes(dir.path_join("game.exe"), PlatformFixtures.build_pe([[{"image": PlatformFixtures.quad(32), "bpp": 32}]]))
	var lnk := PlatformFixtures.write_bytes(dir.path_join("Play Game.lnk"), PlatformFixtures.build_lnk(target, "C:\\Work", "-fast \"a b\""))
	var info := AppInfoReader.get_app_info(lnk, "win32")
	expect_eq(info.name, "Play Game")
	expect_eq(info.path, target)
	expect_eq(info.workingDir, "C:\\Work")
	expect_eq(info.arguments, "-fast \"a b\"")
	expect(info.has("icon"))
	# No cwd/args: workingDir = dirname(target), no arguments key
	var lnk2 := PlatformFixtures.write_bytes(dir.path_join("Plain.LNK"), PlatformFixtures.build_lnk("C:\\Games\\Doom\\doom.exe"))
	var i2 := AppInfoReader.get_app_info(lnk2, "win32")
	expect_eq(i2.name, "Plain")
	expect_eq(i2.path, "C:\\Games\\Doom\\doom.exe")
	expect_eq(i2.workingDir, "C:\\Games\\Doom")
	expect(not i2.has("arguments"))
	expect(not i2.has("icon"))
	# Unreadable shortcut falls back to the file itself.
	var lnk3 := PlatformFixtures.write_bytes(dir.path_join("broken.lnk"), PackedByteArray([1, 2, 3]))
	var i3 := AppInfoReader.get_app_info(lnk3, "win32")
	expect_eq(i3.name, "broken")
	expect_eq(i3.path, lnk3)
	expect_eq(i3.workingDir, dir)
	# Non-lnk on Windows
	var i4 := AppInfoReader.get_app_info("C:\\Tools\\app.exe", "win32")
	expect_eq(i4.name, "app")
	expect_eq(i4.workingDir, "C:\\Tools")
	PlatformFixtures.rm_rf(dir)


func test_filter_tables_match_file_handlers() -> void:
	expect_eq(PlatformFilters.executable_filters("win32"), [
		{"name": "Executables", "extensions": ["exe", "bat", "cmd", "msi"]},
		{"name": "Shortcuts", "extensions": ["lnk"]},
		{"name": "All Files", "extensions": ["*"]}])
	expect_eq(PlatformFilters.executable_filters("darwin"), [
		{"name": "Applications", "extensions": ["app"]},
		{"name": "All Files", "extensions": ["*"]}])
	expect_eq(PlatformFilters.executable_filters("linux"), [
		{"name": "Desktop Entries", "extensions": ["desktop"]},
		{"name": "Shell Scripts", "extensions": ["sh"]},
		{"name": "All Files", "extensions": ["*"]}])
	expect_eq(PlatformFilters.executable_filters("freebsd"), [{"name": "All Files", "extensions": ["*"]}])
	expect_eq(PlatformFilters.image_filters(), [
		{"name": "Images", "extensions": ["png", "jpg", "jpeg", "gif", "ico", "svg"]},
		{"name": "Icons", "extensions": ["ico", "icns"]},
		{"name": "All Files", "extensions": ["*"]}])
	expect_eq(PlatformFilters.grp_open_filters().size(), 2)
	expect_eq(PlatformFilters.grp_save_filters(), [{"name": "Program Manager Groups", "extensions": ["grp"]}])
	expect_eq(PlatformFilters.json_filters(), [{"name": "JSON Files", "extensions": ["json"]}])
	expect_eq(Array(PlatformFilters.to_godot(PlatformFilters.executable_filters("win32"), "win32")), [
		"*.exe, *.bat, *.cmd, *.msi ; Executables", "*.lnk ; Shortcuts", "*.* ; All Files"])
	expect_eq(Array(PlatformFilters.to_godot(PlatformFilters.executable_filters("linux"), "linux")), [
		"*.desktop ; Desktop Entries", "*.sh ; Shell Scripts", "* ; All Files"])
	expect_eq(PlatformFilters.default_extension(PlatformFilters.grp_save_filters()), "grp")
	expect_eq(PlatformFilters.default_extension(PlatformFilters.executable_filters("freebsd")), "")


func test_icon_theme_lookup() -> void:
	var root := PlatformFixtures.tmp_dir()
	PlatformFixtures.write_bytes(root.path_join("hicolor/48x48/apps/foo.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("hicolor/256x256/apps/foo.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("hicolor/128x128/apps/foo.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("hicolor/scalable/apps/bar.svg"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("hicolor/48x48/apps/bar.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("Adwaita/32x32/apps/baz.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("Adwaita/16x16/apps/baz.png"), PackedByteArray([1]))
	PlatformFixtures.write_bytes(root.path_join("breeze/apps/64/qux.svg"), PackedByteArray([1]))
	var roots := [root, "/nonexistent-root"]
	var themes := ["hicolor", "Adwaita", "breeze"]
	expect_eq(IconTheme.find_icon("foo", roots, themes), root.path_join("hicolor/128x128/apps/foo.png"), "smallest PNG >= 128")
	expect_eq(IconTheme.find_icon("bar", roots, themes), root.path_join("hicolor/scalable/apps/bar.svg"), "svg beats png")
	expect_eq(IconTheme.find_icon("baz", roots, themes), root.path_join("Adwaita/32x32/apps/baz.png"), "largest small PNG")
	expect_eq(IconTheme.find_icon("qux", roots, themes), root.path_join("breeze/apps/64/qux.svg"), "KDE layout")
	expect_eq(IconTheme.find_icon("foo.png", roots, themes), root.path_join("hicolor/128x128/apps/foo.png"), "extension stripped")
	expect_eq(IconTheme.find_icon("missing", roots, themes), "")
	expect_eq(IconTheme.find_icon("../etc/passwd", roots, themes), "")
	expect_eq(IconTheme.find_icon("", roots, themes), "")
	expect_eq(IconTheme.dir_size("48x48"), 48)
	expect_eq(IconTheme.dir_size("64"), 64)
	expect_eq(IconTheme.dir_size("48x48@2"), 48)
	expect_eq(IconTheme.dir_size("scalable"), IconTheme.SCALABLE)
	expect_eq(IconTheme.dir_size("apps"), 0)
	# Flat pixmaps directory
	var pix := PlatformFixtures.tmp_dir()
	PlatformFixtures.write_bytes(pix.path_join("old.png"), PackedByteArray([1]))
	expect_eq(IconTheme.find_icon("old", [pix], themes), pix.path_join("old.png"))
	PlatformFixtures.rm_rf(root)
	PlatformFixtures.rm_rf(pix)
