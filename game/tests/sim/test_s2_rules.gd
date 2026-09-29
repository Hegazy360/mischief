## s2-sim §4.5 — episode rules and content seams: `rules.combos` (L4: `[]` = none, order-independent),
## `rules.senses: false` (the Gate-0 scene), `backstage` rooms (Bellows walks there, Hush never enters), fix-up
## stations only among the Night's rooms + backstage, `hooks: "after_gate"`, and the reaction's last beat (T3 →
## `t3_last_beats[hash % n]`, every 4th non-T3 → the slow burn; its `clip_timings` frames are in the length).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _world_rules(rules: Dictionary, loop: Array = ["radiator"], b_room: String = "landing", b_x: int = 1420) -> SimWorld:
	return U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(loop, b_room, b_x).call(ep)
		for k in rules:
			ep["rules"][k] = rules[k])


# --- rules.combos -------------------------------------------------------------------------------------

func test_empty_combos_rule_blocks_poodle_in_either_order() -> void:
	for order in [["SOAKED", "FRAZZLED"], ["FRAZZLED", "SOAKED"]]:
		var w := _world_rules({"combos": []})
		for k in order:
			w.residue.add(w, k, false)
		var log := w.drain_events()
		assert_true(U.first(log, SimEvents.COMBO).is_empty(), "no combo (%s)" % [order])
		assert_true(U.find(log, SimEvents.BONUS, {"kind": "combo"}).is_empty(), "no combo score")
		assert_true(w.residue.has("SOAKED") and w.residue.has("FRAZZLED"), "both residues stay")
	var all := _world_rules({})
	all.residue.add(all, "FRAZZLED", false)
	all.residue.add(all, "SOAKED", false)
	assert_false(U.first(all.drain_events(), SimEvents.COMBO, {"id": "poodle"}).is_empty(), "absent = every combo")


func test_combos_rule_allows_only_the_listed_ones() -> void:
	var w := _world_rules({"combos": ["dough_man"]})
	w.residue.add(w, "SOAKED", false)
	w.residue.add(w, "FRAZZLED", false)
	w.residue.add(w, "FLOURY", false)
	var log := w.drain_events()
	assert_true(U.first(log, SimEvents.COMBO, {"id": "poodle"}).is_empty(), "poodle not allowed")
	assert_false(U.first(log, SimEvents.COMBO, {"id": "dough_man"}).is_empty(), "dough_man allowed")


func test_rules_validation() -> void:
	var files := U.raw()
	files["episodes"]["fx_act1"]["rules"]["combos"] = ["poodle", "nope"]
	files["episodes"]["fx_act1"]["rules"]["senses"] = "off"
	files["episodes"]["fx_act1"]["backstage"] = ["kitchen", "attic"]
	files["episodes"]["fx_meltdown"]["rules"]["combos"] = "poodle"
	var d := ContentDB.load_dicts(files)
	var all := "\n".join(d.errors)
	for needle in ["rules.combos 'nope' not in residues.json combos", "rules.senses must be true or false",
			"backstage 'kitchen' is also one of the Night's rooms", "backstage 'attic' not a room", "rules.combos must be a list"]:
		assert_has(all, needle)
	assert_false(all.contains("'poodle' not in"), "a real combo id is fine")


# --- rules.senses ------------------------------------------------------------------------------------------

func test_senses_false_never_starts_a_question_mark_and_never_catches() -> void:
	# she walks right in front of him, runs, squeaks three times (a lure) and hides in the spot he opens next
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["clock", "warmup"], "hall", 900, "hall", 1100).call(ep)
		ep["rules"]["senses"] = false)
	assert_false(w.ctx.senses)
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.move("hall", 600, true)]))
	log.append_array(U.run(w, 200))
	for i in 3:
		log.append_array(U.step(w, [SimCmd.squeak()]))
		log.append_array(U.run(w, 60))
	log.append_array(U.step(w, [SimCmd.go("hall_clock_case")]))
	log.append_array(U.run(w, 2500))
	for e in [SimEvents.SPOT_START, SimEvents.SPOTTED, SimEvents.CAUGHT, SimEvents.CHASE_START, SimEvents.LURE,
			SimEvents.FACE_TO_FACE]:
		assert_true(U.first(log, e).is_empty(), "no %s with senses off" % e)
	assert_true(U.first(log, SimEvents.B_DETOUR, {"kind": "curious"}).is_empty(), "no curious detour")
	assert_eq(w.bellows.spot_meter, 0)
	# same set-up with senses on: he does notice
	var on := U.world_patched("fx_act1", U.loop_patch(["clock", "warmup"], "hall", 900, "hall", 1100))
	var log2: Array = []
	log2.append_array(U.step(on, [SimCmd.move("hall", 600, true)]))
	log2.append_array(U.run(on, 200))
	assert_false(U.first(log2, SimEvents.SPOT_START).is_empty(), "control: senses on sees her")


# --- backstage ---------------------------------------------------------------------------------------------

func _backstage_world() -> SimWorld:
	# Bellows loops the phone in the hall (backstage); Hush plays in the parlour + kitchen
	return U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["phone", "warmup"], "hall", 960, "kitchen", 3700).call(ep)
		ep["rooms"] = ["parlour", "kitchen"]
		ep["backstage"] = ["hall"])


func test_hush_never_enters_a_backstage_room() -> void:
	var w := _backstage_world()
	assert_true(w.ctx.is_backstage(w.room_idx("hall")))
	assert_false(w.ctx.hush_allowed(w.room_idx("hall")))
	var evs := U.step(w, [SimCmd.go("hall_coat_cupboard")])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "backstage", "go into it")
	evs = U.step(w, [SimCmd.move("hall", 900)])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "backstage", "move into it")
	U.step(w, [SimCmd.freeze(true)])
	evs = U.step(w, [SimCmd.pin("hall", 900)])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "backstage", "pin into it")
	evs = U.step(w, [SimCmd.pin_hotspot("hall_phone")])
	assert_eq(str(U.first(evs, SimEvents.CMD_REJECTED).get("why", "")), "backstage", "pin a hotspot in it")
	U.step(w, [SimCmd.freeze(false)])
	# she wanders the Night's rooms; the nav mask never routes her through the hall, while Bellows plays it
	var log: Array = []
	var hall := w.room_idx("hall")
	var in_hall := 0
	for i in 3000:
		var cmds: Array = []
		if i % 400 == 0:
			cmds.append(SimCmd.move("parlour", 1510) if (i / 400) % 2 == 0 else SimCmd.go("kitchen_honey"))
		log.append_array(U.step(w, cmds))
		if w.hush.room == hall:
			in_hall += 1
	assert_eq(in_hall, 0, "never in the backstage hall")
	assert_false(U.find(log, SimEvents.B_ACTIVITY, {"id": "phone"}).is_empty(), "Bellows still plays the hall")


# --- fix-up stations ------------------------------------------------------------------------------------------

func test_fixup_stations_only_among_the_nights_rooms_and_backstage() -> void:
	var w := U.world_patched("fx_meltdown", func(ep: Dictionary) -> void:
		U.loop_patch(["warmup"], "parlour", 1700, "kitchen", 3800).call(ep)
		ep["rooms"] = ["hall", "kitchen"]
		ep["backstage"] = ["landing"])
	w.bellows.room = w.room_idx("kitchen")
	w.bellows.x_sub = 3000 * SimConst.SUB
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "SOAKED")].id, "st_radiator",
		"the parlour fireplace is not in this Night: the backstage landing's radiator serves")
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "FRAZZLED")].id, "st_hall_mirror")
	var free := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "kitchen", 3800))
	assert_eq(free.db.house.stations[free.residue.fixup_station(free, "SOAKED")].id, "st_fireplace", "control: nearest on his floor")


# --- hooks: after_gate --------------------------------------------------------------------------------------------

func _gate_world(after: bool, entry_level: bool = false) -> SimWorld:
	var gate := {"until": "first_squeak", "plus_s": 3.0, "max_s": null}
	var entry := {"a": "warmup", "gate": gate}
	if after:
		if entry_level:
			entry["hooks"] = "after_gate"
		else:
			gate["hooks"] = "after_gate"
	var w := U.world_patched("fx_act1", U.loop_patch([entry, "tea"], "parlour", 1700, "kitchen", 3800))
	U.force_rig(w, "allegro_go_go")
	return w


func test_after_gate_hooks_wait_for_the_gate() -> void:
	var plain := _gate_world(false)
	var log0 := U.run(plain, 200)
	var a0 := U.first(log0, SimEvents.B_ACTIVITY, {"id": "warmup"})
	var f0 := U.first(log0, SimEvents.PRANK_FIRE, {"prank": "allegro_go_go"})
	assert_eq(int(f0.get("t", -1)) - int(a0["t"]), 30, "control: the 0.5 s mark fires at once")
	for lvl in [false, true]:
		var w := _gate_world(true, lvl)
		assert_true(w.episode.loop[0].hooks_after_gate)
		var log := U.run(w, 600)
		assert_true(U.first(log, SimEvents.PRANK_FIRE).is_empty(), "nothing fires before the gate opens")
		log.append_array(U.step(w, [SimCmd.squeak()]))
		var t_gate := w.tick
		log.append_array(U.run(w, 200))
		var fire := U.first(log, SimEvents.PRANK_FIRE, {"prank": "allegro_go_go"})
		assert_false(fire.is_empty(), "then drops the needle")
		assert_between(int(fire.get("t", -1)) - t_gate, 30, 32, "the mark counts from the gate-open tick")
	var files := U.raw()
	files["episodes"]["fx_act1"]["bellows"]["loop"][1]["hooks"] = "after_gate"
	assert_has("\n".join(ContentDB.load_dicts(files).errors), "has hooks: after_gate but no gate")


# --- last beats ---------------------------------------------------------------------------------------------

func _beat_files() -> Callable:
	return func(files: Dictionary) -> void:
		files["reactions"]["clip_timings"] = {"bellows/beat_slow_burn": {"frames": 70}, "bellows/beat_dignity_fail": {"frames": 70},
			"bellows/beat_bow_topple": {"frames": 60}, "bellows/beat_tear": {"frames": 60}}


func _rinse(temper: int, rx_before: int = 0, seed: int = -1) -> Array:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600).call(ep)
		if seed >= 0:
			ep["seed"] = seed, {}, _beat_files())
	U.force_rig(w, "tap_dance")
	U.set_temper(w, temper)
	w.bellows.rx_count = rx_before
	var log: Array = []
	var rs := U.run_until(w, SimEvents.REACTION_START, {"prank": "tap_dance"}, 300, log)
	var end := U.run_until(w, SimEvents.REACTION_END, {}, 600, log)
	return [w, rs, end]


func test_t3_reaction_ends_with_a_last_beat_whose_frames_are_in_the_length() -> void:
	var r := _rinse(80)
	var w: SimWorld = r[0]
	var rs: Dictionary = r[1]
	assert_eq(int(rs["tier"]), 3)
	var beat := str(rs["last_beat"])
	assert_has(w.db.t3_last_beats, beat)
	assert_eq(int(rs["beat_len"]), w.db.clip_len(beat))
	assert_eq(int(rs["len"]), 153 + int(rs["beat_len"]), "drench_a T3 153 f + the beat")
	assert_eq(int(r[2]["t"]) - int(rs["t"]), int(rs["len"]), "REACTING lasts the whole length")
	assert_eq(str(_rinse(80)[1]["last_beat"]), beat, "deterministic")
	var seen := {}
	for s in range(1, 9):
		seen[str(_rinse(80, 0, s)[1]["last_beat"])] = true
	assert_gt(seen.size(), 1, "hash(seed, prank, loop) spreads the beats: %s" % [seen.keys()])


func test_every_fourth_non_t3_reaction_is_a_slow_burn() -> void:
	var r := _rinse(0, 0)
	assert_eq(str(r[1]["last_beat"]), "", "the 1st: no beat")
	assert_eq(int(r[1]["len"]), 120)
	assert_eq((r[0] as SimWorld).bellows.rx_count, 1)
	var r4 := _rinse(0, 3)
	assert_eq(str(r4[1]["last_beat"]), SimConst.SLOW_BURN_CLIP, "the 4th")
	assert_eq(int(r4[1]["len"]), 120 + 70)
	assert_eq(int(r4[2]["t"]) - int(r4[1]["t"]), 190)
	var t3 := _rinse(80, 3)
	assert_ne(str(t3[1]["last_beat"]), SimConst.SLOW_BURN_CLIP, "T3 reactions do not count towards the slow burn")
	assert_eq((t3[0] as SimWorld).bellows.rx_count, 3)
	# without clip_timings (the fixture) the beat is named but adds nothing
	var bare := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600))
	U.force_rig(bare, "tap_dance")
	bare.bellows.rx_count = 3
	var rs := U.run_until(bare, SimEvents.REACTION_START, {}, 300)
	assert_eq(str(rs["last_beat"]), SimConst.SLOW_BURN_CLIP)
	assert_eq(int(rs["beat_len"]), 0)
	assert_eq(int(rs["len"]), 120)
