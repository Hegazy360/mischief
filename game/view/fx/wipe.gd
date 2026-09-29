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
	for poly in ring_polygons(size, Vector2(_centre.x * size.x, _centre.y * size.y), iris() * size.length() * 0.75):
		draw_colored_polygon(poly, ViewKit.INK)


## The ink outside an iris of radius `r` around `c` on a screen of `s` (s2-fix G #5), as simple
## polygons: nothing when the iris covers the whole screen, the full rect when r < 2, else the
## screen split at c.x into two halves, each clipped by the circle (Geometry2D.clip_polygons), so
## no polygon has a hole or self-intersects ("triangulation failed" at iris 1 before). Pure.
static func ring_polygons(s: Vector2, c: Vector2, r: float, n: int = 48) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var m := 10.0
	var outer := Rect2(-m, -m, s.x + 2.0 * m, s.y + 2.0 * m)
	if r < 2.0:
		out.append(PackedVector2Array([outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]))
		return out
	var far := 0.0
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		far = maxf(far, c.distance_to(corner))
	if r >= far:
		return out
	var circle := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		circle.append(c + Vector2(cos(a), sin(a)) * r)
	var cx := clampf(c.x, outer.position.x + 1.0, outer.end.x - 1.0)
	var halves := [
		PackedVector2Array([outer.position, Vector2(cx, outer.position.y), Vector2(cx, outer.end.y), Vector2(outer.position.x, outer.end.y)]),
		PackedVector2Array([Vector2(cx, outer.position.y), Vector2(outer.end.x, outer.position.y), outer.end, Vector2(cx, outer.end.y)]),
	]
	for h in halves:
		var parts := Geometry2D.clip_polygons(h, circle)
		# A half minus a circle centred on its edge has no hole; should one appear anyway (a centre
		# off screen), keep only the polygons wound like the biggest one (the boundary).
		var big_cw := false
		var big_a := -1.0
		for poly in parts:
			var a := absf(_area(poly))
			if a > big_a:
				big_a = a
				big_cw = Geometry2D.is_polygon_clockwise(poly)
		for poly in parts:
			if poly.size() >= 3 and Geometry2D.is_polygon_clockwise(poly) == big_cw:
				out.append(poly)
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		a += p0.x * p1.y - p1.x * p0.y
	return a * 0.5
