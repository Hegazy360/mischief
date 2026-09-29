## PipView — the Bellows-Cam picture-in-picture (TECH §5.6, GDD §3.7, touchux.md §6.6).
##
## A SubViewport sharing the main `world_2d` (no duplicate nodes) with its own Camera2D
## (zoom 0.75) following Bellows. 448 × 252; `escalate(true)` grows it to the 704 × 396
## Gag-Cam window for off-screen payoffs. It renders at 30 Hz (UPDATE_ONCE every other frame)
## and only while shown; `canvas_cull_mask` drops visibility layer 2 (the FX / marker layer),
## so hotspot glows, bubbles and captions never clutter it. HUD CanvasLayers are not part of
## the world canvas, so they never appear in it either.
##
## Visibility (GDD §3.7): Bellows off-screen AND (within one room of Hush, heading to her
## room, or she is rigging) — or any escalated gag. `set_visible_if(cond)` shows at once and
## hides 2 s after the condition clears. The HUD's `PipFrame` (owner `ui`) shows
## `get_texture()`, draws the frame colour and handles the tap → `CameraDirector.peek`.
class_name PipView
extends SubViewport

signal shown_changed(on: bool)
signal pip_resized(new_size: Vector2i)

const SIZE := Vector2i(448, 252)
const SIZE_ESCALATED := Vector2i(704, 396)
const ZOOM := 0.75
const ZOOM_ESCALATED := 0.7
const HIDE_DELAY_S := 2.0
## Visibility layer 2 (bit value 2) = FX / markers, excluded from the PiP.
const FX_LAYER_BIT := 2
const FOLLOW_TAU := 0.15
## The camera frames his body centre: this far above his feet (world px).
const BODY_UP := 175.0
const FACE_UP := 290.0

var cam: Camera2D = null
## Bellows' view node (its global position = his feet).
var target: Node2D = null
## Render at 30 Hz (every other frame) while shown.
var half_rate: bool = true

var _want := false
var _shown := false
var _hide_t := 0.0
var _escalated := false
var _frame := 0
var _pos := Vector2.ZERO
var _snap := true
var _renders := 0
var _warm_frames := 0


func _init() -> void:
	name = "PipView"
	process_priority = -20
	size = SIZE
	disable_3d = true
	transparent_bg = false
	handle_input_locally = false
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	canvas_cull_mask = 0xFFFFF & ~FX_LAYER_BIT
	cam = Camera2D.new()
	cam.name = "PipCamera"
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = false
	add_child(cam)


func _ready() -> void:
	var host: Viewport = get_parent().get_viewport() if get_parent() != null else get_tree().root
	if host != null and host != self:
		world_2d = host.world_2d
	cam.make_current()


## Desired visibility this frame: shown at once when true, hidden 2 s after it goes false.
func set_visible_if(cond: bool) -> void:
	_want = cond
	if cond:
		_hide_t = 0.0
		_set_shown(true)


## Grow to the 704 × 396 Gag-Cam window (a payoff Hush can't watch) or back to 448 × 252.
func escalate(on: bool) -> void:
	if _escalated == on:
		return
	_escalated = on
	size = SIZE_ESCALATED if on else SIZE
	cam.zoom = Vector2.ONE * (ZOOM_ESCALATED if on else ZOOM)
	pip_resized.emit(size)
	if on:
		_set_shown(true)
	else:
		_hide_t = 0.0


## Hide at once (the main camera is holding a gag on him: no need to show him twice).
func hide_now() -> void:
	_want = false
	if not _escalated:
		_set_shown(false)


## Skip the hide delay (after a seek or a retry): apply the current wish at once.
func settle() -> void:
	_hide_t = 0.0
	if not _escalated:
		_set_shown(_want)


func is_escalated() -> bool:
	return _escalated


## One hidden render on request (NightScene warms it under the curtain so the first real show
## never hitches: the viewport texture, the rig atlases and the room pages are built now).
## The PiP stays hidden (`is_shown()` false); returns true when a render was scheduled.
func warm() -> bool:
	if target != null and is_instance_valid(target):
		_pos = target.global_position + Vector2(0, -BODY_UP)
		cam.position = _pos
	_warm_frames += 1
	render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


## Renders requested so far (shown frames at 30 Hz + warm-ups; tests / perf).
func renders() -> int:
	return _renders + _warm_frames


## True while the PiP is on screen (HudModel.pip_visible).
func is_shown() -> bool:
	return _shown


func _set_shown(on: bool) -> void:
	if _shown == on:
		return
	_shown = on
	if on:
		_snap = true
	render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED
	shown_changed.emit(on)


func _process(delta: float) -> void:
	advance(delta)


## Per-frame update (public for tests): hide delay (real time), follow, 30 Hz rendering.
func advance(delta: float) -> void:
	if _shown and not _want and not _escalated:
		_hide_t += delta
		if _hide_t >= HIDE_DELAY_S:
			_set_shown(false)
	if not _shown:
		return
	if target != null and is_instance_valid(target):
		var want := target.global_position + Vector2(0, -(FACE_UP if _escalated else BODY_UP))
		if _snap:
			_pos = want
			_snap = false
		else:
			_pos = _pos.lerp(want, ViewKit.damp(delta, FOLLOW_TAU))
		cam.position = _pos
	_frame += 1
	if not half_rate or _frame % 2 == 0:
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_renders += 1


## HUD bands (logical screen px) the main view loses to the HUD: the top row (meter, banner, the
## PiP itself) and the bottom clusters (tray, action button).
const HUD_TOP_PX := 280.0
const HUD_BOTTOM_PX := 220.0


## True while Bellows is plainly on the main screen (s2-fix G #19): at least half his body inside
## `view_rect` shrunk by `margins` (left, top, right, bottom, world px — the HUD bands at the current
## zoom). The PiP then hides at once instead of holding its 2 s, so he is never on screen twice.
static func on_screen(snap: ViewSnapshot, view_rect: Rect2, margins: Vector4 = Vector4.ZERO) -> bool:
	var b := snap.bellows
	if not b.present or view_rect.size.x <= 0.0:
		return false
	var body := Rect2(b.x - 90.0, b.y - 390.0, 180.0, 390.0)
	var inner := view_rect.grow_individual(-margins.x, -margins.y, -margins.z, -margins.w)
	var hit := inner.intersection(body)
	return hit.size.x * hit.size.y >= body.size.x * body.size.y * 0.5


## The GDD §3.7 rule. `view_rect` = the main camera's visible world rect; `layout` gives room
## distances; `heading_extra` = an entry warning for Hush's room is live.
static func rule(snap: ViewSnapshot, view_rect: Rect2, layout: HouseLayout, heading_extra: bool = false) -> bool:
	var b := snap.bellows
	var h := snap.hush
	if not b.present or not h.present:
		return false
	var body := Rect2(b.x - 90.0, b.y - 390.0, 180.0, 390.0)
	if view_rect.intersects(body):
		return false
	var dist := layout.room_distance(h.room, b.room) if layout != null else 99
	var near := dist >= 0 and dist <= 1
	var heading := heading_extra or snap.path_rooms.has(h.room)
	var rigging := h.state == "RIGGING"
	return near or heading or rigging
