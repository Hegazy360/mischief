## RigPlayer3D — the 3D character player (r3d-index §7.1): a skinned glTF on the UAL skeleton driven by baked
## clips (ruling R2) with the 2D player's contract — play / frame-lock / tiers / facing / faces / looks / props /
## clip events — on engine nodes:
##
## * **Tree:** `RigPlayer3D` (the view positions it) → `Body` (yaw = facing ± cheat-out; the view never touches it)
##   → the rig scene (`Armature/Skeleton3D` + the mesh) with the player's `RigMods3D`, a `LookAtModifier3D`, the
##   `RigGaze3D` (sidecar `gaze` windows: the face to the active camera, D8) and a `SpringBoneSimulator3D` under the
##   skeleton, `BoneAttachment3D`s for sockets and attachments; an
##   `AnimationTree` (manual callback) whose blend tree is two base slots cross-faded (`X`) + one masked overlay
##   (`M`, per-bone filters for `upper` / `head` / `arms`), each behind a `TimeSeek`.
## * **The clock is the player's own float** (timeline frames of a PlayPlan3D): every frame it seeks each slot to its
##   exact frame and advances the tree by 0, so a frame-locked clip (`set_external_frame`) shows exactly that frame
##   and nothing drifts. `auto_advance` (default on) steps from `_process`; the view may turn it off and call
##   `advance(view_dt)` with its own (hit-stopped) view time.
## * **Faces** go to the `char_toon` uniforms (`face_cell_a/b`, `face_rect[6]`, `face_grid`, `pupil_offset`) only when
##   they change; tint, stone, flash, rim, stage light likewise. The material is built at setup from the
##   descriptor (palette + face atlas), with the outline shader as `next_pass`, on visual layer 2 (CHAR).
## * **Events:** every sidecar event crossed this frame is emitted on `clip_event` (the dictionaries carry `clip`,
##   `rig`, `f`; consumers must not mutate them); `face`, `look`, `prop`, `jiggle` are also handled here; `prop`
##   events on `set:<id>` pieces are emitted only (the view lends them).
## A failed `setup()` shows a `CharStandIn3D` capsule and returns false; `counts()` reports missing clips and face
## misses. No per-frame allocation on the hot path.
class_name RigPlayer3D
extends Node3D

## Every sidecar event crossed this frame (sfx voice laugh fx face cam shake hitstop slowmo freeze prop mark decor
## set_anim set_part look jiggle), with "clip", "rig" and "f".
signal clip_event(ev: Dictionary)
## A non-looping clip reached its end (once per play).
signal clip_finished(clip_id: String)

const CHAR_SHADER := "res://art3d/shaders/char_toon.gdshader"
## Attachments built by the set / props pipelines (r3d-sets) keep their own look: the set shader + the palette the
## glb was built on (a room palette, or the props palette) — never the rig's palette.
const SET_SHADER := "res://art3d/shaders/set_toon.gdshader"
const PROP_SHADER := "res://art3d/shaders/prop_toon.gdshader"
const SET_ART := "res://art3d/set/"
const PROPS_ART := "res://art3d/props/"
const PROPS_PALETTE := "res://art3d/props/palette_props.png"
const HOUSE3D := "res://data/house/house3d.json"
const OUTLINE_SHADER := "res://art3d/shaders/outline.gdshader"
## Visual layer 2 = View3DConst.CHAR (bit value 2).
const CHAR_LAYER_BITS := 2
const TURN_FRAMES := 6
const REST_LIB := &"_rig"
const REST_ANIM := &"_rig/rest"
const P_SEEK_A := &"parameters/SA/seek_request"
const P_SEEK_B := &"parameters/SB/seek_request"
const P_SEEK_O := &"parameters/SO/seek_request"
const P_X := &"parameters/X/blend_amount"
const P_M := &"parameters/M/blend_amount"
const MASK_ROOTS := {"upper": ["spine_02"], "head": ["neck_01"], "arms": ["clavicle_l", "clavicle_r"]}
const LOOK_YAW_DEG := 35.0
const LOOK_PITCH_DEG := 20.0
const LOOK_EASE_S := 0.2
## Yaw shares of the runtime gaze chain (spine_02, spine_top, neck, head) — r3d-anim's `face_cam` FACE_SHARE.
const GAZE_SHARE: PackedFloat32Array = [0.15, 0.15, 0.25, 0.45]
## The bones screen_aabb() spans (with the head top).
const AABB_ROLES: PackedStringArray = ["hand_l", "hand_r", "foot_l", "foot_r", "pelvis", "head"]

## Step the clock from `_process` (the view may turn it off and call `advance(view_dt)` itself).
@export var auto_advance: bool = true

static var _house3d_cache: Dictionary = {}
static var _house3d_loaded: bool = false

var rig_id: String = ""
var variant: String = ""
var def: RigDef3D = null
var ok: bool = false
var body: Node3D = null
var rig_root: Node3D = null
var skeleton: Skeleton3D = null
var mesh: MeshInstance3D = null
var mat: ShaderMaterial = null
var outline_mat: ShaderMaterial = null
var tree: AnimationTree = null
var mods: RigMods3D = null
var look_mod: LookAtModifier3D = null
var gaze_mod: RigGaze3D = null
## Sidecar gaze windows turn the face to the camera (the view may switch it off, e.g. for a staged look elsewhere).
var gaze_enabled: bool = true
## Stats (tests, RigPerf3D): looks passes run since setup (a clip switch with unchanged looks runs none).
var looks_passes: int = 0
var jiggle: SpringBoneSimulator3D = null
var jiggle_clamp: RigJiggleClamp3D = null
var face: FaceCards3D = FaceCards3D.new()
var stand_in: CharStandIn3D = null
var facing: int = 1

var _mats: Array[ShaderMaterial] = []
var _att_mats: Array[ShaderMaterial] = []
var _set_mats: Array[ShaderMaterial] = []    ## set / props attachments (stage light + desat only)
var _libs: Dictionary = {}                   ## rig prefix -> AnimationLibrary
var _anim_a: AnimationNodeAnimation
var _anim_b: AnimationNodeAnimation
var _anim_o: AnimationNodeAnimation
var _blend_m: AnimationNodeBlend2
var _mask_name: String = ""

# base clock
var _plan: PlayPlan3D = null
var _clip: ClipDef3D = null
var _clip_id: String = ""
var _t: float = 0.0
var _ev_from: float = -1.0
var _speed: float = 1.0
var _rate: float = 1.0
var _finished: bool = false
var _external: bool = false
var _slot: int = 0                           ## 0 = slot A holds the current clip, 1 = slot B
var _old_clip: ClipDef3D = null
var _old_t: float = 0.0
var _xfade_f: float = 0.0
var _xfade_len: float = 0.0
var _tail_on: bool = false
var _release_f: float = -1.0

# overlay
var _ov_clip: ClipDef3D = null
var _ov_t: float = 0.0
var _ov_w: float = 0.0
var _ov_target: float = 0.0
var _ov_blend: float = 6.0
var _ov_ev_from: float = -1.0
var _ov_locked: bool = false

# facing / cheat
var _yaw_cur: float = 90.0
var _yaw_from: float = 90.0
var _turn_f: float = -1.0
var _cheat: float = 0.0
var _cheat_from: float = 0.0
var _cheat_to: float = 0.0
var _cheat_t: float = 1.0
var _cheat_s: float = 0.2

# looks, slots, props
var _looks_on := PackedStringArray()
var _slot_clip: Dictionary = {}              ## slot -> variant (clip-owned until _release_f)
var _slot_residue: Dictionary = {}           ## slot -> variant (explicit residue)
var _att_nodes: Dictionary = {}              ## attachment id -> Node3D (the holder)
var _att_forced: Dictionary = {}             ## attachment id -> bool (prop events on attachments)
var _param_defaults: Dictionary = {}         ## uniform -> original value (looks' params)
var _bone_att: Dictionary = {}               ## bone -> BoneAttachment3D
var _sock_nodes: Dictionary = {}             ## socket -> Node3D
var _prop_index: Dictionary = {}             ## prop id -> index into mods arrays
var _prop_state: Dictionary = {}             ## prop id -> state name
var _prop_forced: Dictionary = {}            ## prop id -> true when set at runtime
var _fly_launch_f := PackedFloat32Array()
var _fly_clip: Array[String] = []
var _fly_start: Array[Transform3D] = []
var _fly_vel := PackedVector3Array()
var _fly_spin := PackedFloat32Array()
var _fly_t := PackedFloat32Array()
var _flying := PackedInt32Array()            ## indices of props in flight

# material state
var _tier: int = 0
var _livid_specs: bool = false
var _stone: float = 0.0
var _stone_from: float = 0.0
var _stone_to: float = 0.0
var _stone_t: float = 1.0
var _stone_s: float = 0.1
var _flash: float = 0.0
var _flash_s: float = 0.0
var _outline_scale: float = 1.0
var _warm_frames: int = 0

# look-at
var _look_target: Node3D = null
var _look_w: float = 0.0
var _look_w_to: float = 0.0
var _look_point: Vector3 = Vector3.ZERO
var _gaze_cam: Camera3D = null
var _gaze_w: float = 0.0
var _kick_left: float = 0.0
var _last_applied_t: float = -INF
var _pose_dirty: bool = true

var _missing: Dictionary = {}                ## clip id -> count
var _events := []                            ## reused event buffer
var _pending := []                           ## events crossed this frame, emitted after the pose is applied
var _finished_id: String = ""
var _ov_events := []
var _pending_last_beat: String = ""
var _bone_cache: Dictionary = {}             ## role / bone name -> index
var _scale_bones_cache: Dictionary = {}      ## clip id -> PackedInt32Array (bones with scale tracks)
var _refreshing: bool = false

# prepared clips (prepare_clips / warm): play() then loads nothing, builds no Animation, adds nothing to a library
var _anim_names: Dictionary = {}             ## ClipDef3D -> StringName (its tree library entry "<rig>/<name>")
var _anim_objs: Dictionary = {}              ## ClipDef3D -> the Animation that entry holds (a hot reload re-adds)
var _plans: Dictionary = {}                  ## ClipDef3D -> PlayPlan3D: the plain plan, the clip's own loop mode
var _plans_flip: Dictionary = {}             ## ClipDef3D -> PlayPlan3D: the plain plan, loop mode flipped (opts.loop)

# looks, precomputed at setup (_build_look_fx): set_look / body slots swap cached nodes / params only
var _att_ids := PackedStringArray()          ## attachment index -> id (def.attachment_order)
var _att_index: Dictionary = {}              ## attachment id -> index
var _att_list: Array[Node3D] = []            ## attachment index -> holder (null when not built)
var _att_default := PackedByteArray()        ## attachment index -> visible by default
var _att_vis := PackedByteArray()            ## scratch: attachment index -> visible now
var _look_fx: Dictionary = {}                ## look id -> _LookFx
var _slot_ids := PackedStringArray()         ## slot index -> slot name
var _slot_fx: Array[Dictionary] = []         ## slot index -> {variant: _LookFx}
var _slot_clear: Array[PackedInt32Array] = []   ## slot index -> every attachment index any variant shows
var _slot_hide: Array[PackedInt32Array] = []    ## slot index -> bones hidden while a non-default variant shows
var _default_hidden := PackedInt32Array()    ## descriptor hidden_bones (indices)
var _look_hide := PackedInt32Array()         ## bones the looks / slots hide now (the looks pass fills it)
var _anim_mark := PackedByteArray()          ## scratch per bone: 1 = a playing clip keys its scale
var _params_now: Dictionary = {}             ## StringName -> value: the looks' uniforms set now
var _looks_dirty: bool = true                ## the looks / slots / forced attachments changed since the last pass
var _looks_props: bool = false               ## an on look shows / hides a bone prop (re-applied on every refresh)
var _aabb_bones := PackedInt32Array()        ## screen_aabb's bones (AABB_ROLES), resolved on first use
var _sock_bone: Dictionary = {}              ## socket -> bone index
var _prop_of_bone: Dictionary = {}           ## bone index -> the first bone prop riding it (index into mods arrays)


## One look or body-slot variant, resolved at setup: attachment indices it shows / hides, bone props it shows /
## hides, bones it hides, its uniforms (StringName -> converted value) and face cells.
class _LookFx extends RefCounted:
	var show_att := PackedInt32Array()
	var hide_att := PackedInt32Array()
	var show_props := PackedStringArray()
	var hide_props := PackedStringArray()
	var hide_bones := PackedInt32Array()
	var params: Dictionary = {}
	var face: Dictionary = {}


# --- setup ------------------------------------------------------------------------------------------------------

## Loads `data/rigs3d/<rig>/rig3d[_<variant>].json` + its scene. False (+ push_error, a stand-in capsule) on failure.
## Variant "" | "head_b" (R6); a "pip" skin request falls back to "" (R7).
func setup(p_rig_id: String, p_variant := "") -> bool:
	var d := RigDef3D.load(p_rig_id, p_variant)
	return setup_def(d)


## Sets up from an already loaded descriptor (tests, AnimViewer3D). `scene` overrides `def.scene_path`.
func setup_def(d: RigDef3D, scene: PackedScene = null) -> bool:
	_teardown()
	def = d
	rig_id = d.rig_id
	variant = d.variant
	name = name if name != "" else "Rig_%s" % rig_id
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	if not d.is_valid():
		for e in d.errors:
			push_error("RigPlayer3D(%s): %s" % [rig_id, e])
		_make_stand_in()
		return false
	var ps: PackedScene = scene if scene != null else ResourceLoader.load(d.scene_path) as PackedScene
	if ps == null:
		push_error("RigPlayer3D(%s): scene '%s' failed to load" % [rig_id, d.scene_path])
		_make_stand_in()
		return false
	rig_root = ps.instantiate() as Node3D
	if rig_root == null:
		push_error("RigPlayer3D(%s): scene root is not a Node3D" % rig_id)
		_make_stand_in()
		return false
	rig_root.name = "Rig"
	body.add_child(rig_root)
	skeleton = rig_root.get_node_or_null(NodePath(d.skeleton_path)) as Skeleton3D
	if skeleton == null:
		push_error("RigPlayer3D(%s): no skeleton at '%s'" % [rig_id, d.skeleton_path])
		_make_stand_in()
		return false
	for ap in rig_root.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).active = false
	mesh = rig_root.get_node_or_null(NodePath(d.mesh_path)) as MeshInstance3D if d.mesh_path != "" else null
	if mesh == null:
		mesh = _first_mesh(skeleton)
	_build_materials()
	_build_tree()
	_build_mods()
	_build_attachments()
	_build_look_at()
	_build_jiggle()
	_build_look_fx()
	# The modifiers (props, look-at, springs) run when the player advances, on the view's clock (a hit-stop freezes
	# the springs too); call advance() every frame (auto_advance does).
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	face.setup(d, hash(rig_id) & 0x7FFFFFFF)
	face.view_preset = d.face_default
	ok = true
	set_facing(1, false)
	_refresh_looks()
	_apply_pose(0.0)
	_push_face(0.0)
	return true


func _teardown() -> void:
	ok = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	body = null
	rig_root = null
	skeleton = null
	mesh = null
	tree = null
	mods = null
	look_mod = null
	gaze_mod = null
	jiggle = null
	jiggle_clamp = null
	stand_in = null
	_mats.clear()
	_att_mats.clear()
	_set_mats.clear()
	_libs.clear()
	_att_nodes.clear()
	_bone_att.clear()
	_sock_nodes.clear()
	_prop_index.clear()
	_prop_state.clear()
	_prop_forced.clear()
	_slot_clip.clear()
	_slot_residue.clear()
	_looks_on.clear()
	_bone_cache.clear()
	_anim_names.clear()
	_anim_objs.clear()
	_plans.clear()
	_plans_flip.clear()
	_att_list.clear()
	_look_fx.clear()
	_slot_fx.clear()
	_slot_clear.clear()
	_slot_hide.clear()
	_params_now.clear()
	_aabb_bones.clear()
	_sock_bone.clear()
	_att_index.clear()
	_scale_bones_cache.clear()
	_prop_of_bone.clear()
	_looks_dirty = true
	_looks_props = false
	_clip = null
	_plan = null
	_clip_id = ""
	_ov_clip = null


func _make_stand_in() -> void:
	stand_in = CharStandIn3D.new()
	var cols: Array = []
	if def != null and def.skins.get("stand_in", null) is Array:
		for c in def.skins["stand_in"]:
			cols.append(Color(String(c)))
	stand_in.build(rig_id, def.height_m if def != null else 1.6, cols)
	body.add_child(stand_in)


static func _first_mesh(n: Node) -> MeshInstance3D:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).mesh != null:
			return c as MeshInstance3D
	return null


static func _soft_shader(path: String, fallback: String) -> Shader:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Shader
	if fallback != "" and ResourceLoader.exists(fallback):
		return ResourceLoader.load(fallback) as Shader
	return null


func _build_materials() -> void:
	var sh := _soft_shader(CHAR_SHADER, "")
	var osh := _soft_shader(OUTLINE_SHADER, "")
	var pal: Texture2D = _tex(def.palette)
	var atlas: Texture2D = _tex(def.face_atlas)
	if mesh != null and mesh.mesh != null and (pal == null or atlas == null):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i)
			if m is BaseMaterial3D:
				if pal == null and (m as BaseMaterial3D).albedo_texture != null:
					pal = (m as BaseMaterial3D).albedo_texture
				if atlas == null and (m as BaseMaterial3D).emission_texture != null:
					atlas = (m as BaseMaterial3D).emission_texture
	if sh != null:
		mat = ShaderMaterial.new()
		mat.shader = sh
		mat.resource_name = "char_%s" % rig_id
		mat.set_shader_parameter("palette", pal)
		mat.set_shader_parameter("face_atlas", atlas)
		mat.set_shader_parameter("face_grid", def.face_grid)
		mat.set_shader_parameter("face_cell_a", Vector4i(-1, -1, -1, -1))
		mat.set_shader_parameter("face_cell_b", Vector4i(-1, -1, -1, -1))
		var rects := PackedVector4Array()
		for i in 6:
			rects.append(def.face_rects.get(RigDef3D.FACE_LAYERS[i], Vector4(0, 0, 1, 1)))
		mat.set_shader_parameter("face_rect", rects)
		mat.set_shader_parameter("pupil_offset", Vector2.ZERO)
		mat.set_shader_parameter("pupil_range", def.pupil_range)
		mat.set_shader_parameter("tint_color", Color(1, 1, 1, 0))
		mat.set_shader_parameter("stone", 0.0)
		mat.set_shader_parameter("stone_color", def.stone_color)
		mat.set_shader_parameter("flash", 0.0)
		mat.set_shader_parameter("rim", def.rim)
		mat.set_shader_parameter("stage_light", 1.0)
		mat.set_shader_parameter("desat", 0.0)
		mat.set_shader_parameter("vc_masks", mesh != null and _has_vertex_colors(mesh.mesh))
		if osh != null:
			outline_mat = ShaderMaterial.new()
			outline_mat.shader = osh
			outline_mat.resource_name = "outline_%s" % rig_id
			outline_mat.set_shader_parameter("outline_px", def.outline_px)
			mat.next_pass = outline_mat
		_mats.append(mat)
	for mi in rig_root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.layers = CHAR_LAYER_BITS
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat != null and m3.mesh != null:
			for i in m3.mesh.get_surface_count():
				m3.set_surface_override_material(i, mat)
	_register_warm(mat)


static func _has_vertex_colors(m: Mesh) -> bool:
	if m == null or m.get_surface_count() == 0:
		return false
	if m is ArrayMesh:
		return ((m as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
	return false


func _tex(p: String) -> Texture2D:
	if p == "":
		return null
	if ResourceLoader.exists(p):
		return ResourceLoader.load(p) as Texture2D
	if FileAccess.file_exists(p):
		var img := Image.load_from_file(p)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


func _register_warm(m: Material) -> void:
	if m == null:
		return
	var s := _soft_class("MaterialWarm3D")
	if s != null and s.has_method("register"):
		s.call("register", m, &"char")


## A global class by name (soft: the class may belong to a task that has not landed yet).
static func _soft_class(cls: String) -> Script:
	for e in ProjectSettings.get_global_class_list():
		if String(e.get("class", "")) == cls:
			var p := String(e.get("path", ""))
			return ResourceLoader.load(p) as Script if p != "" and ResourceLoader.exists(p) else null
	return null


func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = true
	add_child(tree)
	tree.root_node = tree.get_path_to(rig_root)
	var rest_lib := AnimationLibrary.new()
	var rest := Animation.new()
	rest.length = 1.0 / 60.0
	rest_lib.add_animation(&"rest", rest)
	tree.add_animation_library(REST_LIB, rest_lib)
	var bt := AnimationNodeBlendTree.new()
	_anim_a = AnimationNodeAnimation.new()
	_anim_a.animation = REST_ANIM
	_anim_b = AnimationNodeAnimation.new()
	_anim_b.animation = REST_ANIM
	_anim_o = AnimationNodeAnimation.new()
	_anim_o.animation = REST_ANIM
	bt.add_node(&"A", _anim_a)
	bt.add_node(&"B", _anim_b)
	bt.add_node(&"O", _anim_o)
	bt.add_node(&"SA", AnimationNodeTimeSeek.new())
	bt.add_node(&"SB", AnimationNodeTimeSeek.new())
	bt.add_node(&"SO", AnimationNodeTimeSeek.new())
	bt.add_node(&"X", AnimationNodeBlend2.new())
	_blend_m = AnimationNodeBlend2.new()
	_blend_m.filter_enabled = true
	bt.add_node(&"M", _blend_m)
	bt.connect_node(&"SA", 0, &"A")
	bt.connect_node(&"SB", 0, &"B")
	bt.connect_node(&"SO", 0, &"O")
	bt.connect_node(&"X", 0, &"SA")
	bt.connect_node(&"X", 1, &"SB")
	bt.connect_node(&"M", 0, &"X")
	bt.connect_node(&"M", 1, &"SO")
	bt.connect_node(&"output", 0, &"M")
	tree.tree_root = bt
	tree.active = true
	tree.set(P_X, 0.0)
	tree.set(P_M, 0.0)


func _build_mods() -> void:
	mods = RigMods3D.new()
	mods.name = "RigMods"
	skeleton.add_child(mods)
	var bones := PackedInt32Array()
	var i := 0
	for pid in def.prop_order:
		var pr: RigDef3D.Prop = def.props[pid]
		bones.append(skeleton.find_bone(pr.bone))
		_prop_index[pid] = i
		i += 1
	mods.setup_props(bones)
	_fly_launch_f.resize(i)
	_fly_clip.resize(i)
	_fly_start.resize(i)
	_fly_vel.resize(i)
	_fly_spin.resize(i)
	_fly_t.resize(i)
	for pid in def.prop_order:
		_set_prop_state(pid, (def.props[pid] as RigDef3D.Prop).default_state, false)
	var sb := PackedInt32Array()
	var names := def.tint_scale_bones
	if names.is_empty():
		for b in def.bone_names:
			if b.begins_with("sideburn"):
				names.append(b)
	for b in names:
		var bi := skeleton.find_bone(b)
		if bi >= 0:
			sb.append(bi)
	mods.scale_bones = sb


func _build_attachments() -> void:
	for aid in def.attachment_order:
		var at: RigDef3D.Attachment = def.attachments[aid]
		if at.soft and not ResourceLoader.exists(at.scene):
			continue
		var ps := ResourceLoader.load(at.scene) as PackedScene
		if ps == null:
			push_error("RigPlayer3D(%s): attachment '%s' scene '%s' failed to load" % [rig_id, aid, at.scene])
			continue
		var inst := ps.instantiate()
		var holder := Node3D.new()
		holder.name = "Att_%s" % aid
		var skinned := false
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).skin != null:
				skinned = true
		if skinned:
			# A skinned attachment shares the rig's bones: its meshes are re-bound to our skeleton.
			skeleton.add_child(holder)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				var m3 := mi as MeshInstance3D
				m3.get_parent().remove_child(m3)
				holder.add_child(m3)
				m3.skeleton = m3.get_path_to(skeleton)
			inst.free()
		else:
			var parent: Node3D = socket_node(at.socket) if at.socket != "" else _bone_attachment(at.bone)
			if parent == null:
				push_warning("RigPlayer3D(%s): attachment '%s' has no socket / bone '%s' on this rig" % [rig_id, aid,
					at.socket if at.socket != "" else at.bone])
				inst.free()
				holder.free()
				continue
			parent.add_child(holder)
			holder.position = at.pos
			holder.rotation_degrees = at.rot_deg
			holder.add_child(inst)
		var set_piece := at.scene.begins_with(SET_ART) or at.scene.begins_with(PROPS_ART)
		for mi2 in holder.find_children("*", "MeshInstance3D", true, false):
			var m4 := mi2 as MeshInstance3D
			m4.layers = CHAR_LAYER_BITS
			m4.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if m4.mesh == null:
				continue
			var am: Material = _set_piece_material(at, m4) if set_piece else (_attachment_material(m4) if mat != null else null)
			if am != null:
				for s in m4.mesh.get_surface_count():
					m4.set_surface_override_material(s, am)
		holder.visible = at.visible_default
		_att_nodes[aid] = holder


func _attachment_material(m4: MeshInstance3D) -> ShaderMaterial:
	var am := mat.duplicate() as ShaderMaterial
	am.resource_name = "char_%s_att" % rig_id
	am.set_shader_parameter("face_cell_a", Vector4i(-1, -1, -1, -1))
	am.set_shader_parameter("face_cell_b", Vector4i(-1, -1, -1, -1))
	var src: Material = m4.get_active_material(0) if m4.mesh.get_surface_count() > 0 else null
	if src is BaseMaterial3D:
		var bm := src as BaseMaterial3D
		if bm.albedo_texture != null:
			am.set_shader_parameter("palette", bm.albedo_texture)
		elif not bm.albedo_color.is_equal_approx(Color.WHITE):
			# A flat-coloured attachment: white palette × its colour.
			am.set_shader_parameter("palette", null)
			am.set_shader_parameter("albedo_color", bm.albedo_color)
		# else: a white, untextured material = the cast's convention (palette UVs into the rig's own palette, like the
		# body mesh): keep the rig palette.
	am.set_shader_parameter("vc_masks", _has_vertex_colors(m4.mesh))
	if outline_mat != null:
		am.next_pass = outline_mat
	_mats.append(am)
	_att_mats.append(am)
	return am


## A set / props glb riding on the rig (Bellows' kitchen stool): the set's own shader and palette, so it is the same
## stool as the one on the set (House3D draws furniture with set_toon on the room palette, live props with prop_toon
## on the props palette). No outline (set furniture has none) and none of the character's face / tint / stone state.
func _set_piece_material(at: RigDef3D.Attachment, m4: MeshInstance3D) -> Material:
	var props := at.scene.begins_with(PROPS_ART)
	var sh := _soft_shader(PROP_SHADER if props else SET_SHADER, "")
	var pal := _set_piece_palette(at, m4)
	if sh == null:
		var st := StandardMaterial3D.new()
		st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		st.albedo_texture = pal
		st.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return st
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.resource_name = "set_%s_att_%s" % [rig_id, at.id]
	if pal != null:
		sm.set_shader_parameter("palette", pal)
	sm.set_shader_parameter("stage_light", 1.0)
	sm.set_shader_parameter("desat", 0.0)
	_set_mats.append(sm)
	var s := _soft_class("MaterialWarm3D")
	if s != null and s.has_method("register"):
		s.call("register", sm, &"prop" if props else &"set")
	return sm


## The palette a set / props glb was built on: the descriptor's `palette`, else the glb's own texture, else (props/)
## the props palette, else (set/) the palette of the room house3d.json places that model in (a furniture / dressing /
## decor entry with the same `model`), else the room its file name starts with (kitchen_arch.glb → kitchen).
func _set_piece_palette(at: RigDef3D.Attachment, m4: MeshInstance3D) -> Texture2D:
	if at.palette != "":
		return _tex(at.palette)
	var src: Material = m4.get_active_material(0) if m4.mesh.get_surface_count() > 0 else null
	if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
		return (src as BaseMaterial3D).albedo_texture
	if at.scene.begins_with(PROPS_ART):
		return _tex(PROPS_PALETTE)
	var room := set_piece_room(at.scene)
	return _tex(room_palette(room)) if room != "" else null


## The room house3d.json places `model` in ("" when none): furniture / dressing / decor / hotspot entries with that
## `model` and a `room`, else the room its file name starts with.
static func set_piece_room(model: String) -> String:
	var h := _house3d()
	var rooms: Dictionary = h.get("rooms", {}) if h.get("rooms", {}) is Dictionary else {}
	for sec in ["furniture", "dressing", "decor", "hotspots"]:
		var v: Variant = h.get(sec, {})
		if not (v is Dictionary):
			continue
		for k in (v as Dictionary):
			var e: Variant = (v as Dictionary)[k]
			if not (e is Dictionary):
				continue
			var mv: Variant = (e as Dictionary).get("model", "")
			if mv is String and String(mv) == model and (e as Dictionary).get("room", null) is String:
				return String((e as Dictionary)["room"])
	var base := model.get_file()
	for r in rooms:
		if base.begins_with(String(r) + "_"):
			return String(r)
	return ""


## The palette path of `room` in house3d.json ("" when none).
static func room_palette(room: String) -> String:
	var rooms: Variant = _house3d().get("rooms", {})
	if rooms is Dictionary and (rooms as Dictionary).get(room, null) is Dictionary:
		return String(((rooms as Dictionary)[room] as Dictionary).get("palette", ""))
	return ""


static func _house3d() -> Dictionary:
	if not _house3d_loaded:
		_house3d_loaded = true
		if FileAccess.file_exists(HOUSE3D):
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(HOUSE3D)) == OK and j.data is Dictionary:
				_house3d_cache = j.data
	return _house3d_cache


func _build_look_at() -> void:
	var hb := def.bone("head", "Head")
	var hi := skeleton.find_bone(hb)
	if hi < 0:
		return
	look_mod = LookAtModifier3D.new()
	look_mod.name = "LookAt"
	skeleton.add_child(look_mod)
	look_mod.bone_name = hb
	# The bone-space axes closest to the model's forward (+Z) and up (+Y) at rest.
	var g := skeleton.get_bone_global_rest(hi).basis
	look_mod.forward_axis = _closest_axis(g.inverse() * Vector3(0, 0, 1))
	var up_axis := _closest_axis(g.inverse() * Vector3(0, 1, 0))
	look_mod.primary_rotation_axis = _rot_axis_of(up_axis)
	look_mod.use_secondary_rotation = true
	look_mod.use_angle_limitation = true
	look_mod.symmetry_limitation = true
	look_mod.primary_limit_angle = deg_to_rad(LOOK_YAW_DEG * 2.0)
	look_mod.secondary_limit_angle = deg_to_rad(LOOK_PITCH_DEG * 2.0)
	look_mod.primary_damp_threshold = 0.8
	look_mod.secondary_damp_threshold = 0.8
	look_mod.duration = 0.0
	_look_target = Node3D.new()
	_look_target.name = "LookTarget"
	add_child(_look_target)
	look_mod.target_node = look_mod.get_path_to(_look_target)
	look_mod.influence = 0.0
	look_mod.active = false
	_build_gaze(hi)


## The runtime gaze (after the look-at, before the springs): upper spine → neck → head of this rig.
func _build_gaze(head_i: int) -> void:
	var names := PackedStringArray()
	var st := skeleton.find_bone(def.bone("spine_top", "spine_03"))
	var sp := skeleton.get_bone_parent(st) if st >= 0 else -1
	names.append(skeleton.get_bone_name(sp) if sp >= 0 and skeleton.get_bone_name(sp).begins_with("spine") else "")
	names.append(skeleton.get_bone_name(st) if st >= 0 else "")
	names.append(def.bone("neck", "neck_01"))
	names.append(skeleton.get_bone_name(head_i))
	var bi := PackedInt32Array()
	var sh := PackedFloat32Array()
	for k in names.size():
		var b := skeleton.find_bone(names[k]) if names[k] != "" else -1
		if b >= 0 and not bi.has(b):
			bi.append(b)
			sh.append(GAZE_SHARE[k])
	gaze_mod = RigGaze3D.new()
	gaze_mod.name = "Gaze"
	skeleton.add_child(gaze_mod)
	gaze_mod.setup(bi, sh, skeleton.get_bone_global_rest(head_i))
	gaze_mod.active = false


static func _closest_axis(v: Vector3) -> int:
	var a := v.abs()
	if a.x >= a.y and a.x >= a.z:
		return SkeletonModifier3D.BONE_AXIS_PLUS_X if v.x >= 0.0 else SkeletonModifier3D.BONE_AXIS_MINUS_X
	if a.y >= a.z:
		return SkeletonModifier3D.BONE_AXIS_PLUS_Y if v.y >= 0.0 else SkeletonModifier3D.BONE_AXIS_MINUS_Y
	return SkeletonModifier3D.BONE_AXIS_PLUS_Z if v.z >= 0.0 else SkeletonModifier3D.BONE_AXIS_MINUS_Z


static func _rot_axis_of(bone_axis: int) -> int:
	match bone_axis:
		SkeletonModifier3D.BONE_AXIS_PLUS_X, SkeletonModifier3D.BONE_AXIS_MINUS_X:
			return SkeletonModifier3D.ROTATION_AXIS_X
		SkeletonModifier3D.BONE_AXIS_PLUS_Y, SkeletonModifier3D.BONE_AXIS_MINUS_Y:
			return SkeletonModifier3D.ROTATION_AXIS_Y
	return SkeletonModifier3D.ROTATION_AXIS_Z


func _build_jiggle() -> void:
	if def.jiggle.is_empty():
		return
	jiggle = SpringBoneSimulator3D.new()
	jiggle.name = "Jiggle"
	skeleton.add_child(jiggle)
	var chains: Array = []
	for g in def.jiggle:
		# A group whose bones form one parent chain is one setting; otherwise one setting per bone.
		var chain_ok := g.bones.size() > 1
		for k in range(1, g.bones.size()):
			if skeleton.get_bone_parent(skeleton.find_bone(g.bones[k])) != skeleton.find_bone(g.bones[k - 1]):
				chain_ok = false
		if chain_ok:
			chains.append([g, g.bones[0], g.bones[g.bones.size() - 1]])
		else:
			for b in g.bones:
				chains.append([g, b, b])
	jiggle.setting_count = chains.size()
	for i in chains.size():
		var g: RigDef3D.JiggleGroup = chains[i][0]
		jiggle.set_root_bone_name(i, String(chains[i][1]))
		jiggle.set_end_bone_name(i, String(chains[i][2]))
		jiggle.set_extend_end_bone(i, true)
		jiggle.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		jiggle.set_end_bone_length(i, g.tip_m)
		jiggle.set_stiffness(i, g.stiffness)
		jiggle.set_drag(i, g.drag)
		jiggle.set_gravity(i, g.gravity)
		jiggle.set_radius(i, g.radius)
	# The clamp (after the springs): every simulated bone of each group.
	var cb := PackedInt32Array()
	var cd := PackedFloat32Array()
	for g2 in def.jiggle:
		for b in g2.bones:
			var bi := skeleton.find_bone(b)
			if bi >= 0 and not cb.has(bi):
				cb.append(bi)
				cd.append(g2.clamp_deg)
	jiggle_clamp = RigJiggleClamp3D.new()
	jiggle_clamp.name = "JiggleClamp"
	skeleton.add_child(jiggle_clamp)
	jiggle_clamp.setup(cb, cd)
	mods.jiggle_clamp = jiggle_clamp


# --- playback ---------------------------------------------------------------------------------------------------

## Plays `clip_id` on the base layer. opts: blend_in (frames), speed, loop, start_frame, tier (1–3), suppressed,
## seed, hold, suppressed_clip, last_beat, t3_prop_f, t3_prop. An overlay clip is routed to `play_overlay()`.
func play(clip_id: String, opts := {}) -> void:
	if not ok:
		_count_missing(clip_id)
		return
	var c := ClipLib3D.get_clip(clip_id)
	if c == null:
		_count_missing(clip_id)
		return
	if c.layer == "overlay":
		play_overlay(clip_id, c.mask if c.mask != "" else "upper", int(opts.get("blend_in", c.blend_in)))
		return
	var anim_name := _ensure_anim(c)
	if anim_name == &"":
		_count_missing(clip_id)
	_end_clip_ownership()
	var prev := _clip
	var prev_t := _t
	_clip = c
	_clip_id = clip_id
	_plan = _plan_for(c, opts)
	_speed = float(opts.get("speed", 1.0))
	_rate = 1.0
	_t = clampf(float(opts.get("start_frame", 0.0)), 0.0, float(_plan.length))
	_ev_from = _t - 1.0
	_finished = false
	_external = false
	_tail_on = false
	_pending_last_beat = ""
	var rel := c.mark("release")
	_release_f = float(_plan.timeline_frame(rel)) if rel >= 0 else float(_plan.length)
	if _plan.suppressed and _plan.tail != null:
		_release_f = float(_plan.length)
	var blend := float(opts.get("blend_in", c.blend_in if c.has_blend_in else ClipDef3D.DEFAULT_BLEND))
	_start_base(anim_name if anim_name != &"" else REST_ANIM, prev, prev_t, blend if prev != null else 0.0)
	_refresh_looks()


## Plays `clip_id` as the masked overlay (micro-gags over walks): mask `upper` | `head` | `arms` | `face`.
func play_overlay(clip_id: String, mask := "upper", blend_f := 6) -> void:
	if not ok:
		_count_missing(clip_id)
		return
	var c := ClipLib3D.get_clip(clip_id)
	if c == null:
		_count_missing(clip_id)
		return
	_ov_clip = c
	_ov_t = 0.0
	_ov_ev_from = -1.0
	_ov_locked = false
	_ov_blend = maxf(0.0, float(blend_f))
	_ov_target = 1.0
	_pose_dirty = true
	if mask == "face":
		_ov_w = 0.0
		_mask_name = "face"
		return
	var an := _ensure_anim(c)
	if an == &"":
		_count_missing(clip_id)
		_ov_clip = null
		return
	_set_mask(mask)
	_anim_o.animation = an
	if _ov_blend <= 0.0:
		_ov_w = 1.0


## Fades the overlay out over `blend_f` frames.
func stop_overlay(blend_f := 6) -> void:
	_ov_locked = false
	_ov_target = 0.0
	_ov_blend = maxf(0.0, float(blend_f))
	_pose_dirty = true
	if _ov_blend <= 0.0:
		_ov_w = 0.0
		_ov_clip = null


## Frame-lock: show timeline frame `frame` of the current plan (reactions, one-shots, rig progress); no own clock
## until `release_external()`. Events between the previous locked frame and this one fire (forward only), after the
## pose of `frame` is applied (a launched prop leaves from where the hand is on that frame).
func set_external_frame(frame: float) -> void:
	if not ok or _plan == null:
		return
	_external = true
	var f := clampf(frame, 0.0, float(_plan.length))
	if f >= _ev_from:
		_collect(_ev_from, f)
	_ev_from = f
	_t = f
	_check_release()
	if not _finished and f >= float(_plan.length) and not _plan.loop:
		# The locked clip reached its end: finished once; a T3 last beat follows on the view clock.
		_finished = true
		_finished_id = _clip_id
		if _plan.last_beat != "" and ClipLib3D.exists(_plan.last_beat):
			_pending_last_beat = _plan.last_beat
	_apply_pose(0.0)
	_flush_events()


## Frame-lock of the overlay (sheets, the viewer): shows frame `frame` of the playing overlay at its full weight; the
## overlay's events between the previous locked frame and this one fire. `play_overlay` / `stop_overlay` unlock it.
func set_overlay_frame(frame: float) -> void:
	if not ok or _ov_clip == null:
		return
	_ov_locked = true
	var f := clampf(frame, 0.0, float(_ov_clip.length))
	if f >= _ov_ev_from:
		ClipEvents3D.between_into(_ov_clip, _ov_ev_from, f, _ov_events)
		_pending.append_array(_ov_events)
	_ov_ev_from = f
	_ov_t = f
	_ov_w = _ov_target
	_pose_dirty = true
	_apply_pose(0.0)
	_flush_events()


## The overlay clip id ("" = none) and its frame.
func current_overlay() -> String:
	return _ov_clip.id if _ov_clip != null else ""


func current_overlay_frame() -> float:
	return _ov_t


## Back to the player's own clock (continues from the locked frame).
func release_external() -> void:
	_external = false


## True while frame-locked.
func is_external() -> bool:
	return _external


## Playback speed for walk clips: rate = m_s / the clip's `speed_m_s` (stride preserved).
func set_speed(m_s: float) -> void:
	if _clip != null and _clip.speed_m_s > 0.0:
		_rate = maxf(0.0, m_s) / _clip.speed_m_s


## Advance the player by `view_dt` seconds of view time (called from `_process` when `auto_advance`): the clock,
## the pose, then this frame's events, look-at, face, material eases.
func advance(view_dt: float) -> void:
	if not ok:
		return
	var df := view_dt * 60.0
	_update_turn(df)
	_update_cheat(view_dt)
	if not _external and _plan != null:
		_step_clock(df)
	_step_overlay(df)
	_update_flying(view_dt)
	_apply_pose(view_dt)
	_flush_events()
	_update_gaze()
	_update_look(view_dt)
	skeleton.advance(view_dt)
	_push_face(df)
	_update_material(view_dt)
	if _pending_last_beat != "":
		var lb := _pending_last_beat
		_pending_last_beat = ""
		play(lb)


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func _step_clock(df: float) -> void:
	if _finished:
		return
	var prev := _t
	_t += df * _speed * _rate
	var n := float(_plan.length)
	if _plan.loop:
		if _t >= n:
			_t = fmod(_t, n)
			_collect(_ev_from, n)
			_ev_from = -1.0
		_collect(_ev_from, _t)
		_ev_from = _t
		return
	if _t >= n:
		_t = n
		_collect(_ev_from, n)
		_ev_from = n
		_check_release()
		_finished = true
		_finished_id = _clip_id
		if _plan.last_beat != "" and ClipLib3D.exists(_plan.last_beat):
			_pending_last_beat = _plan.last_beat
		return
	if _t > prev:
		_collect(_ev_from, _t)
		_ev_from = _t
	_check_release()


## Queues the plan's events crossed in (f0, f1] (emitted by `_flush_events` once the pose is applied).
func _collect(f0: float, f1: float) -> void:
	if _plan == null or f1 <= f0:
		return
	_plan.between_into(f0, f1, _events)
	_pending.append_array(_events)


func _flush_events() -> void:
	if not _pending.is_empty():
		for e in _pending:
			_handle_event(e)
			clip_event.emit(e)
		_pending.clear()
	if _finished_id != "":
		var id := _finished_id
		_finished_id = ""
		clip_finished.emit(id)


func _step_overlay(df: float) -> void:
	if _ov_clip == null or _ov_locked:
		return
	if _ov_blend > 0.0:
		_ov_w = move_toward(_ov_w, _ov_target, df / _ov_blend)
	else:
		_ov_w = _ov_target
	var n := float(_ov_clip.length)
	_ov_t += df
	if _ov_clip.loop:
		if _ov_t >= n:
			_ov_t = fmod(_ov_t, n)
			ClipEvents3D.between_into(_ov_clip, _ov_ev_from, n, _ov_events)
			_pending.append_array(_ov_events)
			_ov_ev_from = -1.0
		ClipEvents3D.between_into(_ov_clip, _ov_ev_from, _ov_t, _ov_events)
		_pending.append_array(_ov_events)
		_ov_ev_from = _ov_t
	else:
		var ended := _ov_t >= n
		if ended:
			_ov_t = n
		ClipEvents3D.between_into(_ov_clip, _ov_ev_from, _ov_t, _ov_events)
		_pending.append_array(_ov_events)
		_ov_ev_from = _ov_t
		if ended and _ov_target > 0.0:
			stop_overlay(_ov_clip.blend_out)
	if _ov_clip != null and _ov_target <= 0.0 and _ov_w <= 0.0:
		_ov_clip = null
	_pose_dirty = true


func _start_base(anim_name: StringName, prev: ClipDef3D, prev_t: float, blend_f: float) -> void:
	var new_slot := 1 - _slot if blend_f > 0.0 else _slot
	if new_slot == 0:
		_anim_a.animation = anim_name
	else:
		_anim_b.animation = anim_name
	if blend_f > 0.0 and prev != null:
		_old_clip = prev
		_old_t = prev_t
		_xfade_len = blend_f
		_xfade_f = 0.0
	else:
		_old_clip = null
		_xfade_len = 0.0
	_slot = new_slot
	_pose_dirty = true


func _apply_pose(view_dt: float) -> void:
	if tree == null or not tree.is_inside_tree():
		_pose_dirty = true
		return
	if not _pose_dirty and _t == _last_applied_t and _old_clip == null and _ov_clip == null:
		return
	_pose_dirty = false
	_last_applied_t = _t
	var cur_f := 0.0
	var cur_clip: ClipDef3D = _clip
	if _plan != null:
		cur_f = _plan.frame_at(_t)
		var at := _plan.clip_at(_t)
		if at != cur_clip and not _tail_on:
			# The suppressed tail: cross-fade into it once.
			_tail_on = true
			var an := _ensure_anim(at)
			_start_base(an if an != &"" else REST_ANIM, _clip, _plan.src_frame(float(_plan.tail_start)), float(_plan.tail_blend))
		if _tail_on:
			cur_clip = at
	var x := float(_slot)
	if _old_clip != null and _xfade_len > 0.0:
		_xfade_f += view_dt * 60.0
		var k := clampf(_xfade_f / _xfade_len, 0.0, 1.0)
		x = lerpf(1.0 - float(_slot), float(_slot), k)
		if not _external:
			_old_t = minf(_old_t + view_dt * 60.0, float(_old_clip.length)) if not _old_clip.loop else fmod(_old_t + view_dt * 60.0, float(_old_clip.length))
		if k >= 1.0:
			_old_clip = null
	var cur_s := _clip_seconds(cur_clip, cur_f)
	var old_s := _clip_seconds(_old_clip, _old_t) if _old_clip != null else 0.0
	if _slot == 0:
		tree.set(P_SEEK_A, cur_s)
		tree.set(P_SEEK_B, old_s)
	else:
		tree.set(P_SEEK_B, cur_s)
		tree.set(P_SEEK_A, old_s)
	tree.set(P_X, x)
	var m := _ov_w if _ov_clip != null and _mask_name != "face" else 0.0
	tree.set(P_M, m)
	if m > 0.0:
		tree.set(P_SEEK_O, _clip_seconds(_ov_clip, _ov_t))
	tree.advance(0.0)


static func _clip_seconds(c: ClipDef3D, f: float) -> float:
	if c == null:
		return 0.0
	return clampf(f, 0.0, float(c.length)) / 60.0


## The clip's playable name in the tree ("<rig>/<name>"); loads + adds it to this player's library the first time
## (prepare_clips does that for the Night's clips under the curtain). &"" when the clip has no Animation.
func _ensure_anim(c: ClipDef3D) -> StringName:
	var a := ClipLib3D.animation(c.id)
	if a == null:
		return &""
	if _anim_objs.get(c, null) == a:
		return _anim_names[c]
	var lib_name := c.rig_id
	var lib: AnimationLibrary = _libs.get(lib_name, null)
	if lib == null:
		lib = AnimationLibrary.new()
		tree.add_animation_library(StringName(lib_name), lib)
		_libs[lib_name] = lib
	var an := StringName(c.name)
	if not lib.has_animation(an):
		lib.add_animation(an, a)
	elif lib.get_animation(an) != a:
		lib.remove_animation(an)
		lib.add_animation(an, a)
	var full := StringName("%s/%s" % [lib_name, c.name])
	_anim_names[c] = full
	_anim_objs[c] = a
	return full


## The plan for playing `c` with `opts`: plain plays (tier ≤ 1, not suppressed, no hold override) reuse one cached
## plan per clip and loop mode (never mutated); tiered / suppressed plays build their own.
func _plan_for(c: ClipDef3D, opts: Dictionary) -> PlayPlan3D:
	var loop := bool(opts.get("loop", c.loop))
	if int(opts.get("tier", 1)) <= 1 and not bool(opts.get("suppressed", false)) and not opts.has("hold"):
		var cache := _plans if loop == c.loop else _plans_flip
		var hit: PlayPlan3D = cache.get(c, null)
		if hit == null:
			hit = PlayPlan3D.build(c, {})
			hit.loop = loop
			cache[c] = hit
		return hit
	var p := PlayPlan3D.build(c, opts)
	for w in p.warnings:
		push_warning("RigPlayer3D(%s): %s" % [rig_id, w])
	if opts.has("loop"):
		p.loop = loop
	return p


## Loads and converts every clip of `ids` for this player, so a later play() / play_overlay() of one loads nothing,
## builds no Animation, adds nothing to a library and builds no plain plan: its Animation (loaded, loop mode from
## the sidecar), its entry in the tree's library, its playable name, its plain plans (both loop modes), the bones
## its scale tracks key — then ONE mixer evaluation, so the AnimationTree's track caches (rebuilt over every
## animation of every library after a library add) are rebuilt now, not in the frame after a switch. Ids of clips
## without a baked Animation are skipped; already prepared clips cost a lookup. Returns the clips ready.
## `warm()` (NightWarmer's materials step, under the curtain) calls it with every clip of the rig; a view may call
## it with the Night's warm list (WorldView3D.warm_clips) — either way before PLAY.
func prepare_clips(ids: PackedStringArray) -> int:
	if not ok:
		return 0
	var n := 0
	var added := false
	for id in ids:
		var c := ClipLib3D.get_clip(id)
		if c == null:
			continue
		var had := _anim_objs.has(c)
		if _ensure_anim(c) == &"":
			continue
		added = added or not had
		if c.layer != "overlay":
			_plan_for(c, {})
			_plan_for(c, {"loop": not c.loop})
		_scale_bones_of(c)
		n += 1
	if added:
		_pose_dirty = true
		_apply_pose(0.0)
	return n


## Every clip of this rig (ClipLib3D.clips_of) through prepare_clips; the count.
func prepare_all_clips() -> int:
	return prepare_clips(ClipLib3D.clips_of(rig_id)) if ok else 0


func _set_mask(mask: String) -> void:
	if mask == _mask_name:
		return
	_mask_name = mask
	_blend_m.filters = []
	var roots: Array = MASK_ROOTS.get(mask, MASK_ROOTS["upper"])
	for r in roots:
		var ri := skeleton.find_bone(String(r))
		if ri < 0:
			continue
		for bi in _descendants(ri):
			_blend_m.set_filter_path(NodePath("%s:%s" % [def.skeleton_path, skeleton.get_bone_name(bi)]), true)


func _descendants(root_i: int) -> PackedInt32Array:
	var out := PackedInt32Array([root_i])
	var k := 0
	while k < out.size():
		for c in skeleton.get_bone_children(out[k]):
			out.append(c)
		k += 1
	return out


func _count_missing(clip_id: String) -> void:
	var first := not _missing.has(clip_id)
	_missing[clip_id] = int(_missing.get(clip_id, 0)) + 1
	if first:
		push_warning("RigPlayer3D(%s): clip '%s' is missing" % [rig_id, clip_id])


## The playing base clip id ("" = none).
func current_clip() -> String:
	return _clip_id


## The timeline frame of the base clip.
func current_frame() -> float:
	return _t


## True when the clip exists (sidecar + Animation).
func has_clip(id: String) -> bool:
	return ClipLib3D.exists(id) and ClipLib3D.animation(id) != null


## The clip's length in frames (−1 when missing).
func clip_length(id: String) -> int:
	return ClipLib3D.length(id)


## The plan of the playing clip (tier remap, events), null when none.
func plan() -> PlayPlan3D:
	return _plan


## {missing_clips: {id: n}, face_misses: n}
func counts() -> Dictionary:
	return {"missing_clips": _missing.duplicate(), "face_misses": face.face_misses}


# --- events -----------------------------------------------------------------------------------------------------

func _handle_event(e: Dictionary) -> void:
	match String(e.get("type", "")):
		"face":
			if e.has("preset"):
				face.set_face(String(e["preset"]))
			var sl: Variant = e.get("slots", null)
			if sl is Dictionary:
				for k in (sl as Dictionary):
					face.set_slot(String(k), String((sl as Dictionary)[k]))
		"look":
			var st: Variant = e.get("set", {})
			if st is Dictionary:
				for slot in (st as Dictionary):
					set_body_slot(String(slot), String((st as Dictionary)[slot]), &"clip")
		"prop":
			_prop_event(e)
		"jiggle":
			kick_jiggle(float(e.get("kick", 0.5)))


func _prop_event(e: Dictionary) -> void:
	var pid := String(e.get("prop", ""))
	if pid.begins_with("set:") or pid == "":
		return
	var op := String(e.get("op", ""))
	match op:
		"show":
			if def.props.has(pid):
				set_prop(pid, _home_state(pid))
			else:
				set_prop(pid, "shown")
		"hide":
			set_prop(pid, "hidden")
		"attach":
			var sock := String(e.get("socket", ""))
			if def.props.has(pid):
				var st := _state_for_socket(pid, sock)
				set_prop(pid, st if st != "" else _home_state(pid))
			else:
				set_prop(pid, "shown")
		"detach", "launch":
			if def.props.has(pid):
				var v: Variant = e.get("vel", [0, 0, 0])
				var vel := Vector3.ZERO
				if v is Array and (v as Array).size() >= 2:
					vel = Vector3(float(v[0]), float(v[1]), float(v[2]) if (v as Array).size() > 2 else 0.0)
				if op == "detach":
					vel = Vector3.ZERO
				launch_prop(pid, vel, float(e.get("spin", 0.0)), float(e.get("f", _t)))
		"fall":
			pass


func _home_state(pid: String) -> String:
	var pr: RigDef3D.Prop = def.props[pid]
	if pr.default_state != "hidden":
		return pr.default_state
	for st in pr.states:
		if String(st) != "hidden" and String(st) != "shown" and String(pr.states[st]) != "":
			return String(st)
	return "shown"


func _state_for_socket(pid: String, sock: String) -> String:
	var pr: RigDef3D.Prop = def.props[pid]
	for s in pr.states:
		if String(pr.states[s]) == sock:
			return String(s)
	return ""


# --- facing, cheat ---------------------------------------------------------------------------------------------

## ±1 → body yaw ±90° (sim facing) minus the cheat toward the camera; a 6-frame eased turn when animated.
func set_facing(dir: int, animate := true) -> void:
	var d := 1 if dir >= 0 else -1
	if d == facing and _turn_f < 0.0 and body != null and is_equal_approx(body.rotation_degrees.y, _target_yaw()):
		return
	facing = d
	if animate and ok:
		# The face's mirrored cells swap at the turn's midpoint (the face is toward the camera then).
		_yaw_from = _yaw_cur
		_turn_f = 0.0
	else:
		face.facing = d
		_turn_f = -1.0
		_yaw_cur = _target_yaw()
		_apply_yaw()


## Extra yaw toward the camera (REDESIGN §5.1: idle 35, walk 20, face-to-face 0–10), eased over `ease_s`.
func set_cheat(deg: float, ease_s := 0.2) -> void:
	_cheat_from = _cheat
	_cheat_to = deg
	_cheat_s = maxf(0.0, ease_s)
	_cheat_t = 0.0 if _cheat_s > 0.0 else 1.0
	if _cheat_s <= 0.0:
		_cheat = deg
		if _turn_f < 0.0:
			_yaw_cur = _target_yaw()
			_apply_yaw()


## The current body yaw in degrees (+90 = facing right).
func body_yaw() -> float:
	return _yaw_cur


## The yaw the body turns to: facing right 90° − cheat, facing left −90° + cheat.
static func yaw_for(dir: int, cheat_deg: float) -> float:
	return 90.0 - cheat_deg if dir >= 0 else -90.0 + cheat_deg


func _target_yaw() -> float:
	return yaw_for(facing, _cheat)


func _update_turn(df: float) -> void:
	if _turn_f < 0.0:
		var ty := _target_yaw()
		if not is_equal_approx(_yaw_cur, ty):
			_yaw_cur = ty
			_apply_yaw()
		return
	_turn_f += df
	var k := clampf(_turn_f / float(TURN_FRAMES), 0.0, 1.0)
	if k >= 0.5 and face.facing != facing:
		face.facing = facing
		face.changed = true
	var e := k * k * (3.0 - 2.0 * k)
	var ty2 := _target_yaw()
	# Turn through the camera side (yaw 0), never through the back.
	_yaw_cur = lerpf(_yaw_from, ty2, e)
	if k >= 1.0:
		_turn_f = -1.0
		_yaw_cur = ty2
	_apply_yaw()


func _update_cheat(dt: float) -> void:
	if _cheat_t >= 1.0:
		return
	_cheat_t = minf(1.0, _cheat_t + dt / maxf(0.0001, _cheat_s))
	var e := _cheat_t * _cheat_t * (3.0 - 2.0 * _cheat_t)
	_cheat = lerpf(_cheat_from, _cheat_to, e)


func _apply_yaw() -> void:
	if body != null:
		body.rotation_degrees = Vector3(0.0, _yaw_cur, 0.0)


# --- face -------------------------------------------------------------------------------------------------------

## The view's face preset (the clip's face timeline still wins at its next entry).
func set_face(preset: String) -> void:
	face.set_face(preset)


## Override one face layer with a cell ("none" hides, "" clears).
func set_slot(slot: String, cell: String) -> void:
	face.set_slot(slot, cell)


func _push_face(df: float) -> void:
	if not face.has_face():
		return
	if _ov_clip != null and _mask_name == "face":
		face.clip = _ov_clip
		face.clip_frame = _ov_t
	elif _plan != null:
		face.clip = _plan.clip_at(_t)
		face.clip_frame = _plan.frame_at(_t)
	else:
		face.clip = null
	face.suppressed = face.clip != null and face.clip.in_hold(face.clip_frame)
	face.update(df)
	if face.changed:
		face.changed = false
		for m in _mats:
			if m in _att_mats:
				continue
			m.set_shader_parameter("face_cell_a", face.cell_a)
			m.set_shader_parameter("face_cell_b", face.cell_b)
			m.set_shader_parameter("pupil_offset", face.pupil)


# --- gaze (sidecar `gaze`, D8) ---------------------------------------------------------------------------------

## The camera the sidecar gaze windows turn the face to (null = the viewport's active camera; while the head is off
## that camera's screen — e.g. drawn only in the PiP window — the face goes to the audience straight in front of it).
func set_gaze_camera(cam: Camera3D) -> void:
	_gaze_cam = cam


## The camera gaze windows look at now (the explicit one, else the viewport's active camera; null = none).
func gaze_camera() -> Camera3D:
	if _gaze_cam != null and is_instance_valid(_gaze_cam) and _gaze_cam.is_inside_tree():
		return _gaze_cam
	var vp := get_viewport() if is_inside_tree() else null
	return vp.get_camera_3d() if vp != null else null


## The gaze weight applied this frame (0..1).
func gaze_weight() -> float:
	return _gaze_w


## The gaze weight of the playing clips at their current frames: the base clip's window (cross-faded with the
## outgoing clip's during a blend) and the overlay's (× its blend weight) — the larger one.
func gaze_weight_now() -> float:
	var w := 0.0
	if _plan != null:
		var c := _plan.clip_at(_t)
		if c != null and c.has_gaze():
			w = c.gaze_weight(_plan.frame_at(_t))
		if _old_clip != null and _xfade_len > 0.0:
			var k := clampf(_xfade_f / _xfade_len, 0.0, 1.0)
			w = lerpf(_old_clip.gaze_weight(_old_t) if _old_clip.has_gaze() else 0.0, w, k)
	if _ov_clip != null and _ov_clip.has_gaze():
		w = maxf(w, _ov_clip.gaze_weight(_ov_t) * _ov_w)
	return w


func _update_gaze() -> void:
	if gaze_mod == null:
		return
	var cam := gaze_camera() if gaze_enabled else null
	_gaze_w = gaze_weight_now() if cam != null else 0.0
	gaze_mod.weight = _gaze_w
	gaze_mod.active = _gaze_w > 0.0001
	if not gaze_mod.active:
		return
	var inv := skeleton.global_transform.affine_inverse()
	var at := cam.global_position
	if _gaze_cam == null:
		# Off the main camera's screen (Bellows drawn only in the PiP window, which shares this pose): face the
		# audience straight in front of him (a camera's height and depth, his x) — how the PiP frames his room.
		var head := head_global()
		if not cam.is_position_in_frustum(head):
			at = Vector3(head.x, at.y, at.z)
	gaze_mod.target = inv * at
	gaze_mod.up = (inv.basis * Vector3.UP).normalized()


# --- look-at ----------------------------------------------------------------------------------------------------

## Head (+ pupils) toward a world point, additive, clamped (±35° yaw, ±20° pitch); `weight` eased over 0.2 s.
func look_at_point(world: Vector3, weight: float) -> void:
	_look_point = world
	_look_w_to = clampf(weight, 0.0, 1.0)
	if _look_target != null and _look_target.is_inside_tree():
		_look_target.global_position = world


func _update_look(dt: float) -> void:
	if look_mod == null:
		return
	_look_w = move_toward(_look_w, _look_w_to, dt / LOOK_EASE_S)
	look_mod.active = _look_w > 0.001
	look_mod.influence = _look_w
	if _look_w <= 0.001:
		if face.look != Vector2.ZERO:
			face.look = Vector2.ZERO
		return
	if is_inside_tree():
		_look_target.global_position = _look_point
	# Pupils: the target direction in the body's frame (x = the character's right on screen, y up).
	var hi := _bone("head")
	if hi < 0:
		return
	var head_w := _skel_to_world() * skeleton.get_bone_global_pose(hi)
	var to := (_look_point - head_w.origin)
	var local := body.global_transform.basis.inverse() * to if is_inside_tree() else to
	var fwd := maxf(0.05, local.z)
	var yaw := atan2(local.x, fwd)
	var pitch := atan2(local.y, Vector2(local.x, fwd).length())
	# A gaze window puts the face (and the painted pupils, centred) on the camera: the look-at pupils fade with it.
	face.look = Vector2(clampf(yaw / deg_to_rad(LOOK_YAW_DEG), -1.0, 1.0), clampf(pitch / deg_to_rad(LOOK_PITCH_DEG), -1.0, 1.0)) * _look_w * (1.0 - _gaze_w)


# --- jiggle -----------------------------------------------------------------------------------------------------

## Resets the spring bones (teleport, seek, retry) so nothing whips.
func reset_jiggle() -> void:
	if jiggle != null:
		jiggle.reset()


## A `jiggle` event: a short external-force kick along the body's up axis (settles on its own).
func kick_jiggle(kick: float) -> void:
	if jiggle == null:
		return
	jiggle.external_force = Vector3(0.0, -absf(kick) * 2.0, 0.0)
	_kick_left = 0.08



# --- looks, body slots -----------------------------------------------------------------------------------------

## Residue / costume looks from the descriptor's `looks` (owner "residue": the sim's state).
func set_look(look: String, on: bool) -> void:
	if not ok:
		return
	if not def.looks.has(look):
		push_error("RigPlayer3D(%s): unknown look '%s'" % [rig_id, look])
		return
	var i := _looks_on.find(look)
	if on and i < 0:
		_looks_on.append(look)
	elif not on and i >= 0:
		_looks_on.remove_at(i)
	else:
		return
	_looks_changed()


## True when `look` is on.
func has_look(look: String) -> bool:
	return _looks_on.has(look)


## Sets a body slot variant (`slots.<slot>.<variant>`) with its owner: &"clip" (a clip's look event; owns the slot
## until the clip's release frame) or &"residue" (the view, from residues.json). Variant "" clears the residue.
func set_body_slot(slot: String, p_variant: String, owner := &"clip") -> void:
	if not ok:
		return
	if not def.slots.has(slot):
		push_error("RigPlayer3D(%s): unknown body slot '%s' (clip %s)" % [rig_id, slot, _clip_id])
		return
	if p_variant != "" and not (def.slots[slot] as Dictionary).has(p_variant):
		push_error("RigPlayer3D(%s): unknown variant '%s' of body slot '%s' (clip %s)" % [rig_id, p_variant, slot, _clip_id])
		return
	if owner == &"clip":
		if p_variant == "":
			_slot_clip.erase(slot)
		else:
			_slot_clip[slot] = p_variant
	else:
		if p_variant == "":
			_slot_residue.erase(slot)
		else:
			_slot_residue[slot] = p_variant
	_looks_changed()


## The variant a body slot shows now (clip-owned > residue > the looks' swaps > the default).
func body_slot(slot: String) -> String:
	if _slot_clip.has(slot):
		return String(_slot_clip[slot])
	if _slot_residue.has(slot):
		return String(_slot_residue[slot])
	for k in range(_looks_on.size() - 1, -1, -1):
		var lk: RigDef3D.Look = def.looks[_looks_on[k]]
		if lk.swap.has(slot):
			return String(lk.swap[slot])
	return String(def.slot_default.get(slot, ""))


## Who owns a body slot now: &"clip", &"residue" or &"" (the default).
func body_slot_owner(slot: String) -> StringName:
	if _slot_clip.has(slot):
		return &"clip"
	if _slot_residue.has(slot):
		return &"residue"
	for k in _looks_on:
		if (def.looks[k] as RigDef3D.Look).swap.has(slot):
			return &"residue"
	return &""


func _check_release() -> void:
	if not _slot_clip.is_empty() and _t >= _release_f:
		_end_clip_ownership()


func _end_clip_ownership() -> void:
	if _slot_clip.is_empty():
		return
	_slot_clip.clear()
	_looks_changed()


## Re-applies the looks: the looks pass (attachments, slot / look uniforms, face cells, look-driven props) only when
## the looks / slots / forced attachments changed (`_looks_dirty`), then the bones pass (hidden bones, props' scale
## fix: they follow the playing clips).
func _refresh_looks() -> void:
	if not ok or _refreshing:
		return
	_refreshing = true
	if _looks_dirty or _looks_props:
		_looks_dirty = false
		looks_passes += 1
		_refresh_looks_now()
	_refresh_bones_now()
	_refreshing = false


## The looks changed: mark them and re-apply.
func _looks_changed() -> void:
	_looks_dirty = true
	_refresh_looks()


## Resolves the descriptor's looks and slot variants to indices / converted values once (setup).
func _build_look_fx() -> void:
	_att_ids = PackedStringArray()
	_att_default = PackedByteArray()
	for aid in def.attachment_order:
		_att_index[aid] = _att_ids.size()
		_att_ids.append(aid)
		_att_list.append(_att_nodes.get(aid, null))
		_att_default.append(1 if (def.attachments[aid] as RigDef3D.Attachment).visible_default else 0)
	_att_vis.resize(_att_ids.size())
	_slot_ids = PackedStringArray()
	for slot in def.slots:
		_slot_ids.append(String(slot))
		var vars: Dictionary = def.slots[slot]
		var fxs: Dictionary = {}
		var clear := PackedInt32Array()
		for vn in vars:
			var sv: RigDef3D.SlotVariant = vars[vn]
			var fx := _LookFx.new()
			_fx_items(sv.show, fx, true)
			for ai in fx.show_att:
				if not clear.has(ai):
					clear.append(ai)
			fx.hide_bones = _bone_indices(sv.hide_bones)
			for pk in sv.params:
				fx.params[StringName(String(pk))] = _param_value(sv.params[pk])
			fxs[String(vn)] = fx
		_slot_fx.append(fxs)
		_slot_clear.append(clear)
		var hb: Variant = def.slot_hide_bones.get(slot, PackedStringArray())
		_slot_hide.append(_bone_indices(hb if hb is PackedStringArray else PackedStringArray()))
	for ln in def.looks:
		var lk: RigDef3D.Look = def.looks[ln]
		var fx2 := _LookFx.new()
		_fx_items(lk.show, fx2, true)
		_fx_items(lk.hide, fx2, false)
		fx2.hide_bones = _bone_indices(lk.hide_bones)
		for pk2 in lk.params:
			fx2.params[StringName(String(pk2))] = _param_value(lk.params[pk2])
		fx2.face = lk.face.duplicate()
		_look_fx[String(ln)] = fx2
	_default_hidden = _bone_indices(def.default_hidden_bones)
	_anim_mark.resize(skeleton.get_bone_count())
	for pid in def.prop_order:
		var pi: int = _prop_index[pid]
		if not _prop_of_bone.has(mods.prop_bone[pi]):
			_prop_of_bone[mods.prop_bone[pi]] = pi
	_looks_dirty = true


## Splits descriptor names into attachment indices / bone prop ids (unknown names are dropped, as before).
func _fx_items(names: PackedStringArray, fx: _LookFx, show: bool) -> void:
	for a in names:
		if _att_index.has(a):
			if show:
				fx.show_att.append(int(_att_index[a]))
			else:
				fx.hide_att.append(int(_att_index[a]))
		elif def.props.has(a):
			if show:
				fx.show_props.append(a)
			else:
				fx.hide_props.append(a)


func _bone_indices(names: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for b in names:
		var bi := skeleton.find_bone(b)
		if bi >= 0 and not out.has(bi):
			out.append(bi)
	return out


## The looks pass: attachment visibility, the bones the looks / slots hide, slot / look uniforms (set the active
## ones, restore the rest), face cells, look-driven prop states — from the precomputed _LookFx (no string lookups).
func _refresh_looks_now() -> void:
	var na := _att_ids.size()
	for i in na:
		_att_vis[i] = _att_default[i]
	var hide := PackedInt32Array()
	var params: Dictionary = {}
	var props_touched := false
	for si in _slot_ids.size():
		for ai in _slot_clear[si]:
			_att_vis[ai] = 0
		var fx: _LookFx = (_slot_fx[si] as Dictionary).get(body_slot(_slot_ids[si]), null)
		if fx != null:
			for ai2 in fx.show_att:
				_att_vis[ai2] = 1
			hide.append_array(fx.hide_bones)
			params.merge(fx.params, true)
	var cells: Dictionary = {}
	for ln in _looks_on:
		var lk: _LookFx = _look_fx[ln]
		for ai3 in lk.show_att:
			_att_vis[ai3] = 1
		for pid in lk.show_props:
			props_touched = true
			set_prop(pid, _home_state(pid))
		for ai4 in lk.hide_att:
			_att_vis[ai4] = 0
		for pid2 in lk.hide_props:
			props_touched = true
			set_prop(pid2, "hidden")
		hide.append_array(lk.hide_bones)
		params.merge(lk.params, true)
		cells.merge(lk.face, true)
	_looks_props = props_touched
	for aid in _att_forced:
		var fi: int = _att_index.get(aid, -1)
		if fi >= 0:
			_att_vis[fi] = 1 if bool(_att_forced[aid]) else 0
	for i2 in na:
		var n: Node3D = _att_list[i2]
		if n != null:
			var v := _att_vis[i2] == 1 or _warm_frames > 0
			if n.visible != v:
				n.visible = v
	for si2 in _slot_ids.size():
		var sn := _slot_ids[si2]
		if body_slot(sn) != String(def.slot_default.get(sn, "")):
			hide.append_array(_slot_hide[si2])
	_look_hide = hide
	face.set_look_cells(cells)
	# Look uniforms: set the active ones, restore the rest (only what changed).
	for pk in _param_defaults.keys():
		if not params.has(pk):
			for m in _mats:
				m.set_shader_parameter(pk, _param_defaults[pk])
			_param_defaults.erase(pk)
			_params_now.erase(pk)
	for pk2 in params:
		if not _param_defaults.has(pk2) and mat != null:
			_param_defaults[pk2] = mat.get_shader_parameter(pk2)
		if not _params_now.has(pk2) or _params_now[pk2] != params[pk2]:
			_params_now[pk2] = params[pk2]
			for m2 in _mats:
				m2.set_shader_parameter(pk2, params[pk2])


## The bones pass: the props' scale fix and the hidden-bone list, from the looks' hidden bones + the descriptor's
## hidden bones that no playing clip keys and no shown prop rides. Runs on every clip switch and prop state change.
func _refresh_bones_now() -> void:
	_anim_mark.fill(0)
	_mark_scale(_clip)
	_mark_scale(_old_clip)
	_mark_scale(_ov_clip)
	for pi in mods.prop_bone.size():
		var pb := mods.prop_bone[pi]
		mods.prop_fix_scale[pi] = 1 if pb >= 0 and _anim_mark[pb] == 1 and mods.prop_mode[pi] == RigMods3D.MODE_HOME else 0
	var hb := _look_hide.duplicate()
	for bi in _default_hidden:
		if _anim_mark[bi] == 0 and not hb.has(bi) and not _prop_bone_shown(bi):
			hb.append(bi)
	mods.hidden_bones = hb


func _mark_scale(c: ClipDef3D) -> void:
	if c == null:
		return
	for bi in _scale_bones_of(c):
		if bi >= 0 and bi < _anim_mark.size():
			_anim_mark[bi] = 1


## The bones whose scale clip `c` keys (cached per clip id).
func _scale_bones_of(c: ClipDef3D) -> PackedInt32Array:
	var hit: Variant = _scale_bones_cache.get(c.id, null)
	if hit != null:
		return hit
	var arr := PackedInt32Array()
	var a := ClipLib3D.animation(c.id)
	if a != null:
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_SCALE_3D:
				var bi := skeleton.find_bone(String(a.track_get_path(t).get_concatenated_subnames()))
				if bi >= 0:
					arr.append(bi)
	_scale_bones_cache[c.id] = arr
	return arr


## True when a bone-driven prop on bone `bi` is in a visible state (its own state machine rules it).
func _prop_bone_shown(bi: int) -> bool:
	var i: int = _prop_of_bone.get(bi, -1)
	return i >= 0 and mods.prop_mode[i] != RigMods3D.MODE_HIDDEN


static func _param_value(v: Variant) -> Variant:
	if v is String and String(v).begins_with("#"):
		return Color(String(v))
	if v is Array:
		var a: Array = v
		if a.size() == 2:
			return Vector2(float(a[0]), float(a[1]))
		if a.size() == 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
		if a.size() == 4:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return v


## Retry / seek / teleport: clears clip-owned body slots, re-attaches launched props, resets jiggle (the view
## re-applies residue looks after). `clear_residues` also drops every residue slot and look.
func reset(clear_residues := false) -> void:
	if not ok:
		return
	_slot_clip.clear()
	if clear_residues:
		_slot_residue.clear()
		_looks_on.clear()
	_att_forced.clear()
	_flying.clear()
	for pid in def.prop_order:
		_set_prop_state(pid, (def.props[pid] as RigDef3D.Prop).default_state, false)
	_prop_forced.clear()
	reset_jiggle()
	_looks_changed()


# --- tint, stone, flash, outline, stage light ------------------------------------------------------------------

## Temper tier 0–3 (4 = livid): `tint_color` (a multiply colour, alpha = amount; skin mask COLOR.r), the tier's
## bone scale (Bellows' sideburn bristle) and specs on at livid when the rig has them.
func set_tint_tier(tier: int) -> void:
	_tier = clampi(tier, 0, 4)
	if not ok:
		return
	var tc := tint_uniform(def, _tier)
	for m in _mats:
		m.set_shader_parameter("tint_color", tc)
	if mods != null:
		mods.scale_factor = def.tint_bone_scale[_tier] if _tier < def.tint_bone_scale.size() else 1.0
	if def.props.has("specs"):
		var pr: RigDef3D.Prop = def.props["specs"]
		if _tier >= 4 and pr.states.has(def.tint_livid_specs) and prop_state("specs") != def.tint_livid_specs:
			set_prop("specs", def.tint_livid_specs)
			_livid_specs = true
		elif _tier < 4 and _livid_specs:
			_livid_specs = false
			set_prop("specs", pr.default_state)


## The `tint_color` uniform for temper `tier` of `d`: tiers 1–3 = the reference skin × the tier's multiply colour,
## livid (4) = the livid colour, alpha 1; tier 0 (white) = alpha 0 (no tint).
static func tint_uniform(d: RigDef3D, tier: int) -> Color:
	if tier >= 4 or tier >= d.tint_tiers.size():
		return Color(d.tint_livid.r, d.tint_livid.g, d.tint_livid.b, 1.0)
	var mul := d.tint_color(tier)
	if tier <= 0 and mul.is_equal_approx(Color.WHITE):
		return Color(1, 1, 1, 0)
	var skin: Color = d.tint_skin
	return Color(skin.r * mul.r, skin.g * mul.g, skin.b * mul.b, 1.0)


## The current temper tier.
func tint_tier() -> int:
	return _tier


## The marble statue (freeze): `stone` 0 → 1 over `ease_s` (eyes, beret, braces keep colour by the COLOR.g mask).
func set_stone(on: bool, ease_s := 0.1) -> void:
	_stone_from = _stone
	_stone_to = 1.0 if on else 0.0
	_stone_s = maxf(0.0, ease_s)
	_stone_t = 0.0 if _stone_s > 0.0 else 1.0
	if _stone_s <= 0.0:
		_stone = _stone_to
		_set_all("stone", _stone)


## The current stone amount (0…1).
func stone_amount() -> float:
	return _stone


## A colour flash that decays over `s` seconds.
func flash(color: Color, s := 0.15) -> void:
	_flash = 1.0
	_flash_s = maxf(0.01, s)
	_set_all("flash_color", color)
	_set_all("flash", 1.0)


## Settings "Outline +50 %" → 1.5. ONE path: the multiplier is the global `mnd_outline_scale` that every outline
## shader (characters, props, halos) already multiplies by (StageLighting3D.set_outline_scale sets the same global);
## this sets that global (when registered) and never scales `outline_px`, so calling both never compounds (1.5, not
## 2.25). `outline_px` stays the descriptor's value.
func set_outline_scale(k: float) -> void:
	_outline_scale = maxf(0.0, k)
	if ProjectSettings.has_setting("shader_globals/mnd_outline_scale"):
		RenderingServer.global_shader_parameter_set(&"mnd_outline_scale", _outline_scale)


## The last Settings outline multiplier set through this player (the live value is the global).
func outline_scale() -> float:
	return _outline_scale


## The room's stage light on this character (REDESIGN §5.3; Bellows' never below 0.9 — the view's rule) and the
## room's desaturation.
func set_stage_light(level: float, desat := 0.0) -> void:
	_set_all("stage_light", level)
	_set_all("desat", desat)
	for sm in _set_mats:
		sm.set_shader_parameter("stage_light", level)
		sm.set_shader_parameter("desat", desat)
	if outline_mat != null:
		outline_mat.set_shader_parameter("stage_light", level)


## The character's main material (null when on the stand-in).
func material() -> ShaderMaterial:
	return mat


func _set_all(param: StringName, v: Variant) -> void:
	for m in _mats:
		m.set_shader_parameter(param, v)


func _update_material(dt: float) -> void:
	if _stone_t < 1.0:
		_stone_t = minf(1.0, _stone_t + dt / maxf(0.0001, _stone_s))
		_stone = lerpf(_stone_from, _stone_to, _stone_t)
		_set_all("stone", _stone)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt / _flash_s)
		# A look's own `flash` uniform (FLOURY's dusting) comes back once the flash has decayed.
		_set_all("flash", _flash if _flash > 0.0 or not _params_now.has(&"flash") else _params_now[&"flash"])
	if _kick_left > 0.0:
		_kick_left -= dt
		if _kick_left <= 0.0 and jiggle != null:
			jiggle.external_force = Vector3.ZERO
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0:
			set_tint_tier(_tier)
			_set_all("stone", _stone)
			_params_now.clear()
			_looks_changed()


## Every look, tint tier, stone and prop state drawn once (instances exist from setup; this shows every attachment
## and the livid / stone uniforms for one frame), every material registered with MaterialWarm3D, and every clip of
## the rig prepared (`prepare_all_clips`: no load / Animation build / library add left for play()).
func warm() -> void:
	if not ok:
		return
	prepare_all_clips()
	_warm_frames = 2
	for m in _mats:
		m.set_shader_parameter("tint_color", Color(def.tint_livid.r, def.tint_livid.g, def.tint_livid.b, 1.0))
		m.set_shader_parameter("stone", 0.5)
		_register_warm(m)
	for aid in _att_nodes:
		(_att_nodes[aid] as Node3D).visible = true


# --- props, sockets ---------------------------------------------------------------------------------------------

## Show / hide / state of a bone-driven prop ("teacup": "held" | "hidden") or of an attachment ("stool": "shown" |
## "hidden") — props first, then attachments.
func set_prop(prop: String, state: String) -> void:
	if not ok:
		return
	if def.props.has(prop):
		_set_prop_state(prop, state, true)
		return
	if def.attachments.has(prop):
		var f := state != "hidden"
		if _att_forced.get(prop, null) is bool and bool(_att_forced[prop]) == f:
			return
		_att_forced[prop] = f
		_looks_changed()
		return
	push_error("RigPlayer3D(%s): unknown prop '%s' (clip %s)" % [rig_id, prop, _clip_id])


## A prop's current state ("" when unknown).
func prop_state(prop: String) -> String:
	if _prop_state.has(prop):
		return String(_prop_state[prop])
	if _att_nodes.has(prop):
		return "shown" if (_att_nodes[prop] as Node3D).visible else "hidden"
	return ""


func _set_prop_state(pid: String, state: String, forced: bool) -> void:
	var pr: RigDef3D.Prop = def.props[pid]
	if not pr.states.has(state):
		push_error("RigPlayer3D(%s): prop '%s' has no state '%s'" % [rig_id, pid, state])
		return
	var i: int = _prop_index[pid]
	var target := String(pr.states[state])
	_prop_state[pid] = state
	if forced:
		_prop_forced[pid] = true
	var fi := _flying.find(i)
	if fi >= 0:
		_flying.remove_at(fi)
	var bi := mods.prop_bone[i]
	if target == "hidden":
		mods.prop_mode[i] = RigMods3D.MODE_HIDDEN
		for h in pr.hides:
			if def.props.has(h) and String(_prop_state.get(h, "")) == "hidden":
				_set_prop_state(h, (def.props[h] as RigDef3D.Prop).default_state, forced)
	else:
		for h2 in pr.hides:
			if def.props.has(h2) and String(_prop_state.get(h2, "")) != "hidden":
				_set_prop_state(h2, "hidden", forced)
		var so: RigDef3D.Socket = def.sockets.get(target, null)
		if target == "" or target == pr.home_socket or so == null or _rides(bi, skeleton.find_bone(so.bone)):
			# At home, or already riding the socket's bone: the clip drives it; the state only shows it.
			mods.prop_mode[i] = RigMods3D.MODE_HOME
		else:
			# Moved to another bone's socket, keeping its rest placement relative to its home socket.
			var sb := skeleton.find_bone(so.bone)
			var home: RigDef3D.Socket = def.sockets.get(pr.home_socket, so)
			var home_rest := skeleton.get_bone_global_rest(skeleton.find_bone(home.bone)) * home.local_xf()
			var rel := home_rest.affine_inverse() * skeleton.get_bone_global_rest(bi)
			mods.prop_mode[i] = RigMods3D.MODE_SOCKET
			mods.prop_sock_bone[i] = sb
			mods.prop_sock_xf[i] = so.local_xf() * rel
	if ok:
		_refresh_hidden_only()


## True when prop bone `bi` is the socket's bone or its direct child (it already rides that socket).
func _rides(bi: int, sock_bone: int) -> bool:
	return bi == sock_bone or skeleton.get_bone_parent(bi) == sock_bone


## Recomputes only the bones pass (a prop's state changed: hidden bones, scale fix); attachments are untouched.
func _refresh_hidden_only() -> void:
	if ok and not _refreshing:
		_refresh_bones_now()


## Launches a bone prop on a deterministic ballistic path from where it is now (vel m/s in the character's facing
## space: x forward, y up, z toward the camera; spin °/s). `at_f` = the timeline frame it left the hand.
func launch_prop(prop: String, vel: Vector3, spin_deg: float, at_f := -1.0) -> void:
	if not ok or not def.props.has(prop):
		return
	var i: int = _prop_index[prop]
	var bi := mods.prop_bone[i]
	if bi < 0:
		return
	var g := skeleton.get_bone_global_pose(bi)
	if mods.prop_mode[i] == RigMods3D.MODE_SOCKET and mods.prop_sock_bone[i] >= 0:
		g = skeleton.get_bone_global_pose(mods.prop_sock_bone[i]) * mods.prop_sock_xf[i]
	var start := _skel_to_world() * g
	# A prop keyed at scale 0 by the clip (a hidden extra) still leaves with a unit basis.
	start.basis = start.basis.orthonormalized() if absf(start.basis.determinant()) > 1e-9 else _skel_to_world().basis.orthonormalized()
	_fly_start[i] = start
	_fly_vel[i] = Vector3(vel.x * float(facing), vel.y, vel.z)
	_fly_spin[i] = spin_deg * float(facing)
	_fly_launch_f[i] = at_f if at_f >= 0.0 else _t
	_fly_clip[i] = _clip_id
	_fly_t[i] = 0.0
	mods.prop_mode[i] = RigMods3D.MODE_FLYING
	mods.prop_world_xf[i] = start
	_prop_state[prop] = "flying"
	if not _flying.has(i):
		_flying.append(i)


func _update_flying(dt: float) -> void:
	if _flying.is_empty():
		return
	var floor_y := global_position.y if is_inside_tree() else 0.0
	for i in _flying:
		var t: float
		if _external and _fly_clip[i] == _clip_id and _plan != null and not _plan.loop:
			# Frame-locked (a sim reaction): closed form in the clip's frames, so a seek or a replay lands identically.
			t = maxf(0.0, (_t - _fly_launch_f[i]) / 60.0)
			_fly_t[i] = t
		else:
			_fly_t[i] += dt
			t = _fly_t[i]
		mods.prop_world_xf[i] = PropSim3D.pose_at(_fly_start[i], _fly_vel[i], _fly_spin[i], t, floor_y)


## Attaches `node` to `socket` (snapped to it; `keep_world` keeps its world transform).
func attach(node: Node3D, socket: String, keep_world := false) -> void:
	var s := socket_node(socket)
	if s == null or node == null:
		return
	if node.get_parent() == null:
		s.add_child(node)
	else:
		node.reparent(s, keep_world)
	if not keep_world:
		node.transform = Transform3D.IDENTITY


## Detaches `node` from its socket into this player's parent (or the player), keeping its world transform.
func detach(node: Node3D) -> void:
	if node == null or node.get_parent() == null:
		return
	var target: Node = get_parent() if get_parent() != null else self
	node.reparent(target, true)


## The Node3D that follows `socket` (a lent set piece is parented to it); null when unknown.
func socket_node(socket: String) -> Node3D:
	if _sock_nodes.has(socket):
		return _sock_nodes[socket]
	# Not `ok`: setup builds the socket attachments before it sets `ok` (a skeleton is all this needs).
	if skeleton == null or def == null or not def.sockets.has(socket):
		return null
	var so: RigDef3D.Socket = def.sockets[socket]
	var ba := _bone_attachment(so.bone)
	if ba == null:
		return null
	var n := Node3D.new()
	n.name = "Sock_%s" % socket
	ba.add_child(n)
	n.transform = so.local_xf()
	_sock_nodes[socket] = n
	return n


func _bone_attachment(bone_name: String) -> BoneAttachment3D:
	if _bone_att.has(bone_name):
		return _bone_att[bone_name]
	if skeleton == null or skeleton.find_bone(bone_name) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "BA_%s" % bone_name
	skeleton.add_child(ba)
	ba.bone_name = bone_name
	_bone_att[bone_name] = ba
	return ba


## A socket's world transform (from the animated skeleton).
func socket_global(socket: String) -> Transform3D:
	if not ok or not def.sockets.has(socket):
		return global_transform if is_inside_tree() else Transform3D.IDENTITY
	var so: RigDef3D.Socket = def.sockets[socket]
	var bi: int = _sock_bone.get(socket, -2)
	if bi == -2:
		bi = skeleton.find_bone(so.bone)
		_sock_bone[socket] = bi
	return _skel_to_world() * (skeleton.get_bone_global_pose(bi) * so.local_xf())


## The head bone's world position.
func head_global() -> Vector3:
	return _bone_world(_bone("head"))


## The top of the character (the `head_top` socket, else the head + the descriptor height above the feet).
func top_global() -> Vector3:
	if ok and def.sockets.has("head_top"):
		return socket_global("head_top").origin
	var base := global_position if is_inside_tree() else Vector3.ZERO
	return base + Vector3(0.0, def.height_m if def != null else 1.6, 0.0)


## Between the feet (the `feet` socket, else the foot bones' midpoint).
func feet_global() -> Vector3:
	if ok and def.sockets.has("feet"):
		return socket_global("feet").origin
	var fl := _bone("foot_l")
	var fr := _bone("foot_r")
	if fl < 0 or fr < 0:
		return global_position if is_inside_tree() else Vector3.ZERO
	return (_bone_world(fl) + _bone_world(fr)) * 0.5


## A conservative world AABB from the head-top, hands, feet and pelvis (+ 0.08 m) — cheap, every frame.
func screen_aabb() -> AABB:
	var base := global_position if is_inside_tree() else Vector3.ZERO
	if not ok:
		var h := def.height_m if def != null else 1.6
		return AABB(base + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, h, 0.6))
	var b := AABB(top_global(), Vector3.ZERO)
	if _aabb_bones.is_empty():
		for role in AABB_ROLES:
			_aabb_bones.append(_bone(role))
	var xf := _skel_to_world()
	for bi in _aabb_bones:
		if bi >= 0:
			b = b.expand(xf * skeleton.get_bone_global_pose(bi).origin)
	return b.grow(0.08)


func _bone(role: String) -> int:
	if _bone_cache.has(role):
		return _bone_cache[role]
	var bn := def.bone(role, _ual_name(role)) if def != null else role
	var bi := skeleton.find_bone(bn) if skeleton != null else -1
	_bone_cache[role] = bi
	return bi


static func _ual_name(role: String) -> String:
	match role:
		"head":
			return "Head"
		"spine_top":
			return "spine_03"
		"neck":
			return "neck_01"
	return role


func _bone_world(bi: int) -> Vector3:
	if bi < 0 or skeleton == null:
		return global_position if is_inside_tree() else Vector3.ZERO
	return _skel_to_world() * skeleton.get_bone_global_pose(bi).origin


## Skeleton space → world (→ this node's space when not inside the tree).
func _skel_to_world() -> Transform3D:
	if is_inside_tree():
		return skeleton.global_transform
	var xf := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
