## Entry warning ≥ 90 ticks before every non-chase entry into Hush's room, with a doorway pause.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_warning_exactly_90_ticks_before_entry() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles"], "parlour", 1700, "kitchen", 3700))
	var log: Array = []
	var warn := U.run_until(w, SimEvents.ENTRY_WARNING, {"room": "kitchen"}, 2000, log)
	assert_false(warn.is_empty())
	assert_eq(int(warn["eta"]), 90)
	var enter := U.run_until(w, SimEvents.B_ROOM, {"room": "kitchen"}, 200, log)
	assert_eq(int(enter["t"]) - int(warn["t"]), 90)
	assert_true(U.first(log, SimEvents.DOORWAY_PAUSE).is_empty(), "no pause needed")


func test_late_entry_gets_a_doorway_pause() -> void:
	# Hush is in the hall; Bellows walks parlour → kitchen. She pops into the kitchen when he is 20 ticks out.
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles"], "parlour", 1700, "hall", 700))
	var log: Array = []
	U.run_until_pred(w, func(x: SimWorld) -> bool:
		return x.bellows.path != null and x.bellows.path.eta_to_room(x.room_idx("kitchen")) == 21, 2000, log)
	U.place_hush(w, "kitchen", 3700)
	var warn := U.run_until(w, SimEvents.ENTRY_WARNING, {"room": "kitchen"}, 5, log)
	assert_false(warn.is_empty())
	assert_eq(int(warn["eta"]), 20)
	var pause := U.first(log, SimEvents.DOORWAY_PAUSE)
	assert_eq(int(pause["ticks"]), 70)
	var enter := U.run_until(w, SimEvents.B_ROOM, {"room": "kitchen"}, 300, log)
	assert_eq(int(enter["t"]) - int(warn["t"]), 90, "the pause fills the gap to 1.5 s")


func test_entry_at_the_portal_still_warned_90() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles"], "parlour", 1700, "hall", 700))
	var log: Array = []
	U.run_until_pred(w, func(x: SimWorld) -> bool:
		return x.bellows.path != null and x.bellows.path.eta_to_room(x.room_idx("kitchen")) <= 1, 2000, log)
	U.place_hush(w, "kitchen", 3700)
	var warn := U.run_until(w, SimEvents.ENTRY_WARNING, {"room": "kitchen"}, 5, log)
	var enter := U.run_until(w, SimEvents.B_ROOM, {"room": "kitchen"}, 300, log)
	assert_eq(int(enter["t"]) - int(warn["t"]), 90)


func test_stairs_entry_is_warned() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["radiator"], "hall", 900, "landing", 1650))
	var log: Array = []
	var warn := U.run_until(w, SimEvents.ENTRY_WARNING, {"room": "landing"}, 2000, log)
	assert_false(warn.is_empty())
	var enter := U.run_until(w, SimEvents.B_ROOM, {"room": "landing"}, 300, log)
	assert_ge(int(enter["t"]) - int(warn["t"]), 90)


func test_no_warning_in_a_chase() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1450 + 150))
	var log: Array = []
	assert_false(U.run_until(w, SimEvents.SPOTTED, {}, 200, log).is_empty(), "she stood in front of him")
	log.append_array(U.step(w, [SimCmd.move("hall", 700, true)]))
	log.append_array(U.run(w, 200))
	assert_false(U.first(log, SimEvents.CHASE_START).is_empty())
	var enter := U.find(log, SimEvents.B_ROOM, {"room": "hall"})
	assert_gt(enter.size(), 0, "he chased her into the hall")
	var warned := false
	for ev in U.find(log, SimEvents.ENTRY_WARNING, {"room": "hall"}):
		warned = true
	assert_false(warned, "chases are exempt")


func test_every_entry_warned_while_wandering() -> void:
	var w := U.world("fx_act1", {"invariants": true})
	var rng := Rng.new(99)
	var spots := ["hall_coat_cupboard", "hall_confiscated_box", "parlour_piano_back", "kitchen_table",
		"kitchen_pantry_curtain", "kitchen_honey", "parlour_recliner", "hall_mirror"]
	var log: Array = []
	var last_warn := {}
	var bad := 0
	var entries := 0
	for t in 12000:
		var cmds: Array = []
		if t % 240 == 0:
			cmds.append(SimCmd.go(spots[rng.range_int(0, spots.size() - 1)]))
		w.step(cmds)
		for ev in w.drain_events():
			var e := str(ev["e"])
			if e == SimEvents.ENTRY_WARNING:
				last_warn[str(ev["room"])] = int(ev["t"])
			elif e == SimEvents.B_ROOM and w.bellows.state != SimBellows.CHASE and w.bellows.state != SimBellows.REACTING \
					and str(ev["room"]) == w.room_id(w.hush.room):
				entries += 1
				if int(ev["t"]) - int(last_warn.get(str(ev["room"]), -100000)) < 90:
					bad += 1
	assert_eq(bad, 0, "%d of %d entries without a 1.5 s warning" % [bad, entries])
	assert_eq(int(w.invariant_counters["entry_without_warning"]), 0)
