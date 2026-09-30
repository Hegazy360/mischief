## PerfProbe3D — the O2 device perf probe (R3D index §3.8, ruling R18): a self-running scene, no sim. The Prologue's
## kitchen through House3D (r3d-sets), both cast glbs on RigPlayer3D (r3d-rig; whatever is current) — Hush walking the
## kitchen, Bellows at the tea stool — the Bellows window open, outlines and halos on, a gag burst every 10 s (a 1.4
## punch-in + particles), and five 20 s runs: MSAA 2× / off, render scale 1.0 / 0.85, outlines on / off. Then a
## summary card on screen (fps p50/p95, frame ms p95 per setting, draw calls, primitives, texture MB), also printed
## and written as `[perfprobe]` lines to `user://perfprobe.log`. It needs nothing the export excludes
## (view3d/sandbox, scenes/dev, tests, tools). `--probe-s=<s>` shortens each run (desktop checks).
extends Node3D

const EPISODE := "p00_curtain_up"
const RUN_S := 20.0
const GAG_EVERY_S := 10.0
const LOG_PATH := "user://perfprobe.log"
## [label, msaa (0 off / 2), render scale, outlines]
const SETTINGS := [["msaa2 scale1.0 ink on", 2, 1.0, true], ["msaa off", 0, 1.0, true], ["scale 0.85", 2, 0.85, true],
	["ink off", 2, 1.0, false], ["cheapest", 0, 0.85, false]]

var cam: CameraDirector3D = null
var house: Node3D = null
var hush: Node3D = null
var bellows: Node3D = null
var pip: PipView3D = null
var fx: Fx3D = null
var card: Label = null
var run_s: float = RUN_S
var results: Array = []

var _set_i := -1
var _t := 0.0
var _gag_t := 0.0
var _dir := 1.0
var _ms := PackedFloat32Array()
var _dc := PackedFloat32Array()
var _prim := 0.0
var _tex := 0.0
var _last_us := 0
var _ink: Array = []        # [material, next_pass]
var _done := false
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-s="):
			run_s = maxf(2.0, float(a.substr(10)))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = View3DConst.BG
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	add_child(StageLighting3D.new())
	_build_set()
	hush = _rig("hush", Vector3(14.6, 0.0, View3DConst.LANE_Z))
	bellows = _rig("bellows", Vector3(15.0, 0.0, View3DConst.BELLOWS_STATION_Z))
	cam = CameraDirector3D.new()
	add_child(cam)
	cam.make_current()
	var hj: Variant = ViewKit.json("res://data/house/house.json")
	cam.setup(hj, PackedStringArray(["parlour", "kitchen", "hall"]))
	cam.follow(hush, func() -> float: return _dir)
	fx = Fx3D.new()
	add_child(fx)
	pip = PipView3D.new()
	add_child(pip)
	pip.setup(null, cam)
	pip.forced_target = bellows
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var frame := PipView3D.SimpleFrame.new()
	layer.add_child(frame)
	frame.bind(pip)
	frame.visible = true
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(View3DConst.INK, 0.82)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(60, 250)
	layer.add_child(panel)
	card = Label.new()
	card.add_theme_font_size_override("font_size", 40)
	card.add_theme_color_override("font_color", Color.WHITE)
	card.add_theme_color_override("font_outline_color", View3DConst.INK)
	card.add_theme_constant_override("outline_size", 8)
	panel.add_child(card)
	_collect_ink()
	_next_setting()
	_log("[perfprobe] start %s | %s | %s | view %s" % [Time.get_datetime_string_from_system(true), OS.get_model_name(),
		RenderingServer.get_video_adapter_name(), get_viewport().get_visible_rect().size])


func _build_set() -> void:
	var db := ContentDB.load_dir("res://data")
	var ep: Variant = db.episodes.get(EPISODE, null)
	var hj: Variant = ViewKit.json("res://data/house/house3d.json")
	var h3: Dictionary = hj if hj is Dictionary else {}
	if ep is EpisodeDef and ResourceLoader.exists("res://view3d/set/house_3d.gd"):
		var r := SetList.for_episode(db, ep as EpisodeDef, h3)
		var hs: Variant = load("res://view3d/set/house_3d.gd")
		if not (hs is Script and (hs as Script).can_instantiate()):
			push_warning("PerfProbe3D: House3D does not compile; no set")
			return
		var h: Variant = (hs as Script).new()
		house = h
		add_child(house)
		house.call("build", r, h3, db)
		for id in r.live:
			var p: Variant = house.call("prop", String(id))
			if p is Object and (p as Object).has_method("set_glow"):
				(p as Object).call("set_glow", View3DConst.verb_color(StringName(str(r.live[id]))), 1.0)


func _rig(id: String, at: Vector3) -> Node3D:
	var n: Node3D = null
	if ResourceLoader.exists("res://view3d/char/rig_player_3d.gd"):
		var s: Variant = load("res://view3d/char/rig_player_3d.gd")
		n = (s as Script).new()
		add_child(n)
		n.call("setup", id, "")
		var loop := "%s/loco_walk" % id if id == "hush" else "%s/loco_idle" % id
		if bool(n.call("has_clip", loop)):
			n.call("play", loop, {"loop": true})
		n.call("set_facing", 1, false)
		n.call("set_cheat", View3DConst.CHEAT_WALK if id == "hush" else View3DConst.CHEAT_IDLE, 0.0)
	else:
		n = Node3D.new()
		add_child(n)
	n.position = at
	return n


func _collect_ink() -> void:
	_ink.clear()
	_walk(self)


func _walk(n: Node) -> void:
	if n is GeometryInstance3D:
		var mats: Array = []
		var g := n as GeometryInstance3D
		if g.material_override != null:
			mats.append(g.material_override)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null:
					mats.append(m)
		for m in mats:
			if m is Material and (m as Material).next_pass != null:
				_ink.append([m, (m as Material).next_pass])
	for c in n.get_children():
		_walk(c)


func _outlines(on: bool) -> void:
	for pair in _ink:
		(pair[0] as Material).next_pass = pair[1] if on else null
	cam.cull_mask = View3DConst.MASK_MAIN if on else View3DConst.MASK_MAIN & ~View3DConst.MASK_PROP_INK


func _next_setting() -> void:
	if _set_i >= 0:
		results.append(_summary(SETTINGS[_set_i][0]))
		_log(_line(results[-1]))
	_set_i += 1
	if _set_i >= SETTINGS.size():
		_finish()
		return
	var st: Array = SETTINGS[_set_i]
	get_viewport().msaa_3d = Viewport.MSAA_2X if int(st[1]) == 2 else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = float(st[2])
	_outlines(bool(st[3]))
	_t = 0.0
	_ms.clear()
	_dc.clear()
	_prim = 0.0
	_tex = 0.0
	_last_us = 0


func _process(delta: float) -> void:
	if _done:
		return
	_frames += 1
	var now := Time.get_ticks_usec()
	if _last_us > 0 and _t > 1.0:
		_ms.append(float(now - _last_us) / 1000.0)
		_dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_prim = maxf(_prim, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		_tex = maxf(_tex, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
	_last_us = now
	var dt := minf(delta, 0.1)
	_t += dt
	_gag_t += dt
	# Hush walks the kitchen back and forth at the tiptoe speed
	hush.position.x += _dir * 2.0 * dt
	if hush.position.x > 18.6 or hush.position.x < 14.4:
		_dir = -_dir
		if hush.has_method("set_facing"):
			hush.call("set_facing", int(_dir), true)
	for r in [hush, bellows]:
		if (r as Node).has_method("advance") and "auto_advance" in r and not bool((r as Node).get("auto_advance")):
			(r as Node).call("advance", dt)
	if _gag_t >= GAG_EVERY_S:
		_gag_t = 0.0
		var chest := bellows.position + Vector3(0.0, 1.1, 0.0)
		cam.request_gag(chest, 1.4, 11, 60, 21, 0, 4.0)
		cam.shake(0.3)
		for k in ["choo_puff", "drops", "stars", "sparkles"]:
			fx.burst(k, chest + Vector3(0.0, 0.4, 0.0))
	cam.advance(dt, dt)
	pip.advance(dt)
	card.text = "PERF PROBE  %d / %d  %s\n%.0f s" % [_set_i + 1, SETTINGS.size(), SETTINGS[_set_i][0], maxf(0.0, run_s - _t)]
	if _t >= run_s:
		_next_setting()


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(round(q * float(b.size() - 1))), 0, b.size() - 1)]


func _summary(label: String) -> Dictionary:
	var p50 := _pct(_ms, 0.5)
	var p95 := _pct(_ms, 0.95)
	var mx := 0.0
	for v in _dc:
		mx = maxf(mx, v)
	return {"setting": label, "frames": _ms.size(), "fps_p50": 1000.0 / maxf(0.01, p50), "fps_p95": 1000.0 / maxf(0.01, p95),
		"frame_ms_p50": p50, "frame_ms_p95": p95, "draw_calls_p95": _pct(_dc, 0.95), "draw_calls_max": mx,
		"primitives_max": _prim, "tex_mb": _tex}


func _line(r: Dictionary) -> String:
	return "[perfprobe] %-22s fps p50 %5.1f p95 %5.1f | frame ms p95 %6.1f | draws p95 %3.0f max %3.0f | prims %6.0f | tex %5.1f MB | %d frames" % [
		r["setting"], r["fps_p50"], r["fps_p95"], r["frame_ms_p95"], r["draw_calls_p95"], r["draw_calls_max"], r["primitives_max"],
		r["tex_mb"], r["frames"]]


func _finish() -> void:
	_done = true
	_outlines(true)
	var lines := PackedStringArray(["PERF PROBE — %s" % OS.get_model_name()])
	for r in results:
		lines.append("%s: %.0f fps (p95 %.0f) · %.1f ms p95 · %d draws · %d k tris · %.0f MB" % [r["setting"], r["fps_p50"],
			r["fps_p95"], r["frame_ms_p95"], int(r["draw_calls_p95"]), int(r["primitives_max"] / 1000.0), r["tex_mb"]])
	card.text = "\n".join(lines)
	card.add_theme_font_size_override("font_size", 34)
	_log("[perfprobe] done %d frames" % _frames)


## The probe's results (tests / the e2e driver).
func is_done() -> bool:
	return _done


func _log(line: String) -> void:
	print(line)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
