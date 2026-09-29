## ContentDB: fixtures load clean; every seeded bad file yields the precise error; derived data.
extends TestBase


func _errs(patch: Callable) -> PackedStringArray:
	var files := SimTestUtil.raw()
	patch.call(files)
	return ContentDB.load_dicts(files).errors


func _has_err(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if e.contains(needle):
			return true
	return false


func test_fixtures_load_with_zero_errors() -> void:
	var db := SimTestUtil.db()
	assert_eq(db.errors, PackedStringArray())
	assert_eq(db.episodes.size(), 3)
	assert_eq(db.prank_list.size(), 14)
	assert_eq(db.item_list.size(), 6)
	assert_eq(db.house.rooms.size(), 5)


func test_fixture_warnings_report_stage3_content() -> void:
	var w := SimTestUtil.db().warnings
	assert_true(_has_err(w, "fan_mail.trigger third_party"), str(w))
	assert_true(_has_err(w, "something_fishy.knock_on headbutt"), str(w))
	assert_true(_has_err(w, "fan_mail.steps[0].conditions 'beryl_within'"), str(w))


func test_stage3_line_kind_is_a_warning_not_an_error() -> void:
	var files := SimTestUtil.raw()
	(files["episodes"]["fx_act1"]["script"] as Array).append({"id": "panto", "kind": "panto", "req": false, "text": "x"})
	var db := ContentDB.load_dicts(files)
	assert_eq(db.errors, PackedStringArray())
	assert_true(_has_err(db.warnings, "line panto kind 'panto' is a Stage-3 line kind"), str(db.warnings))


func test_bad_rig_point() -> void:
	var e := _errs(func(f: Dictionary) -> void: f["pranks"]["pranks"]["achoo_ria"]["rig_point"] = "kitchen_honeyx")
	assert_true(_has_err(e, "pranks.json: achoo_ria.rig_point 'kitchen_honeyx' not in house.json"), str(e))


func test_bad_item_source_and_prank() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		f["items"]["items"]["squeaker"]["source"] = "hall_nowhere"
		f["items"]["items"]["kipper"]["pranks"] = ["no_such_prank"])
	assert_true(_has_err(e, "items.json: squeaker.source 'hall_nowhere' not in house.json"), str(e))
	assert_true(_has_err(e, "items.json: kipper.pranks 'no_such_prank' not in pranks.json"), str(e))


func test_item_source_must_be_a_container() -> void:
	var e := _errs(func(f: Dictionary) -> void: f["items"]["items"]["flour"]["source"] = "kitchen_table")
	assert_true(_has_err(e, "items.json: flour.source 'kitchen_table' is not a container"), str(e))


func test_bad_activity_station_and_bit() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		f["activities"]["activities"]["tea"]["station"] = "st_nope"
		f["activities"]["activities"]["paper"]["squeak_bit"] = "bit_nope"
		f["activities"]["activities"]["pickles"]["awareness"] = "sleepy")
	assert_true(_has_err(e, "activities.json: tea.station 'st_nope' not in house.json"), str(e))
	assert_true(_has_err(e, "activities.json: paper.squeak_bit 'bit_nope' not in squeak_bits"), str(e))
	assert_true(_has_err(e, "activities.json: pickles.awareness 'sleepy'"), str(e))


func test_bad_trigger_and_steps() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		var p: Dictionary = f["pranks"]["pranks"]
		p["tap_dance"]["trigger"]["activity"] = "rinsex"
		p["kettle_drum"]["steps"][0]["needs"] = "whistle"
		p["in_a_pickle"]["steps"][0]["prep"] = "X"
		p["lift_off"]["steps"][1]["at"] = "parlour_nowhere"
		p["rug_burn"]["trigger"]["at"] = "stairs_nowhere"
		p["prima_ballerina"]["trigger"]["room"] = "attic"
		p["cold_open"]["trigger"]["type"] = "telepathy")
	assert_true(_has_err(e, "pranks.json: tap_dance.trigger.activity 'rinsex' not in activities.json"), str(e))
	assert_true(_has_err(e, "pranks.json: kettle_drum.steps[0].needs 'whistle' not in items.json"), str(e))
	assert_true(_has_err(e, "pranks.json: in_a_pickle.steps[0].prep 'X' not Q|S|B"), str(e))
	assert_true(_has_err(e, "pranks.json: lift_off.steps[1].at 'parlour_nowhere' not in house.json"), str(e))
	assert_true(_has_err(e, "pranks.json: rug_burn.trigger.at 'stairs_nowhere' not in house.json"), str(e))
	assert_true(_has_err(e, "pranks.json: prima_ballerina.trigger.room 'attic' not a room in house.json"), str(e))
	assert_true(_has_err(e, "pranks.json: cold_open.trigger.type 'telepathy'"), str(e))


func test_bad_reaction_residue_knock_on_conditions() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		var p: Dictionary = f["pranks"]["pranks"]
		p["achoo_ria"]["reaction"]["variants"] = ["a", "z"]
		p["tap_dance"]["residue"] = [{"kind": "SLIMY"}]
		p["in_a_pickle"]["knock_on"]["prank"] = "nothing"
		p["rug_burn"]["conditions"] = [{"tier_min": "furious"}]
		p["prima_ballerina"]["conditions"] = [{"moon_phase": "full"}])
	assert_true(_has_err(e, "pranks.json: achoo_ria.reaction 'sneeze_blast_z' not in reactions.json"), str(e))
	assert_true(_has_err(e, "pranks.json: tap_dance.residue 'SLIMY' not in residues.json"), str(e))
	assert_true(_has_err(e, "pranks.json: in_a_pickle.knock_on.prank 'nothing' not in pranks.json"), str(e))
	assert_true(_has_err(e, "tier_min 'furious' not calm|irked|steaming|livid"), str(e))
	assert_true(_has_err(e, "pranks.json: prima_ballerina.conditions 'moon_phase' not a known condition"), str(e))


func test_bad_double_act() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		f["pranks"]["double_acts"]["hot_and_cold"]["b"] = "kettle_drum")
	assert_true(_has_err(e, "double_acts.hot_and_cold: achoo_ria.knock_on.prank must be 'kettle_drum'"), str(e))


func test_bad_house_links_and_hotspots() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		var h: Dictionary = f["house"]
		h["links"][1]["b"] = "ballroom"
		h["hotspots"][0]["kind"] = "trapdoor"
		h["stations"][0]["kinds"] = ["POLISH"])
	assert_true(_has_err(e, "house.json: link hall_parlour.b 'ballroom' not a room in house.json"), str(e))
	assert_true(_has_err(e, "house.json: hotspot hall_front_door.kind 'trapdoor'"), str(e))
	assert_true(_has_err(e, "house.json: station st_phone.kinds 'POLISH'"), str(e))


func test_bad_reactions_and_residues() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		f["reactions"]["archetypes"]["drench_a"]["marks"]["accent"] = 500
		f["residues"]["residues"]["SOAKED"]["fixup"] = "TOWEL"
		f["residues"]["combos"]["poodle"]["of"] = ["SOAKED", "PERMED"])
	assert_true(_has_err(e, "reactions.json: drench_a.marks.accent 500 outside 0..119"), str(e))
	assert_true(_has_err(e, "residues.json: SOAKED.fixup 'TOWEL' not DRY|SINK|HONEY|MIRROR"), str(e))
	assert_true(_has_err(e, "residues.json: combos.poodle.of 'PERMED' not in residues"), str(e))


func test_bad_episode() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		var ep: Dictionary = f["episodes"]["fx_act1"]
		ep["rooms"] = ["hall", "parlour", "kitchen", "cellar"]
		ep["bellows"]["loop"][2] = {"a": "juggle"}
		ep["bellows"]["loop"][0]["gate"]["until"] = "rigged:nothing"
		ep["script"][0]["prank"] = "kettle_drumm"
		ep["script"][5]["double_act"] = "hot_and_bothered"
		ep["rules"]["spot_fill_s"] = 0.5
		ep["fixup_overrides"] = {"SOAKED": "st_sink"})
	assert_true(_has_err(e, "episodes/fx_act1.json: rooms 'cellar' not a room in house.json"), str(e))
	assert_true(_has_err(e, "episodes/fx_act1.json: bellows.loop[2] 'juggle' not in activities.json"), str(e))
	assert_true(_has_err(e, "bellows.loop[0].gate.until 'rigged:nothing' not in pranks.json"), str(e))
	assert_true(_has_err(e, "episodes/fx_act1.json: line kettle.prank 'kettle_drumm' not in pranks.json"), str(e))
	assert_true(_has_err(e, "line bn.double_act 'hot_and_bothered'"), str(e))
	assert_true(_has_err(e, "rules.spot_fill_s 0.50 below 0.8"), str(e))
	assert_true(_has_err(e, "fixup_overrides.SOAKED station 'st_sink' has no kind DRY"), str(e))


func test_bad_director_condition() -> void:
	var e := _errs(func(f: Dictionary) -> void:
		f["episodes"]["fx_prologue"]["director"]["cues"][0]["when"] = {"moon_is": "full"})
	assert_true(_has_err(e, "director.cues.laugh_vase.when 'moon_is' is not a condition key"), str(e))


func test_version_must_be_1() -> void:
	var e := _errs(func(f: Dictionary) -> void: f["items"]["version"] = 2)
	assert_true(_has_err(e, "items.json: version must be 1"), str(e))


func test_missing_dir_and_corrupt_file() -> void:
	var db := ContentDB.load_dir("res://tests/sim/no_such_dir")
	assert_true(_has_err(db.errors, "house.json: missing"), str(db.errors))
	assert_true(_has_err(db.errors, "episodes/: missing directory"), str(db.errors))
	var dir := "user://sim_bad_content"
	DirAccess.make_dir_recursive_absolute(dir + "/house")
	DirAccess.make_dir_recursive_absolute(dir + "/episodes")
	var src := SimTestUtil.FIXTURES
	for rel in ["house/house.json", "pranks.json", "activities.json", "reactions.json", "residues.json",
			"episodes/fx_act1.json"]:
		var f := FileAccess.open(dir + "/" + rel, FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(src + "/" + rel))
		f.close()
	var bad := FileAccess.open(dir + "/items.json", FileAccess.WRITE)
	bad.store_string("{\"version\": 1, \"items\": {")
	bad.close()
	var db2 := ContentDB.load_dir(dir)
	assert_true(_has_err(db2.errors, "items.json: parse error line"), str(db2.errors))


func test_normalise_largest_remainder_to_700() -> void:
	var ep: EpisodeDef = SimTestUtil.db().episodes["fx_act1"]
	var bases := {}
	var sum := 0
	for l in ep.script_lines:
		bases[l.id] = l.base_tenths
		sum += l.base_tenths
	assert_eq(sum, 700)
	# weights kettle M14, tap S10, pickle L20, lift L20, achoo M14 (total 78): floors 125/89/179/179/125,
	# remainders 50/58/38/38/50 → +1 to tap, kettle, achoo (kettle before achoo by line order).
	assert_eq(bases["kettle"], 126)
	assert_eq(bases["tap"], 90)
	assert_eq(bases["pickle"], 179)
	assert_eq(bases["lift"], 179)
	assert_eq(bases["achoo"], 126)
	assert_eq(bases["bn"], 0, "goal lines carry no base")


func test_normalise_ties_by_line_order() -> void:
	var files := SimTestUtil.raw()
	files["episodes"]["fx_act1"]["script"] = [
		{"id": "a", "kind": "prank", "prank": "kettle_drum", "req": true},
		{"id": "b", "kind": "prank", "prank": "achoo_ria", "req": true},
		{"id": "c", "kind": "prank", "prank": "cold_open", "req": true}]
	var db := ContentDB.load_dicts(files)
	var ep: EpisodeDef = db.episodes["fx_act1"]
	assert_eq([ep.script_lines[0].base_tenths, ep.script_lines[1].base_tenths, ep.script_lines[2].base_tenths], [234, 233, 233])


func test_derived_hooks_sorted_by_mark_then_prank() -> void:
	var db := SimTestUtil.db()
	var tea: ActivityDef = db.activities["tea"]
	assert_eq(tea.hook_count(), 2)
	assert_eq(tea.hooks[0], 180)
	assert_eq(db.prank_list[tea.hooks[1]].id, "kettle_drum")
	assert_eq(tea.hooks[2], 420)
	assert_eq(db.prank_list[tea.hooks[3]].id, "achoo_ria")
	# fix-up hooks per station
	var st_tea: int = db.house.station_index["st_tea"]
	var ids := []
	for p in db.fixup_hooks[st_tea]:
		ids.append(db.prank_list[p].id)
	assert_eq(ids, ["achoo_ria", "kettle_drum"])


func test_derived_reaction_lengths_per_tier() -> void:
	var r: ReactionDef = SimTestUtil.db().reactions["sneeze_blast_a"]
	assert_eq(r.length(1, false), 150)
	assert_eq(r.length(2, false), 159)
	assert_eq(r.length(3, false), 172)
	assert_eq(r.length(1, true), 200, "suppressed: settle (10) replaced by 60")
	assert_eq(r.remap(92, 3), 92, "the accent is before the hold")
	assert_eq(r.remap(110, 2), 95 + 18)
	assert_eq(r.remap(150, 3), 172)


func test_station_kind_indices_sorted_by_id() -> void:
	var h := SimTestUtil.db().house
	var dry: PackedInt32Array = h.stations_by_kind["DRY"]
	assert_eq([h.stations[dry[0]].id, h.stations[dry[1]].id], ["st_fireplace", "st_radiator"])


func test_load_time_under_150ms() -> void:
	var t0 := Time.get_ticks_usec()
	var db := ContentDB.load_dir(SimTestUtil.FIXTURES)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(db.ok())
	assert_lt(ms, 150.0, "load %.1f ms" % ms)
