## EdgeArrows — "it's over there" arrows (GDD §3.1 tray "where does this go?", §3.2 RIG_DIM,
## §6.4 cue card): a full-screen, never-touchable overlay the Hud lays over the world, under the
## HUD widgets.
##   * `set_directions(dirs, icon)` — one bobbing chunky gold arrow (ARROW px) per screen direction
##     (HudModel.tray_arrows: the directions of matching OFF-screen targets), pinned on the edge of
##     the `zone` rect (the band between the HUD's top row and its bottom clusters, so an arrow never
##     sits on a button) where the direction — scaled by the zone's aspect, so "mostly right" lands
##     on the right edge — leaves it, with the item's icon in a DISC px disc at its tail. Empty = hide.
##   * `point_at(screen_pos, seconds, icon)` — the Figgis cue card's arrow (GDD §6.4 step 2): toward
##     an off-screen target it is an edge arrow like the above; on screen it bobs just above the
##     target pointing down at it. Vector2.INF = none.
## Pooled: at most MAX arrows, one reused polygon buffer, no allocation per frame; redraws only
## while something shows.
class_name EdgeArrows
extends Control

const MAX := 6
## Arrow length / width (px at scale 1).
const ARROW := 128.0
const ARROW_W := 104.0
const DISC := 96.0
const OUTLINE := 7.0
const BOB_HZ := 2.0
const BOB_PX := 14.0
## The tip is kept this far inside the zone edge (px at scale 1): the arrow's half-width, so the
## whole head stays inside; the tail and its disc point inward.
const INSET := 56.0
## Max |sin| of a side-edge arrow's tilt (≈ 12°).
const SIDE_TILT := 0.21
const FILL := UiKit.GOLD
const FILL_LIGHT := UiKit.GOLD_LIGHT

## Where edge arrows may sit (the Hud sets it from HudLayout `edge_zone`).
var zone: Rect2 = Rect2(0, 0, 1920, 1080)
## The visible safe area (on-screen checks).
var safe: Rect2 = Rect2(0, 0, 1920, 1080)
## HUD scale (tablets 0.8).
var k: float = 1.0

var _dirs := PackedVector2Array()
var _icon: Texture2D = null
var _point := Vector2.INF
var _point_icon: Texture2D = null
var _point_until_ms: int = -100000
var _t0: int = 0
var _poly := PackedVector2Array()
var _line := PackedVector2Array()
## The arrow outline pointing +x with its tip at the origin (unit length / width).
const SHAPE: PackedVector2Array = [Vector2(0.0, 0.0), Vector2(-0.52, -0.5), Vector2(-0.52, -0.2),
	Vector2(-1.0, -0.2), Vector2(-1.0, 0.2), Vector2(-0.52, 0.2), Vector2(-0.52, 0.5)]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_poly.resize(SHAPE.size())
	_line.resize(SHAPE.size() + 1)


func _ready() -> void:
	set_process(false)


## Show one edge arrow per direction (≤ MAX), with `icon` at each tail (null = none).
func set_directions(dirs: PackedVector2Array, icon: Texture2D = null) -> void:
	if dirs == _dirs and icon == _icon:
		return
	if _dirs.is_empty() and not dirs.is_empty():
		_t0 = UiKit.now_ms()
	_dirs = dirs.duplicate()
	if _dirs.size() > MAX:
		_dirs.resize(MAX)
	_icon = icon
	_refresh()


## The Figgis card arrow toward `screen_pos` for `seconds`, `icon` at its tail (Vector2.INF clears).
func point_at(screen_pos: Vector2, seconds: float = 4.0, icon: Texture2D = null) -> void:
	_point = screen_pos
	_point_icon = icon
	_point_until_ms = UiKit.now_ms() + int(seconds * 1000.0) if screen_pos != Vector2.INF else -100000
	_t0 = UiKit.now_ms()
	_refresh()


## Arrows currently drawn (tests).
func arrow_count() -> int:
	return _dirs.size() + (1 if _point_live() else 0)


## True when the Figgis arrow's target is on screen (it then points down at it from above).
func point_on_screen() -> bool:
	return _point_live() and safe.grow(-40.0).has_point(_point)


## Where the edge arrow for direction `d` sits (its tip), local px: on the inset zone's edge, the
## direction first scaled by the zone's half-extents so a mostly-horizontal direction lands on a
## side edge and a mostly-vertical one on the top / bottom edge.
func edge_point(d: Vector2) -> Vector2:
	var z := inner_zone()
	var c := z.get_center()
	var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	var h := z.size * 0.5
	# n / max(|n.x|, |n.y|) lies on the unit square's boundary; stretch it onto the zone
	var q := n / maxf(maxf(absf(n.x), absf(n.y)), 0.0001)
	return c + Vector2(q.x * h.x, q.y * h.y)


## What the edge arrow for direction `d` covers at full size (outline and bob included), as
## polygons: [the head + shaft, the icon disc's bounding square] (layout tests).
func arrow_polygons(d: Vector2) -> Array[PackedVector2Array]:
	var n := edge_dir(d)
	var tip := edge_point(d) + n * (BOB_PX * k)
	var side := Vector2(-n.y, n.x)
	var l := ARROW * k + BOB_PX * k
	var w := ARROW_W * k * 0.5 + OUTLINE * k
	var back := tip - n * l
	var body := PackedVector2Array([tip + n * OUTLINE * k + side * w, back + side * w, back - side * w,
		tip + n * OUTLINE * k - side * w])
	var dr := DISC * k * 0.5 + 6.0
	var dc := edge_point(d) - n * (ARROW * k + dr + 6.0 * k)
	var disc := PackedVector2Array([dc + Vector2(-dr, -dr), dc + Vector2(dr, -dr), dc + Vector2(dr, dr),
		dc + Vector2(-dr, dr)])
	var out: Array[PackedVector2Array] = [body, disc]
	return out


## The rect edge-arrow tips move in: the zone inset by INSET, an axis too thin for that collapsing
## to its centre line.
func inner_zone() -> Rect2:
	var gx := minf(INSET * k, zone.size.x * 0.5)
	var gy := minf(INSET * k, zone.size.y * 0.5)
	return zone.grow_individual(-gx, -gy, -gx, -gy)


## The direction an edge arrow at `d` points: toward the target, but an arrow on a SIDE edge tilts at
## most SIDE_TILT (≈ 12°) so its head and tail stay inside the thin band between the corner buttons
## and the thumb clusters ("it's over there, a bit up" reads the same).
func edge_dir(d: Vector2) -> Vector2:
	var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	# edge_point puts |n.x| ≥ |n.y| on a side edge
	if absf(n.x) >= absf(n.y) and absf(n.y) > SIDE_TILT:
		n = Vector2(signf(n.x) * sqrt(1.0 - SIDE_TILT * SIDE_TILT), signf(n.y) * SIDE_TILT)
	return n


func _point_live() -> bool:
	return _point != Vector2.INF and UiKit.now_ms() < _point_until_ms


func _refresh() -> void:
	visible = not _dirs.is_empty() or _point_live()
	set_process(visible)
	queue_redraw()


func _process(_delta: float) -> void:
	if not _dirs.is_empty() or _point_live():
		queue_redraw()
	else:
		_refresh()


func _draw() -> void:
	var t := float(UiKit.now_ms() - _t0) * 0.001
	var bob := 0.0 if UiKit.reduce_motion() else (0.5 + 0.5 * sin(t * TAU * BOB_HZ)) * BOB_PX * k
	var pop := 1.0 if UiKit.reduce_motion() else clampf(0.6 + t * 4.0, 0.6, 1.0)
	for d in _dirs:
		var n := edge_dir(d)
		_draw_arrow(edge_point(d) + n * bob, n, _icon, pop)
	if _point_live():
		if point_on_screen():
			var n2 := Vector2.DOWN
			_draw_arrow(_point - Vector2(0, 36.0 * k) + n2 * bob, n2, null, pop)
		else:
			var d3 := _point - zone.get_center()
			var n3 := edge_dir(d3)
			_draw_arrow(edge_point(d3) + n3 * bob, n3, _point_icon, pop)


## A chunky gold arrow whose tip is at `tip`, pointing along `n`; `icon` in a disc at its tail.
func _draw_arrow(tip: Vector2, n: Vector2, icon: Texture2D, pop: float) -> void:
	var l := ARROW * k * pop
	var w := ARROW_W * k * pop
	var side := Vector2(-n.y, n.x)
	for i in SHAPE.size():
		var sp: Vector2 = SHAPE[i]
		_poly[i] = tip + n * (sp.x * l) + side * (sp.y * w)
	# drop shadow, fill, highlight, outline
	var sh := Vector2(0, 6.0 * k)
	for i in SHAPE.size():
		_line[i] = _poly[i] + sh
	_line[SHAPE.size()] = _poly[0] + sh
	draw_polyline(_line, Color(UiKit.NAVY, 0.35), OUTLINE * k + 4.0, true)
	draw_colored_polygon(_poly, FILL)
	for i in SHAPE.size():
		_line[i] = _poly[i]
	_line[SHAPE.size()] = _poly[0]
	draw_polyline(_line, UiKit.NAVY, OUTLINE * k, true)
	draw_line(tip - n * (l * 0.9) + side * (w * 0.08), tip - n * (l * 0.58) + side * (w * 0.08), Color(FILL_LIGHT, 0.9),
		5.0 * k, true)
	if icon != null:
		var r := DISC * k * 0.5 * pop
		var dc := tip - n * (l + r + 6.0 * k)
		draw_circle(dc + sh, r + 2.0, Color(UiKit.NAVY, 0.35))
		UiKit.draw_disc(self, dc, r, UiKit.CREAM, UiKit.CREAM_SHADE, 6.0)
		UiKit.draw_icon(self, icon, Rect2(dc - Vector2(r, r) * 0.74, Vector2(r, r) * 1.48))
