## PipView3D — the Bellows window (REDESIGN §2.2, §5.2 C8; R3D index §7.9): a SubViewport sharing the main World3D
## (no duplicate nodes) with its own Camera3D framing him (≈ 1.8 m tall in a 2.6 m-high frame), cull mask WORLD |
## CHAR (no prop ink / halo, no decals, no MAIN_ONLY FX), 400×225, rendered at 30 Hz and only while shown;
## `escalate(true)` grows it to 704×396 in the same corner for an off-screen payoff.
##
## **C8:** it shows iff Bellows is off-screen (`WorldView3D.bellows_on_screen()`: < 35 % of his projected bounds in
## the viewport) **and** the sim says the player may see him (`SimVisibility.pip_shows`; the GDD §3.7 rule on
## FakeWorld); it hides 1.5 s after that clears and at once when he comes on screen — never while he is on screen.
## **Two modes (R15)**, Settings / boot_config `bellows_window`: `"sim"` = the above; `"lean"` = while the only reason
## is adjacency (`SimVisibility.pip_reason == &"adjacent"`) and no reaction or emote-less micro-gag runs, the window
## stays closed and WorldView3D raises `edge_badge_wanted` (the HUD's edge badge shows him instead).
## The HUD's PipFrame reads `get_texture()`, `shown_changed`, `pip_resized`, `screen_rect()`.
class_name PipView3D
extends SubViewport

signal shown_changed(on: bool)
signal pip_resized(new_size: Vector2i)

const SIZE := Vector2i(400, 225)
const SIZE_ESCALATED := Vector2i(704, 396)
const HIDE_DELAY_S := 1.5
const FRAME_H_M := 2.6
const FRAME_H_ESCALATED_M := 3.0
const FOLLOW_TAU := 0.15
const DIST_M := 5.2
const MARGIN := 24.0

var cam: Camera3D = null
var wv: WorldView3D = null
var main_cam: CameraDirector3D = null
## Render at 30 Hz (every other frame) while shown.
var half_rate: bool = true
## Tests: the sim's C8 inputs instead of the world's ({sim_pip: bool, reason: StringName}).
var override_sim: Dictionary = {}
## The perf probe (no world view): always shown, following this node.
var forced_target: Node3D = null

var shown: bool = false
var _want := false
var _hide_t := 0.0
var _escalated := false
var _frame := 0
var _pos := Vector3.ZERO
var _snap := true
var _renders := 0
var _shown_frames := 0
var _frames := 0
var _longest := 0
var _run := 0


func _init() -> void:
	name = "PipView3D"
	process_priority = -20
	size = SIZE
	own_world_3d = false
	transparent_bg = false
	handle_input_locally = false
	gui_disable_input = true
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam = Camera3D.new()
	cam.name = "WindowCamera"
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 30.0
	cam.near = 0.5
	cam.far = 40.0
	cam.cull_mask = View3DConst.MASK_PIP
	add_child(cam)


func setup(world_view: WorldView3D, main: CameraDirector3D) -> void:
	wv = world_view
	main_cam = main
	cam.current = true


## Shows at once when `cond`; hides HIDE_DELAY_S after it clears.
func set_visible_if(cond: bool) -> void:
	_want = cond
	if cond:
		_hide_t = HIDE_DELAY_S
		if not shown:
			_set_shown(true)


func escalate(on: bool) -> void:
	if on == _escalated:
		return
	_escalated = on
	size = SIZE_ESCALATED if on else SIZE
	pip_resized.emit(size)
	if on:
		_set_shown(true)
		_hide_t = HIDE_DELAY_S


func is_escalated() -> bool:
	return _escalated


func hide_now() -> void:
	_want = false
	_hide_t = 0.0
	if shown and not _escalated:
		_set_shown(false)


## Skip the hide delay (seeks) and snap the camera.
func settle() -> void:
	_snap = true
	if not _want and not _escalated:
		_hide_t = 0.0
		if shown:
			_set_shown(false)


func is_shown() -> bool:
	return shown


func renders() -> int:
	return _renders


## The window's rect on the HUD (logical px): top-right, (W − S − 424, T + 24), 400×225 (704×396 escalated).
func screen_rect() -> Rect2:
	var vs := main_cam.view_size() if main_cam != null else Vector2(2400, 1080)
	var sz := Vector2(size)
	return Rect2(Vector2(vs.x - MARGIN - sz.x, MARGIN), sz)


## Share of shown frames and the longest shown run (s) since the last reset (R15's `pip_on_share`).
func share() -> Dictionary:
	return {"frames": _frames, "shown_frames": _shown_frames, "pip_on_share": float(_shown_frames) / maxf(1.0, float(_frames)),
		"pip_longest_s": float(maxi(_longest, _run)) / 60.0}


func reset_share() -> void:
	_frames = 0
	_shown_frames = 0
	_longest = 0
	_run = 0


func _set_shown(on: bool) -> void:
	if shown == on:
		return
	shown = on
	if on:
		_snap = true
	render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED
	shown_changed.emit(on)


## One render (NightWarm: the window's viewport compiles under the curtain).
func warm() -> bool:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


func _process(delta: float) -> void:
	advance(delta)


## A reaction / payoff or an emote-less micro-gag is running (the lean mode opens the window for those).
static func is_busy(snap: ViewSnapshot, bv: CharacterView3D) -> bool:
	return snap.bellows.reacting or (bv != null and bv.ctx.mg != "" and bv.ctx.mg_emote == "")


## Pure C8 decision: show the window? (`on_screen` = he is on the main screen; `sim_pip` = SimVisibility.pip_shows;
## `reason` = pip_reason; `lean` = the lean mode; `busy` = a reaction / payoff / emote-less micro-gag runs.)
static func want_window(on_screen: bool, sim_pip: bool, reason: StringName, lean: bool, busy: bool) -> bool:
	if on_screen or not sim_pip:
		return false
	if lean and reason == &"adjacent" and not busy:
		return false
	return true


func advance(delta: float) -> void:
	if forced_target != null:
		if not shown:
			_set_shown(true)
		_follow_node(forced_target, delta)
		_frame += 1
		if not half_rate or _frame % 2 == 0:
			render_target_update_mode = SubViewport.UPDATE_ONCE
			_renders += 1
		return
	if wv == null:
		return
	var snap: ViewSnapshot = wv._snap()
	if snap == null:
		return
	var on_screen := wv.bellows_on_screen()
	var sim_pip := false
	var reason := &""
	if not override_sim.is_empty():
		sim_pip = bool(override_sim.get("sim_pip", false))
		reason = StringName(str(override_sim.get("reason", "")))
	elif wv.world is SimWorld:
		sim_pip = SimVisibility.pip_shows(wv.world as SimWorld)
		reason = SimVisibility.pip_reason(wv.world as SimWorld)
	else:
		sim_pip = PipView.rule(snap, main_cam.visible_world_rect() if main_cam != null else Rect2(), wv.layout, wv.entry_warning_active()) \
				or (snap.bellows.present and snap.bellows.room == snap.hush.room)
		reason = &"room" if snap.bellows.room == snap.hush.room else &"adjacent"
	var busy := PipView3D.is_busy(snap, wv.bellows_view)
	var lean := wv.window_mode == "lean"
	var want := PipView3D.want_window(on_screen, sim_pip, reason, lean, busy)
	if on_screen and not _escalated:
		hide_now()
	elif want:
		set_visible_if(true)
	else:
		_want = false
	if shown and not _want and not _escalated:
		_hide_t -= delta
		if _hide_t <= 0.0:
			_set_shown(false)
	# share bookkeeping (60 Hz fixed steps and real frames alike)
	_frames += 1
	if shown:
		_shown_frames += 1
		_run += 1
	else:
		_longest = maxi(_longest, _run)
		_run = 0
	wv.set_window_shown(shown, 1 if on_screen else 0)
	if not shown:
		return
	_follow(delta)
	_frame += 1
	if not half_rate or _frame % 2 == 0:
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_renders += 1


func _follow(delta: float) -> void:
	var bv := wv.bellows_view
	if bv == null:
		return
	_frame_on(bv.feet_world(), delta)


func _follow_node(n: Node3D, delta: float) -> void:
	_frame_on(n.global_position if n.is_inside_tree() else n.position, delta)


func _frame_on(feet: Vector3, delta: float) -> void:
	var h := FRAME_H_ESCALATED_M if _escalated else FRAME_H_M
	var target := feet + Vector3(0.0, h * 0.5 - 0.15, 0.0)
	if _snap:
		_pos = target
		_snap = false
	else:
		_pos = _pos.lerp(target, 1.0 - exp(-delta / FOLLOW_TAU))
	# distance so `h` metres fill the window height at 30° vertical FOV
	var d := h * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var eye := _pos + Vector3(0.0, d * 0.06, d)
	var xf := Transform3D(Basis.looking_at(_pos - eye, Vector3.UP), eye)
	if cam.is_inside_tree():
		cam.global_transform = xf
	else:
		cam.transform = xf


## A minimal HUD frame for sandboxes / probes (the real one is r3d-hud's PipFrame): the texture in a navy frame.
class SimpleFrame extends Control:
	var pip: PipView3D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func bind(p: PipView3D) -> void:
		pip = p
		p.shown_changed.connect(func(on: bool) -> void: visible = on)

	func _process(_d: float) -> void:
		if pip != null and visible:
			var r := pip.screen_rect()
			position = r.position
			size = r.size
			queue_redraw()

	func _draw() -> void:
		if pip == null:
			return
		var sz := Vector2(pip.size)
		draw_rect(Rect2(Vector2(-10, -10), sz + Vector2(20, 20)), Color("#1B2340"))
		draw_rect(Rect2(Vector2(-6, -6), sz + Vector2(12, 12)), Color("#FFF4E0"))
		draw_texture_rect(pip.get_texture(), Rect2(Vector2.ZERO, sz), false)
