## The bump rule: first bump = pardon, then the meter opens after 2 steps; later bumps open it at once;
## never an instant catch.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _world() -> SimWorld:
	# long fill so the approach alone doesn't spot her; he walks pickles (3130) → rinse (3740)
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["pickles", "rinse"], "kitchen", 3130, "kitchen", 3500).call(ep)
		ep["rules"]["spot_fill_s"] = 3.0)
	U.step(w, [SimCmd.freeze(true)])
	return w


func test_first_bump_is_a_pardon_then_the_meter_opens_after_two_steps() -> void:
	var w := _world()
	var log: Array = []
	var bump := U.run_until(w, SimEvents.BUMP, {}, 800, log)
	assert_true(bool(bump["first"]))
	assert_eq(w.bellows.spot_meter, 0, "the meter resets for the gag")
	var t_bump := int(bump["t"])
	var start := U.run_until(w, SimEvents.SPOT_START, {}, 300, log)
	assert_false(start.is_empty(), "he double-takes into the normal window")
	assert_eq(int(start["t"]) - t_bump, SimConst.BUMP_PAT_TICKS + SimConst.BUMP_WALK_ON_TICKS + SimConst.BUMP_TURN_TICKS)
	assert_true(SimEvents.is_laugh(bump))
	assert_true(U.first(log, SimEvents.CAUGHT).is_empty(), "a bump is never an instant catch")


func test_later_bumps_open_the_meter_at_once() -> void:
	var w := _world()
	var log: Array = []
	U.run_until(w, SimEvents.BUMP, {}, 800, log)
	# she slips away, lets him go on, and freezes in his path again next loop
	U.step(w, [SimCmd.freeze(false)])
	U.place_hush(w, "hall", 700)
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "pickles"}, 3000, log)
	U.place_hush(w, "kitchen", 3500)
	U.step(w, [SimCmd.freeze(true)])
	var bump := U.run_until(w, SimEvents.BUMP, {}, 800, log)
	assert_false(bump.is_empty())
	assert_false(bool(bump["first"]))
	var meter := w.bellows.spot_meter
	assert_gt(meter, 0, "the meter was already filling and keeps going")
	var x := w.bellows.x_sub
	U.run(w, 10)
	assert_eq(w.bellows.x_sub, x, "a later bump stops him")
	assert_gt(w.bellows.spot_meter, meter)
