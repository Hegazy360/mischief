## The curtain-call ResultsScreen at final polish (s2-ui §4.2.5, GDD §6.2, s2-night §4.3):
## buttons live from the FIRST frame, a tap anywhere else skips the current step (the count-up
## jumps to its end, the stamps land at once — replaying for ★★★ never means sitting through
## results), one stamp per earned Curtain Call with a thunk, the why line, "+NEW!" chips, the Gag
## Reel slot, the Prologue and Gate-0 variants, and a clear lower stage band for Bellows.
extends TestBase

const SIZES := [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1920, 1440)]
const INSETS := [Vector4(0, 0, 0, 0), Vector4(162, 0, 162, 58)]

var _made: Array = []


func before_each() -> void:
	UiKit.now_override = 200000


func after_each() -> void:
	for p in _made:
		if is_instance_valid(p):
			(p as Node).free()
	_made.clear()
	UiKit.now_override = -1


func _results(d: Dictionary, vs: Vector2 = Vector2(2400, 1080), ins: Vector4 = Vector4.ZERO) -> ResultsScreen:
	var p := ResultsScreen.new()
	p.setup(d)
	tree.root.add_child(p)
	p.size = vs
	p.set_insets(ins)
	_made.append(p)
	return p


func _tap(b: UiButton) -> void:
	b.touch(true, b.size * 0.5, 3)
	b.touch(false, b.size * 0.5, 3)


func test_buttons_are_live_on_the_first_frame() -> void:
	for variant in ["night", "prologue", "gate0"]:
		var p := _results({"variant": variant, "applause": 120, "stars": [true, true, true], "has_next": true})
		var got := []
		p.closed.connect(func(a: String) -> void: got.append(a))
		assert_eq(p.age_ms(), 0, "first frame")
		assert_eq(p.pop_k(), 1.0, "no pop-in: the buttons are where they will stay")
		assert_true(p.next_button.visible and not p.next_button.disabled, "%s: the default button is up" % variant)
		assert_true(p.next_button.interactive)
		assert_ge(p.next_button.size.y, 240.0, "the 240 px default")
		_tap(p.next_button)
		assert_eq(got, ["again" if variant == "gate0" else "next"], "%s: tapped at 0 ms, mid count-up" % variant)
		assert_eq(p.step(), ResultsScreen.Step.COUNT, "the count-up had not even finished")


func test_retry_is_live_on_the_first_frame() -> void:
	var p := _results({"applause": 64, "stars": [true, false, false]})
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	_tap(p.retry_button)
	assert_eq(got, ["retry"])


func test_a_tap_elsewhere_skips_to_the_end() -> void:
	var p := _results({"applause": 128, "stars": [true, true, true], "new": ["ACHOO-RIA!"]})
	var skips := []
	p.skip_requested.connect(func(s: int) -> void: skips.append(s))
	var finished := [0]
	p.sequence_finished.connect(func() -> void: finished[0] += 1)
	UiKit.now_override = 200000 + 300
	assert_lt(p.shown_applause(), 128, "mid count-up")
	assert_eq(p.stamps_landed(), 0)
	p._scrim_tap(Vector2(1200, 900))
	assert_eq(skips, [ResultsScreen.Step.COUNT], "skip_requested with the step it skipped")
	assert_eq(p.shown_applause(), 128, "the count-up jumps to its end")
	assert_eq(p.stamps_landed(), 3, "the stamps land at once")
	assert_true(p.is_finished())
	assert_eq(finished[0], 1, "sequence_finished once")
	# a second tap once done: NightScene skips the Gag Reel
	p._scrim_tap(Vector2(1200, 900))
	assert_eq(skips[1], ResultsScreen.Step.DONE)
	assert_eq(finished[0], 1)


func test_stamps_land_one_after_another_with_a_thunk_per_earned_star() -> void:
	var p := _results({"applause": 100, "stars": [true, false, true]})
	var t0 := 200000 + ResultsScreen.COUNT_FROM_MS + ResultsScreen.COUNT_MS
	UiKit.now_override = t0 - 1
	assert_eq(p.stamps_landed(), 0)
	UiKit.now_override = t0 + 1
	assert_eq(p.stamps_landed(), 1)
	UiKit.now_override = t0 + ResultsScreen.STAMP_MS + 1
	assert_eq(p.stamps_landed(), 2)
	UiKit.now_override = t0 + 2 * ResultsScreen.STAMP_MS + 1
	assert_eq(p.stamps_landed(), 3)
	assert_eq(p.step(), ResultsScreen.Step.STAMPS, "each stamp holds 0.3 s")
	UiKit.now_override = t0 + 3 * ResultsScreen.STAMP_MS + 1
	assert_eq(p.step(), ResultsScreen.Step.WHY)
	UiKit.now_override = 200000 + int(p.total_ms()) + 1
	assert_true(p.is_finished())


func test_unskipped_length_fits_the_curtain_call_budget() -> void:
	var p := _results({"applause": 100, "stars": [true, true, false]})
	assert_le(p.total_ms(), 2400.0, "first viewing ≤ 2.4 s (s2-night §4.3)")
	var r := _results({"applause": 100, "stars": [true, true, false], "repeat": true})
	UiKit.now_override = 200000 + int(p.total_ms() * ResultsScreen.REPEAT_PACE) + 1
	assert_true(r.is_finished(), "repeat viewing ≤ 1.9 s")
	assert_le(p.total_ms() * ResultsScreen.REPEAT_PACE, 1900.0)


func test_prologue_variant() -> void:
	var p := _results({"variant": "prologue", "applause": 42})
	assert_false(p.has_stamps(), "no Curtain Calls in the Prologue")
	assert_eq(p.stamps_landed(), 0)
	assert_eq(p.next_button.text, UiStrings.t("curtain.night1"), "Night 1 ▶")
	assert_true(p.retry_button.visible)
	assert_false(p.playbill_button.visible)
	assert_eq(p.back_action, "next")


func test_gate0_variant() -> void:
	var p := _results({"variant": "gate0", "applause": 24})
	assert_false(p.has_stamps())
	assert_eq(p.next_button.text, UiStrings.t("curtain.again"), "Again ▶ is the default")
	assert_true(p.stage_door_button.visible)
	assert_false(p.retry_button.visible, "Again is the retry")
	assert_false(p.playbill_button.visible)
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	_tap(p.stage_door_button)
	assert_eq(got, ["stage_door"])


func test_night_without_a_next_night_disables_next() -> void:
	var p := _results({"applause": 30, "stars": [false, false, false], "has_next": false})
	assert_true(p.next_button.disabled, "no ★: Next Night stays shut (Retry / Playbill live)")
	assert_true(p.retry_button.visible and p.playbill_button.visible)


func test_why_line_wraps_inside_the_left_block_at_44px() -> void:
	var p := _results({"applause": 91, "stars": [true, true, false]})
	p.set_why("4/5 lines — Bellows still hasn't talked to a fish, and the Big Number is still sealed tight")
	assert_ge(p._why_lines.size(), 2, "long lines wrap")
	var f := UiKit.ui_font()
	for l in p._why_lines:
		assert_le(f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.text_size(UiKit.SIZE_PLAY)).x,
			p._left.size.x + 0.5, "fits: " + l)


func test_gag_reel_slot() -> void:
	var p := _results({"applause": 91})
	var r := p.gag_reel_rect()
	assert_eq(r.size, ResultsScreen.REEL, "704 × 396")
	assert_true(Rect2(Vector2.ZERO, p.size).encloses(r))
	var tex := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	p.set_gag_reel_texture(tex)
	assert_eq(p.reel_texture, tex)


func test_layout_buttons_big_apart_and_the_stage_band_clear() -> void:
	for vs in SIZES:
		for ins in INSETS:
			var p := _results({"applause": 91, "stars": [true, true, false]}, vs, ins)
			var tag := "%s %s" % [vs, ins]
			var btns := p.buttons()
			var rects: Array[Rect2] = []
			for b in btns:
				var hr := Rect2(b.position - b.hit_pad, b.size + b.hit_pad * 2.0)
				assert_ge(minf(hr.size.x, hr.size.y), 144.0, "%s hit ≥ 144 %s" % [b.name, tag])
				assert_true(Rect2(Vector2.ZERO, vs).encloses(Rect2(b.position, b.size)), "%s on screen %s" % [b.name, tag])
				rects.append(hr)
			for i in rects.size():
				for j in range(i + 1, rects.size()):
					var a: Rect2 = rects[i]
					var c: Rect2 = rects[j]
					assert_false(a.grow(11.9).intersects(c.grow(11.9)), "24 px apart %s" % tag)
			# the lower stage band between the button groups stays clear for Bellows' slow burn
			var left_end := 0.0
			var right_start: float = vs.x
			for b in btns:
				if b.position.x + b.size.x * 0.5 < vs.x * 0.5:
					left_end = maxf(left_end, b.position.x + b.size.x)
				else:
					right_start = minf(right_start, b.position.x)
			assert_ge(right_start - left_end, 560.0, "a ≥ 560 px clear stage band between the corners %s" % tag)
			var reel := p.gag_reel_rect()
			for b in btns:
				assert_false(reel.intersects(Rect2(b.position, b.size)), "the reel is clear of %s %s" % [b.name, tag])
