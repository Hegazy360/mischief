## JuiceClock (TECH §5.2): request kinds, the 150 ms-per-second freeze cap, merging, slow
## segments easing back, freeze-frames exempt from the cap, reset.
extends TestBase

var _j: JuiceClock = null


func before_each() -> void:
	_j = JuiceClock.new()
	_j.test_now_us = 10_000_000


func after_each() -> void:
	_j.free()


func _at(us: int) -> float:
	_j.test_now_us = us
	_j.advance()
	return _j.scale()


func test_kinds_freeze_for_their_frames() -> void:
	var t0 := _j.test_now_us
	_j.request_kind(&"hit_small")
	assert_almost_eq(_j.scale(), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(_at(t0 + 49_000), JuiceClock.FREEZE_SCALE, 1e-6, "3 f ≈ 50 ms")
	assert_almost_eq(_at(t0 + 52_000), 1.0, 1e-6)
	var t1 := t0 + 1_200_000     # past the cap window
	_j.test_now_us = t1
	_j.request_kind(&"hit_sig")
	assert_almost_eq(_at(t1 + 130_000), JuiceClock.FREEZE_SCALE, 1e-6, "8 f ≈ 133 ms")
	assert_almost_eq(_at(t1 + 136_000), 1.0, 1e-6)


func test_cap_150_ms_of_freeze_per_second() -> void:
	var t0 := _j.test_now_us
	# One long request is cut at the cap.
	_j.request(&"long", 400)
	assert_almost_eq(_at(t0 + 149_000), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(_at(t0 + 151_000), 1.0, 1e-6, "capped at 150 ms")
	# Inside the same second nothing more is granted …
	_j.request_kind(&"hit_big")
	assert_almost_eq(_j.scale(), 1.0, 1e-6)
	assert_le(_j.freeze_used_us(), JuiceClock.CAP_MS * 1000)
	# … once the window has passed it is.
	_j.test_now_us = t0 + 1_100_000
	_j.request_kind(&"hit_big")
	assert_almost_eq(_j.scale(), JuiceClock.FREEZE_SCALE, 1e-6)


func test_cap_across_spaced_hits() -> void:
	var t0 := _j.test_now_us
	_j.request_kind(&"hit_sig")                 # 133 ms
	_j.test_now_us = t0 + 200_000
	_j.request_kind(&"hit_sig")                 # only 17 ms left in this second
	assert_almost_eq(_at(t0 + 215_000), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(_at(t0 + 219_000), 1.0, 1e-6)
	_j.test_now_us = t0 + 400_000
	_j.request_kind(&"hit_small")               # nothing left
	assert_almost_eq(_j.scale(), 1.0, 1e-6)
	assert_le(_j.freeze_used_us(), JuiceClock.CAP_MS * 1000)


func test_segments_merge_longest_wins() -> void:
	var t0 := _j.test_now_us
	_j.request(&"a", 100)
	_j.test_now_us = t0 + 20_000
	_j.request(&"b", 40)     # ends at +60 ms: inside the first → no extension
	assert_almost_eq(_at(t0 + 90_000), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(_at(t0 + 101_000), 1.0, 1e-6)


func test_approach_slowmo_runs_half_speed_then_eases_back() -> void:
	var t0 := _j.test_now_us
	_j.request_kind(&"approach_slowmo")
	assert_almost_eq(_at(t0 + 100_000), 0.5, 1e-6)
	var mid := _at(t0 + 380_000)
	assert_between(mid, 0.5, 1.0, "easing back")
	assert_almost_eq(_at(t0 + 420_000), 1.0, 1e-6)


func test_slow_starts_after_the_freeze() -> void:
	var t0 := _j.test_now_us
	_j.request(&"x", 50, 0.5, 0.4, 0.1)
	assert_almost_eq(_at(t0 + 40_000), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(_at(t0 + 100_000), 0.5, 1e-6)


func test_freeze_frame_is_scale_zero_and_exempt_from_the_cap() -> void:
	var t0 := _j.test_now_us
	_j.request_kind(&"hit_sig")
	_j.request_kind(&"hit_sig")
	var seen: Array = []
	_j.freeze_frame_changed.connect(func(on: bool) -> void: seen.append(on))
	_j.request_kind(&"freeze_frame", 52)
	assert_eq(_j.scale(), 0.0)
	assert_true(_j.is_freeze_frame())
	assert_eq(_at(t0 + 800_000), 0.0, "52 f ≈ 867 ms > the hit-stop cap")
	assert_almost_eq(_at(t0 + 900_000), 1.0, 1e-6)
	assert_eq(seen, [true, false])


func test_disabled_and_reset() -> void:
	_j.enabled = false
	_j.request_kind(&"hit_big")
	assert_almost_eq(_j.scale(), 1.0, 1e-6)
	_j.enabled = true
	_j.request_kind(&"hit_big")
	_j.reset()
	assert_almost_eq(_j.scale(), 1.0, 1e-6)
	assert_false(_j.is_busy())


func test_scale_at_pure() -> void:
	assert_almost_eq(JuiceClock.scale_at(0, 10, 10, 100, 0.5, 20), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_almost_eq(JuiceClock.scale_at(50, 10, 10, 100, 0.5, 20), 0.5, 1e-6)
	assert_almost_eq(JuiceClock.scale_at(200, 10, 10, 100, 0.5, 20), 1.0, 1e-6)
