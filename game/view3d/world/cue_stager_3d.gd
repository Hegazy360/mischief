## CueStager3D — the director's `laugh_*` cues made visible in the 3D set (brief r3d-view3d §4.6; the 2D CueStager's
## contract on House3D's decor API). Each staging emits `WorldView3D.cue_staged(id, kind)` (`kind`: "prop" | "clip" |
## "stalls" | "fx" | "none").
##
## | Cue | What the player sees |
## |---|---|
## | `laugh_vase` | the curtain-up shot: until Hush starts her climb-in the camera frames HIM singing and the vase (a cue shot); from tick 0 `parlour_vase` (×1.5, blue-and-white, inked) creeps along the mantel (House3D `nudge`) on every `voice` / `sfx` event of his warm-up clip — each note flies from his head toward it (fallback every 45 f while he warms up, never in pre-roll), at most `VASE_MAX_NUDGES`; from the 3rd nudge it teeters (a growing rock); on the cue it tips (4 f) and drops (8 f): hidden, `parlour_vase_smashed` shown + dust and sparkles; then (fix round 2, Q2-G5) the shot pushes in on HIM: the crash lands on his top note like a cymbal and he takes it as his ovation — `st_straighten_cravat` (the tug, the lapels, the haughty sniff to the Stalls) held `VASE_REACT_F` with the shot on him until it ends |
## | `laugh_doorframe` | (fix round 2, Q2-G6) the anticipation the other way: `WINDUP_F` frames before he reaches the `parlour_kitchen` door frame (blind, FRAZZLED) he draws himself up and back (`cue_doorframe_windup`, nose in the air) while the 1.3 bonk shot pushes in slowly — no camera move starts within 30 f of the hit; on the cue he stops dead at the frame (view pin, `BONK_PIN_F`) and buckles into `st_bonk` (face to camera, dazed, D8) under his `cue:laugh_doorframe` overlay (head snaps back, face to camera from f7); on its accent (f4) a shake + kick, a dust puff off the frame edge, stars at his head — and the jolt knocks the parlour picture askew (a damped swing to `PIC_ASKEW_DEG`: the picture gag's set-up); the shot holds `BONK_HOLD_TAIL_F` past the pin; then he shuffles on |
## | `laugh_relief` | the near miss: while he hunts within `RELIEF_NEAR_M` of Hush's hiding spot the camera holds a 1.3 two-shot of him and her eyes in the gap (his bubble quiet); (fix round 2, Q2-G3) `RELIEF_GAZE_LEFT` ticks before his hunt runs out he glances at the gap, at `RELIEF_TAKE_LEFT` the DOUBLE TAKE (`st_double_take`: he looks away — her eyes duck — and snaps back to an empty gap) held to the cue with his face to camera (≥ 30 f); on the cue her eyes pop up and squeeze shut and a "phew" puff rises from the gap (+ sweat drops; the Stalls exhale, AudioDirector) |
## | `laugh_picture` | a 1.2 cue shot on him at the doorway; `parlour_picture_frame` (gilt, inked; askew since the bonk) drops 12 f onto his head (lent to his `head_top` socket, facing the camera, askew on the bouffant), rides there 60 f (his head's position, never its turns) while he stands stunned (`st_bonk`, never walking on the spot), then (fix round 2, Q2-G8) SLIDES off his head down past his shoulder onto the floor beside his feet (`PIC_OFF_F`, accelerating, tipping onto its side) and lands with a dust puff — it stays there + his `cue:laugh_picture` overlay |
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
const PIC_OFF_F := 26.0
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
const BONK_HOLD_DELAY_F := 2.0
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
## His gaze on the gap she hides in through the near miss (look weight).
const RELIEF_GAZE_W := 0.85
## Ticks before his hunt runs out (the relief cue) when he turns to peer at her gap / when her eyes duck.
const RELIEF_GAZE_LEFT := 46
const RELIEF_DUCK_LEFT := 36
## The vase teeters from this many nudges on (amplitude per nudge past it, degrees; rate Hz).
const TEETER_FROM := 3
const TEETER_DEG := 4.5
const TEETER_HZ := 2.6
## The bonked wing flat's wobble (degrees at first, Hz, frames).
const WING_DEG := 2.2
const WING_HZ := 7.0
const WING_F := 30.0
## Fix round 2 (Q2-G6): the bonk's anticipation the other way — he draws himself up and back in the last WINDUP_F
## frames before the frame (his walk's ETA), while the bonk shot pushes in over WINDUP_PUSH_F (a dolly, no cut near
## the hit); the shot holds BONK_HOLD_TAIL_F past the pin (his dazed face, ≥ 30 f).
const WINDUP_CLIP := "bellows/cue_doorframe_windup"
const WINDUP_F := 40.0
## The bonk shot leads the hit: it starts BONK_SHOT_LEAD_F frames before he reaches the frame and its push is done
## WINDUP_PUSH_F later — ≥ 30 f before the hit, so the camera is still from then through the dazed hold.
const BONK_SHOT_LEAD_F := 64.0
const WINDUP_PUSH_F := 24
const BONK_HOLD_TAIL_F := 36
## The bonk knocks the parlour picture askew (the picture gag's set-up): a damped swing about its hook that settles
## at PIC_ASKEW_DEG.
const PIC_ASKEW_DEG := 9.0
const PIC_SWING_DEG := 12.0
const PIC_SWING_HZ := 1.4
const PIC_SWING_S := 3.0
## Fix round 2 (Q2-G5): the vase crash is his ovation — a push-in on him for his haughty cravat straighten.
const VASE_REACT_CLIP := "bellows/st_straighten_cravat"
const VASE_REACT_DELAY_F := 6.0
const VASE_REACT_F := 46
## ... and the clip plays on past the shot (the haughty sniff 46-70) while the camera eases back to Hush.
const VASE_REACT_CLIP_F := 64.0
const VASE_REACT_ZOOM := 1.15
## Fix round 2 (Q2-G3): the double take at her gap (ticks of his hunt left), held to the cue.
const RELIEF_TAKE_CLIP := "bellows/st_double_take"
const RELIEF_TAKE_LEFT := 40
const RELIEF_PHEW_DELAY_S := 0.12
const RELIEF_PHEW2_S := 0.2
## The look point of a cue close-up's face beat, above his head (m, at 4 m toward the camera): the chin up ≈ 7°.
const CLOSEUP_GAZE_UP_M := 0.5
## Every clip this stager plays itself (WorldView3D.warm_clips warms them under the curtain: no clip or sidecar is
## first read in PLAY, D17).
const STAGED_CLIPS := ["bellows/st_bonk", "bellows/st_smirk", "bellows/cue_doorframe_windup",
	"bellows/st_straighten_cravat", "bellows/st_double_take"]

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
var _wing: Node3D = null
var _gaze_eyes := Vector3.INF
var _relief_spot := ""
var _wing_home := Transform3D.IDENTITY
var _wing_t := 0.0
var _wing_dir := -1.0
var _windup_done := false
var _bonk_lead_done := false
var _pic_wall := Transform3D.IDENTITY
var _pic_has_wall := false
var _pic_swing_t := -1.0
var _pic_tilt := 0.0
var _pic_from := Vector3.ZERO
var _pic_to := Vector3.ZERO
var _pic_tilt_from := 0.0
var _vase_react_wait := -1.0
var _relief_take := false
var _phew_t := -1.0
var _phew_spot := ""
var _phew_n := 0


func setup(w: WorldView3D) -> void:
	wv = w
	var v := _decor(VASE)
	if v != null:
		_vase_home = v.transform
	var pic := _decor(PICTURE)
	if pic != null:
		_pic_wall = pic.transform
		_pic_has_wall = true


func reset() -> void:
	nudges = 0
	_clock = 0.0
	_vase_phase = ""
	_pic_phase = ""
	_teeter_t = 0.0
	if _wing != null and is_instance_valid(_wing):
		_wing.transform = _wing_home
	_wing = null
	_end_shot()
	_est_done = false
	_bonk_t = -1.0
	_relief_done = false
	_gaze_eyes = Vector3.INF
	_relief_spot = ""
	_windup_done = false
	_bonk_lead_done = false
	_pic_swing_t = -1.0
	_pic_tilt = 0.0
	_vase_react_wait = -1.0
	_relief_take = false
	_phew_t = -1.0
	_phew_spot = ""
	var pic := _decor(PICTURE)
	if pic != null and _pic_has_wall:
		if wv != null and wv.set3d != null and wv.set3d.has_method("release_here"):
			wv.set3d.call("release_here", PICTURE)
		pic.transform = _pic_wall
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
				# the wind-up gives way to the bonk's own overlay on the hit
				wv.bellows_view.stage_overlay("", 0.0)
				wv.bellows_view.stage_pin(BONK_PIN_F, x - face * (FLAT_HALF_M + 0.30 + BONK_RECOIL_M))
				# the dazed base clip starts 2 f after the cue overlay (two clip starts never share a frame, D17)
				wv.bellows_view.stage_hold(BONK_HOLD_CLIP, BONK_PIN_F, BONK_HOLD_DELAY_F)
			# the shot already framing his approach (the wind-up push) holds through the payoff: no second move
			# within 30 f of the hit (Q2-G6); without it, a gentler push than a punch
			var held := _shot == "bonk" and _shot_id != 0 and wv.cam != null and wv.cam.has_method("extend_gag") \
					and bool(wv.cam.call("extend_gag", _shot_id, int(BONK_PIN_F) + BONK_HOLD_TAIL_F))
			if not held:
				_start_shot("bonk", _bellows_head(), BONK_ZOOM, 14, int(BONK_PIN_F) + BONK_HOLD_TAIL_F, 24, 5.0 * face)
			_bonk_t = 0.0
			wv.cue_staged.emit(id, "clip" if played else "fx")
		"laugh_relief":
			# the payoff is HERS: her eyes pop back up in the gap and squeeze shut, a "phew" puff rises from the
			# gap and sweat drops fly off her brow (Q2-G3: the laugh lands on the puff, not on his walk-off)
			var spot := _relief_spot if _relief_spot != "" else snap.hush.hidden_spot
			_phew(spot, snap)
			if wv.bellows_view != null and not _relief_take:
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
				wv.bellows_view.stage_hold(PIC_HOLD_CLIP, PIC_DROP_F + PIC_HANG_F - BONK_HOLD_DELAY_F, BONK_HOLD_DELAY_F)
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
	_advance_windup(snap)
	_advance_shot(snap, f)
	_advance_bonk(f)
	_advance_wing(f)
	_advance_pic_swing(f)
	_advance_vase_react(f)
	if _phew_t >= 0.0:
		_phew_t -= dt
		if _phew_t < 0.0:
			_phew_puff(_phew_spot)


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
				wv.fx3d.burst("bonk_dust", at + Vector3(0.0, 0.1, 0.0), Vector3(0.0, 1.0, 0.3))
				wv.fx3d.burst("sparkles", at + Vector3(0.0, 0.2, 0.0))
			# the crash lands: a jolt the whole frame feels (it is the curtain-up gag's payoff)
			if wv.cam != null:
				wv.cam.shake(0.3)
				wv.cam.kick(Vector2.DOWN, 8.0)
			# ... and it lands on his top note like a cymbal: he takes it as his ovation (Q2-G5), while the curtain-up
			# shot is still on him
			if _shot == "establish":
				_vase_react_wait = VASE_REACT_DELAY_F


func _advance_picture(f: float) -> void:
	if _pic_phase == "" or _pic_phase == "gone":
		return
	_pic_t += f
	match _pic_phase:
		"drop":
			if _pic_t >= PIC_DROP_F:
				_pic_phase = "hang"
				_pic_t = 0.0
				# THUNK: the frame lands on his head — stars, a jolt
				if wv.fx3d != null and wv.bellows_view != null:
					wv.fx3d.burst("thunk_stars", wv.bellows_view.head_world() + Vector3(0.0, 0.35, 0.15))
				if wv.cam != null:
					wv.cam.shake(0.35)
					wv.cam.kick(Vector2.DOWN, 10.0)
		"hang":
			_hold_picture_on_head()
			if _pic_t >= PIC_HANG_F:
				_pic_phase = "off"
				_pic_t = 0.0
				# it slides off (Q2-G8: it popped out of sight before): let it go where it sits on his head and slide
				# it down past his shoulder onto the floor beside his feet, behind his facing
				var pic := _decor(PICTURE)
				if pic != null and pic.is_inside_tree() and wv.bellows_view != null:
					if wv.set3d != null and wv.set3d.has_method("release_here"):
						wv.set3d.call("release_here", PICTURE)
					_pic_from = pic.global_position
					var side := -float(wv.bellows_view.get_facing()) if wv.bellows_view.get_facing() != 0 else 1.0
					var fw := wv.bellows_view.feet_world()
					_pic_to = Vector3(fw.x + side * PIC_FLOOR_OFFSET.x, fw.y + 0.02, fw.z + PIC_FLOOR_OFFSET.z)
					_pic_tilt_from = PIC_TILT_DEG
		"off":
			_slide_picture_off(clampf(_pic_t / PIC_OFF_F, 0.0, 1.0))
			if _pic_t >= PIC_OFF_F:
				_pic_phase = "gone"
				if wv.fx3d != null:
					wv.fx3d.burst("dust", _pic_to + Vector3(0.0, 0.1, 0.1))
				if wv.cam != null:
					wv.cam.shake(0.15)


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


## The picture sliding off his head (u 0…1 of PIC_OFF_F): out and down along an accelerating arc to the floor beside
## his feet, tipping from its askew hang onto its side, face-on to the camera.
func _slide_picture_off(u: float) -> void:
	var pic := _decor(PICTURE)
	if pic == null or not pic.is_inside_tree():
		return
	var ux := u * (2.0 - u)
	var at := Vector3(lerpf(_pic_from.x, _pic_to.x, ux), lerpf(_pic_from.y, _pic_to.y, u * u),
			lerpf(_pic_from.z, _pic_to.z, ux))
	var away := signf(_pic_to.x - _pic_from.x) if _pic_to.x != _pic_from.x else 1.0
	var tilt := lerpf(_pic_tilt_from, absf(PIC_FLOOR_TILT_DEG) * -away, u * u)
	pic.global_transform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(tilt)) * _pic_basis, at)


## The bonk's jolt swings the parlour picture on its hook (about its top edge) and leaves it askew: a damped
## swing (PIC_SWING_DEG at PIC_SWING_HZ) settling on PIC_ASKEW_DEG over PIC_SWING_S.
func _advance_pic_swing(f: float) -> void:
	if _pic_swing_t < 0.0:
		return
	var pic := _decor(PICTURE)
	if pic == null or _pic_phase != "" or not _pic_has_wall:
		_pic_swing_t = -1.0
		return
	_pic_swing_t += f / 60.0
	_pic_tilt = CueStager3D.picture_swing(_pic_swing_t)
	pic.transform = CueStager3D.hang_tilted(_pic_wall, _pic_tilt, _pic_hook_h())
	if _pic_swing_t >= PIC_SWING_S:
		_pic_swing_t = -1.0


## The picture's tilt (radians) `t` s after the bonk: 0 at the hit, a damped swing, settled askew.
static func picture_swing(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var settle := deg_to_rad(PIC_ASKEW_DEG) * (1.0 - exp(-t * 2.5))
	return settle + deg_to_rad(PIC_SWING_DEG) * exp(-t * 1.6) * sin(t * TAU * PIC_SWING_HZ)


## `wall` (the piece's local transform, origin = its bottom centre) turned `tilt` about the view axis round its hook,
## `hook_h` m above the origin.
static func hang_tilted(wall: Transform3D, tilt: float, hook_h: float) -> Transform3D:
	var hook := wall.origin + wall.basis.y.normalized() * hook_h
	var r := Basis(Vector3(0.0, 0.0, 1.0), tilt)
	return Transform3D(r * wall.basis, hook + r * (wall.origin - hook))


func _pic_hook_h() -> float:
	var h3: Variant = wv.set3d.get("house3d") if wv != null and wv.set3d != null else null
	var d: Dictionary = ((h3 as Dictionary).get("decor", {}) as Dictionary).get(PICTURE, {}) if h3 is Dictionary else {}
	var b: Array = d.get("box", [])
	return float(b[4]) * float(d.get("scale", 1.0)) if b.size() >= 6 else 0.56


## The picture's tilt now (radians; tests / the review).
func picture_tilt() -> float:
	return _pic_tilt


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
	if _shot != "relief" and _relief_spot != "":
		# the near-miss shot is over: her eyes are back up in the gap
		_duck_spot(_relief_spot, false)
		_relief_spot = ""
	# the curtain rises on HIM: until Hush starts her climb-in (P00) the camera frames him and the vase
	var pre := snap.hush.entering and snap.hush.oneshot != "enter" and snap.bellows.present
	if pre and _shot == "" and not _est_done:
		_est_done = true
		_start_shot("establish", _establish_focus(snap), 1.0, 1, 100000, EST_OUT_F)
	elif _shot == "establish" and not pre and _vase_react_wait < 0.0:
		_end_shot()
	# the near miss: he hunts right past her hiding spot
	if _shot == "" and not _relief_done and snap.bellows.activity == "hunt" and (snap.hush.state == "HIDDEN" or snap.hush.hidden_spot != ""):
		var eyes := _hidden_eyes(snap)
		var head := _bellows_head()
		if eyes != Vector3.INF and head != Vector3.INF and absf(eyes.x - head.x) <= RELIEF_NEAR_M:
			_start_shot("relief", _relief_focus(head, eyes), RELIEF_ZOOM, 14, 100000, 26)
			_relief_spot = snap.hush.hidden_spot
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
		"bonk", "picture", "vase_react":
			var h := _bellows_head()
			if h != Vector3.INF:
				c.set_gag_focus(_shot_id, h)
		"relief":
			var eyes2 := _hidden_eyes(snap)
			var head2 := _bellows_head()
			# the beat before the cue (his hunt runs out — it fires laugh_relief): he turns to peer at her gap, her
			# eyes sink out of sight as he does, then pop up when he turns away (the cue)
			var left := CueStager3D.hunt_left(snap.bellows)
			# Q2-G3: he glances at the gap (her eyes are there) ... looks away — her eyes duck — and SNAPS back: the
			# double take, held on an empty gap to the cue with his face to the Stalls
			_gaze_eyes = eyes2 if left <= RELIEF_GAZE_LEFT and left > RELIEF_TAKE_LEFT else Vector3.INF
			if not _relief_done and not _relief_take and left <= RELIEF_TAKE_LEFT and wv.bellows_view != null \
					and not snap.bellows.reacting:
				_relief_take = true
				wv.bellows_view.stage_hold(RELIEF_TAKE_CLIP, float(left) + 8.0)
			if not _relief_done and left <= RELIEF_DUCK_LEFT:
				_duck_spot(snap.hush.hidden_spot, true)
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
	var l := wv.layout.link_between("parlour", "kitchen")
	var x := float(l.x) / View3DConst.PX_PER_M if l != null else head.x
	var fdir := float(bv.get_facing())
	var edge := x - fdir * FLAT_HALF_M
	if wv.fx3d != null:
		# the contact, where his head meets the frame's edge: a white impact star in front of it, a plaster puff off
		# the edge, plaster sifting down from above, stars round his head
		wv.fx3d.burst("impact", Vector3(edge, head.y + 0.05, View3DConst.LANE_Z + 0.25), Vector3.UP)
		wv.fx3d.burst("bonk_dust", Vector3(edge, head.y, View3DConst.LANE_Z - 0.2), Vector3(-fdir, 0.4, 0.3))
		wv.fx3d.burst("plaster", Vector3(edge, head.y + 0.65, View3DConst.LANE_Z - 0.3), Vector3.DOWN)
		wv.fx3d.burst("bonk_stars", head + Vector3(0.0, 0.3, 0.0))
	# the jolt runs along the wall: the parlour picture swings on its hook and stays askew (it falls on him later)
	_pic_swing_t = 0.0 if _pic_phase == "" else -1.0
	# the frame itself takes the hit: the wing flat rocks on its base, away from him
	if _wing != null and is_instance_valid(_wing):
		_wing.transform = _wing_home
	_wing = wv.set3d.call("wing", l.id) as Node3D if l != null and wv.set3d != null and wv.set3d.has_method("wing") else null
	if _wing != null:
		_wing_home = _wing.transform
		_wing_t = 0.0
		_wing_dir = fdir


## The bonked wing flat rocks on its base (a damped WING_HZ wobble, WING_DEG at first, gone in WING_F frames), its top
## away from him.
func _advance_wing(f: float) -> void:
	if _wing == null:
		return
	if not is_instance_valid(_wing):
		_wing = null
		return
	_wing_t += f
	if _wing_t >= WING_F:
		_wing.transform = _wing_home
		_wing = null
		return
	var th := CueStager3D.wing_angle(_wing_t, _wing_dir)
	var half_h := (_wing as MeshInstance3D).get_aabb().size.y * 0.5 if _wing is MeshInstance3D else _wing_home.origin.y
	var t := _wing_home
	t.basis = Basis(Vector3(0.0, 0.0, 1.0), th) * _wing_home.basis
	# rotate about the base, not the centre: the floor end stays put
	t.origin.x = _wing_home.origin.x - half_h * sin(th)
	t.origin.y = _wing_home.origin.y - half_h + half_h * cos(th)
	_wing.transform = t


## The wing flat's wobble angle (radians) `t` frames after the bonk by a man facing `dir` (its top tips his way).
static func wing_angle(t: float, dir: float) -> float:
	if t < 0.0 or t >= WING_F:
		return 0.0
	var decay := exp(-t / (WING_F * 0.35))
	return deg_to_rad(WING_DEG) * decay * sin(t / 60.0 * TAU * WING_HZ) * signf(-dir if dir != 0.0 else 1.0)


## Q2-G6: the anticipation the other way. Blind (FRAZZLED) and walking at the parlour|kitchen door frame, WINDUP_F
## frames before he reaches it (his walk's ETA) he draws himself up and back (the staged wind-up overlay) while the
## bonk shot pushes in slowly; the cue keeps that shot (extend_gag), so no camera move starts near the hit.
func _advance_windup(snap: ViewSnapshot) -> void:
	if _windup_done or _bonk_t >= 0.0 or wv.bellows_view == null or wv.layout == null:
		return
	var b := snap.bellows
	if not b.present or not b.moving or b.reacting or not b.residues.has("FRAZZLED") or b.room != "kitchen":
		return
	var l := wv.layout.link_between("parlour", "kitchen")
	if l == null:
		return
	var eta := CueStager3D.eta_frames(b.x / View3DConst.PX_PER_M, float(l.x) / View3DConst.PX_PER_M, float(b.facing),
			b.speed_px_s / View3DConst.PX_PER_M)
	if eta < 0.0:
		return
	if not _bonk_lead_done and eta <= BONK_SHOT_LEAD_F:
		_bonk_lead_done = true
		_start_shot("bonk", _bellows_head(), BONK_ZOOM, WINDUP_PUSH_F, int(eta) + int(BONK_PIN_F) + BONK_HOLD_TAIL_F, 24,
				5.0 * float(b.facing if b.facing != 0 else -1))
	if eta <= WINDUP_F:
		_windup_done = true
		wv.bellows_view.stage_overlay(WINDUP_CLIP, eta + 6.0)


## Frames until a walker at `x` (m) heading `dir` at `v` m/s reaches `target_x` (-1 when moving away or still).
static func eta_frames(x: float, target_x: float, dir: float, v: float) -> float:
	var d := (target_x - x) * signf(dir)
	if d < 0.0 or v <= 0.01:
		return -1.0
	return d / v * 60.0


## Q2-G5: the vase ovation, VASE_REACT_DELAY_F after the crash — the shot pushes in on him and he straightens his
## cravat with a haughty sniff to the Stalls (st_straighten_cravat, face to camera from its f14), held VASE_REACT_F.
func _advance_vase_react(f: float) -> void:
	if _vase_react_wait < 0.0:
		return
	_vase_react_wait -= f
	if _vase_react_wait >= 0.0:
		return
	_vase_react_wait = -1.0
	var bv := wv.bellows_view
	if bv == null or not bv.visible:
		return
	bv.stage_hold(VASE_REACT_CLIP, VASE_REACT_CLIP_F)
	_start_shot("vase_react", _bellows_head(), VASE_REACT_ZOOM, 16, VASE_REACT_F - 16, 22)


## Her relief on the near-miss cue: the eyes pop up and squeeze shut, sweat flies, and (RELIEF_PHEW_DELAY_S later)
## the "phew" puff rises from the gap.
func _phew(spot: String, snap: ViewSnapshot) -> void:
	var p: Object = wv.prop(spot) if spot != "" and wv.has_method("prop") else null
	if p != null and p.has_method("eyes_phew"):
		p.call("eyes_phew")
	else:
		_duck_spot(spot, false)
	if wv.fx3d != null and wv.hush_view != null:
		var eyes := _hidden_eyes(snap)
		var at := eyes if eyes != Vector3.INF else wv.hush_view.head_world()
		wv.fx3d.burst("sweat", at + Vector3(0.12, 0.15, 0.25), Vector3(0.5, 1.0, 0.2))
		wv.fx3d.burst("sweat", at + Vector3(-0.12, 0.15, 0.25), Vector3(-0.5, 1.0, 0.2))
	_phew_spot = spot
	_phew_n = 0
	_phew_t = RELIEF_PHEW_DELAY_S


func _phew_puff(spot: String) -> void:
	if wv.fx3d == null:
		return
	var p: Object = wv.prop(spot) if spot != "" and wv.has_method("prop") else null
	if p == null or not p.has_method("eyes_world"):
		return
	var at: Vector3 = p.call("eyes_world")
	wv.fx3d.burst("phew", at + Vector3(0.0, 0.2, 0.2), Vector3(0.15, 1.0, 0.25))
	if _phew_n == 0:
		# a second, bigger breath out (the "phew" reads as a puff, not a speck)
		_phew_n = 1
		_phew_t = RELIEF_PHEW2_S


## Ticks left of his hunt (999999 when he is not hunting): the relief cue fires as it runs out.
static func hunt_left(b: ViewSnapshot.Actor) -> int:
	if b.activity != "hunt" or b.activity_len <= 0:
		return 999999
	return maxi(0, b.activity_len - b.activity_t)


## The near miss: duck (or pop up) her eyes in hiding spot `spot`.
func _duck_spot(spot: String, on: bool) -> void:
	if spot == "" or wv == null or not wv.has_method("prop"):
		return
	var p: Object = wv.prop(spot)
	if p != null and p.has_method("eyes_duck"):
		p.call("eyes_duck", on)


## Where he looks during a cue shot (INF = his own gaze): her eyes in the gap while the near-miss two-shot holds,
## until the cue (then his smirk is to the camera).
func gaze_target() -> Vector3:
	if _shot_live and (_shot == "bonk" or _shot == "picture" or _shot == "vase_react") and wv != null \
			and wv.bellows_view != null:
		# a cue shot's close-up is a face beat: his face to the Stalls (D8), over any noise glance — the chin a little
		# UP (the frazzled bouffant of the bonk covers his eyes when the head is level or dips)
		return wv.bellows_view.head_world() + Vector3(0.0, CLOSEUP_GAZE_UP_M, 4.0)
	if _shot != "relief" or _relief_done:
		return Vector3.INF
	if _relief_take and wv != null and wv.bellows_view != null:
		# the double take is a face beat: to the Stalls (D8)
		return wv.bellows_view.head_world() + Vector3(0.0, -0.8, 4.0)
	return _gaze_eyes


## True while a cue shot holds a close-up on his face (the bonk, the picture, the vase ovation, the near-miss two-shot):
## his thought bubble steps out of it.
func wants_quiet_bubble() -> bool:
	return (_shot == "bonk" or _shot == "picture" or _shot == "vase_react" or _shot == "relief") and _shot_live


## Debug / tests: the vase / picture phases.
func vase_phase() -> String:
	return _vase_phase


func picture_phase() -> String:
	return _pic_phase
