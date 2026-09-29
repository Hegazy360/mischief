## CameraDirector (TECH §5.5, GDD §3.7): frame-rate-independent follow (30 vs 60 fps within
## 2 px), house limits, the 0.40 s floor ease, the gag queue (order, one at a time, punch-in
## zoom, reduce-motion cap), PiP escalation when Hush is busy, pan fling/hold/return, pinch
## limits, peeks, shake in real time.
extends TestBase


class StubPip extends Node:
	var calls: Array = []

	func escalate(on: bool) -> void:
		calls.append(on)


var _cam: CameraDirector = null
var _t: Node2D = null


func before_each() -> void:
	_cam = CameraDirector.new()
	_cam.view_size_override = Vector2(2400, 1080)
	_cam.bounds = Rect2(0, -1530, 6200, 1780)
	_t = Node2D.new()
	_t.position = Vector2(3000, 0)


func after_each() -> void:
	_cam.free()
	_t.free()
	for n in _extra:
		if is_instance_valid(n):
			n.free()
	_extra.clear()


var _extra: Array = []


func _run(seconds: float, fps: float, vx: float = 0.0) -> void:
	var dt := 1.0 / fps
	var n := int(round(seconds * fps))
	for i in n:
		_t.position.x += vx * dt
		_cam.advance(dt, dt)


func test_follow_is_frame_rate_independent() -> void:
	var xs: Array[float] = []
	for fps in [30.0, 60.0]:
		var cam := CameraDirector.new()
		cam.view_size_override = Vector2(2400, 1080)
		cam.bounds = Rect2(-100000, -1530, 200000, 1780)
		var t := Node2D.new()
		t.position = Vector2(1000, 0)
		cam.follow(t, func() -> Vector2: return Vector2(1, 0))
		cam.advance(0.0, 0.0)
		var dt := 1.0 / float(fps)
		for i in int(2.0 * fps):
			t.position.x += 400.0 * dt
			cam.advance(dt, dt)
		xs.append(cam.follow_centre().x)
		cam.free()
		t.free()
	assert_almost_eq(xs[0], xs[1], 2.0, "30 fps vs 60 fps")


func test_follow_lags_then_catches_up_with_look_ahead() -> void:
	_cam.follow(_t, func() -> Vector2: return Vector2(1, 0))
	_cam.advance(0.0, 0.0)
	var lead := CameraDirector.LEAD_FRAC * 2400.0
	assert_almost_eq(_cam.centre().x, 3000.0 + lead, 1.0, "starts on target + 12 % look-ahead")
	_t.position.x = 3500.0
	_run(0.2, 60.0)
	var c := _cam.centre().x
	assert_between(c, 3000.0 + lead + 250.0, 3500.0 + lead - 100.0, "τ 0.20: ~63 % after 0.2 s")
	_run(2.0, 60.0)
	assert_almost_eq(_cam.centre().x, 3500.0 + lead, 2.0)


func test_limits_are_the_house_bounds() -> void:
	_cam.follow(_t, func() -> float: return -1.0)
	_t.position.x = -800.0
	_cam.advance(0.0, 0.0)
	var r := _cam.visible_world_rect()
	assert_ge(r.position.x, _cam.bounds.position.x - 0.5)
	_t.position.x = 9000.0
	_cam.snap_now()
	_cam.advance(0.0, 0.0)
	r = _cam.visible_world_rect()
	assert_le(r.end.x, _cam.bounds.end.x + 0.5)
	assert_ge(r.position.y, _cam.bounds.position.y - 0.5)
	assert_le(r.end.y, _cam.bounds.end.y + 0.5)


func test_one_floor_fills_the_height() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var r := _cam.visible_world_rect()
	assert_almost_eq(r.size.y, 1080.0, 0.5)
	assert_almost_eq(r.position.y, -640.0 - 190.0, 1.0, "190 px of the floor above")
	assert_almost_eq(r.end.y, 60.0 + 190.0, 1.0, "190 px below the slab")


func test_floor_change_eases_over_040_s() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var y0 := _cam.follow_centre().y
	_t.position.y = -700.0
	_run(0.2, 60.0)
	var mid := _cam.follow_centre().y
	assert_between(mid, CameraDirector.floor_centre_y(1) + 100.0, y0 - 100.0, "halfway at 0.2 s")
	_run(0.25, 60.0)
	assert_almost_eq(_cam.follow_centre().y, CameraDirector.floor_centre_y(1), 0.5, "done by 0.40 s")


func test_gag_queue_one_at_a_time_in_priority_order() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var order: Array = []
	_cam.gag_started.connect(func(id: int, _p: bool) -> void: order.append(id))
	var a := _cam.request_gag(Vector2(3100, -300), 1.4, 11, 30, 10, 0)
	var b := _cam.request_gag(Vector2(3200, -300), 1.3, 11, 30, 10, 0)
	var c := _cam.request_gag(Vector2(3300, -300), 1.6, 11, 30, 10, 5)
	assert_eq(_cam.active_gag_id(), a)
	assert_eq(_cam.queued_gags(), 2)
	for i in 400:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_eq(order, [a, c, b], "priority 5 jumps the queue; FIFO otherwise")
	assert_false(_cam.is_gag_active())


func test_punch_in_reaches_the_zoom_and_holds() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var id := _cam.request_gag(Vector2(3050, -300), 1.4, 11, 60, 21)
	for i in 12:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.current_zoom(), 1.4, 0.01, "full punch-in after 11 frames")
	assert_eq(_cam.gag_phase(), CameraDirector.GagPhase.HOLD)
	_cam.release_gag(id)
	for i in 30:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.current_zoom(), 1.0, 0.01, "eased back")


func test_punch_in_snaps_in_real_time_during_hitstop() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var id := _cam.request_gag(Vector2(3050, -300), 1.4, 11, 60, 21, 0, 600, 1.1)
	for i in 30:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_eq(_cam.gag_phase(), CameraDirector.GagPhase.APPROACH)
	assert_almost_eq(_cam.current_zoom(), 1.1, 0.02, "gentle approach zoom")
	_cam.punch_gag(id)
	for i in 12:
		_cam.advance(1.0 / 60.0 * 0.05, 1.0 / 60.0)   # view time frozen (hit-stop)
	assert_almost_eq(_cam.current_zoom(), 1.4, 0.01, "punched in despite the freeze")


func test_reduce_motion_caps_punch_and_kills_shake() -> void:
	_cam.reduce_motion = true
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	_cam.request_gag(Vector2(3050, -300), 1.6, 11, 60, 21)
	_cam.shake(1.0)
	for i in 20:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_le(_cam.current_zoom(), 1.15 + 0.001)
	assert_eq(_cam.trauma(), 0.0)


func test_gag_goes_to_pip_when_hush_is_busy_and_focus_off_screen() -> void:
	var pip := StubPip.new()
	_extra.append(pip)
	_cam.pip = pip
	var busy := [true]
	_cam.hush_busy_fn = func() -> bool: return busy[0]
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var got: Array = []
	_cam.gag_started.connect(func(_id: int, in_pip: bool) -> void: got.append(in_pip))
	_cam.request_gag(Vector2(600, -300), 1.4, 11, 20, 10)
	assert_eq(got, [true])
	assert_eq(pip.calls, [true], "PiP escalated")
	var c0 := _cam.centre()
	for i in 60:
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.centre().x, c0.x, 1.0, "the main camera did not cut away")
	assert_eq(pip.calls, [true, false], "PiP back to normal after the gag")
	# Not busy → the camera cuts to it.
	busy[0] = false
	_cam.request_gag(Vector2(600, -300), 1.4, 11, 20, 10)
	assert_eq(got, [true, false])
	# A seek drops it (and anything queued) at once, unless its reaction is still playing.
	var live := _cam.active_gag_id()
	_cam.request_gag(Vector2(700, -300), 1.3, 11, 20, 10)
	_cam.clear_gags(live)
	assert_eq(_cam.active_gag_id(), live, "the live gag survives")
	assert_eq(_cam.queued_gags(), 0)
	_cam.request_gag(Vector2(700, -300), 1.3, 11, 20, 10)
	_cam.clear_gags()
	assert_false(_cam.is_gag_active())
	assert_eq(_cam.queued_gags(), 0)
	busy[0] = true
	_cam.request_gag(Vector2(600, -300), 1.4, 11, 20, 10)
	_cam.clear_gags()
	assert_eq(pip.calls, [true, false, true, false], "clearing a PiP gag un-escalates it")


func test_gag_on_screen_never_goes_to_pip_even_when_busy() -> void:
	var pip := StubPip.new()
	_extra.append(pip)
	_cam.pip = pip
	_cam.hush_busy_fn = func() -> bool: return true
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	_cam.request_gag(Vector2(3100, -300), 1.4, 11, 20, 10)
	assert_eq(pip.calls, [])


func test_pan_fling_hold_and_return() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var c0 := _cam.centre().x
	for i in 10:
		_cam.pan_by(Vector2(-20, 0))
		_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.centre().x, c0 + 200.0, 5.0, "1:1 pan")
	_cam.end_pan()
	_run(0.3, 60.0)
	assert_gt(_cam.centre().x, c0 + 230.0, "fling carries on")
	_run(1.0, 60.0)
	assert_eq(_cam.pan_mode(), CameraDirector.Pan.HOLD)
	_run(1.6, 60.0)
	assert_eq(_cam.pan_mode(), CameraDirector.Pan.RETURN)
	_run(0.6, 60.0)
	assert_eq(_cam.pan_mode(), CameraDirector.Pan.NONE)
	assert_almost_eq(_cam.centre().x, c0, 1.0, "back on Hush")


func test_pinch_limits_and_overview() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	_cam.pinch(0.1, Vector2(1200, 540))
	_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.current_zoom(), 0.5, 0.001)
	_cam.pinch(10.0, Vector2(1200, 540))
	_cam.advance(1.0 / 60.0, 1.0 / 60.0)
	assert_almost_eq(_cam.current_zoom(), 1.25, 0.001)
	_cam.pinch(0.8, Vector2(1200, 540))
	_cam.toggle_overview()
	_run(0.4, 60.0)
	assert_almost_eq(_cam.current_zoom(), 0.5, 0.001, "overview")
	_cam.toggle_overview()
	_run(0.4, 60.0)
	assert_almost_eq(_cam.current_zoom(), 1.0, 0.001, "back to 1.0")


func test_peek_flies_holds_and_returns() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	var c0 := _cam.centre().x
	_cam.peek(Vector2(4500, -300), 1.8)
	_run(0.4, 60.0)
	assert_almost_eq(_cam.centre().x, 4500.0, 1.0)
	_run(1.8, 60.0)
	assert_true(_cam.is_peeking())
	_run(0.4, 60.0)
	assert_false(_cam.is_peeking())
	assert_almost_eq(_cam.centre().x, c0, 1.0)


func test_shake_runs_in_real_time_and_decays() -> void:
	_cam.follow(_t, func() -> float: return 0.0)
	_cam.advance(0.0, 0.0)
	_cam.shake(0.6)
	for i in 10:
		_cam.advance(0.0, 1.0 / 60.0)   # world frozen
	assert_lt(_cam.trauma(), 0.6)
	assert_gt(_cam.trauma(), 0.0)
	_run(1.0, 60.0)
	assert_eq(_cam.trauma(), 0.0)
