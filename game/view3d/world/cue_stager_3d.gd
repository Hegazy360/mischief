## CueStager3D — the director's `laugh_*` cues made visible in the 3D set (brief r3d-view3d §4.6; the 2D CueStager's
## contract on House3D's decor API). Each staging emits `WorldView3D.cue_staged(id, kind)` (`kind`: "prop" | "clip" |
## "stalls" | "fx" | "none").
##
## | Cue | What the player sees |
## |---|---|
## | `laugh_vase` | from tick 0 `parlour_vase` creeps along the mantel (House3D `nudge`, 5 cm) on every `voice` / `sfx` event of his warm-up clip (fallback every 45 f while he warms up, never in pre-roll), at most `VASE_MAX_NUDGES` so it teeters on the edge; on the cue it tips (4 f) and drops behind him (8 f): hidden, `parlour_vase_smashed` shown + dust and sparkles |
## | `laugh_doorframe` | stars at the `parlour_kitchen` door frame at his head height + his `cue:laugh_doorframe` overlay (head snaps back) over the blind shuffle |
## | `laugh_relief` | the Stalls exhale (their `relief` special comes from AudioDirector) — a small sweat-drop burst over Hush |
## | `laugh_picture` | `parlour_picture_frame` drops 12 f onto his head (lent to his head socket), hangs round his neck 60 f, then falls away + his `cue:laugh_picture` overlay |
## | `sparkle_lever`, `ghost_*`, `figgis_psst`, `card_*` | FTUE (`WorldView3D.sparkle`) — "fx" |
## | `title_card` | nothing during PLAY — "none" |
class_name CueStager3D
extends RefCounted

const VASE := "parlour_vase"
const VASE_SMASHED := "parlour_vase_smashed"
const PICTURE := "parlour_picture_frame"
const CREEP_FALLBACK_F := 45.0
const VASE_MAX_NUDGES := 5
const TIP_F := 4.0
const FALL_F := 8.0
const PIC_DROP_F := 12.0
const PIC_HANG_F := 60.0
const PIC_OFF_F := 20.0
const DOORFRAME_HEAD_Y := 2.05

var wv: WorldView3D = null
var nudges: int = 0
var _clock := 0.0
var _vase_phase := ""   ## "" | "tip" | "fall" | "smashed"
var _vase_t := 0.0
var _vase_home := Transform3D.IDENTITY
var _tip_from := Vector3.ZERO
var _pic_phase := ""    ## "" | "drop" | "hang" | "off" | "gone"
var _pic_t := 0.0


func setup(w: WorldView3D) -> void:
	wv = w
	var v := _decor(VASE)
	if v != null:
		_vase_home = v.transform


func reset() -> void:
	nudges = 0
	_clock = 0.0
	_vase_phase = ""
	_pic_phase = ""
	var v := _decor(VASE)
	if v != null:
		v.transform = _vase_home
		v.visible = true
	_set_visible(VASE_SMASHED, false)
	_set_visible(PICTURE, true)


func _decor(id: String) -> Node3D:
	if wv == null or wv.set3d == null or not wv.set3d.has_method("decor"):
		return null
	var n: Variant = wv.set3d.call("decor", id)
	return n as Node3D if n is Node3D else null


func _set_visible(id: String, on: bool) -> void:
	if wv != null and wv.set3d != null and wv.set3d.has_method("set_decor_visible"):
		wv.set3d.call("set_decor_visible", id, on)


func _play(id: String, anim: String) -> void:
	if wv != null and wv.set3d != null and wv.set3d.has_method("play_decor"):
		wv.set3d.call("play_decor", id, anim)


## Sim events: the cues themselves.
func on_event(ev: Dictionary, snap: ViewSnapshot) -> void:
	if str(ev.get("e", "")) != "director_cue" or wv == null:
		return
	var id := str(ev.get("id", ""))
	match id:
		"laugh_vase":
			_vase_phase = "tip"
			_vase_t = 0.0
			var v := _decor(VASE)
			if v != null:
				_tip_from = v.position
			wv.cue_staged.emit(id, "prop" if _decor(VASE) != null else "none")
		"laugh_doorframe":
			var l := wv.layout.link_between("parlour", "kitchen")
			var x := (float(l.x) if l != null else snap.bellows.x) / View3DConst.PX_PER_M
			var fy := -wv.layout.room_floor_y("parlour") / View3DConst.PX_PER_M
			if wv.fx3d != null:
				wv.fx3d.burst("stars", Vector3(x, fy + DOORFRAME_HEAD_Y, View3DConst.LANE_Z - 0.2))
			var played := _cue_clip(id)
			wv.cue_staged.emit(id, "clip" if played else "fx")
		"laugh_relief":
			if wv.fx3d != null and wv.hush_view != null:
				wv.fx3d.burst("drops", wv.hush_view.head_world() + Vector3(0.15, 0.2, 0.0), Vector3(0.3, 1.0, 0.0))
			wv.cue_staged.emit(id, "stalls")
		"laugh_picture":
			_pic_phase = "drop"
			_pic_t = 0.0
			if wv.set3d != null and wv.set3d.has_method("lend") and wv.bellows_view != null:
				wv.set3d.call("lend", PICTURE, wv.bellows_view.socket_node("head"), int(PIC_DROP_F))
			_cue_clip(id)
			wv.cue_staged.emit(id, "prop" if _decor(PICTURE) != null else "none")
		"title_card":
			wv.cue_staged.emit(id, "none")
		_:
			if id.begins_with("laugh_"):
				wv.cue_staged.emit(id, "none")
			elif id != "":
				wv.cue_staged.emit(id, "fx")


## Play the cue's overlay clip on Bellows when the 3D map has one (`cue:<id>`); true when it played.
func _cue_clip(id: String) -> bool:
	var bv := wv.bellows_view
	if bv == null:
		return false
	var clip := ClipMap.clip_of(ClipMap.entry(bv.map, "cue:" + id, bv.skin))
	var row := ClipRules.row("cue:" + id, "bellows")
	var lr: Variant = row.get("len", {})
	var exp_f := float((lr as Dictionary).get("expect_f", 0)) if lr is Dictionary else 0.0
	var ok := ClipMap.clip_exists3d(clip)
	bv.play_cue(id, 0.0 if ok else exp_f)
	return ok


## Clip events: every warm-up note (voice / sfx of his `warmup` clip) nudges the vase.
func on_clip_event(ev: Dictionary) -> void:
	if wv == null or str(ev.get("actor", "")) != "bellows" or _vase_phase != "":
		return
	var t := str(ev.get("type", ""))
	var clip := str(ev.get("clip", wv.bellows_view.current_clip() if wv.bellows_view != null else ""))
	if (t == "voice" or t == "sfx") and clip.contains("warmup"):
		_creep()


func _creep() -> void:
	_clock = 0.0
	if nudges >= VASE_MAX_NUDGES or _decor(VASE) == null:
		return
	nudges += 1
	_play(VASE, "nudge")


## Per frame (view time).
func advance(snap: ViewSnapshot, dt: float) -> void:
	if wv == null:
		return
	var f := dt * 60.0
	var warm := snap.bellows.activity == "warmup" and not snap.bellows.moving
	var bv := wv.bellows_view
	var clip_driven := warm and bv != null and bv.current_clip().contains("warmup") and ClipMap.clip_exists3d(bv.current_clip())
	if _vase_phase == "" and warm and snap.tick > 0 and not clip_driven:
		_clock += f
		if _clock >= CREEP_FALLBACK_F:
			_creep()
	_advance_vase(f)
	_advance_picture(f)


func _advance_vase(f: float) -> void:
	if _vase_phase == "" or _vase_phase == "smashed":
		return
	var v := _decor(VASE)
	if v == null:
		_vase_phase = "smashed"
		return
	_vase_t += f
	if _vase_phase == "tip":
		v.rotation.z = deg_to_rad(70.0) * clampf(_vase_t / TIP_F, 0.0, 1.0)
		if _vase_t >= TIP_F:
			_vase_phase = "fall"
			_vase_t = 0.0
	elif _vase_phase == "fall":
		var u := clampf(_vase_t / FALL_F, 0.0, 1.0)
		v.rotation.z = deg_to_rad(70.0 + 110.0 * u)
		v.position.y = _tip_from.y - maxf(0.0, _tip_from.y - 0.1) * u * u
		v.position.x = _tip_from.x - 0.15 * u
		if _vase_t >= FALL_F:
			_vase_phase = "smashed"
			var at := v.global_position if v.is_inside_tree() else v.position
			_play(VASE, "smash")
			_set_visible(VASE_SMASHED, true)
			if wv.fx3d != null:
				wv.fx3d.burst("dust", at)
				wv.fx3d.burst("sparkles", at + Vector3(0.0, 0.2, 0.0))


func _advance_picture(f: float) -> void:
	if _pic_phase == "" or _pic_phase == "gone":
		return
	_pic_t += f
	match _pic_phase:
		"drop":
			if _pic_t >= PIC_DROP_F:
				_pic_phase = "hang"
				_pic_t = 0.0
				if wv.fx3d != null and wv.bellows_view != null:
					wv.fx3d.burst("stars", wv.bellows_view.head_world() + Vector3(0.0, 0.25, 0.0))
		"hang":
			if _pic_t >= PIC_HANG_F:
				_pic_phase = "off"
				_pic_t = 0.0
		"off":
			if _pic_t >= PIC_OFF_F:
				_pic_phase = "gone"
				_set_visible(PICTURE, false)
				if wv.fx3d != null and wv.bellows_view != null:
					wv.fx3d.burst("dust", wv.bellows_view.feet_world() + Vector3(0.3, 0.1, 0.0))


## Debug / tests: the vase / picture phases.
func vase_phase() -> String:
	return _vase_phase


func picture_phase() -> String:
	return _pic_phase
