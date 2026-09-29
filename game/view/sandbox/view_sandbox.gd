## ViewSandbox — runs the whole view on FakeWorld's scripted ≈ 47 s timeline (or on the real
## SimWorld with `--sim` when it exists), for screenshots, frame sequences and perf runs.
##
## User args (after `--`):
##   --scenario=<name>  jump to a moment: walk, bubble, stare_off, stare_on, squeak_rings,
##                      entry_warning, gag_punch, captions, pip, pip_escalate, spotted,
##                      near_miss, busted_cam, stalls_t4, overview, peek (default: full run)
##   --realtime         drive from the real frame delta (default: a fixed 1/60 s step with a
##                      virtual juice clock, so frame N after the start is reproducible)
##   --rig              draw characters with the rig system (RigPlayer + rig data) when they
##                      load; the default is the stand-in puppets (`--puppets`) until the
##                      Stage-2 character clips exist (a rig without clips falls back too)
##   --rig=<id>         draw both characters with rig <id> (e.g. _mannequin: the rig path with
##                      the stand-in clips)
##   --sim              use res://sim/world/sim_world.gd + the ContentDB when present
## It wires exactly what a NightScene will: SimDriver → WorldView (+ FxLayer) → GagStager →
## CameraDirector → PipView (+ the ui's PipFrame when present) → AudioDirector → StallsView.
class_name ViewSandbox
extends Node2D

const SIM_WORLD := "res://sim/world/sim_world.gd"
const CONTENT_DB := "res://sim/content/content_db.gd"
const PIP_FRAME := "res://ui/widgets/pip_frame.gd"
const DT := 1.0 / 60.0

var scenario: String = "full"
var fixed_step: bool = true
var puppets: bool = true
## `--rig=<id>`: draw both characters with that rig (e.g. _mannequin).
var rig_override: String = ""
var world: RefCounted = null
var driver: SimDriver = null
var world_view: WorldView = null
var cam: CameraDirector = null
var stager: GagStager = null
var audio: AudioDirector = null
var pip: PipView = null
var stalls: StallsView = null
var pip_frame: Control = null
var _vt := 0.0
var _frame := 0
var _hud: CanvasLayer = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a == "--realtime":
			fixed_step = false
		elif a == "--puppets":
			puppets = true
		elif a == "--rig":
			puppets = false
		elif a.begins_with("--rig="):
			puppets = false
			rig_override = a.substr(6)
	RenderingServer.set_default_clear_color(Color("#1E1830"))
	world = _make_world(OS.get_cmdline_user_args().has("--sim"))
	build(world)
	_seek(int(FakeWorld.SCENARIOS.get(scenario, 0)) if world is FakeWorld else 0)
	print("[ViewSandbox] scenario=%s start=%d rig=%s house=%s" % [scenario, driver.snapshot().tick,
		"on" if world_view.hush_view.uses_rig else "puppet", world_view.layout.source])


func _make_world(want_sim: bool) -> RefCounted:
	if want_sim:
		var sw := ViewKit.soft_script(SIM_WORLD)
		var cdb := ViewKit.soft_script(CONTENT_DB)
		if sw != null and cdb != null and sw.has_method("create"):
			var db: Variant = cdb.call("load_dir", "res://data")
			var w: Variant = sw.call("create", db, "n01_throat_tea", {})
			if w is RefCounted:
				return w
		push_warning("ViewSandbox: --sim requested but the sim is not available; using FakeWorld")
	return FakeWorld.create()


## Build the full view stack for `w` (public so tests can reuse the wiring).
func build(w: RefCounted) -> void:
	driver = SimDriver.new()
	add_child(driver)
	driver.setup(w)
	cam = CameraDirector.new()
	cam.time_source = driver
	world_view = WorldView.new()
	world_view.force_puppets = puppets
	world_view.rig_override = rig_override
	world_view.cam = cam
	add_child(world_view)
	world_view.setup(null, null, driver)
	add_child(cam)
	cam.setup(world_view.layout)
	cam.stage_x_range = world_view.lit_x_range()
	cam.make_current()
	cam.follow(world_view.hush_view, _hush_lead)
	pip = PipView.new()
	add_child(pip)
	pip.target = world_view.bellows_view
	stager = GagStager.new()
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
	sl.add_child(stalls)
	audio.laugh.connect(stalls.react)
	audio.crowd_special.connect(stalls.special)
	_hud = CanvasLayer.new()
	_hud.layer = 10
	_hud.name = "HudPreview"
	add_child(_hud)
	_make_pip_frame()
	driver.ticked.connect(_on_ticked)
	if fixed_step:
		for n in [driver, driver.juice, world_view, world_view.fx, cam, stager, audio, pip, stalls]:
			(n as Node).set_process(false)
		driver.juice.test_now_us = 0


func _make_pip_frame() -> void:
	var s := ViewKit.soft_script(PIP_FRAME)
	if s != null:
		var n: Variant = s.new()
		if n is Control:
			pip_frame = n
	if pip_frame == null:
		pip_frame = _SimplePipFrame.new()
	_hud.add_child(pip_frame)
	pip.shown_changed.connect(func(on: bool) -> void:
		if pip_frame.has_method("set_shown"):
			pip_frame.call("set_shown", on))
	pip.pip_resized.connect(func(_s: Vector2i) -> void:
		if pip_frame.has_method("set_escalated"):
			pip_frame.call("set_escalated", pip.is_escalated()))
	if pip_frame.has_method("set_texture"):
		pip_frame.call("set_texture", pip.get_texture())


## Hush's walk direction for the camera look-ahead (x = dir, y = running).
func _hush_lead() -> Vector2:
	var h := driver.snapshot().hush
	return Vector2(float(h.facing), 1.0 if h.running else 0.0)


func _seek(t: int) -> void:
	audio.muted = true
	while driver.snapshot().tick < t:
		driver.step_now()
	audio.muted = false
	audio.clear_pending()
	stager.clear_pending()
	stager.settle_gags()
	driver.juice.reset()
	world_view.fx.clear()
	stalls.special("rest")
	cam.snap_now()
	cam.reset_motion()
	# One settled frame so characters and the camera start in place.
	_step_views(0.0)
	cam.snap_now()
	# Re-apply the PiP rule against the snapped camera and skip its hide delay.
	stager.advance(0.0)
	pip.settle()


func _on_ticked(events: Array) -> void:
	for ev in events:
		var d: Dictionary = ev
		if ViewKit.s(d.get("e", "")) == "_tap":
			var room := ViewKit.s(d.get("room", "kitchen"))
			var fy := world_view.layout.room_floor_y(room)
			var to := Vector2(float(d.get("x", 0)), fy)
			world_view.fx.ripple(to + Vector2(0, -40))
			var from := world_view.hush_view.global_position
			world_view.fx.path_dots(PackedVector2Array([from + Vector2(0, -6), to + Vector2(0, -6)]))


func _process(delta: float) -> void:
	var dt := DT if fixed_step else delta
	_frame += 1
	_scenario_actions()
	if fixed_step:
		_vt += dt
		driver.juice.test_now_us = int(_vt * 1000000.0)
		driver.juice.advance()
		driver.advance(dt)
		_step_views(dt)
	_update_hud()


func _step_views(dt: float) -> void:
	world_view.advance(dt)
	stager.advance(dt)
	audio.advance(dt)
	cam.advance(driver.view_delta() if dt > 0.0 else 0.0, dt)
	world_view.fx.advance(dt)
	pip.advance(dt)
	stalls.advance(dt)


func _scenario_actions() -> void:
	match scenario:
		"overview":
			if _frame == 2:
				cam.toggle_overview()
		"peek", "bubble":
			if _frame == 4:
				cam.peek(world_view.bellows_view.global_position + Vector2(0, -200), 3.0,
					func() -> Vector2: return world_view.bellows_view.global_position + Vector2(0, -200))


func _update_hud() -> void:
	if pip_frame == null:
		return
	var vs := get_viewport_rect().size
	var sz := Vector2(704, 396) if pip.is_escalated() else Vector2(448, 252)
	pip_frame.position = Vector2(vs.x - 24.0 - sz.x, 24.0)
	var snap := driver.snapshot()
	if pip_frame.has_method("set_tier"):
		pip_frame.call("set_tier", snap.bellows.tier)
	if pip_frame.has_method("set_glyph"):
		pip_frame.call("set_glyph", snap.bubble_glyph)


## Minimal frame for the PiP texture when the ui task's PipFrame is not available.
class _SimplePipFrame extends Control:
	var texture: Texture2D = null
	var shown := false
	var escalated := false

	func set_texture(t: Texture2D) -> void:
		texture = t

	func set_shown(on: bool) -> void:
		shown = on
		visible = on

	func set_escalated(on: bool) -> void:
		escalated = on

	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var sz := Vector2(704, 396) if escalated else Vector2(448, 252)
		draw_rect(Rect2(Vector2(-10, -10), sz + Vector2(20, 20)), Color("#1B2340"))
		draw_rect(Rect2(Vector2(-6, -6), sz + Vector2(12, 12)), Color("#FFF4E0"))
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, sz), false)
