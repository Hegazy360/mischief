## CurtainBows3D — the curtain call's bows in 3D (brief r3d-night §4.3): a transparent SubViewport with its own small
## World3D (nothing but the two actors: the fallen 2D curtain is their backdrop) and a camera at the stage lip renders
## Hush (the bow: `hush/act_bow`) and Bellows (the band routine: `cc_wander_on` → `st_double_take` →
## `beat_slow_burn` → `st_bonk`, in his residues) and is composited in front of the red curtain on the curtain-call
## layer, under the roses, the title card and the valance (CurtainApron draws those on top). A missing clip falls
## back to `loco_idle` / `loco_walk` (counted in `missing`). It renders only while an actor is on.
## (Own World3D rather than the Night's shared one: the Gag Reel re-stages the house's characters at the same time.)
##
## Screen placement uses fractions of the screen: x 0..1, feet at FEET_Y; Hush at the apron's full size (≈ 54 % of
## the height), Bellows for his curtain-call bit nearer the lip than the old far band (BIT_Z: ≈ 46 % of the height,
## so his face reads at phone size while his head stays under the results' upper block — r3d QA2 Q2-G7).
class_name CurtainBows3D
extends TextureRect

const DIST := 5.5
const FOV := 30.0
const FEET_Y := 0.92
const BAND_Z := -4.5
const BAND_FEET_Y := 0.95
## Bellows' bit plane (Q2-G7): 1.4 m behind the lip — ≈ 46 % of the screen height (the far band was ≈ 32 %).
const BIT_Z := -1.4
const FALLBACK := {"hush": ["hush/loco_idle", "hush/loco_walk"], "bellows": ["bellows/loco_idle", "bellows/loco_strut"]}
## His bouffant (r3d polish: the pelmet must CONTACT it): the neat wig is skinned to the `bouffant` bone (its side
## lobes ride on it). From the build (tools/art3d/bellows/parts.py BOUFFANT_LOBES + skeleton.json): the crown lobe's
## top sits WIG_TOP_M above the bone's head along its axis (z 1.778 m = the `head_top` socket); the wig squashes about
## a pivot WIG_PIVOT_M below that head (near the scalp line, so its underside never lifts off his head). A body-slot
## variant (`bouffant_flipped` / `_frazzled` / `_wet` / `_floured`, rigid on Head) squashes about the same pivot and
## its top is its own mesh bounds.
const WIG_BONE := "bouffant"
const WIG_TOP_M := 0.296
const WIG_PIVOT_M := 0.15

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
## The wig squash (1 = none): the modifier on his skeleton, the bones, the variant holders + their own transforms,
## the pivot and each variant's top in Head space (built on first use).
var _wig_sy: float = 1.0
var _wig_mod: _WigSquash = null
var _wig_bone: int = -2
var _head_bone: int = -1
var _wig_atts: Array[Node3D] = []
var _wig_att_base: Array[Transform3D] = []
var _wig_att_top: PackedVector3Array = PackedVector3Array()
var _wig_pivot_head := Vector3.ZERO


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


## Play `clip` (its fallback when it does not exist) on actor `id`; `loop` false holds its last frame, `blend` frames
## (0 = a cut: the bonk's contact frame).
func _play(id: String, rig: Node3D, clip: String, loop: bool = true, blend: int = 6) -> void:
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
		rig.call("play", c, {"loop": loop, "blend_in": blend})


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


## Bellows on his bit plane (BIT_Z): x fraction, clip, facing, cheat (`loop` / `blend` as `_play`).
func pose_bellows(x_frac: float, clip: String, facing: int, cheat: float, loop: bool = true, blend: int = 6) -> void:
	bellows_on = true
	if bellows != null:
		bellows.visible = true
		bellows.position = lip_point(x_frac, BAND_FEET_Y, BIT_Z)
		_play("bellows", bellows, clip, loop, blend)
		bellows.call("set_facing", facing, true)
		bellows.call("set_cheat", cheat, 0.2)
	_update_render()


## Squash Bellows about his feet (the pelmet's hit drives him down): `sy` < 1 squashes, > 1 stretches; the width
## keeps his volume (1 / √sy).
func set_bellows_squash(sy: float) -> void:
	if bellows == null:
		return
	var y := maxf(0.2, sy)
	bellows.scale = Vector3(1.0 / sqrt(y), y, 1.0 / sqrt(y))


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
		bellows.scale = Vector3.ONE
	set_wig_squash(1.0)
	_update_render()


## Squash his bouffant (the pelmet sits on it): `sy` < 1 flattens it about the scalp line, the width keeps its volume
## (1 / √sy). The neat wig through a SkeletonModifier3D after the rig's own (springs included); a body-slot variant
## through its holder's transform.
func set_wig_squash(sy: float) -> void:
	var y := clampf(sy, 0.3, 1.5)
	if y == _wig_sy:
		return
	_wig_sy = y
	if bellows == null or not _wig_setup():
		return
	if _wig_mod != null:
		_wig_mod.sy = y
	var a := 1.0 / sqrt(y)
	var sq := Transform3D(Basis.from_scale(Vector3(a, y, a)), Vector3.ZERO)
	var about := Transform3D(Basis.IDENTITY, _wig_pivot_head) * sq * Transform3D(Basis.IDENTITY, -_wig_pivot_head)
	for i in _wig_atts.size():
		_wig_atts[i].transform = about * _wig_att_base[i]


## The wig squash now (1 = none).
func wig_squash() -> float:
	return _wig_sy


## Finds the bouffant bone, the Head bone, the squash pivot and the variant holders once (false without a rig).
func _wig_setup() -> bool:
	if _wig_bone != -2:
		return _wig_bone >= 0 or _head_bone >= 0
	_wig_bone = -1
	var sk: Skeleton3D = bellows.get("skeleton") if bellows != null else null
	if sk == null:
		return false
	_wig_bone = sk.find_bone(WIG_BONE)
	var hb := "Head"
	var dv: Variant = bellows.get("def")
	if dv is RigDef3D:
		hb = (dv as RigDef3D).bone("head", "Head")
	_head_bone = sk.find_bone(hb)
	if _wig_bone >= 0:
		_wig_mod = _WigSquash.new()
		_wig_mod.name = "CurtainWigSquash"
		_wig_mod.bone = _wig_bone
		_wig_mod.pivot = WIG_PIVOT_M
		_wig_mod.sy = _wig_sy
		sk.add_child(_wig_mod)
	if _head_bone >= 0 and _wig_bone >= 0:
		var piv := sk.get_bone_global_rest(_wig_bone) * Vector3(0.0, -WIG_PIVOT_M, 0.0)
		_wig_pivot_head = sk.get_bone_global_rest(_head_bone).affine_inverse() * piv
	for n in bellows.find_children("Att_bouffant*", "Node3D", true, false):
		var h := n as Node3D
		_wig_atts.append(h)
		_wig_att_base.append(h.transform)
		_wig_att_top.append(_att_top_head(h))
	return _wig_bone >= 0 or _head_bone >= 0


## A variant holder's crown in Head space: the top centre of its meshes' bounds (in its rest transform).
func _att_top_head(h: Node3D) -> Vector3:
	var have := false
	var box := AABB()
	for m in h.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := h.transform
		var n: Node = mi
		var chain := Transform3D.IDENTITY
		while n != null and n != h:
			if n is Node3D:
				chain = (n as Node3D).transform * chain
			n = n.get_parent()
		var b := (xf * chain) * mi.get_aabb()
		box = b if not have else box.merge(b)
		have = true
	if not have:
		return _wig_pivot_head + Vector3(0.0, WIG_TOP_M + WIG_PIVOT_M, 0.0)
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


## His wig's top in world space (squashed): the visible variant's bounds, else the neat crown on the `bouffant` bone,
## else the `head_top` socket.
func wig_top_world() -> Vector3:
	if bellows == null or not _wig_setup() or not bellows.is_inside_tree():
		return Vector3.INF
	var sk: Skeleton3D = bellows.get("skeleton")
	for i in _wig_atts.size():
		if _wig_atts[i].visible and _wig_atts[i].is_visible_in_tree() and _head_bone >= 0:
			var top := _wig_att_top[i]
			top = _wig_pivot_head + (top - _wig_pivot_head) * Vector3(1.0, _wig_sy, 1.0)
			return sk.global_transform * (sk.get_bone_global_pose(_head_bone) * top)
	if _wig_bone >= 0:
		var y := -WIG_PIVOT_M + (WIG_TOP_M + WIG_PIVOT_M) * _wig_sy
		return sk.global_transform * (sk.get_bone_global_pose(_wig_bone) * Vector3(0.0, y, 0.0))
	return Vector3.INF


## His wig's top on screen (logical px of this control; squashed) — the pelmet's contact line rests there. Without a
## rig: `head_screen` (the head_top socket / the descriptor height).
func wig_top_screen() -> Vector2:
	var w := wig_top_world()
	if not w.is_finite() or not cam.is_inside_tree():
		return head_screen("bellows")
	var sz := size if size.x > 0.0 else Vector2(1920, 1080)
	return cam.unproject_position(w) * sz / Vector2(vp.size)


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
		top = lip_point(0.5, BAND_FEET_Y, BIT_Z) + Vector3(0.0, 1.78, 0.0)
	var p := cam.unproject_position(top) if cam.is_inside_tree() else Vector2(vp.size) * 0.5
	var sz := size if size.x > 0.0 else Vector2(1920, 1080)
	return p * sz / Vector2(vp.size)


## Squashes the neat bouffant about its pivot (WIG_PIVOT_M below the `bouffant` bone's head, along the bone): scale
## (a, sy, a) in the bone's own axes, the position shifted so the pivot stays put. Runs after the rig's modifiers
## (added last under his skeleton); the skeleton restores the animated poses after skinning, so nothing accumulates.
class _WigSquash:
	extends SkeletonModifier3D
	var bone: int = -1
	var sy: float = 1.0
	var pivot: float = 0.15

	func _process_modification_with_delta(_delta: float) -> void:
		if bone < 0 or sy == 1.0:
			return
		var sk := get_skeleton()
		if sk == null:
			return
		var a := 1.0 / sqrt(sy)
		var s0 := sk.get_bone_pose_scale(bone)
		var r := sk.get_bone_pose_rotation(bone)
		var t := sk.get_bone_pose_position(bone)
		sk.set_bone_pose_position(bone, t + r * (s0 * Vector3(0.0, -pivot * (1.0 - sy), 0.0)))
		sk.set_bone_pose_scale(bone, s0 * Vector3(a, sy, a))
