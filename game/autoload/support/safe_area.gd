## SafeArea — display safe-area insets (notch, punch-hole, home indicator) in logical px.
##
## `SafeArea.insets(vp)` → Vector4(left, top, right, bottom) with the SIDES MADE SYMMETRIC
## (`side = max(left, right)`, touchux §5.3), so flipping the phone never moves the HUD.
## Zero on desktop / web unless the dev flag `--safe-area=L,T,R,B` (logical px) is given.
##
## As a Node (add one under a HUD) it re-queries on viewport resize, application resume and
## focus-in, and every POLL_SEC (a 180° flip does not resize the window), emitting `changed`
## only when a value moved by more than 1 px.
class_name SafeArea
extends Node

signal changed(insets: Vector4)

const POLL_SEC := 0.5
const FLAG := "--safe-area"

## Test hook: when set (x ≥ 0), returned by `insets()` for every viewport.
static var override_insets: Vector4 = Vector4(-1, -1, -1, -1)

var current: Vector4 = Vector4.ZERO
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(refresh):
		vp.size_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= POLL_SEC:
		_t = 0.0
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		refresh.call_deferred()


## Re-query now; emits `changed` when any inset moved by more than 1 px.
func refresh() -> void:
	if not is_inside_tree():
		return
	var v := insets(get_viewport())
	if _differs(v, current):
		current = v
		changed.emit(v)


static func _differs(a: Vector4, b: Vector4) -> bool:
	return absf(a.x - b.x) > 1.0 or absf(a.y - b.y) > 1.0 or absf(a.z - b.z) > 1.0 or absf(a.w - b.w) > 1.0


## Symmetric insets for `vp` in logical px: x = left, y = top, z = right, w = bottom.
static func insets(vp: Viewport) -> Vector4:
	if override_insets.x >= 0.0:
		return symmetric(override_insets)
	var flag := parse_flag(OS.get_cmdline_user_args())
	if flag.x >= 0.0:
		return symmetric(flag)
	if vp == null or not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	return symmetric(from_display(safe, win, vp.get_visible_rect().size))


## Pure: a display safe rect (window px) → logical insets for a visible canvas of `visible`.
static func from_display(safe: Rect2i, win: Vector2i, visible: Vector2) -> Vector4:
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var sx := visible.x / float(win.x)
	var sy := visible.y / float(win.y)
	return Vector4(maxf(0.0, safe.position.x * sx), maxf(0.0, safe.position.y * sy),
		maxf(0.0, (win.x - safe.end.x) * sx), maxf(0.0, (win.y - safe.end.y) * sy))


## Pure: sides made symmetric (left = right = max of both).
static func symmetric(v: Vector4) -> Vector4:
	var side := maxf(v.x, v.z)
	return Vector4(side, maxf(0.0, v.y), side, maxf(0.0, v.w))


## Pure: the `--safe-area=L,T,R,B` flag, or Vector4(-1, …) when absent / malformed.
static func parse_flag(args: PackedStringArray) -> Vector4:
	var prefix := FLAG + "="
	for a in args:
		if a.begins_with(prefix):
			var p := a.substr(prefix.length()).split(",")
			if p.size() == 4 and p[0].is_valid_float() and p[1].is_valid_float() \
					and p[2].is_valid_float() and p[3].is_valid_float():
				return Vector4(p[0].to_float(), p[1].to_float(), p[2].to_float(), p[3].to_float())
	return Vector4(-1, -1, -1, -1)
