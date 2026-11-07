extends TestCase
## Port of the dialog-key part of win95/__tests__/primitives.test.ts.


func test_routes_default_and_cancel_keys() -> void:
	expect_eq(Win95DialogState.resolve_key({"key": "Escape"}, true), "cancel")
	expect_eq(Win95DialogState.resolve_key({"key": "F4", "altKey": true}, true), "cancel")
	expect_eq(Win95DialogState.resolve_key({"key": "Enter"}, true), "default")
	expect_eq(Win95DialogState.resolve_key({"key": "Tab", "shiftKey": true}, true), "reverse-focus")
	expect_eq(Win95DialogState.resolve_key({"key": "Tab"}, true), "advance-focus")


func test_enter_is_not_default_when_a_button_or_multiline_has_focus() -> void:
	expect_eq(Win95DialogState.resolve_key({"key": "Enter"}, true, true), "none")
	expect_eq(Win95DialogState.resolve_key({"key": "Enter"}, true, false, true), "none")
	expect_eq(Win95DialogState.resolve_key({"key": "Enter"}, false), "none")


func test_selects_least_destructive_defaults() -> void:
	expect_eq(Win95DialogState.least_destructive_default(["yes", "no"]), "no")
	expect_eq(Win95DialogState.least_destructive_default(["ok", "cancel", "apply"]), "cancel")
	expect_eq(Win95DialogState.least_destructive_default(["Save", "Close"]), "Close")
	expect_eq(Win95DialogState.least_destructive_default(["a", "b"]), "a")
	expect_eq(Win95DialogState.least_destructive_default([]), "")
