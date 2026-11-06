## KayActor — a character from the KayKit Adventurers pack (CC0), used EXACTLY as shipped, animated
## ONLY by the KayKit Character Animations library (CC0). Nothing here is re-dressed, re-rigged or
## hand-keyed: that is the whole rule of Prototype 3 (docs/review/pivot/next_options.md §D).
##
## The library .glb files carry the same 23-bone skeleton as the characters, so their clips are merged
## into one AnimationPlayer beside this character's Skeleton3D and rebound by bone name — the approach
## that measured jitter 0.13–0.18 in October (docs/review/oss_cast/index.md), against 0.42 for the
## cast this project built itself.
##
##     var k := KayActor.new(); add_child(k); k.setup("Knight")
##     k.play("Walking_A")            # loops
##     k.play("Hit_A")                # one-shot; `finished` tells you when
class_name KayActor
extends CharacterBody3D

signal finished(clip: String)

const ASSETS := "res://proto/toyhouse/assets/kaykit/"
const LIBRARIES: PackedStringArray = ["General", "MovementBasic", "MovementAdvanced", "Simulation",
	"Tools", "CombatMelee"]
## Clips that cycle. Everything else plays once and emits `finished`.
const LOOPING_PREFIXES: PackedStringArray = ["Idle", "Walking", "Running", "Sneaking", "Crouching",
	"Crawling", "Working", "Cheering", "Waving", "Melee_Unarmed_Idle", "Lie_Idle", "Sit_Chair_Idle",
	"Sit_Floor_Idle", "Holding", "Hammering", "Sawing", "Digging", "Chopping"]
const GRAVITY := 22.0
const TURN_RATE := 11.0
## How hard walking into a loose prop shoves it.
const PUSH := 2.6

static var _lib_cache: AnimationLibrary = null

var model: Node3D = null
var skeleton: Skeleton3D = null
var anim: AnimationPlayer = null
var current: String = ""
var height: float = 1.0
var radius: float = 0.3
## Yaw the body turns toward (radians).
var face_yaw: float = 0.0
var move_speed: float = 3.0


## Build from `assets/kaykit/<name>.glb`.
func setup(character: String, h: float = 1.0, r: float = 0.3) -> void:
	height = h
	radius = r
	var packed: PackedScene = load(ASSETS + character + ".glb")
	if packed == null:
		push_error("KayActor: cannot load %s" % character)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	skeleton = _find_skeleton(model)
	if skeleton == null:
		push_error("KayActor: no Skeleton3D in %s" % character)
		return
	anim = AnimationPlayer.new()
	anim.name = "Lib"
	skeleton.get_parent().add_child(anim)
	anim.add_animation_library("", _library(skeleton.name))
	anim.animation_finished.connect(func(n: StringName) -> void: finished.emit(String(n)))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position = Vector3(0, h * 0.5, 0)
	add_child(cs)
	play("Idle_A")


## Every library clip, loaded once per run and rebound to `<skeleton>:<bone>` paths.
static func _library(skel_name: String) -> AnimationLibrary:
	if _lib_cache != null:
		return _lib_cache
	var lib := AnimationLibrary.new()
	for l in LIBRARIES:
		var packed: PackedScene = load(ASSETS + "Rig_Medium_" + l + ".glb")
		if packed == null:
			push_warning("KayActor: missing library %s" % l)
			continue
		var inst := packed.instantiate()
		var src := _find_player(inst)
		if src != null:
			for ln in src.get_animation_library_list():
				var al := src.get_animation_library(ln)
				for clip in al.get_animation_list():
					if lib.has_animation(clip) or String(clip) == "T-Pose":
						continue
					var a := al.get_animation(clip).duplicate() as Animation
					for t in a.get_track_count():
						var bone := a.track_get_path(t).get_concatenated_subnames()
						if bone != "":
							a.track_set_path(t, NodePath("%s:%s" % [skel_name, bone]))
					a.loop_mode = Animation.LOOP_LINEAR if _loops(String(clip)) else Animation.LOOP_NONE
					lib.add_animation(clip, a)
		inst.free()
	_lib_cache = lib
	return lib


static func _loops(clip: String) -> bool:
	for p in LOOPING_PREFIXES:
		if clip.begins_with(p):
			return true
	return false


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_player(c)
		if r != null:
			return r
	return null


## Play a library clip (no-op if it is already the current loop). `blend` seconds of crossfade.
func play(clip: String, blend: float = 0.15, rate: float = 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		push_warning("KayActor: no clip '%s'" % clip)
		return
	if clip == current and anim.is_playing() and _loops(clip):
		return
	current = clip
	anim.play(clip, blend, rate)


func is_playing(clip: String) -> bool:
	return current == clip and anim != null and anim.is_playing()


## Length of a clip in seconds (0 when unknown).
func clip_len(clip: String) -> float:
	return anim.get_animation(clip).length if anim != null and anim.has_animation(clip) else 0.0


## Turn to face a world point (yaw only).
func face(point: Vector3) -> void:
	var d := point - global_position
	if d.length_squared() > 0.0001:
		face_yaw = atan2(d.x, d.z)


## Step toward `target` on the floor at `spd`; returns true when within `arrive`. Loose props in
## the way get shoved, which is half the toy.
func step_toward(target: Vector3, spd: float, delta: float, arrive: float = 0.25) -> bool:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= arrive:
		velocity.x = 0.0
		velocity.z = 0.0
		_fall(delta)
		move_and_slide()
		return true
	var dir := to / dist
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	face_yaw = atan2(dir.x, dir.z)
	_fall(delta)
	move_and_slide()
	_shove()
	return false


## Stand still this frame (gravity still applies).
func stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_fall(delta)
	move_and_slide()


func _fall(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta


func _shove() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body is RigidBody3D and not (body as RigidBody3D).freeze:
			(body as RigidBody3D).apply_central_impulse(-c.get_normal() * PUSH)


func _physics_process(delta: float) -> void:
	if model == null:
		return
	var cur := model.rotation.y
	model.rotation.y = lerp_angle(cur, face_yaw, 1.0 - pow(0.0001, delta * TURN_RATE / 11.0))


## Pick a loose prop up: kinematic-frozen and OUT of every collision layer, so it can never shove its
## own carrier. (A frozen body is a static collider by default; parked in front of the chest each frame
## it pushed the Rogue backwards, the crate followed, and the feedback loop fired her out of the hall.)
static func hold_prop(p: RigidBody3D) -> void:
	p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	p.freeze = true
	p.collision_layer = 0
	p.collision_mask = 0
	p.linear_velocity = Vector3.ZERO
	p.angular_velocity = Vector3.ZERO


## Let go of a held prop at `at` with velocity `vel`: back into the world and the physics.
static func release_prop(p: RigidBody3D, at: Vector3, vel: Vector3) -> void:
	p.global_position = at
	p.collision_layer = 1
	p.collision_mask = 1
	p.freeze = false
	p.linear_velocity = vel


## World point in front of the chest, where a carried prop sits.
func carry_point() -> Vector3:
	return global_position + Vector3(sin(face_yaw), 0, cos(face_yaw)) * (radius + 0.25) + Vector3(0, height * 0.72, 0)


## Forward direction on the floor.
func forward() -> Vector3:
	return Vector3(sin(face_yaw), 0, cos(face_yaw))
