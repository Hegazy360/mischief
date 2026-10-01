## CurtainBows3D — the curtain call's bows in 3D (brief r3d-night §4.3): a transparent SubViewport with its own small
## World3D (nothing but the two actors: the fallen 2D curtain is their backdrop) and a camera at the stage lip renders
## Hush (the bow: `hush/act_bow`) and Bellows (the band routine: `cc_wander_on` → `st_double_take` →
## `beat_slow_burn` → `st_bonk`, in his residues) and is composited in front of the red curtain on the curtain-call
## layer, under the roses, the title card and the valance (CurtainApron draws those on top). A missing clip falls
## back to `loco_idle` / `loco_walk` (counted in `missing`). It renders only while an actor is on.
## (Own World3D rather than the Night's shared one: the Gag Reel re-stages the house's characters at the same time.)
##
## Screen placement uses fractions of the screen: x 0..1, feet at FEET_Y; Hush at the apron's full size (≈ 54 % of
## the height), Bellows on the lower stage band further back (≈ 33 %).
class_name CurtainBows3D
extends TextureRect

const DIST := 5.5
const FOV := 30.0
const FEET_Y := 0.92
const BAND_Z := -4.5
const BAND_FEET_Y := 0.95
const FALLBACK := {"hush": ["hush/loco_idle", "hush/loco_walk"], "bellows": ["bellows/loco_idle", "bellows/loco_strut"]}

var vp: SubViewport = null
var cam: Camera3D = null
var hush: Node3D = null
var bellows: Node3D = null
var hush_on: bool = false
var bellows_on: bool = false
## Clips that were asked for but do not exist (the curtain call's fallbacks).
var missing: Dictionary = {}
## Test hook: the rigs are not built (headless tests of the placement maths).
var no_rigs: bool = false

var _clip := {"hush": "", "bellows": ""}
var _aspect: float = 20.0 / 9.0
var _cy: float = 0.0


func _init() -> void:
	name = "CurtainBows3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vp = SubViewport.new()
	vp.name = "BowsViewport"
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.name = "LipCamera"
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = FOV
	cam.near = 0.3
	cam.far = 30.0
	_cy = (FEET_Y - 0.5) * 2.0 * DIST * tan(deg_to_rad(FOV) * 0.5)
	cam.position = Vector3(0.0, _cy, DIST)
	vp.add_child(cam)
	visible = false


func _ready() -> void:
	var ws := get_window().size if is_inside_tree() else Vector2i(1200, 540)
	vp.size = Vector2i(maxi(64, ws.x), maxi(64, ws.y))
	_aspect = float(vp.size.x) / float(maxi(1, vp.size.y))
	texture = vp.get_texture()
	cam.current = true
	if not no_rigs:
		hush = _make_rig("hush", String(ViewKit.setting("hush_head", "")))
		bellows = _make_rig("bellows", "")


func _make_rig(id: String, variant: String) -> Node3D:
	var s: Variant = load("res://view3d/char/rig_player_3d.gd") if ResourceLoader.exists("res://view3d/char/rig_player_3d.gd") else null
	if not (s is Script):
		return null
	var r: Node3D = (s as Script).new()
	r.name = "Bow_" + id
	vp.add_child(r)
	if r.has_method("setup"):
		r.call("setup", id, variant)
	r.visible = false
	return r


## World point on the lip plane (z) for a screen x fraction and a feet y fraction (pure maths).
func lip_point(x_frac: float, feet_frac: float, z: float) -> Vector3:
	var d := DIST - z
	var half_h := d * tan(deg_to_rad(FOV) * 0.5)
	var x := (x_frac - 0.5) * 2.0 * half_h * _aspect
	var y := _cy - (feet_frac - 0.5) * 2.0 * half_h
	return Vector3(x, y, z)


## Play `clip` (its fallback when it does not exist) on actor `id`.
func _play(id: String, rig: Node3D, clip: String) -> void:
	if rig == null or _clip[id] == clip:
		return
	_clip[id] = clip
	var c := clip
	if not ClipMap.clip_exists3d(c):
		missing[c] = int(missing.get(c, 0)) + 1
		c = String((FALLBACK[id] as Array)[1 if clip.contains("walk") or clip.contains("wander") else 0])
		if not ClipMap.clip_exists3d(c):
			c = String((FALLBACK[id] as Array)[0])
	if rig.has_method("play") and ClipMap.clip_exists3d(c):
		rig.call("play", c, {"loop": true, "blend_in": 6})


## The clip actor `id` ("hush" / "bellows") plays now ("" while hidden) — the e2e clip coverage (r3d-integrate).
func current_clip(id: String) -> String:
	if (id == "hush" and not hush_on) or (id == "bellows" and not bellows_on):
		return ""
	return String(_clip.get(id, ""))


## Hush on the apron: x fraction, the clip (the walk-in or the bow), facing ±1 and cheat toward the camera.
func pose_hush(x_frac: float, clip: String, facing: int, cheat: float) -> void:
	hush_on = true
	if hush != null:
		hush.visible = true
		hush.position = lip_point(x_frac, FEET_Y, 0.0)
		_play("hush", hush, clip)
		hush.call("set_facing", facing, false)
		hush.call("set_cheat", cheat, 0.15)
	_update_render()


func hide_hush() -> void:
	hush_on = false
	if hush != null:
		hush.visible = false
	_update_render()


## Bellows on the lower band: x fraction, clip, facing, cheat; `residues` (the looks he ended the Night in) once.
func pose_bellows(x_frac: float, clip: String, facing: int, cheat: float) -> void:
	bellows_on = true
	if bellows != null:
		bellows.visible = true
		bellows.position = lip_point(x_frac, BAND_FEET_Y, BAND_Z)
		_play("bellows", bellows, clip)
		bellows.call("set_facing", facing, true)
		bellows.call("set_cheat", cheat, 0.2)
	_update_render()


## Put his residue looks on (the end-of-Night looks, CharacterView3D's rules).
func set_residues(residues: PackedStringArray) -> void:
	if bellows == null or not bellows.has_method("set_look"):
		return
	for r in CharacterView3D.rig_looks(residues, PackedStringArray(), false, ""):
		bellows.call("set_look", r, true)
	var slots := CharacterView3D.residue_slots(residues, false)
	for sl in slots:
		bellows.call("set_body_slot", String(sl), String(slots[sl]), &"residue")


func hide_bellows() -> void:
	bellows_on = false
	if bellows != null:
		bellows.visible = false
	_update_render()


## A tint tier on Bellows (the slow burn reddens him).
func set_bellows_tier(tier: int) -> void:
	if bellows != null and bellows.has_method("set_tint_tier"):
		bellows.call("set_tint_tier", tier)


func _update_render() -> void:
	var on := hush_on or bellows_on
	visible = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## An actor's head top on screen (logical px of this control) — the valance lands there.
func head_screen(id: String) -> Vector2:
	var rig := hush if id == "hush" else bellows
	var top := Vector3.ZERO
	if rig != null and rig.has_method("top_global") and rig.is_inside_tree():
		top = rig.call("top_global")
	elif rig != null:
		top = rig.position + Vector3(0.0, 1.7, 0.0)
	else:
		top = lip_point(0.5, BAND_FEET_Y, BAND_Z) + Vector3(0.0, 1.78, 0.0)
	var p := cam.unproject_position(top) if cam.is_inside_tree() else Vector2(vp.size) * 0.5
	var sz := size if size.x > 0.0 else Vector2(1920, 1080)
	return p * sz / Vector2(vp.size)
