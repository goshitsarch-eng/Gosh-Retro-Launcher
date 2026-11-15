extends TestCase
## Pure window state of the Mac shell: z-order, geometry, shade/zoom, fit.

const DESK := Vector2(640, 480)


func _store() -> MacWindowStore:
	return MacWindowStore.new()


func test_open_raises_and_orders() -> void:
	var s := _store()
	s.open("computer", Rect2(10, 30, 300, 200))
	s.open("g:a", Rect2(40, 60, 300, 200))
	expect_eq(s.active_key(), "g:a")
	s.open("computer", Rect2())  # re-open raises, keeps the geometry
	expect_eq(s.active_key(), "computer")
	expect_eq(s.find("computer").rect, Rect2(10, 30, 300, 200))
	expect_eq(s.windows.size(), 2)


func test_close_and_reset() -> void:
	var s := _store()
	s.open("a", Rect2(0, 22, 200, 150))
	s.open("b", Rect2(0, 22, 200, 150))
	s.close("b")
	expect_eq(s.active_key(), "a")
	s.close("nope")
	s.reset()
	expect_eq(s.active_key(), "")
	expect(not s.has("a"))


func test_move_and_resize_limits() -> void:
	var s := _store()
	s.open("a", Rect2(10, 30, 300, 200))
	s.move_to("a", Vector2(50.7, 80.2))
	expect_eq(s.find("a").rect.position, Vector2(50, 80))
	s.resize_to("a", Vector2(10, 10))
	expect_eq(s.find("a").rect.size, Vector2(MacGeometry.MIN_W, MacGeometry.MIN_H))
	s.resize_to("a", Vector2(5000, 5000), Vector2(600, 400))
	expect_eq(s.find("a").rect.size, Vector2(600, 400))


func test_shade_and_zoom_round_trip() -> void:
	var s := _store()
	s.open("a", Rect2(30, 60, 300, 200))
	s.toggle_shade("a")
	expect(s.find("a").shaded)
	s.toggle_zoom("a", DESK)
	expect(s.find("a").zoomed)
	expect(not s.find("a").shaded, "zoom expands a collapsed window")
	expect_eq(s.find("a").rect, MacGeometry.zoom_rect(DESK))
	s.toggle_zoom("a", DESK)
	expect_eq(s.find("a").rect, Rect2(30, 60, 300, 200))
	s.resize_to("a", Vector2(250, 200))
	expect(not s.find("a").zoomed)


func test_view_selection_scroll() -> void:
	var s := _store()
	s.open("a", Rect2(0, 22, 300, 200))
	s.set_view("a", "details")
	expect_eq(s.find("a").view, "details")
	s.set_view("a", "bogus")
	expect_eq(s.find("a").view, "details")
	s.set_selection("a", "x")
	s.set_scroll("a", 40)
	s.set_scroll("a", -5)
	expect_eq(s.find("a").sel, "x")
	expect_eq(s.find("a").scroll, 0)


func test_fit_keeps_title_bars_reachable_and_refits_zoomed() -> void:
	var s := _store()
	s.open("a", Rect2(900, 700, 300, 200))
	s.open("z", Rect2(10, 30, 300, 200))
	s.toggle_zoom("z", DESK)
	s.fit(Vector2(800, 600))
	var r: Rect2 = s.find("a").rect
	expect(r.position.x <= 800 - 32 and r.position.y <= 600 - MacGeometry.TITLE_H, "title bar on screen")
	expect_eq(s.find("z").rect, MacGeometry.zoom_rect(Vector2(800, 600)))


func test_orphans_and_close_where() -> void:
	var s := _store()
	s.open("computer", Rect2(0, 22, 200, 150))
	s.open("g:a", Rect2(0, 22, 200, 150))
	s.open("g:b", Rect2(0, 22, 200, 150))
	expect_eq(s.orphan_group_windows(["a"]), ["g:b"])
	s.close_where(func(w): return w.key == "g:a")
	expect(not s.has("g:a"))


func test_changed_signal_fires_on_mutation() -> void:
	var s := _store()
	var count := [0]
	s.changed.connect(func(): count[0] += 1)
	s.open("a", Rect2(0, 22, 200, 150))
	s.toggle_shade("a")
	s.raise("a")  # already on top: no signal
	expect_eq(count[0], 2)
