## Jiggle3D — secondary motion for the cast (REDESIGN_3D §5.6: "secondary motion on jiggle bones,
## computed in the view, never in the sim").
##
## This is half the answer to "the movements feel too basic". The 2D rig animated every part from a
## keyframe, so a beret only moved when an animator moved it — and across 80 frames of
## `hush/loco_walk` it never does. Here the beret, braces, bouffant lobes, jowls, cravat and coat
## tails are driven by the *motion of the bone they hang off*: they lag into a turn, overshoot out
## of a stop, and settle. Nothing has to be keyed for a character to stop looking rigid.
##
## Model: one point mass per bone, sitting where the bone's tip would be if it were rigid, pulled
## toward that rest tip by a critically-ish damped spring in WORLD space, then projected back onto
## the bone's length and clamped to `max_deg`. Working in world space is what makes it react to the
## parent's translation as well as its rotation (a sidestep swings the coat tails; a pure local
## spring would not notice).
##
##   var j := Jiggle3D.new()
##   j.configure(rig, skeleton)
##   j.step(skeleton, delta)        # after the FK pose is written, before the skeleton is read
##
## Determinism: `step()` is a pure function of (previous state, transforms, dt). The sim never sees
## it, so a replay that re-renders is free to differ here without changing a single sim tick.
class_name Jiggle3D
extends RefCounted

## Below this the spring is treated as settled and skipped, so a still character costs nothing.
const SLEEP_EPS := 0.00002
## Clamp dt so a frame spike (or a breakpoint) cannot explode the spring.
const MAX_DT := 1.0 / 20.0

class Bone:
	var idx := -1
	var parent_idx := -1
	var rest_tip_local := Vector3.ZERO    # bone-space tip at rest
	var rest_dir := Vector3.FORWARD       # normalised rest_tip_local
	var length := 0.1
	var stiffness := 140.0
	var damping := 0.6
	var max_rad := 0.3
	var p := Vector3.ZERO                 # simulated tip, world space
	var v := Vector3.ZERO
	var primed := false

var _bones: Array[Bone] = []
var _enabled := true


## Resolve the rig's jiggle list against a real skeleton. Bones the mesh does not have are skipped
## with a warning rather than failing: a greybox stand-in has no bouffant.
func configure(rig: CastRig3D, skel: Skeleton3D) -> void:
	_bones.clear()
	if rig == null or skel == null:
		return
	for j in rig.jiggle:
		var name: String = j["bone"]
		var idx := skel.find_bone(name)
		if idx < 0:
			push_warning("Jiggle3D: %s has no bone '%s'" % [rig.rig_id, name])
			continue
		var b := Bone.new()
		b.idx = idx
		b.parent_idx = skel.get_bone_parent(idx)
		# The rest tip in bone space: the bone's own length down its local -Z... but the glTF
		# importer is free to orient bones however Blender did, so take it from the rest pose.
		var rest := skel.get_bone_rest(idx)
		b.length = maxf(0.01, rest.origin.length())
		b.rest_tip_local = Vector3(0, b.length, 0)
		b.rest_dir = Vector3(0, 1, 0)
		b.stiffness = float(j["stiffness"])
		b.damping = clampf(float(j["damping"]), 0.0, 0.999)
		b.max_rad = deg_to_rad(float(j["max_deg"]))
		_bones.append(b)


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		reset()


func bone_count() -> int:
	return _bones.size()


## Drop every spring back onto its rest tip. Called on a teleport, a retry or a camera cut, so the
## cast does not arrive in a new room trailing hair from the old one.
func reset() -> void:
	for b in _bones:
		b.primed = false
		b.v = Vector3.ZERO


## Advance every spring and write the resulting rotations into the skeleton's bone poses.
func step(skel: Skeleton3D, delta: float) -> void:
	if not _enabled or skel == null or _bones.is_empty():
		return
	var dt := minf(maxf(delta, 0.0), MAX_DT)
	if dt <= 0.0:
		return
	for b in _bones:
		_step_bone(skel, b, dt)


func _step_bone(skel: Skeleton3D, b: Bone, dt: float) -> void:
	# The bone's rest-pose world transform: where the tip would sit with no jiggle at all.
	var parent_world := skel.global_transform
	if b.parent_idx >= 0:
		parent_world = skel.global_transform * skel.get_bone_global_pose(b.parent_idx)
	var rest_world := parent_world * skel.get_bone_rest(b.idx)
	var target := rest_world * b.rest_tip_local

	if not b.primed:
		b.p = target
		b.v = Vector3.ZERO
		b.primed = true
		return

	# Spring toward the rest tip. `damping` is a per-second retention, converted to this frame.
	var to_target := target - b.p
	b.v += to_target * b.stiffness * dt
	b.v *= pow(1.0 - b.damping, dt * 60.0)
	b.p += b.v * dt

	var origin := rest_world.origin
	var dir := b.p - origin
	if dir.length_squared() < 1e-10:
		b.p = target
		return
	# Keep the bone rigid: the spring may only change the tip's DIRECTION, never its distance.
	dir = dir.normalized()
	var rest_dir_world := (target - origin).normalized()

	# Clamp the swing so nothing folds through the head.
	var ang := rest_dir_world.angle_to(dir)
	if ang > b.max_rad:
		var axis := rest_dir_world.cross(dir)
		if axis.length_squared() > 1e-12:
			dir = rest_dir_world.rotated(axis.normalized(), b.max_rad)
			ang = b.max_rad
	b.p = origin + dir * b.length

	if ang < SLEEP_EPS:
		return
	# Turn the world-space swing into a local rotation on top of the bone's rest pose.
	var axis_w := rest_dir_world.cross(dir)
	if axis_w.length_squared() < 1e-12:
		return
	var swing := Quaternion(axis_w.normalized(), ang)
	var parent_basis := parent_world.basis.orthonormalized()
	var local_axis := parent_basis.inverse() * swing.get_axis()
	var local_swing := Quaternion(local_axis.normalized(), swing.get_angle())
	var rest := skel.get_bone_rest(b.idx)
	skel.set_bone_pose_rotation(b.idx, local_swing * rest.basis.get_rotation_quaternion())
