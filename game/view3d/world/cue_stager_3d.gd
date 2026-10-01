## CueStager3D — the director's `laugh_*` cues made visible in the 3D set (brief r3d-view3d §4.6; the 2D CueStager's
## contract on House3D's decor API). Each staging emits `WorldView3D.cue_staged(id, kind)` (`kind`: "prop" | "clip" |
## "stalls" | "fx" | "none").
##
## | Cue | What the player sees |
## |---|---|
## | `laugh_vase` | the curtain-up shot: until Hush starts her climb-in the camera frames HIM singing and the vase (a cue shot); from tick 0 `parlour_vase` (×1.5, blue-and-white, inked) creeps along the mantel (House3D `nudge`) on every `voice` / `sfx` event of his warm-up clip — each note flies from his head toward it (fallback every 45 f while he warms up, never in pre-roll), at most `VASE_MAX_NUDGES`; from the 3rd nudge it teeters (a growing rock); on the cue it tips (4 f) and drops (8 f): hidden, `parlour_vase_smashed` shown + dust and sparkles |
## | `laugh_doorframe` | a 1.3 punch on his head at the `parlour_kitchen` door frame; he stops dead at the frame (view pin, `BONK_PIN_F`) and buckles into `st_bonk` (face to camera, dazed, D8) under his `cue:laugh_doorframe` overlay (head snaps back); on its accent (f4) a shake + kick, a dust puff off the frame edge and stars at his head; then he shuffles on |
## | `laugh_relief` | the near miss: while he hunts within `RELIEF_NEAR_M` of Hush's hiding spot the camera holds a 1.3 two-shot of him and her eyes in the gap; on the cue the Stalls exhale (AudioDirector), a sweat-drop burst over Hush and his smug `st_smirk` to the camera ("nothing here") |
## | `laugh_picture` | a 1.2 cue shot on him at the doorway; `parlour_picture_frame` (gilt, inked) drops 12 f onto his head (lent to his `head_top` socket, facing the camera, askew on the bouffant), rides there 60 f (his head's position, never its turns) while he stands stunned (`st_bonk`, never walking on the spot), then slides down beside his feet (20 f) and is gone in a puff of dust + his `cue:laugh_picture` overlay |
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
## The frame on his head: tilted about the view axis, its bottom edge sunk into the bouffant below `head_top`, a
## little toward the camera (it reads as a picture stuck on his head, face-on, not edge-on along his facing).
const PIC_TILT_DEG := 14.0
const PIC_SINK_M := 0.22
const PIC_FRONT_M := 0.14
## Where it falls: beside his feet, toppled onto its side.
const PIC_FLOOR_OFFSET := Vector3(0.42, 0.0, 0.2)
const PIC_FLOOR_TILT_DEG := -80.0
const DOORFRAME_HEAD_Y := 2.05
## Cue shots (r3d-fix-gags: every Prologue gag's cause and contact on screen): CameraDirector3D gags with these zooms,
## priority under a reaction's punch-in (10) so a payoff always wins.
const SHOT_PRIORITY := 5
const EST_OUT_F := 27
const BONK_ZOOM := 1.3
const BONK_PIN_F := 58.0
const BONK_HOLD_CLIP := "bellows/st_bonk"
const BONK_ACCENT_F := 4.0
const BONK_RECOIL_M := 0.12
## Half the wing flat's thickness (house3d.json stage.wing_flat 0.22 m).
const FLAT_HALF_M := 0.11
const PIC_ZOOM := 1.2
const PIC_HOLD_CLIP := "bellows/st_bonk"
const RELIEF_ZOOM := 1.3
const RELIEF_NEAR_M := 1.7
const RELIEF_TAIL_F := 40
const RELIEF_CLIP := "bellows/st_smirk"
## The vase teeters from this many nudges on (amplitude per nudge past it, degrees; rate Hz).
const TEETER_FROM := 3
const TEETER_DEG := 4.5
const TEETER_HZ := 2.6

var wv: WorldView3D = null
var nudges: int = 0
var _clock := 0.0
var _vase_phase := ""   ## "" | "tip" | "fall" | "smashed"
var _vase_t := 0.0
var _vase_home := Transform3D.IDENTITY
var _tip_from := Vector3.ZERO
var _pic_phase := ""    ## "" | "drop" | "hang" | "off" | "gone"
var _pic_t := 0.0
var _pic_basis := Basis.IDENTITY   ## the frame's world basis on the wall (face-on to the camera)
var _teeter_t := 0.0
var _tip_rot0 := 0.0
var _shot_id := 0
var _shot := ""          ## "" | "establish" | "bonk" | "relief" | "picture"
var _shot_live := false  ## the shot became the camera's active gag at least once
var _est_done := false
var _bonk_t := -1.0
var _relief_done := false
var _shot_tail := -1.0    ## frames left before the current shot is let go (-1 = it plays its own hold)
## Cue shots requested (tests / the review).
var shots: int = 0


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
	_teeter_t = 0.0
	_end_shot()
	_est_done = false
	_bonk_t = -1.0
	_relief_done = false
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
				_tip_rot0 = v.rotation.z
			wv.cue_staged.emit(id, "prop" if _decor(VASE) != null else "none")
		"laugh_doorframe":
			var l := wv.layout.link_between("parlour", "kitchen")
			var x := (float(l.x) if l != null else snap.bellows.x) / View3DConst.PX_PER_M
			var played := _cue_clip(id)
			# he walked into the frame: he stops dead against it (his face at the frame's edge on his side, a recoil
			# off it), buckles dazed, face to camera, while the camera punches in on his head
			var face := float(snap.bellows.facing if snap.bellows.facing != 0 else -1)
			if wv.bellows_view != null:
				wv.bellows_view.stage_pin(BONK_PIN_F, x - face * (FLAT_HALF_M + 0.30 + BONK_RECOIL_M))
				wv.bellows_view.stage_hold(BONK_HOLD_CLIP, BONK_PIN_F)
			_start_shot("bonk", _bellows_head(), BONK_ZOOM, 8, int(BONK_PIN_F) + 6, 24, 5.0 * face)
			_bonk_t = 0.0
			wv.cue_staged.emit(id, "clip" if played else "fx")
		"laugh_relief":
			if wv.fx3d != null and wv.hush_view != null:
				var eyes := _hidden_eyes(snap)
				var at := eyes if eyes != Vector3.INF else wv.hush_view.head_world()
				wv.fx3d.burst("drops", at + Vector3(0.15, 0.2, 0.0), Vector3(0.3, 1.0, 0.0))
			if wv.bellows_view != null:
				wv.bellows_view.stage_overlay(RELIEF_CLIP, 34.0)
			if _shot == "relief" and wv.cam != null:
				# hold the two-shot through his smirk, then let it go
				_end_shot_after(RELIEF_TAIL_F)
			_relief_done = true
			wv.cue_staged.emit(id, "stalls")
		"laugh_picture":
			_pic_phase = "drop"
			_pic_t = 0.0
			_start_shot("picture", _bellows_head(), PIC_ZOOM, 10, int(PIC_DROP_F + PIC_HANG_F + PIC_OFF_F) + 8, 24)
			if wv.bellows_view != null:
				wv.bellows_view.stage_hold(PIC_HOLD_CLIP, PIC_DROP_F + PIC_HANG_F)
			var top: Node3D = wv.bellows_view.socket_node("head_top") if wv.bellows_view != null else null
			_pic_basis = _pic_home_basis()
			if wv.set3d != null and wv.set3d.has_method("lend") and top != null and top.is_inside_tree():
				var at := CueStager3D.picture_pose(top.global_transform,
						top.global_position + Vector3(0.0, -PIC_SINK_M, PIC_FRONT_M), PIC_TILT_DEG, _pic_basis)
				wv.set3d.call("lend", PICTURE, top, int(PIC_DROP_F), at)
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
	var v := _decor(VASE)
	if nudges >= VASE_MAX_NUDGES or v == null:
		return
	nudges += 1
	_play(VASE, "nudge")
	# the cause on screen: his note flies from his mouth toward the vase, and lands on it
	if wv.fx3d != null and wv.bellows_view != null and v.is_inside_tree():
		var head := wv.bellows_view.head_world()
		var to := v.global_position + Vector3(0.0, 0.5, 0.0)
		wv.fx3d.burst("note_fly", head + Vector3(0.0, 0.1, 0.1), (to - head).normalized() + Vector3(0.0, 0.08, 0.0))
		wv.fx3d.burst("notes", to + Vector3(0.0, 0.25, 0.0), Vector3.UP)


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
	_advance_shot(snap, f)
	_advance_bonk(f)


func _advance_vase(f: float) -> void:
	if _vase_phase == "":
		_teeter(f)
		return
	if _vase_phase == "smashed":
		return
	var v := _decor(VASE)
	if v == null:
		_vase_phase = "smashed"
		return
	_vase_t += f
	if _vase_phase == "tip":
		v.rotation.z = lerpf(_tip_rot0, deg_to_rad(70.0), clampf(_vase_t / TIP_F, 0.0, 1.0))
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
			_hold_picture_on_head()
			if _pic_t >= PIC_HANG_F:
				_pic_phase = "off"
				_pic_t = 0.0
				var feet: Node3D = wv.bellows_view.socket_node("feet") if wv.bellows_view != null else null
				if wv.set3d != null and wv.set3d.has_method("lend") and feet != null and feet.is_inside_tree():
					var at := CueStager3D.picture_pose(feet.global_transform, feet.global_position + PIC_FLOOR_OFFSET,
							PIC_FLOOR_TILT_DEG, _pic_basis)
					wv.set3d.call("lend", PICTURE, feet, int(PIC_OFF_F), at)
		"off":
			if _pic_t >= PIC_OFF_F:
				_pic_phase = "gone"
				_set_visible(PICTURE, false)
				if wv.fx3d != null and wv.bellows_view != null:
					wv.fx3d.burst("dust", wv.bellows_view.feet_world() + Vector3(0.3, 0.1, 0.0))


## The socket-space pose (for `lend`) that puts a set piece at `world_pos` with its wall orientation `home_basis`
## (its world basis as it hung, face-on to the camera, its own size) turned `tilt_deg` about the view axis (+z) —
## whatever the socket's bone orientation (Bellows faces ±x: an identity pose on his head socket shows the frame
## edge-on).
static func picture_pose(sock: Transform3D, world_pos: Vector3, tilt_deg: float, home_basis: Basis) -> Transform3D:
	var world := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(tilt_deg)) * home_basis, world_pos)
	return sock.affine_inverse() * world


## While it hangs, the frame follows his head's position but never its turns (lent to the head bone it would turn
## with it: a profile-to-camera turn shows it edge-on).
func _hold_picture_on_head() -> void:
	var pic := _decor(PICTURE)
	var top: Node3D = wv.bellows_view.socket_node("head_top") if wv.bellows_view != null else null
	if pic == null or top == null or not pic.is_inside_tree() or not top.is_inside_tree():
		return
	pic.global_transform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(PIC_TILT_DEG)) * _pic_basis,
			top.global_position + Vector3(0.0, -PIC_SINK_M, PIC_FRONT_M))


## The picture frame's world basis on the wall (identity when it is not built).
func _pic_home_basis() -> Basis:
	var pic := _decor(PICTURE)
	if pic == null or not pic.is_inside_tree():
		return Basis.IDENTITY
	return pic.global_transform.basis


## The vase on the edge: from TEETER_FROM nudges it rocks on its base, harder with every note (the wobble before it
## tips, Q-G4).
func _teeter(f: float) -> void:
	if nudges < TEETER_FROM:
		return
	var v := _decor(VASE)
	if v == null:
		return
	_teeter_t += f / 60.0
	v.rotation.z = CueStager3D.teeter_angle(nudges, _teeter_t)


## The teeter's angle (radians) after `n` nudges at `t` s: 0 below TEETER_FROM, then a rock of TEETER_DEG per nudge
## past it (toward the edge it creeps to, +z).
static func teeter_angle(n: int, t: float) -> float:
	if n < TEETER_FROM:
		return 0.0
	var amp := TEETER_DEG * float(n - TEETER_FROM + 1)
	return deg_to_rad(amp * (0.35 + 0.65 * absf(sin(t * TAU * TEETER_HZ * 0.5))) * signf(sin(t * TAU * TEETER_HZ)))


# --- cue shots ------------------------------------------------------------------------------

func _bellows_head() -> Vector3:
	return wv.bellows_view.head_world() if wv.bellows_view != null and wv.bellows_view.visible else Vector3.INF


func _start_shot(kind: String, focus: Vector3, zoom: float, in_f: int, hold_f: int, out_f: int, yaw: float = 0.0) -> void:
	var c := wv.cam if wv != null else null
	if c == null or focus == Vector3.INF:
		return
	if _shot_id != 0:
		c.release_gag(_shot_id)
	_shot_id = c.request_gag(focus, zoom, in_f, hold_f, out_f, SHOT_PRIORITY, yaw)
	_shot = kind
	_shot_tail = -1.0
	_shot_live = c.active_gag_id() == _shot_id
	shots += 1


func _end_shot() -> void:
	if _shot_id != 0 and wv != null and wv.cam != null:
		wv.cam.release_gag(_shot_id)
	_shot_id = 0
	_shot = ""
	_shot_live = false
	_shot_tail = -1.0



func _end_shot_after(frames: int) -> void:
	_shot_tail = float(frames)


## The current cue shot's kind ("" when none) — tests / the review.
func shot_kind() -> String:
	return _shot


## Per frame: the curtain-up shot, the relief two-shot, and every shot's focus (he moves through it).
func _advance_shot(snap: ViewSnapshot, f: float) -> void:
	var c := wv.cam
	if c == null:
		return
	# the curtain rises on HIM: until Hush starts her climb-in (P00) the camera frames him and the vase
	var pre := snap.hush.entering and snap.hush.oneshot != "enter" and snap.bellows.present
	if pre and _shot == "" and not _est_done:
		_est_done = true
		_start_shot("establish", _establish_focus(snap), 1.0, 1, 100000, EST_OUT_F)
	elif _shot == "establish" and not pre:
		_end_shot()
	# the near miss: he hunts right past her hiding spot
	if _shot == "" and not _relief_done and snap.bellows.activity == "hunt" and (snap.hush.state == "HIDDEN" or snap.hush.hidden_spot != ""):
		var eyes := _hidden_eyes(snap)
		var head := _bellows_head()
		if eyes != Vector3.INF and head != Vector3.INF and absf(eyes.x - head.x) <= RELIEF_NEAR_M:
			_start_shot("relief", _relief_focus(head, eyes), RELIEF_ZOOM, 14, 100000, 26)
	if _shot == "":
		return
	if c.active_gag_id() == _shot_id:
		_shot_live = true
	elif _shot_live or _shot_id == 0:
		# it played out (or a reaction's punch-in replaced it)
		_shot_id = 0
		_shot = ""
		_shot_live = false
		_shot_tail = -1.0
		return
	match _shot:
		"establish":
			c.set_gag_focus(_shot_id, _establish_focus(snap))
		"bonk", "picture":
			var h := _bellows_head()
			if h != Vector3.INF:
				c.set_gag_focus(_shot_id, h)
		"relief":
			var eyes2 := _hidden_eyes(snap)
			var head2 := _bellows_head()
			if eyes2 != Vector3.INF and head2 != Vector3.INF:
				c.set_gag_focus(_shot_id, _relief_focus(head2, eyes2))
			elif _shot_tail < 0.0:
				_end_shot()
				return
	if _shot_tail >= 0.0:
		_shot_tail -= f
		if _shot_tail <= 0.0:
			_end_shot()


## The curtain-up shot's focus: between him and the vase when it is on his floor and within one frame of him, else
## his chest — on the lane at the base aim height.
func _establish_focus(snap: ViewSnapshot) -> Vector3:
	var bv := wv.bellows_view
	var bx := bv.feet_world() if bv != null else Vector3.ZERO
	var x := bx.x
	var v := _decor(VASE)
	if v != null and v.is_inside_tree() and v.visible and absf(v.global_position.x - bx.x) < 5.5:
		x = (bx.x + v.global_position.x) * 0.5
	return Vector3(x, View3DConst.floor_y(View3DConst.floor_of_y(bx.y)) + View3DConst.CAM_AIM_Y, View3DConst.LANE_Z)


## The two-shot point between his head and her eyes in the gap.
static func _relief_focus(head: Vector3, eyes: Vector3) -> Vector3:
	return Vector3((head.x + eyes.x) * 0.5, minf(head.y, eyes.y) + 0.1, View3DConst.LANE_Z)


## Hush's eyes in her hiding spot (world), INF when she is not hidden.
func _hidden_eyes(snap: ViewSnapshot) -> Vector3:
	var spot := snap.hush.hidden_spot
	if spot == "" or not wv.has_method("anchor_of"):
		return Vector3.INF
	var p: Vector3 = wv.anchor_of(spot, &"eyes")
	return p if p != Vector3.ZERO else Vector3.INF


## The doorframe bonk's accent (its clip's f4): the hit lands on the frame — shake, kick, dust off the frame's edge,
## stars at his head.
func _advance_bonk(f: float) -> void:
	if _bonk_t < 0.0:
		return
	_bonk_t += f
	if _bonk_t < BONK_ACCENT_F:
		return
	_bonk_t = -1.0
	var bv := wv.bellows_view
	if bv == null:
		return
	var head := bv.head_world()
	if wv.cam != null:
		wv.cam.shake(0.5)
		wv.cam.kick(Vector2(float(bv.get_facing()) * -1.0, -0.3), 14.0)
	if wv.fx3d != null:
		var l := wv.layout.link_between("parlour", "kitchen")
		var x := float(l.x) / View3DConst.PX_PER_M if l != null else head.x
		var edge := x - float(bv.get_facing()) * FLAT_HALF_M
		wv.fx3d.burst("bonk_dust", Vector3(edge, head.y, View3DConst.LANE_Z - 0.25), Vector3(-float(bv.get_facing()), 0.4, 0.3))
		wv.fx3d.burst("bonk_stars", head + Vector3(0.0, 0.3, 0.0))


## Debug / tests: the vase / picture phases.
func vase_phase() -> String:
	return _vase_phase


func picture_phase() -> String:
	return _pic_phase
