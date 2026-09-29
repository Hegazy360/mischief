## s2-sim §4.1 — Bellows' micro-gag beats (lead decision D1): both `micro_gags` schema forms, the cycle while a
## gated activity keeps performing, the suppression list, the 180-tick spacing, walk beats, `SimVisibility.beat_vis`
## (room / pip by each of its three reasons / edge / none), `SimEvents.is_beat` / `is_visible_beat`, and `SimFf.drops`.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


## files_patch: give activity `act` these `micro_gags` (and an optional `mg_cycle_s`).
func _mg(act: String, gags: Array, cycle_s: float = -1.0) -> Callable:
	return func(files: Dictionary) -> void:
		var a: Dictionary = files["activities"]["activities"][act]
		a["micro_gags"] = gags
		if cycle_s > 0.0:
			a["mg_cycle_s"] = cycle_s


## Bellows loops the radiator on the landing (upstairs); Hush idles in the kitchen.
func _radiator_world(files_patch: Callable, loop: Array = ["radiator"]) -> SimWorld:
	return U.world_patched("fx_act1", U.loop_patch(loop, "landing", 1420), {}, files_patch)


func test_legacy_string_list_spreads_beats() -> void:
	var a := ActivityDef.from_dict("x", {"dur_s": 10, "micro_gags": ["admire_in_kettle", "hum", "pinkie_up"]})
	assert_true(a.mg_legacy)
	assert_eq(a.mg_ids, PackedStringArray(["admire_in_kettle", "hum", "pinkie_up"]))
	assert_eq(a.mg_at, PackedInt32Array([120, 480, 840]), "2.0 + 6·i s")
	assert_eq(a.mg_len, PackedInt32Array([48, 48, 48]))
	assert_eq(a.mg_emote, PackedStringArray(["", "", ""]), "no emote")
	assert_eq(a.mg_cycle, 840 + 360, "default cycle = last at_s + 6 s")
	assert_eq(a.mg_errors.size(), 0)


func test_timed_schema_parses_with_cycle() -> void:
	var a := ActivityDef.from_dict("tea", {"dur_s": 10, "micro_gags": [
		{"id": "admire_in_kettle", "at_s": 2.0, "len_f": 60, "emote": "smug"},
		{"id": "hum", "at_s": 7.0, "emote": null}]})
	assert_false(a.mg_legacy)
	assert_eq(a.mg_at, PackedInt32Array([120, 420]))
	assert_eq(a.mg_len, PackedInt32Array([60, 48]), "len_f default 48")
	assert_eq(a.mg_emote, PackedStringArray(["smug", ""]))
	assert_eq(a.mg_cycle, 420 + 360)
	var b := ActivityDef.from_dict("tea", {"micro_gags": [{"id": "a", "at_s": 2.0}], "mg_cycle_s": 8.0})
	assert_eq(b.mg_cycle, 480)
	assert_eq(b.mg_due(120), 0)
	assert_eq(b.mg_due(600), 0, "repeats every mg_cycle_s")
	assert_eq(b.mg_due(121), -1)
	assert_eq(ActivityDef.from_dict("n", {}).mg_cycle, 0, "no micro_gags: nothing due")


func test_bad_schema_is_a_validation_error() -> void:
	var files := U.raw()
	var acts: Dictionary = files["activities"]["activities"]
	acts["tea"]["micro_gags"] = [{"id": "a", "at_s": 2.0, "emote": "wink"}]
	acts["pickles"]["micro_gags"] = [{"id": "b"}]
	acts["rinse"]["micro_gags"] = [{"id": "c", "at_s": 3.0}, {"id": "d", "at_s": 3.0}]
	acts["paper"]["micro_gags"] = [{"id": "e", "at_s": 3.0}]
	acts["paper"]["mg_cycle_s"] = 2.0
	acts["fire"]["micro_gags"] = [7]
	files["activities"]["walk_beats"] = {"min_leg_s": 5.0, "every_s": 6.0, "ids": [{"id": "walk_hum", "emote": "whistle"}]}
	var d := ContentDB.load_dicts(files)
	var all := "\n".join(d.errors)
	for needle in ["tea.micro_gags[0] (a) emote 'wink'", "pickles.micro_gags[0] (b) has no at_s",
			"rinse.micro_gags[1] (d) at_s must be after", "paper.mg_cycle_s 2.00 must be greater", "fire.micro_gags[0] must be",
			"walk_beats.ids[0] (walk_hum) emote 'whistle'"]:
		assert_has(all, needle)
	for em in ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]:
		assert_has(SimEvents.EMOTES, em)
	assert_eq(SimEvents.EMOTES.size(), 8, "the fixed edge-bubble vocabulary")


func test_beats_fire_at_their_marks_with_the_payload() -> void:
	var w := _radiator_world(_mg("radiator", [{"id": "tap_pipe", "at_s": 1.0, "len_f": 60, "emote": "hum"},
		{"id": "stare", "at_s": 4.0, "len_f": 30, "emote": null}]))
	var log := U.run(w, 900)
	var acts := U.find(log, SimEvents.B_ACTIVITY, {"id": "radiator"})
	assert_ge(acts.size(), 2)
	var t0 := int(acts[0]["t"])
	var mg := U.find(log, SimEvents.MICRO_GAG)
	assert_ge(mg.size(), 3)
	var first: Dictionary = mg[0]
	assert_eq(int(first["t"]) - t0, 60, "at_s counts from the b_activity tick")
	assert_eq(str(first["id"]), "tap_pipe")
	assert_eq(str(first["activity"]), "radiator")
	assert_eq(str(first["room"]), "landing")
	assert_eq(int(first["x"]), 1420)
	assert_eq(int(first["len"]), 60)
	assert_eq(str(first["emote"]), "hum")
	assert_eq(str(first["vis"]), "edge", "upstairs, not linked to the kitchen, with an emote → the edge bubble")
	var second: Dictionary = mg[1]
	assert_eq(int(second["t"]) - t0, 240)
	assert_eq(str(second["vis"]), "", "no emote and out of sight → invisible")
	assert_true(SimEvents.is_beat(second))
	assert_false(SimEvents.is_visible_beat(second))
	assert_true(SimEvents.is_visible_beat(first))
	assert_false(SimEvents.is_laugh(first), "a micro-gag is not a laugh")
	var t1 := int(acts[1]["t"])
	var again := U.first(U.find(log, SimEvents.MICRO_GAG, {"id": "stare"}).filter(func(ev: Dictionary) -> bool: return int(ev["t"]) > t1), SimEvents.MICRO_GAG)
	assert_eq(int(again.get("t", -1)) - t1, 240, "the next visit plays them again (its 1 s beat falls within 180 ticks of the last one)")


func test_legacy_form_emits_hidden_beats() -> void:
	var w := _radiator_world(_mg("radiator", ["tap_pipe"]))
	var log := U.run(w, 400)
	var mg := U.find(log, SimEvents.MICRO_GAG)
	assert_eq(mg.size(), 1)
	var t0 := int(U.first(log, SimEvents.B_ACTIVITY, {"id": "radiator"})["t"])
	assert_eq(int(mg[0]["t"]) - t0, 120, "legacy: 2.0 s")
	assert_eq(int(mg[0]["len"]), 48)
	assert_eq(str(mg[0]["emote"]), "")
	assert_eq(str(mg[0]["vis"]), "")


func test_never_two_within_180_ticks() -> void:
	var w := _radiator_world(_mg("radiator", [{"id": "a", "at_s": 1.0}, {"id": "b", "at_s": 2.0}, {"id": "c", "at_s": 4.0}]))
	var log := U.run(w, 1200)
	var acts := U.find(log, SimEvents.B_ACTIVITY, {"id": "radiator"})
	var t1 := int(acts[1]["t"]) if acts.size() > 1 else 1 << 30
	var mg := U.find(log, SimEvents.MICRO_GAG).filter(func(ev: Dictionary) -> bool: return int(ev["t"]) < t1)
	assert_eq(mg.size(), 2, "first visit")
	var ids := PackedStringArray()
	for k in mg.size():
		ids.append(str(mg[k]["id"]))
		if k > 0:
			assert_ge(int(mg[k]["t"]) - int(mg[k - 1]["t"]), SimConst.MG_MIN_GAP, "spacing")
	assert_false(ids.has("b"), "b (1 s after a) is dropped, not deferred: %s" % [ids])
	assert_eq(ids[0], "a")
	assert_eq(ids[1], "c")


func test_gated_activity_repeats_its_list_every_cycle() -> void:
	# an uncapped player-led gate: he keeps performing the radiator until Hush rigs something (she never does)
	var loop := [{"a": "radiator", "gate": {"until": "first_rig", "plus_s": 1, "max_s": null}}]
	var w := _radiator_world(_mg("radiator", [{"id": "tap_pipe", "at_s": 1.0, "emote": "hum"},
		{"id": "hum", "at_s": 4.0, "emote": "hum"}], 6.0), loop)
	var log := U.run(w, 1500)
	var acts := U.find(log, SimEvents.B_ACTIVITY)
	assert_eq(acts.size(), 1, "the gate holds him at the radiator")
	var t0 := int(acts[0]["t"])
	var got := PackedInt32Array()
	for ev in U.find(log, SimEvents.MICRO_GAG):
		got.append(int(ev["t"]) - t0)
	assert_eq(got.slice(0, 6), PackedInt32Array([60, 240, 420, 600, 780, 960]), "every 6 s: 1, 4, 7, 10, 13, 16 s")


func test_suppressed_while_he_is_busy_with_something_funnier() -> void:
	var w := _radiator_world(_mg("radiator", [{"id": "tap_pipe", "at_s": 1.0, "emote": "hum"}]))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "radiator"}, 600)
	var b := w.bellows
	assert_false(b.beats_suppressed(w), "performing: free to play")
	# a squeak bit over the activity clock
	b.bit_until = w.tick + 120
	assert_true(b.beats_suppressed(w), "a squeak bit plays")
	var log := U.run(w, 100)
	assert_eq(U.find(log, SimEvents.MICRO_GAG).size(), 0, "the beat at 1 s is swallowed by the bit")
	b.bit_until = 0
	for st in [SimBellows.REACTING, SimBellows.CURIOUS, SimBellows.SEARCH, SimBellows.SPOTTED, SimBellows.CHASE,
			SimBellows.CAUGHT_HOLD, SimBellows.MELTDOWN, SimBellows.EXHAUSTED]:
		var keep := b.state
		b.state = st
		assert_true(b.beats_suppressed(w), "state %d suppresses" % st)
		b.state = keep
	b.head_turn_until = w.tick + 10
	assert_true(b.beats_suppressed(w), "head turn")
	b.head_turn_until = 0
	b.bump_phase = SimBellows.BUMP_LOOK
	assert_true(b.beats_suppressed(w), "bump")
	b.bump_phase = SimBellows.BUMP_NONE
	b.mg_last_t = w.tick - 10
	assert_true(b.beats_suppressed(w), "within 180 ticks of the last beat")
	b.mg_last_t = -1000000
	assert_false(b.beats_suppressed(w))


func test_doorway_pause_suppresses_walk_beats() -> void:
	var w := _radiator_world(func(files: Dictionary) -> void:
		files["activities"]["walk_beats"] = {"min_leg_s": 1.0, "every_s": 1.0, "ids": [{"id": "walk_hum", "emote": "hum"}]},
		["paper", "tea"])
	var log: Array = []
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "paper"}, 2000, log)
	var b := w.bellows
	b._path_to(w, w.room_idx("kitchen"), 3000 * SimConst.SUB, SimConst.MOVER_B_WALK)
	b.phase = SimBellows.PH_WALK
	b.path.insert_pause(b.path.cursor, 90, NavPath.AUX_DOORWAY_PAUSE)
	assert_true(b.beats_suppressed(w), "a doorway pause")


func test_walk_beats_cycle_during_long_walks() -> void:
	var patch := func(files: Dictionary) -> void:
		files["activities"]["walk_beats"] = {"min_leg_s": 3.0, "every_s": 3.5, "ids": [{"id": "walk_hum", "len_f": 40, "emote": "hum"},
			{"id": "cravat_tug", "emote": "smug"}, {"id": "shrug"}]}
	# kitchen tea ↔ landing radiator: long walks through the house
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "radiator"], "kitchen", 2900, "porch", 300), {}, patch)
	var log := U.run(w, 6000)
	var walks := U.find(log, SimEvents.MICRO_GAG, {"activity": "walk"})
	assert_ge(walks.size(), 4, "several walk beats")
	var want := ["walk_hum", "cravat_tug", "shrug"]
	for k in walks.size():
		assert_eq(str(walks[k]["id"]), want[k % 3], "cycles in list order")
		if k > 0:
			assert_ge(int(walks[k]["t"]) - int(walks[k - 1]["t"]), SimConst.MG_MIN_GAP)
	assert_eq(int(walks[0]["len"]), 40)
	assert_eq(int(walks[1]["len"]), 48)
	# short walks never qualify
	var w2 := U.world_patched("fx_act1", U.loop_patch(["tea", "radiator"], "kitchen", 2900, "porch", 300), {}, func(files: Dictionary) -> void:
		files["activities"]["walk_beats"] = {"min_leg_s": 60.0, "every_s": 3.5, "ids": [{"id": "walk_hum"}]})
	assert_eq(U.find(U.run(w2, 3000), SimEvents.MICRO_GAG).size(), 0, "no walk is longer than 60 s")


func test_beats_change_nothing_but_the_beat_clock() -> void:
	var gags := [{"id": "sip", "at_s": 1.0, "emote": "yum"}, {"id": "hum", "at_s": 5.0, "emote": "hum"}]
	var patch := func(files: Dictionary) -> void:
		for a in ["warmup", "tea", "pickles", "paper", "rinse"]:
			files["activities"]["activities"][a]["micro_gags"] = gags
	var cmds := U.bot_act1(4000)
	var by := {}
	for e in cmds:
		if not by.has(int(e[0])):
			by[int(e[0])] = []
		(by[int(e[0])] as Array).append(e[1])
	var plain := U.world("fx_act1")
	var files := U.raw()
	patch.call(files)
	var beaty := SimWorld.create(ContentDB.load_dicts(files), "fx_act1", {})
	var ev_a: Array = []
	var ev_b: Array = []
	var n_beats := 0
	for t in range(1, 4001):
		plain.step(by.get(t, []))
		beaty.step(by.get(t, []))
		ev_a.append_array(plain.drain_events())
		for ev in beaty.drain_events():
			if str(ev["e"]) == SimEvents.MICRO_GAG:
				n_beats += 1
			else:
				ev_b.append(ev)
	assert_gt(n_beats, 0, "beats played")
	assert_eq(ev_b.size(), ev_a.size(), "same events apart from the beats")
	assert_eq(JSON.stringify(ev_b), JSON.stringify(ev_a))
	assert_eq(beaty.applause_tenths(), plain.applause_tenths())
	assert_eq(beaty.bellows.temper_q, plain.bellows.temper_q)


func test_beat_vis_truth_table() -> void:
	var w := U.quiet_world()
	U.run(w, 5)
	var b := w.bellows
	var hu := w.hush
	var put := func(broom: String, bx: int, hroom: String, hx: int) -> void:
		b.room = w.room_idx(broom)
		b.floor = w.db.house.rooms[b.room].floor
		b.x_sub = bx * SimConst.SUB
		b.path = null
		U.place_hush(w, hroom, hx)
	put.call("kitchen", 2900, "kitchen", 3700)
	assert_eq(SimVisibility.beat_vis(w, false), "room", "same room")
	# hidden: the hiding spot's room
	hu.state = SimHush.HIDDEN
	hu.hidden_spot = w.db.house.hotspot_index["kitchen_pantry_curtain"]
	assert_eq(SimVisibility.beat_vis(w, false), "room", "a hidden Hush sees her hiding spot's room")
	hu.state = SimHush.IDLE
	hu.hidden_spot = -1
	put.call("parlour", 2000, "kitchen", 3700)
	assert_eq(SimVisibility.beat_vis(w, false), "pip", "next door through a doorway")
	put.call("landing", 1300, "hall", 900)
	assert_eq(SimVisibility.beat_vis(w, false), "pip", "linked by the stairs")
	put.call("porch", 300, "hall", 900)
	assert_eq(SimVisibility.beat_vis(w, false), "pip", "linked by a door")
	put.call("hall", 900, "kitchen", 3700)
	assert_eq(SimVisibility.beat_vis(w, false), "", "two rooms away, not coming")
	assert_eq(SimVisibility.beat_vis(w, true), "edge", "…but an emote plays on the edge bubble")
	b._path_to(w, w.room_idx("kitchen"), 3000 * SimConst.SUB, SimConst.MOVER_B_WALK)
	assert_eq(SimVisibility.beat_vis(w, false), "pip", "his path ends in her room")
	b.path = null
	put.call("landing", 1300, "kitchen", 3700)
	hu.state = SimHush.RIGGING
	assert_eq(SimVisibility.beat_vis(w, false), "pip", "she is rigging: the PiP shows him")
	hu.state = SimHush.IDLE
	assert_eq(SimVisibility.beat_vis(w, true), "edge")
	assert_eq(SimVisibility.beat_vis(w, false), "")


func test_sim_ff_drop_rule() -> void:
	assert_true(SimFf.drops({"e": "prank_fire", "prank": "x"}, "kitchen"))
	assert_true(SimFf.drops({"e": "spot_start", "by": "bellows"}, "kitchen"))
	assert_true(SimFf.drops({"e": "entry_warning", "room": "kitchen", "eta": 90}, "kitchen"), "into her room")
	assert_true(SimFf.drops({"e": "entry_warning", "eta": 90}, "kitchen"), "unnamed room: drop to be safe")
	assert_false(SimFf.drops({"e": "entry_warning", "room": "parlour", "eta": 90}, "kitchen"), "another room")
	for e in ["micro_gag", "reaction_accent", "b_activity", "squeak", "cmd_queued", "hush_go"]:
		assert_false(SimFf.drops({"e": e}, "kitchen"), e)
	assert_eq(SimFf.RATE, 3)


func test_real_data_beats() -> void:
	var db := ContentDB.load_dir("res://data")
	if not assert_true(db.errors.is_empty(), "real data loads: %s" % [db.errors]):
		return
	var timed := 0
	for a in db.activity_list:
		assert_eq(a.mg_errors.size(), 0, "%s micro_gags: %s" % [a.id, a.mg_errors])
		if a.mg_count() > 0 and not a.mg_legacy:
			timed += 1
		for em in a.mg_emote:
			assert_true(em == "" or SimEvents.EMOTES.has(em), "%s emote %s" % [a.id, em])
	assert_gt(timed, 0, "content's timed micro_gags are read")
	for ep in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]:
		var w := SimWorld.create(db, ep, {})
		var log := U.run(w, 3600)
		var mg := U.find(log, SimEvents.MICRO_GAG)
		assert_gt(mg.size(), 0, "%s: Bellows plays micro-gags" % ep)
		for ev in mg:
			assert_has(["room", "pip", "edge", ""], str(ev["vis"]))
			assert_true(str(ev["room"]) != "" and int(ev["len"]) > 0, "%s payload" % ep)
		for k in range(1, mg.size()):
			assert_ge(int(mg[k]["t"]) - int(mg[k - 1]["t"]), SimConst.MG_MIN_GAP, "%s spacing" % ep)
