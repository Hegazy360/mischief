## The 3D animation lint (game/tools/anim/lint3d_rules.gd): every rule proven on a fixture clip that breaks it, and
## clean fixtures that pass. Fixtures: game/tests/anim3d/fixtures/ (sidecars + baked .res on the fixture skeleton
## rig/hush_skel.glb), made by `tools/art3d/anim/bake.sh` from the specs in tools/art3d/anim/lib/fixtures/ (r3d-anim).
extends TestBase

const L := preload("res://tools/anim/lint3d_rules.gd")
const FX := "res://tests/anim3d/fixtures/"
const RIG := FX + "rig/hush_skel.glb"


func before_each() -> void:
	L.reset_caches()
	L.expect_override = []
	L.audio_override = {}
	L.reactions_override = null
	L.rig_actions_override = null


func after_each() -> void:
	L.expect_override = null
	L.audio_override = null
	L.reactions_override = null
	L.rig_actions_override = null
	L.reset_caches()


func _lint(name: String) -> Array:
	return L.lint_paths(FX + "sidecars/%s.json" % name, "", RIG)


func _rules(findings: Array, severity: String = "error") -> PackedStringArray:
	var out := PackedStringArray()
	for f in findings:
		if String(f["severity"]) == severity and not out.has(String(f["rule"])):
			out.append(String(f["rule"]))
	return out


func _dump(findings: Array) -> String:
	var lines := PackedStringArray()
	for f in findings:
		if String(f["severity"]) != "info":
			lines.append(L.format(f))
	return "\n".join(lines)


func _expect_only(name: String, rule: String) -> void:
	var fs := _lint(name)
	var errs := _rules(fs)
	assert_has(errs, rule, "%s must fail %s:\n%s" % [name, rule, _dump(fs)])


func _expect_clean(name: String) -> void:
	var fs := L.make_strict(_lint(name))
	assert_eq(L.error_count(fs), 0, "%s must pass --strict:\n%s" % [name, _dump(fs)])


func test_fixture_skeleton_loads() -> void:
	var rig := L.rig_skeleton(RIG)
	assert_true(bool(rig.get("ok", false)), str(rig.get("error", "")))
	assert_true((rig["index"] as Dictionary).has("foot_l"))
	assert_eq((rig["soles"] as Dictionary).size(), 2, "heel / ball / toe points for both feet")


func test_clean_take_passes() -> void:
	_expect_clean("fx_clean")


func test_clean_walk_at_2ms_passes() -> void:
	_expect_clean("fx_walk_ok")
	var d: Variant = TestBase.load_json(FX + "sidecars/fx_walk_ok.json")
	assert_almost_eq(float((d as Dictionary)["speed_m_s"]), 2.0, 0.001, "the in-place walk carries its speed")


func test_clean_stepped_rig_clip_passes() -> void:
	L.rig_actions_override = {"tiers": {"q": 48, "s": 90, "b": 150}, "pranks": {"fx_step_ok": {"tier": "Q"}}}
	_expect_clean("rig_fx_step_ok")


func test_accent_of_6_frames_fails() -> void:
	_expect_only("fx_accent_6f", "L05_accent_length")


func test_missing_anticipation_fails() -> void:
	_expect_only("fx_no_antic", "L07_antic_opposes")


func test_22_frame_dead_hold_fails() -> void:
	_expect_only("fx_dead_hold", "L09_dead_hold")


func test_50_deg_jump_without_pop_fails() -> void:
	_expect_only("fx_jump", "L10_pop_jump")


func test_standing_foot_sliding_fails() -> void:
	_expect_only("fx_foot_slide", "L12_feet_planted")


func test_walk_sliding_per_stance_in_lane_space_fails() -> void:
	_expect_only("fx_walk_slide", "L12_feet_planted")


func test_walk_with_slow_stance_fails() -> void:
	var fs := _lint("fx_walk_slow")
	var found := false
	for f in fs:
		if String(f["rule"]) == "L12_feet_planted" and String(f["msg"]).contains("clip space"):
			found = true
	assert_true(found, "a stance at 0.8 × speed_m_s is caught by the stance-velocity check:\n" + _dump(fs))


func test_loop_seam_of_2_deg_fails() -> void:
	_expect_only("fx_seam", "L04_loop_seam")


func test_beats_4_frames_off_reactions_fail() -> void:
	L.reactions_override = {"archetypes": {"fx_beats": {"clip": "hush/rx_fx_beats", "frames": 90,
		"marks": {"antic": 14, "accent": 28, "hold": [31, 70], "release": 90}}}, "tiers": {"hold_scale_pct": [100, 120, 150]}}
	_expect_only("rx_fx_beats", "L19_beats_match")


func test_beats_on_reactions_pass() -> void:
	L.reactions_override = {"archetypes": {"fx_beats": {"clip": "hush/rx_fx_beats", "frames": 90,
		"marks": {"antic": 10, "accent": 24, "hold": [27, 70], "release": 90}}}, "tiers": {"hold_scale_pct": [100, 120, 150]}}
	assert_false(_rules(_lint("rx_fx_beats")).has("L19_beats_match"))


func test_prank_rig_clip_at_the_wrong_tier_length_fails() -> void:
	L.rig_actions_override = {"tiers": {"q": 48, "s": 90, "b": 150}, "pranks": {"fx_tier": {"tier": "Q"}}}
	_expect_only("rig_fx_tier", "L28_rig_clip")


func test_rig_clip_not_rig_pm_fails() -> void:
	_expect_only("rig_fx_lock", "L28_rig_clip")


func test_band_clip_with_a_glance_mark_fails() -> void:
	_expect_only("rig_mid", "L28_rig_clip")


func test_stepped_clip_ending_in_the_air_fails() -> void:
	_expect_only("rig_fx_step_air", "L28_rig_clip")


func test_draft_clip_still_fails_timing() -> void:
	var d: Variant = TestBase.load_json(FX + "sidecars/fx_draft.json")
	assert_true(bool(((d as Dictionary)["lint"] as Dictionary)["draft"]), "the fixture is a draft")
	_expect_only("fx_draft", "L05_accent_length")


func test_sound_frames_must_match_the_audio_table() -> void:
	var d: Dictionary = TestBase.load_json(FX + "sidecars/fx_clean.json")
	d["source"] = {"kind": "custom", "audio": "table"}
	d["events"] = [{"f": 24, "type": "sfx", "id": "whoosh"}]
	L.audio_override = {"hush/fx_clean": {"len_f": 60, "events": [{"f": 25, "type": "sfx", "id": "whoosh"}]}}
	var anim := load(String(d["anim"])) as Animation
	var fs := L.lint_data(d, anim, L.rig_skeleton(RIG), "fx_clean(table)")
	assert_has(_rules(fs), "L24_sound_table", _dump(fs))
	L.audio_override = {"hush/fx_clean": {"len_f": 60, "events": [{"f": 24, "type": "sfx", "id": "whoosh"}]}}
	fs = L.lint_data(d, anim, L.rig_skeleton(RIG), "fx_clean(table)")
	assert_false(_rules(fs).has("L24_sound_table"), _dump(fs))


func test_unknown_sound_and_face_ids_fail() -> void:
	var d: Dictionary = TestBase.load_json(FX + "sidecars/fx_clean.json")
	d["events"] = [{"f": 24, "type": "sfx", "id": "no_such_sound_xyz"}, {"f": 10, "type": "teleport"}]
	d["face"] = [{"f": 0, "preset": "no_such_face_xyz"}, {"f": 24, "preset": "shock"}]
	var anim := load(String(d["anim"])) as Animation
	var fs := L.lint_data(d, anim, L.rig_skeleton(RIG), "fx_clean(ids)")
	var msgs := _dump(fs)
	assert_true(msgs.contains("no_such_sound_xyz"), msgs)
	assert_true(msgs.contains("teleport"), msgs)
	if not L._face_presets("hush").is_empty():
		assert_true(msgs.contains("no_such_face_xyz"), msgs)


func test_expected_length_from_the_manifest() -> void:
	L.expect_override = [{"clip": "hush/fx_clean", "expect_f": 48, "tol_f": 2, "loop_ok": false, "why": "test row"}]
	assert_has(_rules(_lint("fx_clean")), "L25_expected_length")
	L.expect_override = [{"clip": "hush/fx_clean", "expect_f": 60, "tol_f": 0, "loop_ok": false, "why": "test row"}]
	assert_false(_rules(_lint("fx_clean")).has("L25_expected_length"))


func test_cheat_limits() -> void:
	var d: Dictionary = TestBase.load_json(FX + "sidecars/rig_fx_lock.json")
	d["cheat_deg"] = 30
	var anim := load(String(d["anim"])) as Animation
	var fs := L.lint_data(d, anim, L.rig_skeleton(RIG), "rig(cheat)")
	assert_has(_rules(fs), "L26_cheat", "rig clips reach at cheat ≤ 10")


func test_strict_turns_warnings_into_errors() -> void:
	var fs := _lint("rig_mid")
	var before := L.error_count(fs)
	L.make_strict(fs)
	assert_gt(L.error_count(fs), before, "the L22 glance-mark warning counts under --strict")
