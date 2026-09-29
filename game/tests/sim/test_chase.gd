## Chase: timings, catch radius, wheeze, search, on guard, door slam once, Chase Trips.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _spot_in_parlour(extra: Callable = Callable()) -> SimWorld:
	var w := U.world_patched("fx_meltdown", func(ep: Dictionary) -> void:
		U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1550).call(ep)
		if extra.is_valid():
			extra.call(ep))
	U.run_until(w, SimEvents.SPOTTED, {}, 200)
	return w


func test_catch_within_80px() -> void:
	var w := _spot_in_parlour()
	var log: Array = []
	U.run_until(w, SimEvents.CHASE_START, {}, 30, log)
	var ev := U.run_until(w, SimEvents.CAUGHT, {}, 100, log)
	assert_eq(str(ev["cause"]), "grab")
	assert_le(absi(w.bellows.x_sub - (1550 * 60)), SimConst.CATCH_PX * SimConst.SUB)
	assert_gt(absi(w.bellows.x_sub - (1550 * 60)), (SimConst.CATCH_PX - 10) * SimConst.SUB, "caught at the edge of the radius")


func test_chase_phases_wheeze_then_search_then_on_guard() -> void:
	var w := _spot_in_parlour()
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.go("stairs_foot", true)]))
	var start := U.run_until(w, SimEvents.CHASE_START, {}, 30, log)
	log.append_array(U.step(w, [SimCmd.go("landing_airing_cupboard", true)]))
	var wheeze := U.run_until(w, SimEvents.WHEEZE, {}, 400, log)
	assert_eq(int(wheeze["t"]) - int(start["t"]), SimConst.CHASE_RUN1)
	var end := U.run_until(w, SimEvents.CHASE_END, {}, 600, log)
	assert_eq(str(end["why"]), "lost")
	assert_ge(int(end["t"]) - int(start["t"]), SimConst.CHASE_RUN1 + SimConst.CHASE_WHEEZE + SimConst.CHASE_RUN2)
	assert_eq(w.bellows.state, SimBellows.SEARCH)
	assert_true(w.bellows.specs_on)
	var guard := U.run_until(w, SimEvents.ON_GUARD, {}, 400, log)
	assert_eq(int(guard["t"]) - int(end["t"]), SimConst.SEARCH_TICKS)
	assert_eq(w.bellows.on_guard_until, int(guard["t"]) + SimConst.ON_GUARD_TICKS)
	U.run(w, 5)
	assert_true(w.bellows.specs_on, "on guard: specs on")


func test_chase_hard_cap_600() -> void:
	# she keeps running back and forth in his sight: the cap ends it
	var w := _spot_in_parlour(func(ep: Dictionary) -> void: ep["rules"]["tomatoes"] = -1)
	var log: Array = []
	var start := U.run_until(w, SimEvents.CHASE_START, {}, 30, log)
	for i in 700:
		var cmds: Array = []
		# stay ~200 px ahead of him, in view, never caught
		var tx := Fx.to_px(w.bellows.x_sub) + 250 * w.bellows.facing
		tx = clampi(tx, 1520, 2780)
		if absi(w.hush.x_sub - w.bellows.x_sub) < 200 * 60:
			w.hush.x_sub = clampi(w.bellows.x_sub + 250 * 60 * w.bellows.facing, 1520 * 60, 2780 * 60)
			if absi(w.hush.x_sub - w.bellows.x_sub) < 200 * 60:
				w.hush.x_sub = clampi(w.bellows.x_sub - 250 * 60 * w.bellows.facing, 1520 * 60, 2780 * 60)
		w.step(cmds)
		var evs := w.drain_events()
		log.append_array(evs)
		if not U.first(evs, SimEvents.CHASE_END).is_empty():
			break
	var end := U.first(log, SimEvents.CHASE_END)
	assert_false(end.is_empty())
	assert_le(int(end["t"]) - int(start["t"]), SimConst.CHASE_CAP)


func test_door_slam_once_per_chase() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1600))
	var log: Array = []
	U.run_until(w, SimEvents.CHASE_START, {}, 200, log)
	log.append_array(U.step(w, [SimCmd.move("hall", 600, true)]))
	var slam := U.run_until(w, SimEvents.DOOR_SLAM, {}, 40, log)
	assert_false(slam.is_empty(), "she ran through the doorway with him on her heels")
	assert_true(SimEvents.is_laugh(slam))
	var x := w.bellows.x_sub
	U.run(w, 30)
	assert_eq(w.bellows.x_sub, x, "stunned (bonked the door) for 1 s")
	# another portal right in front of him: no second slam this chase
	w.chase.on_hush_portal(w, 0)
	log.append_array(w.drain_events())
	assert_eq(U.find(log, SimEvents.DOOR_SLAM).size(), 1)


func test_chase_trip_on_a_step_prank() -> void:
	var w := _spot_in_parlour()
	U.force_rig(w, "rug_burn")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.go("stairs_foot", true)]))
	U.run_until(w, SimEvents.CHASE_START, {}, 30, log)
	var fire := U.run_until(w, SimEvents.PRANK_FIRE, {"prank": "rug_burn"}, 600, log)
	assert_false(fire.is_empty(), "he chased her up the stairs over the rigged rods")
	assert_eq(str(fire["trigger"]), "step")
	assert_false(U.first(log, SimEvents.CHASE_END, {"why": "trip"}).is_empty())
	U.run_until(w, SimEvents.REACTION_END, {"prank": "rug_burn"}, 400, log)
	U.run(w, 2)
	assert_true(w.line_states()[0]["done"], "rug line")
	assert_eq(w.pranks.chase_trips, 1)


func test_step_prank_needs_steaming_outside_a_chase() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["radiator", "warmup"], "hall", 900, "kitchen", 3800))
	U.force_rig(w, "rug_burn")
	var log := U.run(w, 400)
	assert_true(U.first(log, SimEvents.PRANK_FIRE).is_empty(), "calm: he walks up unharmed")
	var w2 := U.world_patched("fx_meltdown", U.loop_patch(["radiator", "warmup"], "hall", 900, "kitchen", 3800))
	U.force_rig(w2, "rug_burn")
	U.set_temper(w2, 50)
	var log2 := U.run(w2, 400)
	assert_false(U.first(log2, SimEvents.PRANK_FIRE, {"prank": "rug_burn"}).is_empty(), "steaming: RUG BURN")
