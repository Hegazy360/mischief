## Tray — the 4-slot item tray, bottom-left (GDD §3.6): 128 px visual / 168 px hit slots with
## 24 px gaps (744 × 168). No bag screen, no scrolling. The slot the current rig point accepts
## rises 12 px and glows. Tap a filled slot → `tray_tap(i)` ("where does this go?"); drag one
## > 24 px and release → `tray_drag(i, screen_pos)` (the optional power-user path).
## Items are item ids (icons from art-house, neutral fallback).
class_name ItemTray
extends TouchWidget

signal tray_tap(i: int)
signal tray_drag(i: int, screen_pos: Vector2)

const SLOTS := 4
const HIT := 168.0
const VISUAL := 128.0
const GAP := 24.0
const RISE := 12.0
const DRAG_PX := 24.0

var items: PackedStringArray = PackedStringArray()
var highlight: int = -1

var _tex: Array[Texture2D] = [null, null, null, null]
var _press_slot: int = -1
var _dragging: bool = false
var _drag_pos: Vector2 = Vector2.ZERO
var _down_pos: Vector2 = Vector2.ZERO
var _rise: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0])
var _arrive_ms: PackedInt64Array = PackedInt64Array([-100000, -100000, -100000, -100000])


func _init() -> void:
	super()
	size = Vector2(SLOTS * HIT + (SLOTS - 1) * GAP, HIT)
	custom_minimum_size = size


func _ready() -> void:
	set_process(false)


## The hit rect of slot `i` in local px.
static func slot_rect(i: int) -> Rect2:
	return Rect2(float(i) * (HIT + GAP), 0.0, HIT, HIT)


## Set the carried items (oldest first). Newly filled slots pop in.
func set_items(ids: PackedStringArray) -> void:
	if ids == items:
		return
	var now := UiKit.now_ms()
	for i in SLOTS:
		var id := ids[i] if i < ids.size() else ""
		var old := items[i] if i < items.size() else ""
		if id != old:
			_tex[i] = UiIcons.item(id) if id != "" else null
			if id != "":
				_arrive_ms[i] = now
	items = ids.duplicate()
	set_process(true)
	queue_redraw()


## Highlight slot `i` (−1 = none).
func set_highlight(i: int) -> void:
	if i == highlight:
		return
	highlight = i
	set_process(true)
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return _slot_at(point) >= 0


func _slot_at(p: Vector2) -> int:
	for i in SLOTS:
		if slot_rect(i).has_point(p):
			return i
	return -1


func _touch_down(pos: Vector2) -> bool:
	var i := _slot_at(pos)
	if i < 0:
		return false
	_press_slot = i
	_dragging = false
	_down_pos = pos
	_drag_pos = pos
	UiKit.haptic(&"ui")
	return true


func _touch_move(pos: Vector2) -> void:
	_drag_pos = pos
	if not _dragging and pos.distance_to(_down_pos) > DRAG_PX and _has_item(_press_slot):
		_dragging = true
	if _dragging:
		queue_redraw()


func _touch_up(pos: Vector2, _inside: bool) -> void:
	var i := _press_slot
	_press_slot = -1
	if i < 0 or not _has_item(i):
		_dragging = false
		return
	if _dragging:
		_dragging = false
		if not slot_rect(i).grow(DRAG_PX).has_point(pos):
			tray_drag.emit(i, get_global_transform_with_canvas() * pos if is_inside_tree() else pos)
		return
	if slot_rect(i).has_point(pos):
		tray_tap.emit(i)


func _touch_cancel() -> void:
	_press_slot = -1
	_dragging = false


func _has_item(i: int) -> bool:
	return i >= 0 and i < items.size() and items[i] != ""


func _process(delta: float) -> void:
	var busy := false
	for i in SLOTS:
		var target := RISE if i == highlight else 0.0
		_rise[i] = move_toward(_rise[i], target, delta * RISE / 0.12)
		if not is_equal_approx(_rise[i], target):
			busy = true
		if UiKit.now_ms() - _arrive_ms[i] < 260:
			busy = true
	if highlight >= 0:
		busy = true   # glow pulse
	queue_redraw()
	if not busy:
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	for i in SLOTS:
		var hr := slot_rect(i)
		var c := hr.get_center() - Vector2(0, _rise[i])
		var pressed := is_pressed and i == _press_slot and not _dragging
		var k := UiKit.PRESS_SCALE if pressed else 1.0
		var at := float(now - _arrive_ms[i]) / 260.0
		if at >= 0.0 and at < 1.0 and not UiKit.reduce_motion():
			k *= 1.0 + 0.25 * sin(at * PI) * (1.0 - at)
		draw_set_transform(c, 0.0, Vector2(k, k))
		var half := VISUAL * 0.5
		var vr := Rect2(-half, -half, VISUAL, VISUAL)
		if i == highlight:
			var g := 0.5 + 0.5 * sin(float(now) * 0.001 * TAU * 1.5)
			var glow := vr.grow(12.0 + 5.0 * g)
			UiKit.draw_chunky_rect(self, glow.grow(4.0), 40.0, Color(UiKit.GOLD, 0.45 + 0.3 * g), Color(UiKit.GOLD, 0.45 + 0.3 * g), 0.0, 0.0)
			UiKit.draw_chunky_rect(self, glow, 36.0, Color(UiKit.GOLD_LIGHT, 0.85), Color(UiKit.GOLD_LIGHT, 0.85), 0.0, 0.0)
		var filled := _has_item(i)
		if filled:
			var fill := UiKit.CREAM if not pressed else UiKit.pressed(UiKit.CREAM)
			UiKit.draw_chunky_rect(self, vr, 28.0, fill, UiKit.CREAM_SHADE if not pressed else UiKit.pressed(UiKit.CREAM_SHADE))
			if not (_dragging and i == _press_slot):
				UiKit.draw_icon(self, _tex[i], Rect2(vr.position + Vector2(14, 10), vr.size - Vector2(28, 28)))
			else:
				UiKit.draw_icon(self, _tex[i], vr.grow(-16.0), Color(1, 1, 1, 0.3))
		else:
			UiKit.draw_chunky_rect(self, vr, 28.0, Color(UiKit.NAVY, 0.42), Color(UiKit.NAVY, 0.42), 0.0, 0.0)
			draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color(UiKit.CREAM, 0.28), 5.0, true)
	draw_set_transform(Vector2.ZERO)
	if _dragging and _has_item(_press_slot):
		var gr := Rect2(_drag_pos - Vector2(64, 64), Vector2(128, 128))
		UiKit.draw_icon(self, _tex[_press_slot], gr, Color(1, 1, 1, 0.85))
