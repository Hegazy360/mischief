## SetLint3D (brief r3d-tools-b §4.1, §5): each rule fails on its fixture and passes on a clean one — a fake SetList
## with 6 live props, 5 dressing pieces, two hiding spots in an Act-I room, a quake prop at 1.6 m on a wall, dressing
## in the lane / too small / in a preview band, no negative space, a shared silhouette family, a stack 20 px apart, two
## masks at IoU 0.9 (sil64.py fixture), a dressing piece at C* 40 (lab.py fixture) — and the real Prologue.
extends TestBase

const FX := "res://tests/lint3d/fixtures/"


func _box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> AABB:
	return AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, y1 - y0, z1 - z0))


func _live(id: String, x: float, kind: String = "rig", fam: String = "", merge: String = "") -> Dictionary:
	var b := _box(x, 0.8, -2.0, x + 0.4, 1.5, -1.7)
	return {"id": id, "kind": kind, "silhouette": fam if fam != "" else id, "merge": merge, "hit": b, "visual": b}


## A clean room 6 m wide: 3 live props low on the counter, 2 dressing pieces high up, a 2 m clear stretch.
func _room() -> Dictionary:
	return {"lit": true, "x0": 10.0, "x1": 16.0,
		"live": [_live("a_jar", 10.5), _live("b_kettle", 11.5), _live("c_pantry", 15.2, "hide")],
		"dressing": [{"id": "d_window", "box": _box(12.2, 1.9, -2.4, 12.9, 2.8, -2.35), "quake": false, "source": "dressing"},
			{"id": "d_pans", "box": _box(13.0, 2.3, -2.35, 13.8, 2.8, -2.25), "quake": true, "source": "dressing"}],
		"furniture": [], "decor": [], "built_ins": []}


func _facts(room: Dictionary, act: int = 1) -> Dictionary:
	return {"night": "fx_night", "act": act, "rooms": {"kitchen": room}}


func _rules(issues: Array, level: String = Lint3D.ERROR) -> PackedStringArray:
	var out := PackedStringArray()
	for i in issues:
		if String((i as Dictionary)["level"]) == level:
			out.append(String((i as Dictionary)["rule"]))
	return out


func test_clean_room_passes() -> void:
	var issues := SetLint3D.check_facts(_facts(_room()))
	assert_eq(_rules(issues), PackedStringArray(), "clean fixture room: %s" % [_rules(issues)])


func test_six_live_props_fail() -> void:
	var rm := _room()
	for i in 3:
		(rm["live"] as Array).append(_live("x%d" % i, 12.0 + 0.5 * float(i)))
	assert_has(_rules(SetLint3D.check_facts(_facts(rm))), "live_count")


func test_five_dressing_pieces_fail() -> void:
	var rm := _room()
	for i in 3:
		(rm["dressing"] as Array).append({"id": "extra%d" % i, "box": _box(14.0, 2.4, -2.4, 14.6, 3.0, -2.35), "quake": false})
	assert_has(_rules(SetLint3D.check_facts(_facts(rm))), "dressing_count")


func test_two_hiding_spots_in_an_act_one_room_fail() -> void:
	var rm := _room()
	(rm["live"] as Array).append(_live("d_piano", 14.2, "hide"))
	assert_has(_rules(SetLint3D.check_facts(_facts(rm, 1))), "hides_act1")
	assert_false(_rules(SetLint3D.check_facts(_facts(rm, 2))).has("hides_act1"), "Act II may have two")


func test_quake_prop_at_1_6_m_on_a_wall_fails_on_the_mantel_passes() -> void:
	var rm := _room()
	(rm["dressing"] as Array)[1]["box"] = _box(13.0, 1.6, -2.4, 13.8, 2.1, -2.3)
	assert_has(_rules(SetLint3D.check_facts(_facts(rm))), "quake_height")
	var mantel := _box(12.9, 1.4, -2.4, 14.0, 1.6, -2.0)
	assert_false(_rules(SetLint3D.check_facts(_facts(rm), [mantel])).has("quake_height"), "sitting on the mantel top")


func test_dressing_small_in_the_lane_or_over_a_preview_fails() -> void:
	var rm := _room()
	(rm["dressing"] as Array).append({"id": "vase_small", "box": _box(13.9, 2.5, -2.4, 14.2, 2.8, -2.35), "quake": false})
	(rm["dressing"] as Array).append({"id": "lane_lamp", "box": _box(14.6, 0.0, -1.5, 15.1, 1.0, -1.2), "quake": false})
	(rm["dressing"] as Array).append({"id": "over_jar", "box": _box(10.4, 1.3, -2.4, 11.0, 1.7, -2.35), "quake": false})
	var r := _rules(SetLint3D.check_facts(_facts(rm)))
	assert_has(r, "dressing_size")
	assert_has(r, "dressing_lane")
	assert_has(r, "preview_band")


func test_no_negative_space_fails() -> void:
	var rm := _room()
	(rm["built_ins"] as Array).append({"id": "shelf_wall", "box": _box(11.9, 1.2, -2.4, 15.5, 1.4, -2.2)})
	assert_has(_rules(SetLint3D.check_facts(_facts(rm))), "negative_space")
	var fs := SetLint3D.free_stretch(_room())
	assert_almost_eq(float(fs["len"]), 3.3, 0.01, "11.9 … 15.2 between the kettle and the pantry")


func test_shared_silhouette_family_fails_merged_zones_pass() -> void:
	var rm := _room()
	(rm["live"] as Array).append(_live("e_jar2", 13.5, "rig", "a_jar"))
	assert_has(_rules(SetLint3D.check_facts(_facts(rm))), "silhouette_family")
	var rm2 := _room()
	(rm2["live"] as Array)[0]["merge"] = "fridge"
	(rm2["live"] as Array).append(_live("a_jar_zone2", 10.5, "take", "a_jar", "fridge"))
	assert_false(_rules(SetLint3D.check_facts(_facts(rm2))).has("silhouette_family"), "two zones of one merged prop")


func test_a_stack_20_px_apart_fails_30_passes() -> void:
	var frames := [{"cam_x": 13.0, "rects": {"honey": Rect2(100, 100, 200, 200), "kettle": Rect2(100, 320, 200, 200)}},
		{"cam_x": 13.5, "rects": {"honey": Rect2(100, 100, 200, 200), "kettle": Rect2(100, 330, 200, 200)}}]
	var issues := SetLint3D.check_stacks("fx", "kitchen", frames, PackedStringArray(["honey", "kettle"]))
	assert_eq(_rules(issues), PackedStringArray(["stack"]))
	assert_almost_eq(float(issues[0]["value"]), 20.0, 0.001, "the worst framing")
	var ok := SetLint3D.check_stacks("fx", "kitchen", [frames[1]], PackedStringArray(["honey", "kettle"]))
	assert_eq(_rules(ok), PackedStringArray())


func test_two_masks_at_iou_0_9_fail() -> void:
	var sil: Variant = load_json(FX + "sil_iou.json")
	var issues := SetLint3D.iou_issues("fx", "kitchen", sil)
	assert_eq(_rules(issues), PackedStringArray(["silhouette_iou"]))
	assert_has(String(issues[0]["subject"]), "fx_jar|fx_jar_twin")
	assert_ge(float(issues[0]["value"]), 0.8)


func test_a_dressing_piece_at_c40_fails() -> void:
	var rules: Variant = load_json(FX + "colour_rules.json")
	var issues := SetLint3D.colour_issues("fx", "kitchen", rules)
	var bad := PackedStringArray()
	for i in issues:
		if String(i["level"]) == Lint3D.ERROR:
			bad.append(String(i["subject"]))
	assert_eq(bad.size(), 1, "only the C* 40 piece fails: %s" % [bad])
	assert_has(bad[0], "fx_rug_c40")
	assert_eq(Lint3D.counts(issues)[Lint3D.INFO], 8, "the clean regions are reported with their values")


func test_missing_measures_skip() -> void:
	var issues := SetLint3D.check_measures(null, PackedStringArray())
	assert_eq(_rules(issues, Lint3D.SKIP), PackedStringArray(["colour", "silhouette_iou"]))


func test_real_prologue_counts_match_redesign_3_4() -> void:
	var db := ContentDB.load_dir("res://data")
	var ep: EpisodeDef = db.episodes.get("p00_curtain_up", null)
	if ep == null:
		skip("p00_curtain_up missing (r3d-content)")
		return
	var facts := SetLint3D.facts_for(db, ep)
	var rooms: Dictionary = facts["rooms"]
	assert_true(rooms.has("kitchen") and rooms.has("parlour"), "P00 lit rooms")
	assert_false(rooms.has("hall"), "the hall is backstage")
	assert_eq((rooms["kitchen"]["live"] as Array).size(), 2, "REDESIGN §3.4: P00 kitchen live count 2")
	assert_eq((rooms["parlour"]["live"] as Array).size(), 2, "P00 parlour live count 2")
	for i in SetLint3D.check_facts(facts, SetLint3D.mantels(SetGeo.load_house3d())):
		if String(i["rule"]) in ["live_count", "dressing_count", "hides_act1", "quake_height"]:
			assert_ne(String(i["level"]), Lint3D.ERROR, Lint3D.line(i))


func test_fake_setlist_with_six_live_props_fails() -> void:
	var db := ContentDB.load_dir("res://data")
	var ep: EpisodeDef = db.episodes.get("n01_throat_tea", null)
	if ep == null:
		skip("n01 missing")
		return
	var res := SetList.for_episode(db, ep)
	# the fake: every kitchen rig point / container / hiding spot of house.json live tonight
	for h in db.house.hotspots:
		if h.room == "kitchen" and h.kind in [HotspotDef.RIG_POINT, HotspotDef.CONTAINER, HotspotDef.HIDING] and h.tappable:
			res.live[h.id] = {HotspotDef.RIG_POINT: "rig", HotspotDef.CONTAINER: "take", HotspotDef.HIDING: "hide"}[h.kind]
	var facts := SetLint3D.facts_for(db, ep, {}, res)
	assert_ge((facts["rooms"]["kitchen"]["live"] as Array).size(), 6)
	assert_has(_rules(SetLint3D.check_facts(facts)), "live_count")
