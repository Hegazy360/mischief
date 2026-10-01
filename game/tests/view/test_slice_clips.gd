## SliceClips (L14, brief §4.1.10): the manifest from a fixture db (rows, lengths, tolerances,
## `_ko`, combos filtered by `rules.combos`, Pip overrides, sim durations) and on the real data
## (deterministic, no duplicates, every slice reaction present). Writes the human-readable dump
## `docs/review/s2-view/slice_clips.md` when the repo's docs folder is reachable.
extends TestBase



func _db() -> Dictionary:
	var rows: Array = [
		{"key": "oneshot:bump", "rig": "bellows", "clip": "bellows/st_bump", "layer": "base", "len": {"src": "sim:bump"}, "episodes": "all"},
		{"key": "oneshot:doorway_pause", "rig": "bellows", "clip": "bellows/st_straighten_cravat", "layer": "base",
			"len": {"src": "sim:doorway_pause", "loop_ok": true}, "episodes": "all"},
		{"key": "oneshot:caught:lecture", "rig": "bellows", "clips": ["bellows/lec_a", "bellows/lec_b"],
			"skin": {"pip": ["bellows/lec_broom_a", "bellows/lec_broom_b"]}, "layer": "base", "len": {"src": "caught:lecture"},
			"episodes": ["n01_throat_tea"]},
		{"key": "oneshot:caught:wipe", "rig": "bellows", "clip": "", "layer": "fx", "len": {"src": "caught:wipe"}, "episodes": "all"},
		{"key": "state:meltdown", "rig": "bellows", "clips": ["bellows/melt_a"], "layer": "base", "len": {"src": "clip_timings"},
			"episodes": "all"},
		{"key": "cue:laugh_picture", "rig": "bellows", "clip": "bellows/cue_picture_bonk", "layer": "overlay",
			"len": {"src": "clip", "expect_f": 48}, "episodes": ["p00_curtain_up"]},
		{"key": "curtain:wander_on", "rig": "bellows", "clip": "bellows/cc_wander_on", "layer": "base", "len": {"src": "clip"},
			"episodes": "all"},
	]
	var bmap := {"idle": "bellows/loco_idle", "walk": {"clip": "bellows/loco_strut", "stride_px": 60}, "turn": "bellows/loco_turn",
		"walk@tier2": "bellows/loco_irked", "walk@tier3": "bellows/loco_stomp", "walk@blind": "bellows/loco_blind",
		"state:meltdown": ["bellows/melt_a"], "activity:tea": "bellows/act_tea", "bit:*": "bellows/{id}", "mg:*": "bellows/mg_{id}",
		"oneshot:bump": "bellows/st_bump", "oneshot:doorway_pause": {"clip": "bellows/st_straighten_cravat", "loop": true},
		"oneshot:caught:lecture": ["bellows/lec_a", "bellows/lec_b"],
		"skin:pip": {"oneshot:caught:lecture": ["bellows/lec_broom_a", "bellows/lec_broom_b"]}}
	var hmap := {"idle": "hush/loco_idle", "walk": "hush/loco_walk", "rigging@q": "hush/act_tinker_q",
		"rigging@b": "hush/act_tinker_b", "freeze": ["hush/freeze_1"]}
	return {
		"episodes": {"n01_throat_tea": {"id": "n01_throat_tea", "status": "final", "rooms": ["kitchen"],
			"rules": {"combos": []},
			"bellows": {"loop": [{"a": "tea"}]},
			"script": [{"kind": "prank", "prank": "achoo_ria"}, {"kind": "prank", "prank": "tap_dance"},
				{"kind": "prank", "prank": "in_a_pickle"}, {"kind": "prank", "prank": "lift_off"},
				{"kind": "double_act", "double_act": "hot_and_cold"}]}},
		"pranks": {
			"achoo_ria": {"size": "M", "steps": [{"prep": "Q"}], "reaction": {"archetype": "sneeze_blast", "variants": ["a"]},
				"knock_on": {"prank": "tap_dance", "frame": 112}, "residue": [{"kind": "FRAZZLED", "blind": true}]},
			"tap_dance": {"size": "S", "steps": [{"prep": "Q"}], "reaction": {"archetype": "drench", "variants": ["a"]},
				"residue": [{"kind": "SOAKED"}]},
			"in_a_pickle": {"size": "L", "steps": [{"prep": "B"}], "reaction": {"archetype": "strain_slip", "variants": ["a"]}},
			"lift_off": {"size": "L", "steps": [{"prep": "B"}], "reaction": {"archetype": "launch_ceiling", "variants": ["a"]}}},
		"double_acts": {"hot_and_cold": {"a": "achoo_ria", "b": "tap_dance"}},
		"activities": {"activities": {"tea": {"clip": "bellows/act_tea", "squeak_bit": "bit_tea",
				"micro_gags": [{"id": "hum", "at_s": 2.0, "len_f": 48, "emote": "hum"}, "pinkie_up"]}},
			"detours": {"fixup_mirror": {"clip": "bellows/act_fixup_mirror"}, "fixup_dry": {"clip": "bellows/act_fixup_dry"}},
			"squeak_bits": {"bit_tea": {"clip": "bellows/bit_tea", "len_f": 100, "activity": "tea"},
				"bit_paper": {"clip": "bellows/bit_paper", "len_f": 80, "activity": "paper"}}},
		"reactions": {"archetypes": {"sneeze_blast_a": {"clip": "bellows/rx_sneeze_blast_a", "frames": 165},
				"drench_a": {"clip": "bellows/rx_drench_a", "frames": 107},
				"strain_slip_a": {"clip": "bellows/rx_strain_slip_a", "frames": 159}},
			"t3_last_beats": ["bellows/beat_slow_burn", "bellows/beat_tear"],
			"caught": {"lecture": [60, 192], "wipe": [192, 204]},
			"clip_timings": {"bellows/melt_a": {"frames": 330}, "bellows/beat_slow_burn": {"frames": 70},
				"bellows/beat_tear": {"frames": 60}, "bellows/combo_poodle": {"frames": 90}}},
		"residues": {"FRAZZLED": {"fixup": "MIRROR"}, "SOAKED": {"fixup": "DRY"}},
		"combos": {"poodle": {"of": ["SOAKED", "FRAZZLED"], "clip": "bellows/combo_poodle"}},
		"rules": rows,
		"maps": {"bellows": bmap, "hush": hmap},
		"oneshots": {"bump": 82, "doorway_pause": -1},
		"house": {},
	}


func _by(rows: Array[Dictionary]) -> Dictionary:
	var d := {}
	for r in rows:
		d[r["clip"]] = r
	return d


func test_fixture_rows_lengths_and_tolerances() -> void:
	var rows := SliceClips.build_from(_db())
	var d := _by(rows)
	assert_has(d, "bellows/st_bump")
	assert_eq(int(d["bellows/st_bump"]["expect_f"]), 82, "sim: rows take SimOneshots.duration")
	assert_false(bool(d["bellows/st_bump"]["loop_ok"]), "the bump must be exactly 82")
	assert_eq(int(d["bellows/st_straighten_cravat"]["expect_f"]), -1, "the doorway pause is variable")
	assert_true(bool(d["bellows/st_straighten_cravat"]["loop_ok"]), "… so the clip loops")
	assert_eq(int(d["bellows/lec_a"]["expect_f"]), 132, "caught:lecture span 60–192")
	assert_eq(int(d["bellows/bit_tea"]["expect_f"]), 100)
	assert_eq(int(d["bellows/bit_tea"]["tol_f"]), 2, "bits ± 2 f")
	assert_false(d.has("bellows/bit_paper"), "a bit whose activity the Night doesn't play is left out")
	assert_eq(int(d["bellows/mg_hum"]["expect_f"]), 48)
	assert_eq(int(d["bellows/mg_hum"]["tol_f"]), 12, "micro-gags ± 12 f")
	assert_has(d, "bellows/mg_pinkie_up", "legacy string micro-gags are listed too")
	assert_eq(int(d["bellows/rx_sneeze_blast_a"]["expect_f"]), 165)
	assert_eq(int(d["bellows/melt_a"]["expect_f"]), 330, "clip_timings")
	assert_false(d.has("bellows/cue_picture_bonk"), "a P00-only row is not in N01")
	assert_has(d, "bellows/cc_wander_on", "curtain-call rows are in every Night")
	assert_has(d, "figgis/f_idle", "the Figgis chip clips")


func test_ko_variant_only_where_a_knock_on_can_enter() -> void:
	var d := _by(SliceClips.build_from(_db()))
	assert_has(d, "bellows/rx_drench_a_ko", "HOT & COLD enters TAP DANCE at accent − 2")
	assert_eq(int(d["bellows/rx_drench_a_ko"]["expect_f"]), 107, "same length as the plain clip")
	assert_false(d.has("bellows/rx_sneeze_blast_a_ko"), "nothing knocks on into the sneeze")


func test_combos_filtered_by_rules() -> void:
	var db := _db()
	assert_false(_by(SliceClips.build_from(db)).has("bellows/combo_poodle"), "rules.combos [] → no combo (L4)")
	(db["episodes"]["n01_throat_tea"]["rules"] as Dictionary).erase("combos")
	assert_has(_by(SliceClips.build_from(db)), "bellows/combo_poodle", "absent = all: SOAKED + FRAZZLED can form POODLE")


func test_detours_loco_tiers_and_last_beats() -> void:
	var d := _by(SliceClips.build_from(_db()))
	assert_has(d, "bellows/act_fixup_mirror", "FRAZZLED → the MIRROR fix-up detour")
	assert_has(d, "bellows/act_fixup_dry", "SOAKED → DRY")
	assert_has(d, "bellows/loco_blind", "a blinding residue → walk@blind")
	assert_has(d, "bellows/loco_stomp", "Livid is reachable → walk@tier3")
	assert_has(d, "bellows/beat_tear", "Livid → the T3 last-beat pool")
	assert_eq(int(d["bellows/beat_slow_burn"]["expect_f"]), 70)
	assert_has(d, "hush/act_tinker_q")
	assert_has(d, "hush/act_tinker_b")
	assert_false(d.has("hush/act_tinker_s"), "no S-prep step in this Night")


func test_t3_needs_livid_before_a_prank_and_a_rules_row_can_drop_a_bit() -> void:
	var db := _db()
	(db["episodes"]["n01_throat_tea"] as Dictionary)["script"] = [{"kind": "prank", "prank": "achoo_ria"},
		{"kind": "prank", "prank": "in_a_pickle"}]   # 35 + 45 = 80: Livid only after both
	var d := _by(SliceClips.build_from(db))
	assert_has(d, "bellows/loco_stomp", "Livid after both pranks → walk@tier3")
	assert_false(d.has("bellows/beat_tear"), "no reaction starts at T3 (35 < 70 before the second)")
	assert_has(d, "bellows/beat_slow_burn", "the every-4th slow burn stays")
	db = _db()
	(db["rules"] as Array).append({"key": "bit:bit_tea", "rig": "bellows", "clip": "bellows/bit_tea", "layer": "base",
		"len": {"src": "squeak_bits"}, "episodes": []})
	assert_false(_by(SliceClips.build_from(db)).has("bellows/bit_tea"), "a bit:<id> row's episodes drop the bit")


func test_pip_skin_swaps_in_the_overrides() -> void:
	var d := _by(SliceClips.build_from(_db(), "pip"))
	assert_has(d, "bellows/lec_broom_a")
	assert_false(d.has("bellows/lec_a"), "Pip: the broom Lecture replaces the lift")


func test_deterministic_and_no_duplicates() -> void:
	var a := SliceClips.build_from(_db())
	var b := SliceClips.build_from(_db())
	assert_eq(a.size(), b.size())
	var seen := {}
	for i in a.size():
		assert_eq(a[i]["clip"], b[i]["clip"], "same order")
		assert_false(seen.has(a[i]["clip"]), "no duplicate %s" % a[i]["clip"])
		seen[a[i]["clip"]] = true
		if i > 0:
			assert_true(String(a[i - 1]["clip"]) < String(a[i]["clip"]), "sorted")


func test_real_data_manifest() -> void:
	var rows := SliceClips.build()
	assert_gt(rows.size(), 60, "the slice plays many clips")
	var d := _by(rows)
	var seen := {}
	for r in rows:
		assert_false(seen.has(r["clip"]), "no duplicate %s" % r["clip"])
		seen[r["clip"]] = true
		for k in ["clip", "rig", "why", "expect_f", "tol_f", "loop_ok", "max_f", "keys"]:
			assert_true(r.has(k), "%s has %s" % [r["clip"], k])
	# Every slice reaction is present.
	var pranks: Dictionary = SliceClips._dget(ViewKit.json("res://data/pranks.json"), "pranks", {})
	for ep in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]:
		var e: Variant = ViewKit.json("res://data/episodes/%s.json" % ep)
		if not (e is Dictionary):
			continue
		for l in (e as Dictionary).get("script", []):
			var pid := ViewKit.s((l as Dictionary).get("prank", ""))
			if pid == "":
				continue
			var rd: Dictionary = (pranks.get(pid, {}) as Dictionary).get("reaction", {})
			var arch := ViewKit.s(rd.get("archetype", ""))
			var vs: Array = rd.get("variants", [])
			var clip := ViewSnapshot.reaction_clip(null, arch, ViewKit.s(vs[0]) if not vs.is_empty() else "")
			assert_has(d, clip, "%s: %s's reaction" % [ep, pid])
	assert_has(d, "bellows/rx_sneeze_blast_a", "the sneeze")
	assert_has(d, "bellows/rx_drench_a_ko", "HOT & COLD's knock-on entry")
	assert_eq(int(d["bellows/st_bump"]["expect_f"]), 82, "st_bump = the sim's first bump")
	assert_true(bool(d["bellows/st_straighten_cravat"]["loop_ok"]), "the cravat straighten loops")
	assert_has(d, "hush/act_climb_in")
	assert_has(d, "bellows/cue_picture_bonk", "the Prologue's picture bonk")
	assert_false(d.has("bellows/combo_poodle"), "N01/N02 forbid combos (L4)")
	assert_has(d, "bellows/lec_a")
	assert_has(SliceClips.build("pip").map(func(r: Dictionary) -> String: return r["clip"]), "hush/lec_swept", "Pip")
	_dump(rows)


func _dump(rows: Array[Dictionary]) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/review/s2-view")
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slice_clips.md"), FileAccess.WRITE)
	if f != null:
		f.store_string(SliceClips.to_markdown(rows))
		f.close()
