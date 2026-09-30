## ScreenRectLint3D (brief r3d-tools-b §4.2, §5): a live rect of 130 px, a hit box 20 px from its neighbour, a rect
## under the pause button, one outside the safe rect each fail; under the Bellows window only warns; the HUD rects per
## aspect (REDESIGN §2.1 with S = 96 at 20:9; ×0.8 at 4:3); the real framing sweep covers every live prop.
extends TestBase

var _hud: Dictionary = {}
var _view := Rect2(0, 0, 2400, 1080)


func before_each() -> void:
	_hud = {"always_on": {"pause": Rect2(120, 24, 144, 144), "script": Rect2(288, 24, 312, 144),
		"clarence": Rect2(128, 880, 168, 168), "action": Rect2(1992, 792, 240, 240)},
		"pip": Rect2(1880, 24, 400, 225), "safe": Rect2(96, 0, 2208, 1080)}


func _frame(rects: Dictionary) -> Dictionary:
	return {"cam_x": 15.0, "rects": rects, "px_per_m_back": 226.0}


func _rules(issues: Array, level: String = Lint3D.ERROR) -> PackedStringArray:
	var out := PackedStringArray()
	for i in issues:
		if String((i as Dictionary)["level"]) == level:
			out.append(String((i as Dictionary)["rule"]))
	return out


func _lint(rects: Dictionary, ids: Array) -> Array:
	return ScreenRectLint3D.check_frame("fx", "kitchen", "20x9", _frame(rects), PackedStringArray(ids), _view, _hud)


func test_clean_frame_passes() -> void:
	var issues := _lint({"a": Rect2(700, 300, 200, 200), "b": Rect2(930, 300, 200, 200)}, ["a", "b"])
	assert_eq(_rules(issues), PackedStringArray())
	assert_eq(_rules(issues, Lint3D.WARNING), PackedStringArray())


func test_a_live_rect_of_130_px_fails() -> void:
	assert_eq(_rules(_lint({"a": Rect2(700, 300, 130, 200)}, ["a"])), PackedStringArray(["min_size"]))
	assert_eq(_rules(_lint({"a": Rect2(700, 300, 200, 130)}, ["a"])), PackedStringArray(["min_size"]))


func test_two_rects_20_px_apart_fail_once() -> void:
	var issues := _lint({"a": Rect2(700, 300, 200, 200), "b": Rect2(920, 300, 200, 200)}, ["a", "b"])
	assert_eq(_rules(issues), PackedStringArray(["gap"]), "reported once per pair")
	assert_almost_eq(float(issues[0]["value"]), 20.0, 0.001)
	# stacked (the kettle under the honey): the vertical gap counts
	assert_eq(_rules(_lint({"a": Rect2(700, 100, 200, 200), "b": Rect2(700, 320, 200, 200)}, ["a", "b"])),
		PackedStringArray(["gap"]))
	assert_eq(_rules(_lint({"a": Rect2(700, 100, 200, 200), "b": Rect2(700, 330, 200, 200)}, ["a", "b"])),
		PackedStringArray())


func test_a_neighbour_rooms_rect_counts_for_the_gap() -> void:
	var issues := _lint({"a": Rect2(700, 300, 200, 200), "n": Rect2(915, 300, 200, 200)}, ["a"])
	assert_eq(_rules(issues), PackedStringArray(["gap"]))


func test_a_rect_under_the_pause_button_fails() -> void:
	var issues := _lint({"a": Rect2(200, 100, 200, 200)}, ["a"])
	assert_eq(_rules(issues), PackedStringArray(["hud_overlap", "hud_overlap"]), "pause and the Script chip")
	assert_has(String(issues[0]["subject"]), "|pause")


func test_outside_the_safe_rect_fails() -> void:
	assert_eq(_rules(_lint({"a": Rect2(40, 400, 200, 200)}, ["a"])), PackedStringArray(["safe_rect"]))


func test_under_the_bellows_window_only_warns() -> void:
	var issues := _lint({"a": Rect2(1900, 150, 200, 200)}, ["a"])
	assert_eq(_rules(issues), PackedStringArray())
	assert_eq(_rules(issues, Lint3D.WARNING), PackedStringArray(["window_overlap"]))


func test_back_wall_px_per_m() -> void:
	var fr := _frame({"a": Rect2(700, 300, 200, 200)})
	fr["px_per_m_back"] = 190.0
	var issues := ScreenRectLint3D.check_frame("fx", "kitchen", "20x9", fr, PackedStringArray(["a"]), _view, _hud)
	assert_eq(_rules(issues), PackedStringArray(["back_wall"]))


func test_hud_rects_per_aspect() -> void:
	var h20 := ScreenRectLint3D.hud_rects(null, "20x9")
	assert_eq(h20["always_on"]["pause"], Rect2(120, 24, 144, 144), "S + 24 with S = 96 (REDESIGN §2.1)")
	assert_eq(h20["always_on"]["action"], Rect2(2400 - 96 - 168 - 120, 1080 - 168 - 120, 240, 240))
	assert_eq(h20["safe"], Rect2(96, 0, 2208, 1080))
	assert_eq(h20["pip"], Rect2(2400 - 96 - 424, 24, 400, 225))
	var h43 := ScreenRectLint3D.hud_rects(null, "4x3")
	assert_almost_eq(float(h43["hud_scale"]), 0.8, 0.001, "4:3 = a 1920 × 1440 tablet canvas: HUD × 0.8 (§2.6)")
	var p43: Rect2 = h43["always_on"]["pause"]
	assert_almost_eq(p43.size.x, 144.0 * 0.8 * 0.75, 0.01, "mapped into the 1440 × 1080 frame")
	assert_almost_eq((h43["safe"] as Rect2).size.x, 1440.0, 0.01)


func test_the_script_chip_width_follows_the_night() -> void:
	var db := ContentDB.load_dir("res://data")
	var ep: EpisodeDef = db.episodes.get("n01_throat_tea", null)
	if ep == null:
		skip("n01 missing")
		return
	var h := ScreenRectLint3D.hud_rects(ep, "20x9")
	assert_ge((h["always_on"]["script"] as Rect2).size.x, 312.0)


func test_fold_keeps_the_worst_value_and_counts_framings() -> void:
	var a := Lint3D.issue("screen", "min_size", Lint3D.ERROR, "fx", "k", "a", Vector2(130, 200), "144×144", "r3d-sets",
		"20x9 cam x 15.0: hit box too small")
	var b := Lint3D.issue("screen", "min_size", Lint3D.ERROR, "fx", "k", "a", Vector2(120, 200), "144×144", "r3d-sets",
		"20x9 cam x 15.5: hit box too small")
	var f := ScreenRectLint3D.fold([a, b], "20x9")
	assert_eq(f.size(), 1)
	assert_eq(f[0]["value"], Vector2(120, 200))
	assert_eq(int(f[0]["framings"]), 2)
	assert_has(String(f[0]["detail"]), "15.0…15.5")


func test_real_sweep_measures_every_live_prop_of_the_prologue() -> void:
	var db := ContentDB.load_dir("res://data")
	if not db.episodes.has("p00_curtain_up"):
		skip("p00 missing")
		return
	var r := ScreenRectLint3D.run(db, PackedStringArray(["p00_curtain_up"]), PackedStringArray(["20x9"]))
	var rooms: Dictionary = r["results"]["p00_curtain_up"]["20x9"]["rooms"]
	assert_true(rooms.has("kitchen") and rooms.has("parlour"))
	for rid in rooms.keys():
		assert_ge(int(rooms[rid]["framings"]), 1, "%s has at least one framing" % rid)
		for id in (rooms[rid]["min_size"] as Dictionary).keys():
			var s: Vector2 = rooms[rid]["min_size"][id]
			assert_gt(s.x, 50.0, "%s projects to a real rect (%s)" % [id, s])
