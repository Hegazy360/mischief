## CameraDirector3D — the Night camera on a Camera3D (REDESIGN §5.2, R3D index §7.7; the 2D CameraDirector's
## public API with sim-px arguments at the lane).
##
## **Base framing (binding numbers):** vertical FOV 30°, KEEP_HEIGHT, the camera 7.5 m in front of the lane (z +6.5)
## at y 1.9 m aimed at y 1.35 m on the lane (pitch −4.2°), near 0.5, far 60 → 1 m ≈ 269 px at the lane and 226 px at
## the back wall (1080 logical px); visible lane width 8.93 / 7.15 / 5.36 m at 20:9 / 16:9 / 4:3.
## The camera is described by an **aim point** on the framed floor's lane (x, floor y + 1.35, z −1.0), a horizontal
## **distance** D (7.5 m at base) along the fixed −4.2° pitch, and a **yaw** about the vertical through the aim point;
## dollies (punch-ins, two-shot, Overview) change D along the view axis, never the pitch.
##
## * **C1 room framing:** Hush's room fits (width + 0.6 ≤ V) → the camera x stays in [x1 − V/2 + 0.3, x0 + V/2 − 0.3]
##   (the whole room in view), biased toward her walk by the 12 % look-ahead but kept near the room centre so each
##   neighbour strip stays ≤ 1.7 m at 20:9 / 0.8 m at 16:9 where the room width allows; a wider room is followed with
##   the look-ahead (she sits at 40–45 %) and clamped to the room ± 0.3 m. Exponential smoothing τ 0.20 s (0.15 s
##   running); a doorway crossing eases to the new room's framing over 0.45 s (never a cut).
## * **C2 edge clamp:** at most 0.3 m of unbuilt space past the Night's outermost built walls (wins over C1).
## * **C3 two-shot:** Bellows in her room (or a linked room within 3 m of the shared doorway) → pull back to ≤ 1.15×
##   (8.63 m) and shift to hold both, Hush ≥ 20 % from either edge.
## * **C4 hold offset:** while the action button is held, Hush stays at 40–55 % of the width (mirrored left-handed).
## * **C5 floors:** a floor change cranes 3.5 m over 0.40 s.
## * **C6 safe rect:** Hush and every keep-visible box (the live props of her room) inside the safe rect (shift within
##   C1/C2; Hush wins when all cannot fit).
## * **C7 punch-ins:** a dolly toward his head/chest to D = 7.5 / zoom (S 1.15 = 6.52 m, L 1.3 = 5.77, M 1.4 = 5.36,
##   SIG 1.6 = 4.69; never closer than 4.5 m), 0.18 s in (REAL time, so it lands with the hit-stop), hold, 0.35 s out,
##   + the caller's yaw (3–6° toward his face side, 8° for MIRROR, MIRROR); an approach "push" (the clip's `cam push`,
##   e.g. 1.15 through the sneeze build) before the punch; one punchline at a time (a queue); off-screen payoffs while
##   Hush is busy go to the Bellows window (`pip.escalate(true)`).
## * **Overview / Map:** a dolly back to 15 m (0.5×). **Peek:** fly 0.35 s, hold 1.8 s, return. **Shake / kick** in
##   real time (h/v offset + roll). **Reduce motion:** no shake, no yaw, punch ≤ 1.15×, 0.25 s linear moves.
## Projection helpers work headless (they use the camera transform + the logical size, not the renderer).
class_name CameraDirector3D
extends Camera3D

signal gag_started(id: int, in_pip: bool)
signal gag_finished(id: int)

const BASE_DIST := 7.5
const PITCH_TAN := (View3DConst.CAM_Y - View3DConst.CAM_AIM_Y) / (View3DConst.CAM_Z - View3DConst.LANE_Z)
const LEAD_FRAC := 0.12
const LEAD_TAU := 0.45
const TAU_WALK := 0.20
const TAU_RUN := 0.15
const DOOR_EASE_S := 0.45
const FLOOR_EASE_S := View3DConst.CRANE_S
const HOLD_TAU := 0.12
const TWO_SHOT_DOOR_M := 3.0
const TWO_SHOT_EDGE := 0.20
const BELLOWS_HALF_W := 0.5
const DIST_TAU := 0.30
const FLING_TAU := 0.25
const PAN_HOLD_S := 1.5
const PAN_RETURN_S := 0.5
const PAN_IDLE_S := 0.06
const PINCH_MIN_DIST := 6.0
const PINCH_MAX_DIST := View3DConst.OVERVIEW_DIST_M
const OVERVIEW_EASE_S := 0.35
const PEEK_FLY_S := 0.35
const PEEK_HOLD_S := 1.8
const REDUCED_ZOOM_MAX := 1.15
const REDUCED_PAN_S := 0.25
const GAG_OUT_DEFAULT_F := 21
const SHAKE_PX := 12.0
const SHAKE_DEG := 1.5
const SHAKE_HZ := 25.0
const SHAKE_DECAY := 1.5
const KICK_K := 500.0
const KICK_D := 22.0
const KICK_V_PER_PX := 40.6
const GAG_FOCUS_MID := 0.18          ## the focus stays within the middle 36 % of a punch-in frame (C2 yields)
## A punch-in never shows more than this much below the floor at the lane (the aim rises instead of framing the pit).
const GAG_BELOW_FLOOR_M := 0.35
const APPROACH_HOLD_MAX_F := 600     ## a push waits this long past its frames for punch_gag, then punches anyway

enum Pan { NONE, DRAG, FLING, HOLD, RETURN }
enum Peek { NONE, OUT, HOLD, BACK }
enum GagPhase { APPROACH, IN, HOLD, OUT }


## One room of the house in metres.
class Room3:
	var id: String = ""
	var floor: int = 0
	var x0: float = 0.0
	var x1: float = 0.0


class Gag:
	var id: int = 0
	var focus: Variant = Vector3.ZERO
	var zoom: float = 1.4
	var in_f: int = 11
	var hold_f: int = 90
	var out_f: int = 21
	var priority: int = 0
	var seq: int = 0
	var yaw_deg: float = 0.0
	var approach_f: int = 0
	var approach_zoom: float = 0.0
	var phase: int = GagPhase.IN
	var t: float = 0.0
	var in_pip: bool = false
	var released: bool = false
	var from_aim: Vector3 = Vector3.ZERO
	var from_dist: float = BASE_DIST
	var from_yaw: float = 0.0
	var out_aim: Vector3 = Vector3.ZERO
	var out_dist: float = BASE_DIST
	var out_yaw: float = 0.0
	## A seek kept this gag: its start frame is re-based on the next advance (the old one is stale).
	var rebase: bool = false


## Source of view-time deltas (a SimDriver: `view_delta()`); null = real time.
var time_source: Node = null
## The Bellows window to escalate for off-screen gags (`escalate(on)`).
var pip: Node = null
## Returns true while Hush is busy (rigging) or in danger ("?" filling on her).
var hush_busy_fn: Callable = Callable()
var reduce_motion: bool = false
## +1 right-handed (the action button bottom-right), −1 left-handed.
var hand: float = 1.0
## Tests: a fixed logical size instead of the viewport's visible rect.
var logical_size_override: Vector2 = Vector2.ZERO
## Apply C1's neighbour-strip bias (tests may turn it off to check the raw clamp).
var neighbour_bias: bool = true

var _rooms: Array[Room3] = []
var _built: Dictionary = {}          # room id → true
var _links: Array = []               # [{a, b, x_m}]
var _edges: Dictionary = {}          # floor → Vector2(x0, x1) of the outermost built walls
var _target: Node3D = null
var _lead_fn: Callable = Callable()
var _other: Node3D = null
var _safe := Rect2()
var _keep_fn: Callable = Callable()
var _cx := 0.0
var _lead := 0.0
var _lead_dir := 1.0
var _room_id := ""
var _door_t := 1.0
var _door_from := 0.0
var _floor := 0
var _aim_y := View3DConst.CAM_AIM_Y
var _floor_from := 0.0
var _floor_to := 0.0
var _floor_t := 1.0
var _hold_on := false
var _dist := BASE_DIST
var _user_dist := BASE_DIST
var _ud_from := BASE_DIST
var _ud_to := BASE_DIST
var _ud_t := 1.0
var _pan_mode: int = Pan.NONE
var _pan_off := 0.0
var _pan_vel := 0.0
var _pan_t := 0.0
var _pan_from := 0.0
var _pan_accum := 0.0
var _pan_idle := 0.0
var _peek_mode: int = Peek.NONE
var _peek_x := 0.0
var _peek_floor := 0
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
var _aim := Vector3(0.0, View3DConst.CAM_AIM_Y, View3DConst.LANE_Z)
var _yaw := 0.0
var _two_shot := false
var _has_frame := false
var _frame_dist := BASE_DIST
var _ts_extra := 0.0


func _init() -> void:
	name = "CameraDirector3D"
	process_priority = -40
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = View3DConst.CAM_FOV_DEG
	near = View3DConst.CAM_NEAR
	far = View3DConst.CAM_FAR
	cull_mask = View3DConst.MASK_MAIN
	_apply_transform()


func _ready() -> void:
	reduce_motion = bool(_setting("reduce_motion", reduce_motion))
	if bool(_setting("left_handed", false)):
		hand = -1.0
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _on_setting)


func _on_setting(key: String, value: Variant) -> void:
	match key:
		"reduce_motion":
			reduce_motion = bool(value)
		"left_handed":
			hand = -1.0 if bool(value) else 1.0


# --- setup --------------------------------------------------------------------------------

## The house (house.json Dictionary, ContentDB, HouseDef or an Array of room dicts) and tonight's set
## (SetList.Result / a Dictionary with rooms_lit + rooms_backstage / an Array of built room ids / null = every room).
func setup(house: Variant, set_list: Variant = null) -> void:
	_rooms = CameraDirector3D.rooms_from(house)
	_links = CameraDirector3D.links_from(house)
	_built.clear()
	var ids := CameraDirector3D.built_ids(set_list)
	for r in _rooms:
		if ids.is_empty() or ids.has(r.id):
			_built[r.id] = true
	_edges.clear()
	for r in _rooms:
		if not _built.has(r.id):
			continue
		var e: Vector2 = _edges.get(r.floor, Vector2(INF, -INF))
		_edges[r.floor] = Vector2(minf(e.x, r.x0), maxf(e.y, r.x1))
	_snap = true


## Follow `target` (Hush's view node, world metres). `lead_dir_fn()` → −1/0/+1 or Vector2(dir, running ? 1 : 0).
func follow(target: Node3D, lead_dir_fn: Callable) -> void:
	_target = target
	_lead_fn = lead_dir_fn
	_snap = true


## Bellows' view node, for the C3 two-shot (null = none).
func set_other(target: Node3D) -> void:
	_other = target


## C4: Hush at 40–55 % of the width while the action button is held.
func set_hold_offset(on: bool) -> void:
	_hold_on = on


## C6: the safe rect in logical screen px (the HUD's safe area).
func set_safe_rect(r: Rect2) -> void:
	_safe = r


## C6: `rects_fn()` returns the world AABBs that must stay inside the safe rect (the live props of Hush's room).
func set_keep_visible(rects_fn: Callable) -> void:
	_keep_fn = rects_fn


# --- pan, pinch, overview, peek ----------------------------------------------------------

## Drag pan 1:1 with the finger (logical px, horizontal); release flings (τ 0.25 s), holds 1.5 s, eases back 0.5 s.
func pan_by(screen_delta: Vector2) -> void:
	var dm := -screen_delta.x / maxf(1.0, px_per_m_at(View3DConst.LANE_Z))
	_pan_off += dm
	_pan_accum += dm
	_pan_idle = 0.0
	if _pan_mode != Pan.DRAG:
		_pan_vel = 0.0
	_pan_mode = Pan.DRAG


func end_pan() -> void:
	if _pan_mode == Pan.DRAG:
		_pan_mode = Pan.FLING


## Pinch by `factor` (> 1 = in) anchored at the screen point `mid`; the distance stays within 6.0–15 m.
func pinch(factor: float, mid: Vector2) -> void:
	var before := screen_to_world(mid)
	_user_dist = clampf(_user_dist / maxf(0.01, factor), PINCH_MIN_DIST, PINCH_MAX_DIST)
	_ud_to = _user_dist
	_ud_t = 1.0
	_dist = _user_dist
	_apply_transform()
	var after := screen_to_world(mid)
	_pan_off += (before.x - after.x) / View3DConst.PX_PER_M
	_pan_vel = 0.0
	_pan_mode = Pan.HOLD
	_pan_t = 0.0


## The Map: dolly back to 15 m (0.5×) and back (eased 0.35 s).
func toggle_overview() -> void:
	_ud_from = _user_dist
	_ud_to = BASE_DIST if _user_dist > (BASE_DIST + View3DConst.OVERVIEW_DIST_M) * 0.5 else View3DConst.OVERVIEW_DIST_M
	_ud_t = 0.0


func is_overview() -> bool:
	return _ud_to >= View3DConst.OVERVIEW_DIST_M - 0.01


## Peek at a sim-px world point: fly 0.35 s, hold `hold_s`, fly back. Calling it during the hold refreshes it.
## `follow_fn()` (optional) returns a moving target each frame (Vector2 sim px or Vector3 world).
func peek(world_pos: Vector2, hold_s: float = PEEK_HOLD_S, follow_fn: Callable = Callable()) -> void:
	_set_peek_target(world_pos)
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


# --- gags (C7) ----------------------------------------------------------------------------

## Queue a punch-in on `focus` (Vector3 world, a Node3D tracked each frame, or Vector2 sim px on the lane): a dolly
## to D = 7.5 / zoom (≥ 4.5 m) in `in_f` real frames, hold `hold_f`, out `out_f` view frames, + `yaw_deg`.
## `approach_f` / `approach_zoom`: a slow push toward the focus first (the clip's `cam push`), until `punch_gag`.
func request_gag(focus: Variant, zoom: float, in_f: int, hold_f: int, out_f: int, priority: int = 0,
		yaw_deg: float = 0.0, approach_f: int = 0, approach_zoom: float = 0.0) -> int:
	var g := Gag.new()
	g.id = _next_id
	_next_id += 1
	g.focus = focus
	g.zoom = minf(zoom, REDUCED_ZOOM_MAX) if reduce_motion else zoom
	g.in_f = maxi(1, in_f)
	g.hold_f = maxi(0, hold_f)
	g.out_f = maxi(1, out_f)
	g.priority = priority
	g.yaw_deg = 0.0 if reduce_motion else yaw_deg
	_seq += 1
	g.seq = _seq
	g.approach_f = maxi(0, approach_f)
	g.approach_zoom = minf(approach_zoom, REDUCED_ZOOM_MAX) if reduce_motion else approach_zoom
	if _gag == null or _gag.phase == GagPhase.OUT or _gag.released:
		if _gag != null:
			_finish_gag()
		_start_gag(g)
	else:
		_queue.append(g)
		_queue.sort_custom(func(a: Gag, b: Gag) -> bool:
			return a.priority > b.priority or (a.priority == b.priority and a.seq < b.seq))
	return g.id


## The accent landed: a gag still pushing in punches now (real time, with the hit-stop).
func punch_gag(id: int) -> void:
	if _gag != null and _gag.id == id and _gag.phase == GagPhase.APPROACH:
		_gag.phase = GagPhase.IN
		_gag.t = 0.0
		_gag.from_aim = _aim
		_gag.from_dist = _dist
		_gag.from_yaw = _yaw


## Move a gag's focus (the victim travels during his reaction).
func set_gag_focus(id: int, p: Variant) -> void:
	if _gag != null and _gag.id == id:
		_gag.focus = p
		return
	for g in _queue:
		if g.id == id:
			g.focus = p


## Start easing a gag out now; a queued one is dropped.
func release_gag(id: int) -> void:
	if _gag != null and _gag.id == id:
		_gag.released = true
		if _gag.phase != GagPhase.OUT:
			_begin_out()
		return
	cancel_gag(id)


func cancel_gag(id: int) -> void:
	for i in _queue.size():
		if _queue[i].id == id:
			_queue.remove_at(i)
			return


## Drop the active gag and the queue (seek, retry); `keep_id` survives.
func clear_gags(keep_id: int = 0) -> void:
	for i in range(_queue.size() - 1, -1, -1):
		if keep_id == 0 or _queue[i].id != keep_id:
			_queue.remove_at(i)
	if _gag != null and (keep_id == 0 or _gag.id != keep_id):
		_finish_gag()
	elif _gag != null:
		_gag.rebase = true


func is_gag_active() -> bool:
	return _gag != null


func active_gag_id() -> int:
	return _gag.id if _gag != null else 0


func queued_gags() -> int:
	return _queue.size()


## True while the active gag plays in the escalated Bellows window.
func gag_in_pip() -> bool:
	return _gag != null and _gag.in_pip


## -1 none, 0 approach, 1 in, 2 hold, 3 out.
func gag_phase() -> int:
	return _gag.phase if _gag != null else -1


# --- shake / kick -------------------------------------------------------------------------

func shake(trauma_add: float) -> void:
	if reduce_motion:
		return
	_trauma = clampf(_trauma + trauma_add, 0.0, 1.0)


## A screen-space spring impulse along `dir` peaking at about `px` logical px.
func kick(dir: Vector2, px: float) -> void:
	if reduce_motion:
		return
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	_kick_v += d * px * KICK_V_PER_PX


func trauma() -> float:
	return _trauma


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on


# --- projection (headless-safe) -----------------------------------------------------------

## Logical screen size (2400 × 1080 on a 20:9 phone).
func view_size() -> Vector2:
	if logical_size_override != Vector2.ZERO:
		return logical_size_override
	if is_inside_tree():
		var vs := get_viewport().get_visible_rect().size
		if vs.x > 1.0 and vs.y > 1.0:
			return vs
	return Vector2(View3DConst.LOGICAL_W_20X9, View3DConst.LOGICAL_H)


## The focal length in logical px (KEEP_HEIGHT: from the vertical FOV and the logical height).
func focal_px() -> float:
	return view_size().y * 0.5 / tan(deg_to_rad(fov) * 0.5)


## World → logical screen px (without shake). Points behind the camera return a far-off point.
func project(p: Vector3) -> Vector2:
	var xf := _frame_xform()
	var q := xf.affine_inverse() * p
	if q.z > -0.001:
		return Vector2(-100000.0, -100000.0)
	var f := focal_px()
	var vs := view_size()
	return Vector2(vs.x * 0.5 + f * q.x / -q.z, vs.y * 0.5 - f * q.y / -q.z)


## The screen bounding rect of an AABB's 8 projected corners (REDESIGN §5.5 hit rects).
func project_aabb(b: AABB) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var s := project(b.get_endpoint(i))
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2(lo, hi - lo)


## The world point on the plane z = `z` under a logical screen point (a ray hit).
func screen_to_plane(p: Vector2, z: float = View3DConst.LANE_Z) -> Vector3:
	var xf := _frame_xform()
	var f := focal_px()
	var vs := view_size()
	var dir_cam := Vector3((p.x - vs.x * 0.5) / f, -(p.y - vs.y * 0.5) / f, -1.0)
	var dir := (xf.basis * dir_cam).normalized()
	var o := xf.origin
	if absf(dir.z) < 1e-6:
		return o
	var t := (z - o.z) / dir.z
	return o + dir * t


## Sim px on the lane → logical screen px.
func world_to_screen(p: Vector2) -> Vector2:
	return project(View3DConst.px_to_world(p, View3DConst.LANE_Z))


## Logical screen px → sim px on the lane plane.
func screen_to_world(p: Vector2) -> Vector2:
	var w := screen_to_plane(p, View3DConst.LANE_Z)
	return Vector2(w.x * View3DConst.PX_PER_M, -w.y * View3DConst.PX_PER_M)


## The sim-px rect of the lane plane in view (without shake): x from the screen's middle row, y from its middle
## column (the frame's extents at the aim height).
func visible_world_rect() -> Rect2:
	var vs := view_size()
	var l := screen_to_world(Vector2(0.0, vs.y * 0.5))
	var r := screen_to_world(Vector2(vs.x, vs.y * 0.5))
	var t := screen_to_world(Vector2(vs.x * 0.5, 0.0))
	var b := screen_to_world(Vector2(vs.x * 0.5, vs.y))
	var x0 := minf(l.x, r.x)
	var y0 := minf(t.y, b.y)
	return Rect2(x0, y0, maxf(l.x, r.x) - x0, maxf(t.y, b.y) - y0)


## A lane point in world metres for a sim x (px) on a floor.
func lane_point(x_px: float, floor_i: int, z: float = View3DConst.LANE_Z) -> Vector3:
	return Vector3(x_px / View3DConst.PX_PER_M, View3DConst.floor_y(floor_i), z)


## Logical px per metre (horizontal) on the plane z at the aim point's height, for the current framing.
func px_per_m_at(z: float) -> float:
	var xf := _frame_xform()
	var p := Vector3(_aim.x, _aim.y, z)
	var depth := (xf.affine_inverse() * p).z
	return focal_px() / maxf(0.001, -depth)


## The visible width (m) on the plane z at the current framing.
func visible_width_at(z: float = View3DConst.LANE_Z) -> float:
	return view_size().x / maxf(0.001, px_per_m_at(z))


## The base-framing visible lane width for a distance D (pure; used by C1–C3).
func visible_width_for(dist: float) -> float:
	var depth := dist * sqrt(1.0 + PITCH_TAN * PITCH_TAN)
	return view_size().x * depth / focal_px()


# --- state accessors (tests / debug) --------------------------------------------------------

func aim() -> Vector3:
	return _aim


func distance() -> float:
	return _dist


func yaw_deg() -> float:
	return _yaw


## 7.5 / D (1.0 at base, 1.15 at the S punch-in, 0.5 in the Overview).
func current_zoom() -> float:
	return BASE_DIST / maxf(0.001, _dist)


func follow_x() -> float:
	return _cx


func framed_room() -> String:
	return _room_id


func floor_index() -> int:
	return _floor


func is_two_shot() -> bool:
	return _two_shot


func pan_mode() -> int:
	return _pan_mode


## Jump straight to the follow framing (seeks, retries).
func snap_now() -> void:
	_snap = true


## Drop shake, kicks, pan and peeks (retry / seek). Gags are kept.
func reset_motion() -> void:
	_trauma = 0.0
	_kick = Vector2.ZERO
	_kick_v = Vector2.ZERO
	_pan_mode = Pan.NONE
	_pan_off = 0.0
	_pan_vel = 0.0
	_peek_mode = Peek.NONE
	h_offset = 0.0
	v_offset = 0.0


# --- the frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var vdt := delta
	if time_source != null and time_source.has_method("view_delta"):
		vdt = float(time_source.call("view_delta"))
	advance(vdt, delta)


## One camera update: `view_dt` (juice / ff scaled) for follow, holds and outs; `real_dt` for shake, kicks, pans,
## peeks, the Overview ease and the punch-in. Public for tests.
func advance(view_dt: float, real_dt: float) -> void:
	real_dt = minf(real_dt, 0.1)
	view_dt = minf(view_dt, 0.3)
	_update_user_dist(real_dt)
	var hx := _cx
	var hy := 0.0
	var running := false
	var dir := 0.0
	if _target != null and is_instance_valid(_target):
		var tp := CameraDirector3D.node_pos(_target)
		hx = tp.x
		hy = tp.y
	if _lead_fn.is_valid():
		var v: Variant = _lead_fn.call()
		if v is Vector2:
			dir = (v as Vector2).x
			running = (v as Vector2).y > 0.5
		elif v is float or v is int:
			dir = float(v)
	if absf(dir) > 0.1:
		_lead_dir = signf(dir)
	var fl := View3DConst.floor_of_y(hy)
	_update_floor(fl, view_dt)
	# The distance: the user's (pinch / Overview, already eased), or the two-shot pull-back (smoothed τ 0.3 s).
	var other_x := NAN
	if _other != null and is_instance_valid(_other):
		other_x = CameraDirector3D.node_pos(_other).x
	var room := _room_at(hx, fl)
	var ts := _two_shot_dist(hx, other_x, room, fl)
	_two_shot = ts > _user_dist + 0.001 and not is_overview()
	var extra := ts - _user_dist if _two_shot else 0.0
	if _snap:
		_ts_extra = extra
	else:
		_ts_extra = lerpf(_ts_extra, extra, _damp(view_dt, DIST_TAU))
	_dist = _user_dist + _ts_extra
	var V := visible_width_for(_dist)
	# The follow x (C1, C3, C4, C6).
	var lead_target := _lead_dir * LEAD_FRAC * V
	if _snap:
		_lead = lead_target
	else:
		_lead = lerpf(_lead, lead_target, _damp(view_dt, LEAD_TAU))
	var want := _c1_target(hx, room, V)
	if _two_shot:
		want = _two_shot_x(hx, other_x, V)
	if _hold_on:
		var lo_f := 0.40 if hand > 0.0 else 0.45
		var hi_f := 0.55 if hand > 0.0 else 0.60
		want = clampf(want, hx + (0.5 - hi_f) * V, hx + (0.5 - lo_f) * V)
	want = _c6_clamp(want, hx, fl)
	want = _c2_clamp(want, fl, V)
	var room_id := room.id if room != null else ""
	if _snap:
		_cx = want
		_room_id = room_id
		_door_t = 1.0
		_snap = false
	else:
		if room_id != _room_id and room_id != "" and _room_id != "":
			_door_t = 0.0
			_door_from = _cx
		if room_id != "":
			_room_id = room_id
		if _door_t < 1.0:
			var dur := REDUCED_PAN_S if reduce_motion else DOOR_EASE_S
			_door_t = minf(1.0, _door_t + view_dt / dur)
			var e := _door_t if reduce_motion else _ease_in_out(_door_t)
			_cx = lerpf(_door_from, want, e)
		else:
			_cx = lerpf(_cx, want, _damp(view_dt, TAU_RUN if running else TAU_WALK))
	# Manual pan (within the C2 limits).
	_update_pan(real_dt)
	var base_x := _c2_clamp(_cx + _pan_off, fl, V)
	if _pan_mode != Pan.NONE:
		_pan_off = base_x - _cx
	var aim := Vector3(base_x, _aim_y, View3DConst.LANE_Z)
	var dist := _dist
	var yaw := 0.0
	# Peek.
	var pw := _update_peek(real_dt)
	if pw > 0.0:
		if _peek_fn.is_valid():
			var pp: Variant = _peek_fn.call()
			if pp is Vector2:
				_set_peek_target(pp)
			elif pp is Vector3:
				_peek_x = (pp as Vector3).x
				_peek_floor = View3DConst.floor_of_y((pp as Vector3).y)
		var peek_aim := Vector3(_c2_clamp(_peek_x, _peek_floor, V), View3DConst.floor_y(_peek_floor) + View3DConst.CAM_AIM_Y, View3DConst.LANE_Z)
		aim = aim.lerp(peek_aim, pw)
	# Gag.
	if _gag != null:
		var gr := _update_gag(view_dt, real_dt, aim, dist, yaw)
		aim = gr[0]
		dist = gr[1]
		yaw = gr[2]
	_aim = aim
	_yaw = yaw
	_frame_dist = dist
	_has_frame = true
	_apply_transform()
	_update_shake_kick(real_dt)


# --- C1–C6 --------------------------------------------------------------------------------

func _c1_target(hx: float, room: Room3, V: float) -> float:
	var want := hx + _lead
	if room == null:
		return want
	var w := room.x1 - room.x0
	var m := View3DConst.ROOM_FIT_MARGIN_M
	if w + 2.0 * m <= V:
		var lo := room.x1 - V * 0.5 + m
		var hi := room.x0 + V * 0.5 - m
		if neighbour_bias:
			var centre := (room.x0 + room.x1) * 0.5
			var dev := maxf(0.0, strip_limit(V) - (V - w) * 0.5)
			var lo2 := maxf(lo, centre - dev)
			var hi2 := minf(hi, centre + dev)
			if lo2 <= hi2:
				lo = lo2
				hi = hi2
			else:
				lo = centre
				hi = centre
		return clampf(want, lo, hi)
	return clampf(want, room.x0 + V * 0.5 - m, room.x1 - V * 0.5 + m)


## The neighbour-strip limit (m) for a visible width: 1.7 m at 20:9 (8.93 m), 0.8 m at 16:9 (7.15 m), linear between.
func strip_limit(V: float) -> float:
	var v20: float = View3DConst.VISIBLE_W["20x9"]
	var v16: float = View3DConst.VISIBLE_W["16x9"]
	var s20: float = View3DConst.NEIGHBOUR_STRIP_M["20x9"]
	var s16: float = View3DConst.NEIGHBOUR_STRIP_M["16x9"]
	var u := (V - v16) / (v20 - v16)
	return maxf(0.0, lerpf(s16, s20, u))


func _c2_clamp(x: float, fl: int, V: float) -> float:
	if not _edges.has(fl):
		return x
	var e: Vector2 = _edges[fl]
	var lo := e.x - View3DConst.EDGE_CLAMP_M + V * 0.5
	var hi := e.y + View3DConst.EDGE_CLAMP_M - V * 0.5
	if lo > hi:
		return (e.x + e.y) * 0.5
	return clampf(x, lo, hi)


## C3: the distance a two-shot needs (0 = no two-shot).
func _two_shot_dist(hx: float, bx: float, room: Room3, fl: int) -> float:
	if is_nan(bx) or room == null:
		return 0.0
	var broom := _room_at(bx, fl)
	if broom == null:
		return 0.0
	if broom.id != room.id:
		var door := _door_between(room.id, broom.id)
		if is_nan(door) or absf(bx - door) > TWO_SHOT_DOOR_M:
			return 0.0
	var gap := absf(bx - hx) + BELLOWS_HALF_W
	var need_v := gap / (1.0 - TWO_SHOT_EDGE)
	var base_v := visible_width_for(_user_dist)
	if need_v <= base_v:
		return _user_dist
	return minf(_user_dist * need_v / base_v, BASE_DIST * View3DConst.TWO_SHOT_MAX)


## C3: the camera x holding both (Hush ≥ 20 % from either edge, Bellows inside with his half width).
func _two_shot_x(hx: float, bx: float, V: float) -> float:
	var c := (hx + bx) * 0.5
	var lo := hx - (0.5 - TWO_SHOT_EDGE) * V
	var hi := hx + (0.5 - TWO_SHOT_EDGE) * V
	c = clampf(c, lo, hi)
	var blo := bx + BELLOWS_HALF_W - V * 0.5
	var bhi := bx - BELLOWS_HALF_W + V * 0.5
	if blo <= bhi:
		var c2 := clampf(c, blo, bhi)
		if c2 >= lo and c2 <= hi:
			c = c2
	return c


## C6: shift within the safe rect for Hush and the keep-visible boxes (Hush first; a box that cannot fit is dropped).
func _c6_clamp(want: float, hx: float, fl: int) -> float:
	if _safe.size.x <= 0.0:
		return want
	var f := focal_px()
	var vs := view_size()
	var cam_pos := _cam_pos_for(Vector3(want, View3DConst.floor_y(fl) + View3DConst.CAM_AIM_Y, View3DConst.LANE_Z), _dist, 0.0)
	var cosp := 1.0 / sqrt(1.0 + PITCH_TAN * PITCH_TAN)
	var s0 := _safe.position.x - vs.x * 0.5
	var s1 := _safe.end.x - vs.x * 0.5
	var lo := -INF
	var hi := INF
	# Hush (±0.35 m)
	var dh := (cam_pos.z - View3DConst.LANE_Z) * cosp
	lo = maxf(lo, hx + 0.35 - s1 * dh / f)
	hi = minf(hi, hx - 0.35 - s0 * dh / f)
	if lo > hi:
		return want
	if _keep_fn.is_valid():
		var boxes: Variant = _keep_fn.call()
		if boxes is Array:
			for bv in boxes:
				if not (bv is AABB):
					continue
				var b: AABB = bv
				var zc := b.position.z + b.size.z
				var d := (cam_pos.z - zc) * cosp
				var blo := b.position.x + b.size.x - s1 * d / f
				var bhi := b.position.x - s0 * d / f
				var nlo := maxf(lo, blo)
				var nhi := minf(hi, bhi)
				if nlo <= nhi:
					lo = nlo
					hi = nhi
	return clampf(want, lo, hi)


func _update_floor(fl: int, dt: float) -> void:
	var y := View3DConst.floor_y(fl) + View3DConst.CAM_AIM_Y
	if _snap:
		_floor = fl
		_aim_y = y
		_floor_t = 1.0
		return
	if fl != _floor:
		_floor = fl
		_floor_from = _aim_y
		_floor_to = y
		_floor_t = 0.0
	if _floor_t < 1.0:
		var dur := REDUCED_PAN_S if reduce_motion else FLOOR_EASE_S
		_floor_t = minf(1.0, _floor_t + dt / dur)
		var e := _floor_t if reduce_motion else _ease_in_out(_floor_t)
		_aim_y = lerpf(_floor_from, _floor_to, e)
	else:
		_aim_y = y


func _update_user_dist(dt: float) -> void:
	if _ud_t >= 1.0:
		return
	var dur := REDUCED_PAN_S if reduce_motion else OVERVIEW_EASE_S
	_ud_t = minf(1.0, _ud_t + dt / dur)
	var e := _ud_t if reduce_motion else _ease_in_out(_ud_t)
	_user_dist = exp(lerpf(log(_ud_from), log(_ud_to), e))


func _update_pan(dt: float) -> void:
	match _pan_mode:
		Pan.DRAG:
			if dt > 0.0:
				_pan_vel = lerpf(_pan_vel, _pan_accum / dt, 0.5)
			_pan_accum = 0.0
			_pan_idle += dt
			if _pan_idle > PAN_IDLE_S:
				_pan_mode = Pan.FLING
		Pan.FLING:
			_pan_off += _pan_vel * dt
			_pan_vel *= exp(-dt / FLING_TAU)
			if absf(_pan_vel) < 0.08:
				_pan_vel = 0.0
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
			_pan_off = _pan_from * (1.0 - (u if reduce_motion else _ease_in_out(u)))
			if u >= 1.0:
				_pan_off = 0.0
				_pan_mode = Pan.NONE


func _update_peek(dt: float) -> float:
	var fly := REDUCED_PAN_S if reduce_motion else PEEK_FLY_S
	match _peek_mode:
		Peek.OUT:
			_peek_t += dt
			var u := clampf(_peek_t / fly, 0.0, 1.0)
			if u >= 1.0:
				_peek_mode = Peek.HOLD
				_peek_t = 0.0
			return u if reduce_motion else _ease_in_out(u)
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
			return 1.0 - (u2 if reduce_motion else _ease_in_out(u2))
	return 0.0


func _set_peek_target(world_pos: Vector2) -> void:
	_peek_x = world_pos.x / View3DConst.PX_PER_M
	_peek_floor = View3DConst.floor_of_y(-world_pos.y / View3DConst.PX_PER_M)


# --- gags ---------------------------------------------------------------------------------

func _start_gag(g: Gag) -> void:
	_gag = g
	g.from_aim = _aim
	g.from_dist = _dist
	g.from_yaw = _yaw
	g.t = 0.0
	g.phase = GagPhase.APPROACH if g.approach_f > 0 else GagPhase.IN
	g.in_pip = false
	if hush_busy_fn.is_valid() and bool(hush_busy_fn.call()) and not _focus_on_screen(_focus_point(g)):
		g.in_pip = true
		if pip != null and pip.has_method("escalate"):
			pip.call("escalate", true)
	gag_started.emit(g.id, g.in_pip)


## The world point of a gag's focus (Node3D tracked, Vector3, or Vector2 sim px on the lane).
func _focus_point(g: Gag) -> Vector3:
	var f: Variant = g.focus
	if f is Node3D and is_instance_valid(f):
		return CameraDirector3D.node_pos(f)
	if f is Vector3:
		return f
	if f is Vector2:
		return View3DConst.px_to_world(f, View3DConst.LANE_Z)
	return _aim


func _focus_on_screen(p: Vector3) -> bool:
	var s := project(p)
	var vs := view_size()
	return Rect2(Vector2.ZERO, vs).grow(-60.0).has_point(s) and Rect2(Vector2.ZERO, vs).grow(-60.0).has_point(project(p + Vector3(0.0, 1.0, 0.0)))


func _begin_out() -> void:
	if _gag == null:
		return
	_gag.phase = GagPhase.OUT
	_gag.t = 0.0
	_gag.out_aim = _aim
	_gag.out_dist = _frame_dist
	_gag.out_yaw = _yaw


func _finish_gag() -> void:
	if _gag == null:
		return
	var g := _gag
	_gag = null
	if g.in_pip and pip != null and pip.has_method("escalate"):
		pip.call("escalate", false)
	gag_finished.emit(g.id)


## The punch-in frame for a focus at a zoom: aim at the focus, D = 7.5 / zoom (≥ 4.5), C2-clamped with the focus
## kept inside the middle 60 %.
func gag_frame(focus: Vector3, zoom: float) -> Array:
	var d := maxf(View3DConst.GAG_MIN_DIST_M, BASE_DIST / maxf(0.1, zoom))
	var fl := View3DConst.floor_of_y(focus.y)
	var V := visible_width_for(d)
	var x := _c2_clamp(focus.x, fl, V)
	x = clampf(x, focus.x - GAG_FOCUS_MID * V, focus.x + GAG_FOCUS_MID * V)
	# the frame's lower edge at the lane stays within GAG_BELOW_FLOOR_M of the floor
	var half_h := d * tan(deg_to_rad(fov) * 0.5)
	var y := maxf(focus.y, View3DConst.floor_y(fl) + half_h - GAG_BELOW_FLOOR_M)
	return [Vector3(x, y, focus.z), d]


func _update_gag(vdt: float, rdt: float, aim: Vector3, dist: float, yaw: float) -> Array:
	var g := _gag
	if g.rebase:
		g.rebase = false
		g.from_aim = aim
		g.from_dist = dist
		g.from_yaw = yaw
		g.out_aim = aim
		g.out_dist = dist
		g.out_yaw = yaw
	var fp := _focus_point(g)
	var gf := gag_frame(fp, g.zoom)
	var g_aim: Vector3 = gf[0]
	var g_dist: float = gf[1]
	var g_yaw := g.yaw_deg
	var o_aim := aim
	var o_dist := dist
	var o_yaw := yaw
	match g.phase:
		GagPhase.APPROACH:
			g.t += vdt * 60.0
			var az := g.approach_zoom if g.approach_zoom > 0.0 else BASE_DIST / maxf(0.001, dist)
			var af := gag_frame(fp, az)
			var ramp := float(g.approach_f)
			var u := clampf(g.t / maxf(1.0, ramp), 0.0, 1.0)
			var e := u if reduce_motion else _ease_in_out(u)
			o_aim = g.from_aim.lerp(af[0], e)
			o_dist = lerpf(g.from_dist, af[1], e)
			o_yaw = g.from_yaw
			if g.t >= float(g.approach_f + APPROACH_HOLD_MAX_F):
				g.phase = GagPhase.IN
				g.t = 0.0
				g.from_aim = o_aim
				g.from_dist = o_dist
		GagPhase.IN:
			g.t += rdt * 60.0
			var u2 := clampf(g.t / float(g.in_f), 0.0, 1.0)
			var e2 := u2 if reduce_motion else _ease_out_cubic(u2)
			o_aim = g.from_aim.lerp(g_aim, e2)
			o_dist = lerpf(g.from_dist, g_dist, e2)
			o_yaw = lerpf(g.from_yaw, g_yaw, e2)
			if u2 >= 1.0:
				g.phase = GagPhase.HOLD
				g.t = 0.0
		GagPhase.HOLD:
			g.t += vdt * 60.0
			o_aim = g_aim
			o_dist = g_dist
			o_yaw = g_yaw
			if g.t >= float(g.hold_f):
				_begin_out()
				g.out_aim = g_aim
				g.out_dist = g_dist
				g.out_yaw = g_yaw
		GagPhase.OUT:
			g.t += vdt * 60.0
			var u3 := clampf(g.t / float(g.out_f), 0.0, 1.0)
			var e3 := u3 if reduce_motion else _ease_in_out(u3)
			o_aim = g.out_aim.lerp(aim, e3)
			o_dist = lerpf(g.out_dist, dist, e3)
			o_yaw = lerpf(g.out_yaw, yaw, e3)
			if u3 >= 1.0:
				_finish_gag()
				if not _queue.is_empty():
					var nxt: Gag = _queue.pop_front()
					_aim = o_aim
					_frame_dist = o_dist
					_yaw = o_yaw
					_start_gag(nxt)
	if g.in_pip:
		return [aim, dist, yaw]
	return [o_aim, o_dist, o_yaw]


# --- transform ------------------------------------------------------------------------------

func _cam_pos_for(aim_p: Vector3, dist: float, yaw_d: float) -> Vector3:
	var off := Vector3(0.0, dist * PITCH_TAN, dist).rotated(Vector3.UP, deg_to_rad(yaw_d))
	return aim_p + off


## The un-shaken camera transform of the current frame.
func _frame_xform() -> Transform3D:
	var pos := _cam_pos_for(_aim, _frame_dist, _yaw)
	return Transform3D(Basis.looking_at(_aim - pos, Vector3.UP), pos)


func _apply_transform() -> void:
	if is_inside_tree():
		global_transform = _frame_xform()
	else:
		transform = _frame_xform()


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
	var ppm := maxf(1.0, px_per_m_at(View3DConst.LANE_Z))
	var sh := (Vector2(n1, n2) * SHAKE_PX * t2 - _kick) / ppm
	h_offset = sh.x
	v_offset = -sh.y
	if t2 > 0.0001:
		rotate_object_local(Vector3.BACK, deg_to_rad(SHAKE_DEG * t2 * n3))


# --- helpers ------------------------------------------------------------------------------

func _room_at(x: float, fl: int) -> Room3:
	var best: Room3 = null
	for r in _rooms:
		if r.floor != fl or not _built.has(r.id):
			continue
		if x >= r.x0 and x < r.x1:
			return r
		if best == null:
			best = r
		elif absf(x - (r.x0 + r.x1) * 0.5) < absf(x - (best.x0 + best.x1) * 0.5):
			best = r
	return best


func _door_between(a: String, b: String) -> float:
	for l in _links:
		var d: Dictionary = l
		if (d["a"] == a and d["b"] == b) or (d["a"] == b and d["b"] == a):
			return float(d["x_m"])
	return NAN


func _setting(key: String, def: Variant) -> Variant:
	var st := get_node_or_null("/root/Settings") if is_inside_tree() else null
	if st != null and st.has_method("get_value"):
		var v: Variant = st.call("get_value", key, def)
		return def if v == null else v
	return def


## A node's world position (its local position while it is outside the tree — tests).
static func node_pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


static func _damp(dt: float, tau: float) -> float:
	return 1.0 - exp(-dt / maxf(0.0001, tau))


static func _ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func _ease_out_cubic(u: float) -> float:
	var v := 1.0 - u
	return 1.0 - v * v * v


## Rooms (m) from a house.json Dictionary, a ContentDB / HouseDef (its `rooms`), or an Array of room dicts.
static func rooms_from(house: Variant) -> Array[Room3]:
	var out: Array[Room3] = []
	var list: Array = []
	if house is Dictionary:
		list = (house as Dictionary).get("rooms", [])
	elif house is Array:
		list = house
	elif house is Object:
		var o: Object = house
		var h: Variant = o.get("house") if "house" in o else null
		if h is Object:
			o = h
		var rv: Variant = o.get("rooms") if "rooms" in o else null
		if rv is Array:
			list = rv
	for item in list:
		var r := Room3.new()
		if item is Dictionary:
			var d: Dictionary = item
			r.id = str(d.get("id", ""))
			r.floor = int(d.get("floor", 0))
			r.x0 = float(d.get("x0", 0)) / View3DConst.PX_PER_M
			r.x1 = float(d.get("x1", 0)) / View3DConst.PX_PER_M
		elif item is Object:
			var o2: Object = item
			r.id = str(o2.get("id"))
			r.floor = int(o2.get("floor"))
			r.x0 = float(o2.get("x0")) / View3DConst.PX_PER_M
			r.x1 = float(o2.get("x1")) / View3DConst.PX_PER_M
		else:
			continue
		out.append(r)
	return out


## Doorway / door links: [{a, b, x_m}].
static func links_from(house: Variant) -> Array:
	var out: Array = []
	var list: Array = []
	if house is Dictionary:
		list = (house as Dictionary).get("links", [])
	elif house is Object:
		var o: Object = house
		var h: Variant = o.get("house") if "house" in o else null
		if h is Object:
			o = h
		var lv: Variant = o.get("links") if "links" in o else null
		if lv is Array:
			list = lv
	for item in list:
		if item is Dictionary:
			var d: Dictionary = item
			out.append({"a": str(d.get("a", "")), "b": str(d.get("b", "")), "x_m": float(d.get("x", 0)) / View3DConst.PX_PER_M})
		elif item is Object:
			var o2: Object = item
			var a: Variant = o2.get("a") if "a" in o2 else o2.get("room_a")
			var b: Variant = o2.get("b") if "b" in o2 else o2.get("room_b")
			# LinkDef keeps sub-px (`x_sub`, SimConst.SUB per px); plain objects may carry px `x`
			var xpx := 0.0
			if "x_sub" in o2:
				xpx = float(o2.get("x_sub")) / float(SimConst.SUB)
			elif "x" in o2:
				xpx = float(o2.get("x"))
			out.append({"a": str(a), "b": str(b), "x_m": xpx / View3DConst.PX_PER_M})
	return out


## Built room ids from a SetList.Result / Dictionary (rooms_lit + rooms_backstage) / Array; empty = every room.
static func built_ids(set_list: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if set_list == null:
		return out
	if set_list is PackedStringArray:
		return set_list
	if set_list is Array:
		for v in set_list:
			out.append(str(v))
		return out
	for key in ["rooms_lit", "rooms_backstage"]:
		var v: Variant = null
		if set_list is Dictionary:
			v = (set_list as Dictionary).get(key, null)
		elif set_list is Object and key in (set_list as Object):
			v = (set_list as Object).get(key)
		if v is PackedStringArray or v is Array:
			for id in v:
				out.append(str(id))
	return out
