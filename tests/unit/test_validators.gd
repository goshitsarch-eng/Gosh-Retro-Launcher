extends TestCase
## Port of src/main/ipc/__tests__/storeHandlers.test.ts + windowHandlers.test.ts

func _item() -> Dictionary:
	return {"id": "123", "name": "Test App", "path": "/usr/bin/test", "icon": "default", "workingDir": "/home/user"}


func _with(d: Dictionary, extra: Dictionary) -> Dictionary:
	var c := d.duplicate(true)
	c.merge(extra, true)
	return c


func _without(d: Dictionary, key: String) -> Dictionary:
	var c := d.duplicate(true)
	c.erase(key)
	return c


func test_item() -> void:
	expect(Validators.is_valid_item(_item()))
	for k in ["id", "name", "path", "icon"]:
		expect(not Validators.is_valid_item(_without(_item(), k)), "missing " + k)
	expect(not Validators.is_valid_item(null))
	expect(not Validators.is_valid_item("string"))
	expect(not Validators.is_valid_item(42))
	expect(Validators.is_valid_item(_with(_item(), {"shortcutKey": "Ctrl+A"})))
	expect(not Validators.is_valid_item(_with(_item(), {"workingDir": 123})))
	expect(Validators.is_valid_item(_with(_item(), {"launchGroup": 2})))
	expect(not Validators.is_valid_item(_with(_item(), {"launchGroup": -1})))
	expect(not Validators.is_valid_item(_with(_item(), {"launchGroup": 1.5})))


func _group() -> Dictionary:
	return {"id": "group-1", "name": "Main", "icon": "folder",
		"windowState": {"x": 0, "y": 0, "width": 300, "height": 200, "minimized": false, "maximized": false},
		"items": [_item()]}


func test_group() -> void:
	expect(Validators.is_valid_group(_group()))
	expect(Validators.is_valid_group(_with(_group(), {"items": []})))
	expect(not Validators.is_valid_group(_with(_group(), {"items": [{"bad": true}]})))
	expect(not Validators.is_valid_group(_without(_group(), "windowState")))
	expect(not Validators.is_valid_group(_with(_group(), {"windowState": null})))
	expect(not Validators.is_valid_group(_without(_group(), "items")))


func _settings() -> Dictionary:
	return {"autoArrange": true, "minimizeOnUse": false, "saveSettingsOnExit": true, "launchDelay": 500,
		"trayOnClose": true, "groupChromeScale": 1, "theme": "light", "labelDisplay": "wrap", "shell": "win31"}


func test_settings() -> void:
	var s := _settings()
	expect(Validators.is_valid_settings(s))
	expect(Validators.is_valid_settings(_with(s, {"theme": "dark"})))
	expect(Validators.is_valid_settings(_with(s, {"labelDisplay": "ellipsis"})))
	expect(not Validators.is_valid_settings(_with(s, {"theme": "blue"})))
	expect(not Validators.is_valid_settings(_with(s, {"labelDisplay": "truncate"})))
	expect(not Validators.is_valid_settings(_with(s, {"launchDelay": -1})))
	expect(not Validators.is_valid_settings(_with(s, {"groupChromeScale": 0})))
	expect(not Validators.is_valid_settings(_with(s, {"autoArrange": "yes"})))
	expect(not Validators.is_valid_settings(null))
	expect(not Validators.is_valid_settings("string"))
	expect(not Validators.is_valid_settings(_without(s, "theme")))
	expect(Validators.is_valid_settings(_with(s, {"shell": "win95", "win95Scale": "auto"})))
	expect(Validators.is_valid_settings(_with(s, {"shell": "win95", "win95Scale": 4})))
	expect(not Validators.is_valid_settings(_with(s, {"win95Scale": 1.5})))
	expect(not Validators.is_valid_settings(_with(s, {"win95Scale": 5})))
	expect(not Validators.is_valid_settings(_with(s, {"shell": "win98"})))
	expect(Validators.is_valid_settings(_without(s, "shell")))
	expect(Validators.is_valid_settings(_with(s, {"soundEnabled": true})))
	expect(Validators.is_valid_settings(_with(s, {"soundEnabled": false})))
	expect(not Validators.is_valid_settings(_with(s, {"soundEnabled": "yes"})))
	expect(Validators.is_valid_settings(_without(s, "soundEnabled")))
	# the app's own defaults must always validate
	expect(Validators.is_valid_settings(Types.default_settings()))


func test_shell_framing() -> void:
	expect(Validators.is_valid_shell_frame_request("win31"))
	expect(Validators.is_valid_shell_frame_request("win95"))
	expect(not Validators.is_valid_shell_frame_request("win98"))
	expect(not Validators.is_valid_shell_frame_request({"shell": "win31"}))
	expect(not Validators.uses_native_window_frame("win31"))
	expect(Validators.uses_native_window_frame("win95"))
