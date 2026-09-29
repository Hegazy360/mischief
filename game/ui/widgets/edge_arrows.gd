## EdgeArrows — "it's over there" arrows (GDD §3.1 tray "where does this go?", §3.2 RIG_DIM,
## §6.4 cue card): a full-screen, never-touchable overlay the Hud lays over the world.
##   * `set_directions(dirs, icon)` — one bobbing 88 px arrow per screen direction (HudModel.
##     tray_arrows: the directions of matching OFF-screen rig points), pinned where the ray from the
##     screen centre leaves the `zone` rect (the band between the HUD's top row and its bottom
##     clusters, so an arrow never sits on a button), with the tapped item's icon in a disc at its
##     tail. Empty = hide them.
##   * `point_at(screen_pos, seconds)` — the Figgis cue card's arrow (GDD §6.4 step 2): toward an
##     off-screen target it is an edge arrow like the above; on screen it bobs just above the
##     target pointing down at it. Vector2.INF = none.
## Pooled: at most MAX arrows, no allocation per frame; redraws only while something shows.
class_name EdgeArrows
extends Control

const MAX := 6
const ARROW := 88.0
const DISC := 60.0
const BOB_HZ := 2.0
const BOB_PX := 10.0
## Kept this far inside the zone edge (px at scale 1).
const INSET := 56.0

## Where edge arrows may sit (the Hud sets it from HudLayout `edge_zone`, grown to the edges).
var zone: Rect2 = Rect2(0, 0, 1920, 1080)
## The visible safe area (on-screen checks).
var safe: Rect2 = Rect2(0, 0, 1920, 1080)
## HUD scale (tablets 0.8).
var k: float = 1.0

var _dirs := PackedVector2Array()
var _icon: Texture2D = null
var _point := Vector2.INF
var _point_until_ms: int = -100000
var _t0: int = 0
var _tex_arrow: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_tex_arrow = UiIcons.get_icon(&"arrow")
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


## The Figgis card arrow toward `screen_pos` for `seconds` (Vector2.INF clears it).
func point_at(screen_pos: Vector2, seconds: float = 4.0) -> void:
	_point = screen_pos
	_point_until_ms = UiKit.now_ms() + int(seconds * 1000.0) if screen_pos != Vector2.INF else -100000
	_t0 = UiKit.now_ms()
	_refresh()


## Arrows currently drawn (tests).
func arrow_count() -> int:
	return _dirs.size() + (1 if _point_live() else 0)


## Where the edge arrow for direction `d` sits (its tip), local px.
func edge_point(d: Vector2) -> Vector2:
	var z := zone.grow(-INSET * k)
	var c := z.get_center()
	var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
	var tx := INF
	var ty := INF
	if absf(n.x) > 0.0001:
		tx = ((z.end.x if n.x > 0.0 else z.position.x) - c.x) / n.x
	if absf(n.y) > 0.0001:
		ty = ((z.end.y if n.y > 0.0 else z.position.y) - c.y) / n.y
	return c + n * minf(tx, ty)


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
		var n := d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT
		_draw_arrow(edge_point(n) + n * bob, n, _icon, pop)
	if _point_live():
		if safe.grow(-40.0).has_point(_point):
			var n2 := Vector2.DOWN
			_draw_arrow(_point - Vector2(0, 30.0 * k) + n2 * bob, n2, null, pop)
		else:
			var n3 := (_point - zone.get_center()).normalized()
			_draw_arrow(edge_point(n3) + n3 * bob, n3, null, pop)


## An arrow whose tip is at `tip`, pointing along `n`; `icon` in a disc at its tail.
func _draw_arrow(tip: Vector2, n: Vector2, icon: Texture2D, pop: float) -> void:
	var s := ARROW * k * pop
	var ctr := tip - n * s * 0.5
	draw_set_transform(ctr, n.angle(), Vector2.ONE)
	UiKit.draw_icon(self, _tex_arrow, Rect2(-s * 0.5, -s * 0.5, s, s))
	draw_set_transform(Vector2.ZERO)
	if icon != null:
		var dc := tip - n * (s + DISC * k * 0.5)
		var r := DISC * k * 0.5 * pop
		UiKit.draw_disc(self, dc, r, UiKit.CREAM, UiKit.CREAM_SHADE, 5.0)
		UiKit.draw_icon(self, icon, Rect2(dc - Vector2(r, r) * 0.72, Vector2(r, r) * 1.44))
