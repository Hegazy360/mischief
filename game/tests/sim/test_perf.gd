## Perf: an 18,000-tick Act-I Night with a scripted Hush runs in ≤ 1.5 s headless (TECH §9: ≤ 0.05 ms/tick).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_18000_ticks_under_1_5s() -> void:
	var d: Variant = TestBase.load_json("res://tests/sim/fixtures/cmds_fx_act1.json")
	var cmds: Array = d["cmds"]
	var by := {}
	for e in cmds:
		var t := int(e[0])
		if not by.has(t):
			by[t] = []
		(by[t] as Array).append(e[1])
	var w := U.world("fx_act1")
	var empty: Array = []
	var n_ev := 0
	var t0 := Time.get_ticks_usec()
	for t in range(1, 18001):
		w.step(by.get(t, empty))
		n_ev += w.drain_events().size()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[perf] 18000 ticks in %.1f ms (%.4f ms/tick), %d events" % [ms, ms / 18000.0, n_ev])
	assert_eq(w.tick, 18000)
	assert_lt(ms, 1500.0)


func test_state_hash_is_cheap_enough_for_recording() -> void:
	var w := U.world("fx_act1")
	U.run(w, 100)
	var t0 := Time.get_ticks_usec()
	for i in 100:
		w.state_hash()
	var us := (Time.get_ticks_usec() - t0) / 100.0
	print("[perf] state_hash %.0f µs" % us)
	assert_lt(us, 2000.0)
