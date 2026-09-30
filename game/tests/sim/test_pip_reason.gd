## R3D ruling R15 — `SimVisibility.pip_reason(w)`: why the Bellows window may show him ("" when `pip_shows` is
## false; "room" | "heading" | "rigging" | "adjacent", heading and rigging win over adjacent), on synthetic worlds,
## and `pip_shows` unchanged: on every tick of real runs `pip_reason != ""` iff `pip_shows`. Micro-gag events carry
## the reason (`pip_reason`), which the solver's `d1_lean` column reads.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _place_bellows(w: SimWorld, room: String, x_px: int) -> void:
	var b := w.bellows
	b.room = w.room_idx(room)
	b.floor = w.db.house.rooms[b.room].floor
	b.x_sub = x_px * SimConst.SUB
	b.path = null


func _room_x(w: SimWorld, room: String) -> int:
	var r := w.db.house.rooms[w.room_idx(room)]
	return Fx.to_px((r.x0_sub + r.x1_sub) / 2)


func _two_rooms(w: SimWorld, linked: bool) -> Array:
	var rooms := w.db.house.rooms
	for a in rooms.size():
		for b in rooms.size():
			if a != b and rooms[a].floor == rooms[b].floor and w.db.nav.linked(a, b) == linked:
				return [rooms[a].id, rooms[b].id]
	return []


func test_each_reason_on_a_synthetic_world() -> void:
	var w := U.quiet_world()
	var adj := _two_rooms(w, true)
	var far := _two_rooms(w, false)
	if not assert_false(adj.is_empty(), "two linked rooms") or not assert_false(far.is_empty(), "two unlinked rooms"):
		return
	# same room
	U.place_hush(w, adj[0], _room_x(w, adj[0]))
	_place_bellows(w, adj[0], _room_x(w, adj[0]) + 100)
	assert_eq(SimVisibility.pip_reason(w), &"room")
	# one link away, standing still
	_place_bellows(w, adj[1], _room_x(w, adj[1]))
	assert_eq(SimVisibility.pip_reason(w), &"adjacent")
	# one link away and heading into her room: heading wins
	var b := w.bellows
	b.path = w.db.nav.path(b.room, b.x_sub, w.room_idx(adj[0]), w.hush.x_sub, SimConst.MOVER_B_WALK)
	if assert_true(b.path.ok and not b.path.is_done(), "a path into her room"):
		assert_eq(SimVisibility.pip_reason(w), &"heading")
	b.path = null
	# one link away while she rigs: rigging wins over adjacent
	w.hush.state = SimHush.RIGGING
	assert_eq(SimVisibility.pip_reason(w), &"rigging")
	# far away (no link), rigging
	U.place_hush(w, far[0], _room_x(w, far[0]))
	_place_bellows(w, far[1], _room_x(w, far[1]))
	w.hush.state = SimHush.RIGGING
	assert_eq(SimVisibility.pip_reason(w), &"rigging")
	# far away, not rigging: not shown
	w.hush.state = SimHush.IDLE
	assert_eq(SimVisibility.pip_reason(w), &"")
	assert_false(SimVisibility.pip_shows(w))


func _check_run(w: SimWorld, ticks: int, cmds_at: Dictionary) -> Array:
	var bad := 0
	var reasons := {}
	var gags := 0
	for i in ticks:
		if w.ended:
			break
		w.step(cmds_at.get(w.tick + 1, []))
		for ev in w.drain_events():
			if str(ev["e"]) == SimEvents.MICRO_GAG:
				gags += 1
				var pr := str(ev.get("pip_reason", "?"))
				if str(ev.get("vis", "")) == "pip" and pr == "":
					bad += 1
				if str(ev.get("vis", "")) == "room" and pr != "room":
					bad += 1
		var r := SimVisibility.pip_reason(w)
		reasons[r] = int(reasons.get(r, 0)) + 1
		if (r != &"") != SimVisibility.pip_shows(w):
			bad += 1
	return [bad, reasons, gags]


func test_pip_shows_is_unchanged_on_every_tick() -> void:
	var db := ContentDB.load_dir("res://data")
	if not db.errors.is_empty():
		skip("real content invalid: %s" % db.errors[0])
		return
	var seen := {}
	for ep in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]:
		var w := SimWorld.create(db, ep, {})
		# a wandering Hush: tiptoe to each live hotspot of her start room and back, so the reasons all occur
		var cmds := {}
		var t := maxi(2, w.ctx.hush_enter_ticks + 2)
		for id in SimCtx.live_hotspots(db, w.episode):
			cmds[t] = [SimCmd.go(String(id))]
			t += 420
		var res := _check_run(w, 7200, cmds)
		assert_eq(int(res[0]), 0, "%s: pip_reason ≠ '' iff pip_shows, and micro_gag.pip_reason consistent with vis" % ep)
		assert_gt(int(res[2]), 0, "%s: micro-gags were emitted" % ep)
		for k in (res[1] as Dictionary):
			seen[k] = true
	for k in [&"room", &"adjacent", &""]:
		assert_true(seen.has(k), "reason %s occurs on the real routes" % k)


func test_pip_reason_does_not_allocate() -> void:
	var w := U.quiet_world()
	var n := 20000
	var t0 := Time.get_ticks_usec()
	for i in n:
		SimVisibility.pip_reason(w)
	var us := float(Time.get_ticks_usec() - t0) / n
	assert_lt(us, 5.0 * TestBase.cpu_load_scale(), "pip_reason %.2f µs" % us)
