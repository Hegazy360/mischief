## PipView (TECH §5.6, GDD §3.7): the visibility rule, the 2 s hide delay, escalation sizes,
## the FX cull mask, 30 Hz rendering only while shown.
extends TestBase

var _layout: HouseLayout = HouseLayout.greybox()


func _snap(hush_room: String, hush_x: float, b_room: String, b_x: float, hush_state: String = "IDLE") -> ViewSnapshot:
	var s := ViewSnapshot.new()
	s.hush.present = true
	s.hush.room = hush_room
	s.hush.x = hush_x
	s.hush.state = hush_state
	s.bellows.present = true
	s.bellows.room = b_room
	s.bellows.x = b_x
	return s


func test_rule_needs_him_off_screen() -> void:
	var view := Rect2(2600, -830, 2400, 1080)
	assert_false(PipView.rule(_snap("kitchen", 3300, "kitchen", 3500), view, _layout), "on screen → no PiP")
	assert_true(PipView.rule(_snap("kitchen", 3300, "parlour", 1700), view, _layout), "off screen, next room → PiP")


func test_rule_far_away_only_when_heading_or_rigging() -> void:
	var view := Rect2(2600, -830, 2400, 1080)
	var s := _snap("kitchen", 3300, "hall", 800)
	assert_false(PipView.rule(s, view, _layout), "two rooms away, idle → no PiP")
	s.hush.state = "RIGGING"
	assert_true(PipView.rule(s, view, _layout), "Hush rigging → PiP")
	s.hush.state = "IDLE"
	s.path_rooms = PackedStringArray(["hall", "parlour", "kitchen"])
	assert_true(PipView.rule(s, view, _layout), "heading to her room → PiP")
	s.path_rooms = PackedStringArray()
	assert_true(PipView.rule(s, view, _layout, true), "entry warning live → PiP")


func test_hide_delay_is_two_seconds() -> void:
	var p := PipView.new()
	var shown: Array = []
	p.shown_changed.connect(func(on: bool) -> void: shown.append(on))
	p.set_visible_if(true)
	assert_true(p.is_shown())
	p.set_visible_if(false)
	for i in 114:   # 1.9 s
		p.advance(1.0 / 60.0)
	assert_true(p.is_shown(), "still shown at 1.9 s")
	for i in 12:
		p.advance(1.0 / 60.0)
	assert_false(p.is_shown(), "hidden after 2 s")
	assert_eq(shown, [true, false])
	# The condition returning resets the delay.
	p.set_visible_if(true)
	p.set_visible_if(false)
	for i in 60:
		p.advance(1.0 / 60.0)
	p.set_visible_if(true)
	p.set_visible_if(false)
	for i in 90:
		p.advance(1.0 / 60.0)
	assert_true(p.is_shown(), "the delay restarts")
	# A seek / retry skips the delay.
	p.settle()
	assert_false(p.is_shown(), "settle() hides at once when the rule is false")
	p.set_visible_if(true)
	p.settle()
	assert_true(p.is_shown(), "settle() keeps it when the rule is true")
	p.free()


func test_escalate_sizes_and_stays_up() -> void:
	var p := PipView.new()
	assert_eq(p.size, PipView.SIZE)
	p.escalate(true)
	assert_eq(p.size, PipView.SIZE_ESCALATED)
	assert_true(p.is_shown(), "an escalated gag shows the PiP")
	for i in 200:
		p.advance(1.0 / 60.0)
	assert_true(p.is_shown(), "no hide while escalated")
	p.escalate(false)
	assert_eq(p.size, PipView.SIZE)
	for i in 130:
		p.advance(1.0 / 60.0)
	assert_false(p.is_shown(), "hides 2 s after the gag")
	p.free()


func test_cull_mask_drops_the_fx_layer_and_rendering_only_while_shown() -> void:
	var p := PipView.new()
	assert_eq(p.canvas_cull_mask & PipView.FX_LAYER_BIT, 0, "layer 2 excluded")
	assert_ne(p.canvas_cull_mask & 1, 0, "layer 1 drawn")
	assert_eq(p.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	p.set_visible_if(true)
	var once := 0
	for i in 10:
		p.render_target_update_mode = SubViewport.UPDATE_DISABLED
		p.advance(1.0 / 60.0)
		if p.render_target_update_mode == SubViewport.UPDATE_ONCE:
			once += 1
	assert_eq(once, 5, "30 Hz: every other frame")
	p.free()
