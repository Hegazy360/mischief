## HideSpot3D — a hiding spot on tonight's set (the pantry curtain, behind the piano, the coat cupboard): a Prop3D
## with the hide animations (`close` — the cloth or door swings shut, `wobble` 0.4 s after the dive, `breathe` — the
## cloth breathing while occupied, `burst` — the pop-out) and the **eye card** in the dark gap (REDESIGN §4.2 Hide
## AFTER): only Hush's eyes blink there and track him. The card uses Hush's face atlas cells `eyes_dark_open` /
## `eyes_dark_blink` / `pupils_dark` (r3d-cast-hush) when they exist, else two white discs with dark pupils.
class_name HideSpot3D
extends Prop3D

const FACE_ATLAS := "res://art3d/chars/hush/face_hush.png"
const PUPIL_RANGE := 0.022
const BLINK_S := 0.12

var _eyes: Node3D = null
var _pupils: Array[Node3D] = []
var _whites: Array[Node3D] = []
var _look: Vector2 = Vector2.ZERO
var _blink_t: float = -1.0
var _breathe_t: float = 0.0


func setup(id: String, p_entry: Dictionary, xf: Transform3D, p_room: String, p_verb: String, p_live: bool,
		room_color: Color = Color(0.78, 0.71, 0.52), p_mats: SetMats = null, palette: Texture2D = null) -> void:
	super.setup(id, p_entry, xf, p_room, p_verb, p_live, room_color, p_mats, palette)
	_build_eyes()


func _build_eyes() -> void:
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	add_child(_eyes)
	_eyes.position = SetGeo.vec3(entry.get("eyes_anchor", [0.0, 1.1, 0.1])) * float(entry.get("scale", 1.0))
	# the card faces the camera (+z) whatever the prop's yaw
	_eyes.rotation.y = -rotation.y
	var white := mats.get_mat(Color(0.97, 0.97, 0.95, 0.4), &"set")
	var dark := mats.get_mat(Color("#141018"), &"set")
	for sx in [-1.0, 1.0]:
		var w := SetPrims._ball(_eyes, 0.034, Vector3(0.045 * sx, 0.0, 0.0), white, Vector3(1.0, 1.25, 0.25), "eye_white")
		_whites.append(w)
		var p := SetPrims._ball(_eyes, 0.017, Vector3(0.045 * sx, 0.0, 0.012), dark, Vector3(1.0, 1.0, 0.3), "pupil")
		_pupils.append(p)
	_eyes.visible = false


## Shows the eye card in the dark gap (and starts the cloth breathing). Idempotent.
func set_occupied(on: bool) -> void:
	if on == _occupied:
		return
	_occupied = on
	if _eyes != null:
		_eyes.visible = on
	if on:
		_breathe_t = 0.0
		_wake()


## The pupils look toward `dir` (−1…1 each axis; x toward +x on screen, y up).
func eyes_look(dir: Vector2) -> void:
	_look = dir.clamp(Vector2(-1, -1), Vector2(1, 1))
	for i in _pupils.size():
		var base := Vector3(0.045 * (-1.0 if i == 0 else 1.0), 0.0, 0.012)
		_pupils[i].position = base + Vector3(_look.x * PUPIL_RANGE, _look.y * PUPIL_RANGE * 0.6, 0.0)


## One blink (0.12 s: whites and pupils squash to a lid line).
func eyes_blink() -> void:
	if not _occupied:
		return
	_blink_t = 0.0
	_wake()


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
	if _occupied:
		_breathe_t += dt
		var s := float(entry.get("scale", 1.0))
		_visual.scale = Vector3(s * (1.0 + 0.012 * sin(_breathe_t * TAU * 0.5)), s, s)
		busy = true
	return busy
