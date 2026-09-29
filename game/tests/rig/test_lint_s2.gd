## Stage-2 animation lint rules A23–A29 (s2-rig §4.1.3): each is caught on a seeded bad
## fixture in tests/rig/fixtures/s2/, the matching good cases pass, and `--strict` turns
## warnings into errors.
extends TestBase

const FIX := "res://tests/rig/fixtures/s2"


func after_each() -> void:
	AnimLint.expect_override = null
	AnimLint.maps_override = null
	AnimLint.decor_override = null
	AnimLint.reset_caches()
	for id in ["_mannequin/bit_test", "_mannequin/mg_test", "_mannequin/st_bump_test", "_mannequin/st_look_test", "_mannequin/mg_nomask"]:
		ClipLib.invalidate(id)


static func _rules(findings: Array, severity: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for f in findings:
		if severity != "" and String(f["severity"]) != severity:
			continue
		if not out.has(String(f["rule"])):
			out.append(String(f["rule"]))
	return out


func _lint_file(name: String) -> Array:
	return AnimLint.lint_clip(ClipLib.load_file("%s/%s" % [FIX, name]))


func _manifest() -> Array:
	var d: Variant = load_json(FIX + "/manifest_a29.json")
	return (d as Dictionary)["rows"] if d is Dictionary else []


func test_a23_overlay_needs_a_mask_and_a_real_blend() -> void:
	var found := _lint_file("bad_a23_overlay.json")
	assert_has(_rules(found, "error"), "A23_overlay", "no mask + 2 f blend in")
	var n := 0
	for f in found:
		if String(f["rule"]) == "A23_overlay" and String(f["severity"]) == "error":
			n += 1
	assert_eq(n, 2, "two errors: the missing mask and the 2 f blend")
	# A rig mask the rig lacks → warning (falls back to the keyed parts); locomotion parts → warning.
	var base := {"version": 1, "rig": "_mannequin", "length": 30, "layer": "overlay", "blend_in": 6, "blend_out": 6,
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": 30, "pose": "m_notice", "ease": "in_out_sine"}]}
	var d1 := base.duplicate(true)
	d1["mask"] = "no_such_mask"
	var w1 := AnimLint.lint_clip(ClipLib.from_dict(d1, "_mannequin/mg_a"))
	assert_has(_rules(w1, "warning"), "A23_overlay", "unknown rig mask warns")
	assert_false(_rules(w1, "error").has("A23_overlay"))
	var d2 := base.duplicate(true)
	d2["mask"] = ["hips", "head*"]
	var w2 := AnimLint.lint_clip(ClipLib.from_dict(d2, "_mannequin/mg_b"))
	assert_has(_rules(w2, "warning"), "A23_overlay", "locomotion parts in the mask warn")
	var d3 := base.duplicate(true)
	d3["mask"] = "upper"
	assert_false(_rules(AnimLint.lint_clip(ClipLib.from_dict(d3, "_mannequin/mg_c"))).has("A23_overlay"), "a clean overlay")
	var d4 := base.duplicate(true)
	d4["layer"] = "base"
	assert_has(_rules(AnimLint.lint_clip(ClipLib.from_dict(d4, "_mannequin/mg_d")), "warning"), "A23_overlay", "an mg_ clip on the base layer warns")


func test_a24_a25_bit_and_micro_gag_lengths() -> void:
	AnimLint.expect_override = _manifest()
	assert_has(_rules(_lint_file("bad_a24_bit.json")), "A24_bit_length", "80 f vs 90 ± 2")
	assert_has(_rules(_lint_file("bad_a25_mg.json")), "A25_mg_length", "100 f vs 60 ± 12")
	# Within tolerance passes.
	AnimLint.expect_override = [{"clip": "_mannequin/bit_test", "expect_f": 81, "tol_f": 2}, {"clip": "_mannequin/mg_test", "expect_f": 90, "tol_f": 12}]
	assert_false(_rules(_lint_file("bad_a24_bit.json")).has("A24_bit_length"))
	assert_false(_rules(_lint_file("bad_a25_mg.json")).has("A25_mg_length"))


func test_a24_a25_fall_back_to_activities_json() -> void:
	AnimLint.reset_caches()
	var src := AnimLint.expectations_source()
	assert_true(src == "SliceClips" or src == "activities.json", "a real source (%s)" % src)
	var ex := AnimLint.expectations()
	if src == "activities.json":
		assert_true(ex.has("bellows/bit_warmup"), "squeak bits become rows")
		var row: Dictionary = (ex["bellows/bit_warmup"] as Array)[0]
		assert_eq(int(row["tol_f"]), AnimLint.BIT_TOL)


func test_a26_cold_opens_may_run_long_but_not_forever() -> void:
	assert_has(_rules(_lint_file("bad_a26_cold.json")), "A26_cold_curtain", "450 f cold open")
	# A 300 f curtain-call clip with a 40 f still hold is fine (A09 relaxed to 90 f).
	var keys: Array = [{"f": 0, "pose": "m_stand"}, {"f": 60, "pose": "m_notice", "ease": "in_out_sine"},
		{"f": 100, "pose": "m_notice", "ease": "hold"}, {"f": 160, "pose": "m_stand_b", "ease": "in_out_sine"},
		{"f": 230, "pose": "m_idle_look", "ease": "in_out_sine"}, {"f": 300, "pose": "m_stand", "ease": "in_out_sine"}]
	var ok := ClipLib.from_dict({"version": 1, "rig": "_mannequin", "length": 300, "tags": ["curtain"], "keys": keys}, "_mannequin/cc_test")
	var rules := _rules(AnimLint.lint_clip(ok))
	assert_false(rules.has("A26_cold_curtain"), "300 f is allowed")
	assert_false(rules.has("A09_dead_hold"), "a 40 f hold is allowed in a curtain call")
	var plain := ClipLib.from_dict({"version": 1, "rig": "_mannequin", "length": 300, "keys": keys}, "_mannequin/act_test")
	assert_has(_rules(AnimLint.lint_clip(plain)), "A09_dead_hold", "but not in an ordinary clip")


func test_a27_walk_speed_against_the_map() -> void:
	var walk := ClipLib.get_clip("_mannequin/loco_walk")
	var natural := walk.stride_px / (float(walk.length) / 60.0)
	var fixture: Variant = load_json(FIX + "/map_a27.json")
	AnimLint.maps_override = {"_mannequin": fixture}
	var found := AnimLint.lint_clip(walk)
	assert_has(_rules(found), "A27_walk_speed", "270 px/s on a %.0f px/s walk slides" % natural)
	var stride_msg := false
	for f in found:
		if String(f["rule"]) == "A27_walk_speed" and String(f["msg"]).contains("stride_px 120"):
			stride_msg = true
	assert_true(stride_msg, "the skin:pip entry's wrong stride_px is reported")
	AnimLint.maps_override = {"_mannequin": {"walk": {"clip": "loco_walk", "stride_px": walk.stride_px, "speed_px_s": natural}}}
	assert_false(_rules(AnimLint.lint_clip(walk)).has("A27_walk_speed"), "at its natural speed the feet stay planted")


func test_a28_decor_events_name_house_decor() -> void:
	AnimLint.decor_override = {"kitchen_stool": true}
	var found := _lint_file("bad_a28_decor.json")
	var msgs := PackedStringArray()
	for f in found:
		if String(f["rule"]) == "A28_decor":
			msgs.append(String(f["msg"]))
	assert_eq(msgs.size(), 2, "unknown id + missing visible (%s)" % [msgs])
	var ok := ClipLib.from_dict({"version": 1, "rig": "_mannequin", "length": 20, "keys": [{"f": 0, "pose": "m_stand"}, {"f": 20, "pose": "m_notice", "ease": "in_out_sine"}],
		"events": [{"f": 0, "type": "decor", "id": "kitchen_stool", "visible": false}, {"f": 20, "type": "decor", "id": "kitchen_stool", "visible": true}]}, "_mannequin/decor_ok")
	assert_false(_rules(AnimLint.lint_clip(ok)).has("A28_decor"))
	assert_eq(ok.errors, PackedStringArray(), "decor is a known event type")
	# The real house.json lists the stool (s2-art's Gate-0 kitchen).
	AnimLint.decor_override = null
	AnimLint.reset_caches()
	if FileAccess.file_exists(AnimLint.HOUSE):
		assert_true(AnimLint.decor_ids().has("kitchen_stool"), "house.json decor ids are read")


func test_a29_sim_lengths_from_the_manifest() -> void:
	var rows := _manifest()
	ClipLib.register_file(FIX + "/bad_a29_bump.json")
	ClipLib.register_file(FIX + "/good_a29_look.json")
	ClipLib.register_file(FIX + "/bad_a24_bit.json")
	ClipLib.register_file(FIX + "/bad_a25_mg.json")
	var found := AnimLint.lint_manifest(rows)
	var by := {}
	for f in found:
		by[String(f["rule"])] = int(by.get(String(f["rule"]), 0)) + 1
		assert_false(String(f["msg"]).contains("not_authored_yet"), "missing clips are the coverage lint's job")
	assert_eq(int(by.get("A29_sim_length", 0)), 1, "the 72 f bump against the 82-tick sim row (%s)" % [found])
	assert_eq(int(by.get("A24_bit_length", 0)), 1)
	assert_eq(int(by.get("A25_mg_length", 0)), 1)
	# The looping st_look on a loop_ok row passes; the same loop on a row without loop_ok fails.
	var strict_rows: Array = [{"clip": "_mannequin/st_look_test", "expect_f": 180, "tol_f": 0, "loop_ok": false, "why": "sim"}]
	assert_has(_rules(AnimLint.lint_manifest(strict_rows)), "A29_sim_length")
	# lint_clip applies the same rows.
	AnimLint.expect_override = rows
	assert_has(_rules(AnimLint.lint_clip(ClipLib.get_clip("_mannequin/st_bump_test"))), "A29_sim_length")
	assert_false(_rules(AnimLint.lint_clip(ClipLib.get_clip("_mannequin/st_look_test"))).has("A29_sim_length"))


func test_strict_turns_warnings_into_errors() -> void:
	var d := {"version": 1, "rig": "_mannequin", "length": 30, "layer": "overlay", "mask": "no_such_mask",
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": 30, "pose": "m_notice", "ease": "in_out_sine"}]}
	var found := AnimLint.lint_clip(ClipLib.from_dict(d, "_mannequin/mg_strict"))
	var warn := found.size() - AnimLint.error_count(found)
	assert_gt(warn, 0, "has warnings")
	var errs0 := AnimLint.error_count(found)
	AnimLint.make_strict(found)
	assert_eq(AnimLint.error_count(found), errs0 + warn, "every warning is an error under --strict")


func test_lint_skips_folders_that_are_not_rigs() -> void:
	for r in ClipLib.rigs_with_clips():
		assert_true(FileAccess.file_exists("res://data/rigs/%s/rig.json" % r), "%s is a rig" % r)
		for cid in ClipLib.list(r):
			assert_false(cid.ends_with("/tiers") or cid.ends_with("/map") or cid.ends_with("/reactions"), "%s is a clip" % cid)
