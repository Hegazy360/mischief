## RigSampler3D — samples a 3D clip on a rig without rendering (r3d-rig §4.3): the animation lint and the tests use it.
## The rig scene is instanced once per rig (cached) under the SceneTree root, hidden, with an AnimationPlayer (C++
## track application, deterministic: bones without a track sit at rest — exactly what RigPlayer3D shows); a sample
## is one `seek(frame / 60, true)`, then bone poses are read from the Skeleton3D. Local rotations / positions come from
## the skeleton's local poses (= the tracks, interpolated); globals are in MODEL space (the rig scene's root frame,
## Godot axes: +y up, the rig facing +z). No per-sample allocation in the instance API.
##   var s := RigSampler3D.for_rig("hush")
##   s.pose_at("hush/loco_walk", 12.0); var p := s.global_pos("foot_l")
##   RigSampler3D.sample("hush", "hush/loco_walk", 12.0) → {local_rot, local_pos, global_pos} (dictionaries by bone)
class_name RigSampler3D
extends RefCounted

static var _cache: Dictionary = {}

var def: RigDef3D = null
var ok: bool = false
var skeleton: Skeleton3D = null
var root: Node3D = null
var player: AnimationPlayer = null
var clip_id: String = ""
var frame: float = -1.0
var _to_model: Transform3D = Transform3D.IDENTITY
var _libs: Dictionary = {}


## The cached sampler of `rig_id` (and `variant`); `ok` false when the rig does not load.
static func for_rig(rig_id: String, variant := "") -> RigSampler3D:
	var key := "%s|%s" % [rig_id, variant]
	if _cache.has(key) and is_instance_valid((_cache[key] as RigSampler3D).root):
		return _cache[key]
	var s := RigSampler3D.new()
	s._setup(RigDef3D.load(rig_id, variant))
	_cache[key] = s
	return s


## Frees every cached sampler's nodes (tests, hot reload).
static func clear_cache() -> void:
	for k in _cache:
		(_cache[k] as RigSampler3D).free_nodes()
	_cache.clear()


## One-shot sample (allocates the result): {"local_rot": {bone: Quaternion}, "local_pos": {bone: Vector3},
## "global_pos": {bone: Vector3}} at `frame` of `clip_id`; {} when the rig or clip is missing.
static func sample(rig_id: String, p_clip_id: String, p_frame: float) -> Dictionary:
	var s := for_rig(rig_id)
	if not s.ok or not s.pose_at(p_clip_id, p_frame):
		return {}
	var lr: Dictionary = {}
	var lp: Dictionary = {}
	var gp: Dictionary = {}
	for i in s.skeleton.get_bone_count():
		var bn := s.skeleton.get_bone_name(i)
		lr[bn] = s.skeleton.get_bone_pose_rotation(i)
		lp[bn] = s.skeleton.get_bone_pose_position(i)
		gp[bn] = s._to_model * s.skeleton.get_bone_global_pose(i).origin
	return {"local_rot": lr, "local_pos": lp, "global_pos": gp}


func _setup(d: RigDef3D) -> void:
	def = d
	if not d.is_valid():
		return
	var ps := ResourceLoader.load(d.scene_path) as PackedScene
	if ps == null:
		return
	root = ps.instantiate() as Node3D
	if root == null:
		return
	root.name = "RigSampler3D_%s" % d.rig_id
	root.visible = false
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).active = false
	skeleton = root.get_node_or_null(NodePath(d.skeleton_path)) as Skeleton3D
	if skeleton == null:
		root.free()
		root = null
		return
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	player = AnimationPlayer.new()
	player.name = "SamplerPlayer"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.deterministic = true
	root.add_child(player)
	player.root_node = player.get_path_to(root)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		root.free()
		root = null
		return
	tree.root.add_child(root)
	# Skeleton space → the rig scene's root frame (the Armature node may carry a transform).
	var xf := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	_to_model = xf
	ok = true


## Removes the sampler's nodes from the tree.
func free_nodes() -> void:
	if root != null and is_instance_valid(root):
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.free()
	root = null
	skeleton = null
	player = null
	ok = false


## Applies `p_clip_id` at `p_frame` (clamped to the clip). False when the clip or its Animation is missing.
func pose_at(p_clip_id: String, p_frame: float) -> bool:
	if not ok:
		return false
	if p_clip_id != clip_id:
		var a := ClipLib3D.animation(p_clip_id)
		if a == null:
			return false
		var c := ClipLib3D.get_clip(p_clip_id)
		var lib_name := StringName(c.rig_id)
		var lib: AnimationLibrary = _libs.get(c.rig_id, null)
		if lib == null:
			lib = AnimationLibrary.new()
			player.add_animation_library(lib_name, lib)
			_libs[c.rig_id] = lib
		var an := StringName(c.name)
		if not lib.has_animation(an):
			lib.add_animation(an, a)
		elif lib.get_animation(an) != a:
			lib.remove_animation(an)
			lib.add_animation(an, a)
		player.play(StringName("%s/%s" % [c.rig_id, c.name]))
		clip_id = p_clip_id
		frame = -1.0
	var len_f := float(ClipLib3D.length(p_clip_id))
	var f := clampf(p_frame, 0.0, len_f)
	if f != frame:
		player.seek(f / 60.0, true)
		frame = f
	return true


## Index of `bone` (−1 when absent).
func bone_index(bone: String) -> int:
	return skeleton.find_bone(bone) if skeleton != null else -1


## Model-space transform of `bone` in the current pose.
func global_xf(bone: String) -> Transform3D:
	var bi := bone_index(bone)
	return _to_model * skeleton.get_bone_global_pose(bi) if bi >= 0 else Transform3D.IDENTITY


## Model-space position of `bone`; with `at_frame` ≥ 0 the current clip is posed there first.
func global_pos(bone: String, at_frame := -1.0) -> Vector3:
	if at_frame >= 0.0 and clip_id != "":
		pose_at(clip_id, at_frame)
	var bi := bone_index(bone)
	return _to_model * skeleton.get_bone_global_pose(bi).origin if bi >= 0 else Vector3.ZERO


## Local rotation of `bone` in the current pose.
func local_rot(bone: String) -> Quaternion:
	var bi := bone_index(bone)
	return skeleton.get_bone_pose_rotation(bi) if bi >= 0 else Quaternion.IDENTITY


## Local position of `bone` in the current pose.
func local_pos(bone: String) -> Vector3:
	var bi := bone_index(bone)
	return skeleton.get_bone_pose_position(bi) if bi >= 0 else Vector3.ZERO


## The angle (degrees) the bone's local rotation turns between frames f0 and f1 of the current clip — per-frame
## angular speed when f1 = f0 + 1.
func angle_delta_deg(bone: String, f0: float, f1: float) -> float:
	var bi := bone_index(bone)
	if bi < 0 or clip_id == "":
		return 0.0
	pose_at(clip_id, f0)
	var a := skeleton.get_bone_pose_rotation(bi)
	pose_at(clip_id, f1)
	var b := skeleton.get_bone_pose_rotation(bi)
	return rad_to_deg((a.inverse() * b).get_angle())


## Model-space height (y) of `bone` at `at_frame` (feet vs the floor).
func height(bone: String, at_frame := -1.0) -> float:
	return global_pos(bone, at_frame).y


## Model-space bounds of every bone origin at `at_frame` (+ nothing: bones only).
func aabb(at_frame := -1.0) -> AABB:
	if at_frame >= 0.0 and clip_id != "":
		pose_at(clip_id, at_frame)
	var b := AABB()
	for i in skeleton.get_bone_count():
		var p := _to_model * skeleton.get_bone_global_pose(i).origin
		b = AABB(p, Vector3.ZERO) if i == 0 else b.expand(p)
	return b
