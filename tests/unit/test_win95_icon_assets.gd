extends TestCase
## Port of win95/__tests__/iconAssets.test.ts (clean-room asset families).

const ROOT := "res://assets/win95"


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		failures.append("%s: cannot decode %s" % [_current, path])
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func test_ships_both_native_families_for_every_catalog_id() -> void:
	for id in Win95IconCatalog.ICON_IDS:
		var small := _load("%s/small/%s-16.png" % [ROOT, id])
		var large := _load("%s/large/%s-32.png" % [ROOT, id])
		if small:
			expect_eq(small.get_size(), Vector2i(16, 16), "small " + id)
		if large:
			expect_eq(large.get_size(), Vector2i(32, 32), "large " + id)


func test_generates_every_higher_variant_by_strict_nearest_neighbor() -> void:
	for pair in [["small", 16], ["large", 32]]:
		var family: String = pair[0]
		var base: int = pair[1]
		for id in Win95IconCatalog.ICON_IDS:
			var source := _load("%s/%s/%s-%d.png" % [ROOT, family, id, base])
			if source == null:
				continue
			var src_data := source.get_data()
			for factor: int in [2, 3, 4]:
				var output := _load("%s/%s/%s-%d.png" % [ROOT, family, id, base * factor])
				if output == null:
					continue
				expect_eq(output.get_width(), base * factor, "%s %s x%d width" % [family, id, factor])
				var out_data := output.get_data()
				var w := output.get_width()
				var same := true
				for y in output.get_height():
					for x in w:
						var o := (y * w + x) * 4
						var s := ((y / factor) * base + (x / factor)) * 4
						if out_data[o] != src_data[s] or out_data[o + 1] != src_data[s + 1] or out_data[o + 2] != src_data[s + 2] or out_data[o + 3] != src_data[s + 3]:
							same = false
							break
					if not same:
						break
				expect(same, "%s %s x%d is not a nearest-neighbor enlargement" % [family, id, factor])


func test_uses_independently_drawn_small_sources_rather_than_reductions() -> void:
	for id in ["my-computer", "folder", "find", "shutdown"]:
		var small := _load("%s/small/%s-16.png" % [ROOT, id])
		var large := _load("%s/large/%s-32.png" % [ROOT, id])
		if small == null or large == null:
			continue
		var differs := false
		for y in 16:
			for x in 16:
				if small.get_pixel(x, y) != large.get_pixel(x * 2, y * 2):
					differs = true
					break
			if differs:
				break
		expect(differs, id + " small icon equals a reduction of the large one")
