## Director: cues fire once when their conditions hold; safety net; can't-fail hook; scripted end.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_cues_fire_once() -> void:
	var w := U.world("fx_prologue")
	var log := U.run(w, 300)
	var vase := U.find(log, SimEvents.DIRECTOR_CUE, {"id": "laugh_vase"})
	assert_eq(vase.size(), 1)
	assert_eq(int(vase[0]["t"]), 138, "tick_ge_s 2.3")
	assert_true(SimEvents.is_laugh(vase[0]), "laugh_ cues are laughs")
	assert_eq(U.find(log, SimEvents.DIRECTOR_CUE, {"id": "ghost_squeak"}).size(), 1)
	assert_true(U.first(log, SimEvents.DIRECTOR_CUE, {"id": "ghost_honey"}).is_empty())
	log = U.run(w, 10)
	log.append_array(U.step(w, [SimCmd.squeak()]))
	log.append_array(U.run(w, 2))
	assert_eq(U.find(log, SimEvents.DIRECTOR_CUE, {"id": "ghost_honey"}).size(), 1, "event_seen squeak")
	assert_false(SimEvents.is_laugh(U.first(log, SimEvents.DIRECTOR_CUE, {"id": "ghost_honey"})))


func test_safety_net_on_and_off() -> void:
	var w := U.world("fx_prologue")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	U.walk_to(w, "kitchen_honey", 600, log)
	U.rig_hold(w, 100, log)
	var on := U.run_until(w, SimEvents.SAFETY_NET, {"on": true}, 800, log)
	assert_false(on.is_empty(), "he is coming and she isn't hidden")
	log.append_array(U.step(w, [SimCmd.go("kitchen_pantry_curtain", true)]))
	var off := U.run_until(w, SimEvents.SAFETY_NET, {"on": false}, 200, log)
	assert_false(off.is_empty())


func test_cant_fail_figgis_hook() -> void:
	var w := U.world("fx_prologue")
	# stand in front of him in the parlour (the hall is off-limits; he faces the kitchen side? no: left)
	U.place_hush(w, "parlour", 1550)
	var log: Array = []
	var hook := U.run_until(w, SimEvents.FIGGIS_HOOK, {}, 300, log)
	assert_false(hook.is_empty(), "a full \"?\" in the Prologue")
	assert_eq(int(hook["t"]) - int(U.first(log, SimEvents.SPOT_START)["t"]), 119, "2.0 s window")
	assert_eq(w.hush.state, SimHush.HIDDEN)
	assert_eq(w.db.house.hotspots[w.hush.hidden_spot].id, "parlour_piano_back")
	assert_true(U.first(log, SimEvents.CHASE_START).is_empty())
	assert_true(U.first(log, SimEvents.CAUGHT).is_empty())


func test_prologue_scripted_end() -> void:
	var w := U.world("fx_prologue")
	w.bits.first_squeak_tick = 1
	U.force_rig(w, "achoo_ria")
	U.force_rig(w, "allegro_go_go")
	U.place_hush_at(w, "kitchen_pantry_curtain")
	w.hush.state = SimHush.HIDDEN
	w.hush.hidden_spot = w.hush.at_hotspot
	var log := U.run(w, 20000)
	assert_true(w.ended)
	assert_eq(w.end_reason, "prologue_done")
	var acts := []
	for ev in U.find(log, SimEvents.B_ACTIVITY):
		acts.append(str(ev["id"]))
	assert_eq(acts, ["warmup", "warmup", "tea", "fixup_mirror", "warmup", "hunt"], str(acts))
	assert_false(U.first(log, SimEvents.PRANK_FIRE, {"prank": "allegro_go_go"}).is_empty())
