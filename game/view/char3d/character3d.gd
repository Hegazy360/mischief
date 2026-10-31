## Character3D — one 3D cast member (REDESIGN_3D §5.6). The 3D replacement for `view/rig/rig_player.gd`.
##
## Everything upstream of the draw is the 2D pipeline, unchanged: `ClipLib` loads the clip,
## `RigSampler` samples and blends it, `ClipEvents` fires its sfx / face / shake / smear events on
## the same frames. `PoseRetarget3D` then writes the sampled pose onto a Skeleton3D instead of a
## stack of cutouts, and four procedural layers — which a 2D cutout rig could not have — run on
## top. Those layers are the answer to "the movements feel too basic":
##
##   1. **Jiggle** (`Jiggle3D`): beret, braces, bouffant, jowls, cravat, coat tails lag and settle.
##   2. **Foot grounding** (`Ik3D.ground`): the stance foot stays on the floor at any walk speed,
##      so nothing skates — the 2D rig could only match one authored `stride_px`.
##   3. **Squash & stretch**: the root's authored sx/sy become a volume-preserving 3D squash, so an
##      accent reads as weight rather than a scale pop.
##   4. **Moving holds**: breathing and a slow drift mean a "still" character is never dead-still,
##      the single biggest tell of a cheap animation.
##
##   var c := Character3D.new(); add_child(c); c.setup("hush")
##   c.play("hush/loco_walk", {"speed": 400.0})
##   c.set_face("sneak")
##
## Draw calls: one skinned mesh + one inverted-hull outline pass (`next_pass`) = 2 per character,
## inside the §5.6 budget of ≤ 4.
class_name Character3D
extends Node3D

## Every clip event as its frame is crossed (same payload as RigPlayer.clip_event).
signal clip_event(ev: Dictionary)
signal clip_finished(clip_id: String)

const TOON_SHADER := "res://art3d/shaders/cast_toon.gdshader"
const OUTLINE_SHADER := "res://art3d/shaders/cast_outline.gdshader"
const PALETTE_TEX := "res://art3d/cast/cast_palette.png"

## Breathing: amplitude in metres of chest rise, and its period.
const BREATH_M := 0.009
const BREATH_HZ := 0.28
## Moving-hold drift: a sub-degree sway so a held pose never freezes solid.
const DRIFT_DEG := 0.55
const DRIFT_HZ := 0.17
## Grounding lift follow rate (1/s). See _smooth_lift.
const LIFT_RATE := 18.0

var rig_id := ""
var rig3d: CastRig3D = null
var rig2d: RigDef = null
var skeleton: Skeleton3D = null
var mesh_instance: MeshInstance3D = null

var jiggle := Jiggle3D.new()
var retarget: PoseRetarget3D = null

## Where the character stands on the stage. The animation's root offset is added to this every
## frame, so placing a character never fights the clip (and a clip never teleports one home).
var base_position := Vector3.ZERO
## Floor the character stands on, world Y. The cast walks one lane (§5.1), so a height is enough.
var floor_y := 0.0
var ground_weight := 1.0
var facing := 1

var _toon: ShaderMaterial = null
var _outline: ShaderMaterial = null
var _clip: ClipDef = null
var _clip_id := ""
var _frame := 0.0
var _speed := 0.0
var _loop := true
var _pose := PackedFloat32Array()
var _rest := PackedFloat32Array()
var _time := 0.0
var _seed := 0.0
var _manual := false
var _face_preset := ""
var _lift := 0.0
var _ok := false


## Build the character: load the glTF, swap in the toon + outline materials, resolve the rig.
## Returns false (and leaves the node empty) when the art or the rig data is missing, so the
## caller can fall back to a greybox stand-in rather than losing the Night.
func setup(rig: String) -> bool:
	rig_id = rig
	rig3d = CastRig3D.load_rig(rig)
	if rig3d == null:
		return false
	rig2d = RigDef.for_id(rig)
	if rig2d == null:
		push_error("Character3D: no 2D rig '%s' to take clips from" % rig)
		return false

	var packed: PackedScene = load(rig3d.mesh_path)
	if packed == null:
		push_error("Character3D: cannot load %s" % rig3d.mesh_path)
		return false
	var inst := packed.instantiate()
	add_child(inst)
	skeleton = _find_skeleton(inst)
	mesh_instance = _find_mesh(inst)
	if skeleton == null or mesh_instance == null:
		push_error("Character3D: %s has no skinned mesh" % rig3d.mesh_path)
		return false

	_build_materials()
	retarget = PoseRetarget3D.build(rig3d, rig2d, skeleton)
	for m in retarget.missing():
		push_warning("Character3D(%s): %s" % [rig, m])
	jiggle.configure(rig3d, skeleton)
	_rest = rig2d.rest.duplicate()
	_pose = _rest.duplicate()
	_seed = float(hash(rig)) * 0.001
	_ok = retarget.is_valid()
	set_process(_ok and not _manual)
	return _ok


func is_ready() -> bool:
	return _ok


## Tool mode: `_process` stops advancing and the caller drives `advance(dt)` (sheets, tests).
func set_manual(on: bool) -> void:
	_manual = on
	set_process(_ok and not on)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null


func _build_materials() -> void:
	_toon = ShaderMaterial.new()
	_toon.shader = load(TOON_SHADER)
	var pal: Texture2D = load(PALETTE_TEX)
	if pal != null:
		_toon.set_shader_parameter("palette", pal)
	var face: Texture2D = load(rig3d.face_atlas_path)
	if face != null:
		_toon.set_shader_parameter("face_atlas", face)
	for layer in ["brows", "eyes", "mouth", "extra"]:
		_toon.set_shader_parameter("%s_band" % layer, rig3d.face_band(layer))

	# The outline rides as a second pass on the same mesh: one MeshInstance, two draw calls.
	_outline = ShaderMaterial.new()
	_outline.shader = load(OUTLINE_SHADER)
	_toon.next_pass = _outline

	# `material_override` rather than per-surface overrides: a glTF import has no override slots
	# populated, so set_surface_override_material() silently wrote nothing and the imported
	# StandardMaterial3D kept drawing.
	mesh_instance.material_override = _toon
	set_face("neutral")


# --- playback ------------------------------------------------------------------------------------

## Play a clip id (`"hush/loco_walk"`). Opts: `speed` (px/s, for a clip with `stride_px`),
## `loop` (defaults to the clip's own), `from` (start frame).
func play(clip_id: String, opts := {}) -> void:
	var c := ClipLib.get_clip(clip_id)
	if c == null:
		push_warning("Character3D(%s): no clip '%s'" % [rig_id, clip_id])
		return
	_clip = c
	_clip_id = clip_id
	_frame = float(opts.get("from", 0.0))
	_loop = bool(opts.get("loop", c.loop))
	_speed = float(opts.get("speed", 0.0))


func clip_id() -> String:
	return _clip_id


func frame() -> float:
	return _frame


## Walk speed in sim px/s. A clip with `stride_px` is time-scaled so the feet match the ground,
## and `Ik3D.ground` pins whatever is left — together they are why nothing skates.
func set_speed(px_per_s: float) -> void:
	_speed = px_per_s


func set_facing(dir: int) -> void:
	facing = -1 if dir < 0 else 1
	# Turning the whole node keeps the outline, the face card and the jiggle consistent; the
	# "cheat out" yaw of §5.1 is applied by the staging code on top of this.
	rotation.y = 0.0 if facing > 0 else PI


func _process(delta: float) -> void:
	advance(delta)


## Advance the animation by `dt` seconds and rebuild the pose. Safe to call with dt = 0 to re-pose.
func advance(dt: float) -> void:
	if not _ok:
		return
	_time += dt
	# A clip with `stride_px` plays at speed / (stride / cycle_seconds) so the feet match the
	# ground at any sim speed — the same rule as RigPlayer, now backed up by foot grounding.
	var rate := 60.0
	if _clip != null and _speed > 0.0 and _clip.stride_px > 0.0 and _clip.length > 0:
		var cycle_s := float(_clip.length) / 60.0
		rate = 60.0 * (_speed / (_clip.stride_px / cycle_s))
	var before := _frame
	_frame += dt * rate

	if _clip != null:
		var ln := float(maxi(1, _clip.length))
		if _loop:
			_frame = fposmod(_frame, ln)
		elif _frame >= ln:
			_frame = ln
			if before < ln:
				clip_finished.emit(_clip_id)
		RigSampler.sample(_clip, _frame, _pose)
	else:
		RigSampler.copy(_rest, _pose)

	_pump_events(before, _frame)
	_apply_pose(dt)


## Fire every clip event whose frame the last step crossed. `ClipEvents.between` is the same
## collector RigPlayer uses, so a 3D character emits the identical sfx / face / shake / smear
## stream the audio director and the FX layer already listen for.
func _pump_events(from_f: float, to_f: float) -> void:
	if _clip == null or is_equal_approx(from_f, to_f):
		return
	for e in ClipEvents.between(_clip, from_f, to_f):
		if e is Dictionary:
			clip_event.emit(e)


func _apply_pose(dt: float) -> void:
	if skeleton == null or retarget == null:
		return
	skeleton.reset_bone_poses()
	var root_off := retarget.apply(skeleton, _pose)

	_moving_hold()
	# Squash & stretch: the authored root sx/sy, with depth following width so volume is kept.
	var sq := PoseRetarget3D.root_scale(_pose)
	skeleton.scale = sq

	position = base_position + Vector3(root_off.x * facing, root_off.y, 0.0)

	# ORDER MATTERS, and getting it wrong is what made the first cut of this vibrate.
	#
	# Grounding must be solved from the FK-ONLY pose and the body moved to its final place BEFORE
	# the springs run. The earlier order (jiggle, then move the body) gave the springs a world-space
	# target computed from a position that grounding then changed, so every frame they chased where
	# the body had been one frame ago. Two feedback loops on one skeleton, oscillating at 2-3 frames
	# — measured at jitter 0.42 against 0.14-0.23 for a clean clip (tools/anim/stability.py).
	#
	# 1. Grounding, from the FK pose, in two steps: move the BODY so the lowest sole meets the
	#    floor, then IK only the residual (a leg cannot stretch, so IK alone would leave a
	#    root-lifted clip hanging in the air on straight legs).
	if ground_weight > 0.0:
		var lift := Ik3D.ground_offset(skeleton, rig3d, floor_y, ground_weight)
		position.y += _smooth_lift(lift, dt)
		Ik3D.plant_feet(skeleton, rig3d, floor_y, ground_weight)

	# 2. Springs last, against a body that is already where it will be drawn. They see real motion
	#    only, never a correction.
	jiggle.step(skeleton, dt)


## Smooth the grounding lift so a single odd frame (a clip key that drops a foot through the floor,
## a blend crossing a contact) cannot step the whole body. Critically damped, ~4 frames to settle:
## fast enough that a stair or a stool reads as instant, slow enough that it never pumps.
func _smooth_lift(target: float, dt: float) -> float:
	if dt <= 0.0:
		_lift = target
		return _lift
	var k := 1.0 - exp(-LIFT_RATE * dt)
	_lift += (target - _lift) * k
	if absf(target - _lift) < 0.0002:
		_lift = target
	return _lift


## Breathing + a slow sway, so a held pose is never dead-still (comedy.md: the moving hold).
func _moving_hold() -> void:
	if skeleton == null:
		return
	var t := _time + _seed
	var chest := skeleton.find_bone("chest")
	if chest >= 0:
		var amount := sin(t * TAU * BREATH_HZ) * 0.5 + 0.5
		var q := skeleton.get_bone_pose_rotation(chest)
		skeleton.set_bone_pose_rotation(chest, q * Quaternion(Vector3(0, 0, 1), deg_to_rad(amount * 1.3)))
		var p := skeleton.get_bone_pose_position(chest)
		skeleton.set_bone_pose_position(chest, p + Vector3(0, amount * BREATH_M, 0))
	var pelvis := skeleton.find_bone("pelvis")
	if pelvis >= 0:
		var drift := sin(t * TAU * DRIFT_HZ + 1.7) * DRIFT_DEG
		var q := skeleton.get_bone_pose_rotation(pelvis)
		skeleton.set_bone_pose_rotation(pelvis, q * Quaternion(Vector3(0, 1, 0), deg_to_rad(drift)))


# --- face ----------------------------------------------------------------------------------------

## Set a named face preset from the atlas (`neutral`, `sneak`, `shock`, `furious`, …). Unknown
## presets are ignored and warned once, never cleared — a missing expression must not blank a face.
func set_face(preset: String) -> void:
	if rig3d == null or _toon == null:
		return
	if not rig3d.face_presets.has(preset):
		if preset != "":
			push_warning("Character3D(%s): no face preset '%s'" % [rig_id, preset])
		return
	_face_preset = preset
	var p: Dictionary = rig3d.face_presets[preset]
	for layer in ["brows", "eyes", "mouth", "extra"]:
		var cell := String(p.get(layer, "none"))
		_toon.set_shader_parameter("%s_cell" % layer, rig3d.face_cell(layer, cell))


func face_preset() -> String:
	return _face_preset


## Move the pupils without a new atlas cell (look-at). `offset` is in face-square units, ±0.05 is
## a strong glance.
func set_pupils(offset: Vector2) -> void:
	if _toon != null:
		_toon.set_shader_parameter("pupil", offset)


## Temper tint, 0..1: peach → beetroot on skin-flagged paint only (GDD §1.2).
func set_temper(t: float) -> void:
	if _toon != null:
		_toon.set_shader_parameter("temper", clampf(t, 0.0, 1.0))


## Stage dimmer, 0..1, shared by the toon and outline passes so a dimmed character stays coherent.
func set_stage(level: float) -> void:
	var l := clampf(level, 0.0, 1.0)
	if _toon != null:
		_toon.set_shader_parameter("stage", l)
	if _outline != null:
		_outline.set_shader_parameter("stage", l)


func set_outline_px(px: float) -> void:
	if _outline != null:
		_outline.set_shader_parameter("width_1080", maxf(0.0, px))
