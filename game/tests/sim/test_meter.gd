## The "?" meter: fill per rules (and relaxed), drain 2×, near miss (≥ 50 %) with its cap, spotted.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


## Bellows brews tea at 2900 facing right for 10 s; Hush starts in the hall.
func _tea_world(config: Dictionary = {}, rules: Dictionary = {}) -> SimWorld:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["tea"], "kitchen", 2900, "hall", 600).call(ep)
		for k in rules:
			ep["rules"][k] = rules[k], config)
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "tea"}, 100)
	return w


func _ticks_to_spot(w: SimWorld) -> int:
	U.place_hush(w, "kitchen", 3300)
	var t0 := w.tick
	var ev := U.run_until(w, SimEvents.SPOTTED, {}, 400)
	return int(ev.get("t", -1)) - t0


func test_fill_time_per_rules() -> void:
	assert_eq(_ticks_to_spot(_tea_world()), 60, "Act I: 1.0 s")
	assert_eq(_ticks_to_spot(_tea_world({}, {"spot_fill_s": 0.8})), 48, "Act II: 0.8 s")
	assert_eq(_ticks_to_spot(_tea_world({"relaxed": true})), 90, "relaxed ×1.5")


func test_fill_never_below_08s() -> void:
	var files := U.raw()
	files["episodes"]["fx_act1"]["rules"]["spot_fill_s"] = 0.3
	var db := ContentDB.load_dicts(files)
	var ctx := SimCtx.build(db, db.episodes["fx_act1"], {})
	assert_eq(ctx.spot_fill, 48)
	var pro := SimCtx.build(U.db(), U.db().episodes["fx_prologue"], {})
	assert_eq(pro.spot_fill, 120, "the Prologue's larger value")


func test_meter_fills_1_and_drains_2_per_tick() -> void:
	var w := _tea_world()
	U.place_hush(w, "kitchen", 3300)
	var log := U.run(w, 20)
	assert_eq(w.bellows.spot_meter, 20)
	assert_eq(U.find(log, SimEvents.SPOT_START).size(), 1)
	U.place_hush(w, "kitchen", 2850)
	U.run(w, 5)
	assert_eq(w.bellows.spot_meter, 10)
	log = U.run(w, 5)
	assert_eq(w.bellows.spot_meter, 0)
	assert_true(U.first(log, SimEvents.NEAR_MISS).is_empty(), "peaked at 33 %: not a near miss")


func test_near_miss_at_50_percent_and_cap_of_3() -> void:
	var w := _tea_world()
	var near := 0
	var bonuses := 0
	for i in 4:
		U.place_hush(w, "kitchen", 3300)
		U.run(w, 30)
		assert_eq(w.bellows.spot_meter, 30)
		U.place_hush(w, "hall", 700)
		var log := U.run(w, 16)
		near += U.find(log, SimEvents.NEAR_MISS).size()
		bonuses += U.find(log, SimEvents.BONUS, {"kind": "near_miss"}).size()
		w.bellows.state = SimBellows.ROUTINE
		U.world_patched  # (no-op reference)
		# put him back at the tea
		w.routine.dq = PackedInt32Array()
		w.bellows.room = w.room_idx("kitchen")
		w.bellows.x_sub = 2900 * SimConst.SUB
		w.bellows.facing = 1
		w.bellows.path = null
		w.bellows.phase = SimBellows.PH_PERFORM
		w.bellows.task_kind = SimBellows.T_ACTIVITY
		w.bellows.task_act = w.db.activity_idx("tea")
		w.bellows.activity_id = "tea"
		w.bellows.activity_t = 10
		w.bellows.activity_len = 600
	assert_eq(near, 4, "every return to 0 after ≥ 50 % is a near miss")
	assert_eq(bonuses, 3, "NEAR MISS! scores at most 3 per Night")
	assert_eq(w.scoring.near_misses_scored, 3)


func test_spotted_then_chase_after_double_take() -> void:
	var w := _tea_world()
	U.place_hush(w, "kitchen", 3300)
	var log: Array = []
	var sp := U.run_until(w, SimEvents.SPOTTED, {}, 100, log)
	assert_eq(w.bellows.state, SimBellows.SPOTTED)
	var ch := U.run_until(w, SimEvents.CHASE_START, {}, 40, log)
	assert_eq(int(ch["t"]) - int(sp["t"]), SimConst.SPOTTED_TICKS)
