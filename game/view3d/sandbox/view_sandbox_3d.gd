## ViewSandbox3D — the 3D view's shot scene (brief r3d-view3d §4.2, §6). It wires exactly what NightScene will:
## SimDriver → WorldView3D → GagStager3D → CameraDirector3D → PipView3D (+ a plain frame) → AudioDirector →
## StallsView, over the real sim or FakeWorld.
##
## User args (after `--`):
##   --sim --episode=<id> [--cmds=/abs.json] [--seek=<tick>]   the real SimWorld (default episode p00_curtain_up)
##   --scenario=<name>          FakeWorld's scripted timeline, jumped to a named moment (FakeWorld.SCENARIOS)
##   --realtime                 drive from the real frame delta (default: a fixed 1/60 s step, reproducible frames)
##   --stand-ins                capsules instead of the rigs
##   --window=sim|lean          the Bellows-window mode (index R15)
##   --msaa=0|2|4               3D MSAA (default 2; timing runs use 0)
##   --scale=<0.5..1>           3D render scale (default 1.0)
##   --aspect-debug             print the camera numbers once
##   --fallbacks                print WorldView3D.fallback_counts() every 60 frames and at exit
##   --share                    print the Bellows-window share (pip_on_share, pip_longest_s) at exit
##   --run-s=<s>                quit after this many seconds of (real or fixed-step) time, printing `[perf3d]`:
##                              frame ms p50/p95, draw calls p95/max, primitives max, texture MB, script ms p95
##   --studio --fig=… [--cam=… --bg=… --floor=… --outline=… --face-dir=…]   the look-dev shading stage
## Frame sequences / perf logs come from DevShot (`--shot-seq=…`, `--perf-log`).
extends Node

const DT := 1.0 / 60.0

var studio: LookdevStudio3D = null
var world: RefCounted = null
var driver: SimDriver = null
var world_view: WorldView3D = null
var cam: CameraDirector3D = null
var stager: GagStager3D = null
var audio: AudioDirector = null
var pip: PipView3D = null
var stalls: StallsView = null
var fixed_step: bool = true
var episode: String = "p00_curtain_up"
var scenario: String = "full"
var cmds_path: String = ""
var seek_tick: int = -1
var print_fallbacks: bool = false
var print_share: bool = false
var run_s: float = -1.0
var _vt := 0.0
var _frame := 0
var _t_real := 0.0
var _ms := PackedFloat32Array()
var _dc := PackedFloat32Array()
var _script_ms := PackedFloat32Array()
var _sim_us := PackedFloat32Array()
var _view_us := PackedFloat32Array()
var _first_us := 0
var _prim_max := 0.0
var _tex_max := 0.0
var _last_us := 0
var _hud: CanvasLayer = null
var _pip_frame: PipView3D.SimpleFrame = null


func _ready() -> void:
	var opt := {}
	var figs := PackedStringArray()
	var flags := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fig="):
			figs.append(a.substr(6))
		elif a.begins_with("--") and a.contains("="):
			opt[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			flags[a.substr(2)] = true
	if flags.has("studio") or not figs.is_empty():
		get_viewport().msaa_3d = Viewport.MSAA_4X if str(opt.get("msaa", "4")) == "4" else Viewport.MSAA_2X
		add_child(StageLighting3D.new())
		studio = LookdevStudio3D.new()
		add_child(studio)
		studio.build(opt, figs)
		return
	fixed_step = not flags.has("realtime")
	print_fallbacks = flags.has("fallbacks")
	print_share = flags.has("share")
	episode = str(opt.get("episode", episode))
	scenario = str(opt.get("scenario", scenario))
	cmds_path = str(opt.get("cmds", ""))
	seek_tick = int(opt.get("seek", "-1"))
	run_s = float(opt.get("run-s", "-1"))
	var msaa := str(opt.get("msaa", "2"))
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if msaa == "0" else (Viewport.MSAA_4X if msaa == "4" else Viewport.MSAA_2X)
	get_viewport().scaling_3d_scale = clampf(float(opt.get("scale", "1.0")), 0.5, 1.0)
	var st := ViewKit.autoload("Settings")
	if opt.has("window") and st != null and st.has_method("set_value"):
		st.call("set_value", "bellows_window", str(opt["window"]))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = View3DConst.BG
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	world = _make_world(flags.has("sim"))
	build(world, flags.has("stand-ins"))
	if opt.has("window"):
		world_view.window_mode = str(opt["window"])
	world_view.profile = run_s > 0.0
	if cmds_path != "":
		var j := JSON.new()
		if FileAccess.file_exists(cmds_path) and j.parse(FileAccess.get_file_as_string(cmds_path)) == OK:
			driver.set_script_cmds(j.data)
		else:
			push_warning("ViewSandbox3D: cannot read --cmds=%s" % cmds_path)
	if world is FakeWorld:
		_seek(int(FakeWorld.SCENARIOS.get(scenario, 0)))
	else:
		_seek(maxi(0, seek_tick))
	print("[ViewSandbox3D] episode=%s scenario=%s start=%d rig=%s/%s set=%s" % [episode if not (world is FakeWorld) else "fake",
		scenario, driver.snapshot().tick, "rig" if world_view.hush_view.uses_rig else "stand-in",
		"rig" if world_view.bellows_view.uses_rig else "stand-in", "greybox" if world_view.set3d is GreyboxSet3D else "House3D"])
	if flags.has("aspect-debug"):
		print("[ViewSandbox3D] view %s px/m lane %.1f back %.1f visible %.2f m" % [cam.view_size(), cam.px_per_m_at(-1.0),
			cam.px_per_m_at(-2.4), cam.visible_width_at()])


func _make_world(want_sim: bool) -> RefCounted:
	if want_sim:
		var db := ContentDB.load_dir("res://data")
		var w := SimWorld.create(db, episode, {})
		if w != null:
			return w
		push_warning("ViewSandbox3D: --sim: episode %s did not load; using FakeWorld" % episode)
	var fw := FakeWorld.create()
	if FakeWorld.DEMOS.has(scenario):
		fw.demo = String(FakeWorld.DEMOS[scenario])
		fw.reset()
	return fw


## Build the full 3D view stack for `w` (public so tests reuse the wiring).
func build(w: RefCounted, stand_ins: bool = false) -> void:
	driver = SimDriver.new()
	add_child(driver)
	driver.setup(w)
	cam = CameraDirector3D.new()
	cam.time_source = driver
	add_child(cam)
	cam.make_current()
	world_view = WorldView3D.new()
	world_view.force_stand_ins = stand_ins
	world_view.cam = cam
	add_child(world_view)
	world_view.setup(null, null, driver)
	cam.follow(world_view.hush_view, _hush_lead)
	cam.set_other(world_view.bellows_view)
	cam.set_keep_visible(_keep_boxes)
	pip = PipView3D.new()
	add_child(pip)
	pip.setup(world_view, cam)
	world_view.pip = pip
	stager = GagStager3D.new()
	add_child(stager)
	stager.setup(driver, cam, world_view, pip)
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup(driver, cam, world_view)
	var sl := CanvasLayer.new()
	sl.layer = 9
	sl.name = "StallsLayer"
	add_child(sl)
	stalls = StallsView.new()
	stalls.hidden_at_rest = true
	sl.add_child(stalls)
	audio.laugh.connect(stalls.react)
	audio.crowd_special.connect(stalls.special)
	_hud = CanvasLayer.new()
	_hud.layer = 10
	_hud.name = "HudPreview"
	add_child(_hud)
	_pip_frame = PipView3D.SimpleFrame.new()
	_hud.add_child(_pip_frame)
	_pip_frame.bind(pip)
	driver.ticked.connect(_on_ticked)
	for n in [driver, driver.juice, world_view, cam, stager, audio, pip, stalls]:
		(n as Node).set_process(false)
	if fixed_step:
		driver.juice.test_now_us = 0


func _keep_boxes() -> Array:
	var out: Array = []
	var snap := driver.snapshot()
	for id in world_view.live:
		var hs := world_view.layout.hotspot(String(id))
		if hs != null and hs.room == snap.hush.room and not (hs.kind in ["door", "stairs", "exit"]):
			out.append(world_view.hotspot_box(String(id)))
	return out


func _hush_lead() -> Vector2:
	var h := driver.snapshot().hush
	return Vector2(float(h.facing) if h.moving else 0.0, 1.0 if h.running else 0.0)


func _seek(t: int) -> void:
	audio.muted = true
	while driver.snapshot().tick < t:
		driver.step_now()
	audio.muted = false
	audio.clear_pending()
	stager.clear_pending()
	stager.settle_gags()
	driver.juice.reset()
	world_view.decals.clear()
	stalls.special("rest")
	cam.snap_now()
	cam.reset_motion()
	_step_views(0.0)
	cam.snap_now()
	_step_views(0.0)
	pip.settle()
	pip.reset_share()


func _on_ticked(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		if str(d.get("e", "")) == "hush_go" and not (world is FakeWorld):
			var tp := world_view.target_point(str(d.get("target", "")))
			if tp != Vector3.INF:
				world_view.tap_feedback(tp)


func _process(delta: float) -> void:
	if studio != null:
		return
	var dt := DT if fixed_step else delta
	_frame += 1
	if run_s > 0.0:
		_sample_perf(delta)
	if print_fallbacks and _frame % 60 == 0:
		print("[ViewSandbox3D] frame %d tick %d fallbacks %s" % [_frame, driver.snapshot().tick, JSON.stringify(world_view.fallback_counts())])
	# the sandbox drives every node itself (both modes) so the view's script cost can be timed per frame
	if fixed_step:
		_vt += dt
		driver.juice.test_now_us = int(_vt * 1000000.0)
	driver.juice.advance()
	var t0 := Time.get_ticks_usec()
	driver.advance(dt)
	var t1 := Time.get_ticks_usec()
	_step_views(dt)
	if run_s > 0.0 and _frame > 10:
		_sim_us.append(float(t1 - t0))
		_view_us.append(float(Time.get_ticks_usec() - t1))


func _sample_perf(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _frame == 11:
		_first_us = now
	if _last_us > 0 and _frame > 10:
		_ms.append(float(now - _last_us) / 1000.0)
		_dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_script_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_prim_max = maxf(_prim_max, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		_tex_max = maxf(_tex_max, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
	_last_us = now
	_t_real += DT if fixed_step else delta
	if _t_real >= run_s:
		print(perf_line())
		if world_view.prof_frames > 0:
			var n := float(world_view.prof_frames)
			var pu := world_view.prof_us
			print("[perf3d] view phases mean µs/frame: hush %.0f | bellows %.0f | caught+recorder %.0f | props+cues %.0f | decals+fx %.0f | overlays %.0f" % [
				pu[0] / n, pu[1] / n, pu[2] / n, pu[3] / n, pu[4] / n, pu[5] / n])
		if pip != null:
			print("[ViewSandbox3D] window share %s" % JSON.stringify(pip.share()))
		run_s = -1.0
		get_tree().quit()


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(round(q * float(b.size() - 1))), 0, b.size() - 1)]


## `[perf3d] …` from the samples so far.
func perf_line() -> String:
	var mx := 0.0
	for v in _dc:
		mx = maxf(mx, v)
	var wall := float(Time.get_ticks_usec() - _first_us) / 1000000.0 if _first_us > 0 else 0.0
	var msaa_names := ["off", "2x", "4x", "8x"]
	return "[perf3d] frames %d wall_s %.1f fps %.1f sim_tick %d frame_ms p50 %.1f p95 %.1f | view script ms p50 %.2f p95 %.2f | sim ms p95 %.2f | draw calls p95 %.0f max %.0f | primitives max %.0f | tex MB %.1f | process ms p95 %.2f | msaa %s | %s" % [
		_ms.size(), wall, float(_ms.size()) / maxf(0.001, wall), driver.snapshot().tick, _pct(_ms, 0.5), _pct(_ms, 0.95),
		_pct(_view_us, 0.5) / 1000.0, _pct(_view_us, 0.95) / 1000.0, _pct(_sim_us, 0.95) / 1000.0, _pct(_dc, 0.95), mx,
		_prim_max, _tex_max, _pct(_script_ms, 0.95), msaa_names[clampi(get_viewport().msaa_3d, 0, 3)],
		"fixed-step" if fixed_step else "realtime"]


func _step_views(dt: float) -> void:
	world_view.advance(dt)
	stager.advance(dt)
	audio.advance(dt)
	cam.advance(driver.view_delta() if dt > 0.0 else 0.0, dt)
	pip.advance(dt)
	stalls.advance(dt)


func _exit_tree() -> void:
	if world_view == null:
		return
	if print_fallbacks:
		print("[ViewSandbox3D] final fallbacks %s" % JSON.stringify(world_view.fallback_counts()))
	if print_share and pip != null:
		print("[ViewSandbox3D] window share %s" % JSON.stringify(pip.share()))
