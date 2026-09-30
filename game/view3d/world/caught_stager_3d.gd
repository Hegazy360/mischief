## CaughtStager3D — caught → Busted Cam → Lecture → doorstep in the 3D set (GDD §4.6; the 2D CaughtStager's contract,
## brief r3d-view3d §4.6), frame-locked to `reactions.json caught` through the sim's one-shot clock (`caught:grab` /
## `caught:busted` 0–60, `caught:lecture` 60–192, `caught:wipe` 192–204, `caught:doorstep` 204–240):
##
## * 0–60 — the Busted Cam re-stage (WorldView3D.start_busted_replay on the `caught` event) over `st_grab` / `st_busted`.
## * 60–192 — the Lecture: Hush hangs by her braces (`brace_r` socket) from his fist (`grip_r`), both rigs in one
##   world transform chain, the camera pushed onto both (1.25 zoom). Without rigs: a fixed dangle offset.
## * 192–204 — the wipe (the HUD's iris; here the busted tint lifts).
## * 204–240 — Hush on the doorstep (the sim places her), Bellows in the nearest doorway (`st_door_slam`); the knocker
##   bonks her (stars) at DOORSTEP_KNOCK_F, then the tomato. Control returns at 240. Only N1/N2 can catch (not the
##   Prologue); nothing here errors without House3D, rigs or clips.
class_name CaughtStager3D
extends RefCounted

const DOORSTEP_KNOCK_F := 14
## Hush's origin relative to his (m, facing-mirrored x) when there is no rig to hang from.
const DANGLE_FALLBACK := Vector3(0.48, 1.05, 0.12)

var wv: WorldView3D = null
var phase: String = ""
var phase_t: int = 0
var _lecture_gag := 0
var _door_gag := 0
var _knocked := false
var _tomato := false
var _door_x := INF


func setup(w: WorldView3D) -> void:
	wv = w


func reset() -> void:
	phase = ""
	phase_t = 0
	_lecture_gag = 0
	_door_gag = 0
	_knocked = false
	_tomato = false
	_door_x = INF


func on_event(ev: Dictionary, _snap: ViewSnapshot) -> void:
	if str(ev.get("e", "")) == "caught":
		_knocked = false
		_tomato = false
		_door_x = INF


## Where Hush's origin goes so her braces socket sits on his grip (world points, m).
static func attach_origin(grip: Vector3, braces: Vector3, hush_origin: Vector3) -> Vector3:
	return hush_origin + (grip - braces)


## The caught phase for a one-shot id ("" when not caught).
static func phase_of(oneshot: String) -> String:
	return oneshot.substr(7) if oneshot.begins_with("caught:") else ""


## Per frame, after both CharacterView3Ds applied their snapshot (`replaying`: the Busted Cam owns the characters).
func advance(snap: ViewSnapshot, _dt: float, replaying: bool = false) -> void:
	if wv == null:
		return
	var p := CaughtStager3D.phase_of(snap.bellows.oneshot)
	if p == "":
		p = CaughtStager3D.phase_of(snap.hush.oneshot)
	if p != phase:
		_enter(p, snap)
	phase = p
	phase_t = snap.bellows.oneshot_t if CaughtStager3D.phase_of(snap.bellows.oneshot) != "" else snap.hush.oneshot_t
	if replaying:
		return
	match phase:
		"lecture":
			_attach()
		"doorstep":
			_doorstep(snap)


func _enter(p: String, snap: ViewSnapshot) -> void:
	var cam := wv.cam
	match p:
		"lecture":
			if cam != null and wv.hush_view != null and wv.bellows_view != null:
				var mid := (wv.hush_view.chest_world() + wv.bellows_view.chest_world()) * 0.5
				_lecture_gag = cam.request_gag(mid, 1.25, 10, 120, 8, 90)
		"wipe":
			wv.end_busted_replay()
			if wv.overlays != null and wv.cam != null and wv.hush_view != null:
				var sp := wv.project(wv.hush_view.chest_world())
				var vs := wv.cam.view_size()
				wv.overlays.wipe(Vector2(sp.x / maxf(1.0, vs.x), sp.y / maxf(1.0, vs.y)))
			if cam != null and _lecture_gag != 0:
				cam.release_gag(_lecture_gag)
				_lecture_gag = 0
		"doorstep":
			_door_x = _doorway_x(snap)
			if cam != null:
				var fy := -wv.layout.room_floor_y(snap.hush.room) / View3DConst.PX_PER_M
				var at := Vector3((snap.hush.x + _door_x) * 0.5 / View3DConst.PX_PER_M, fy + 1.1, View3DConst.LANE_Z)
				_door_gag = cam.request_gag(at, 1.2, 1, 30, 10, 90)
		"":
			if cam != null:
				if _lecture_gag != 0:
					cam.release_gag(_lecture_gag)
				if _door_gag != 0:
					cam.release_gag(_door_gag)
			_lecture_gag = 0
			_door_gag = 0


## Hush dangles by her braces from his fist (the Pip skin's broom shoo has no attach).
func _attach() -> void:
	var hv := wv.hush_view
	var bv := wv.bellows_view
	if hv == null or bv == null or hv.skin == "pip":
		return
	var here := hv.global_position if hv.is_inside_tree() else hv.position
	var to := here
	if hv.uses_rig and bv.uses_rig:
		var grip := bv.socket_world("grip_r").origin
		var braces := hv.socket_world("brace_r").origin
		to = CaughtStager3D.attach_origin(grip, braces, here)
	else:
		var bp := bv.global_position if bv.is_inside_tree() else bv.position
		to = bp + Vector3(DANGLE_FALLBACK.x * float(bv.get_facing()), DANGLE_FALLBACK.y, DANGLE_FALLBACK.z)
	if hv.is_inside_tree():
		hv.global_position = to
	else:
		hv.position = to


## The doorway nearest the doorstep point (a door / exit hotspot within 450 px), else beside her (sim px).
func _doorway_x(snap: ViewSnapshot) -> float:
	var best := INF
	var bx := snap.hush.x + 160.0
	for hs in wv.layout.hotspots:
		if hs.room != snap.hush.room and wv.layout.room_distance(hs.room, snap.hush.room) > 1:
			continue
		if hs.kind != "exit" and hs.kind != "door":
			continue
		var d := absf(hs.use_x - snap.hush.x)
		if d < best and d < 450.0:
			best = d
			bx = hs.use_x
	return bx


func _doorstep(snap: ViewSnapshot) -> void:
	var bv := wv.bellows_view
	var hv := wv.hush_view
	if bv == null or hv == null:
		return
	if _door_x != INF:
		var fy := -wv.layout.room_floor_y(snap.hush.room) / View3DConst.PX_PER_M
		var p := Vector3(_door_x / View3DConst.PX_PER_M, fy, View3DConst.LANE_Z)
		if bv.is_inside_tree():
			bv.global_position = p
		else:
			bv.position = p
	if not _knocked and phase_t >= DOORSTEP_KNOCK_F:
		_knocked = true
		if wv.fx3d != null:
			wv.fx3d.burst("stars", hv.head_world() + Vector3(0.0, 0.2, 0.0))
			wv.fx3d.burst("sparkles", hv.head_world())
	if not _tomato and phase_t >= DOORSTEP_KNOCK_F + 6:
		_tomato = true
