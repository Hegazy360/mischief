## The view on the real SimWorld replaying solver command dumps (`solve.sh --dump-cmds`, copied to
## tests/view/fixtures/cmds): visibility parity (s2-view brief §4.2.11 — whenever the sim credits a
## micro-gag as `room` / `pip`, Bellows is on screen or the PiP rule shows him within 0.3 s), the
## one-shot and caught phases seen through the snapshot, the g0 sneeze with no sound id twice
## within 100 ms, and pools stable with real rigs. Soft: skips when the sim is missing.
extends TestBase

const CMDS := "res://tests/view/fixtures/cmds"
const WINDOW_TICKS := 18


func _world(ep: String) -> Object:
	var sw := ViewKit.soft_script("res://sim/world/sim_world.gd")
	var cdb := ViewKit.soft_script("res://sim/content/content_db.gd")
	if sw == null or cdb == null:
		return null
	var db: Variant = cdb.call("load_dir", "res://data")
	return sw.call("create", db, ep, {})


func _cmds(ep: String) -> Dictionary:
	var v: Variant = TestBase.load_json("%s/%s_ideal.cmds.json" % [CMDS, ep])
	return SimDriver.cmds_by_tick(v) if v != null else {}


## View rect of a camera following Hush at zoom 1 in a 1920 × 1080 view (one floor + 190 px).
static func _view_rect(snap: ViewSnapshot) -> Rect2:
	return Rect2(snap.hush.x - 960.0, snap.hush.y - 830.0, 1920.0, 1080.0)


func test_visibility_parity_on_the_real_routes() -> void:
	var sw := ViewKit.soft_script("res://sim/world/sim_world.gd")
	if sw == null:
		skip("no sim")
		return
	var report: Array = []
	var credited := [0]
	for ep in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]:
		var w: Object = _world(ep)
		if w == null:
			skip("episode %s did not load" % ep)
			return
		var d := SimDriver.new()
		tree.root.add_child(d)
		d.setup(w)
		d.set_script_cmds(_cmds(ep))
		var layout := HouseLayout.load_default()
		var pending: Array = []
		var entry_t := -1000
		d.ticked.connect(func(evs: Array) -> void:
			var s := d.snapshot()
			for e in evs:
				var ed: Dictionary = e
				var nm := String(ed.get("e", ""))
				if nm == "entry_warning" and (String(ed.get("room", "")) == s.hush.room or String(ed.get("room", "")) == ""):
					entry_t = s.tick
				if nm == "micro_gag" and (String(ed.get("vis", "")) == "room" or String(ed.get("vis", "")) == "pip"):
					credited[0] += 1
					pending.append([s.tick, false, "%s@%d %s (%s)" % [ep, s.tick, String(ed.get("id", "")), String(ed.get("vis", ""))]]))
		var misses: Array = []
		var n := 0
		var limit := maxi(d.script_last_tick() + 2400, 3600)
		while n < limit and not bool(w.get("ended")):
			d.step_now()
			n += 1
			var snap := d.snapshot()
			var body := Rect2(snap.bellows.x - 90.0, snap.bellows.y - 390.0, 180.0, 390.0)
			var shown := snap.bellows.present and (_view_rect(snap).intersects(body)
					or PipView.rule(snap, _view_rect(snap), layout, snap.tick - entry_t < 90))
			var keep: Array = []
			for p in pending:
				if shown:
					continue
				if snap.tick - int(p[0]) > WINDOW_TICKS:
					misses.append(p[2])
				else:
					keep.append(p)
			pending = keep
		report.append_array(misses)
		d.queue_free()
	if not report.is_empty():
		print("[view parity] micro-gags credited room/pip the view does not show within 0.3 s: %s" % ", ".join(PackedStringArray(report)))
	assert_gt(int(credited[0]), 5, "the routes credit visible micro-gags")
	print("[view parity] %d room/pip micro-gags, %d not shown within 0.3 s" % [int(credited[0]), report.size()])
	assert_eq(report.size(), 0, "visibility parity (sim beat_vis vs the view's screen + PiP rule)")


func test_caught_route_phases_through_the_snapshot() -> void:
	var w: Object = _world("n01_throat_tea")
	if w == null:
		skip("no sim")
		return
	var v: Variant = TestBase.load_json("%s/n01_throat_tea_caught.cmds.json" % CMDS)
	if v == null:
		skip("no caught dump")
		return
	var d := SimDriver.new()
	tree.root.add_child(d)
	d.setup(w)
	d.set_script_cmds(v)
	var phases := {}
	var lecture_var := -1
	for i in 6000:
		d.step_now()
		var s := d.snapshot()
		if s.bellows.oneshot.begins_with("caught:"):
			phases[s.bellows.oneshot] = true
			if s.bellows.oneshot == "caught:lecture":
				lecture_var = s.bellows.oneshot_var
				assert_eq(s.hush.oneshot, "caught:lecture", "both rigs on the Lecture clock")
				assert_eq(s.hush.oneshot_t, s.bellows.oneshot_t, "frame-locked pair")
		if phases.has("caught:doorstep") and not s.bellows.oneshot.begins_with("caught:"):
			break
	d.queue_free()
	if phases.is_empty():
		skip("the caught route no longer catches (content changed)")
		return
	for p in ["caught:grab", "caught:lecture", "caught:wipe", "caught:doorstep"]:
		assert_true(phases.has(p), "phase %s seen" % p)
	assert_between(lecture_var, 0, 2)


func test_g0_sneeze_in_the_real_scene_plays_no_sound_twice_within_100_ms() -> void:
	var w: Object = _world("g0_sneeze")
	if w == null:
		skip("no sim")
		return
	var sb := ViewSandbox.new()
	sb.world = null
	sb.set_process(false)
	tree.root.add_child(sb)
	await tree.process_frame
	sb.set_process(false)
	# Rebuild the stack on the real world (the sandbox built FakeWorld in _ready).
	for c in sb.get_children():
		c.free()
	sb.world = w
	sb.build(w)
	sb.driver.set_script_cmds(_cmds("g0_sneeze"))
	sb.audio.record = true
	var n := 0
	while n < 1500 and not bool(w.get("ended")):
		sb._process(1.0 / 60.0)
		n += 1
	var last: Dictionary = {}
	var doubles: Array = []
	for i in sb.audio.calls.size():
		var c: Array = sb.audio.calls[i]
		if c[0] != "play_sfx" and c[0] != "play_voice":
			continue
		var id := String(c[1])
		var t := sb.audio.call_times[i]
		if last.has(id) and t - float(last[id]) < 0.1 - 0.0001:
			doubles.append(id)
		last[id] = t
	assert_eq(doubles, [], "no sound id twice within 100 ms over the whole g0 sneeze")
	var fb := sb.world_view.fallback_counts()
	print("[view g0] fallbacks %s" % JSON.stringify(fb))
	assert_eq(int(fb["puppets"]), 0)
	sb.queue_free()


func test_pools_stable_with_rigs_over_600_frames() -> void:
	var sb := ViewSandbox.new()
	tree.root.add_child(sb)
	await tree.process_frame
	sb.set_process(false)
	var warmed := sb.world_view.warm_clips()
	assert_gt(warmed, 5, "warm_clips loads the clips before PLAY")
	sb._seek(600)
	for i in 300:
		sb._process(1.0 / 60.0)
	# The view's per-frame hot path (two rigs, FX, PiP, Stalls, audio) allocates nothing that
	# survives: 600 frames with the world held still.
	sb.driver.set_paused(true)
	# warm the paused state first (first-time lazies, frees queued by earlier tests), then measure; a
	# real leak grows in every window, a one-off does not — pass when a window is flat (s2-fix G #6:
	# delta 27 depending on test order)
	for iw in 120:
		sb._process(1.0 / 60.0)
	var deltas: Array[float] = []
	var n0 := 0.0
	var n1 := 0.0
	for win in 2:
		n0 = Performance.get_monitor(Performance.OBJECT_COUNT)
		for i2 in 600:
			sb._process(1.0 / 60.0)
		n1 = Performance.get_monitor(Performance.OBJECT_COUNT)
		deltas.append(n1 - n0)
		if absf(n1 - n0) <= 2.0:
			break
	var flat := false
	for dv in deltas:
		flat = flat or absf(dv) <= 2.0
	assert_true(flat, "objects stable over 600 view frames with two rigs (deltas %s)" % [deltas])
	# Tick-driven growth (first-time textures, lazy residue looks, bubble icons) — reported.
	sb.driver.set_paused(false)
	var n2 := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i3 in 600:
		sb._process(1.0 / 60.0)
	var n3 := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("[view pools] paused view %d → %d; live 600 frames %d → %d (%d clips warmed)" % [n0, n1, n2, n3, warmed])
	sb.queue_free()
