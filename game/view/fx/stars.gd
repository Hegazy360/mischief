## FxStars — "seeing stars" (the door-frame bonk, `laugh_doorframe`; a bonk's head circle): four
## sparkles orbiting a point for 1 s. Two pooled orbits, one sparkle texture (batched).
class_name FxStars
extends Node2D

const ORBITS := 2
const LIFE_S := 1.1
const COUNT := 4

var _pos := PackedVector2Array()
var _t := PackedFloat32Array()
var _next := 0
var _tex: Texture2D = null
var _unit := 1.0


func _init() -> void:
	name = "Stars"
	z_index = 33
	_pos.resize(ORBITS)
	_t.resize(ORBITS)
	for i in ORBITS:
		_t[i] = 99.0


func _ready() -> void:
	_tex = FxArt.particle("sparkles")


## Stars around `world_pos` (a head, a door frame).
func spin(world_pos: Vector2) -> void:
	_pos[_next] = world_pos
	_t[_next] = 0.0
	_next = (_next + 1) % ORBITS
	queue_redraw()


func active_count() -> int:
	var n := 0
	for t in _t:
		if t < LIFE_S:
			n += 1
	return n


func clear() -> void:
	for i in ORBITS:
		_t[i] = 99.0
	queue_redraw()


func tick(dt: float, unit: float) -> void:
	_unit = unit
	var any := false
	for i in ORBITS:
		if _t[i] < LIFE_S:
			_t[i] += dt
			any = true
	if any:
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	for i in ORBITS:
		var t := _t[i]
		if t >= LIFE_S:
			continue
		var a := clampf((LIFE_S - t) / 0.25, 0.0, 1.0)
		for k in COUNT:
			var ang := t * 7.0 + TAU * float(k) / float(COUNT)
			var p := _pos[i] + Vector2(cos(ang) * 70.0, sin(ang) * 22.0) * _unit
			var s := (30.0 + 8.0 * sin(t * 20.0 + float(k))) * _unit
			draw_texture_rect(_tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 0.95, 0.6, a))
