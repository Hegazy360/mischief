## ItemTray — the CARRIED-ITEM CHIPS (REDESIGN_3D §2.2; replaces the 4-slot tray): only while Hush
## carries something, one 128 px chip (144 hit, 168 pitch) per item at (S+224 + i·168, H−B−188),
## right of Clarence, max 4 — no empty slots are ever drawn. The chip the current rig point accepts
## rises 12 px and glows. Tap a chip → `tray_tap(i)` ("where does this go?"); drag one > 24 px and
## release → `tray_drag(i, screen_pos)` (the optional power-user path). Items are item ids.
class_name ItemTray
extends TouchWidget

signal tray_tap(i: int)
signal tray_drag(i: int, screen_pos: Vector2)

const SLOTS := 4
const HIT := 144.0
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
	var i := _slot_at(point)
	return i >= 0 and _has_item(i)


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


## Slot `i`'s draw transform: its centre (risen), the press squash and the arrival pop.
func _slot_xform(i: int, now: int) -> Transform2D:
	var c := slot_rect(i).get_center() - Vector2(0, _rise[i])
	var pressed := is_pressed and i == _press_slot and not _dragging
	var k := UiKit.PRESS_SCALE if pressed else 1.0
	var at := float(now - _arrive_ms[i]) / 260.0
	if at >= 0.0 and at < 1.0 and not UiKit.reduce_motion():
		k *= 1.0 + 0.25 * sin(at * PI) * (1.0 - at)
	return Transform2D(0.0, Vector2(k, k), 0.0, c)


func _draw() -> void:
	var now := UiKit.now_ms()
	var half := VISUAL * 0.5
	var vr := Rect2(-half, -half, VISUAL, VISUAL)
	# pass 1: every slot's plate / glow / empty ring in ONE triangle array (s2-fix G #8: 16 draw
	# calls → 1 + one per item icon); pass 2: the icons on top.
	UiShapes.begin()
	for i in SLOTS:
		var pressed := is_pressed and i == _press_slot and not _dragging
		UiShapes.set_xform(_slot_xform(i, now))
		if i == highlight and _has_item(i):
			var g := 0.5 + 0.5 * sin(float(now) * 0.001 * TAU * 1.5)
			UiShapes.circle(Vector2.ZERO, half + 16.0 + 5.0 * g, Color(UiKit.GOLD, 0.45 + 0.3 * g))
			UiShapes.circle(Vector2.ZERO, half + 11.0, Color(UiKit.GOLD_LIGHT, 0.85))
		if _has_item(i):
			var fill := UiKit.CREAM if not pressed else UiKit.pressed(UiKit.CREAM)
			UiShapes.circle(Vector2(0, 4), half, Color(0, 0, 0, 0.18))
			UiKit.draw_disc(self, Vector2.ZERO, half, fill, UiKit.CREAM_SHADE if not pressed else UiKit.pressed(UiKit.CREAM_SHADE), 5.0)
	UiShapes.flush(self)
	for i in SLOTS:
		if not _has_item(i):
			continue
		draw_set_transform_matrix(_slot_xform(i, now))
		if not (_dragging and i == _press_slot):
			UiKit.draw_icon(self, _tex[i], Rect2(vr.position + Vector2(20, 16), vr.size - Vector2(40, 40)))
		else:
			UiKit.draw_icon(self, _tex[i], vr.grow(-16.0), Color(1, 1, 1, 0.3))
	draw_set_transform(Vector2.ZERO)
	if _dragging and _has_item(_press_slot):
		var gr := Rect2(_drag_pos - Vector2(64, 64), Vector2(128, 128))
		UiKit.draw_icon(self, _tex[_press_slot], gr, Color(1, 1, 1, 0.85))
