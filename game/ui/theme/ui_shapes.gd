## UiShapes — the HUD's flat shapes as ONE triangle array per call site (s2-fix G #8).
##
## On the Compatibility renderer every StyleBoxFlat rounded rect, every circle and every polygon is
## its own draw call, and an anti-aliased arc costs three; one HUD frame had ~100 of them (the
## applause meter alone 29). Rects, lines and text batch; triangle arrays do not batch with each
## other, but ONE array can hold any number of shapes. UiShapes builds that array: vertex colours,
## a feathered 1-unit rim on every edge (the StyleBoxFlat `anti_aliasing` look), later shapes on top.
##
##   UiShapes.begin()
##   UiShapes.rrect(rect, radius, color)
##   UiShapes.circle(center, r, color)
##   UiShapes.arc(center, r, a0, a1, width, color, points)
##   UiShapes.line(a, b, color, width)
##   UiShapes.flush(canvas_item)   # one draw call; flush before draw_set_transform / text / icons
##
## UiKit.draw_chunky_rect / draw_disc / draw_ring use it (one draw call each instead of 3); widgets
## wrap a run of shapes in begin() … flush() to make the whole run one call.
class_name UiShapes
extends RefCounted

## Feather width (local units, like StyleBoxFlat.anti_aliasing_size).
const AA := 1.0
## Corner segments of a rounded rect (StyleBoxFlat.corner_detail in UiKit).
const CORNER_DETAIL := 10

static var _pts := PackedVector2Array()
static var _cols := PackedColorArray()
static var _idx := PackedInt32Array()
static var _ring := PackedVector2Array()
static var _nrm := PackedVector2Array()
static var _open := false
static var _xf := Transform2D.IDENTITY


## Start collecting shapes (drops anything not flushed).
static func begin() -> void:
	_pts.resize(0)
	_cols.resize(0)
	_idx.resize(0)
	_xf = Transform2D.IDENTITY
	_open = true


## Transform applied to the shapes added from now on (relative to the draw transform in force at
## flush time) — lets one batch hold shapes a widget used to draw under several
## draw_set_transform() calls (the tray's four slots).
static func set_xform(xf: Transform2D) -> void:
	_xf = xf


## True between begin() and flush().
static func is_open() -> bool:
	return _open


## Draw everything collected as one triangle array on `ci` (in its current draw transform) and
## close the batch. Returns the number of triangles.
static func flush(ci: CanvasItem) -> int:
	_open = false
	var tris := _idx.size() / 3
	if tris > 0 and ci != null:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _idx, _pts, _cols)
	_pts.resize(0)
	_cols.resize(0)
	_idx.resize(0)
	_xf = Transform2D.IDENTITY
	return tris


## Vertices / indices collected so far (tests).
static func vertex_count() -> int:
	return _pts.size()


static func _v(p: Vector2, c: Color) -> int:
	_pts.append(_xf * p)
	_cols.append(c)
	return _pts.size() - 1


## The ring in _ring / _nrm (outline points in order, outward unit normals) as a filled convex fan
## around `center` with a feathered rim.
static func _fan(center: Vector2, color: Color, aa: float) -> void:
	var n := _ring.size()
	if n < 3:
		return
	var c0 := _v(center, color)
	var base := _pts.size()
	var clear := Color(color, 0.0)
	var h := aa * 0.5
	for i in n:
		_v(_ring[i] - _nrm[i] * h, color)
	for i in n:
		_v(_ring[i] + _nrm[i] * h, clear)
	for i in n:
		var j := (i + 1) % n
		_idx.append(c0)
		_idx.append(base + i)
		_idx.append(base + j)
		_idx.append(base + i)
		_idx.append(base + n + i)
		_idx.append(base + n + j)
		_idx.append(base + i)
		_idx.append(base + n + j)
		_idx.append(base + j)


## A filled rounded rectangle (corner radius clamped to half the short side).
static func rrect(rect: Rect2, radius: float, color: Color, aa: float = AA) -> void:
	var r := rect.abs()
	if r.size.x <= 0.0 or r.size.y <= 0.0 or color.a <= 0.0:
		return
	var rad := clampf(radius, 0.0, minf(r.size.x, r.size.y) * 0.5)
	_ring.resize(0)
	_nrm.resize(0)
	if rad < 0.5:
		var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var ns := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for i in 4:
			_ring.append(cs[i])
			_nrm.append((ns[i] as Vector2) * 0.7071)
	else:
		var centres := [Vector2(r.position.x + rad, r.position.y + rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad)]
		for q in 4:
			var a0 := PI + float(q) * PI * 0.5
			for k in CORNER_DETAIL + 1:
				var a := a0 + float(k) / float(CORNER_DETAIL) * PI * 0.5
				var d := Vector2(cos(a), sin(a))
				_ring.append((centres[q] as Vector2) + d * rad)
				_nrm.append(d)
	_fan(r.get_center(), color, aa)


## A filled circle.
static func circle(center: Vector2, radius: float, color: Color, aa: float = AA) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var segs := clampi(int(radius * 0.6), 16, 64)
	_ring.resize(0)
	_nrm.resize(0)
	for i in segs:
		var a := TAU * float(i) / float(segs)
		var d := Vector2(cos(a), sin(a))
		_ring.append(center + d * radius)
		_nrm.append(d)
	_fan(center, color, aa)


## A thick arc (CanvasItem.draw_arc: `point_count` points from a0 to a1, `width` centred on
## `radius`), feathered on both edges, square ends.
static func arc(center: Vector2, radius: float, a0: float, a1: float, width: float, color: Color, point_count: int = 16, aa: float = AA) -> void:
	if width <= 0.0 or color.a <= 0.0 or point_count < 2:
		return
	var h := aa * 0.5
	var r_in := maxf(0.0, radius - width * 0.5)
	var r_out := radius + width * 0.5
	var clear := Color(color, 0.0)
	var base := _pts.size()
	for i in point_count:
		var a := lerpf(a0, a1, float(i) / float(point_count - 1))
		var d := Vector2(cos(a), sin(a))
		_v(center + d * maxf(0.0, r_in - h), clear)
		_v(center + d * (r_in + h), color)
		_v(center + d * (r_out - h), color)
		_v(center + d * (r_out + h), clear)
	for i in point_count - 1:
		var p := base + i * 4
		var q := p + 4
		for s in 3:
			_idx.append(p + s)
			_idx.append(q + s)
			_idx.append(q + s + 1)
			_idx.append(p + s)
			_idx.append(q + s + 1)
			_idx.append(p + s + 1)


## A thick straight line, feathered along its sides.
static func line(a: Vector2, b: Vector2, color: Color, width: float, aa: float = AA) -> void:
	var d := b - a
	if d.length_squared() <= 0.0 or width <= 0.0 or color.a <= 0.0:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var h := aa * 0.5
	var w := width * 0.5
	var clear := Color(color, 0.0)
	var base := _pts.size()
	for p in [a, b]:
		_v(p + n * (w + h), clear)
		_v(p + n * (w - h), color)
		_v(p - n * (w - h), color)
		_v(p - n * (w + h), clear)
	for s in 3:
		_idx.append(base + s)
		_idx.append(base + 4 + s)
		_idx.append(base + 4 + s + 1)
		_idx.append(base + s)
		_idx.append(base + 4 + s + 1)
		_idx.append(base + s + 1)


## Any simple polygon (triangulated; no feather — stars, sparkles).
static func poly(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3 or color.a <= 0.0:
		return
	var tri := Geometry2D.triangulate_polygon(points)
	if tri.is_empty():
		return
	var base := _pts.size()
	for p in points:
		_v(p, color)
	for t in tri:
		_idx.append(base + t)
