## Each fairness invariant (TECH §8.6) fires on a purpose-built bad log and passes a good one.
extends TestBase

const U := preload("res://tests/solver/solver_test_util.gd")


## `n` ticks of samples; `over` = {tick: {field: value}} overrides; defaults: Hush in kitchen,
## Bellows ROUTINE in parlour.
func _log(n: int, events: Array = [], over: Dictionary = {}, base: Dictionary = {}) -> SolverLog:
	var lg := SolverLog.new()
	lg.fill_ticks = 60
	for t in range(1, n + 1):
		var s := {"hush_room": "kitchen", "b_room": "parlour", "b_state": "ROUTINE", "hush_x": 3500}
		s.merge(base, true)
		if over.has(t):
			s.merge(over[t], true)
		lg.add_sample(t, s)
	lg.events = events
	return lg


func _rules(v: Array[String]) -> String:
	return "\n".join(PackedStringArray(v))


func test_good_mock_run_is_fair() -> void:
	var ex := U.executor(U.world(), U.solution().resolve("ideal"))
	ex.run(20000)
	ex.log.replay_hash = Invariants.replay_hash(func() -> Object: return U.world(), ex.log)
	var bad := Invariants.check(ex.log)
	assert_eq(bad, [] as Array[String], _rules(bad))


func test_rule1_spot_window() -> void:
	var over := {}
	for t in range(101, 161):
		over[t] = {"spot": t - 100}
	var good := _log(200, [{"e": "spotted", "t": 160}, {"e": "caught", "t": 170, "cause": "grab", "spotted_tick": 160}], over)
	assert_eq(Invariants.rule1_spot_window(good), [] as Array[String])
	var over2 := {}
	for t in range(151, 161):
		over2[t] = {"spot": 60}
	var bad := _log(200, [{"e": "spotted", "t": 160}, {"e": "caught", "t": 170, "cause": "grab", "spotted_tick": 160}], over2)
	var v := Invariants.rule1_spot_window(bad)
	assert_eq(v.size(), 1)
	assert_has(v[0], "filled in 10 ticks")
	var none := _log(200, [{"e": "caught", "t": 170, "cause": "grab"}])
	assert_has(Invariants.rule1_spot_window(none)[0], "no preceding 'spotted'")
	var f2f_ok := _log(200, [{"e": "face_to_face", "t": 100}, {"e": "caught", "t": 150, "cause": "face_to_face"}])
	assert_eq(Invariants.rule1_spot_window(f2f_ok), [] as Array[String])
	var f2f_bad := _log(200, [{"e": "face_to_face", "t": 100}, {"e": "caught", "t": 120, "cause": "face_to_face"}])
	assert_has(Invariants.rule1_spot_window(f2f_bad)[0], "only 20 ticks after face_to_face")


func test_rule2_entry_warning() -> void:
	var good := _log(300, [{"e": "entry_warning", "t": 100, "room": "kitchen", "eta": 90}, {"e": "b_room", "t": 190, "room": "kitchen"}])
	assert_eq(Invariants.rule2_entry_warning(good), [] as Array[String])
	var late := _log(300, [{"e": "entry_warning", "t": 150, "room": "kitchen", "eta": 40}, {"e": "b_room", "t": 190, "room": "kitchen"}])
	assert_has(Invariants.rule2_entry_warning(late)[0], "only 40 ticks earlier")
	var ambush := _log(300, [{"e": "b_room", "t": 190, "room": "kitchen"}])
	assert_has(Invariants.rule2_entry_warning(ambush)[0], "no entry_warning")
	var chase := _log(300, [{"e": "b_room", "t": 190, "room": "kitchen"}], {189: {"b_state": "CHASE"}, 190: {"b_state": "CHASE"}})
	assert_eq(Invariants.rule2_entry_warning(chase), [] as Array[String], "chases are exempt")
	var other_room := _log(300, [{"e": "b_room", "t": 190, "room": "hall"}])
	assert_eq(Invariants.rule2_entry_warning(other_room), [] as Array[String], "not Hush's room")


func test_rule3_safe_hiding() -> void:
	var bad := _log(200, [{"e": "caught", "t": 150, "cause": "grab"}], {149: {"hidden": "kitchen_pantry_curtain"}})
	assert_has(Invariants.rule3_safe_hiding(bad)[0], "hidden unseen in kitchen_pantry_curtain")
	var watched := _log(200, [{"e": "caught", "t": 150, "cause": "pull_out"}], {149: {"hidden": "kitchen_pantry_curtain", "watched": true}})
	assert_eq(Invariants.rule3_safe_hiding(watched), [] as Array[String])
	var in_use := _log(200, [{"e": "caught", "t": 150, "cause": "face_to_face"}], {149: {"hidden": "bathroom_bath", "b_activity": "bath"}})
	in_use.in_use = {"bathroom_bath": "bath"}
	assert_eq(Invariants.rule3_safe_hiding(in_use), [] as Array[String], "a red-badged in-use spot may be found")


func test_rule4_bubble() -> void:
	var evs := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 100, "id": "pickles", "detour": false},
		{"e": "b_activity_end", "t": 700, "id": "tea"}, {"e": "b_activity", "t": 900, "id": "pickles"}]
	assert_eq(Invariants.rule4_bubble(_log(1000, evs)), [] as Array[String])
	var late := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 600, "id": "pickles", "detour": false},
		{"e": "b_activity_end", "t": 700, "id": "tea"}, {"e": "b_activity", "t": 900, "id": "pickles"}]
	assert_has(Invariants.rule4_bubble(_log(1000, late))[0], "shown only 100 ticks")
	var wrong := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 100, "id": "paper", "detour": false},
		{"e": "b_activity_end", "t": 700, "id": "tea"}, {"e": "b_activity", "t": 900, "id": "pickles"}]
	assert_has(Invariants.rule4_bubble(_log(1000, wrong))[0], "showed 'paper'")
	var detour_bad := [{"e": "b_detour", "t": 300, "kind": "MIRROR", "station": "st_hall_mirror", "why": "residue"}]
	assert_has(Invariants.rule4_bubble(_log(1000, detour_bad))[0], "without a b_next")
	var lure := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 100, "id": "pickles", "detour": false},
		{"e": "b_next", "t": 500, "id": "curious", "detour": false},
		{"e": "b_activity_end", "t": 700, "id": "tea"}, {"e": "b_activity", "t": 900, "id": "pickles"}]
	assert_eq(Invariants.rule4_bubble(_log(1000, lure)), [] as Array[String], "a lure (curious) is a detour")
	var queued := [{"e": "b_detour", "t": 300, "kind": "fixup_mirror"}, {"e": "b_next", "t": 300, "id": "fixup_mirror", "detour": true},
		{"e": "b_detour", "t": 400, "kind": "fixup_dry"}]
	assert_eq(Invariants.rule4_bubble(_log(1000, queued)), [] as Array[String], "a second detour queues behind the shown one")
	var stale := queued + [{"e": "b_activity", "t": 350, "id": "fixup_mirror"}]
	stale.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
	assert_eq(Invariants.rule4_bubble(_log(1000, stale)).size(), 1, "…but not once that detour has started")
	var detour_ok := [{"e": "b_detour", "t": 300, "kind": "MIRROR"}, {"e": "b_next", "t": 300, "id": "fixup_mirror", "detour": true}]
	assert_eq(Invariants.rule4_bubble(_log(1000, detour_ok)), [] as Array[String])
	var short := [{"e": "b_activity", "t": 100, "id": "rinse"}, {"e": "b_next", "t": 250, "id": "warmup", "detour": false},
		{"e": "b_activity_end", "t": 300, "id": "rinse"}, {"e": "b_activity", "t": 500, "id": "warmup"}]
	assert_eq(Invariants.rule4_bubble(_log(1000, short)), [] as Array[String], "< 4 s activities are exempt")


func test_rule5_and_rule6() -> void:
	var lg := _log(10)
	lg.final_hash = 42
	assert_eq(Invariants.rule5_determinism(lg), [] as Array[String], "not replayed → nothing to say")
	lg.replay_hash = 42
	assert_eq(Invariants.rule5_determinism(lg), [] as Array[String])
	lg.replay_hash = 43
	assert_has(Invariants.rule5_determinism(lg)[0], "non-deterministic")
	lg.softlock_probes = [{"t": 600, "ok": true}, {"t": 1200, "ok": false, "why": "cannot reach kettle"}]
	var v := Invariants.rule6_softlock(lg)
	assert_eq(v.size(), 1)
	assert_has(v[0], "cannot reach kettle")


func test_rule7_speed_and_loop() -> void:
	var over := {}
	for t in range(1, 101):
		over[t] = {"b_x_sub": t * 300}
	var fast := _log(100, [], over)
	assert_has(Invariants.rule7_speed_and_loop(fast)[0], "faster than 115 %")
	var over_ok := {}
	for t in range(1, 101):
		over_ok[t] = {"b_x_sub": t * 276}
	assert_eq(Invariants.rule7_speed_and_loop(_log(100, [], over_ok)), [] as Array[String], "Livid 115 % is fine")
	var over_chase := {}
	for t in range(1, 101):
		over_chase[t] = {"b_x_sub": t * 600, "b_state": "CHASE"}
	assert_eq(Invariants.rule7_speed_and_loop(_log(100, [], over_chase)), [] as Array[String], "chases run")
	var loop_ok := _log(10, [{"e": "b_activity", "t": 1, "id": "warmup"}, {"e": "b_activity", "t": 2, "id": "tea"},
		{"e": "b_activity", "t": 3, "id": "fixup_mirror"}, {"e": "b_activity", "t": 4, "id": "tea"},
		{"e": "b_activity", "t": 5, "id": "pickles"}, {"e": "b_activity", "t": 6, "id": "warmup"}])
	loop_ok.loop = [{"a": "warmup"}, {"a": "tea"}, {"a": "pickles"}]
	assert_eq(Invariants.rule7_speed_and_loop(loop_ok), [] as Array[String], "detours excluded, resumed tea ok")
	var loop_bad := _log(10, [{"e": "b_activity", "t": 1, "id": "warmup"}, {"e": "b_activity", "t": 2, "id": "pickles"}])
	loop_bad.loop = [{"a": "warmup"}, {"a": "tea"}, {"a": "pickles"}]
	assert_has(Invariants.rule7_speed_and_loop(loop_bad)[0], "breaks the loop order (expected 'tea')")
	var once := _log(10, [{"e": "b_activity", "t": 1, "id": "answer_door"}, {"e": "b_activity", "t": 2, "id": "tea"},
		{"e": "b_activity", "t": 3, "id": "tea"}, {"e": "b_activity", "t": 4, "id": "mirror"}])
	once.loop = [{"a": "answer_door", "once": true}, {"a": "tea"}, {"a": "mirror"}]
	assert_eq(Invariants.rule7_speed_and_loop(once), [] as Array[String])


func test_rule8_blind_reacting() -> void:
	var evs := [{"e": "reaction_start", "t": 100, "prank": "a"}, {"e": "reaction_end", "t": 200, "prank": "a"}]
	assert_has(Invariants.rule8_blind_reacting(_log(400, evs + [{"e": "spot_start", "t": 150, "by": "bellows"}]))[0], "during a reaction")
	assert_eq(Invariants.rule8_blind_reacting(_log(400, evs + [{"e": "spot_start", "t": 250, "by": "bellows"}])).size(), 1, "< 60 after")
	assert_eq(Invariants.rule8_blind_reacting(_log(400, evs + [{"e": "spot_start", "t": 259, "by": "bellows"}])).size(), 1, "59 after: still blind")
	assert_eq(Invariants.rule8_blind_reacting(_log(400, evs + [{"e": "spot_start", "t": 260, "by": "bellows"}])), [] as Array[String], "60 after: sees again")
	assert_eq(Invariants.rule8_blind_reacting(_log(400, evs + [{"e": "spot_start", "t": 150, "by": "delphine"}])), [] as Array[String], "only Bellows")


func test_rule9_progress_and_feedback() -> void:
	var stuck := _log(4000, [{"e": "b_activity", "t": 10, "id": "tea"}], {}, {"b_activity": "tea"})
	assert_has(Invariants.rule9_progress(stuck)[0], "no Bellows progress")
	var gated := _log(4000, [{"e": "b_activity", "t": 10, "id": "warmup"}], {}, {"b_activity": "warmup"})
	gated.gated = PackedStringArray(["warmup"])
	assert_eq(Invariants.rule9_progress(gated), [] as Array[String], "player-led gates wait for the player")
	var silent := _log(400)
	silent.cmds = [[10, {"c": "go", "hotspot": "kitchen_sink_tap", "run": false}]]
	assert_has(Invariants.rule9_progress(silent)[0], "produced no movement")
	var heard := _log(400, [{"e": "cmd_rejected", "t": 10, "c": "go", "why": "hidden"}])
	heard.cmds = [[10, {"c": "go", "hotspot": "kitchen_sink_tap", "run": false}]]
	assert_eq(Invariants.rule9_progress(heard), [] as Array[String])
	var held := _log(400, [{"e": "hush_go", "t": 222, "target": "kitchen_sink_tap", "run": false}])
	held.cmds = [[1, {"c": "go", "hotspot": "kitchen_sink_tap", "run": false}]]
	assert_eq(Invariants.rule9_progress(held), [] as Array[String], "held, then run: not dropped")
	var moved := _log(400, [], {50: {"hush_x": 3490}})
	moved.cmds = [[10, {"c": "move", "room": "kitchen", "x": 3000, "run": false}]]
	assert_eq(Invariants.rule9_progress(moved), [] as Array[String])


func test_rule10_reactions_applause_bases() -> void:
	var overlap := _log(10, [{"e": "reaction_start", "t": 1, "prank": "a"}, {"e": "reaction_start", "t": 2, "prank": "b"}])
	assert_has(Invariants.rule10_reactions_applause(overlap)[0], "while a was still playing")
	var knock := _log(10, [{"e": "reaction_start", "t": 1, "prank": "a"}, {"e": "knock_on", "t": 2, "a": "a", "b": "b"},
		{"e": "reaction_start", "t": 2, "prank": "b"}, {"e": "reaction_end", "t": 5, "prank": "b"}])
	assert_eq(Invariants.rule10_reactions_applause(knock), [] as Array[String], "a knock-on hands over")
	var neg := _log(10, [{"e": "applause", "t": 3, "delta": -50, "total": -20}])
	assert_has(Invariants.rule10_reactions_applause(neg)[0], "< 0")
	var bases := _log(10)
	bases.bases_sum = 690
	assert_has(Invariants.rule10_reactions_applause(bases)[0], "sum to 690")
	bases.bases_sum = 700
	assert_eq(Invariants.rule10_reactions_applause(bases), [] as Array[String])


func test_rule11_headbutt_only_with_beryl() -> void:
	var lg := _log(100, [{"e": "headbutt", "t": 40, "target": "hush", "landing": "pond"}, {"e": "caught", "t": 50, "cause": "grab", "by": "bellows"}])
	assert_eq(Invariants.rule11_headbutt(lg), [] as Array[String], "no Beryl → rule inactive")
	lg.has_beryl = true
	assert_has(Invariants.rule11_headbutt(lg)[0], "headbutt produced a catch")
	var lg2 := _log(100, [{"e": "caught", "t": 50, "cause": "grab", "by": "bellows"}])
	lg2.has_beryl = true
	assert_eq(Invariants.rule11_headbutt(lg2), [] as Array[String])


func test_sim_counters() -> void:
	var o := RefCounted.new()
	assert_eq(Invariants.sim_counters(o), [] as Array[String])
	assert_eq(Invariants.sim_counters(null), [] as Array[String])
