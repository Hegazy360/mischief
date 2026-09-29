## CameraDirector — the Night camera (TECH §5.5, GDD §3.7, touchux.md §3.5 / §6.4).
##
## * **Framing:** at zoom 1.0 one floor (640 interior + 60 slab) fills the height with ≈ 190 px
##   of the floors above and below visible. The base zoom scales with the logical viewport
##   height (1080 on every landscape phone), so framing is identical on 16:9 … 21:9 and 4:3.
## * **Follow:** Hush with a 12 % (of the visible width) look-ahead toward her walk, which with
##   the follow lag puts her at 40–45 % of the width while she walks. Exponential smoothing
##   τ 0.20 s (0.15 s running) using a first-order-hold step, so 30 and 60 fps trace the same
##   path. Never Camera2D's built-in smoothing. Floor changes ease over 0.40 s; no walk bob.
## * **Limits** = the house bounds (rooms + flies + apron); the clamp is applied before shake.
## * **Hold offset** +200 px (mirrored left-handed) while the action button is held.
## * **Drag** pans 1:1; release flings (τ 0.25 s), holds 1.5 s, eases back over 0.5 s.
##   **Pinch** 0.5–1.25 anchored at the midpoint; **overview** toggles 1.0 ↔ 0.5.
## * **Peek:** fly 0.35 s, hold 1.8 s (extendable), fly back.
## * **Gag-Cam queue:** one gag at a time; a gag optionally approaches its focus at a gentle
##   zoom during the anticipation, then punches in (1.15 / 1.3 / 1.4 / 1.6 in 0.18 s, in REAL
##   time so it snaps together with the hit-stop freeze), holds, and eases back over 0.35 s.
##   If Hush is busy / in danger and the focus is off screen, the gag goes to the PiP
##   (`pip.escalate(true)`) instead of cutting away.
## * **Shake** (trauma: 12 px·t², 1.5°·t², ~25 Hz, decay 1.5/s) and spring **kicks** run in real
##   time; follow, floor eases, holds and zoom-outs run in view time (`SimDriver.view_delta`).
## * **reduce_motion:** no shake or kicks, punch-ins ≤ 1.15×, 0.25 s linear pans.
class_name CameraDirector
extends Camera2D

## A gag started (in_pip = it plays in the escalated PiP instead of the main camera).
signal gag_started(id: int, in_pip: bool)
signal gag_finished(id: int)

const FRAME_H := 1080.0
const FLOOR_CENTRE_UP := 290.0
const LEAD_FRAC := 0.12
const LEAD_TAU := 0.45
const TAU_WALK := 0.20
const TAU_RUN := 0.15
const FLOOR_EASE_S := 0.40
const HOLD_OFFSET_PX := 200.0
const HOLD_TAU := 0.12
const FLING_TAU := 0.25
const PAN_HOLD_S := 1.5
const PAN_RETURN_S := 0.5
const PAN_IDLE_S := 0.06
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.25
const OVERVIEW_ZOOM := 0.5
const OVERVIEW_EASE_S := 0.35
const PEEK_FLY_S := 0.35
const PEEK_HOLD_S := 1.8
const GAG_ZOOMS := {"small": 1.15, "big": 1.3, "m": 1.4, "finale": 1.6}
const GAG_OUT_DEFAULT_F := 21
const REDUCED_ZOOM_MAX := 1.15
const REDUCED_PAN_S := 0.25
const SHAKE_PX := 12.0
const SHAKE_DEG := 1.5
const SHAKE_HZ := 25.0
const SHAKE_DECAY := 1.5
const KICK_K := 500.0
const KICK_D := 22.0
const KICK_V_PER_PX := 40.6
## Focus framing: the gag focus sits this far above the screen centre (fraction of height),
## so a head focus leaves room for the caption below the HUD band.
const GAG_FOCUS_UP := 0.04

enum Pan { NONE, DRAG, FLING, HOLD, RETURN }
enum Peek { NONE, OUT, HOLD, BACK }
enum GagPhase { APPROACH, IN, HOLD, OUT }


class Gag:
	var id: int = 0
	var focus: Vector2 = Vector2.ZERO
	var zoom: float = 1.4
	var in_f: int = 11
	var hold_f: int = 90
	var out_f: int = 21
	var priority: int = 0
	var seq: int = 0
	var approach_f: int = 0
	var approach_zoom: float = 0.0
	var phase: int = GagPhase.IN
	var t: float = 0.0
	var in_pip: bool = false
	var released: bool = false
	var from_centre: Vector2 = Vector2.ZERO
	var from_zoom: float = 1.0
	var out_centre: Vector2 = Vector2.ZERO
	var out_zoom: float = 1.0


## World rect the camera may show (rooms + flies + apron).
var bounds: Rect2 = Rect2(0, -1530, 6200, 1780)
## Source of view-time deltas (a SimDriver: `view_delta()`); null = real time.
var time_source: Node = null
## PiP to escalate for off-screen gags (PipView: `escalate(on)`).
var pip: Node = null
## Returns true while Hush is busy (rigging) or in danger ("?" filling on her).
var hush_busy_fn: Callable = Callable()
var reduce_motion: bool = false
## +1 right-handed (action button bottom-right), −1 left-handed (mirrors the hold offset).
var hand: float = 1.0
## Tests: a fixed viewport size instead of the real one.
var view_size_override: Vector2 = Vector2.ZERO
## World x range of tonight's lit rooms: gag close-ups lean toward it (the victim stays within
## the middle 60 % of the frame), so a payoff by a doorway doesn't frame half an unlit set.
var stage_x_range: Vector2 = Vector2(-INF, INF)
## How far past the lit rooms the follow camera may show the unlit set (world px).
var stage_margin: float = 600.0

var _target: Node2D = null
var _lead_fn: Callable = Callable()
var _cx := 0.0
var _cy := 0.0
var _tx_old := 0.0
var _lead := 0.0
var _lead_dir := 1.0
var _floor := 0
var _floor_from := 0.0
var _floor_to := 0.0
var _floor_t := 1.0
var _hold_on := false
var _hold := 0.0
var _pan_mode: int = Pan.NONE
var _pan_off := Vector2.ZERO
var _pan_vel := Vector2.ZERO
var _pan_t := 0.0
var _pan_from := Vector2.ZERO
var _pan_accum := Vector2.ZERO
var _pan_idle := 0.0
var _uz := 1.0
var _uz_from := 1.0
var _uz_to := 1.0
var _uz_t := 1.0
var _peek_mode: int = Peek.NONE
var _peek_pos := Vector2.ZERO
var _peek_fn: Callable = Callable()
var _peek_t := 0.0
var _peek_hold := PEEK_HOLD_S
var _gag: Gag = null
var _queue: Array[Gag] = []
var _next_id := 1
var _seq := 0
var _trauma := 0.0
var _shake_t := 0.0
var _kick := Vector2.ZERO
var _kick_v := Vector2.ZERO
var _snap := true
var _centre := Vector2.ZERO
var _zoom := 1.0
var _has_frame := false


func _init() -> void:
	name = "CameraDirector"
	process_priority = -40
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	ignore_rotation = false
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER


func _ready() -> void:
	reduce_motion = bool(ViewKit.setting("reduce_motion", reduce_motion))
	if bool(ViewKit.setting("left_handed", false)):
		hand = -1.0
	var st := ViewKit.autoload("Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _on_setting)


func _on_setting(key: String, value: Variant) -> void:
	match key:
		"reduce_motion":
			reduce_motion = bool(value)
		"left_handed":
			hand = -1.0 if bool(value) else 1.0


## House bounds from a HouseLayout / house.json Dictionary / ContentDB / HouseDef (TECH §5.5).
func setup(house: Variant) -> void:
	var h := HouseLayout.from_any(house)
	bounds = h.bounds()
	_snap = true


## Follow `target` (Hush's view node). `lead_dir_fn()` returns her walk direction as a float
## (−1 / 0 / +1; 0 = standing) or a Vector2(dir, running ? 1 : 0).
func follow(target: Node2D, lead_dir_fn: Callable) -> void:
	_target = target
	_lead_fn = lead_dir_fn
	_snap = true


## +200 px (mirrored left-handed) while the action button is held (GDD §3.2).
func set_hold_offset(on: bool) -> void:
	_hold_on = on


## Drag pan: 1:1 with the finger (screen px). The fling velocity is measured per frame; a
## release is detected after 60 ms without a call (or end_pan()), then the view flings
## (τ 0.25 s), holds 1.5 s and eases back over 0.5 s.
func pan_by(screen_delta: Vector2) -> void:
	var z := maxf(0.001, _zoom)
	var wd := -screen_delta / z
	_pan_off += wd
	_pan_accum += wd
	_pan_idle = 0.0
	if _pan_mode != Pan.DRAG:
		_pan_vel = Vector2.ZERO
	_pan_mode = Pan.DRAG


## Explicit end of a drag (optional; release is also auto-detected).
func end_pan() -> void:
	if _pan_mode == Pan.DRAG:
		_pan_mode = Pan.FLING


## Pinch by `factor` anchored at the screen point `mid`; zoom stays within 0.5–1.25.
func pinch(factor: float, mid: Vector2) -> void:
	var vs := _view_size()
	var z_old := _zoom
	_uz = clampf(_uz * factor, ZOOM_MIN, ZOOM_MAX)
	_uz_to = _uz
	_uz_t = 1.0
	var z_new := base_zoom() * _uz
	var rel := mid - vs * 0.5
	var wp := _centre + rel / maxf(0.001, z_old)
	var c_new := wp - rel / maxf(0.001, z_new)
	_pan_off += c_new - _centre
	_pan_vel = Vector2.ZERO
	_pan_mode = Pan.HOLD
	_pan_t = 0.0


## Overview toggle 1.0 ↔ 0.5 (eased 0.35 s).
func toggle_overview() -> void:
	_uz_from = _uz
	_uz_to = 1.0 if _uz < 0.75 else OVERVIEW_ZOOM
	_uz_t = 0.0


func is_overview() -> bool:
	return _uz_to <= OVERVIEW_ZOOM + 0.01


## Peek: fly to `world_pos` in 0.35 s, hold `hold_s`, fly back. Calling it again during the
## hold refreshes the target and the hold (finger still down). `follow_fn()` (optional)
## returns a moving target each frame.
func peek(world_pos: Vector2, hold_s: float = PEEK_HOLD_S, follow_fn: Callable = Callable()) -> void:
	_peek_pos = world_pos
	_peek_fn = follow_fn
	_peek_hold = maxf(0.1, hold_s)
	if _peek_mode == Peek.HOLD:
		_peek_t = 0.0
		return
	if _peek_mode == Peek.OUT:
		return
	_peek_mode = Peek.OUT
	_peek_t = 0.0


func is_peeking() -> bool:
	return _peek_mode != Peek.NONE


## Queue a gag punch-in on `focus` (world). Frames at 60 fps. Returns its id. One gag at a
## time: a request waits behind the active gag unless that one is easing out / released.
## Optional `approach_f` / `approach_zoom` frame the focus gently during the anticipation
## before the punch.
func request_gag(focus: Vector2, zoom: float, in_f: int, hold_f: int, out_f: int, priority: int = 0,
		approach_f: int = 0, approach_zoom: float = 0.0) -> int:
	var g := Gag.new()
	g.id = _next_id
	_next_id += 1
	g.focus = focus
	g.zoom = minf(zoom, REDUCED_ZOOM_MAX) if reduce_motion else zoom
	g.in_f = maxi(1, in_f)
	g.hold_f = maxi(0, hold_f)
	g.out_f = maxi(1, out_f)
	g.priority = priority
	_seq += 1
	g.seq = _seq
	g.approach_f = maxi(0, approach_f)
	g.approach_zoom = approach_zoom
	if _gag == null or _gag.phase == GagPhase.OUT or _gag.released:
		if _gag != null:
			_finish_gag()
		_start_gag(g)
	else:
		_queue.append(g)
		_queue.sort_custom(func(a: Gag, b: Gag) -> bool:
			return a.priority > b.priority or (a.priority == b.priority and a.seq < b.seq))
	return g.id


## The accent landed: a gag still approaching its focus punches in now (in REAL time, so
## the zoom snaps together with the hit-stop freeze).
func punch_gag(id: int) -> void:
	if _gag != null and _gag.id == id and _gag.phase == GagPhase.APPROACH:
		_gag.phase = GagPhase.IN
		_gag.t = 0.0
		_gag.from_centre = _centre
		_gag.from_zoom = _zoom


## True while the active gag plays in the escalated PiP (the main camera stays on Hush).
func gag_in_pip() -> bool:
	return _gag != null and _gag.in_pip


## Current gag phase (tests / debug): -1 none, 0 approach, 1 in, 2 hold, 3 out.
func gag_phase() -> int:
	return _gag.phase if _gag != null else -1


## Move a gag's focus (the victim travels during his reaction).
func set_gag_focus(id: int, world_pos: Vector2) -> void:
	if _gag != null and _gag.id == id:
		_gag.focus = world_pos
		return
	for g in _queue:
		if g.id == id:
			g.focus = world_pos


## Start easing out a gag now (reaction ended early / knock-on). Queued gags are dropped.
func release_gag(id: int) -> void:
	if _gag != null and _gag.id == id:
		_gag.released = true
		if _gag.phase != GagPhase.OUT:
			_begin_out()
		return
	cancel_gag(id)


## Remove a queued gag (no effect on the active one).
func cancel_gag(id: int) -> void:
	for i in _queue.size():
		if _queue[i].id == id:
			_queue.remove_at(i)
			return


## Drop the active gag (un-escalating its PiP) and the queue at once — a seek or a retry.
## `keep_id` (non-zero) survives: the gag of a reaction that is still playing.
func clear_gags(keep_id: int = 0) -> void:
	for i in range(_queue.size() - 1, -1, -1):
		if _queue[i].id != keep_id or keep_id == 0:
			_queue.remove_at(i)
	if _gag != null and (keep_id == 0 or _gag.id != keep_id):
		_finish_gag()


func is_gag_active() -> bool:
	return _gag != null


## Id of the active gag (0 when none) and the number of queued gags (tests / debug).
func active_gag_id() -> int:
	return _gag.id if _gag != null else 0


func queued_gags() -> int:
	return _queue.size()


## Screen shake: add trauma (0..1).
func shake(trauma: float) -> void:
	if reduce_motion:
		return
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)


## Screen-space spring impulse along `dir` peaking at about `px` screen px.
func kick(dir: Vector2, px: float) -> void:
	if reduce_motion:
		return
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	_kick_v += d * px * KICK_V_PER_PX


## The world rect currently shown (without shake).
func visible_world_rect() -> Rect2:
	var vs := _view_size() / maxf(0.001, _zoom)
	return Rect2(_centre - vs * 0.5, vs)


## World → screen (logical px) for the current framing.
func world_to_screen(p: Vector2) -> Vector2:
	return (p - _centre) * _zoom + _view_size() * 0.5


## Screen → world for the current framing.
func screen_to_world(p: Vector2) -> Vector2:
	return _centre + (p - _view_size() * 0.5) / maxf(0.001, _zoom)


## Zoom at which one floor fills the height (1.0 on landscape phones).
func base_zoom() -> float:
	return _view_size().y / FRAME_H


## The current (smoothed, un-shaken) centre and zoom.
func centre() -> Vector2:
	return _centre


func current_zoom() -> float:
	return _zoom


## The follow position (before peeks / gags / pans) — tests.
func follow_centre() -> Vector2:
	return Vector2(_cx, _cy)


## Jump straight to the follow framing (scenario seeks, retries).
func snap_now() -> void:
	_snap = true


## Drop shake, kicks, manual pan and peeks (retry / scenario seek). Gags are kept.
func reset_motion() -> void:
	_trauma = 0.0
	_kick = Vector2.ZERO
	_kick_v = Vector2.ZERO
	_pan_mode = Pan.NONE
	_pan_off = Vector2.ZERO
	_pan_vel = Vector2.ZERO
	_peek_mode = Peek.NONE
	offset = Vector2.ZERO
	rotation = 0.0


func _process(delta: float) -> void:
	var vdt := delta
	if time_source != null and time_source.has_method("view_delta"):
		vdt = float(time_source.call("view_delta"))
	advance(vdt, delta)


## One camera update: `view_dt` (scaled by juice / ff) for follow and zooms, `real_dt` for
## shake, kicks, pans, peeks and the gag punch-in. Public for tests.
func advance(view_dt: float, real_dt: float) -> void:
	real_dt = minf(real_dt, 0.1)
	view_dt = minf(view_dt, 0.3)
	_update_zoom_ease(real_dt)
	_update_follow(view_dt)
	_update_pan(real_dt)
	var base_c := Vector2(_cx + _lead + _hold + _pan_off.x, _cy + _pan_off.y)
	var z := base_zoom() * _uz
	base_c.x = _stage_follow_clamp(base_c.x, _view_size().x / maxf(0.001, z))
	# Clamp the base framing and fold the clamp back into the pan offset (no wind-up).
	var clamped := _clamp_centre(base_c, z)
	if _pan_mode != Pan.NONE:
		_pan_off += clamped - base_c
	base_c = clamped
	var c := base_c
	# Peek.
	var pw := _update_peek(real_dt)
	if pw > 0.0:
		var pp: Variant = _peek_fn.call() if _peek_fn.is_valid() else _peek_pos
		if pp is Vector2:
			_peek_pos = pp
		c = c.lerp(_clamp_centre(_peek_pos, z), pw)
	# Gag.
	if _gag != null:
		var gz := _update_gag(view_dt, real_dt, c, z)
		c = gz[0]
		z = gz[1]
	c = _clamp_centre(c, z)
	_centre = c
	_zoom = z
	_has_frame = true
	_update_shake_kick(real_dt)
	position = c
	zoom = Vector2(z, z)


# --- follow -------------------------------------------------------------------------------

func _update_follow(dt: float) -> void:
	var tx := _cx
	var ty := 0.0
	var running := false
	var dir := 0.0
	if _target != null and is_instance_valid(_target):
		tx = _target.global_position.x
		ty = _target.global_position.y
	if _lead_fn.is_valid():
		var v: Variant = _lead_fn.call()
		if v is Vector2:
			dir = (v as Vector2).x
			running = (v as Vector2).y > 0.5
		elif v is float or v is int:
			dir = float(v)
	if absf(dir) > 0.1:
		_lead_dir = signf(dir)
	var vis_w := _view_size().x / maxf(0.001, base_zoom() * _uz)
	var lead_target := _lead_dir * LEAD_FRAC * vis_w
	var hold_target := hand * HOLD_OFFSET_PX if _hold_on else 0.0
	var fl := roundi(-ty / 700.0)
	if _snap:
		_cx = tx
		_tx_old = tx
		_lead = lead_target
		_hold = hold_target
		_floor = fl
		_cy = CameraDirector.floor_centre_y(fl)
		_floor_t = 1.0
		_snap = false
		return
	_lead = lerpf(_lead, lead_target, ViewKit.damp(dt, LEAD_TAU))
	_hold = lerpf(_hold, hold_target, ViewKit.damp(dt, HOLD_TAU))
	_cx = ViewKit.follow_exp(_cx, _tx_old, tx, dt, TAU_RUN if running else TAU_WALK)
	_tx_old = tx
	if fl != _floor:
		_floor = fl
		_floor_from = _cy
		_floor_to = CameraDirector.floor_centre_y(fl)
		_floor_t = 0.0
	if _floor_t < 1.0:
		var dur := REDUCED_PAN_S if reduce_motion else FLOOR_EASE_S
		_floor_t = minf(1.0, _floor_t + dt / dur)
		var e := _floor_t if reduce_motion else ViewKit.ease_in_out(_floor_t)
		_cy = lerpf(_floor_from, _floor_to, e)
	else:
		_cy = CameraDirector.floor_centre_y(_floor)


## Camera centre y that frames floor `fl` (its interior + slab centred).
static func floor_centre_y(fl: int) -> float:
	return -700.0 * float(fl) - FLOOR_CENTRE_UP


func _update_zoom_ease(dt: float) -> void:
	if _uz_t >= 1.0:
		return
	var dur := REDUCED_PAN_S if reduce_motion else OVERVIEW_EASE_S
	_uz_t = minf(1.0, _uz_t + dt / dur)
	var e := _uz_t if reduce_motion else ViewKit.ease_in_out(_uz_t)
	_uz = exp(lerpf(log(_uz_from), log(_uz_to), e))


# --- pan ----------------------------------------------------------------------------------

func _update_pan(dt: float) -> void:
	match _pan_mode:
		Pan.DRAG:
			if dt > 0.0:
				_pan_vel = _pan_vel.lerp(_pan_accum / dt, 0.5)
			_pan_accum = Vector2.ZERO
			_pan_idle += dt
			if _pan_idle > PAN_IDLE_S:
				_pan_mode = Pan.FLING
		Pan.FLING:
			_pan_off += _pan_vel * dt
			_pan_vel *= exp(-dt / FLING_TAU)
			if _pan_vel.length() < 20.0:
				_pan_vel = Vector2.ZERO
				_pan_mode = Pan.HOLD
				_pan_t = 0.0
		Pan.HOLD:
			_pan_t += dt
			if _pan_t >= PAN_HOLD_S:
				_pan_mode = Pan.RETURN
				_pan_t = 0.0
				_pan_from = _pan_off
		Pan.RETURN:
			_pan_t += dt
			var u := clampf(_pan_t / PAN_RETURN_S, 0.0, 1.0)
			_pan_off = _pan_from * (1.0 - (u if reduce_motion else ViewKit.ease_in_out(u)))
			if u >= 1.0:
				_pan_off = Vector2.ZERO
				_pan_mode = Pan.NONE


## Current manual pan state (tests): 0 none, 1 drag, 2 fling, 3 hold, 4 return.
func pan_mode() -> int:
	return _pan_mode


# --- peek ---------------------------------------------------------------------------------

func _update_peek(dt: float) -> float:
	var fly := REDUCED_PAN_S if reduce_motion else PEEK_FLY_S
	match _peek_mode:
		Peek.OUT:
			_peek_t += dt
			var u := clampf(_peek_t / fly, 0.0, 1.0)
			if u >= 1.0:
				_peek_mode = Peek.HOLD
				_peek_t = 0.0
			return u if reduce_motion else ViewKit.ease_in_out(u)
		Peek.HOLD:
			_peek_t += dt
			if _peek_t >= _peek_hold:
				_peek_mode = Peek.BACK
				_peek_t = 0.0
			return 1.0
		Peek.BACK:
			_peek_t += dt
			var u2 := clampf(_peek_t / fly, 0.0, 1.0)
			if u2 >= 1.0:
				_peek_mode = Peek.NONE
				return 0.0
			return 1.0 - (u2 if reduce_motion else ViewKit.ease_in_out(u2))
	return 0.0


# --- gags ---------------------------------------------------------------------------------

func _start_gag(g: Gag) -> void:
	_gag = g
	g.from_centre = _centre if _has_frame else g.focus
	g.from_zoom = _zoom if _has_frame else base_zoom() * _uz
	g.t = 0.0
	g.phase = GagPhase.APPROACH if g.approach_f > 0 else GagPhase.IN
	g.in_pip = false
	if hush_busy_fn.is_valid() and bool(hush_busy_fn.call()) and not _focus_on_screen(g.focus):
		g.in_pip = true
		if pip != null and pip.has_method("escalate"):
			pip.call("escalate", true)
	gag_started.emit(g.id, g.in_pip)


func _focus_on_screen(p: Vector2) -> bool:
	var r := visible_world_rect().grow(-60.0 / maxf(0.001, _zoom))
	return r.has_point(p) and r.has_point(p + Vector2(0, -260))


func _begin_out() -> void:
	if _gag == null:
		return
	_gag.phase = GagPhase.OUT
	_gag.t = 0.0
	_gag.out_centre = _centre
	_gag.out_zoom = _zoom


func _finish_gag() -> void:
	if _gag == null:
		return
	var g := _gag
	_gag = null
	if g.in_pip and pip != null and pip.has_method("escalate"):
		pip.call("escalate", false)
	gag_finished.emit(g.id)


## Gag framing for this frame given the base framing (c, z). Returns [centre, zoom].
func _update_gag(vdt: float, rdt: float, c: Vector2, z: float) -> Array:
	var g := _gag
	var vs := _view_size()
	var gz := g.zoom * base_zoom()
	var focus_c := _stage_bias(g.focus + Vector2(0, vs.y * GAG_FOCUS_UP / maxf(0.001, gz)), g.focus.x, vs.x / maxf(0.001, gz))
	var out_c := c
	var out_z := z
	match g.phase:
		GagPhase.APPROACH:
			g.t += vdt * 60.0
			var az := g.approach_zoom * base_zoom() if g.approach_zoom > 0.0 else z
			var ramp := minf(float(g.approach_f), 24.0)
			var u := clampf(g.t / maxf(1.0, ramp), 0.0, 1.0)
			var e := ViewKit.ease_in_out(u)
			var ac := g.focus + Vector2(0, vs.y * GAG_FOCUS_UP / maxf(0.001, az))
			out_c = g.from_centre.lerp(ac, e)
			out_z = exp(lerpf(log(g.from_zoom), log(az), e))
			if g.t >= float(g.approach_f):
				g.phase = GagPhase.IN
				g.t = 0.0
				g.from_centre = out_c
				g.from_zoom = out_z
		GagPhase.IN:
			g.t += rdt * 60.0
			var u2 := clampf(g.t / float(g.in_f), 0.0, 1.0)
			var e2 := u2 if reduce_motion else ViewKit.ease_out_cubic(u2)
			out_c = g.from_centre.lerp(focus_c, e2)
			out_z = exp(lerpf(log(g.from_zoom), log(gz), e2))
			if u2 >= 1.0:
				g.phase = GagPhase.HOLD
				g.t = 0.0
		GagPhase.HOLD:
			g.t += vdt * 60.0
			out_c = focus_c
			out_z = gz
			if g.t >= float(g.hold_f):
				_begin_out()
				g.out_centre = focus_c
				g.out_zoom = gz
		GagPhase.OUT:
			g.t += vdt * 60.0
			var u3 := clampf(g.t / float(g.out_f), 0.0, 1.0)
			var e3 := u3 if reduce_motion else ViewKit.ease_in_out(u3)
			out_c = g.out_centre.lerp(c, e3)
			out_z = exp(lerpf(log(g.out_zoom), log(z), e3))
			if u3 >= 1.0:
				_finish_gag()
				if not _queue.is_empty():
					var nxt: Gag = _queue.pop_front()
					_centre = out_c
					_zoom = out_z
					_start_gag(nxt)
	if g.in_pip:
		return [c, z]
	return [out_c, out_z]


## Keep the follow view within the lit rooms ± `stage_margin` when the view is narrower.
func _stage_follow_clamp(x: float, vw: float) -> float:
	if stage_x_range.x == -INF or stage_x_range.y == INF:
		return x
	var lo := stage_x_range.x - stage_margin + vw * 0.5
	var hi := stage_x_range.y + stage_margin - vw * 0.5
	if lo > hi:
		return (stage_x_range.x + stage_x_range.y) * 0.5
	return clampf(x, lo, hi)


## Lean a gag centre toward the lit stage (see `stage_x_range`), keeping the focus x within
## the middle 30 % of a view `vw` world px wide (room for his caption on both sides).
func _stage_bias(c: Vector2, focus_x: float, vw: float) -> Vector2:
	if stage_x_range.x == -INF or stage_x_range.y == INF:
		return c
	var lo := stage_x_range.x - 120.0 + vw * 0.5
	var hi := stage_x_range.y + 120.0 - vw * 0.5
	var want := c.x
	if lo <= hi:
		want = clampf(c.x, lo, hi)
	want = clampf(want, focus_x - vw * 0.15, focus_x + vw * 0.15)
	return Vector2(want, c.y)


## Pure: the centre clamped so a view of `vs` world px stays inside `r` (centred on an axis
## where the view is larger than the bounds).
static func clamp_to_bounds(c: Vector2, vs: Vector2, r: Rect2) -> Vector2:
	var out := c
	if vs.x >= r.size.x:
		out.x = r.get_center().x
	else:
		out.x = clampf(c.x, r.position.x + vs.x * 0.5, r.end.x - vs.x * 0.5)
	if vs.y >= r.size.y:
		out.y = r.get_center().y
	else:
		out.y = clampf(c.y, r.position.y + vs.y * 0.5, r.end.y - vs.y * 0.5)
	return out


func _clamp_centre(c: Vector2, z: float) -> Vector2:
	return CameraDirector.clamp_to_bounds(c, _view_size() / maxf(0.001, z), bounds)


# --- shake / kick -------------------------------------------------------------------------

func _update_shake_kick(dt: float) -> void:
	var steps := clampi(int(ceil(dt / (1.0 / 240.0))), 1, 24)
	var h := dt / float(steps)
	for i in steps:
		var acc := -KICK_K * _kick - KICK_D * _kick_v
		_kick_v += acc * h
		_kick += _kick_v * h
	if _kick.length_squared() < 0.01 and _kick_v.length_squared() < 0.25:
		_kick = Vector2.ZERO
		_kick_v = Vector2.ZERO
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * dt)
	_shake_t += dt
	var t2 := _trauma * _trauma
	var w := TAU * SHAKE_HZ
	var n1 := sin(_shake_t * w) * 0.62 + sin(_shake_t * w * 0.69 + 1.3) * 0.38
	var n2 := cos(_shake_t * w * 0.93 + 0.4) * 0.6 + sin(_shake_t * w * 0.57 + 2.1) * 0.4
	var n3 := sin(_shake_t * w * 0.81 + 0.7)
	var sh := Vector2(n1, n2) * SHAKE_PX * t2
	offset = (sh - _kick) / maxf(0.001, _zoom)
	rotation = deg_to_rad(SHAKE_DEG * t2 * n3)


## Current trauma (tests / debug).
func trauma() -> float:
	return _trauma


## Logical viewport size the camera frames (2400 × 1080 on a 20:9 phone).
func view_size() -> Vector2:
	return _view_size()


func _view_size() -> Vector2:
	if view_size_override != Vector2.ZERO:
		return view_size_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(2400, 1080)
