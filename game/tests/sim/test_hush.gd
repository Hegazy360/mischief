## SimHush: go + auto actions, idempotence, the queue, pins, pop out, freeze, squeak arm, tray, restock.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_go_container_rummages_then_picks_single_item() -> void:
	var w := U.quiet_world()
	var log: Array = []
	assert_true(U.walk_to(w, "kitchen_pantry_shelf", 600, log))
	assert_eq(w.hush.state, SimHush.RUMMAGE)
	var t0 := w.tick
	var ev := U.run_until(w, SimEvents.PICK, {}, 100, log)
	assert_eq(w.tick - t0, SimConst.RUMMAGE_TICKS)
	assert_eq(str(ev.get("item", "")), "flour")
	assert_eq(w.hush.carrying, PackedStringArray(["flour"]))
	assert_false(U.first(log, SimEvents.RUMMAGE).is_empty())


func test_container_with_two_items_opens_pick_window() -> void:
	var w := U.quiet_world("fx_act1", {}, func(f: Dictionary) -> void:
		(f["episodes"]["fx_act1"]["script"] as Array).append({"id": "cold", "kind": "prank", "prank": "cold_open", "req": false}))
	var log: Array = []
	U.walk_to(w, "kitchen_fridge", 600, log)
	var ev := U.run_until(w, SimEvents.PICK, {}, 100, log)
	assert_eq(str(ev.get("item", "")), "butter", "one useful item (kipper is not needed tonight): taken at once")
	assert_true(U.first(log, SimEvents.PICK_WINDOW).is_empty())
	w = U.quiet_world("fx_act1", {}, func(f: Dictionary) -> void:
		var s: Array = f["episodes"]["fx_act1"]["script"]
		s.append({"id": "cold", "kind": "prank", "prank": "cold_open", "req": false})
		s.append({"id": "fish", "kind": "prank", "prank": "something_fishy", "req": false}))
	U.walk_to(w, "kitchen_fridge", 600)
	ev = U.run_until(w, SimEvents.PICK_WINDOW, {}, 100)
	assert_eq(str(ev.get("items", "")), "butter,kipper")
	assert_eq(w.hush.state, SimHush.PICK_WINDOW)
	var evs := U.step(w, [SimCmd.pick("kipper")])
	assert_false(U.first(evs, SimEvents.PICK, {"item": "kipper"}).is_empty())
	assert_eq(w.hush.state, SimHush.IDLE)
	# the window times out after 180 ticks if nothing is picked
	var w2 := U.quiet_world("fx_act1", {}, func(f: Dictionary) -> void:
		var s: Array = f["episodes"]["fx_act1"]["script"]
		s.append({"id": "cold", "kind": "prank", "prank": "cold_open", "req": false})
		s.append({"id": "fish", "kind": "prank", "prank": "something_fishy", "req": false}))
	U.walk_to(w2, "kitchen_fridge", 600)
	U.run_until(w2, SimEvents.PICK_WINDOW, {}, 100)
	U.run(w2, SimConst.PICK_WINDOW_TICKS)
	assert_eq(w2.hush.state, SimHush.IDLE)
	# picking still works while standing at it
	var e2 := U.step(w2, [SimCmd.pick("butter")])
	assert_false(U.first(e2, SimEvents.PICK, {"item": "butter"}).is_empty())


func test_go_hiding_dives_and_hides() -> void:
	var w := U.quiet_world()
	var log: Array = []
	U.walk_to(w, "kitchen_pantry_curtain", 600, log)
	assert_eq(w.hush.state, SimHush.DIVING)
	var ev := U.run_until(w, SimEvents.HIDE, {}, 60, log)
	assert_eq(str(ev.get("spot", "")), "kitchen_pantry_curtain")
	assert_false(bool(ev.get("watched", true)))
	assert_eq(w.hush.state, SimHush.HIDDEN)
	assert_false(w.hush.is_moving(w.tick))


func test_go_rig_point_arrives_and_faces_only() -> void:
	var w := U.quiet_world()
	var log: Array = []
	U.walk_to(w, "kitchen_honey", 600, log)
	U.run(w, 5)
	assert_eq(w.hush.state, SimHush.IDLE)
	assert_eq(w.hush.at_hotspot, w.db.house.hotspot_index["kitchen_honey"])
	assert_eq(w.prank_state("achoo_ria"), Pranks.AVAILABLE, "rigs never auto-execute")


func test_go_stairs_traverses() -> void:
	var w := U.quiet_world("fx_meltdown")
	U.place_hush(w, "hall", 1300)
	var log: Array = []
	w.step([SimCmd.go("stairs_foot")])
	U.run_until(w, SimEvents.HUSH_ARRIVE, {"hotspot": "stairs_foot"}, 400, log)
	assert_eq(w.room_id(w.hush.room), "landing")
	assert_eq(w.hush.x_sub, 1050 * SimConst.SUB)
	assert_false(U.first(log, SimEvents.HUSH_ROOM, {"room": "landing"}).is_empty())


func test_repeat_go_same_target_is_idempotent() -> void:
	var w := U.quiet_world()
	var e1 := U.step(w, [SimCmd.go("kitchen_honey")])
	assert_eq(U.find(e1, SimEvents.HUSH_GO).size(), 1)
	var serial := w.hush.path_serial
	var e2 := U.step(w, [SimCmd.go("kitchen_honey")])
	assert_eq(U.find(e2, SimEvents.HUSH_GO).size(), 0)
	assert_eq(w.hush.path_serial, serial)
	# a second tap with run upgrades the walk (no new path)
	var e3 := U.step(w, [SimCmd.go("kitchen_honey", true)])
	assert_true(w.hush.run)
	assert_eq(w.hush.path_serial, serial)
	assert_eq(U.find(e3, SimEvents.HUSH_GO, {"run": true}).size(), 1)


func test_queue_rig_then_dive_when_ring_completes() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "kitchen_honey")
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.RIG_START).is_empty())
	U.run(w, 10)
	var eq := U.step(w, [SimCmd.go("kitchen_pantry_curtain")])
	assert_eq(w.hush.queued.get("hotspot", ""), "kitchen_pantry_curtain")
	assert_eq(w.hush.state, SimHush.RIGGING, "a go while busy is queued")
	assert_false(U.first(eq, SimEvents.CMD_QUEUED, {"c": "go", "why": "busy", "target": "kitchen_pantry_curtain"}).is_empty(),
		"the held go says so at once")
	var log: Array = []
	var ev := U.run_until(w, SimEvents.RIGGED, {}, 100, log)
	assert_false(ev.is_empty())
	assert_true(w.hush.is_travelling(), "the queued go ran the tick the ring completed")
	U.run_until(w, SimEvents.HIDE, {}, 120)
	assert_eq(w.hush.state, SimHush.HIDDEN)


func test_queue_runs_when_rig_is_released() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "kitchen_honey")
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 10)
	U.step(w, [SimCmd.move("kitchen", 3200)])
	assert_eq(w.hush.state, SimHush.RIGGING)
	var e := U.step(w, [SimCmd.rig(false)])
	assert_false(U.first(e, SimEvents.RIG_PAUSE).is_empty())
	assert_true(w.hush.is_travelling())
	assert_eq(w.rig_progress_pm("achoo_ria"), Fx.div(12 * 1000, 48), "release keeps progress (12 ticks held)")


func test_newer_queued_command_replaces_older() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "kitchen_honey")
	U.step(w, [SimCmd.rig(true)])
	U.step(w, [SimCmd.go("kitchen_table")])
	U.step(w, [SimCmd.go("kitchen_pantry_curtain")])
	assert_eq(w.hush.queued.get("hotspot", ""), "kitchen_pantry_curtain")


func test_pins_while_hidden_and_pop_out_to_pin() -> void:
	var w := U.quiet_world()
	U.walk_to(w, "kitchen_pantry_curtain")
	U.run_until(w, SimEvents.HIDE)
	var e := U.step(w, [SimCmd.go("kitchen_honey")])
	assert_false(U.first(e, SimEvents.PIN, {"room": "kitchen", "x": 2990}).is_empty(), "taps while hidden become pins")
	assert_eq(w.hush.state, SimHush.HIDDEN)
	e = U.step(w, [SimCmd.pin("kitchen", 3200)])
	assert_false(U.first(e, SimEvents.PIN, {"x": 3200}).is_empty(), "a new pin replaces the old")
	U.run(w, 30)
	assert_eq(w.hush.state, SimHush.HIDDEN, "a pin never moves her")
	e = U.step(w, [SimCmd.pop_out(true)])
	assert_false(U.first(e, SimEvents.POP_OUT).is_empty())
	U.run(w, SimConst.POP_TICKS + 1)
	assert_eq(w.hush.state, SimHush.RUN, "pops out and runs to the pin")
	assert_eq(w.hush.path.final_x(), 3200 * SimConst.SUB)


func test_pins_while_frozen_then_release_goes() -> void:
	var w := U.quiet_world()
	U.step(w, [SimCmd.freeze(true)])
	assert_eq(w.hush.state, SimHush.FROZEN)
	var e := U.step(w, [SimCmd.move("kitchen", 3000)])
	assert_false(U.first(e, SimEvents.PIN).is_empty())
	assert_eq(w.hush.state, SimHush.FROZEN)
	U.step(w, [SimCmd.freeze(false)])
	assert_eq(w.hush.state, SimHush.WALK)
	assert_eq(w.hush.path.final_x(), 3000 * SimConst.SUB)


func test_pin_rejected_when_not_hidden_or_frozen() -> void:
	var w := U.quiet_world()
	var e := U.step(w, [SimCmd.pin("kitchen", 3000)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "pin"}).is_empty())


func test_freeze_stops_and_is_not_moving() -> void:
	var w := U.quiet_world()
	U.step(w, [SimCmd.move("kitchen", 3000)])
	U.run(w, 5)
	var x := w.hush.x_sub
	var e := U.step(w, [SimCmd.freeze(true)])
	assert_false(U.first(e, SimEvents.FREEZE, {"on": true}).is_empty())
	U.run(w, 20)
	assert_eq(w.hush.x_sub, x)
	assert_false(w.hush.is_moving(w.tick))
	e = U.step(w, [SimCmd.freeze(false)])
	assert_false(U.first(e, SimEvents.FREEZE, {"on": false}).is_empty())
	assert_true(w.hush.is_moving(w.tick), "idle counts as moving")


func test_squeak_arm_counts_as_moving_for_18_ticks() -> void:
	var w := U.quiet_world()
	U.step(w, [SimCmd.freeze(true)])
	U.step(w, [SimCmd.squeak()])
	var t0 := w.tick
	assert_true(w.hush.is_moving(w.tick))
	assert_eq(w.hush.state, SimHush.FROZEN)
	U.run(w, SimConst.SQUEAK_ARM_TICKS - 1)
	assert_true(w.hush.is_moving(w.tick))
	U.run(w, 1)
	assert_eq(w.tick - t0, SimConst.SQUEAK_ARM_TICKS)
	assert_false(w.hush.is_moving(w.tick))


func test_no_squeak_from_a_hiding_spot() -> void:
	var w := U.quiet_world()
	U.walk_to(w, "kitchen_pantry_curtain")
	U.run_until(w, SimEvents.HIDE)
	var e := U.step(w, [SimCmd.squeak()])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "squeak", "why": "hidden"}).is_empty())
	assert_true(U.first(e, SimEvents.SQUEAK).is_empty())


func test_standing_squeak_is_busy_and_queues() -> void:
	var w := U.quiet_world()
	U.step(w, [SimCmd.squeak()])
	assert_eq(w.hush.state, SimHush.SQUEAKING)
	var e := U.step(w, [SimCmd.move("kitchen", 3000)])
	assert_eq(w.hush.state, SimHush.SQUEAKING)
	assert_false(U.first(e, SimEvents.CMD_QUEUED, {"c": "move", "why": "busy", "target": "kitchen:3000"}).is_empty())
	U.run(w, SimConst.SQUEAK_ARM_TICKS)
	assert_true(w.hush.is_travelling())


func test_tray_cap_oldest_flies_home() -> void:
	var w := U.quiet_world("fx_act1", {}, func(f: Dictionary) -> void:
		var s: Array = f["episodes"]["fx_act1"]["script"]
		for id in ["cold_open", "something_fishy", "bellows_blows", "pipe_down"]:
			s.append({"id": id, "kind": "prank", "prank": id, "req": false}))
	U.place_hush_at(w, "kitchen_fridge")
	U.step(w, [SimCmd.pick("butter")])
	U.step(w, [SimCmd.pick("kipper")])
	U.place_hush_at(w, "kitchen_pantry_shelf")
	U.step(w, [SimCmd.pick("flour")])
	U.place_hush_at(w, "hall_confiscated_box")
	U.step(w, [SimCmd.pick("squeaker")])
	assert_eq(w.hush.carrying.size(), 4)
	var e := U.step(w, [SimCmd.pick("balloon")])
	assert_false(U.first(e, SimEvents.ITEM_HOME, {"item": "butter"}).is_empty())
	assert_eq(w.hush.carrying, PackedStringArray(["kipper", "flour", "squeaker", "balloon"]))
	assert_true(w.hotspot_state("kitchen_fridge")["stock"].has("butter"), "back in stock at once")


func test_used_item_restocks_after_20s() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "hall_confiscated_box")
	U.step(w, [SimCmd.pick("squeaker")])
	U.place_hush_at(w, "kitchen_kettle")
	var log: Array = []
	assert_true(U.rig_hold(w, 200, log))
	assert_eq(w.prank_state("kettle_drum"), Pranks.RIGGED)
	assert_eq(w.hush.carrying.size(), 0, "consumed on step completion")
	var done_t: int = U.first(log, SimEvents.RIG_STEP_DONE)["t"]
	assert_false(w.hotspot_state("hall_confiscated_box")["stock"].has("squeaker"))
	var ev := U.run_until(w, SimEvents.RESTOCK, {"item": "squeaker"}, 1300)
	assert_eq(int(ev["t"]) - done_t, SimConst.RESTOCK_TICKS)
	assert_eq(str(ev["container"]), "hall_confiscated_box")


func test_rig_needs_the_item() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "kitchen_kettle")
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "rig", "why": "needs_item"}).is_empty())
	var hs := w.hotspot_state("kitchen_kettle")
	assert_eq(hs["needs_item"], "squeaker")


func test_locked_rooms_are_rejected() -> void:
	var w := U.world("fx_prologue")
	var e := U.step(w, [SimCmd.go("hall_confiscated_box")])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "go", "why": "locked"}).is_empty())
	e = U.step(w, [SimCmd.move("hall", 900)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "move", "why": "locked"}).is_empty())


func test_unknown_commands_rejected_never_error() -> void:
	var w := U.quiet_world()
	var e := U.step(w, [{"c": "teleport"}, {"c": "go", "hotspot": "nowhere"}, {"c": "pick", "item": "cake"}, "junk"])
	assert_eq(U.find(e, SimEvents.CMD_REJECTED).size(), 4)
