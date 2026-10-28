extends TestCase
## Port of win95/__tests__/menuState.test.ts.


func test_wraps_vertical_selection_and_handles_home_end() -> void:
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [0]}, "ArrowUp", [7]).indices[0], 6)
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [6]}, "ArrowDown", [7]).indices[0], 0)
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [3]}, "Home", [7]).indices[0], 0)
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [3]}, "End", [7]).indices[0], 6)
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [-1]}, "ArrowDown", [7]).indices[0], 0)
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [-1]}, "ArrowUp", [7]).indices[0], 6)


func test_opens_and_closes_nested_levels_without_losing_the_parent_index() -> void:
	var opened := Win95MenuState.reduce_navigation({"level": 0, "indices": [2]}, "ArrowRight", [7, 4], true)
	expect_eq(opened, {"level": 1, "indices": [2, 0], "action": "open-child"})
	var closed := Win95MenuState.reduce_navigation(opened, "Escape", [7, 4])
	expect_eq(closed, {"level": 0, "indices": [2], "action": "close-level"})
	expect_eq(Win95MenuState.reduce_navigation(closed, "Escape", [7, 4]).action, "close-all")


func test_finds_and_displays_ampersand_mnemonics() -> void:
	expect_eq(Win95MenuState.mnemonic_index(["&Programs", "Sh&ut Down..."], "u"), 1)
	expect_eq(Win95MenuState.mnemonic_index(["&Programs", "Sh&ut Down..."], "P"), 0)
	expect_eq(Win95MenuState.mnemonic_index(["&Programs"], "z"), -1)
	expect_eq(Win95MenuState.display_mnemonic("Sh&ut Down..."), {"before": "Sh", "mnemonic": "u", "after": "t Down..."})
	expect_eq(Win95MenuState.display_mnemonic("Plain"), {"before": "Plain", "mnemonic": "", "after": ""})


func test_enter_activates_or_opens_children() -> void:
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [1]}, "Enter", [3]).action, "activate")
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [1]}, "Enter", [3, 2], true).action, "open-child")
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [1]}, "ArrowLeft", [3]).action, "close-all")
	expect_eq(Win95MenuState.reduce_navigation({"level": 0, "indices": [1]}, "ArrowRight", [3]).action, "none")
