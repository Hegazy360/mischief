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
	assert_ge(_s.tumble_frame(), 0, "the tumbler plays its tumble frames in its seat")


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
	assert_eq(_s.mode(), "relief", "relief is its own special (exhale, then a titter)")


func test_no_input_handling() -> void:
	for m in ["_input", "_unhandled_input", "_gui_input"]:
		assert_false(_s.get_script().has_method(m), "StallsView must not handle input (%s)" % m)


func test_tumble_advances_at_8_frames_per_frame_then_holds() -> void:
	_s.react(4)
	_run(1.0 / 60.0)
	assert_eq(_s.tumble_frame(), 0)
	_run(8.0 / 60.0)
	assert_eq(_s.tumble_frame(), 1, "8 f per tumble frame")
	_run(2.0)
	assert_eq(_s.tumble_frame(), 3, "holds the last frame")


func test_behind_you_points_and_shush_leans() -> void:
	_s.special("behind_you")
	_run(0.3)
	var pointing := 0
	for i in StallsView.HEADS:
		if _s.frame_of(i) == "point":
			pointing += 1
	assert_between(pointing, 4, 12, "about a third of the Stalls point")
	_s.special("shush")
	assert_eq(_s.frame_of(0), "lean")


func test_seats_follow_the_layout_and_alpha_from_data() -> void:
	var d: Variant = TestBase.load_json(StallsView.STALLS_JSON)
	if not (d is Dictionary) or not (d as Dictionary).has("layout"):
		skip("stalls.json has no layout")
		return
	var lay: Array = (d as Dictionary)["layout"]
	assert_eq(_s.seat_ids()[0], String(lay[0]))
	assert_eq(_s.seat_ids()[5], String(lay[5]))
	assert_almost_eq(_s.alpha_rest, float((d as Dictionary).get("alpha_rest", 0.6)), 0.001)


func test_tier_rows_merge_the_optional_tiers_json() -> void:
	var t4 := _s.tier_row(4)
	assert_true(bool(t4.get("stand", false)), "T4 stands")
	assert_gt(float(t4.get("rise_px", 0.0)), float(_s.tier_row(3).get("rise_px", 0.0)) - 30.0)
