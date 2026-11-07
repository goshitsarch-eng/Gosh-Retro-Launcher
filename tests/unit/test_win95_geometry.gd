extends TestCase
## Port of win95/__tests__/geometry.test.ts (+ keyboard-sizing edge case from primitives.test.ts).

const AREA := {"width": 640, "height": 452}
const RECT := {"x": 40, "y": 30, "width": 300, "height": 200}


func test_constrains_restored_windows_to_the_logical_desktop() -> void:
	expect_eq(Win95Geometry.constrain_rect({"x": 600, "y": 440, "width": 300, "height": 200}, AREA),
		{"x": 340, "y": 252, "width": 300, "height": 200})


func test_uses_logical_deltas_independent_of_renderer_scale() -> void:
	var moved: Dictionary = RECT.duplicate()
	moved.x = 65
	moved.y = 45
	expect_eq(Win95Geometry.drag_rect(RECT, 25, 15, AREA), moved)
	var sized: Dictionary = RECT.duplicate()
	sized.width = 340
	sized.height = 220
	expect_eq(Win95Geometry.resize_rect(RECT, "se", 40, 20, AREA), sized)


func test_keeps_all_eight_edge_resize_paths_within_the_work_area() -> void:
	expect_eq(Win95Geometry.resize_rect(RECT, "nw", -100, -100, AREA), {"x": 0, "y": 0, "width": 340, "height": 230})
	expect_eq(Win95Geometry.resize_rect(RECT, "e", 1000, 0, AREA).width, 600)
	for edge in ["n", "s", "e", "w", "ne", "nw", "se", "sw"]:
		for d in [[-500, -500], [500, 500], [-50, 70], [0, 0]]:
			var r := Win95Geometry.resize_rect(RECT, edge, d[0], d[1], AREA)
			expect(r.x >= 0 and r.y >= 0, "%s origin in area" % edge)
			expect(r.x + r.width <= 640 and r.y + r.height <= 452, "%s extent in area" % edge)
			expect(r.width >= 160 and r.height >= 100, "%s minimum size" % edge)


func test_minimum_size_pushes_the_opposite_origin() -> void:
	var r := Win95Geometry.resize_rect(RECT, "nw", 400, 400, AREA)
	expect_eq(r.width, 160)
	expect_eq(r.height, 100)
	expect_eq(r.x, 180)
	expect_eq(r.y, 130)


func test_chooses_every_keyboard_sizing_edge_deterministically() -> void:
	expect_eq(Win95Geometry.keyboard_resize_edge("", "ArrowLeft"), "w")
	expect_eq(Win95Geometry.keyboard_resize_edge("w", "ArrowUp"), "nw")
	expect_eq(Win95Geometry.keyboard_resize_edge("", "ArrowRight"), "e")
	expect_eq(Win95Geometry.keyboard_resize_edge("e", "ArrowDown"), "se")
	expect_eq(Win95Geometry.keyboard_resize_edge("ne", "ArrowLeft"), "nw")
	expect_eq(Win95Geometry.keyboard_resize_edge("", "ArrowUp"), "n")


func test_drag_never_leaves_the_desktop() -> void:
	var r := Win95Geometry.drag_rect(RECT, -1000, 1000, AREA)
	expect_eq(r.x, 0)
	expect_eq(r.y, 252)
