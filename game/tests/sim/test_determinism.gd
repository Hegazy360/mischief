## Determinism: same commands → same hash every tick; clone() continues identically; reset() == fresh;
## the golden file for fx_act1; hash logging; clone speed.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")
const GOLDEN := "res://tests/sim/golden/fx_act1.json"


func _cmds() -> Array:
	var d: Variant = TestBase.load_json("res://tests/sim/fixtures/cmds_fx_act1.json")
	return d["cmds"] if typeof(d) == TYPE_DICTIONARY else []


func _by_tick(cmds: Array) -> Dictionary:
	var by := {}
	for e in cmds:
		var t := int(e[0])
		if not by.has(t):
			by[t] = []
		(by[t] as Array).append(e[1])
	return by


func test_same_commands_same_hash_every_tick() -> void:
	var cmds := _cmds()
	assert_gt(cmds.size(), 100)
	var a := PackedInt64Array()
	var b := PackedInt64Array()
	U.replay("fx_act1", cmds, 6000, a)
	U.replay("fx_act1", cmds, 6000, b)
	assert_eq(a.size(), 6000)
	var diff := -1
	for i in a.size():
		if a[i] != b[i]:
			diff = i
			break
	assert_eq(diff, -1, "first differing tick")


func test_clone_at_1000_continues_identically() -> void:
	var by := _by_tick(_cmds())
	var w := U.world("fx_act1")
	for t in range(1, 1001):
		w.step(by.get(t, []))
		w.drain_events()
	var c := w.clone()
	assert_eq(c.state_hash(), w.state_hash())
	assert_eq(c.tick, 1000)
	var diff := -1
	for t in range(1001, 5001):
		var cmds: Array = by.get(t, [])
		w.step(cmds.duplicate(true))
		c.step(cmds.duplicate(true))
		var ew := w.drain_events()
		var ec := c.drain_events()
		if w.state_hash() != c.state_hash() or ew.size() != ec.size():
			diff = t
			break
	assert_eq(diff, -1)


func test_clone_is_deep() -> void:
	var w := U.world("fx_act1")
	U.run(w, 200)
	var h := w.state_hash()
	var c := w.clone()
	c.step([SimCmd.go("kitchen_honey")])
	U.run(c, 300)
	assert_eq(w.state_hash(), h, "stepping the clone leaves the original untouched")
	assert_eq(w.tick, 200)


func test_reset_equals_fresh_create() -> void:
	var cmds := _cmds()
	var by := _by_tick(cmds)
	var w := U.world("fx_act1")
	var first := PackedInt64Array()
	for t in range(1, 3001):
		w.step(by.get(t, []))
		w.drain_events()
		first.append(w.state_hash())
	w.reset()
	assert_eq(w.tick, 0)
	var fresh := U.world("fx_act1")
	assert_eq(w.state_hash(), fresh.state_hash())
	var diff := -1
	for t in range(1, 3001):
		w.step(by.get(t, []))
		w.drain_events()
		if w.state_hash() != first[t - 1]:
			diff = t
			break
	assert_eq(diff, -1)


func test_golden_fx_act1() -> void:
	var g: Variant = TestBase.load_json(GOLDEN)
	if typeof(g) != TYPE_DICTIONARY:
		fail("golden file missing")
		return
	var db := ContentDB.load_dir(str(g["data"]))
	var w := SimWorld.create(db, str(g["episode"]), {})
	var by := _by_tick(g["cmds"])
	var want := {}
	for cp in g["checkpoints"]:
		want[int(cp[0])] = int(cp[1])
	var bad := []
	for t in range(1, int(g["ticks"]) + 1):
		w.step(by.get(t, []))
		w.drain_events()
		if want.has(t) and w.state_hash() != int(want[t]):
			bad.append(t)
	assert_eq(bad, [], "golden checkpoints that differ (regenerate only with a reason: sim_run --golden=update)")
	assert_eq(want.size(), 30)


func test_record_hash_every() -> void:
	var w := U.world("fx_act1", {"record_hash_every": 100})
	U.run(w, 350)
	assert_eq(w.hash_log.size(), 3)
	assert_eq(int(w.hash_log[0][0]), 100)


func test_clone_under_1ms() -> void:
	var by := _by_tick(_cmds())
	var w := U.world("fx_act1")
	for t in range(1, 3001):
		w.step(by.get(t, []))
		w.drain_events()
	var t0 := Time.get_ticks_usec()
	for i in 50:
		var c := w.clone()
		assert_true(c != null)
	var us := (Time.get_ticks_usec() - t0) / 50.0
	assert_lt(us, 1000.0, "clone %.0f µs" % us)
	print("[perf] clone %.0f µs" % us)
