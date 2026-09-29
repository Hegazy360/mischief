## Caught: busted cam → Lecture → doorstep (+204) → control (+240); items home; −5.0; tomato; the Hook.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _caught_world(tomatoes: int, config: Dictionary = {}) -> SimWorld:
	return U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1550).call(ep)
		ep["rules"]["tomatoes"] = tomatoes, config)


func test_timeline_items_applause_tomato() -> void:
	var w := _caught_world(3)
	w.hush.carrying = PackedStringArray(["squeaker"])
	w.hush.carry_uses = PackedInt32Array([1])
	w.pranks.item_carried(w, "squeaker")
	w.scoring.applause = 200
	var log: Array = []
	var c := U.run_until(w, SimEvents.CAUGHT, {}, 300, log)
	var t0 := int(c["t"])
	assert_false(U.first(log, SimEvents.ITEM_HOME, {"item": "squeaker"}).is_empty(), "carried items fly home")
	assert_eq(w.hush.carrying.size(), 0)
	assert_eq(w.applause_tenths(), 150, "−5 Applause")
	assert_eq(w.bellows.state, SimBellows.CAUGHT_HOLD)
	assert_eq(int(U.first(log, SimEvents.BUSTED_CAM)["t"]), t0)
	var lec := U.run_until(w, SimEvents.LECTURE, {}, 100, log)
	assert_eq(int(lec["t"]) - t0, 60)
	var ds := U.run_until(w, SimEvents.DOORSTEP, {}, 200, log)
	assert_eq(int(ds["t"]) - t0, 204)
	assert_eq(w.room_id(w.hush.room), "porch")
	assert_eq(w.hush.x_sub, 350 * SimConst.SUB)
	assert_eq(int(U.first(log, SimEvents.TOMATO)["n"]), 1)
	assert_eq(w.tomatoes(), 1)
	U.run(w, 35)
	assert_eq(w.hush.state, SimHush.CAUGHT, "no control before +240")
	U.run(w, 1)
	assert_eq(w.tick - t0, 240)
	assert_eq(w.hush.state, SimHush.IDLE, "control at +240")
	assert_gt(w.bellows.on_guard_until, w.tick)


func test_commands_during_the_lecture_are_queued() -> void:
	var w := _caught_world(3)
	U.run_until(w, SimEvents.CAUGHT, {}, 300)
	U.run(w, 10)
	U.step(w, [SimCmd.go("hall_front_door")])
	assert_eq(w.hush.state, SimHush.CAUGHT)
	U.run_until(w, SimEvents.HUSH_GO, {}, 300)
	assert_true(w.hush.is_travelling(), "runs the moment control returns")


func test_hook_at_max_tomatoes() -> void:
	var w := _caught_world(1)
	var log: Array = []
	var hook := U.run_until(w, SimEvents.HOOK, {}, 600, log)
	assert_false(hook.is_empty())
	assert_true(w.ended)
	assert_eq(w.end_reason, "hook")
	assert_false(U.first(log, SimEvents.NIGHT_END, {"reason": "hook"}).is_empty())


func test_unlimited_tomatoes_when_minus_one_and_in_relaxed() -> void:
	for cfg in [[-1, {}], [1, {"relaxed": true}]]:
		var w := _caught_world(cfg[0], cfg[1])
		assert_eq(w.tomatoes_max(), -1)
		var n := 0
		for i in 3:
			if not U.run_until(w, SimEvents.CAUGHT, {}, 1500).is_empty():
				n += 1
				U.run(w, 240)
				U.place_hush(w, "parlour", Fx.to_px(w.bellows.x_sub) + 150 * w.bellows.facing)
		assert_eq(n, 3)
		assert_false(w.ended)


func test_applause_never_below_zero() -> void:
	var w := _caught_world(-1)
	U.run_until(w, SimEvents.CAUGHT, {}, 300)
	assert_eq(w.applause_tenths(), 0)
