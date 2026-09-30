## Prop3D — one hotspot's piece on tonight's set (a live prop, or a hotspot on stage as furniture): its model (the
## `.glb` of `house3d.json` or a SetPrims greybox of its silhouette family), the 2.5 px ink and 8 px verb-halo shells
## (live props only, visual layer 3 PROP_INK), the idle / armed / spent looks, the rig progress scrub, the red beret
## tag, verb glow, short trigger animations and the lend / return_home slide of set-piece hand-offs (R3D index §7.2,
## §7.10; REDESIGN_3D §4.1–§4.4).
##
## The node's transform is the prop frame (origin + yaw, `SetGeo.prop_xform`); its `Visual` child carries `scale`.
## Anchors (`anchor(kind)`) are the house3d.json anchors in world space. Animations only process while running.
class_name Prop3D
extends Node3D

const TAG_GLB := "res://art3d/chars/hush/tag_beret.glb"
const TAG_PALETTE := "res://art3d/chars/hush/palette_hush.png"
const TAG_SWING_S := 0.3
const WIGGLE_S := 0.6
const FPS := 60.0
const STATES: Array[StringName] = [&"idle", &"armed", &"spent", &"open"]
const PROPS_PALETTE := "res://art3d/props/palette_props.png"
## Per silhouette family: the part the rig scrubs [part, axis (prop frame), degrees at 100 %, offset at 100 %].
const RIG_POSE := {
	"squat_jar": ["lid", Vector3(0, 0, 1), 38.0, Vector3(0.0, 0.025, 0.0)],
	"round_kettle": ["lid", Vector3(0, 0, 1), 55.0, Vector3(0.0, 0.03, 0.0)],
	"tall_jar": ["lid", Vector3(0, 1, 0), 540.0, Vector3.ZERO],
	"gooseneck_tap": ["head", Vector3(0, 1, 0), 180.0, Vector3.ZERO],
	"tall_rounded_box": ["door_upper", Vector3(0, 1, 0), -75.0, Vector3.ZERO],
	"big_horn": ["lever", Vector3(1, 0, 0), -55.0, Vector3.ZERO],
	"fat_armchair": ["key", Vector3(0, 0, 1), 720.0, Vector3.ZERO],
	"candlestick_phone": ["handset", Vector3(0, 0, 1), 25.0, Vector3(0.02, 0.06, 0.0)],
	"oval_on_stand": ["pane", Vector3(0, 0, 1), 0.0, Vector3(0.0, 0.25, 0.12)],
	"tall_case_clock": ["hands", Vector3(0, 0, 1), -1080.0, Vector3.ZERO],
	"banded_crate": ["lid", Vector3(1, 0, 0), -70.0, Vector3.ZERO],
}
## Per family: the armed look beyond the "armed" marks part [part, axis, degrees, offset, scale].
const ARMED_POSE := {
	"squat_jar": [["lid", Vector3(0, 0, 1), 16.0, Vector3(0.012, 0.01, 0.0), 1.0]],
	"tall_jar": [["lid", Vector3(0, 1, 0), 25.0, Vector3.ZERO, 1.0]],
	"big_horn": [["lever", Vector3(1, 0, 0), -55.0, Vector3.ZERO, 1.0]],
	"tall_rounded_box": [["door_upper", Vector3(0, 1, 0), -4.0, Vector3.ZERO, 1.0]],
	"oval_on_stand": [["pane", Vector3(0, 0, 1), 0.0, Vector3.ZERO, 0.0]],
	"candlestick_phone": [["handset", Vector3(0, 0, 1), 0.0, Vector3.ZERO, 0.0]],
	"tall_case_clock": [["pendulum", Vector3(0, 0, 1), 12.0, Vector3.ZERO, 1.0]],
}

## The hotspot id (house.json).
var hotspot_id: String = ""
## Extra hotspot ids sharing this model (the merged fridge: shelf + door).
var zone_ids: PackedStringArray = PackedStringArray()
var room: String = ""
## "rig" | "take" | "hide" | "exit" | "door" | "stairs" (the verb colour).
var verb: String = "rig"
## True when interactive tonight (ink, halo, glow); false = on stage as furniture.
var live: bool = false
var entry: Dictionary = {}
var mats: SetMats = null

var _visual: Node3D = null
var _meshes: Array[MeshInstance3D] = []
var _shells: Array[MeshInstance3D] = []
var _parts: Dictionary = {}
var _part_rest: Dictionary = {}
var _anim_player: AnimationPlayer = null
var _skel: Skeleton3D = null
var _bones: Dictionary = {}
var _family: String = ""
var _palette: Texture2D = null
var _hidden_parts: Dictionary = {}
var _state: StringName = &"idle"
var _progress: float = 0.0
var _glow_color: Color = Color("#FFC838")
var _glow_amp: float = 0.0
var _tag: Node3D = null
var _tag_on: bool = false
var _tag_t: float = -1.0
var _wiggle_t: float = -1.0
var _anim: String = ""
var _anim_t: float = 0.0
var _anim_dur: float = 0.0
var _home_parent: Node = null
var _home_local: Transform3D = Transform3D.IDENTITY
var _lent_to: Node3D = null
var _slide_from: Transform3D = Transform3D.IDENTITY
var _slide_to: Transform3D = Transform3D.IDENTITY
var _slide_t: float = -1.0
var _slide_dur: float = 0.1
var _returning: bool = false
var _armed_nodes: Array[Node3D] = []
var _occupied: bool = false


## Builds the piece. `xf` = the prop frame (SetGeo.prop_xform); `p_live` = interactive tonight.
## `p_mats`: share a material group (a room's: furniture and dressing are one material per room); null = own
## group (live props: each has its own glow). `palette`: the palette texture of a .glb model (default: the props
## palette for hotspot props).
func setup(id: String, p_entry: Dictionary, xf: Transform3D, p_room: String, p_verb: String, p_live: bool,
		room_color: Color = Color(0.78, 0.71, 0.52), p_mats: SetMats = null, palette: Texture2D = null) -> void:
	hotspot_id = id
	name = id
	entry = p_entry
	room = p_room
	verb = p_verb
	live = p_live
	transform = xf
	mats = p_mats if p_mats != null else SetMats.new(id)
	if p_mats == null:
		mats.room_color = room_color
	_palette = palette
	_family = SetGeo.s(entry.get("silhouette", ""))
	_glow_color = verb_color(verb)
	_visual = Node3D.new()
	_visual.name = "Visual"
	var s := float(entry.get("scale", 1.0))
	_visual.scale = Vector3(s, s, s)
	add_child(_visual)
	var model := SetGeo.s(entry.get("model", ""))
	var built := false
	if model.begins_with("res://") and ResourceLoader.exists(model):
		built = _build_glb(model)
	if not built:
		_build_primitive()
	if live:
		_build_shells()
	if _skel == null:
		_build_armed_marks()
	set_process(false)
	_apply_state()


## Skeleton3D ignores bone poses set before it is inside the tree (no update is queued): re-apply the look once the
## piece is on stage.
func _enter_tree() -> void:
	if _skel != null:
		_apply_state.call_deferred()


## The verb colour (REDESIGN §3.7): rig gold, hide blue, take / exit cream.
static func verb_color(v: String) -> Color:
	match v:
		"hide":
			return Color("#5C9EFF")
		"take", "exit", "door", "stairs":
			return Color("#FFF4DB")
		_:
			return Color("#FFC838")


# --- building --------------------------------------------------------------------------------

func _build_glb(path: String) -> bool:
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return false
	inst.name = "Model"
	_visual.add_child(inst)
	var tex := _palette
	if tex == null and ResourceLoader.exists(PROPS_PALETTE):
		tex = load(PROPS_PALETTE) as Texture2D
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := tex
		if t == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var sm := mi.mesh.surface_get_material(0)
			if sm is BaseMaterial3D:
				t = (sm as BaseMaterial3D).albedo_texture
		mi.material_override = mats.tex_mat(t, &"prop" if live else &"set")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_meshes.append(mi)
		_parts[String(mi.name)] = mi
		_part_rest[String(mi.name)] = mi.transform
	for n in inst.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		if not _parts.has(String(nd.name)):
			_parts[String(nd.name)] = nd
			_part_rest[String(nd.name)] = nd.transform
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim_player = aps[0] as AnimationPlayer
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_skel = sks[0] as Skeleton3D
		for i in _skel.get_bone_count():
			_bones[_skel.get_bone_name(i)] = i
	return not _meshes.is_empty()


## True when this piece came from a .glb with no skeleton and no animation player (a static-merge candidate).
func is_static_glb() -> bool:
	return not _meshes.is_empty() and _skel == null and _anim_player == null and SetGeo.s(entry.get("model", "")).begins_with("res://")


## The piece's meshes (House3D's static merge reads them).
func static_meshes() -> Array[MeshInstance3D]:
	return _meshes


## Hides the visual (the piece was merged into its room's static mesh); the node, boxes and API stay.
func hide_visual() -> void:
	if _visual != null:
		_visual.visible = false


func _build_primitive() -> void:
	var fam := SetGeo.s(entry.get("silhouette", "box"))
	var m := SetGeo.s(entry.get("model", ""))
	if m.begins_with("primitive:"):
		fam = m.substr(10)
	var col := SetGeo.color(entry.get("color", null), Color(0.8, 0.6, 0.3))
	if not live:
		col = col.lerp(mats.room_color, 0.35)
	var lb := SetGeo.local_bounds(entry)
	_meshes = SetPrims.build(_visual, fam, lb, col, &"prop" if live else &"set", mats)
	for mi in _meshes:
		_parts[String(mi.name)] = mi
		_part_rest[String(mi.name)] = mi.transform


func _build_shells() -> void:
	var ink := mats.ink_mat(false)
	var halo := mats.halo_mat(_glow_color, false)
	var ink_root := Node3D.new()
	ink_root.name = "Ink"
	_visual.add_child(ink_root)
	for mi in _meshes:
		if mi.mesh == null:
			continue
		for pair in [[ink, "ink"], [halo, "halo"]]:
			var mat: Material = pair[0]
			if mat == null:
				continue
			var sh := MeshInstance3D.new()
			sh.name = "%s_%s" % [mi.name, pair[1]]
			sh.mesh = mi.mesh
			sh.material_override = mat
			sh.layers = 1 << 2
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(sh)
			if _skel != null:
				sh.skin = mi.skin
				sh.skeleton = sh.get_path_to(_skel)
			_shells.append(sh)


## The armed marks of a greybox (REDESIGN §4.3 AFTER, stand-ins until the .glb states land): pepper speckles on the
## jar rim, the squeaker's yellow tail, a blue spray rose, a spanner, a spring, a sausage, a magnifier handle, a
## kipper, a spring on the clock, footprints in the empty frame. Hidden unless armed.
func _build_armed_marks() -> void:
	if verb == "" or (not _parts.is_empty() and _anim_player != null):
		return
	var fam := SetGeo.s(entry.get("silhouette", ""))
	var lb := SetGeo.local_bounds(entry)
	var top := lb.position.y + lb.size.y
	var dark := mats.get_mat(Color("#2A2D36"), &"prop")
	var mark := Node3D.new()
	mark.name = "armed_marks"
	_visual.add_child(mark)
	match fam:
		"squat_jar":
			for i in 6:
				SetPrims._ball(mark, 0.012, Vector3(-0.05 + i * 0.02, 0.112, 0.07), dark)
		"round_kettle":
			SetPrims._ball(mark, 0.03, Vector3(lb.position.x + 0.01, 0.16, 0.0), mats.get_mat(Color("#FFD23F"), &"prop"))
		"gooseneck_tap":
			SetPrims._cyl(mark, 0.05, 0.02, 0.05, Vector3(lb.position.x + 0.02, lb.size.y * 0.66, 0.0), mats.get_mat(Color("#3D7BD9"), &"prop"))
		"tall_jar":
			SetPrims._box(mark, Vector3(0.02, 0.14, 0.01), Vector3(lb.position.x - 0.01, top - 0.08, 0.05), mats.get_mat(Color("#9AA3AD"), &"prop"))
		"fat_armchair":
			SetPrims._torus(mark, 0.06, 0.09, Vector3(0.0, 0.08, lb.position.z + lb.size.z), mats.get_mat(Color("#B8C0C8"), &"prop"), Vector3(0, 0, 90))
		"tall_rounded_box":
			SetPrims._capsule(mark, 0.03, 0.18, Vector3(lb.position.x + lb.size.x - 0.05, 1.3, lb.position.z + lb.size.z + 0.02), mats.get_mat(Color("#C45A4A"), &"prop"))
		"folded_broadsheet":
			SetPrims._cyl(mark, 0.012, 0.012, 0.09, Vector3(lb.position.x + lb.size.x, 0.08, 0.0), mats.get_mat(Color("#6B4A2E"), &"prop"), "", Vector3(0, 0, 70))
		"candlestick_phone":
			SetPrims._capsule(mark, 0.025, 0.14, Vector3(0.07, 0.19, 0.04), mats.get_mat(Color("#C9B06A"), &"prop"))
		"tall_case_clock":
			SetPrims._torus(mark, 0.03, 0.05, Vector3(lb.position.x + lb.size.x, 1.7, 0.1), mats.get_mat(Color("#B8C0C8"), &"prop"), Vector3(0, 90, 0))
		"oval_on_stand":
			SetPrims._box(mark, Vector3(0.1, 0.01, 0.16), Vector3(-0.08, 0.06, 0.0), dark)
			SetPrims._box(mark, Vector3(0.1, 0.01, 0.16), Vector3(0.08, 0.06, 0.0), dark)
		"big_horn":
			SetPrims._box(mark, Vector3(0.1, 0.06, 0.005), Vector3(0.02, 0.535, 0.143), mats.get_mat(Color("#E23B4E"), &"prop"))
	_armed_nodes.append(mark)


# --- state ---------------------------------------------------------------------------------------

## The look: &"idle" | &"armed" (the prank is set: its armed marks show) | &"spent" (the joke used up: glow off, a
## tired look) | &"open" (doors). Idempotent.
func set_state(s: StringName) -> void:
	if not STATES.has(s):
		push_warning("Prop3D %s: unknown state %s" % [hotspot_id, s])
		return
	if s == _state:
		return
	_state = s
	_apply_state()


func state() -> StringName:
	return _state


func _apply_state() -> void:
	for n in _armed_nodes:
		n.visible = _state == &"armed" or _state == &"spent"
	for k in _parts.keys():
		var p: Node3D = _parts[k]
		var ks := String(k)
		if ks.begins_with("state_armed") or ks.ends_with("_armed"):
			p.visible = _state == &"armed"
		elif ks.begins_with("state_spent") or ks.ends_with("_spent"):
			p.visible = _state == &"spent"
		elif ks.begins_with("state_idle") or ks.ends_with("_idle"):
			p.visible = _state == &"idle"
	_reset_parts()
	var shown := _state == &"armed" or _state == &"spent"
	_pose_part("armed", Vector3.UP, 0.0, Vector3.ZERO, 1.0 if shown else 0.0)
	if shown:
		for pose in ARMED_POSE.get(_family, []):
			_pose_part(String(pose[0]), pose[1], float(pose[2]), pose[3], float(pose[4]))
	elif _progress > 0.0:
		_apply_rig_pose()
	for h in _hidden_parts.keys():
		_pose_part(String(h), Vector3.UP, 0.0, Vector3.ZERO, 0.0)
	mats.set_spent(_state == &"spent")
	if _state == &"spent":
		set_glow(_glow_color, 0.0)


## Scrubs the prop's `rig` animation while Hush works (0…1): the lid lifting, the lever travelling to ×3, the key
## winding (RIG_POSE per silhouette family; a .glb AnimationPlayer "rig" clip wins when present).
func set_rig_progress(frac: float) -> void:
	_progress = clampf(frac, 0.0, 1.0)
	if _anim_player != null and _anim_player.has_animation("rig"):
		var a := _anim_player.get_animation("rig")
		if _anim_player.current_animation != "rig":
			_anim_player.play("rig")
			_anim_player.pause()
		_anim_player.seek(_progress * a.length, true)
		return
	if _state == &"idle":
		_apply_rig_pose()


func _apply_rig_pose() -> void:
	var rp: Array = RIG_POSE.get(_family, [])
	if rp.is_empty():
		return
	_pose_part(String(rp[0]), rp[1], float(rp[2]) * _progress, (rp[3] as Vector3) * _progress, 1.0)


# --- parts (bones of a skinned .glb, or the greybox's part meshes) -------------------------------------

## Poses a part relative to its rest: a rotation of `deg` about `axis` (prop frame) at its pivot, an offset and a
## uniform scale (0 hides it). Returns false when the prop has no such part.
func _pose_part(part: String, axis: Vector3, deg: float, offset: Vector3 = Vector3.ZERO, s: float = 1.0) -> bool:
	var r := Basis(axis.normalized(), deg_to_rad(deg)) if absf(deg) > 1e-5 else Basis()
	if _skel != null and _bones.has(part):
		var i: int = _bones[part]
		var g_rest := _skel.get_bone_global_rest(i)
		var g := Transform3D(r * g_rest.basis * Basis.from_scale(Vector3.ONE * maxf(s, 0.0001)), g_rest.origin + offset)
		var par := _skel.get_bone_parent(i)
		var local := g if par < 0 else _skel.get_bone_global_pose(par).affine_inverse() * g
		_skel.set_bone_pose_position(i, local.origin)
		_skel.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
		_skel.set_bone_pose_scale(i, Vector3.ONE * maxf(s, 0.0001))
		return true
	var n: Node3D = _parts.get(part, null)
	if n == null or not _part_rest.has(part):
		return false
	var rest: Transform3D = _part_rest[part]
	n.transform = Transform3D(r * rest.basis, rest.origin + offset)
	n.visible = s > 0.001
	return true


func _reset_parts() -> void:
	if _skel != null:
		_skel.reset_bone_poses()
		return
	for k in _part_rest.keys():
		var n: Node3D = _parts.get(k, null)
		if n != null:
			n.transform = _part_rest[k]


## True when the prop has this part (a bone or a greybox part mesh).
func has_part(part: String) -> bool:
	return (_skel != null and _bones.has(part)) or _parts.has(part)


func rig_progress() -> float:
	return _progress


## Verb glow (prop_toon pulse + the halo shell): `amp` 0 off, 1 normal, 2 the active spot. Idempotent.
func set_glow(col: Color, amp: float) -> void:
	_glow_color = col
	_glow_amp = amp if _state != &"spent" else 0.0
	if not live:
		_glow_amp = 0.0
	mats.set_glow(_glow_color, _glow_amp, float(hotspot_id.hash() % 628) / 100.0)


func glow_amp() -> float:
	return _glow_amp


## Room light for this prop (House3D.set_room_light pushes it).
func set_light(level: float, p_desat: float) -> void:
	mats.set_light(level, p_desat)


# --- the red beret tag ---------------------------------------------------------------------------

## Hangs Hush's calling card at `tag_socket` (a 0.3 s swing-in when animated). Idempotent.
func show_tag(on: bool, animate: bool = true) -> void:
	if on == _tag_on:
		return
	_tag_on = on
	if on:
		if _tag == null:
			_tag = _make_tag()
			add_child(_tag)
		_tag.position = SetGeo.vec3(entry.get("tag_socket", [0.0, 0.1, 0.1])) * float(entry.get("scale", 1.0))
		_tag.visible = true
		_tag_t = 0.0 if animate else -1.0
		_tag.rotation = Vector3(0, 0, deg_to_rad(70.0) if animate else 0.0)
		_wake()
	elif _tag != null:
		_tag.visible = false
		_tag_t = -1.0
		_wiggle_t = -1.0


func tag_shown() -> bool:
	return _tag_on


## The TRIGGER anticipation: the tag wiggles (0.6 s).
func tag_wiggle() -> void:
	if not _tag_on:
		return
	_wiggle_t = 0.0
	_wake()


func _make_tag() -> Node3D:
	var root := Node3D.new()
	root.name = "Tag"
	if ResourceLoader.exists(TAG_GLB):
		var ps := load(TAG_GLB) as PackedScene
		if ps != null:
			var inst := ps.instantiate() as Node3D
			if inst != null:
				root.add_child(inst)
				# the cast's convention: palette UVs into Hush's own palette (r3d-cast-hush) — the glb carries no
				# texture, so give it that palette (else its vertex colours render black) + the prop ink shell
				var pal: Texture2D = load(TAG_PALETTE) as Texture2D if ResourceLoader.exists(TAG_PALETTE) else null
				var ink := mats.ink_mat(false)
				for n in inst.find_children("*", "MeshInstance3D", true, false):
					var mi := n as MeshInstance3D
					if pal != null:
						mi.material_override = mats.tex_mat(pal, &"prop")
					else:
						SetMats.warm(mi.get_active_material(0), &"prop")
					if ink != null and mi.mesh != null:
						var sh := MeshInstance3D.new()
						sh.name = "%s_ink" % mi.name
						sh.mesh = mi.mesh
						sh.material_override = ink
						sh.layers = 1 << 2
						sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						mi.add_child(sh)
						if mi.skin != null and not mi.skeleton.is_empty():
							# the shell is the mesh's child: its skeleton path is one level further up
							sh.skin = mi.skin
							sh.skeleton = NodePath("../" + String(mi.skeleton))
				return root
	var red := mats.get_mat(Color("#E23B4E"), &"prop")
	SetPrims._ball(root, 0.14, Vector3(0.0, -0.2, 0.0), red, Vector3(1.0, 0.42, 1.0), "beret")
	SetPrims._cyl(root, 0.012, 0.012, 0.05, Vector3(0.0, -0.15, 0.0), red, "stalk")
	SetPrims._cyl(root, 0.004, 0.004, 0.16, Vector3(0.0, -0.08, 0.0), mats.get_mat(Color("#FFF6EA"), &"prop"), "string")
	return root


# --- trigger / decor animations ---------------------------------------------------------------

## Plays a trigger / hide animation (`lid_flip`, `play`, `nudge`, `smash`, `fall`, `wobble`, `close`, `breathe`,
## `burst`, `open`, `spray` …): the .glb's AnimationPlayer clip when it has one, else a procedural stand-in.
func play(anim: String) -> void:
	var real := SetGeo.s((entry.get("anims", {}) as Dictionary).get(anim, anim)) if typeof(entry.get("anims", null)) == TYPE_DICTIONARY else anim
	if _anim_player != null and _anim_player.has_animation(real):
		_anim_player.play(real)
		return
	_anim = real
	_anim_t = 0.0
	_anim_dur = 0.5 if real != "breathe" else 2.0
	_wake()


func playing() -> String:
	return _anim


## Shows / hides a named part (the pepper pot while Hush holds hers). Unknown parts are ignored.
func set_part(part: String, on: bool) -> void:
	if on:
		_hidden_parts.erase(part)
	else:
		_hidden_parts[part] = true
	if _skel != null and _bones.has(part):
		_apply_state()
		return
	for k in _parts.keys():
		if String(k) == part or String(k).begins_with(part + "_"):
			(_parts[k] as Node3D).visible = on


## True when a part is visible (tests).
func part_visible(part: String) -> bool:
	if not has_part(part):
		return false
	return not _hidden_parts.has(part)


## Hiding spots override (HideSpot3D); a plain prop has no occupant.
func set_occupied(on: bool) -> void:
	_occupied = on


func occupied() -> bool:
	return _occupied


func eyes_look(_dir: Vector2) -> void:
	pass


func eyes_blink() -> void:
	pass


# --- anchors ------------------------------------------------------------------------------------

## A house3d.json anchor in world space: &"preview" &"tag" &"ring" &"item" &"eyes" &"reach"; &"origin" the prop frame.
func anchor(kind: StringName) -> Vector3:
	var key := SetGeo.s({&"preview": "preview_anchor", &"tag": "tag_socket", &"ring": "ring_anchor", &"item": "item_anchor",
		&"eyes": "eyes_anchor", &"reach": "reach_target"}.get(kind, ""))
	var home := _home_xform()
	if key == "" or entry.get(key, null) == null:
		return home.origin
	return home.origin + home.basis * (SetGeo.vec3(entry[key]) * float(entry.get("scale", 1.0)))


## The world AABB of the visual at home (SetGeo bounds).
func home_aabb() -> AABB:
	return SetGeo.world_aabb(_home_xform(), entry)


func _home_xform() -> Transform3D:
	if _lent_to == null and not (_returning and _slide_t >= 0.0):
		return global_transform if is_inside_tree() else transform
	if _home_parent is Node3D and (_home_parent as Node3D).is_inside_tree():
		return (_home_parent as Node3D).global_transform * _home_local
	return _home_local


# --- lend / return (set-piece hand-offs, index §7.2) ------------------------------------------

## Slides the piece into `to` (a socket node) over `frames` (60 fps), keeping its state, armed look, tag and
## particles. The world transform is unchanged on the first frame (no pop).
func lend(to: Node3D, frames: int = 6) -> void:
	if to == null:
		return
	if _lent_to == null:
		_home_parent = get_parent()
		_home_local = transform
	_lent_to = to
	_returning = false
	if is_inside_tree() and to.is_inside_tree():
		reparent(to, true)
	else:
		var g := _home_xform()
		if get_parent() != null:
			get_parent().remove_child(self)
		to.add_child(self)
		transform = to.global_transform.affine_inverse() * g if to.is_inside_tree() else g
	_slide_from = transform
	_slide_to = Transform3D.IDENTITY
	_start_slide(frames)


## Slides the piece back to its home over `frames`, then re-parents it there.
func return_home(frames: int = 6) -> void:
	if _lent_to == null or _home_parent == null:
		return
	if is_inside_tree() and (_home_parent as Node).is_inside_tree():
		reparent(_home_parent, true)
	else:
		if get_parent() != null:
			get_parent().remove_child(self)
		_home_parent.add_child(self)
	_lent_to = null
	_returning = true
	_slide_from = transform
	_slide_to = _home_local
	_start_slide(frames)


func is_lent() -> bool:
	return _lent_to != null


func _start_slide(frames: int) -> void:
	_slide_dur = maxf(1.0, float(frames)) / FPS
	_slide_t = 0.0
	if frames <= 0:
		_slide_t = -1.0
		transform = _slide_to
		return
	_wake()


# --- processing (only while something runs) --------------------------------------------------

func _wake() -> void:
	set_process(true)


func _process(delta: float) -> void:
	advance(delta)


## Steps every running animation by `dt` seconds (the tree calls it through _process; tests call it directly).
func advance(dt: float) -> void:
	var busy := false
	if _slide_t >= 0.0:
		_slide_t += dt
		var k := clampf(_slide_t / _slide_dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		transform = _slide_from.interpolate_with(_slide_to, e)
		if k >= 1.0:
			_slide_t = -1.0
			transform = _slide_to
			_returning = false
		else:
			busy = true
	if _tag != null and _tag_t >= 0.0:
		_tag_t += dt
		var kt := clampf(_tag_t / TAG_SWING_S, 0.0, 1.0)
		_tag.rotation.z = deg_to_rad(70.0) * (1.0 - kt) * cos(kt * 7.0)
		if kt >= 1.0:
			_tag_t = -1.0
			_tag.rotation.z = 0.0
		else:
			busy = true
	if _tag != null and _wiggle_t >= 0.0:
		_wiggle_t += dt
		var kw := clampf(_wiggle_t / WIGGLE_S, 0.0, 1.0)
		_tag.rotation.z = deg_to_rad(16.0) * sin(kw * TAU * 3.0) * (1.0 - kw)
		if kw >= 1.0:
			_wiggle_t = -1.0
			_tag.rotation.z = 0.0
		else:
			busy = true
	if _anim != "":
		_anim_t += dt
		_run_anim(clampf(_anim_t / _anim_dur, 0.0, 1.0))
		if _anim_t >= _anim_dur:
			_finish_anim()
		else:
			busy = true
	if _occupied_busy():
		busy = true
	if not busy:
		set_process(false)


func _occupied_busy() -> bool:
	return false


## A procedural stand-in for the named animation at phase k (0…1): bones / part meshes when the prop has the part,
## else the whole visual.
func _run_anim(k: float) -> void:
	var v := _visual
	var a := sin(k * PI)
	match _anim:
		"lid_flip", "lid_pop", "lid_up":
			_pose_part("lid", Vector3(0, 0, 1) if _anim != "lid_up" else Vector3(1, 0, 0), 120.0 * a, Vector3(0, 0.06 * a, 0))
		"wobble", "shake":
			v.rotation.z = deg_to_rad(6.0) * sin(k * TAU * 3.0) * (1.0 - k)
		"nudge":
			v.position.x = -0.05 * k
		"fall":
			v.position.y = -2.4 * k * k
			v.rotation.z = deg_to_rad(40.0) * k
		"smash":
			v.visible = k < 0.2
		"play":
			_pose_part("horn", Vector3(0, 1, 0), 8.0 * sin(k * TAU * 4.0))
		"spray":
			_pose_part("head", Vector3(0, 0, 1), 25.0 * sin(k * TAU * 5.0) * (1.0 - k))
		"ring":
			_pose_part("handset", Vector3(0, 0, 1), 12.0 * sin(k * TAU * 8.0), Vector3(0, 0.02 * a, 0))
		"avalanche", "door_open", "door_strain":
			_pose_part("door_upper" if _anim != "door_open" else "door_lower", Vector3(0, 1, 0), -95.0 * a)
		"close":
			if not _pose_part("curtain", Vector3(1, 0, 0), 18.0 * sin(k * TAU * 1.5) * (1.0 - k)):
				_pose_part("door", Vector3(0, 1, 0), -70.0 * (1.0 - k))
		"burst":
			if not _pose_part("curtain", Vector3(1, 0, 0), -55.0 * a):
				_pose_part("door", Vector3(0, 1, 0), -100.0 * a)
		"breathe":
			_pose_part("curtain", Vector3(0, 1, 0), 0.0, Vector3(0, 0, 0.012 * sin(k * TAU)), 1.0)
		"launch", "pogo":
			v.position.y = 0.25 * a
		"swing":
			v.rotation.z = deg_to_rad(10.0) * sin(k * TAU * 2.0) * (1.0 - k)
		"shatter":
			_pose_part("pane", Vector3.UP, 0.0, Vector3.ZERO, 1.0 - k)
		_:
			v.scale = Vector3.ONE * float(entry.get("scale", 1.0)) * (1.0 + 0.04 * a)


func _finish_anim() -> void:
	var done := _anim
	_anim = ""
	_anim_t = 0.0
	var s := float(entry.get("scale", 1.0))
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3(s, s, s)
	if done in ["launch", "pogo"]:
		_visual.position.y = 0.0
	if done == "nudge":
		_visual.position.x = 0.0
		position.x -= 0.05
		_home_local.origin.x -= 0.05
	if done != "fall" and done != "smash":
		_apply_state()


## Counts for the perf budget: {meshes, shells}.
func counts() -> Dictionary:
	return {"meshes": _meshes.size(), "shells": _shells.size()}
