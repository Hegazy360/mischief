## The condition language (TECH §8.2) and prank condition entries (TECH §4.4).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _tea() -> SimWorld:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.run(w, 10)
	return w


func test_bellows_keys() -> void:
	var w := _tea()
	var C := Conditions
	assert_true(C.eval(w, {"bellows_activity": "tea"}))
	assert_true(C.eval(w, {"bellows_performing": "tea"}))
	assert_true(C.eval(w, {"bellows_activity_in": ["pickles", "tea"]}))
	assert_true(C.eval(w, {"bellows_state": "routine"}))
	assert_true(C.eval(w, {"bellows_in_room": "kitchen"}))
	assert_true(C.eval(w, {"bellows_not_in_room": "hall"}))
	assert_true(C.eval(w, {"bellows_eta_to_room_gt_s": ["hall", 3]}), "not heading there")
	assert_false(C.eval(w, {"bellows_eta_to_room_gt_s": ["kitchen", 3]}), "he is in it")
	assert_false(C.eval(w, {"bellows_activity_remaining_le_s": 4}))
	U.run(w, 600 - 10 - 240 + 1)
	assert_true(C.eval(w, {"bellows_activity_remaining_le_s": 4}))
	assert_true(C.eval(w, {"bellows_facing_away_from_hush": true}), "she is in another room")


func test_hush_and_meta_keys() -> void:
	var w := _tea()
	var C := Conditions
	assert_true(C.eval(w, {"hush_in_room": "hall"}))
	assert_true(C.eval(w, {"hush_visible": false}))
	assert_true(C.eval(w, {"hush_hidden": false}))
	U.place_hush(w, "kitchen", 3300)
	assert_true(C.eval(w, {"hush_visible": true}))
	U.run(w, 30)
	assert_true(C.eval(w, {"spot_meter_pct_ge": 45}))
	assert_false(C.eval(w, {"spot_meter_pct_ge": 60}))
	assert_true(C.eval(w, {"tick_ge_s": 0.5}))
	assert_false(C.eval(w, {"tick_ge_s": 100}))
	assert_true(C.eval(w, {"prank_state": ["achoo_ria", "available"]}))
	assert_true(C.eval(w, {"temper_tier_ge": "calm"}))
	assert_false(C.eval(w, {"temper_tier_ge": "irked"}))
	assert_true(C.eval(w, {"link_ge": 0}))
	assert_false(C.eval(w, {"line_done": "tap"}))
	assert_true(C.eval(w, {"all_required_done": false}))
	assert_true(C.eval(w, {"first_squeak": false}))
	assert_true(C.eval(w, {"first_rig": false}))
	assert_false(C.eval(w, "first_rig"))


func test_event_seen_and_combinators() -> void:
	var w := _tea()
	var C := Conditions
	assert_true(C.eval(w, {"event_seen": "b_activity"}))
	assert_true(C.eval(w, {"event_seen": ["b_activity", {"id": "tea"}]}))
	assert_true(C.eval(w, {"event_seen": {"e": "b_activity", "id": "tea"}}))
	assert_true(C.eval(w, {"event_seen": {"event": "b_activity", "match": {"id": "tea"}}}))
	assert_false(C.eval(w, {"event_seen": ["b_activity", {"id": "rinse"}]}))
	assert_true(C.eval(w, {"and": [{"bellows_in_room": "kitchen"}, {"not": {"hush_hidden": true}}]}))
	assert_true(C.eval(w, {"or": [{"bellows_in_room": "hall"}, {"bellows_in_room": "kitchen"}]}))
	assert_false(C.eval(w, {"not": {"bellows_in_room": "kitchen"}}))
	assert_true(C.eval(w, {}))
	assert_false(C.eval(w, null))
	assert_true(C.eval(w, [{"bellows_in_room": "kitchen"}, true]))
	assert_false(C.eval(w, {"unknown_key": 1}))


func test_validate_reports_unknown_keys() -> void:
	assert_eq(Conditions.validate({"tick_ge_s": 1}), PackedStringArray())
	assert_eq(Conditions.validate({"and": [{"hush_hidden": true}, {"not": {"line_done": "x"}}]}), PackedStringArray())
	assert_eq(Conditions.validate({"moon": 1}).size(), 1)
	assert_eq(Conditions.validate({"prank_state": "x"}).size(), 1)
	assert_eq(Conditions.validate("rigged:achoo_ria"), PackedStringArray())


func test_prank_condition_entries() -> void:
	var w := _tea()
	var rug := w.db.prank_idx("rug_burn")
	var conds: Array = w.db.prank_list[rug].conditions
	assert_false(Conditions.prank_conditions(w, conds, rug), "calm, not chasing")
	U.set_temper(w, 50)
	assert_true(Conditions.prank_conditions(w, conds, rug), "steaming")
	U.set_temper(w, 0)
	w.bellows.state = SimBellows.CHASE
	assert_true(Conditions.prank_conditions(w, conds, rug), "or_chase")
	w.bellows.state = SimBellows.ROUTINE
	assert_false(Conditions.prank_conditions(w, [{"beryl_within": 150}], rug), "Stage-3: no Beryl yet")
	assert_true(Conditions.prank_conditions(w, [], rug))
