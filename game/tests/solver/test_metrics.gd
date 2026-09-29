## Metrics on synthetic event logs: dead air, first laugh, laughs by 60 s, gaps, expect checks.
extends TestBase


## A log of `n` ticks (1..n) with input at the given ticks and the given events.
func _log(n: int, input_ticks: Array, events: Array, reacting: Array = []) -> SolverLog:
	var lg := SolverLog.new()
	lg.start_tick = 0
	var inp := {}
	for t in input_ticks:
		inp[int(t)] = true
	var rea := {}
	for pair in reacting:
		for t in range(int(pair[0]), int(pair[1]) + 1):
			rea[t] = true
	for t in range(1, n + 1):
		lg.add_sample(t, {"input": inp.has(t), "reacting": rea.has(t)})
	lg.events = events
	return lg


func test_dead_air_counts_only_quiet_ticks() -> void:
	# Input at tick 1 only, no laughs: ticks 301..600 are dead (input > 180 ago AND laugh > 300 ago).
	var lg := _log(600, [1], [])
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r["dead_air_pct"]), 100.0 * 300 / 600, 0.1)
	# A laugh at 400 resets the laugh clock: dead again only after 700 → only 301..399 dead.
	var lg2 := _log(600, [1], [{"e": "reaction_accent", "t": 400, "prank": "x"}])
	var r2 := Metrics.compute(lg2, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r2["dead_air_pct"]), 100.0 * 99 / 600, 0.1)
	# Constant input: never dead.
	var inputs: Array = []
	for t in range(1, 601, 100):
		inputs.append(t)
	assert_eq(float(Metrics.compute(_log(600, inputs, []), SolverHooks.fallback_is_laugh)["dead_air_pct"]), 0.0)


func test_reacting_is_never_dead_air() -> void:
	var lg := _log(600, [1], [], [[300, 600]])
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	assert_eq(float(r["dead_air_pct"]), 0.0, "reaction ticks are not dead air")
	var lg2 := _log(600, [1], [{"e": "reaction_start", "t": 350, "prank": "a"}, {"e": "reaction_end", "t": 600, "prank": "a"}])
	var r2 := Metrics.compute(lg2, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r2["dead_air_pct"]), 100.0 * 49 / 600, 0.1, "event-derived reaction window counts too")


func test_first_player_laugh_skips_director_laughs() -> void:
	var evs := [{"e": "director_cue", "t": 120, "id": "laugh_vase"}, {"e": "director_cue", "t": 150, "id": "figgis_psst"},
		{"e": "squeak_bit", "t": 400, "bit": "bit_warmup"}, {"e": "reaction_accent", "t": 1400, "prank": "achoo_ria"},
		{"e": "bump", "t": 1500, "first": false}, {"e": "bump", "t": 1600, "first": true}]
	var lg := _log(3000, [10], evs)
	lg.launch_offset_s = 2.3
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r["first_player_laugh_s"]), 400 / 60.0, 0.01)
	assert_almost_eq(float(r["first_player_laugh_launch_s"]), 400 / 60.0 + 2.3, 0.02)
	assert_almost_eq(float(r["first_prank_s"]), 1400 / 60.0, 0.01)
	assert_eq((r["laughs"] as Array).size(), 4, "cue laugh_vase, squeak bit, accent, first bump")
	assert_eq(String(r["laughs"][0]["kind"]), "cue:laugh_vase")
	# laughs_by_60 is launch-relative: tick 3000 = 50 s + 2.3 → all 4 are before 60 s.
	assert_eq(int(r["laughs_by_60"]), 4)


func test_laughs_by_60_launch_relative_cutoff() -> void:
	var evs := [{"e": "reaction_accent", "t": 3500, "prank": "a"}, {"e": "reaction_accent", "t": 3700, "prank": "b"}]
	var lg := _log(4000, [1], evs)
	lg.launch_offset_s = 2.3
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	# 3500 → 58.3 + 2.3 = 60.6 s > 60 → not counted; nothing counted.
	assert_eq(int(r["laughs_by_60"]), 0)
	lg.launch_offset_s = 0.0
	assert_eq(int(Metrics.compute(lg, SolverHooks.fallback_is_laugh)["laughs_by_60"]), 1)


func test_max_gap_and_prank_interval() -> void:
	var evs := [{"e": "reaction_accent", "t": 100, "prank": "a"}, {"e": "reaction_accent", "t": 1300, "prank": "b"},
		{"e": "reaction_accent", "t": 1900, "prank": "c"}, {"e": "caught", "t": 500, "cause": "grab"},
		{"e": "near_miss", "t": 700}]
	var lg := _log(2000, [1, 700], evs)
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	# Quiet runs: 2..99 (98), 101..699 (599), 701..1299 (599 - near_miss at 700 is a laugh too), …
	assert_almost_eq(float(r["max_gap_s"]), 599 / 60.0, 0.02)
	assert_almost_eq(float(r["prank_interval_mean_s"]), (1800 / 2) / 60.0, 0.02)
	assert_eq((r["catches"] as Array).size(), 1)
	assert_eq(String(r["catches"][0]["cause"]), "grab")
	assert_eq(int(r["near_misses"]), 1)
	assert_almost_eq(float(r["duration_s"]), 2000 / 60.0, 0.01)


func test_hold_total() -> void:
	var lg := SolverLog.new()
	for t in range(1, 301):
		lg.add_sample(t, {"hold_rig": t <= 90, "frozen": t > 200})
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r["hold_total_s"]), 1.5, 0.01)
	assert_almost_eq(float(r["freeze_total_s"]), 100 / 60.0, 0.01)


func test_check_expect_all_keys() -> void:
	var rep := {"stars": [true, false, true], "applause": 95.0, "lines": ["a", "b"], "catches": [{"t": 1, "cause": "x"}],
		"duration_s": 400.0, "first_player_laugh_launch_s": 12.0, "first_prank_launch_s": 25.0, "launch_offset_s": 2.3,
		"laughs": [{"t": 5.0}, {"t": 40.0}, {"t": 80.0}], "dead_air_ff_pct": 25.0, "max_gap_ff_s": 11.0}
	var ok_expect := {"stars": [true, null, null], "applause": [90, 140], "lines": ["a"], "catches_max": 1,
		"duration_s": [100, 500], "first_player_laugh_s_max": 15, "first_prank_s_max": 30, "laughs_by_s": [[45, 2]],
		"dead_air_pct_max": 30, "max_gap_s_max": 12}
	assert_eq(Metrics.check_expect(rep, ok_expect), PackedStringArray())
	var bad := {"stars": [true, true, false], "applause": [100, 140], "lines": ["c"], "catches_max": 0,
		"duration_s": [120, 300], "first_player_laugh_s_max": 10, "first_prank_s_max": 20, "laughs_by_s": [[75, 4]],
		"dead_air_pct_max": 20, "max_gap_s_max": 10}
	var f := Metrics.check_expect(rep, bad)
	assert_eq(f.size(), 11, "\n".join(f))
	var all := "\n".join(f)
	for needle in ["stars[1]", "stars[2]", "applause 95.0 < min", "line 'c' not done", "1 catch(es) > max 0",
			"duration 400.0 s > max", "first player laugh at 12.00 s", "first prank at 25.00 s", "2 laugh(s) by 75 s",
			"dead air ⏩ 25.0", "longest gap ⏩ 11.0"]:
		assert_has(all, needle)


func test_summary_line_and_markdown() -> void:
	var rep := {"episode": "n01_throat_tea", "route": "ideal", "ok": true, "duration_s": 214.3, "stars": [true, true, true],
		"applause": 118.0, "lines": ["a", "b", "c", "d", "e", "f"], "catches": [], "first_player_laugh_launch_s": 7.9,
		"first_prank_launch_s": 25.0, "laughs_by_60": 5, "dead_air_pct": 12.0, "max_gap_s": 8.0, "hold_total_s": 11.0, "fail": []}
	var line := Metrics.summary_line(rep)
	assert_true(line.begins_with("[solve] n01_throat_tea ideal OK 214.3 s ★★★ 118 applause"), line)
	var md := Metrics.to_markdown([rep, {"episode": "x", "route": "slow", "ok": false, "fail": ["step 2 (bow): rejected"], "stars": []}])
	assert_has(md, "| n01_throat_tea | ideal | OK | 214.3 s | ★★★ | 118.0 | 6 | 0 |")
	assert_has(md, "## Failures")
	assert_has(md, "step 2 (bow): rejected")


func test_fallback_is_laugh_mirrors_tech() -> void:
	for e in ["reaction_accent", "squeak_bit", "panto_round", "near_miss", "combo", "meltdown_start", "door_slam"]:
		assert_true(SolverHooks.fallback_is_laugh({"e": e, "t": 1}), e)
	assert_true(SolverHooks.fallback_is_laugh({"e": "director_cue", "id": "laugh_vase"}))
	assert_false(SolverHooks.fallback_is_laugh({"e": "director_cue", "id": "ghost_squeak"}))
	assert_false(SolverHooks.fallback_is_laugh({"e": "bump", "first": false}))
	assert_true(SolverHooks.fallback_is_laugh({"e": "bump", "first": true}))
	assert_false(SolverHooks.fallback_is_laugh({"e": "rigged"}))


func test_ff_weighted_dead_air() -> void:
	# 600 ticks, input only at 1: 301..600 dead. Hidden from 301 on: those ticks weigh 1/3 (a persona that
	# re-presses ⏩ at once — the naive Stage-1 weighting; the latch delay is covered in test_s2_gate.gd).
	var lg := SolverLog.new()
	lg.ff_repress_ticks = 0
	for t in range(1, 601):
		lg.add_sample(t, {"input": t == 1, "hidden": "kitchen_pantry_curtain" if t > 300 else ""})
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r["dead_air_ff_naive_pct"]), float(r["dead_air_ff_pct"]), 0.01, "no delay: latch = naive")
	assert_almost_eq(float(r["dead_air_pct"]), 50.0, 0.1)
	assert_almost_eq(float(r["dead_air_ff_pct"]), 100.0 * 300 / (300 * 3 + 300), 0.1, "300 hidden dead ticks of 1200 thirds")
	assert_almost_eq(float(r["real_time_ff_s"]), 400 / 60.0, 0.02, "300 visible + 300/3 hidden ticks")
	assert_almost_eq(float(r["max_gap_ff_s"]), (299 * 3 + 300) / 3 / 60.0, 0.02)
