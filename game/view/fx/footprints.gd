## FxFootprints — Bellows' walking line for the next 1.5 s as faint slipper prints on the
## floor (GDD §3.9), shown whenever he is in Hush's room or the next one. Points come from
## `bellows_path_preview` (via the snapshot). Up to 14 prints, one texture (batched), fading
## in and out as the preview changes.
class_name FxFootprints
extends Node2D

const MAX_PRINTS := 14
const STEP_PX := 56.0
const COLOR := Color("#2A1E3A")
const ALPHA := 0.32

var _p := PackedVector2Array()
var _f := PackedFloat32Array()
var _n := 0
var _a := 0.0
var _want := 0.0
var _tex: Texture2D = null


func _init() -> void:
	name = "Footprints"
	visibility_layer = 2
	z_index = -3
	_p.resize(MAX_PRINTS)
	_f.resize(MAX_PRINTS)


func _ready() -> void:
	_tex = FxArt.sprite("footprint")


## Lay prints along `points` (world, on the floor line). Empty = fade out.
func footprints(points: PackedVector2Array) -> void:
	_n = 0
	_want = 0.0 if points.size() < 2 else 1.0
	if points.size() < 2:
		queue_redraw()
		return
	var carry := STEP_PX * 0.5
	var k := 0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg < 1.0:
			continue
		var dir := signf(b.x - a.x)
		var d := carry
		while d < seg and _n < MAX_PRINTS:
			var p := a.lerp(b, d / seg)
			p.y += -6.0 if k % 2 == 0 else 4.0
			_p[_n] = p
			_f[_n] = dir
			_n += 1
			k += 1
			d += STEP_PX
		carry = d - seg
	queue_redraw()


func visible_prints() -> int:
	return _n if _a > 0.01 else 0


func tick(dt: float) -> void:
	var a0 := _a
	_a = move_toward(_a, _want, dt * 4.0)
	if _a != a0:
		queue_redraw()


func _draw() -> void:
	if _tex == null or _a <= 0.0:
		return
	for i in _n:
		var fade := 1.0 - float(i) / float(maxi(1, _n)) * 0.6
		var c := Color(COLOR, ALPHA * _a * fade)
		var sz := Vector2(34, 18)
		var r := Rect2(_p[i] - sz * 0.5, sz)
		if _f[i] < 0.0:
			r = Rect2(_p[i] + Vector2(sz.x * 0.5, -sz.y * 0.5), Vector2(-sz.x, sz.y))
		draw_texture_rect(_tex, r, false, c)
