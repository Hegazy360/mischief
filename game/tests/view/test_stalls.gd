## StallsView (TECH §5.10, GDD §6.5): 24 heads, resting 40 px at alpha 0.6, rising per tier
## (T3 +60 px, T4 stand + one head tumbles), specials, back to rest; one atlas; no input.
extends TestBase

var _s: StallsView = null


func before_each() -> void:
	_s = StallsView.new()
	_s.view_size_override = Vector2(2400, 1080)
	tree.root.add_child(_s)


func after_each() -> void:
	_s.queue_free()
	await tree.process_frame


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		_s.advance(1.0 / 60.0)


func _max_rise() -> float:
	var m := 0.0
	for i in StallsView.HEADS:
		m = maxf(m, _s.head_rise(i))
	return m


func test_rest_is_40_px_at_alpha_06() -> void:
	_run(0.5)
	assert_eq(_s.mode(), "rest")
	assert_almost_eq(_max_rise(), StallsView.REST_PX, 0.5)
	assert_almost_eq(_s.strip_alpha(), StallsView.REST_ALPHA, 0.01)


func test_t3_rises_60_px_and_full_alpha() -> void:
	_s.react(3)
	_run(0.8)
	assert_gt(_max_rise(), StallsView.REST_PX + 50.0)
	assert_almost_eq(_s.strip_alpha(), 1.0, 0.01)
	_run(4.0)
	assert_eq(_s.mode(), "rest")
	assert_almost_eq(_max_rise(), StallsView.REST_PX, 2.0)


func test_t4_stands_and_one_head_tumbles() -> void:
	_s.react(4)
	_run(1.0)
	assert_gt(_max_rise(), StallsView.REST_PX + 75.0, "everyone stands")
	assert_between(_max_rise(), 0.0, 120.0 + 40.0, "up to ~120 px")
	var tumbler := _s.tumbling()
	assert_ge(tumbler, 0)
	assert_lt(_s.head_rise(tumbler), 0.0, "the tumbler falls out of view")


func test_low_tiers_are_small() -> void:
	_s.react(1)
	_run(0.3)
	assert_lt(_max_rise(), StallsView.REST_PX + 20.0)
	_s.react(0)
	_run(0.3)
	assert_lt(_max_rise(), StallsView.REST_PX + 12.0)


func test_specials_switch_modes() -> void:
	for k in ["gasp", "behind_you", "chant", "aww", "boo", "shush"]:
		_s.special(k)
		assert_eq(_s.mode(), k)
	_s.special("relief")
	assert_eq(_s.mode(), "laugh")
	assert_eq(_s.tier(), 1)


func test_no_input_handling() -> void:
	for m in ["_input", "_unhandled_input", "_gui_input"]:
		assert_false(_s.get_script().has_method(m), "StallsView must not handle input (%s)" % m)
