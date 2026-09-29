## FxRipple — tap feedback (GDD §3.1: ripple ≤ 16 ms, fading 0.35 s), the dotted path to the
## destination (0.4 s) and the destination marker. Pooled: 4 ripples, 48 path dots, one
## marker; everything is lines and one dot texture (batched). Real time.
class_name FxRipple
extends Node2D

const RIPPLES := 4
const RIPPLE_S := 0.35
const RIPPLE_R := 70.0
const DOTS := 48
const DOT_GAP := 44.0
const PATH_S := 0.4
const MARKER_S := 1.6
const SEGMENTS := 28
const COLOR := Color("#FFF4E0")

var _rp := PackedVector2Array()
var _rt := PackedFloat32Array()
var _next := 0
var _dots := PackedVector2Array()
var _dot_n := 0
var _path_t := 99.0
var _marker := Vector2.ZERO
var _marker_t := 99.0
var _dot_tex: Texture2D = null
var _unit := 1.0


func _init() -> void:
	name = "Ripple"
	visibility_layer = 2
	z_index = 35
	_rp.resize(RIPPLES)
	_rt.resize(RIPPLES)
	for i in RIPPLES:
		_rt[i] = 99.0
	_dots.resize(DOTS)


func _ready() -> void:
	_dot_tex = FxArt.sprite("dot")


## A ripple at the tap point (drawn this very frame).
func ripple(world_pos: Vector2) -> void:
	_rp[_next] = world_pos
	_rt[_next] = 0.0
	_next = (_next + 1) % RIPPLES
	queue_redraw()


## Dots along `points` (world polyline from Hush to the target) + a marker at the end.
func path_dots(points: PackedVector2Array) -> void:
	_dot_n = 0
	if points.size() < 2:
		return
	var carry := DOT_GAP * 0.5
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var d := carry
		while d < seg and _dot_n < DOTS:
			_dots[_dot_n] = a.lerp(b, d / seg)
			_dot_n += 1
			d += DOT_GAP
		carry = d - seg
	_path_t = 0.0
	_marker = points[points.size() - 1]
	_marker_t = 0.0
	queue_redraw()


## Drop every ripple, dot and the marker (retry / scenario seek).
func clear() -> void:
	for i in RIPPLES:
		_rt[i] = 99.0
	_path_t = 99.0
	_marker_t = 99.0
	queue_redraw()


## Hide the destination marker (arrived / cancelled).
func clear_marker() -> void:
	_marker_t = 99.0
	queue_redraw()


func tick(dt: float, unit: float) -> void:
	_unit = unit
	var any := false
	for i in RIPPLES:
		if _rt[i] < RIPPLE_S:
			_rt[i] += dt
			any = true
	if _path_t < PATH_S:
		_path_t += dt
		any = true
	if _marker_t < MARKER_S:
		_marker_t += dt
		any = true
	if any:
		queue_redraw()


func _draw() -> void:
	for i in RIPPLES:
		var t := _rt[i]
		if t >= RIPPLE_S:
			continue
		var u := t / RIPPLE_S
		var r := (18.0 + RIPPLE_R * ViewKit.ease_out_cubic(u)) * _unit
		var c := Color(COLOR, 0.95 * (1.0 - u))
		_ring(_rp[i], r, Color(ViewKit.INK, 0.55 * (1.0 - u)), 11.0 * _unit)
		_ring(_rp[i], r, c, 6.0 * _unit)
		_ring(_rp[i], r * 0.55, Color(COLOR, 0.6 * (1.0 - u)), 4.0 * _unit)
	if _path_t < PATH_S and _dot_tex != null:
		var a := 1.0 - _path_t / PATH_S
		var s := 18.0 * _unit
		var so := 26.0 * _unit
		for i in _dot_n:
			draw_texture_rect(_dot_tex, Rect2(_dots[i] - Vector2(so, so) * 0.5, Vector2(so, so)), false, Color(ViewKit.INK, 0.7 * a))
			draw_texture_rect(_dot_tex, Rect2(_dots[i] - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(COLOR, a))
	if _marker_t < MARKER_S:
		var m := _marker
		var bob := sin(_marker_t * 9.0) * 6.0 * _unit
		var a2 := clampf((MARKER_S - _marker_t) / 0.3, 0.0, 1.0)
		var c2 := Color(COLOR, 0.95 * a2)
		var h := 26.0 * _unit
		var tip := m + Vector2(0, -12.0 * _unit + bob)
		var ink := Color(ViewKit.INK, 0.8 * a2)
		draw_line(tip, tip + Vector2(-h * 0.7, -h), ink, 12.0 * _unit)
		draw_line(tip, tip + Vector2(h * 0.7, -h), ink, 12.0 * _unit)
		draw_line(tip, tip + Vector2(-h * 0.7, -h), c2, 7.0 * _unit)
		draw_line(tip, tip + Vector2(h * 0.7, -h), c2, 7.0 * _unit)
		_ring(m, 22.0 * _unit, Color(COLOR, 0.5 * a2), 4.0 * _unit)


## A circle of line segments (thick lines batch; arcs do not).
func _ring(c: Vector2, r: float, col: Color, w: float) -> void:
	var prev := c + Vector2(r, 0)
	for i in range(1, SEGMENTS + 1):
		var ang := TAU * float(i) / float(SEGMENTS)
		var p := c + Vector2(cos(ang), sin(ang)) * r
		draw_line(prev, p, col, w)
		prev = p
