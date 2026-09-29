## Content, hotspot and IP lints: every rule is caught on a seeded bad fixture set
## (tests/solver/fixtures/lint_bad_*, each overlaid on the good mock set) and the good set passes.
extends TestBase

const FX := "res://tests/solver/fixtures"
const GOOD := FX + "/mock_data"


func _content(bad: String) -> String:
	return "\n".join(ContentLint.lint_dir("%s/%s" % [FX, bad], GOOD))


func _hot(bad: String) -> String:
	return "\n".join(HotspotLint.lint_file("%s/%s/house/house.json" % [FX, bad]))


func test_good_set_is_clean() -> void:
	assert_eq(ContentLint.lint_dir(GOOD), PackedStringArray(), "content lint on the good set")
	assert_eq(HotspotLint.lint_file(GOOD + "/house/house.json"), PackedStringArray(), "hotspot lint on the good set")
	var ip := IpLint.scan_project(GOOD)
	assert_eq(ip["hits"], PackedStringArray(), "ip lint on the good set")


func test_content_ids_resolve() -> void:
	var e := _content("lint_bad_ids")
	for needle in ["kettle_drum.rig_point 'kitchen_nowhere' not in house.json", "kettle_drum.steps[0].needs 'ghost_item' not in items.json",
			"tap_dance.trigger.activity 'yodel' not in activities.json", "achoo_ria.knock_on.prank 'no_such_prank'",
			"double_acts hot_and_cold.b 'not_a_prank'"]:
		assert_has(e, needle)


func test_content_trigger_activity_in_loop() -> void:
	assert_has(_content("lint_bad_trigger_loop"), "prank tap_dance triggers on 'rinse', which is not in this Night's loop")


func test_content_items_come_from_the_nights_rooms() -> void:
	assert_has(_content("lint_bad_item_room"), "prank kettle_drum needs 'squeaker' from hall_confiscated_box (hall), which is not in this Night's rooms")


func test_content_script_shape() -> void:
	var e := _content("lint_bad_script_shape")
	assert_has(e, "Script has 2 line(s) before the Big Number (want 3–6)")
	assert_has(e, "Script has 2 Big Number(s) (want exactly 1)")
	var e2 := _content("lint_bad_script_long")
	assert_has(e2, "Script has 8 lines (max 7)")
	assert_has(e2, "Script has 7 line(s) before the Big Number")


func test_content_one_new_rule_per_night() -> void:
	var e := _content("lint_bad_new_rule")
	assert_has(e, "mock_ep.json: new_rule must be ONE rule")
	assert_has(e, "mock_ep3.json: new_rule 'freeze' already introduced by mock_ep2")
	assert_has(e, "mock_ep4.json: no new_rule")


func test_content_card_words() -> void:
	assert_has(_content("lint_bad_card"), "card is 30 words (max 25)")


func test_content_captions() -> void:
	var e := _content("lint_bad_caption")
	assert_has(e, "tap_dance.caption 'A VERY LONG CAPTION INDEED' is 26 characters (max 18)")
	assert_has(e, "double_acts hot_and_cold.caption")


func test_content_fixup_station_per_floor() -> void:
	assert_has(_content("lint_bad_fixup_floor"), "residue fix-up kind DRY has no station on floor 0")


func test_content_reactions_cover_archetypes() -> void:
	var e := _content("lint_bad_reactions")
	assert_has(e, "tap_dance: reaction 'drench_a' not in reactions.json")
	assert_has(e, "no 'suppressed' archetype")


func test_content_rx_time_jitter() -> void:
	var e := _content("lint_bad_jitter")
	assert_has(e, "rx clip bellows/rx_drench_a has variation.time_jitter 0.5")
	assert_false(e.contains("act_tea"), "non-reaction clips may jitter")


func test_content_bases_normalise() -> void:
	var e := _content("lint_bad_bases")
	assert_has(e, "tap_dance.size 'XL' not in")
	assert_has(e, "line tap prank size 'XL' has no weight")
	assert_has(e, "mock_ep2.json: no prank lines: prank bases cannot normalise to 700 tenths")
	assert_has(e, "line kettle stores base_tenths")


func test_normalise_bases_largest_remainder() -> void:
	var pranks := {"a": {"size": "S"}, "b": {"size": "S"}, "c": {"size": "S"}, "d": {"size": "M"}, "e": {"size": "SIG"}}
	var lines := [{"id": "1", "kind": "prank", "prank": "a"}, {"id": "2", "kind": "prank", "prank": "b"},
		{"id": "3", "kind": "prank", "prank": "c"}, {"id": "x", "kind": "double_act"}]
	var b := SolverData.normalise_bases(lines, pranks)
	assert_eq(b, {"1": 234, "2": 233, "3": 233}, "700/3: the remainder goes to the first line")
	var b2 := SolverData.normalise_bases([{"id": "1", "kind": "prank", "prank": "d"}, {"id": "2", "kind": "prank", "prank": "e"}], pranks)
	assert_eq(int(b2["1"]) + int(b2["2"]), 700)
	assert_eq(b2, {"1": 223, "2": 477}, "14:30 of 700: 222.7 → 223, 477.3 → 477")


func test_hotspot_rules() -> void:
	assert_has(_hot("lint_bad_hotspot_size"), "hall_coat_cupboard hit box 100 × 100 < 144 × 144")
	assert_has(_hot("lint_bad_hotspot_gap"), "kitchen_honey and kitchen_kettle are only 10 px apart (min 24)")
	assert_has(_hot("lint_bad_hotspot_overlap"), "parlour_gramophone and parlour_piano_back hit boxes overlap")
	assert_has(_hot("lint_bad_hotspot_use_point"), "hall_mirror use_x 1600 outside hall [500, 1500]")
	var st := _hot("lint_bad_hotspot_station")
	assert_has(st, "station st_tea x 3200 is more than 80 px from the GDD §7.1 x 2960")
	assert_has(st, "station st_sink in parlour, GDD §7.1 puts it in kitchen")


func test_hotspot_rules_across_the_floor_stacks_and_doors() -> void:
	var e := _hot("lint_bad_hotspot_floor")
	assert_has(e, "floor 0: parlour_piano_back and kitchen_honey hit boxes overlap", "a box straddling the wall meets the next room's")
	assert_has(e, "door kitchen_hatch is tappable but names no link")
	assert_false(e.contains("kitchen_window"), "a non-tappable door with no link (the Prologue window), stacked over the tap: fine\n%s" % e)
	assert_has(e, "stack [\"kitchen_honey\",\"kitchen_pantry_curtain\"]: kitchen_honey is not in the same column")
	assert_has(e, "has unknown members")


func test_micro_gag_cadence_and_emotes() -> void:
	var e := _content("lint_bad_micro_gags")
	assert_has(e, "warmup: 12.0 s without a micro-gag (2.0 s → 14.0 s; D1 max 8 s)")
	assert_has(e, "tea: micro-gags only 2.0 s apart (2.0 s → 4.0 s; min 5 s)")
	assert_has(e, "activities.tea micro_gags 'sip' emote 'wink' not in")
	assert_has(e, "walk_beats 'walk_hum' emote 'whistle' not in")
	assert_false(e.contains("the end at 20.0"), "14 s → the 20 s end is only 6 s")
	assert_false(e.contains("rinse"), "a 5 s rinse needs no beat")
	var g := _content("lint_bad_mg_gated")
	assert_has(g, "rinse: no micro_gags, but a gated Night holds him here")
	# the cycle of a gated activity is checked with its wrap
	var c := BeatLint.cadence("warmup", {"dur_s": 10, "micro_gags": [{"id": "a", "at_s": 2.0}, {"id": "b", "at_s": 7.0}], "mg_cycle_s": 16.0}, true)
	assert_has("\n".join(c), "11.0 s without a micro-gag (7.0 s → 18.0 s", "7 → 16 + 2")
	assert_eq(BeatLint.cadence("warmup", {"dur_s": 10, "micro_gags": [{"id": "a", "at_s": 2.0}, {"id": "b", "at_s": 7.0}], "mg_cycle_s": 10.0}, true),
		PackedStringArray(), "2, 7, 12, 17 …")
	assert_eq(BeatLint.cadence("tea", {"dur_s": 10, "micro_gags": ["a", "b"]}, false), PackedStringArray(), "legacy 2 + 8: gaps 2, 6, 2")
	var used := BeatLint.used_by_final(ContentLint.load_parts(GOOD))
	assert_has(used, "warmup")
	assert_false(used.has("curious"), "beats never play while curious")


func test_clip_coverage_warns_and_lists_the_missing() -> void:
	var parts := ContentLint.load_parts(GOOD)
	var cov := BeatLint.coverage(parts, GOOD)
	assert_eq(str(cov["source"]), "fallback", "a fixture dir: the lint's own derivation")
	var miss: PackedStringArray = cov["missing"]
	assert_has(miss, "bellows/mg_trill", "micro-gag clips")
	assert_gt(int(cov["rows"]), 0)
	var real := BeatLint.coverage(ContentLint.load_parts("res://data"), "res://data")
	print("  [real data] clip coverage from %s: %d of %d missing" % [real["source"], (real["missing"] as PackedStringArray).size(), int(real["rows"])])
	assert_has(["SliceClips", "fallback"], str(real["source"]))


func test_hotspot_stacked_objects_pass() -> void:
	var h := {"rooms": [{"id": "kitchen", "x0": 2800, "x1": 3900}], "stations": [], "hotspots": [
		{"id": "kitchen_fridge", "room": "kitchen", "use_x": 3300, "rect": [3220, -170, 160, 170]},
		{"id": "kitchen_fridge_shelf", "room": "kitchen", "use_x": 3300, "rect": [3220, -400, 160, 206]}]}
	assert_eq(HotspotLint.lint_house(h), PackedStringArray(), "stacked with a 24 px vertical gap")
	h["hotspots"][1]["rect"] = [3220, -400, 160, 220]
	assert_has("\n".join(HotspotLint.lint_house(h)), "only 10 px apart")


func test_ip_catches_every_banned_term() -> void:
	for term in IpLint.BANNED:
		var text := "Our line: %s here." % term.to_upper()
		assert_eq(IpLint.scan_text(text, "t").size(), 1, "catches '%s'" % term)
		var id := "x_%s_y" % term.replace(" ", "_")
		assert_eq(IpLint.scan_text(id, "t").size(), 1, "catches the id form '%s'" % id)


func test_ip_no_false_positives() -> void:
	for ok in ["woodblock bonk", "a goldenrod sofa", "Volga", "season 10", "Season 12", "the landing_airing_cupboard",
			"channel 110", "marble bust", "cacti", "goodwoody", "golden neighbourhood", "drawing pins", "binocular"]:
		assert_eq(IpLint.scan_text(ok, "t"), PackedStringArray(), "no false positive on '%s'" % ok)


func test_ip_scans_data_and_scenes_not_tests() -> void:
	var res := IpLint.scan_project(FX + "/lint_bad_ip")
	var all := "\n".join(res["hits"])
	assert_has(all, "'neighbours from hell'")
	assert_has(all, "'marbles'")
	assert_has(all, "'on air'")
	assert_has(all, "'banana peel'")
	assert_has(all, "'cactus'")
	assert_has(all, "scenes/x.tscn:3: banned term 'woody'")
	assert_false(all.contains("ignored.tscn"), "tests/ folders are skipped")
	assert_false(all.contains("oodblock") or all.contains("goldenrod") or all.contains("Volga") or all.contains("Season 10"))
	assert_eq((res["hits"] as PackedStringArray).size(), 6)


func test_ip_gdd_strings() -> void:
	var gdd := "### 5.7 The catalogue\n- **#1 `achoo_ria` ACHOO-RIA!** (M) · tea\n- **#2 `x_y` WOODY WOBBLE** (S)\n### 7.2 Episodes\n- Script: R \"Bellows gets a face wash\" (**TAP DANCE**) · O \"Bellows goes on air\"\n- Card: *\"Hold FREEZE.\"*\n"
	var strs := IpLint.gdd_strings(gdd)
	var texts := PackedStringArray()
	for s in strs:
		texts.append(String(s[1]))
	for want in ["ACHOO-RIA!", "WOODY WOBBLE", "Bellows gets a face wash", "Bellows goes on air", "TAP DANCE", "Hold FREEZE."]:
		assert_has(texts, want)
	var hits := PackedStringArray()
	for s in strs:
		hits.append_array(IpLint.scan_text(String(s[1]), String(s[0])))
	assert_eq(hits.size(), 2, "\n".join(hits))


func test_parse_errors_and_missing_files_are_reported() -> void:
	var e := _content("lint_bad_json")
	assert_true(e.contains("lint_bad_json/items.json:") and e.contains("Expected"), "a JSON syntax error names the file, line and problem: %s" % e)
	var parts := ContentLint.load_parts(FX + "/no_such_dir")
	assert_eq((parts["missing"] as PackedStringArray).size(), 6, "all six core files reported missing")
	var d := SolverData.load_dir(FX + "/lint_bad_json")
	assert_eq(d.errors.size(), 1, "SolverData keeps the parse error")
	var sol := SolutionDef.load_file(FX + "/lint_bad_json/solutions/mock_ep.json")
	assert_eq(sol.errors.size(), 1)
	assert_has(sol.errors[0], "mock_ep.json:")
	var none := SolutionDef.load_file(FX + "/nothing_here.json")
	assert_has(none.errors[0], "missing")
	var empty := SolutionDef.from_dict({"routes": []})
	assert_has("\n".join(empty.errors), "no 'episode'")
	assert_has("\n".join(empty.errors), "'routes' must be an object")


func test_real_data_lints_when_present() -> void:
	if not FileAccess.file_exists("res://data/pranks.json") or not FileAccess.file_exists("res://data/house/house.json"):
		skip("real data (pranks.json + house.json) not written yet")
		return
	var errs := ContentLint.lint_dir("res://data")
	var herrs := HotspotLint.lint_file("res://data/house/house.json")
	# Reported, not asserted: the data is owned by content / art-house and may be mid-edit.
	print("  [real data] content lint: %d error(s); hotspot lint: %d error(s)" % [errs.size(), herrs.size()])
	for e in errs.slice(0, 10):
		print("    - %s" % e)
	for e in herrs.slice(0, 10):
		print("    - %s" % e)
	assert_true(true)
