## InputRouter — world gestures from raw touches (GDD §3.1, TECH §6.1, touchux §6.3).
##
## Lives in the world canvas as a Node2D and reads `_unhandled_input`, so HUD widgets (STOP
## filter) always win. Classification, per touch index:
##   * tap: touch-up ≤ TAP_MS after touch-down, travel ≤ SLOP_PX, no second finger. Fires on
##     touch-up and is NEVER delayed; a second tap ≤ DOUBLE_MS / DOUBLE_PX after the first is
##     emitted again with `is_double = true` (the view upgrades the walk to a run).
##   * long press: held ≥ LONG_MS within the slop → `long_pressed`; the lift → `long_released`
##     (the Reveal: lifting over a hotspot selects it). A long press never pans.
##   * drag: travel > SLOP_PX → `pan(screen_delta)` 1:1 (the first emission carries the whole
##     displacement since touch-down so the world stays under the finger). Drags that START
##     within EDGE_EXCLUSION_PX of the left / right screen edge are ignored (Android back).
##   * pinch: two touches whose distance changed by > PINCH_PX → `pinch(factor, mid)` with the
##     incremental factor per event. After a pinch the remaining finger is inert until lifted.
## Mouse events are ignored (desktop testing uses `emulate_touch_from_mouse`).
## Tests drive it with `handle(event)` and `poll()` plus `now_override`.
class_name InputRouter
extends Node2D

signal tapped(world_pos: Vector2, is_double: bool)
signal long_pressed(world_pos: Vector2)
signal long_released(world_pos: Vector2)
signal pan(screen_delta: Vector2)
signal pinch(factor: float, mid: Vector2)

## When false every touch is ignored (panels open, cut-scenes).
var enabled: bool = true
## Test hook: when ≥ 0, used instead of Time.get_ticks_msec().
var now_override: int = -1
## Test hook: screen width for the edge exclusion (≤ 0 = the viewport's width).
var screen_width_override: float = -1.0
## Optional screen → world mapping (default: this node's canvas transform, i.e. the camera).
var screen_to_world: Callable = Callable()


class _Touch:
	extends RefCounted
	var index: int = 0
	var p0: Vector2 = Vector2.ZERO
	var p: Vector2 = Vector2.ZERO
	var t0: int = 0
	var moved: bool = false
	var long: bool = false
	var edge: bool = false
	var dead: bool = false


var _touches: Dictionary = {}           # index -> _Touch
var _order: PackedInt32Array = PackedInt32Array()   # indices in press order
var _last_tap_ms: int = -100000
var _last_tap_pos: Vector2 = Vector2(-1e9, -1e9)
var _multi: bool = false
var _pinching: bool = false
var _pinch_d0: float = 0.0
var _pinch_prev: float = 0.0


func _unhandled_input(e: InputEvent) -> void:
	if handle(e) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _touches.is_empty():
		poll()


## Feed one input event. Returns true when it was a touch this router consumed.
func handle(e: InputEvent) -> bool:
	if not enabled:
		if not _touches.is_empty():
			cancel_all()
		return false
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_down(st.index, st.position)
		else:
			_up(st.index, st.position, st.canceled)
		return true
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if not _touches.has(sd.index):
			return false
		_drag(sd.index, sd.position, sd.relative)
		return true
	return false


## Long-press detection (called every frame; public for tests).
func poll() -> void:
	var now := _now()
	for i in _touches:
		var t: _Touch = _touches[i]
		if not t.moved and not t.long and not t.dead and not _multi and now - t.t0 >= GestureConfig.LONG_MS:
			t.long = true
			long_pressed.emit(_to_world(t.p))


## Forget every touch in flight (panel opened, scene paused).
func cancel_all() -> void:
	_touches.clear()
	_order.clear()
	_multi = false
	_pinching = false


## Number of touches currently tracked.
func touch_count() -> int:
	return _touches.size()


func _down(index: int, pos: Vector2) -> void:
	var t := _Touch.new()
	t.index = index
	t.p0 = pos
	t.p = pos
	t.t0 = _now()
	var w := _screen_width()
	t.edge = pos.x < GestureConfig.EDGE_EXCLUSION_PX or (w > 0.0 and pos.x > w - GestureConfig.EDGE_EXCLUSION_PX)
	_touches[index] = t
	_order.append(index)
	if _touches.size() >= 2:
		_multi = true
		_pinching = false
		_pinch_d0 = _two_dist()
		_pinch_prev = _pinch_d0


func _up(index: int, pos: Vector2, canceled: bool) -> void:
	var t: _Touch = _touches.get(index)
	if t == null:
		return
	_touches.erase(index)
	var k := _order.find(index)
	if k >= 0:
		_order.remove_at(k)
	var now := _now()
	if canceled:
		pass
	elif t.long:
		long_released.emit(_to_world(pos))
	elif not t.moved and not t.dead and not _multi and now - t.t0 <= GestureConfig.TAP_MS \
			and pos.distance_to(t.p0) <= GestureConfig.SLOP_PX:
		var dbl := now - _last_tap_ms <= GestureConfig.DOUBLE_MS \
			and pos.distance_to(_last_tap_pos) <= GestureConfig.DOUBLE_PX
		if dbl:
			_last_tap_ms = -100000       # a third quick tap starts a new pair
		else:
			_last_tap_ms = now
			_last_tap_pos = pos
		tapped.emit(_to_world(pos), dbl)
	if _touches.size() < 2:
		_pinching = false
		for i in _touches:
			(_touches[i] as _Touch).dead = true   # the finger left after a pinch is inert
	if _touches.is_empty():
		_multi = false


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var t: _Touch = _touches[index]
	t.p = pos
	if _touches.size() >= 2:
		var d := _two_dist()
		if not _pinching and absf(d - _pinch_d0) > GestureConfig.PINCH_PX:
			_pinching = true
			if _pinch_d0 > 0.0:
				pinch.emit(d / _pinch_d0, _two_mid())
			_pinch_prev = d
		elif _pinching and _pinch_prev > 0.0 and not is_equal_approx(d, _pinch_prev):
			pinch.emit(d / _pinch_prev, _two_mid())
			_pinch_prev = d
		return
	if t.dead or t.long:
		return
	if not t.moved:
		if pos.distance_to(t.p0) > GestureConfig.SLOP_PX:
			t.moved = true
			if t.edge:
				t.dead = true
				return
			pan.emit(pos - t.p0)
		return
	pan.emit(relative)


func _two_dist() -> float:
	if _order.size() < 2:
		return 0.0
	var a: _Touch = _touches[_order[0]]
	var b: _Touch = _touches[_order[1]]
	return a.p.distance_to(b.p)


func _two_mid() -> Vector2:
	if _order.size() < 2:
		return Vector2.ZERO
	var a: _Touch = _touches[_order[0]]
	var b: _Touch = _touches[_order[1]]
	return (a.p + b.p) * 0.5


func _to_world(screen: Vector2) -> Vector2:
	if screen_to_world.is_valid():
		return screen_to_world.call(screen)
	if is_inside_tree():
		return get_canvas_transform().affine_inverse() * screen
	return screen


func _screen_width() -> float:
	if screen_width_override > 0.0:
		return screen_width_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size.x
	return -1.0


func _now() -> int:
	return now_override if now_override >= 0 else Time.get_ticks_msec()
