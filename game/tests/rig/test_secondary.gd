## Springs (stable at 30 / 60 / 120 fps, settle, no NaN), FaceState (seeded blinks),
## PropSim (deterministic ballistic launch with bounces).
extends TestBase

const RIG := "_mannequin"


func _run_spring(fps: float, seconds: float, kick: float) -> Dictionary:
	var sp := Springs.new()
	sp.setup(RigDef.for_id(RIG))
	var s := sp.index_of(RigDef.for_id(RIG).idx("hat"))
	sp.kick(s, kick)
	var dt := 1.0 / fps
	var peak := 0.0
	var nan := false
	var t := 0.0
	var at_1s := INF
	while t < seconds:
		sp.step(dt)
		var v := sp.value(s)
		if is_nan(v) or is_inf(v):
			nan = true
		peak = maxf(peak, absf(v))
		t += dt
		if at_1s == INF and t >= 1.5:
			at_1s = absf(v)
	return {"peak": peak, "nan": nan, "end": absf(sp.value(s)), "late": at_1s, "awake": sp.awake}


func test_springs_stable_and_settle_at_30_60_120_fps() -> void:
	var ref := _run_spring(60.0, 3.0, 20.0)
	assert_almost_eq(ref["peak"], 20.0, 1.5, "a kick of 20° peaks at ≈ 20°")
	for fps in [30.0, 60.0, 120.0, 144.0]:
		var r := _run_spring(fps, 3.0, 20.0)
		assert_false(r["nan"], "no NaN at %d fps" % fps)
		assert_almost_eq(r["peak"], ref["peak"], 2.0, "same peak at %d fps" % fps)
		assert_lt(r["late"], 1.0, "settled below 1° after 1.5 s at %d fps" % fps)
		assert_lt(r["end"], 0.1, "at rest after 3 s at %d fps" % fps)
	# Huge frame spikes stay bounded (clamp ±25° from rig.json).
	var spike := _run_spring(5.0, 3.0, 400.0)
	assert_false(spike["nan"])
	assert_le(spike["peak"], 25.0001, "clamped")


func test_springs_follow_body_acceleration() -> void:
	var rig := RigDef.for_id(RIG)
	var sp := Springs.new()
	sp.setup(rig)
	var xf: Array[Transform2D] = []
	var pose := PoseLib.for_rig(RIG).pose("m_stand")
	RigSampler.solve(rig, pose, xf)
	var s := sp.index_of(rig.idx("hat"))
	# Sit still, then jolt the character sideways for a few frames.
	for i in 10:
		sp.feed(xf, Vector2.ZERO, 1.0, 1.0 / 60.0)
		sp.step(1.0 / 60.0)
	assert_almost_eq(sp.value(s), 0.0, 0.0001, "no motion, no spring")
	var x := 0.0
	var v := 0.0
	var peak := 0.0
	for i in 40:
		v = 900.0 if i < 6 else 0.0
		x += v / 60.0
		sp.feed(xf, Vector2(x, 0), 1.0, 1.0 / 60.0)
		sp.step(1.0 / 60.0)
		peak = minf(peak, sp.value(s))
	assert_lt(peak, -2.0, "the hat lags (tilts back) when the body accelerates forward: %.1f°" % peak)


func test_blinks_are_seeded_and_timed() -> void:
	var rig := RigDef.for_id(RIG)
	var lib := PoseLib.for_rig(RIG)
	var a := FaceState.new()
	var b := FaceState.new()
	var c := FaceState.new()
	a.setup(rig, lib, 42)
	b.setup(rig, lib, 42)
	c.setup(rig, lib, 43)
	var starts_a := PackedInt32Array()
	var starts_c := PackedInt32Array()
	var closed_frames := 0
	var prev := 0
	for f in 60 * 120:
		a.advance(1.0)
		b.advance(1.0)
		c.advance(1.0)
		if a.blink_phase() != b.blink_phase():
			fail("same seed, same blinks (frame %d)" % f)
			return
		if a.blink_count != prev:
			starts_a.append(f)
			prev = a.blink_count
		if a.blink_phase() == 2:
			closed_frames += 1
		if c.blink_t == 0.0:
			starts_c.append(f)
	assert_ne(starts_a, starts_c, "another seed blinks elsewhere")
	assert_between(a.blink_count, 20, 60, "2–6 s apart over 2 minutes (+ doubles)")
	var doubles := 0
	for i in range(1, starts_a.size()):
		var gap := starts_a[i] - starts_a[i - 1]
		if gap < 20:
			doubles += 1
			assert_eq(gap, FaceState.BLINK_LEN + FaceState.DOUBLE_GAP, "a double follows right after")
		else:
			assert_between(gap, FaceState.BLINK_MIN_F + FaceState.BLINK_LEN, FaceState.BLINK_MAX_F + FaceState.BLINK_LEN, "interval 2–6 s")
	assert_eq(doubles, a.double_count)
	assert_between(float(a.double_count) / float(maxi(1, a.blink_count - a.double_count)), 0.03, 0.35, "≈ 15 % doubles")
	assert_eq(closed_frames, a.blink_count * 2, "6-frame blinks: 2 closed frames each")


func test_blinks_suppressed_during_takes_and_apply_to_eyes() -> void:
	var rig := RigDef.for_id(RIG)
	var lib := PoseLib.for_rig(RIG)
	var f := FaceState.new()
	f.setup(rig, lib, 7)
	f.suppressed = true
	for i in 60 * 30:
		f.advance(1.0)
	assert_eq(f.blink_count, 0, "no blinks during a take")
	f.suppressed = false
	var pose := lib.pose("m_stand").duplicate()
	while f.blink_phase() != 2:
		f.advance(1.0)
	f.apply(pose)
	var eyes := rig.idx("face_eyes")
	assert_eq(int(pose[RigDef.ch(eyes, RigDef.C_TEX)]), rig.tex_index(eyes, "closed"))
	assert_eq(pose[RigDef.ch(rig.idx("face_pupils"), RigDef.C_VIS)], 0.0, "pupils hide while shut")
	f.set_face("shock")
	var p2 := lib.pose("m_stand").duplicate()
	f.blink_t = -1.0
	f.apply(p2)
	assert_eq(int(p2[RigDef.ch(rig.idx("face_mouth"), RigDef.C_TEX)]), rig.tex_index(rig.idx("face_mouth"), "open"), "override wins")
	f.on_clip_face_changed()
	assert_false(f.has_override(), "a keyed face change clears overrides")


func test_prop_launch_is_deterministic_closed_form() -> void:
	var rig := RigDef.for_id(RIG)
	var a := PropSim.new()
	var b := PropSim.new()
	a.setup(rig)
	b.setup(rig)
	var start := Transform2D(0.3, Vector2(40, -260))
	a.launch(0, 27.0, start, Vector2(140, -1000), 900.0)
	b.launch(0, 27.0, start, Vector2(140, -1000), 900.0)
	# Evaluate b out of order (seeking) — same answers.
	var frames: Array[int] = [120, 30, 90, 27, 60, 200, 45]
	for f in frames:
		var xa := a.flying_xf(0, float(f))
		var xb := b.flying_xf(0, float(f))
		assert_true(xa.is_equal_approx(xb), "frame %d identical" % f)
	var apex := INF
	var landed_f := -1
	var prev_y := -INF
	for f2 in range(27, 240):
		var y := a.flying_xf(0, float(f2)).origin.y
		apex = minf(apex, y)
		if landed_f < 0 and f2 > 40 and y >= -a.radius[0] - 12.0:
			landed_f = f2
		prev_y = y
	assert_lt(apex, -400.0, "flies up")
	assert_between(landed_f, 70, 100, "lands after ≈ 1 s")
	var rest := a.flying_xf(0, 400.0)
	assert_almost_eq(rest.origin.y, -a.radius[0], 0.01, "comes to rest on the floor")
	assert_true(rest.is_equal_approx(a.flying_xf(0, 500.0)), "and stays there")
	var bounce_up := false
	var y0 := PropSim.ballistic(Vector2.ZERO, Vector2(0, 600), 0.0, 0.0, 0.0, 100.0)
	var last := y0.y
	for i in 120:
		var q := PropSim.ballistic(Vector2.ZERO, Vector2(0, 600), 0.0, 0.0, float(i) / 60.0, 100.0)
		if q.y < last - 0.01:
			bounce_up = true
		last = q.y
		assert_le(q.y, 100.0001, "never through the floor")
	assert_true(bounce_up, "bounces off the floor")
