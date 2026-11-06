## RoguePlayer — you. Tap-to-move (Sneaky Sasquatch's scheme, no joystick), pick up anything loose,
## carry it, throw it. Every clip is KayKit library: Idle_A, Walking_A, Running_A, PickUp, Throw, Hit_A.
class_name RoguePlayer
extends KayActor

signal threw(prop: RigidBody3D)

enum S { IDLE, MOVE, TO_PROP, PICKUP, HOLD, THROW, HIT }

const WALK := 2.8
const RUN := 6.4
const RUN_FROM := 3.5
const GRAB_REACH := 2.4
## Blocked on the way to a prop (a stack in front of it) but this close: reach over and take it anyway.
const GRAB_STALL_REACH := 3.4
const THROW_MIN := 7.0
const THROW_MAX := 17.0

var state: int = S.IDLE
var target: Vector3 = Vector3.ZERO
var want_prop: RigidBody3D = null
var held: RigidBody3D = null
var _t: float = 0.0
var _throw_dir: Vector3 = Vector3.FORWARD
var _throw_speed: float = 10.0
var _released: bool = false
var _stall_t: float = 0.0


## Walk or run to a floor point (carrying whatever is held).
func go_to(p: Vector3) -> void:
	if state == S.HIT or state == S.THROW or state == S.PICKUP:
		return
	target = p
	want_prop = null
	state = S.MOVE


## Go and pick a prop up.
func grab(prop: RigidBody3D) -> void:
	if state == S.HIT or state == S.THROW or state == S.PICKUP or held != null:
		return
	want_prop = prop
	target = prop.global_position
	state = S.TO_PROP


## Throw the held prop at a world point (aimed), or straight ahead when `aimed` is false.
func throw_at(p: Vector3, aimed: bool = true) -> void:
	if held == null or state == S.THROW or state == S.HIT:
		return
	var from := carry_point()
	var to := p if aimed else from + forward() * 6.0
	var flat := to - from
	var dist := flat.length()
	flat.y = 0.0
	face(to)
	_throw_dir = (to - from).normalized()
	_throw_dir.y += 0.22
	_throw_dir = _throw_dir.normalized()
	_throw_speed = clampf(dist * 1.7, THROW_MIN, THROW_MAX)
	_released = false
	_t = 0.0
	state = S.THROW
	play("Throw", 0.08)


## Caught or clobbered: stagger back, drop whatever is held.
func knocked(from: Vector3) -> void:
	_drop()
	var away := global_position - from
	away.y = 0.0
	velocity = away.normalized() * 6.0 + Vector3(0, 3.0, 0)
	face(from)
	_t = 0.0
	state = S.HIT
	play("Hit_A", 0.05)


func is_holding() -> bool:
	return held != null


func _drop() -> void:
	if held == null:
		return
	KayActor.release_prop(held, held.global_position, Vector3.ZERO)
	held = null


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_t += delta
	match state:
		S.IDLE:
			stand(delta)
			play("Holding_B" if held != null else "Idle_A")
		S.MOVE:
			var far := global_position.distance_to(target) > RUN_FROM
			var spd := RUN if far and held == null else WALK
			if step_toward(target, spd, delta):
				state = S.IDLE
			else:
				play("Running_A" if spd == RUN else "Walking_A")
		S.TO_PROP:
			if want_prop == null or not is_instance_valid(want_prop):
				state = S.IDLE
			else:
				var arrived := step_toward(want_prop.global_position, RUN, delta, GRAB_REACH)
				var flat := Vector2(velocity.x, velocity.z).length()
				_stall_t = _stall_t + delta if flat < 0.4 else 0.0
				var close := global_position.distance_to(want_prop.global_position) < GRAB_STALL_REACH
				if arrived or (_stall_t > 0.35 and close):
					_stall_t = 0.0
					face(want_prop.global_position)
					_t = 0.0
					state = S.PICKUP
					play("PickUp", 0.08)
				else:
					play("Running_A")
		S.PICKUP:
			stand(delta)
			if _t >= 0.45 and held == null and want_prop != null and is_instance_valid(want_prop):
				held = want_prop
				KayActor.hold_prop(held)
				want_prop = null
			if _t >= 0.9:
				state = S.IDLE
		S.HOLD:
			stand(delta)
		S.THROW:
			stand(delta)
			if _t >= 0.3 and not _released and held != null:
				_released = true
				var p := held
				held = null
				KayActor.release_prop(p, carry_point() + _throw_dir * 0.6, _throw_dir * _throw_speed)
				p.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
				threw.emit(p)
			if _t >= 0.75:
				state = S.IDLE
		S.HIT:
			_fall(delta)
			velocity.x *= 0.92
			velocity.z *= 0.92
			move_and_slide()
			if _t >= 1.0:
				state = S.IDLE
	if held != null and is_instance_valid(held):
		held.global_position = carry_point()
		held.rotation = Vector3(0, face_yaw, 0)
