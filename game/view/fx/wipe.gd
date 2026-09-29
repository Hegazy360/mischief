## FxWipe — the caught sequence's scene change (GDD §4.6, `caught:wipe`, 12 f): an ink iris
## closes on the Lecture (6 f) and opens on the doorstep (6 f). Screen space, one node, one
## polygon. Real time (the sim clock owns its start; the wipe itself never waits on hit-stop).
class_name FxWipe
extends Control

const HALF_S := 0.1

var _t := 99.0
var _centre := Vector2(0.5, 0.45)


func _init() -> void:
	name = "Wipe"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Start the wipe around a screen point (0–1 fractions of the view).
func start(centre_frac: Vector2 = Vector2(0.5, 0.45)) -> void:
	_centre = centre_frac
	_t = 0.0
	visible = true
	queue_redraw()


func active() -> bool:
	return _t < HALF_S * 2.0


## Iris radius as a fraction of the screen diagonal (1 open … 0 closed).
func iris() -> float:
	if _t >= HALF_S * 2.0:
		return 1.0
	if _t < HALF_S:
		return 1.0 - ViewKit.ease_in_out(_t / HALF_S)
	return ViewKit.ease_in_out((_t - HALF_S) / HALF_S)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not active():
		visible = false
	queue_redraw()


func _draw() -> void:
	if not active():
		return
	var s := size
	var diag := s.length()
	var c := Vector2(_centre.x * s.x, _centre.y * s.y)
	var r := iris() * diag * 0.75
	# Ink everywhere outside the iris: a ring polygon (outer square corners + inner circle).
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * maxf(r, 1.0))
	var outer := PackedVector2Array([Vector2(-10, -10), Vector2(s.x + 10, -10), Vector2(s.x + 10, s.y + 10), Vector2(-10, s.y + 10), Vector2(-10, -10)])
	# Two polygons: left and right halves of the ring, so neither self-intersects.
	for side in 2:
		var poly := PackedVector2Array()
		var x_edge := -10.0 if side == 0 else s.x + 10.0
		poly.append(Vector2(c.x, -10))
		poly.append(Vector2(x_edge, -10))
		poly.append(Vector2(x_edge, s.y + 10))
		poly.append(Vector2(c.x, s.y + 10))
		var half := n / 2
		for k in half + 1:
			var idx := (n / 4 + k) if side == 0 else (n / 4 - k + n) % n
			poly.append(pts[idx % n])
		if poly.size() >= 3:
			draw_colored_polygon(poly, ViewKit.INK)
	if r < 2.0:
		draw_rect(Rect2(outer[0], s + Vector2(20, 20)), ViewKit.INK)
