## s2-sim §4.4 / §4.4b / §4.5.2 — the read-only accessors the HUD and the view use so nobody re-derives rules:
## `action_context()` (every verb + the danger rim, fixtures and the real P00 / N01), `bellows_oneshot()` /
## `hush_oneshot()` (every id on the right ticks, phase boundaries exact, `len` = `SimOneshots`), `SimOneshots` vs
## `SimConst`, `sight_ranges()` / `hearing_px()`, `bellows_leg()` / `hush_leg()` (stairs progress monotonic); all
## allocation-free (one reused Dictionary) and invisible to the state hash.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


# --- action_context ----------------------------------------------------------------------------------

func test_action_context_verbs_on_fixtures() -> void:
	var w := U.quiet_world()
	U.run(w, 2)
	U.place_hush(w, "kitchen", 3560)
	var ac := w.action_context()
	assert_eq(str(ac["verb"]), "freeze", "not at a rig point, not hidden")
	assert_eq(str(ac["danger"]), "green", "he is upstairs")
	assert_true(is_same(ac, w.action_context()), "one reused Dictionary")
	U.place_hush_at(w, "kitchen_honey")
	ac = w.action_context()
	assert_eq(str(ac["verb"]), "rig")
	assert_eq(str(ac["prank"]), "achoo_ria")
	assert_eq(int(ac["step"]), 0)
	assert_eq(str(ac["item_needed"]), "")
	assert_true(bool(ac["item_have"]))
	assert_eq(int(ac["tier_ticks"]), 48, "Q")
	assert_eq(int(ac["ring_pm"]), 0)
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 23)
	ac = w.action_context()
	assert_eq(str(ac["verb"]), "rig", "still rigging")
	assert_between(int(ac["ring_pm"]), 400, 600, "half-way through a 48-tick step")
	U.step(w, [SimCmd.rig(false)])
	U.place_hush_at(w, "kitchen_kettle")
	ac = w.action_context()
	assert_eq(str(ac["verb"]), "rig_dim", "the kettle needs the squeaker")
	assert_eq(str(ac["prank"]), "kettle_drum")
	assert_eq(str(ac["item_needed"]), "squeaker")
	assert_false(bool(ac["item_have"]))
	assert_eq(str(ac["container"]), "hall_confiscated_box", "where the missing item is")
	w.hush.carrying = PackedStringArray(["squeaker"])
	w.hush.carry_uses = PackedInt32Array([1])
	ac = w.action_context()
	assert_eq(str(ac["verb"]), "rig")
	assert_true(bool(ac["item_have"]))
	assert_eq(str(ac["container"]), "")
	# hidden: POP OUT, or GO ▶ with a pin
	U.place_hush(w, "kitchen", 3560)
	assert_true(U.walk_to(w, "kitchen_pantry_curtain"))
	U.run_until_pred(w, func(x: SimWorld) -> bool: return x.hush.state == SimHush.HIDDEN, 120)
	assert_eq(str(w.action_context()["verb"]), "pop_out")
	U.step(w, [SimCmd.pin("parlour", 2000)])
	assert_eq(str(w.action_context()["verb"]), "go")
	# caught / climbing in: nothing
	w.hush.on_caught(w)
	assert_eq(str(w.action_context()["verb"]), "none")
	var ent := U.world_patched("fx_act1", func(ep: Dictionary) -> void: ep["hush"]["enter"] = {"at_s": 0.0, "busy_s": 3.0})
	U.run(ent, 2)
	assert_eq(str(ent.action_context()["verb"]), "none", "climbing in")


func test_danger_rim_colours() -> void:
	var w := U.quiet_world()
	U.run(w, 2)
	U.place_hush(w, "kitchen", 3560)
	var b := w.bellows
	var put := func(r: String, x: int) -> void:
		b.room = w.room_idx(r)
		b.floor = w.db.house.rooms[b.room].floor
		b.x_sub = x * SimConst.SUB
		b.path = null
	put.call("landing", 1400)
	assert_eq(str(w.action_context()["danger"]), "green")
	put.call("hall", 900)
	assert_eq(str(w.action_context()["danger"]), "green", "two rooms away")
	b._path_to(w, w.room_idx("kitchen"), 3000 * SimConst.SUB, SimConst.MOVER_B_WALK)
	assert_eq(str(w.action_context()["danger"]), "amber", "heading here")
	put.call("parlour", 2000)
	assert_eq(str(w.action_context()["danger"]), "amber", "next door")
	put.call("kitchen", 2900)
	assert_eq(str(w.action_context()["danger"]), "red", "in this room")


func test_action_context_on_real_prologue_and_night_one() -> void:
	var db := ContentDB.load_dir("res://data")
	if not assert_true(db.errors.is_empty(), "real data loads: %s" % [db.errors]):
		return
	var p := SimWorld.create(db, "p00_curtain_up", {})
	U.run(p, 1)
	var entering := p.hush.entering
	assert_eq(str(p.action_context()["verb"]), "none" if entering else "freeze", "the climb-in")
	U.run_until_pred(p, func(x: SimWorld) -> bool: return not x.hush.entering, 1200)
	var ac := p.action_context()
	assert_has(["freeze", "rig", "rig_dim"], str(ac["verb"]))
	assert_has(["green", "amber", "red"], str(ac["danger"]))
	# Night 1: every rig point that needs an item shows RIG dimmed and names the container, then RIG once carried
	var n := SimWorld.create(db, "n01_throat_tea", {})
	U.run(n, 2)
	var found := 0
	for pd in db.prank_list:
		if not n.ctx.prank_in_ep[pd.idx] or pd.steps.is_empty() or pd.steps[0].needs == "":
			continue
		var rp: String = pd.rig_point
		var hs := db.house.hotspot(rp)
		if hs == null or not n.ctx.hush_allowed(hs.room_idx) or n.pranks.rig_target(n, hs.idx) != pd.idx:
			continue
		U.place_hush_at(n, rp)
		n.hush.carrying = PackedStringArray()
		n.hush.carry_uses = PackedInt32Array()
		var c := n.action_context()
		assert_eq(str(c["verb"]), "rig_dim", "%s without %s" % [pd.id, pd.steps[0].needs])
		assert_eq(str(c["item_needed"]), pd.steps[0].needs)
		assert_eq(str(c["container"]), (db.items[pd.steps[0].needs] as ItemDef).source)
		n.hush.carrying = PackedStringArray([pd.steps[0].needs])
		n.hush.carry_uses = PackedInt32Array([1])
		assert_eq(str(n.action_context()["verb"]), "rig", "%s with it" % pd.id)
		found += 1
	assert_gt(found, 0, "Night 1 has item pranks")


func test_action_context_costs_under_5_us() -> void:
	var w := U.quiet_world()
	U.run(w, 2)
	U.place_hush_at(w, "kitchen_kettle")
	w.action_context()
	# the heaviest path (RIG dimmed: a rig point, a missing item); the best of 25 short batches, so a shared,
	# busy box measures the call and not the scheduler
	var per := 1.0e9
	for b in 25:
		var t0 := Time.get_ticks_usec()
		for i in 1000:
			w.action_context()
		per = minf(per, float(Time.get_ticks_usec() - t0) / 1000.0)
	# the budget is for a free core: on an oversubscribed box (10 agents share 4 cores while Stage 2 builds) it
	# scales with the 1-minute load per core, read from /proc/loadavg where there is one
	var scale := TestBase.cpu_load_scale()
	assert_le(per, 5.0 * scale, "action_context %.2f µs per call (budget 5 µs × load %.1f)" % [per, scale])



# --- one-shots -----------------------------------------------------------------------------------------

## Record {tick: [b_id, b_t, b_len, b_variant, h_id, h_t, h_len]} while stepping `n` ticks (events appended to `log`).
func _track(w: SimWorld, n: int, log: Array, cmds_at: Dictionary = {}) -> Dictionary:
	var out := {}
	for i in n:
		if w.ended:
			break
		w.step(cmds_at.get(w.tick + 1, []))
		log.append_array(w.drain_events())
		var b := w.bellows_oneshot()
		var h := w.hush_oneshot()
		out[w.tick] = [str(b["id"]), int(b["t"]), int(b["len"]), int(b["variant"]), str(h["id"]), int(h["t"]), int(h["len"])]
	return out


## Contiguous runs of one-shot `id` (Bellows' when `hush` is false): [[first_tick, last_tick, t_first, t_last, len]].
func _runs(track: Dictionary, id: String, hush: bool = false) -> Array:
	var out: Array = []
	var cur: Array = []
	var ticks := track.keys()
	ticks.sort()
	var o := 4 if hush else 0
	for t in ticks:
		var r: Array = track[t]
		if str(r[o]) == id:
			if cur.is_empty() or int(cur[1]) != int(t) - 1:
				if not cur.is_empty():
					out.append(cur)
				cur = [int(t), int(t), int(r[o + 1]), int(r[o + 1]), int(r[o + 2])]
			else:
				cur[1] = int(t)
				cur[3] = int(r[o + 1])
		elif not cur.is_empty():
			out.append(cur)
			cur = []
	if not cur.is_empty():
		out.append(cur)
	return out


## Assert one full run of `id` starting at tick `t0` with t 0..len-1 and the given length.
func _assert_run(track: Dictionary, id: String, t0: int, length: int, hush: bool = false, full: bool = true) -> void:
	var runs := _runs(track, id, hush)
	var hit: Array = []
	for r in runs:
		if int(r[0]) == t0:
			hit = r
	if not assert_false(hit.is_empty(), "%s starts at tick %d (runs %s)" % [id, t0, runs]):
		return
	assert_eq(int(hit[2]), 0, "%s: t = 0 on its first tick" % id)
	assert_eq(int(hit[4]), length, "%s: len" % id)
	assert_eq(int(hit[3]) - int(hit[2]), int(hit[1]) - int(hit[0]), "%s: t counts ticks" % id)
	if full:
		assert_eq(int(hit[1]) - int(hit[0]) + 1, length, "%s lasts exactly len ticks" % id)


func test_caught_phases_for_both() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1550).call(ep)
		ep["rules"]["tomatoes"] = 3)
	var log: Array = []
	var tr := _track(w, 600, log)
	var c := U.first(log, SimEvents.CAUGHT)
	if not assert_false(c.is_empty(), "caught"):
		return
	var t0 := int(c["t"])
	_assert_run(tr, "caught:grab", t0, SimConst.CAUGHT_BUSTED)
	_assert_run(tr, "caught:lecture", int(U.first(log, SimEvents.LECTURE)["t"]), SimConst.CAUGHT_LECTURE)
	_assert_run(tr, "caught:wipe", t0 + SimConst.CAUGHT_BUSTED + SimConst.CAUGHT_LECTURE, SimConst.CAUGHT_WIPE)
	_assert_run(tr, "caught:doorstep", int(U.first(log, SimEvents.DOORSTEP)["t"]), SimConst.CAUGHT_HOLD - SimConst.CAUGHT_DOORSTEP_AT)
	assert_eq(int(tr[t0 + 70][3]), int(U.first(log, SimEvents.LECTURE)["variant"]), "variant = the Lecture's")
	_assert_run(tr, "caught:busted", t0, SimConst.CAUGHT_BUSTED, true)
	_assert_run(tr, "caught:lecture", t0 + SimConst.CAUGHT_BUSTED, SimConst.CAUGHT_LECTURE, true)
	_assert_run(tr, "caught:doorstep", t0 + SimConst.CAUGHT_DOORSTEP_AT, SimConst.CAUGHT_HOLD - SimConst.CAUGHT_DOORSTEP_AT, true)
	assert_eq(str(tr[t0 + SimConst.CAUGHT_HOLD][4]), "", "control back at +240")
	for id in ["caught:grab", "caught:lecture", "caught:wipe", "caught:doorstep", "caught:busted"]:
		assert_eq(SimOneshots.duration(id), int(_runs(tr, id, id == "caught:busted")[0][4]), "SimOneshots.%s" % id)


func test_climb_in_is_the_enter_one_shot() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void: ep["hush"]["enter"] = {"at_s": 1.0, "busy_s": 2.0})
	var tr := _track(w, 300, [])
	_assert_run(tr, "enter", 60, 120, true)
	assert_eq(str(tr[59][4]), "", "not before at_s")
	assert_eq(SimOneshots.duration("enter"), -1)
	assert_eq(SimOneshots.duration_in(w, "enter"), 120, "from hush.enter")


func test_head_turn_bit_and_specs() -> void:
	# pickles has no squeak bit: a heard squeak turns his head
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles", "paper"], "kitchen", 3130, "parlour", 2000))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "pickles"}, 100)
	var log: Array = []
	var tr := _track(w, 80, log, {w.tick + 1: [SimCmd.squeak()]})
	var ht := U.first(log, SimEvents.HEAD_TURN)
	assert_false(ht.is_empty(), "heard through the doorway")
	_assert_run(tr, "head_turn", int(ht["t"]), SimConst.HEAD_TURN_TICKS)
	# the paper has bit_paper (72 f) and specs on
	var p := U.world_patched("fx_act1", U.loop_patch(["paper", "warmup"], "parlour", 1900, "kitchen", 3470))
	var log2: Array = []
	var tr2 := _track(p, 200, log2)
	var sp := U.first(log2, SimEvents.SPECS, {"on": true})
	assert_false(sp.is_empty())
	_assert_run(tr2, "specs_on", int(sp["t"]), SimConst.SPECS_ON_TICKS)
	var tr3 := _track(p, 100, log2, {p.tick + 1: [SimCmd.squeak()]})
	var bit := U.first(log2, SimEvents.SQUEAK_BIT)
	assert_false(bit.is_empty(), "a squeak bit")
	_assert_run(tr3, "bit:bit_paper", int(bit["t"]), 72)
	assert_eq(SimOneshots.duration("bit:bit_paper"), -1, "variable: from squeak_bits")
	assert_eq(SimOneshots.duration_in(p, "bit:bit_paper"), 72)


func test_bump_then_bump_look() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["pickles", "rinse"], "kitchen", 3130, "kitchen", 3500).call(ep)
		ep["rules"]["spot_fill_s"] = 3.0)
	U.step(w, [SimCmd.freeze(true)])
	var log: Array = []
	var tr := _track(w, 900, log)
	var bump := U.first(log, SimEvents.BUMP)
	if not assert_false(bump.is_empty()):
		return
	var t0 := int(bump["t"])
	_assert_run(tr, "bump", t0, 82)
	assert_eq(int(tr[t0 + SimConst.BUMP_PAT_TICKS][1]), SimConst.BUMP_PAT_TICKS, "walk-on starts at 30")
	assert_eq(int(tr[t0 + 70][1]), 70, "turn starts at 70")
	_assert_run(tr, "bump_look", t0 + 82, SimConst.BUMP_LOOK_MAX, false, false)


func test_curious_stop_and_look() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["paper", "warmup"], "parlour", 2080, "parlour", 1600))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "paper"}, 60)
	U.place_hush(w, "kitchen", 3470)
	var cmds := {}
	for i in 3:
		cmds[w.tick + 1 + i * 100] = [SimCmd.squeak()]
	cmds[w.tick + 202] = [SimCmd.go("kitchen_table")]
	var log: Array = []
	var tr := _track(w, 900, log, cmds)
	var det := U.first(log, SimEvents.B_DETOUR, {"kind": "curious"})
	if not assert_false(det.is_empty(), "lured"):
		return
	_assert_run(tr, "curious_stop", int(det["t"]), SimConst.CURIOUS_STOP_TICKS)
	var look := U.first(log, SimEvents.B_ACTIVITY, {"id": "curious"})
	var runs := _runs(tr, "curious_look")
	assert_false(runs.is_empty())
	assert_eq(int(runs[0][0]), int(look["t"]), "the look starts on arrival")
	assert_eq(int(runs[0][2]), 0)
	assert_eq(int(runs[0][1]) - int(runs[0][0]) + 1, int(runs[0][4]), "lasts its len")


func test_chase_wheeze_and_door_slam_stun() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1550))
	U.run_until(w, SimEvents.SPOTTED, {}, 200)
	var log: Array = []
	var st := U.run_until(w, SimEvents.CHASE_START, {}, 30, log)
	var cmds := {w.tick + 1: [SimCmd.go("stairs_foot", true)]}
	var tr := _track(w, 20, log, cmds)
	tr.merge(_track(w, 500, log, {w.tick + 1: [SimCmd.go("landing_airing_cupboard", true)]}))
	var wz := U.first(log, SimEvents.WHEEZE)
	assert_false(wz.is_empty())
	assert_eq(int(wz["t"]) - int(st["t"]), SimConst.CHASE_RUN1)
	_assert_run(tr, "chase_wheeze", int(wz["t"]), SimConst.CHASE_WHEEZE)
	var d := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "parlour", 1600))
	var log2: Array = []
	U.run_until(d, SimEvents.CHASE_START, {}, 200, log2)
	var tr2 := _track(d, 120, log2, {d.tick + 1: [SimCmd.move("hall", 600, true)]})
	var slam := U.first(log2, SimEvents.DOOR_SLAM)
	if assert_false(slam.is_empty(), "door slam"):
		_assert_run(tr2, "stun", int(slam["t"]), SimConst.DOOR_SLAM_STUN)


func test_face_to_face_and_near_miss() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["clock"], "hall", 900, "hall", 1340))
	U.place_hush_at(w, "hall_clock_case")
	w.hush.state = SimHush.HIDDEN
	w.hush.hidden_spot = w.hush.at_hotspot
	w.hush.watched_spot = -1
	var log: Array = []
	var tr := _track(w, 700, log)
	var f := U.first(log, SimEvents.FACE_TO_FACE)
	if not assert_false(f.is_empty()):
		return
	_assert_run(tr, "face_to_face", int(f["t"]), w.ctx.f2f_ticks)
	assert_eq(str(tr[int(f["t"]) + w.ctx.f2f_ticks][0]), "caught:grab", "then the grab")
	# escape: POP OUT inside the window is Hush's near miss
	var e := U.world_patched("fx_act1", U.loop_patch(["clock"], "hall", 900, "hall", 1340))
	U.place_hush_at(e, "hall_clock_case")
	e.hush.state = SimHush.HIDDEN
	e.hush.hidden_spot = e.hush.at_hotspot
	e.hush.watched_spot = -1
	var log2: Array = []
	U.run_until(e, SimEvents.FACE_TO_FACE, {}, 600, log2)
	U.run(e, 20)
	var tr2 := _track(e, 40, log2, {e.tick + 1: [SimCmd.pop_out(true)]})
	var pop := U.first(log2, SimEvents.POP_OUT)
	_assert_run(tr2, "near_miss", int(pop["t"]), SimConst.POP_TICKS, true)


func test_fizzle_yank_wink_wheeze() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["mirror", "warmup"], "hall", 1080, "kitchen", 3800))
	U.force_rig(w, "mirror_mirror")
	var log: Array = []
	var tr := _track(w, 200, log)
	var fz := U.first(log, SimEvents.FIZZLE)
	if assert_false(fz.is_empty(), "fizzle"):
		_assert_run(tr, "fizzle", int(fz["t"]), SimConst.FIZZLE_TICKS)
	# Figgis's hook
	var y := U.quiet_world()
	U.run(y, 2)
	var tr2 := _track(y, 1, [])
	y.hush.figgis_into(y, y.db.house.hotspot_index["kitchen_pantry_curtain"])
	tr2.merge({y.tick: [str(y.bellows_oneshot()["id"]), 0, 0, 0, str(y.hush_oneshot()["id"]), int(y.hush_oneshot()["t"]), int(y.hush_oneshot()["len"])]}, true)
	tr2.merge(_track(y, 60, []), true)
	_assert_run(tr2, "yanked", y.tick - 60, SimConst.FIGGIS_YANK_TICKS, true)
	# wheeze held: the variable one
	var wz := U.quiet_world()
	U.run(wz, 2)
	var tr3 := _track(wz, 30, [], {wz.tick + 1: [SimCmd.wheeze(true)]})
	var r := _runs(tr3, "wheeze", true)
	assert_false(r.is_empty(), "wheeze")
	assert_eq(int(r[0][4]), SimConst.WHEEZE_MAX_TICKS)
	assert_eq(SimOneshots.duration("wheeze"), -1)


func test_doorway_pause_and_look_back() -> void:
	# she slips into the kitchen just before he reaches the doorway: the pause makes up the warning
	var w := U.world_patched("fx_act1", U.loop_patch(["warmup", "tea"], "parlour", 1700, "hall", 700))
	U.run_until(w, SimEvents.B_ACTIVITY_END, {"id": "warmup"}, 2000)
	U.run_until_pred(w, func(x: SimWorld) -> bool: return x.bellows.x_sub >= 2760 * SimConst.SUB, 600)
	U.place_hush(w, "kitchen", 3700)
	var log: Array = []
	var tr := _track(w, 200, log)
	var dp := U.first(log, SimEvents.DOORWAY_PAUSE)
	if assert_false(dp.is_empty(), "doorway pause"):
		var runs := _runs(tr, "doorway_pause")
		assert_false(runs.is_empty())
		assert_eq(int(runs[0][4]), int(dp["ticks"]), "len = the inserted 90 − eta")
		assert_eq(int(runs[0][2]), 0)
		assert_eq(int(runs[0][1]) - int(runs[0][0]) + 1, int(dp["ticks"]), "lasts the pause")
	# steaming, he looks back over his shoulder after a doorway
	var s := U.world_patched("fx_act1", U.loop_patch(["paper", "tea"], "parlour", 2080, "hall", 700))
	U.run_until(s, SimEvents.B_ACTIVITY_END, {"id": "paper"}, 2000)
	U.set_temper(s, 60)
	var log2: Array = []
	var tr2 := _track(s, 600, log2)
	var lb := U.first(log2, SimEvents.LOOK_BACK)
	if assert_false(lb.is_empty(), "look back"):
		var r2 := _runs(tr2, "look_back")
		assert_false(r2.is_empty())
		assert_eq(int(r2[0][4]), SimConst.LOOK_BACK_TICKS)
		# a pause entered mid-advance (after a zero-length portal leg) shows from t = 1: it still ends on its last frame
		assert_between(int(r2[0][2]), 0, 1)
		assert_eq(int(r2[0][3]), SimConst.LOOK_BACK_TICKS - 1, "ends on its last frame")


func test_sim_oneshots_durations_come_from_sim_const() -> void:
	var d := SimOneshots.DURATIONS
	assert_eq(int(d["head_turn"]), SimConst.HEAD_TURN_TICKS)
	assert_eq(int(d["specs_on"]), 12)
	assert_eq(int(d["look_back"]), 60)
	assert_eq(int(d["bump"]), 82, "pat 30 → walk-on 40 → turn 12")
	assert_eq(int(d["bump_look"]), 180)
	assert_eq(int(d["curious_stop"]), 60)
	assert_eq(int(d["curious_look"]), SimConst.CURIOUS_LOOK_TICKS)
	assert_eq(int(d["chase_wheeze"]), 90)
	assert_eq(int(d["stun"]), 60)
	assert_eq(int(d["face_to_face"]), 48)
	assert_eq(int(d["fizzle"]), 30)
	assert_eq(int(d["caught:grab"]), 60)
	assert_eq(int(d["caught:lecture"]), 132)
	assert_eq(int(d["caught:wipe"]), 12)
	assert_eq(int(d["caught:doorstep"]), 36)
	assert_eq(int(d["caught:busted"]), 60)
	for v in ["doorway_pause", "enter", "wheeze", "bit:*"]:
		assert_eq(int(d[v]), -1, "%s is variable" % v)
	assert_eq(SimOneshots.duration("bit:bit_tea"), -1)
	assert_eq(SimOneshots.duration("nope"), -1)
	for id in SimOneshots.BELLOWS_IDS + SimOneshots.HUSH_IDS:
		assert_true(d.has(id), "%s has a duration" % id)


func test_accessors_are_read_only_and_reuse_their_dictionaries() -> void:
	var cmds := U.bot_act1(3000)
	var plain := PackedInt64Array()
	U.replay("fx_act1", cmds, 3000, plain)
	var w := U.world("fx_act1")
	var by := {}
	for e in cmds:
		if not by.has(int(e[0])):
			by[int(e[0])] = []
		(by[int(e[0])] as Array).append(e[1])
	var probe := [w.action_context(), w.bellows_oneshot(), w.hush_oneshot(), w.sight_ranges(), w.bellows_leg(), w.hush_leg()]
	var same := true
	for t in range(1, plain.size() + 1):
		w.step(by.get(t, []))
		w.drain_events()
		var now := [w.action_context(), w.bellows_oneshot(), w.hush_oneshot(), w.sight_ranges(), w.bellows_leg(), w.hush_leg()]
		w.hearing_px("run")
		for k in now.size():
			same = same and is_same(now[k], probe[k])
		if w.state_hash() != plain[t - 1]:
			fail("accessors changed the state at tick %d" % t)
			return
	assert_true(same, "every accessor returns its one reused Dictionary")


# --- senses + legs ---------------------------------------------------------------------------------------

func test_sight_ranges_and_hearing() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["paper", "warmup"], "parlour", 2080, "kitchen", 3700))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "paper"}, 100)
	var sr := w.sight_ranges()
	var arr := w.senses.sight_ranges(w)
	assert_eq(int(sr["moving_px"]), int(arr[0]), "matches the senses")
	assert_eq(int(sr["frozen_px"]), int(arr[1]))
	assert_eq(bool(sr["to_wall"]), int(arr[0]) < 0)
	assert_false(bool(sr["blind"]))
	assert_eq(w.hearing_px("run"), SimConst.NOISE_PX)
	assert_eq(w.hearing_px("rig"), SimConst.NOISE_PX)
	assert_eq(w.hearing_px("squeak"), -1, "room + doorway-joined rooms")
	assert_eq(w.hearing_px("sneeze"), 0, "unknown kind")
	w.bellows.state = SimBellows.REACTING
	assert_eq(w.hearing_px("run"), 0, "deaf while reacting")
	w.bellows.state = SimBellows.ROUTINE
	var g := U.world_patched("fx_act1", func(ep: Dictionary) -> void: ep["rules"]["senses"] = false)
	U.run(g, 5)
	assert_true(bool(g.sight_ranges()["blind"]), "rules.senses false: blind")
	assert_eq(g.hearing_px("run"), 0)


func test_bellows_leg_stairs_progress_is_monotonic() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["radiator", "tea"], "landing", 1420, "kitchen", 3800))
	var saw_stairs := 0
	var last_pm := -1
	var in_stairs := false
	var walk_last := -1
	var walk_key := ""
	for i in 1500:
		w.step([])
		w.drain_events()
		var lg := w.bellows_leg()
		var k := str(lg["kind"])
		if k == "stairs":
			if not in_stairs:
				in_stairs = true
				last_pm = -1
				saw_stairs += 1
				assert_true(str(lg["from_room"]) in ["landing", "hall"] and str(lg["to_room"]) in ["landing", "hall"])
				assert_ne(str(lg["from_room"]), str(lg["to_room"]))
			assert_ge(int(lg["progress_pm"]), last_pm, "stairs progress never goes back")
			last_pm = int(lg["progress_pm"])
			assert_eq(w.room_id(w.bellows.room), str(lg["to_room"]), "during a STAIRS leg room is the arrival end's")
		else:
			if in_stairs:
				assert_ge(last_pm, 900, "the climb ends near 1000")
			in_stairs = false
		if k == "walk":
			var key := "%s>%s:%d" % [lg["from_room"], lg["to_room"], int(lg["to_x"])]
			if key == walk_key:
				assert_ge(int(lg["progress_pm"]), walk_last, "walk progress monotonic")
			walk_key = key
			walk_last = int(lg["progress_pm"])
	assert_ge(saw_stairs, 1, "he took the stairs")
	var h := U.quiet_world()
	U.step(h, [SimCmd.go("kitchen_pickle_jar")])
	U.run(h, 5)
	var hl := h.hush_leg()
	assert_eq(str(hl["kind"]), "walk")
	assert_eq(str(hl["to_room"]), "kitchen")
	assert_eq(int(hl["to_x"]), 3130)
	assert_true(is_same(hl, h.hush_leg()))
	var idle := U.quiet_world()
	U.run(idle, 2)
	assert_eq(str(idle.hush_leg()["kind"]), "", "standing still")
