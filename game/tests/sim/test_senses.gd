## Senses: every row of the sight table, facing, never behind, doorway look-through, idle = moving,
## reacting + 60 blind, stairs, hidden.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


## A world where Bellows is performing `act` (long) at its station.
func _performing(act: String, files_patch: Callable = Callable()) -> SimWorld:
	var w := U.world_patched("fx_act1", U.loop_patch([act], "kitchen", 3900, "hall", 600), {}, files_patch)
	var st := w.db.house.stations[w.db.activities[act].station_idx]
	w.bellows.room = st.room_idx
	w.bellows.x_sub = st.stand_sub
	w.bellows.path = null
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": act}, 100)
	U.run(w, 2)
	return w


func _sees(w: SimWorld, dx_px: int, frozen: bool) -> bool:
	var b := w.bellows
	U.place_hush(w, w.room_id(b.room), Fx.to_px(b.x_sub) + dx_px)
	if frozen:
		w.hush.state = SimHush.FROZEN
	return w.senses.can_see(w)


func test_specs_off_moving_600_frozen_250() -> void:
	var w := _performing("tea")
	assert_false(w.bellows.specs_on)
	assert_true(_sees(w, 590, false))
	assert_false(_sees(w, 610, false))
	assert_true(_sees(w, 240, true))
	assert_false(_sees(w, 260, true))


func test_idle_counts_as_moving() -> void:
	var w := _performing("tea")
	assert_true(_sees(w, 500, false), "an idle Hush fidgets")
	assert_eq(w.hush.state, SimHush.IDLE)


func test_specs_on_whole_room_and_frozen_600() -> void:
	var w := _performing("paper")
	assert_true(w.bellows.specs_on)
	assert_true(_sees(w, 700, false), "to the wall")
	assert_true(_sees(w, 590, true))
	assert_false(_sees(w, 610, true))


func test_absorbed_moving_250_frozen_0() -> void:
	var w := _performing("bath", func(f: Dictionary) -> void: f["activities"]["activities"]["bath"]["facing"] = -1)
	assert_true(_sees(w, -240, false))
	assert_false(_sees(w, -260, false))
	assert_false(_sees(w, -20, true))


func test_blinded_150_150() -> void:
	var w := _performing("tea")
	w.bellows.blinded_until = w.tick + 10000
	U.run(w, 1)
	assert_true(w.bellows.blinded)
	assert_eq(w.bubble()["glyph"], "blinded")
	assert_true(_sees(w, 140, false))
	assert_false(_sees(w, 160, false))
	assert_true(_sees(w, 140, true))
	assert_false(_sees(w, 160, true))


func test_blind_residue_blinds_until_cleared() -> void:
	var w := _performing("tea")
	w.residue.add(w, "FRAZZLED", true)
	U.run(w, 1)
	assert_true(w.bellows.blinded)
	assert_false(_sees(w, 300, false))
	w.residue.clear(w, "FRAZZLED")
	U.run(w, 1)
	assert_false(w.bellows.blinded)


func test_exhausted_150_150() -> void:
	var w := _performing("tea")
	w.bellows.start_exhausted(w)
	U.run(w, 1)
	assert_eq(w.senses.sight_ranges(w), [150, 150])


func test_asleep_blind_eyes_shut_reacting_meltdown_zero() -> void:
	var w := _performing("nap")
	assert_true(w.bellows.asleep)
	assert_eq(w.bubble()["glyph"], "asleep")
	assert_false(_sees(w, 100, false))
	w = _performing("cloak")
	assert_false(_sees(w, 50, false), "dressing with his eyes shut")
	w = _performing("tea")
	w.bellows.state = SimBellows.REACTING
	assert_eq(w.senses.sight_ranges(w), [0, 0])
	w.bellows.state = SimBellows.MELTDOWN
	assert_eq(w.senses.sight_ranges(w), [0, 0])


func test_reacting_plus_60_blind() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3700, "hall", 600))
	U.force_rig(w, "tap_dance")
	var log: Array = []
	var end := U.run_until(w, SimEvents.REACTION_END, {"prank": "tap_dance"}, 400, log)
	assert_false(end.is_empty())
	var t_end := int(end["t"])
	assert_eq(w.bellows.blind_after_until, t_end + 60)
	assert_eq(w.senses.sight_ranges(w), [0, 0], "blind at the reaction end")
	U.run(w, 58)
	assert_eq(w.tick, t_end + 58)
	assert_eq(w.senses.sight_ranges(w), [0, 0])
	U.run(w, 2)
	assert_ne(w.senses.sight_ranges(w), [0, 0], "sees again 60 ticks after")


func test_behind_is_never_seen() -> void:
	var w := _performing("paper")
	assert_false(_sees(w, -100, false))
	assert_false(_sees(w, -10, false))


func test_doorway_look_through() -> void:
	# tea turned to face the parlour doorway (2800), 100 px from it
	var w := _performing("tea", func(f: Dictionary) -> void: f["activities"]["activities"]["tea"]["facing"] = -1)
	U.place_hush(w, "parlour", 2510)
	assert_true(w.senses.can_see(w), "290 px into the next room, moving")
	U.place_hush(w, "parlour", 2490)
	assert_false(w.senses.can_see(w), "beyond 300 px")
	U.place_hush(w, "parlour", 2700)
	w.hush.state = SimHush.FROZEN
	assert_true(w.senses.can_see(w), "frozen 200 px from him")
	U.place_hush(w, "parlour", 2600)
	w.hush.state = SimHush.FROZEN
	assert_false(w.senses.can_see(w), "frozen 300 px from him: beyond 250")


func test_no_look_through_when_far_from_the_doorway() -> void:
	# pickles at 3130 faced left: 330 px from the doorway
	var w := _performing("pickles", func(f: Dictionary) -> void: f["activities"]["activities"]["pickles"]["facing"] = -1)
	U.place_hush(w, "parlour", 2750)
	assert_false(w.senses.can_see(w))


func test_head_turn_looks_behind_for_1s() -> void:
	var w := _performing("pickles")
	U.place_hush(w, "kitchen", 2900)
	assert_false(w.senses.can_see(w))
	var e := U.step(w, [SimCmd.squeak()])
	assert_false(U.first(e, SimEvents.HEAD_TURN).is_empty(), "pickles has no squeak bit")
	assert_true(w.senses.can_see(w), "turned toward the squeak")
	U.place_hush(w, "hall", 700)
	U.run(w, SimConst.HEAD_TURN_TICKS)
	U.place_hush(w, "kitchen", 2900)
	assert_false(w.senses.can_see(w))


func test_never_across_the_stairs_or_into_unwatched_hiding() -> void:
	var w := _performing("radiator")
	U.place_hush(w, "hall", 1500)
	assert_false(w.senses.can_see(w))
	w = _performing("tea")
	U.place_hush_at(w, "kitchen_table")
	w.hush.state = SimHush.HIDDEN
	w.hush.hidden_spot = w.hush.at_hotspot
	w.hush.watched_spot = -1
	assert_false(w.senses.can_see(w))
	w.hush.watched_spot = w.hush.hidden_spot
	assert_true(w.senses.can_see(w), "watched: the spot is in plain view")
