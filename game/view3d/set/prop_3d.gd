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
const TAG_SWING_S := 0.3
const WIGGLE_S := 0.6
const FPS := 60.0
const STATES: Array[StringName] = [&"idle", &"armed", &"spent", &"open"]

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
func setup(id: String, p_entry: Dictionary, xf: Transform3D, p_room: String, p_verb: String, p_live: bool,
		room_color: Color = Color(0.78, 0.71, 0.52)) -> void:
	hotspot_id = id
	name = id
	entry = p_entry
	room = p_room
	verb = p_verb
	live = p_live
	transform = xf
	mats = SetMats.new(id)
	mats.room_color = room_color
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
	_build_armed_marks()
	set_process(false)
	_apply_state()


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
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var tex: Texture2D = null
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var sm := mi.mesh.surface_get_material(0)
			if sm is BaseMaterial3D:
				tex = (sm as BaseMaterial3D).albedo_texture
		mi.material_override = mats.tex_mat(tex, &"prop" if live else &"set")
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
	return not _meshes.is_empty()


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
			sh.skeleton = mi.skeleton
			sh.skin = mi.skin
			mi.add_child(sh)
			_shells.append(sh)


## The armed marks of a greybox (REDESIGN §4.3 AFTER, stand-ins until the .glb states land): pepper speckles on the
## jar rim, the squeaker's yellow tail, a blue spray rose, a spanner, a spring, a sausage, a magnifier handle, a
## kipper, a spring on the clock, footprints in the empty frame. Hidden unless armed.
func _build_armed_marks() -> void:
	if not _parts.is_empty() and _anim_player != null:
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
		n.visible = _state == &"armed"
	for k in _parts.keys():
		var p: Node3D = _parts[k]
		var ks := String(k)
		if ks.begins_with("state_armed") or ks.ends_with("_armed"):
			p.visible = _state == &"armed"
		elif ks.begins_with("state_spent") or ks.ends_with("_spent"):
			p.visible = _state == &"spent"
		elif ks.begins_with("state_idle") or ks.ends_with("_idle"):
			p.visible = _state == &"idle"
	var lid: Node3D = _parts.get("lid", null)
	if lid != null and _part_rest.has("lid"):
		var rest: Transform3D = _part_rest["lid"]
		lid.transform = rest
		if _state == &"armed":
			lid.transform = Transform3D(rest.basis.rotated(Vector3(0, 0, 1), deg_to_rad(14.0)), rest.origin + Vector3(0.01, 0.008, 0.0))
	mats.set_spent(_state == &"spent")
	if _state == &"spent":
		set_glow(_glow_color, 0.0)


## Scrubs the prop's `rig` animation while Hush works (0…1): the lid lifting, the lever travelling to ×3.
func set_rig_progress(frac: float) -> void:
	_progress = clampf(frac, 0.0, 1.0)
	if _anim_player != null and _anim_player.has_animation("rig"):
		var a := _anim_player.get_animation("rig")
		if _anim_player.current_animation != "rig":
			_anim_player.play("rig")
			_anim_player.pause()
		_anim_player.seek(_progress * a.length, true)
		return
	var lid: Node3D = _parts.get("lid", null)
	if lid != null and _part_rest.has("lid") and _state != &"armed":
		var r: Transform3D = _part_rest["lid"]
		lid.transform = Transform3D(r.basis.rotated(Vector3(0, 0, 1), deg_to_rad(25.0 * _progress)), r.origin + Vector3(0, 0.04 * _progress, 0))
	var lever: Node3D = _parts.get("lever", null)
	if lever != null and _part_rest.has("lever"):
		var r2: Transform3D = _part_rest["lever"]
		lever.transform = Transform3D(r2.basis.rotated(Vector3(0, 0, 1), deg_to_rad(-60.0 * _progress)), r2.origin)


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
				for n in inst.find_children("*", "MeshInstance3D", true, false):
					SetMats.warm((n as MeshInstance3D).get_active_material(0), &"prop")
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
	for k in _parts.keys():
		if String(k) == part or String(k).begins_with(part + "_") or String(k).begins_with(part):
			(_parts[k] as Node3D).visible = on


## True when a part is visible (tests).
func part_visible(part: String) -> bool:
	var p: Node3D = _parts.get(part, null)
	return p != null and p.visible


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


## A procedural stand-in for the named animation at phase k (0…1).
func _run_anim(k: float) -> void:
	var v := _visual
	match _anim:
		"lid_flip", "lid_pop":
			var lid: Node3D = _parts.get("lid", null)
			if lid != null and _part_rest.has("lid"):
				var r: Transform3D = _part_rest["lid"]
				var a := sin(k * PI)
				lid.transform = Transform3D(r.basis.rotated(Vector3(0, 0, 1), deg_to_rad(120.0) * a), r.origin + Vector3(0, 0.08 * a, 0))
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
			var horn: Node3D = _parts.get("horn", null)
			if horn != null:
				horn.rotation.y = TAU * k * 2.0
		_:
			v.scale = Vector3.ONE * float(entry.get("scale", 1.0)) * (1.0 + 0.04 * sin(k * TAU))


func _finish_anim() -> void:
	var done := _anim
	_anim = ""
	_anim_t = 0.0
	var s := float(entry.get("scale", 1.0))
	if done in ["wobble", "shake", "breathe", "close", "burst"]:
		_visual.rotation = Vector3.ZERO
		_visual.scale = Vector3(s, s, s)
	if done in ["lid_flip", "lid_pop"]:
		_apply_state()
	if done == "nudge":
		_visual.position.x = 0.0
		position.x -= 0.05
		_home_local.origin.x -= 0.05


## Counts for the perf budget: {meshes, shells}.
func counts() -> Dictionary:
	return {"meshes": _meshes.size(), "shells": _shells.size()}
