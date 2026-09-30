## REDESIGN_3D §6.2 C1 — the episode field `hides`: the slice lists (one hiding spot per room in Act I), their
## validation (ids, kinds, rooms, one per room, the safety net and the Director cues) and the solutions (every
## hide step uses a listed spot; `SolutionDef.validate_live`).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")

const HIDES := {
	"p00_curtain_up": ["kitchen_pantry_curtain", "parlour_piano_back"],
	"g0_sneeze": ["kitchen_pantry_curtain"],
	"n01_throat_tea": ["kitchen_pantry_curtain", "parlour_piano_back", "hall_coat_cupboard"],
	"n02_something_fishy": ["kitchen_pantry_curtain", "parlour_piano_back", "hall_coat_cupboard"],
}


func test_the_slice_episodes_list_their_hiding_spots() -> void:
	for ep_id in HIDES:
		var d: Variant = TestBase.load_json("res://data/episodes/%s.json" % ep_id)
		if not assert_true(d is Dictionary, ep_id):
			continue
		assert_eq((d as Dictionary).get("hides", null), HIDES[ep_id], "%s.hides" % ep_id)


func test_real_content_validates_with_the_lists() -> void:
	var db := ContentDB.load_dir("res://data")
	assert_eq(db.errors, PackedStringArray(), "real content validates")
	for ep_id in HIDES:
		var ep: EpisodeDef = db.episodes.get(ep_id, null)
		if not assert_true(ep != null, ep_id):
			continue
		assert_true(ep.has_hides)
		assert_eq(ContentValidate.hides_per_room(db, ep), PackedStringArray(), "%s: one hiding spot per room" % ep_id)
		var sn := ContentUtil.dict(ep.director, "safety_net")
		if ContentUtil.s(sn, "pulse") != "":
			assert_true(ep.hides.has(ContentUtil.s(sn, "pulse")), "%s: the safety-net pulse is listed" % ep_id)
		for c in ContentUtil.arr(ep.director, "cues"):
			var tgt := ContentUtil.s(c, "target")
			var hs := db.house.hotspot(tgt)
			if hs != null and hs.kind == HotspotDef.HIDING:
				assert_true(ep.hides.has(tgt), "%s: cue %s targets a listed spot" % [ep_id, ContentUtil.s(c, "id")])


func _errs(ep_patch: Callable) -> PackedStringArray:
	var files := U.raw()
	ep_patch.call(files["episodes"]["fx_act1"])
	return ContentDB.load_dicts(files).errors


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if e.contains(needle):
			return true
	return false


func test_validation_names_every_bad_list() -> void:
	var e := _errs(func(ep: Dictionary) -> void: ep["hides"] = ["kitchen_honey"])
	assert_true(_has(e, "hides 'kitchen_honey' is a rig_point, not a hiding spot"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["hides"] = ["attic_trunk"])
	assert_true(_has(e, "hides 'attic_trunk' not in house.json"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["hides"] = ["kitchen_pantry_curtain", "kitchen_pantry_curtain"])
	assert_true(_has(e, "lists 'kitchen_pantry_curtain' twice"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["hides"] = ["kitchen_pantry_curtain", "kitchen_table"])
	assert_true(_has(e, "hides lists 2 hiding spots in room kitchen"), "Act I final: one per room — %s" % str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["hides"] = "kitchen_pantry_curtain")
	assert_true(_has(e, "hides must be a list"), str(e))
	e = _errs(func(ep: Dictionary) -> void:
		ep["hides"] = ["kitchen_pantry_curtain"]
		ep["director"] = {"safety_net": {"pulse": "kitchen_table", "hide_before_entry_s": 1.5},
			"cues": [{"id": "ghost_hide", "when": {"tick_ge_s": 1.0}, "target": "kitchen_table", "mode": "tap"}]})
	assert_true(_has(e, "safety_net.pulse 'kitchen_table' is not in hides"), str(e))
	assert_true(_has(e, "cues.ghost_hide.target 'kitchen_table' is not in hides"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["hides"] = ["kitchen_pantry_curtain", "parlour_piano_back"])
	assert_eq(e, PackedStringArray(), "a good list validates")


func test_a_draft_with_two_spots_in_a_room_only_warns() -> void:
	var files := U.raw()
	files["episodes"]["fx_act1"]["status"] = "draft"
	files["episodes"]["fx_act1"]["hides"] = ["kitchen_pantry_curtain", "kitchen_table"]
	var db := ContentDB.load_dicts(files)
	assert_false(_has(db.errors, "hides lists 2"), "no error for a draft: %s" % str(db.errors))
	assert_true(_has(db.warnings, "hides lists 2 hiding spots in room kitchen"), str(db.warnings))


func test_every_solution_hide_uses_a_listed_spot() -> void:
	var data := SolverData.load_dir("res://data")
	for ep_id in HIDES:
		var sol := SolutionDef.load_file("res://data/solutions/%s.json" % ep_id)
		if not assert_true(sol != null, ep_id):
			continue
		for rn in sol.route_names():
			var steps: Array = (sol.routes[rn] as Dictionary).get("steps", [])
			for i in steps.size():
				var s: Dictionary = steps[i]
				if String(s.get("do", "")) == "hide":
					assert_true((HIDES[ep_id] as Array).has(String(s.get("spot", ""))),
						"%s/%s step %d hides in %s" % [ep_id, rn, i + 1, s.get("spot", "")])
				assert_eq(SolutionDef.validate_live(s, data, ep_id), PackedStringArray(), "%s/%s step %d" % [ep_id, rn, i + 1])
		assert_eq(sol.validate(data), PackedStringArray(), "solutions/%s.json validates" % ep_id)
	var bad := SolutionDef.validate_live({"do": "hide", "spot": "kitchen_table"}, data, "n01_throat_tea")
	assert_eq(bad.size(), 1)
	assert_true(bad[0].contains("struck"), str(bad))


func test_the_retired_scenarios_are_gone() -> void:
	var sol := SolutionDef.load_file("res://data/solutions/n02_something_fishy.json")
	if not assert_true(sol != null):
		return
	assert_false(sol.routes.has("face_to_face"), "face_to_face retired (C2)")
	assert_false(sol.routes.has("face_to_face_lost"), "face_to_face_lost retired (C2)")
	var n1 := FileAccess.get_file_as_string("res://data/solutions/n01_throat_tea.json")
	assert_false(n1.contains("\"kitchen_table\""), "N1 hides moved to the pantry curtain")
	assert_false(n1.contains("\"parlour_chaise_back\""), "N1 chase hides behind the piano")


func test_fixup_holds_validate() -> void:
	var e := _errs(func(ep: Dictionary) -> void: ep["director"] = {"fixup_holds": [{"kind": "COMB", "until": "rigged:nope"}]})
	assert_true(_has(e, "fixup_holds[0].kind 'COMB'"), str(e))
	assert_true(_has(e, "fixup_holds[0].until 'rigged:nope' not in pranks.json"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["director"] = {"fixup_holds": [{"kind": "MIRROR"}]})
	assert_true(_has(e, "fixup_holds[0].until is missing"), str(e))
	e = _errs(func(ep: Dictionary) -> void: ep["director"] = {"fixup_holds": [{"kind": "MIRROR", "until": "rigged:lift_off"}]})
	assert_false(_has(e, "fixup_holds"), str(e))

