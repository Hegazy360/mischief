## TouchWidget — base of every HUD target: a Control that reads InputEventScreenTouch/Drag BY
## INDEX (two thumbs at once), ignores mouse events, and uses the STOP filter so world gestures
## never see its touches. The Control's rect is the hit box; `hit_circle` makes it round.
##
## Subclasses override `_touch_down(pos) -> bool` (false = ignore this touch), `_touch_move(pos)`,
## `_touch_up(pos, inside)` and `_touch_cancel()`. Only one touch at a time per widget; a second
## finger on the same widget is ignored. Pressed feedback is the subclass's job (drawn in the
## same frame: `_press` flips before `queue_redraw`).
## Tests call `touch(pressed, pos, index)` / `drag(pos, index)` with local positions.
class_name TouchWidget
extends Control

## Hit shape: false = the rect, true = the inscribed circle.
var hit_circle: bool = false
## When false, touches are ignored (paused / hidden).
var interactive: bool = true
## The touch index that owns this widget, −1 when idle.
var touch_index: int = -1
## Real-time ms of the current touch-down.
var down_ms: int = 0
## True while a finger is down on the widget.
var is_pressed: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _has_point(point: Vector2) -> bool:
	if hit_circle:
		var r := minf(size.x, size.y) * 0.5
		return point.distance_to(size * 0.5) <= r
	return Rect2(Vector2.ZERO, size).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_accept()
		if st.pressed:
			touch(true, st.position, st.index)
		else:
			touch(false, st.position, st.index, st.canceled)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_accept()
		drag(sd.position, sd.index)
	elif event is InputEventMouse:
		_accept()   # emulated mouse from touch: swallow, never act on it


## Feed a touch (local position). Public for tests.
func touch(pressed: bool, pos: Vector2, index: int = 0, canceled: bool = false) -> void:
	if pressed:
		if touch_index != -1 or not interactive or not is_visible_in_tree_or_detached():
			return
		if not _touch_down(pos):
			return
		touch_index = index
		down_ms = UiKit.now_ms()
		is_pressed = true
		queue_redraw()
		return
	if index != touch_index:
		return
	touch_index = -1
	is_pressed = false
	if canceled:
		_touch_cancel()
	else:
		_touch_up(pos, _has_point(pos))
	queue_redraw()


## Feed a drag (local position). Public for tests.
func drag(pos: Vector2, index: int = 0) -> void:
	if index != touch_index:
		return
	_touch_move(pos)


## Drop the current touch without firing (panel opened over it, widget hidden).
func release_touch() -> void:
	if touch_index == -1:
		return
	touch_index = -1
	is_pressed = false
	_touch_cancel()
	queue_redraw()


## True when visible in the tree, or not in a tree at all (headless tests).
func is_visible_in_tree_or_detached() -> bool:
	return visible if not is_inside_tree() else is_visible_in_tree()


# --- overridables ------------------------------------------------------------------------

## A finger went down at `pos`. Return false to ignore the touch entirely.
func _touch_down(_pos: Vector2) -> bool:
	return true


func _touch_move(_pos: Vector2) -> void:
	pass


## The finger lifted at `pos`; `inside` = over the hit shape.
func _touch_up(_pos: Vector2, _inside: bool) -> void:
	pass


func _touch_cancel() -> void:
	pass


func _accept() -> void:
	if is_inside_tree():
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_touch()
