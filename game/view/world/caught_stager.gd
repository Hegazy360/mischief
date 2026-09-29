## CaughtStager — caught → Busted Cam → Lecture → doorstep (GDD §4.6, s2-view brief §4.2.14),
## frame-locked to `reactions.json caught` through the sim's one-shot clock (`caught:grab` /
## `caught:busted` 0–60, `caught:lecture` 60–192, `caught:wipe` 192–204, `caught:doorstep`
## 204–240):
##
## * 0–60 — the Busted Cam re-stage (WorldView.start_busted_replay on the `caught` event) over
##   `st_grab` / `st_busted`.
## * 60–192 — the Lecture: Hush's `torso:braces` point is attached to Bellows' `hand_r:grip`
##   socket (two rigs, one transform chain; her `lec_dangled` frame-locked with his
##   `lec_<variant>` by the ClipMap one-shot rows), the camera framing both. Pip skin: no attach
##   (`lec_broom_*` + `lec_swept`: the broom shoos her out).
## * 192–204 — the ink iris wipe.
## * 204–240 — Hush on the doorstep (the sim places her at the Night's entry point), Bellows in
##   the nearest doorway playing `st_door_slam`; the knocker bonks her (stars) at DOORSTEP_KNOCK_F,
##   then `st_tomato` with the `TOMATO` look. Control returns at 240.
class_name CaughtStager
extends RefCounted

const DOORSTEP_KNOCK_F := 14
const DANGLE_FALLBACK := Vector2(96, -210)

var wv: WorldView = null
var phase: String = ""
var phase_t: int = 0
var _lecture_gag := 0
var _door_gag := 0
var _wiped := false
var _knocked := false
var _tomato := false
var _door_x := INF


func setup(w: WorldView) -> void:
	wv = w


func reset() -> void:
	phase = ""
	phase_t = 0
	_lecture_gag = 0
	_door_gag = 0
	_wiped = false
	_knocked = false
	_tomato = false
	_door_x = INF


func on_event(ev: Dictionary, _snap: ViewSnapshot) -> void:
	if ViewKit.s(ev.get("e", "")) == "caught":
		_wiped = false
		_knocked = false
		_tomato = false
		_door_x = INF


## The attach offset: where Hush's origin goes so that her braces point sits on his grip.
## `grip` / `braces` are world points of his socket and her socket; `hush_origin` her node.
static func attach_origin(grip: Vector2, braces: Vector2, hush_origin: Vector2) -> Vector2:
	return hush_origin + (grip - braces)


## The caught phase for a one-shot id ("" when not caught).
static func phase_of(oneshot: String) -> String:
	if oneshot.begins_with("caught:"):
		return oneshot.substr(7)
	return ""


## Per frame, after both CharacterViews applied their snapshot (`replaying`: the Busted Cam
## re-stage owns the characters — track the phase only).
func advance(snap: ViewSnapshot, _dt: float, replaying: bool = false) -> void:
	var b := snap.bellows
	var h := snap.hush
	var p := CaughtStager.phase_of(b.oneshot)
	if p == "":
		p = CaughtStager.phase_of(h.oneshot)
	if p != phase:
		_enter(p, snap)
	phase = p
	phase_t = b.oneshot_t if CaughtStager.phase_of(b.oneshot) != "" else h.oneshot_t
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
			if cam != null:
				var mid := (wv.hush_view.global_position + wv.bellows_view.global_position) * 0.5 + Vector2(0, -230)
				_lecture_gag = cam.request_gag(mid, 1.25, 10, 120, 8, 90)
		"wipe":
			if not _wiped:
				_wiped = true
				wv.fx.wipe()
			if cam != null and _lecture_gag != 0:
				cam.release_gag(_lecture_gag)
				_lecture_gag = 0
		"doorstep":
			_door_x = _doorway_x(snap)
			if cam != null:
				var at := Vector2((snap.hush.x + _door_x) * 0.5, wv.layout.room_floor_y(snap.hush.room) - 220.0)
				_door_gag = cam.request_gag(at, 1.2, 1, 30, 10, 90)
		"":
			if cam != null:
				if _lecture_gag != 0:
					cam.release_gag(_lecture_gag)
				if _door_gag != 0:
					cam.release_gag(_door_gag)
			_lecture_gag = 0
			_door_gag = 0


## Hush dangles by her braces from his fist (skin "" only; the Pip broom shoo has no attach).
func _attach() -> void:
	var hv := wv.hush_view
	var bv := wv.bellows_view
	if not hv.pick().attach:
		return
	if hv.uses_rig and bv.uses_rig:
		var grip := bv.socket_transform("hand_r:grip").origin
		var braces := hv.socket_transform("torso:braces").origin
		hv.global_position = CaughtStager.attach_origin(grip, braces, hv.global_position)
	else:
		hv.global_position = bv.global_position + Vector2(DANGLE_FALLBACK.x * float(bv.get_facing()), DANGLE_FALLBACK.y)


## The doorway nearest the doorstep point (a door / exit hotspot within 450 px), else beside her.
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
	if _door_x != INF:
		bv.global_position = Vector2(_door_x, wv.layout.room_floor_y(snap.hush.room))
	if not _knocked and phase_t >= DOORSTEP_KNOCK_F:
		_knocked = true
		wv.fx.stars_at(hv.head_position())
		wv.fx.burst("sparkles", hv.head_position(), 6)
	if not _tomato and phase_t >= DOORSTEP_KNOCK_F + 6:
		_tomato = true
