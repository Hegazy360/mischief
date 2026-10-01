## HideSpot3D — a hiding spot on tonight's set (the pantry curtain, behind the piano, the coat cupboard): a Prop3D
## with the hide animations (`close` — the cloth or door swings shut, `wobble` 0.4 s after the dive, `breathe` — the
## cloth breathing while occupied, `burst` — the pop-out) and the **eye card** in the dark gap (REDESIGN §4.2 Hide
## AFTER): only Hush's eyes blink there and track him. The card uses Hush's face atlas cells `eyes_dark_open` /
## `eyes_dark_blink` / `pupils_dark` (r3d-cast-hush) when they exist, else two white discs with dark pupils.
class_name HideSpot3D
extends Prop3D

const FACE_ATLAS := "res://art3d/chars/hush/face_hush.png"
const PUPIL_RANGE := 0.03
const BLINK_S := 0.12
const EYE_R := 0.046
const EYE_DX := 0.058

var _eyes: Node3D = null
var _pupils: Array[Node3D] = []
var _whites: Array[Node3D] = []
var _look: Vector2 = Vector2.ZERO
var _blink_t: float = -1.0
var _breathe_t: float = 0.0
## The near-miss duck (r3d-fix-gags Q-G6): the eye card sinks DUCK_M out of sight while he peers at the gap, and pops
## back up (with a blink) once he turns away.
const DUCK_M := 0.24
const DUCK_S := 0.09
var _duck := false
var _duck_k := 0.0
var _eyes_y := 0.0
## The relieved squeeze after the near miss (eyes_phew): shut for SQUEEZE_S, a 0.08 s ease each way.
const SQUEEZE_S := 0.5
var _squeeze_t := -1.0


func setup(id: String, p_entry: Dictionary, xf: Transform3D, p_room: String, p_verb: String, p_live: bool,
		room_color: Color = Color(0.78, 0.71, 0.52), p_mats: SetMats = null, palette: Texture2D = null) -> void:
	super.setup(id, p_entry, xf, p_room, p_verb, p_live, room_color, p_mats, palette)
	_build_eyes()


func _build_eyes() -> void:
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	add_child(_eyes)
	_eyes.position = SetGeo.vec3(entry.get("eyes_anchor", [0.0, 1.1, 0.1])) * float(entry.get("scale", 1.0))
	# the card faces the camera (+z) whatever the prop's yaw; house3d `eyes_scale` enlarges it (r3d-fix-gags Q-G6:
	# her eyes in the gap must read in the near-miss two-shot)
	_eyes.rotation.y = -rotation.y
	var es := float(entry.get("eyes_scale", 1.0))
	_eyes.scale = Vector3(es, es, es)
	_eyes_y = _eyes.position.y
	var white := mats.get_mat(Color(0.97, 0.97, 0.95, 0.4), &"set")
	var dark := mats.get_mat(Color("#141018"), &"set")
	# sized to read at phone scale (each eye ≈ 12 px tall at 1200×540 from the base framing)
	for sx in [-1.0, 1.0]:
		var w := SetPrims._ball(_eyes, EYE_R, Vector3(EYE_DX * sx, 0.0, 0.0), white, Vector3(1.0, 1.25, 0.25), "eye_white")
		_whites.append(w)
		var p := SetPrims._ball(_eyes, EYE_R * 0.5, Vector3(EYE_DX * sx, 0.0, 0.016), dark, Vector3(1.0, 1.0, 0.3), "pupil")
		_pupils.append(p)
	_eyes.visible = false


## Shows the eye card in the dark gap (and starts the cloth breathing). Idempotent.
func set_occupied(on: bool) -> void:
	if on == _occupied:
		return
	_occupied = on
	if not on:
		_duck = false
		_squeeze_t = -1.0
	if _eyes != null:
		_eyes.visible = on
	if on:
		_breathe_t = 0.0
		_wake()


## The pupils look toward `dir` (−1…1 each axis; x toward +x on screen, y up).
func eyes_look(dir: Vector2) -> void:
	_look = dir.clamp(Vector2(-1, -1), Vector2(1, 1))
	for i in _pupils.size():
		var base := Vector3(EYE_DX * (-1.0 if i == 0 else 1.0), 0.0, 0.016)
		_pupils[i].position = base + Vector3(_look.x * PUPIL_RANGE, _look.y * PUPIL_RANGE * 0.6, 0.0)


## One blink (0.12 s: whites and pupils squash to a lid line).
func eyes_blink() -> void:
	if not _occupied:
		return
	_blink_t = 0.0
	_wake()


## The near-miss duck: `on` sinks the eyes out of sight in the gap (fast), off pops them back up with a blink.
func eyes_duck(on: bool) -> void:
	if on == _duck:
		return
	_duck = on
	if not on and _occupied:
		eyes_blink()
	_wake()


func ducking() -> bool:
	return _duck


## Her "phew" after the near miss (r3d-fix-gags2 Q2-G3): the eyes pop back up and squeeze shut in relief for
## SQUEEZE_S (whites and pupils pressed to a happy lid line), then open. The caller puffs the "phew" cloud from
## `eyes_world()`.
func eyes_phew() -> void:
	if not _occupied:
		return
	_duck = false
	_squeeze_t = 0.0
	_wake()


func squeezing() -> bool:
	return _squeeze_t >= 0.0


## The eye card's world position (the gap); the prop's origin when it has no card.
func eyes_world() -> Vector3:
	if _eyes != null and _eyes.is_inside_tree():
		return _eyes.global_position
	return global_position if is_inside_tree() else position


func look_dir() -> Vector2:
	return _look


func eyes_visible() -> bool:
	return _eyes != null and _eyes.visible


func _occupied_busy() -> bool:
	var busy := false
	var dt := get_process_delta_time() if is_inside_tree() else 1.0 / 60.0
	if _blink_t >= 0.0:
		_blink_t += dt
		var k := clampf(_blink_t / BLINK_S, 0.0, 1.0)
		var sy := 1.0 - sin(k * PI) * 0.92
		for w in _whites:
			w.scale.y = 1.25 * sy
		for p in _pupils:
			p.scale.y = sy
		if k >= 1.0:
			_blink_t = -1.0
		else:
			busy = true
	if _squeeze_t >= 0.0 and _blink_t < 0.0:
		_squeeze_t += dt
		var ks := clampf(minf(_squeeze_t, SQUEEZE_S - _squeeze_t) / 0.08, 0.0, 1.0)
		var sq := 1.0 - 0.85 * ks
		for w in _whites:
			w.scale.y = 1.25 * sq
		for p in _pupils:
			p.scale.y = sq
		if _squeeze_t >= SQUEEZE_S:
			_squeeze_t = -1.0
			for w in _whites:
				w.scale.y = 1.25
			for p in _pupils:
				p.scale.y = 1.0
		else:
			busy = true
	var dk := 1.0 if (_duck and _occupied) else 0.0
	if _duck_k != dk:
		_duck_k = move_toward(_duck_k, dk, dt / DUCK_S)
		if _eyes != null:
			_eyes.position.y = _eyes_y - DUCK_M * _duck_k * _duck_k * (3.0 - 2.0 * _duck_k)
		busy = true
	if _occupied:
		_breathe_t += dt
		var s := float(entry.get("scale", 1.0))
		_visual.scale = Vector3(s * (1.0 + 0.012 * sin(_breathe_t * TAU * 0.5)), s, s)
		busy = true
	return busy
