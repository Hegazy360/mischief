## KnightNpc — the Knight (KayKit, as shipped) living his day in the hall. A routine of stations, each
## with a library activity; knocked flat by anything thrown hard enough; gets up, looks about, chases you
## if he sees you, and otherwise puts back whatever you moved — the "NPCs tidy up" loop that makes a
## sandbox feel alive. Every motion is a library clip.
class_name KnightNpc
extends KayActor

signal knocked_down
signal caught_player
signal state_changed(label: String)

enum S { ROUTINE_WALK, ROUTINE_ACT, HIT, DOWN, GETUP, ALERT, CHASE, CATCH, TIDY_WALK, TIDY_PICK, TIDY_CARRY, TIDY_PLACE }

const WALK := 2.4
const CHASE_SPEED := 5.6
const SEE_DIST := 11.0
const SEE_COS := 0.45          ## ~63 degrees either side
const CATCH_DIST := 1.5
const CHASE_MAX := 9.0
## A prop this fast, this close, knocks him down.
const HIT_SPEED := 4.5
const HIT_DIST := 1.4
const MESS_DIST := 1.5

## Each: {pos: Vector3, look: Vector3, clip: String, dur: float, sit: bool}
var stations: Array = []
var props: Array = []
var player: KayActor = null

var state: int = S.ROUTINE_WALK
var _st_i: int = 0
var _t: float = 0.0
var _hit_cool: float = 0.0
var _tidy: RigidBody3D = null
var _carrying: RigidBody3D = null
var _label: String = ""
var _stall_t: float = 0.0


## True once he has been barely moving for `after` seconds (blocked by something): treat it as arrived.
func _stalled(delta: float, after: float) -> bool:
	var flat := Vector2(velocity.x, velocity.z).length()
	_stall_t = _stall_t + delta if flat < 0.35 else 0.0
	if _stall_t >= after:
		_stall_t = 0.0
		return true
	return false


func begin() -> void:
	_goto_station(0)


func _goto_station(i: int) -> void:
	_st_i = i % maxi(1, stations.size())
	state = S.ROUTINE_WALK
	_set_label("on his rounds")


## A prop hit him.
func hit_by(prop: RigidBody3D) -> void:
	if state == S.HIT or state == S.DOWN or state == S.GETUP or _hit_cool > 0.0:
		return
	_hit_cool = 1.2
	_drop_carry()
	var from := prop.global_position
	var away := global_position - from
	away.y = 0.0
	velocity = away.normalized() * 2.5
	face(from)
	_t = 0.0
	state = S.HIT
	play("Hit_A", 0.05)
	_set_label("BONK")
	knocked_down.emit()


func _drop_carry() -> void:
	if _carrying != null and is_instance_valid(_carrying):
		KayActor.release_prop(_carrying, _carrying.global_position, Vector3.ZERO)
	_carrying = null
	_tidy = null


func _set_label(l: String) -> void:
	if l != _label:
		_label = l
		state_changed.emit(l)


func label() -> String:
	return _label


## Anything fast and close enough to clobber him this frame.
func _scan_hits() -> void:
	if _hit_cool > 0.0:
		return
	var chest := global_position + Vector3(0, height * 0.6, 0)
	for p: RigidBody3D in props:
		if not is_instance_valid(p) or p.freeze:
			continue
		if p.linear_velocity.length() < HIT_SPEED:
			continue
		if p.global_position.distance_to(chest) < HIT_DIST + 0.3 * p.get_meta("size", 1.0):
			hit_by(p)
			return


func _sees_player() -> bool:
	if player == null:
		return false
	var to := player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > SEE_DIST or d < 0.01:
		return false
	return forward().dot(to / d) > SEE_COS


## The prop furthest from its home, or null when the hall is tidy.
func _worst_mess() -> RigidBody3D:
	var worst: RigidBody3D = null
	var wd := MESS_DIST
	for p: RigidBody3D in props:
		if not is_instance_valid(p) or p.freeze:
			continue
		var home: Vector3 = p.get_meta("home", p.global_position)
		var d := p.global_position.distance_to(home)
		if d > wd:
			wd = d
			worst = p
	return worst


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_t += delta
	_hit_cool = maxf(0.0, _hit_cool - delta)
	if state != S.HIT and state != S.DOWN and state != S.GETUP:
		_scan_hits()
	match state:
		S.ROUTINE_WALK:
			var st: Dictionary = stations[_st_i]
			# a generous arrival radius: furniture and loose props can hold him short of the exact spot
			if step_toward(st["pos"], WALK, delta, 0.6) or _stalled(delta, 1.2):
				face(st["look"])
				_t = 0.0
				state = S.ROUTINE_ACT
				if bool(st.get("sit", false)):
					play("Sit_Chair_Down", 0.1)
				else:
					play(str(st["clip"]), 0.2)
				_set_label(str(st.get("label", "busy")))
			else:
				play("Walking_A")
		S.ROUTINE_ACT:
			stand(delta)
			var st: Dictionary = stations[_st_i]
			var dur := float(st.get("dur", 4.0))
			if bool(st.get("sit", false)):
				if _t > 1.0 and current == "Sit_Chair_Down" and not anim.is_playing():
					play("Sit_Chair_Idle")
				if _t >= dur and current == "Sit_Chair_Idle":
					play("Sit_Chair_StandUp", 0.1)
				if current == "Sit_Chair_StandUp" and not anim.is_playing():
					_after_activity()
			elif _t >= dur:
				_after_activity()
		S.HIT:
			_fall(delta)
			velocity.x *= 0.9
			velocity.z *= 0.9
			move_and_slide()
			if _t >= 0.45:
				_t = 0.0
				state = S.DOWN
				play("Death_A", 0.05)
				_set_label("knocked flat")
		S.DOWN:
			stand(delta)
			if current == "Death_A" and not anim.is_playing():
				play("Lie_Idle", 0.2)
			if _t >= 2.6:
				_t = 0.0
				state = S.GETUP
				play("Lie_StandUp", 0.1)
				_set_label("getting up")
		S.GETUP:
			stand(delta)
			if current == "Lie_StandUp" and not anim.is_playing():
				_t = 0.0
				state = S.ALERT
				play("Idle_B", 0.2)
				_set_label("looking around")
		S.ALERT:
			stand(delta)
			if player != null and _t > 0.3:
				face(player.global_position)
			if _t >= 1.1:
				if _sees_player():
					_t = 0.0
					state = S.CHASE
					_set_label("CHASING YOU")
				else:
					_after_activity()
		S.CHASE:
			if player == null:
				_goto_station(_st_i + 1)
			elif global_position.distance_to(player.global_position) < CATCH_DIST:
				_t = 0.0
				state = S.CATCH
				play("Melee_Unarmed_Attack_Punch_A", 0.05)
				_set_label("GOT YOU")
				caught_player.emit()
			elif _t > CHASE_MAX or not _sees_player() and _t > 2.0 and global_position.distance_to(player.global_position) > 7.0:
				_t = 0.0
				state = S.ALERT
				play("Idle_B", 0.2)
				_set_label("lost you")
			else:
				step_toward(player.global_position, CHASE_SPEED, delta, CATCH_DIST * 0.8)
				play("Running_A")
		S.CATCH:
			stand(delta)
			if _t >= 0.6 and current != "Cheering":
				play("Cheering", 0.2)
			if _t >= 2.2:
				_after_activity()
		S.TIDY_WALK:
			if _tidy == null or not is_instance_valid(_tidy) or _tidy.freeze:
				_after_activity()
			elif step_toward(_tidy.global_position, WALK, delta, 1.3):
				face(_tidy.global_position)
				_t = 0.0
				state = S.TIDY_PICK
				play("PickUp", 0.1)
			else:
				play("Walking_A")
		S.TIDY_PICK:
			stand(delta)
			if _t >= 0.5 and _carrying == null and _tidy != null and is_instance_valid(_tidy) and not _tidy.freeze:
				_carrying = _tidy
				KayActor.hold_prop(_carrying)
			if _t >= 1.0:
				if _carrying == null:
					_after_activity()
				else:
					state = S.TIDY_CARRY
					_set_label("tidying up")
		S.TIDY_CARRY:
			if _carrying == null or not is_instance_valid(_carrying):
				_after_activity()
			else:
				var home: Vector3 = _carrying.get_meta("home", global_position)
				if step_toward(Vector3(home.x, global_position.y, home.z), WALK, delta, 1.0):
					_t = 0.0
					state = S.TIDY_PLACE
					play("Interact", 0.1)
				else:
					play("Walking_A")
		S.TIDY_PLACE:
			stand(delta)
			if _t >= 0.4 and _carrying != null and is_instance_valid(_carrying):
				var home: Vector3 = _carrying.get_meta("home", global_position)
				KayActor.release_prop(_carrying, home, Vector3.ZERO)
				_carrying.rotation = Vector3.ZERO
				_carrying.angular_velocity = Vector3.ZERO
				_carrying = null
				_tidy = null
			if _t >= 1.0:
				_after_activity()
	if _carrying != null and is_instance_valid(_carrying):
		_carrying.global_position = carry_point()
		_carrying.rotation = Vector3(0, face_yaw, 0)


## What he does once an activity, a chase or a tidy is over: tidy next, else the next station.
func _after_activity() -> void:
	var mess := _worst_mess()
	if mess != null:
		_tidy = mess
		_t = 0.0
		state = S.TIDY_WALK
		_set_label("noticed a mess")
		return
	_goto_station(_st_i + 1)
