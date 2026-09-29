## FxNoiseRings — every noise draws an expanding ring to its TRUE radius over 0.5 s (6 px,
## alpha 0.5 → 0; GDD §3.9): squeaks yellow, runs and rigs white, so the lure radius is
## learnable. Pooled (8 rings), drawn as batched line segments. View time (a ring slows
## down with the world during slow-mo).
class_name FxNoiseRings
extends Node2D

const RINGS := 8
const LIFE := 0.5
const SEGMENTS := 48
const SQUEAK := Color("#FFD23F")
const WHITE := Color("#FFFFFF")

var _pos := PackedVector2Array()
var _r := PackedFloat32Array()
var _t := PackedFloat32Array()
var _c := PackedColorArray()
var _next := 0
var _unit := 1.0


func _init() -> void:
	name = "NoiseRings"
	visibility_layer = 2
	z_index = 25
	_pos.resize(RINGS)
	_r.resize(RINGS)
	_t.resize(RINGS)
	_c.resize(RINGS)
	for i in RINGS:
		_t[i] = 99.0


## Start a ring at `world_pos` growing to `radius` world px.
func ring(world_pos: Vector2, radius: float, color: Color) -> void:
	_pos[_next] = world_pos
	_r[_next] = maxf(20.0, radius)
	_t[_next] = 0.0
	_c[_next] = color
	_next = (_next + 1) % RINGS
	queue_redraw()


## Drop every ring (retry / seek).
func clear() -> void:
	for i in RINGS:
		_t[i] = 99.0
	queue_redraw()


## Rings currently alive (tests).
func alive() -> int:
	var n := 0
	for i in RINGS:
		if _t[i] < LIFE:
			n += 1
	return n


func tick(dt: float, unit: float) -> void:
	_unit = unit
	var any := false
	for i in RINGS:
		if _t[i] < LIFE:
			_t[i] += dt
			any = true
	if any:
		queue_redraw()


func _draw() -> void:
	for i in RINGS:
		var t := _t[i]
		if t >= LIFE:
			continue
		var u := t / LIFE
		var r := _r[i] * ViewKit.ease_out_cubic(u)
		var col := Color(_c[i], 0.5 * (1.0 - u))
		var w := 6.0 * _unit
		var prev := _pos[i] + Vector2(r, 0)
		for k in range(1, SEGMENTS + 1):
			var a := TAU * float(k) / float(SEGMENTS)
			var p := _pos[i] + Vector2(cos(a), sin(a)) * r
			draw_line(prev, p, col, w)
			prev = p
