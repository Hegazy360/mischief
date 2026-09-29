## Stage-2 texture pipeline (s2-rig §4.3): TexStats counts every build path (AtlasBuilder
## pages, look pages, HiResTex rasters, warm()), per-path / glob art scales keep the 1×
## layout, multi-page room / prop atlases, mip chains on character pages, the rig's base vs
## look-only split, and RigPlayer draws from mipmapped pages with a mipmap filter.
extends TestBase

const MQ := "res://art/chars/_mannequin"


func before_each() -> void:
	TexStats.reset()


func test_tex_stats_counts_every_build_path() -> void:
	assert_eq(TexStats.pages_built(), 0, "reset")
	var paths := PackedStringArray(["%s/head.svg" % MQ, "%s/torso.svg" % MQ])
	AtlasBuilder.forget("test:ts:a")
	var set := AtlasBuilder.build("test:ts:a", paths, 1.0)
	assert_eq(TexStats.built("atlas"), set.pages.size(), "one per atlas page")
	AtlasBuilder.build("test:ts:a", paths, 1.0)
	assert_eq(TexStats.built("atlas"), set.pages.size(), "a cached set builds nothing")
	HiResTex.clear()
	HiResTex.get_texture("%s/hat.svg" % MQ, {}, 1.5)
	assert_eq(TexStats.built("hires"), 1, "a HiResTex raster")
	AtlasBuilder.forget("test:ts:w")
	var n := 0
	while not AtlasBuilder.warm("test:ts:w", paths, 2, 1.0) and n < 600:
		n += 1
		await tree.process_frame
	assert_eq(TexStats.built("atlas"), set.pages.size() * 2, "warm() pages are counted when they upload")
	AtlasBuilder.forget("test:ts:l:look:X")
	AtlasBuilder.build("test:ts:l:look:X", paths, 1.0)
	assert_eq(TexStats.built("look"), 1, "look keys count as look pages")
	assert_eq(TexStats.pages_built(), TexStats.built("atlas") + TexStats.built("hires") + TexStats.built("look"))
	assert_false(TexStats.recent().is_empty(), "recent builds are listed for the device log")
	TexStats.note_build("fx", "sparkle")
	assert_eq(TexStats.by_kind().get("fx", 0), 1, "s2-view's FX builds count too")
	TexStats.reset()
	assert_eq(TexStats.pages_built(), 0)
	for k in ["test:ts:a", "test:ts:w", "test:ts:l:look:X"]:
		AtlasBuilder.forget(k)


func test_per_path_and_glob_scales_keep_the_layout() -> void:
	var head := "%s/head.svg" % MQ
	var torso := "%s/torso.svg" % MQ
	var hat := "%s/hat.svg" % MQ
	assert_almost_eq(AtlasBuilder.scale_for_path(head, 2.0, {head: 1.0}), 1.0)
	assert_almost_eq(AtlasBuilder.scale_for_path(torso, 2.0, {"*/tor*.svg": 1.5}), 1.5, 0.0001, "glob key")
	assert_almost_eq(AtlasBuilder.scale_for_path(hat, 2.0, {"*/tor*.svg": 1.5}), 2.0, 0.0001, "no match: the set's scale")
	assert_almost_eq(AtlasBuilder.scale_for_path(hat, 1.5, {hat: 2.0}), 1.5, 0.0001, "never above the set's scale")
	AtlasBuilder.forget("test:scales")
	var set := AtlasBuilder.build("test:scales", PackedStringArray([head, torso, hat]), 2.0, {}, 0, {head: 1.0, "*/tor*.svg": 1.5})
	for q in [head, torso, hat]:
		assert_eq(set.size_1x(q), AtlasBuilder.svg_size(q), "%s: 1× layout unchanged" % q.get_file())
	var k_head := set.region(head).size.x / set.draw_rect(head).size.x
	var k_torso := set.region(torso).size.x / set.draw_rect(torso).size.x
	var k_hat := set.region(hat).size.x / set.draw_rect(hat).size.x
	assert_almost_eq(k_head, 1.0, 0.02, "head at 1×")
	assert_almost_eq(k_torso, 1.5, 0.02, "torso at 1.5×")
	assert_almost_eq(k_hat, 2.0, 0.02, "hat at the set's 2×")
	AtlasBuilder.forget("test:scales")


func test_multi_page_atlases_split_over_2048_pages() -> void:
	# Room-sized images: 5 × 1000×900 cannot share one 2048² page.
	var sizes: Array[Vector2i] = []
	for i in 5:
		sizes.append(Vector2i(1000, 900))
	var r := AtlasBuilder.pack(sizes, [Vector2i(4, 4)])
	var pages: Array = r["pages"]
	assert_ge(pages.size(), 2, "overflows onto a second page")
	for ps in pages:
		assert_le((ps as Vector2i).x, AtlasBuilder.PAGE_PREF)
		assert_le((ps as Vector2i).y, AtlasBuilder.PAGE_PREF)
	var place: PackedInt32Array = r["place"]
	var seen := {}
	for i in 5:
		seen[place[i * 3]] = true
	assert_eq(seen.size(), pages.size(), "every page holds images")
	# A real multi-page build: page_index tells where each image went.
	var rig := RigDef.for_id("_mannequin")
	var paths := rig.all_texture_paths()
	AtlasBuilder.forget("test:mp")
	var big := AtlasBuilder.build("test:mp", paths, 6.0)
	assert_ge(big.pages.size(), 2, "the mannequin at 6× needs 2+ pages (%d)" % big.pages.size())
	for q in paths:
		var pi := big.page_index(q)
		assert_between(pi, 0, big.pages.size() - 1)
		assert_true(Rect2(Vector2.ZERO, Vector2(big.page_sizes[pi])).encloses(big.region(q)), "%s inside page %d" % [q.get_file(), pi])
	AtlasBuilder.forget("test:mp")


func test_character_pages_carry_mipmaps_and_players_filter_with_them() -> void:
	assert_true(AtlasBuilder.mipmaps, "mipmaps on by default")
	var p := RigPlayer.new()
	tree.root.add_child(p)
	p.setup("_mannequin")
	assert_true(p.atlas.mipmaps)
	assert_true(p.atlas.pages[0].get_image().has_mipmaps(), "the page has a mip chain")
	assert_eq(p._filter, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var sz := p.atlas.page_sizes[0]
	assert_eq(p.atlas.memory_bytes(), sz.x * sz.y * 4 + sz.x * sz.y * 4 / 3, "memory includes the mip chain")
	p.free()


func test_base_and_look_texture_split() -> void:
	for id in ["_mannequin", "bellows", "hush"]:
		var r := RigDef.for_id(id)
		if r == null:
			continue
		var all := r.all_texture_paths()
		var base := r.base_texture_paths()
		var looks := {}
		for k in r.residues:
			for q in r.look_texture_paths(String(k)):
				looks[q] = true
				assert_false(base.has(q), "%s: look file %s is not in the base" % [id, q.get_file()])
		for q2 in all:
			assert_true(base.has(q2) or looks.has(q2), "%s: %s is in the base or a look" % [id, q2.get_file()])
		for q3 in r.core_texture_paths():
			var visible_rest := false
			for i in r.names.size():
				if r.is_textured(i) and r.rest[RigDef.ch(i, RigDef.C_VIS)] >= 0.5 and r.tex_files[i][clampi(int(r.rest[RigDef.ch(i, RigDef.C_TEX)]), 0, r.tex_files[i].size() - 1)] == q3:
					visible_rest = true
			if visible_rest:
				assert_true(base.has(q3), "%s: the rest look %s is in the base" % [id, q3.get_file()])
		print("  [atlas] %s: %d textures = %d base + %d look-only" % [id, all.size(), base.size(), all.size() - base.size()])
