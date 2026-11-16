extends TestCase
## Px.checker / Win95Draw.dither_checker draw their 50% patterns as one tiled 2x2 mask instead of one
## draw_rect per pixel. The mask must match the per-pixel loop exactly. Headless runs check the
## masks and the whole-pixel-grid rule; a windowed run (`godot --path . --script tests/run_tests.gd --
## test_px_checker`) also renders both forms at 1x-4x and compares the pixels.

const RECTS := [Rect2(1, 1, 15, 300), Rect2(20, 3, 16, 17), Rect2(40.5, 7.25, 13.6, 30.7), Rect2(60, 2, 1, 1),
	Rect2(70, 9, 33, 2), Rect2(110, -3, 9, 12), Rect2(125, 0, 0, 5), Rect2(130, 4, 5, -2)]
const ORIGINS := [Vector2(0, 0), Vector2(2, 2), Vector2(3, 0), Vector2(-1, 5), Vector2(0.5, 1)]


func test_masks_are_complementary_checkers() -> void:
	var masks := Px.checker_masks()
	expect_eq(masks.size(), 2)
	expect(Px.checker_masks()[0] == masks[0], "built once")
	var even: Image = masks[0].get_image()
	var odd: Image = masks[1].get_image()
	for j in 2:
		for i in 2:
			expect_eq(even.get_pixel(i, j).a > 0.0, (i + j) % 2 == 0, "mask 0 at %d,%d" % [i, j])
			expect_eq(odd.get_pixel(i, j).a > 0.0, (i + j) % 2 == 1, "mask 1 at %d,%d" % [i, j])


func test_windowed_render_matches_the_per_pixel_loops() -> void:
	if DisplayServer.get_name() == "headless":
		return  # no pixels to read back; the windowed run covers this
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var saved_scale := root.content_scale_factor
	var saved_size := root.size
	var c := Control.new()
	var state := {"fast": true, "case": 0}
	c.draw.connect(func():
		var case_i: int = state.case
		for r in RECTS:
			Px.fill_rect(c, r, Color.WHITE)
			if case_i < 2:
				if state.fast:
					Px.checker(c, r, Color(0.5, 0.5, 0.5), Color.WHITE, case_i)
				else:
					Px.checker_loop(c, r, Color(0.5, 0.5, 0.5), case_i)
			elif state.fast:
				Win95Draw.dither_checker(c, r, ORIGINS[case_i - 2], Color(0, 0, 0.5))
			else:
				Win95Draw.dither_checker_loop(c, r, ORIGINS[case_i - 2], Color(0, 0, 0.5)))
	root.add_child(c)
	for k in [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0]:  # whole scales and the fractional ones 125%-250% displays give
		root.content_scale_factor = k
		root.size = Vector2i(ceili(160 * k), ceili(320 * k))
		for offset in [Vector2.ZERO, Vector2(0.5, 0.5), Vector2(0.25, 0.75)]:
			for case_i in 2 + ORIGINS.size():
				state.case = case_i
				c.position = offset
				var shots := {}
				for fast in [false, true]:
					state.fast = fast
					c.queue_redraw()
					await tree.process_frame
					await tree.process_frame
					RenderingServer.force_draw()
					shots[fast] = root.get_texture().get_image().get_data()
				expect(shots[true] == shots[false], "tiled mask == per-pixel loop, case %d at %sx, offset %s" % [case_i, k, offset])
	c.queue_free()
	root.content_scale_factor = saved_scale
	root.size = saved_size
	await tree.process_frame


func test_fractional_or_detached_canvas_items_use_the_loops() -> void:
	var detached := Control.new()
	expect(not Px.whole_pixel_grid(detached), "not in a tree: no transform to trust")
	detached.free()
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var saved := root.content_scale_factor
	var c := Control.new()
	root.add_child(c)
	for k in [1.0, 2.0, 3.0]:
		root.content_scale_factor = k
		c.position = Vector2(3, 5)
		expect(Px.whole_pixel_grid(c), "%sx whole-pixel offset" % k)
	for k in [1.25, 1.5, 2.5]:
		root.content_scale_factor = k
		expect(not Px.whole_pixel_grid(c), "%sx falls back to the per-pixel loop" % k)
	root.content_scale_factor = 2.0
	c.position = Vector2(3.25, 5)
	expect(not Px.whole_pixel_grid(c), "a quarter-pixel offset at 2x is not on the device grid")
	c.position = Vector2(3.5, 5)
	expect(Px.whole_pixel_grid(c), "half a logical pixel at 2x is one device pixel")
	c.position = Vector2.ZERO
	c.rotation = 0.3
	expect(not Px.whole_pixel_grid(c), "rotated")
	c.free()
	root.content_scale_factor = saved
