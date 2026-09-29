## InputRouter gesture classification (GDD §3.1, TECH §6.1): tap / double / long / drag / pinch
## thresholds, the first tap never delayed, edge exclusion, mouse ignored.
extends TestBase

var r: InputRouter
var taps: Array = []
var longs: Array = []
var long_ups: Array = []
var pans: Array = []
var pinches: Array = []


func before_each() -> void:
	r = InputRouter.new()
	r.now_override = 1000
	r.screen_width_override = 2400.0
	taps = []
	longs = []
	long_ups = []
	pans = []
	pinches = []
	r.tapped.connect(func(p: Vector2, d: bool) -> void: taps.append([p, d]))
	r.long_pressed.connect(func(p: Vector2) -> void: longs.append(p))
	r.long_released.connect(func(p: Vector2) -> void: long_ups.append(p))
	r.pan.connect(func(d: Vector2) -> void: pans.append(d))
	r.pinch.connect(func(f: float, m: Vector2) -> void: pinches.append([f, m]))


func after_each() -> void:
	r.free()


func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	r.handle(e)


func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	r.handle(e)


func _at(ms: int) -> void:
	r.now_override = ms
	r.poll()


func test_tap_fires_on_touch_up_immediately() -> void:
	_touch(0, Vector2(800, 500), true)
	assert_eq(taps.size(), 0, "nothing on touch-down")
	_at(1200)
	_touch(0, Vector2(806, 503), false)
	assert_eq(taps.size(), 1, "tap on touch-up")
	assert_false(taps[0][1], "first tap is not double")
	assert_eq(taps[0][0], Vector2(806, 503))


func test_tap_too_slow_is_not_a_tap() -> void:
	_touch(0, Vector2(800, 500), true)
	_at(1000 + GestureConfig.TAP_MS + 1)
	_touch(0, Vector2(800, 500), false)
	assert_eq(taps.size(), 0, "> 300 ms is not a tap")


func test_tap_at_exact_limit_counts() -> void:
	_touch(0, Vector2(800, 500), true)
	_at(1000 + GestureConfig.TAP_MS)
	_touch(0, Vector2(800, 500), false)
	assert_eq(taps.size(), 1, "300 ms is still a tap")


func test_travel_beyond_slop_is_a_drag_not_a_tap() -> void:
	_touch(0, Vector2(800, 500), true)
	_drag(0, Vector2(820, 500), Vector2(20, 0))
	assert_eq(pans.size(), 0, "20 px is within the slop: no pan yet")
	_drag(0, Vector2(830, 500), Vector2(10, 0))
	assert_eq(pans.size(), 1, "crossing 24 px starts the pan")
	assert_eq(pans[0], Vector2(30, 0), "the first pan carries the whole displacement (1:1)")
	_drag(0, Vector2(850, 510), Vector2(20, 10))
	assert_eq(pans[1], Vector2(20, 10), "then the per-event delta")
	_at(1100)
	_touch(0, Vector2(850, 510), false)
	assert_eq(taps.size(), 0, "a drag never taps (never moves Hush)")


func test_double_tap_flags_second_and_never_delays_first() -> void:
	_touch(0, Vector2(800, 500), true)
	_at(1080)
	_touch(0, Vector2(800, 500), false)
	assert_eq(taps.size(), 1, "first tap emitted at once")
	_at(1080 + GestureConfig.DOUBLE_MS - 40)
	_touch(0, Vector2(840, 520), true)
	_at(1080 + GestureConfig.DOUBLE_MS)
	_touch(0, Vector2(840, 520), false)
	assert_eq(taps.size(), 2)
	assert_true(taps[1][1], "second tap within 280 ms / 64 px is double")


func test_double_tap_limits() -> void:
	_touch(0, Vector2(800, 500), true)
	_touch(0, Vector2(800, 500), false)
	_at(1000 + GestureConfig.DOUBLE_MS + 1)
	_touch(0, Vector2(800, 500), true)
	_touch(0, Vector2(800, 500), false)
	assert_false(taps[1][1], "281 ms later is a new single tap")
	_at(1400)
	_touch(0, Vector2(900, 500), true)
	_touch(0, Vector2(900, 500), false)
	assert_false(taps[2][1], "100 px away is not a double tap")


func test_long_press_and_release() -> void:
	_touch(0, Vector2(600, 400), true)
	_at(1000 + GestureConfig.LONG_MS - 1)
	assert_eq(longs.size(), 0, "449 ms: not yet")
	_at(1000 + GestureConfig.LONG_MS)
	assert_eq(longs.size(), 1, "450 ms: long press")
	_drag(0, Vector2(700, 400), Vector2(100, 0))
	assert_eq(pans.size(), 0, "moving after a long press does not pan (Reveal selection)")
	_touch(0, Vector2(700, 400), false)
	assert_eq(long_ups.size(), 1, "lift → long_released")
	assert_eq(long_ups[0], Vector2(700, 400))
	assert_eq(taps.size(), 0, "a long press is not a tap")


func test_long_press_cancelled_by_movement() -> void:
	_touch(0, Vector2(600, 400), true)
	_drag(0, Vector2(640, 400), Vector2(40, 0))
	_at(1600)
	assert_eq(longs.size(), 0, "dragging cancels the long press")


func test_edge_exclusion_ignores_drags_but_allows_taps() -> void:
	_touch(0, Vector2(30, 500), true)
	_drag(0, Vector2(140, 500), Vector2(110, 0))
	_drag(0, Vector2(200, 500), Vector2(60, 0))
	assert_eq(pans.size(), 0, "a drag starting within 48 px of the left edge is ignored")
	_touch(0, Vector2(200, 500), false)
	_touch(1, Vector2(2400 - 20, 500), true)
	_drag(1, Vector2(2200, 500), Vector2(-180, 0))
	assert_eq(pans.size(), 0, "…and of the right edge")
	_touch(1, Vector2(2200, 500), false)
	_at(2000)
	_touch(2, Vector2(20, 300), true)
	_touch(2, Vector2(20, 300), false)
	assert_eq(taps.size(), 1, "a tap at the edge still taps")
	_touch(3, Vector2(GestureConfig.EDGE_EXCLUSION_PX + 1, 500), true)
	_drag(3, Vector2(200, 500), Vector2(151, 0))
	assert_eq(pans.size(), 1, "49 px in: drags normally")


func test_pinch_needs_32px_then_reports_factor_and_mid() -> void:
	_touch(0, Vector2(1000, 500), true)
	_touch(1, Vector2(1200, 500), true)
	_drag(1, Vector2(1220, 500), Vector2(20, 0))
	assert_eq(pinches.size(), 0, "20 px change: no pinch yet")
	assert_eq(pans.size(), 0, "two fingers never pan")
	_drag(1, Vector2(1240, 500), Vector2(20, 0))
	assert_eq(pinches.size(), 1, "40 px change > 32: pinch starts")
	assert_almost_eq(float(pinches[0][0]), 240.0 / 200.0, 0.0001, "factor since the start")
	assert_eq(pinches[0][1], Vector2(1120, 500), "midpoint")
	_drag(0, Vector2(940, 500), Vector2(-60, 0))
	assert_almost_eq(float(pinches[1][0]), 300.0 / 240.0, 0.0001, "then incremental")
	_touch(1, Vector2(1240, 500), false)
	_drag(0, Vector2(700, 500), Vector2(-240, 0))
	_touch(0, Vector2(700, 500), false)
	assert_eq(pans.size(), 0, "the finger left after a pinch is inert")
	assert_eq(taps.size(), 0, "a pinch never taps")


func test_second_finger_kills_the_tap() -> void:
	_touch(0, Vector2(800, 500), true)
	_touch(1, Vector2(900, 500), true)
	_touch(1, Vector2(900, 500), false)
	_touch(0, Vector2(800, 500), false)
	assert_eq(taps.size(), 0, "no tap with a second finger down")


func test_mouse_events_are_ignored() -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(500, 500)
	assert_false(r.handle(mb), "mouse press not handled")
	mb = mb.duplicate()
	mb.pressed = false
	r.handle(mb)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(100, 0)
	assert_false(r.handle(mm))
	assert_eq(taps.size() + pans.size(), 0, "mouse produces nothing")


func test_disabled_router_ignores_and_cancels() -> void:
	_touch(0, Vector2(800, 500), true)
	r.enabled = false
	_touch(0, Vector2(800, 500), false)
	assert_eq(taps.size(), 0)
	assert_eq(r.touch_count(), 0, "in-flight touches dropped")


func test_canceled_touch_does_not_tap() -> void:
	_touch(0, Vector2(800, 500), true)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(800, 500)
	e.pressed = false
	e.canceled = true
	r.handle(e)
	assert_eq(taps.size(), 0)


func test_world_mapping_uses_screen_to_world() -> void:
	r.screen_to_world = func(p: Vector2) -> Vector2: return p * 2.0 + Vector2(100, 0)
	_touch(0, Vector2(10, 20), true)
	_touch(0, Vector2(10, 20), false)
	assert_eq(taps[0][0], Vector2(120, 40))
