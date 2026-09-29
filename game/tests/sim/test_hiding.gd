## Hiding: unseen = safe; watched → pull-out; in-use spots → face-to-face window.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_unseen_hiding_is_safe_for_10000_ticks() -> void:
	# He walks warmup → tea → pickles → paper → rinse past the piano all Night.
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["bellows"]["loop"] = [{"a": "warmup"}, {"a": "tea"}, {"a": "pickles"}, {"a": "paper"}, {"a": "rinse"}]
		ep["hush"]["start"] = {"room": "parlour", "x": 1840}
		ep["bellows"]["start"] = {"room": "kitchen", "x": 3700})
	U.place_hush_at(w, "parlour_piano_back")
	var e := U.step(w, [SimCmd.go("parlour_piano_back")])
	U.run_until(w, SimEvents.HIDE, {}, 30)
	assert_eq(w.hush.state, SimHush.HIDDEN)
	assert_eq(w.hush.watched_spot, -1)
	var log := U.run(w, 10000)
	assert_eq(U.find(log, SimEvents.SPOT_START).size(), 0)
	assert_eq(U.find(log, SimEvents.CAUGHT).size(), 0)
	assert_eq(w.hush.state, SimHush.HIDDEN)
	assert_gt(U.find(log, SimEvents.B_ROOM, {"room": "parlour"}).size(), 3, "he walked past many times")


func test_diving_in_view_is_watched_and_pulled_out() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "hall", 600))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "tea"}, 100)
	U.place_hush(w, "kitchen", 3400)
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.go("kitchen_table")]))
	var hide := U.run_until(w, SimEvents.HIDE, {}, 60, log)
	assert_true(bool(hide["watched"]), "he saw her dive in")
	assert_eq(w.hush.watched_spot, w.hush.hidden_spot)
	var caught := U.run_until(w, SimEvents.CAUGHT, {}, 400, log)
	assert_eq(str(caught.get("cause", "")), "pull_out")
	assert_false(U.first(log, SimEvents.SPOTTED).is_empty(), 'the "?" kept filling on the spot')


func _hide_in(w: SimWorld, spot: String) -> void:
	U.place_hush_at(w, spot)
	w.hush.state = SimHush.HIDDEN
	w.hush.hidden_spot = w.hush.at_hotspot
	w.hush.watched_spot = -1


func test_in_use_spot_face_to_face_then_caught() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["clock"], "hall", 900, "hall", 1340))
	_hide_in(w, "hall_clock_case")
	assert_true(w.hotspot_state("hall_clock_case")["in_use_next"], "red badge: he opens it next")
	var log: Array = []
	var f2f := U.run_until(w, SimEvents.FACE_TO_FACE, {"spot": "hall_clock_case"}, 600, log)
	assert_false(f2f.is_empty())
	var caught := U.run_until(w, SimEvents.CAUGHT, {}, 100, log)
	assert_eq(str(caught["cause"]), "face_to_face")
	assert_eq(int(caught["t"]) - int(f2f["t"]), SimConst.FACE_TO_FACE_TICKS)


func test_in_use_spot_escape_by_pop_out_run_is_a_near_miss() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["clock"], "hall", 900, "hall", 1340))
	_hide_in(w, "hall_clock_case")
	var log: Array = []
	U.run_until(w, SimEvents.FACE_TO_FACE, {}, 600, log)
	U.run(w, 20)
	log.append_array(U.step(w, [SimCmd.pin("parlour", 2400)]))
	log.append_array(U.step(w, [SimCmd.pop_out(true)]))
	log.append_array(U.run(w, 3))
	assert_false(U.first(log, SimEvents.NEAR_MISS).is_empty(), "BOO! — a near miss")
	log.append_array(U.run(w, 100))
	assert_true(U.first(log, SimEvents.CAUGHT).is_empty())
	assert_false(U.first(log, SimEvents.BONUS, {"kind": "near_miss"}).is_empty())
