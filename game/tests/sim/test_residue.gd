## Residue → fix-up routing (nearest on his floor by path, overrides), clearing, interrupts, combos, blind.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_nearest_station_of_the_kind_on_his_floor() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "kitchen", 3800))
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "SOAKED")].id, "st_fireplace", "ground floor")
	w.bellows.room = w.room_idx("landing")
	w.bellows.floor = 1
	w.bellows.x_sub = 1700 * 60
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "SOAKED")].id, "st_radiator", "upper floor")
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "FRAZZLED")].id, "st_hall_mirror", "none upstairs: any floor")


func test_override_first() -> void:
	var w := U.world_patched("fx_meltdown", func(ep: Dictionary) -> void:
		U.loop_patch(["warmup"], "parlour", 1700, "kitchen", 3800).call(ep)
		ep["fixup_overrides"] = {"SOAKED": "st_radiator"})
	assert_eq(w.db.house.stations[w.residue.fixup_station(w, "SOAKED")].id, "st_radiator")


func test_fixup_takes_240_ticks_and_clears() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "landing", 1700))
	U.run(w, 3)
	var log: Array = []
	w.residue.add(w, "SOAKED", false)
	log.append_array(w.drain_events())
	assert_false(U.first(log, SimEvents.RESIDUE_ADD, {"kind": "SOAKED"}).is_empty())
	assert_eq(w.bellows.residues, PackedStringArray(["SOAKED"]))
	var start := U.run_until(w, SimEvents.B_ACTIVITY, {"id": "fixup_dry"}, 2000, log)
	var clear := U.run_until(w, SimEvents.RESIDUE_CLEAR, {"kind": "SOAKED"}, 400, log)
	assert_eq(int(clear["t"]) - int(start["t"]), SimConst.FIXUP_TICKS)
	assert_eq(w.bellows.residues.size(), 0)


func test_prank_during_fixup_interrupts_and_residue_stays() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup", "paper"], "parlour", 1700, "landing", 1700))
	U.force_rig(w, "bellows_blows")
	U.run(w, 3)
	w.residue.add(w, "SOAKED", false)
	var log: Array = []
	var fire := U.run_until(w, SimEvents.PRANK_FIRE, {"prank": "bellows_blows"}, 1500, log)
	assert_eq(str(fire["trigger"]), "fixup", "the DRY fix-up at the fireplace sets it off")
	U.run_until(w, SimEvents.REACTION_END, {"prank": "bellows_blows"}, 400, log)
	assert_true(w.residue.has("SOAKED"), "interrupted: still soaked")
	log.append_array(U.run(w, 1500))
	assert_false(U.first(log, SimEvents.COMBO, {"id": "dough_man"}).is_empty(), "SOAKED + FLOURY")
	assert_eq(U.find(log, SimEvents.BONUS, {"kind": "combo"}).size(), 1)
	# the interrupted fix-up is re-queued; the new residue's fix-up follows
	var dets := U.find(log, SimEvents.B_ACTIVITY)
	var ids := []
	for d in dets:
		ids.append(str(d["id"]))
	assert_true(ids.count("fixup_dry") >= 2, "back to drying off: %s" % str(ids))


func test_combo_once_per_night() -> void:
	var w := U.quiet_world()
	w.residue.add(w, "SOAKED", false)
	w.residue.add(w, "FLOURY", false)
	w.residue.clear(w, "FLOURY")
	w.residue.add(w, "FLOURY", false)
	var log := w.drain_events()
	assert_eq(U.find(log, SimEvents.COMBO, {"id": "dough_man"}).size(), 1)


func test_frazzled_from_achoo_blinds_until_the_mirror() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "landing", 1700))
	U.force_rig(w, "achoo_ria")
	var log: Array = []
	U.run_until(w, SimEvents.RESIDUE_ADD, {"kind": "FRAZZLED"}, 1000, log)
	U.run(w, 1)
	assert_true(w.bellows.blinded, "flipped bouffant over his eyes")
	assert_eq(w.bubble()["glyph"], "blinded")
	U.run_until(w, SimEvents.RESIDUE_CLEAR, {"kind": "FRAZZLED"}, 3000, log)
	U.run(w, 1)
	assert_false(w.bellows.blinded)
	assert_false(U.first(log, SimEvents.B_ACTIVITY, {"id": "fixup_mirror"}).is_empty())


func test_several_residues_queue_oldest_first() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "landing", 1700))
	U.run(w, 3)
	w.residue.add(w, "STICKY", false)
	w.residue.add(w, "COSTUME", false)
	var log := U.run(w, 3000)
	var ids := []
	for d in U.find(log, SimEvents.B_ACTIVITY):
		ids.append(str(d["id"]))
	assert_eq(ids.slice(0, 3), ["fixup_sink", "fixup_mirror", "pickles"], str(ids))
