## Every GDD §4.7 fairness rule as its own test, over the scripted Night (fx_act1 command log) and
## targeted scenarios.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")

static var _log: Array = []
static var _world: SimWorld = null


func _night() -> Array:
	if _log.is_empty():
		var d: Variant = TestBase.load_json("res://tests/sim/fixtures/cmds_fx_act1.json")
		var by := {}
		for e in d["cmds"]:
			if not by.has(int(e[0])):
				by[int(e[0])] = []
			by[int(e[0])].append(e[1])
		var w := U.world("fx_act1", {"invariants": true})
		for t in range(1, 18001):
			w.step(by.get(t, []))
			for ev in w.drain_events():
				ev["_b_state"] = w.bellows.state
				ev["_h_room"] = w.room_id(w.hush.room)
				_log.append(ev)
		_world = w
	return _log


func test_fair_1_spot_window() -> void:
	var log := _night()
	var fill: int = roundi((U.db().episodes["fx_act1"] as EpisodeDef).spot_fill_s * 60)
	var catches := U.find(log, SimEvents.CAUGHT)
	assert_ge(catches.size(), 2, "the scripted Night gets caught a few times")
	for c in catches:
		if str(c["cause"]) == "face_to_face":
			continue
		var sp := int(c["spotted_tick"])
		var start := -1
		for ev in log:
			if int(ev["t"]) > sp:
				break
			if str(ev["e"]) == SimEvents.SPOT_START:
				start = int(ev["t"])
		assert_ge(sp - start + 1, int(fill), "catch at %d: a \"?\" of ≥ 1.0 s before it" % int(c["t"]))
	assert_eq(int(_world.invariant_counters["catch_without_window"]), 0)


func test_fair_2_unseen_hiding_is_safe() -> void:
	_night()
	assert_eq(int(_world.invariant_counters["caught_unwatched_hidden"]), 0)
	# and an in-use spot still opens a window instead of an ambush (see test_hiding)
	var w := U.world_patched("fx_act1", U.loop_patch(["clock"], "hall", 900, "hall", 1340))
	U.place_hush_at(w, "hall_clock_case")
	w.hush.state = SimHush.HIDDEN
	w.hush.hidden_spot = w.hush.at_hotspot
	var log: Array = []
	var c := U.run_until(w, SimEvents.CAUGHT, {}, 800, log)
	assert_eq(str(c.get("cause", "")), "face_to_face")
	assert_false(U.first(log, SimEvents.FACE_TO_FACE).is_empty())


func test_fair_3_entry_warning() -> void:
	var log := _night()
	var last := {}
	var bad := 0
	for ev in log:
		if str(ev["e"]) == SimEvents.ENTRY_WARNING:
			last[str(ev["room"])] = int(ev["t"])
		elif str(ev["e"]) == SimEvents.B_ROOM and str(ev["room"]) == str(ev["_h_room"]) \
				and int(ev["_b_state"]) != SimBellows.CHASE and int(ev["_b_state"]) != SimBellows.REACTING:
			if int(ev["t"]) - int(last.get(str(ev["room"]), -100000)) < 90:
				bad += 1
	assert_eq(bad, 0)
	assert_eq(int(_world.invariant_counters["entry_without_warning"]), 0)


func test_fair_4_next_activity_shown_and_route_changes_same_tick() -> void:
	var log := _night()
	for d in U.find(log, SimEvents.B_DETOUR):
		assert_eq(U.find(log, SimEvents.B_NEXT, {"t": d["t"]}).size() >= 1, true, "b_detour at %d" % int(d["t"]))
	var acts := U.find(log, SimEvents.B_ACTIVITY)
	var loop_ids := ["warmup", "tea", "pickles", "paper", "rinse"]
	for i in range(1, acts.size()):
		var id := str(acts[i]["id"])
		if not loop_ids.has(id):
			continue
		# the bubble's last `next` before this b_activity (in event order) named it
		var shown := -1
		for ev in log:
			if ev == acts[i]:
				break
			if str(ev["e"]) == SimEvents.B_NEXT:
				shown = int(ev["t"]) if str(ev["id"]) == id else -1
		assert_true(shown >= 0, "%s at %d was in the bubble" % [id, int(acts[i]["t"])])


func test_fair_5_blind_and_deaf_while_reacting() -> void:
	_night()
	assert_eq(int(_world.invariant_counters["spot_while_blind"]), 0)
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "kitchen", 3300))
	U.force_rig(w, "tap_dance")
	var log: Array = []
	U.run_until(w, SimEvents.REACTION_START, {}, 200, log)
	for i in 100:
		log.append_array(U.step(w, [SimCmd.squeak()] if i % 20 == 0 else []))
	assert_true(U.first(log, SimEvents.SPOT_START).is_empty())
	for sq in U.find(log, SimEvents.SQUEAK):
		assert_false(bool(sq["heard"]))


func test_fair_6_same_inputs_same_night() -> void:
	var d: Variant = TestBase.load_json("res://tests/sim/fixtures/cmds_fx_act1.json")
	var a := PackedInt64Array()
	var b := PackedInt64Array()
	U.replay("fx_act1", d["cmds"], 4000, a)
	U.replay("fx_act1", d["cmds"], 4000, b)
	assert_eq(a, b)


func test_fair_7_no_soft_locks_items_respawn() -> void:
	_night()
	var w := _world
	for l in w.episode.script_lines:
		if l.kind != LineDef.K_PRANK or w.goals.done[l.idx] == 1:
			continue
		var s := w.prank_state(l.prank)
		assert_true(s == Pranks.AVAILABLE or s == Pranks.IN_PROGRESS or s == Pranks.RIGGED,
			"%s still achievable (%s)" % [l.id, Pranks.STATE_NAMES[s]])
		for st in w.db.pranks[l.prank].steps:
			if st.needs != "":
				var i := w.db.item_idx(st.needs)
				assert_true(w.pranks.item_state[i] != Pranks.ITEM_CARRIED or w.hush.carrying.has(st.needs))
	# a used item restocks in 20 s
	var q := U.quiet_world()
	q.pranks.item_used(q, "squeaker")
	q.drain_events()
	var ev := U.run_until(q, SimEvents.RESTOCK, {"item": "squeaker"}, 1300)
	assert_eq(int(ev["t"]), SimConst.RESTOCK_TICKS)


func test_fair_8_every_catch_logged_with_cause() -> void:
	var log := _night()
	for c in U.find(log, SimEvents.CAUGHT):
		assert_true(["grab", "pull_out", "face_to_face"].has(str(c["cause"])))
		assert_ge(int(c["spotted_tick"]), 0)
		assert_eq(U.find(log, SimEvents.BUSTED_CAM, {"t": c["t"]}).size(), 1, "the Busted Cam replays it")


func test_fair_9_speed_and_loop_order() -> void:
	var log := _night()
	assert_eq(int(_world.invariant_counters["fast_nonchase"]), 0)
	assert_le(SimConst.b_walk_speed(3), Fx.mul_pct(SimConst.B_WALK, 115))
	var loop_ids := ["warmup", "tea", "pickles", "paper", "rinse"]
	var seq := []
	for ev in U.find(log, SimEvents.B_ACTIVITY):
		if loop_ids.has(str(ev["id"])):
			seq.append(loop_ids.find(str(ev["id"])))
	assert_gt(seq.size(), 5)
	for i in range(1, seq.size()):
		var ok: bool = seq[i] == seq[i - 1] or seq[i] == (seq[i - 1] + 1) % loop_ids.size()
		assert_true(ok, "activity order %s" % str(seq))


func test_fair_10_headbutt_never_a_catch() -> void:
	var log := _night()
	for c in U.find(log, SimEvents.CAUGHT):
		assert_ne(str(c["cause"]), "headbutt")
	assert_true(U.first(log, SimEvents.HEADBUTT).is_empty(), "Beryl is Stage 3; headbutt knock-ons are inactive")
