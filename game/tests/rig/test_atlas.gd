## AtlasBuilder / AtlasSet: shelf-skyline packing without overlaps, padding, extrude,
## 1× sizes, built-ins, ≥ 90 % pack for the mannequin; HiResTex basics.
extends TestBase


func test_pack_has_no_overlaps_and_keeps_padding() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sizes: Array[Vector2i] = []
	for i in 60:
		sizes.append(Vector2i(rng.randi_range(8, 220), rng.randi_range(8, 260)))
	var r := AtlasBuilder.pack(sizes, [Vector2i(4, 4)], 512, 1024)
	var cells: PackedInt32Array = r["cells"]
	var place: PackedInt32Array = r["place"]
	var pages: Array = r["pages"]
	assert_gt(pages.size(), 1, "overflows onto more 512 pages")
	for i in sizes.size():
		var ci := Rect2i(cells[i * 4], cells[i * 4 + 1], cells[i * 4 + 2], cells[i * 4 + 3])
		var pg := place[i * 3]
		var ps: Vector2i = pages[pg]
		assert_true(Rect2i(Vector2i.ZERO, ps).encloses(ci), "cell %d inside its page" % i)
		assert_eq(Vector2i(place[i * 3 + 1], place[i * 3 + 2]) - ci.position, Vector2i(AtlasBuilder.PAD, AtlasBuilder.PAD), "image inset by the padding")
		assert_eq(ci.size, sizes[i] + Vector2i(2, 2) * AtlasBuilder.PAD)
		for j in range(i + 1, sizes.size()):
			if place[j * 3] != pg:
				continue
			var cj := Rect2i(cells[j * 4], cells[j * 4 + 1], cells[j * 4 + 2], cells[j * 4 + 3])
			if ci.intersects(cj):
				fail("cells %d and %d overlap" % [i, j])
				return


func test_mannequin_atlas_regions_sizes_and_ratio() -> void:
	var rig := RigDef.for_id("_mannequin")
	var paths := rig.all_texture_paths()
	var set := AtlasBuilder.build("test:mannequin:2", paths, 2.0)
	assert_eq(set.missing, PackedStringArray(), "every texture rasterised")
	assert_eq(set.pages.size(), 1, "one page for the whole character")
	assert_le(set.page_sizes[0].x, AtlasBuilder.PAGE_PREF)
	assert_le(set.page_sizes[0].y, AtlasBuilder.PAGE_PREF)
	assert_ge(set.pack_ratio(), 0.9, "≥ 90 %% of the page used (%.1f %%)" % (set.pack_ratio() * 100.0))
	var cells: Array[Rect2i] = []
	for p in paths:
		var s1 := set.size_1x(p)
		var reg := set.region(p)
		assert_eq(s1, AtlasBuilder.svg_size(p), "%s: 1× size = authored size" % p.get_file())
		var dr := set.draw_rect(p)
		assert_almost_eq(reg.size.x, dr.size.x * 2.0, 0.01, "region is 2× its 1× draw rect")
		assert_almost_eq(reg.size.y, dr.size.y * 2.0, 0.01)
		assert_true(Rect2(Vector2.ZERO, s1).grow(0.01).encloses(dr), "trimmed rect stays inside the canvas")
		cells.append(set.cell(p))
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			assert_false(cells[i].intersects(cells[j]), "no overlap %d/%d" % [i, j])
	for b in [AtlasSet.WHITE, AtlasSet.DISC, AtlasSet.LINE]:
		assert_ne(set.builtin_uv(b, 0), Rect2(), "built-in %s packed" % b)
	# Extrude: the pixel just outside a region repeats the region's edge pixel.
	var img := set.pages[0].get_image()
	var reg2 := set.region(paths[0])
	var x := int(reg2.position.x) + int(reg2.size.x / 2)
	var y := int(reg2.position.y)
	assert_eq(img.get_pixel(x, y - 1), img.get_pixel(x, y), "top edge extruded")
	assert_eq(AtlasBuilder.build("test:mannequin:2", paths, 2.0), set, "cached by key")
	# Trimming: the kept pixels hold every visible pixel of the full raster.
	var head := "res://art/chars/_mannequin/head.svg"
	var full := HiResTex.rasterize(head, {}, 2.0)
	var used := full.get_used_rect()
	var dr2 := set.draw_rect(head)
	assert_true(Rect2(dr2.position * 2.0, dr2.size * 2.0).grow(0.01).encloses(Rect2(used)), "trim keeps all opaque pixels")


func test_warm_builds_without_blocking() -> void:
	var rig := RigDef.for_id("_mannequin")
	var paths := rig.all_texture_paths()
	AtlasBuilder.forget("test:warm")
	var calls := 0
	while not AtlasBuilder.warm("test:warm", paths, 2, 1.0):
		calls += 1
		await tree.process_frame
		if calls > 600:
			break
	var set := AtlasBuilder.get_set("test:warm")
	assert_true(set != null, "warm() finishes")
	assert_eq(set.paths().size(), paths.size())
	AtlasBuilder.forget("test:warm")


func test_hires_tex_overrides_size_to_1x() -> void:
	var p := "res://art/chars/_mannequin/head.svg"
	var t := HiResTex.get_texture(p, {}, 2.0)
	assert_true(t != null)
	assert_eq(t.get_size(), AtlasBuilder.svg_size(p), "layout size stays 1×")
	assert_eq(t.get_image().get_size(), Vector2i(AtlasBuilder.svg_size(p) * 2.0), "pixels are 2×")
	var swapped := HiResTex.swap_colors('fill="#F1D3A8" stroke="#1b2340"', {"#F1D3A8": "#00FF00", "#1B2340": "#FF0000"})
	assert_eq(swapped, 'fill="#00FF00" stroke="#FF0000"')
	assert_true(HiResTex.ART_SCALE == 2.0 or HiResTex.ART_SCALE == 1.5)
