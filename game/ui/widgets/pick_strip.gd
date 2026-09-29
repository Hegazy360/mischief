## PickStrip — the rummage choice (GDD §3.6): when a container holds 2–4 useful items, 144 px item
## icons with 24 px gaps pop above the container for TIMEOUT_SEC (a draining bar shows the time).
## `open(items, anchor)` places it centred above `anchor` (screen px) — the Hud clamps it into
## the safe area, clear of the thumb clusters. Tap an icon → `pick(item)`; it then closes.
class_name PickStrip
extends TouchWidget

signal pick(item: String)
signal closed()

const CELL := 144.0
const GAP := 24.0
const TIMEOUT_SEC := 3.0
const BAR_H := 12.0

var items: PackedStringArray = PackedStringArray()
var opened_ms: int = -100000

var _tex: Array[Texture2D] = []
var _press: int = -1


func _init() -> void:
	super()
	visible = false


func _ready() -> void:
	set_process(false)


## The strip size for `n` items.
static func size_for(n: int) -> Vector2:
	return Vector2(float(n) * CELL + float(maxi(0, n - 1)) * GAP, CELL + BAR_H + 14.0)


## Cell rect of item `i` (local).
static func cell_rect(i: int) -> Rect2:
	return Rect2(float(i) * (CELL + GAP), 0.0, CELL, CELL)


## Show `ids` (restarts the timeout). The Hud sets `position`.
func open(ids: PackedStringArray) -> void:
	items = ids.duplicate()
	_tex.clear()
	for id in items:
		_tex.append(UiIcons.item(id))
	size = size_for(items.size())
	opened_ms = UiKit.now_ms()
	visible = not items.is_empty()
	_press = -1
	set_process(visible)
	queue_redraw()


## Hide now (emits `closed` when it was open).
func close() -> void:
	if not visible:
		return
	visible = false
	items = PackedStringArray()
	set_process(false)
	closed.emit()


## Milliseconds left before the timeout (0 when closed).
func time_left_ms() -> int:
	if not visible:
		return 0
	return maxi(0, int(TIMEOUT_SEC * 1000.0) - (UiKit.now_ms() - opened_ms))


## Close when the timeout ran out (every frame; public for tests).
func tick() -> void:
	if visible and time_left_ms() <= 0:
		close()


func _has_point(point: Vector2) -> bool:
	return _cell_at(point) >= 0


func _cell_at(p: Vector2) -> int:
	for i in items.size():
		if cell_rect(i).has_point(p):
			return i
	return -1


func _touch_down(pos: Vector2) -> bool:
	_press = _cell_at(pos)
	if _press < 0:
		return false
	UiKit.haptic(&"ui")
	return true


func _touch_up(pos: Vector2, _inside: bool) -> void:
	var i := _press
	_press = -1
	if i >= 0 and cell_rect(i).has_point(pos) and i < items.size():
		var id := items[i]
		pick.emit(id)
		close()


func _touch_cancel() -> void:
	_press = -1


func _process(_delta: float) -> void:
	tick()
	queue_redraw()


func _draw() -> void:
	var t := float(UiKit.now_ms() - opened_ms) / 1000.0
	var ap := clampf(t / 0.16, 0.0, 1.0)
	for i in items.size():
		var cr := cell_rect(i)
		var k := (0.6 + 0.4 * ap) * (UiKit.PRESS_SCALE if is_pressed and i == _press else 1.0)
		draw_set_transform(cr.get_center(), 0.0, Vector2(k, k))
		var vr := Rect2(-CELL * 0.5, -CELL * 0.5, CELL, CELL)
		UiKit.draw_chunky_rect(self, vr, 30.0, UiKit.CREAM, UiKit.CREAM_SHADE)
		UiKit.draw_icon(self, _tex[i], Rect2(vr.position + Vector2(18, 14), vr.size - Vector2(36, 36)))
	draw_set_transform(Vector2.ZERO)
	var bw := size.x * clampf(float(time_left_ms()) / (TIMEOUT_SEC * 1000.0), 0.0, 1.0)
	var br := Rect2(0, CELL + 12.0, size.x, BAR_H)
	UiKit.draw_chunky_rect(self, br, 6.0, Color(UiKit.NAVY, 0.7), Color(UiKit.NAVY, 0.7), 0.0, 0.0)
	UiKit.draw_chunky_rect(self, Rect2(br.position, Vector2(bw, BAR_H)), 6.0, UiKit.YELLOW, UiKit.YELLOW, 0.0, 0.0)
