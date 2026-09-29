## ActionButton (GDD §3.2, TECH §6.3): latch at touch-down, 250 ms hysteresis (never while
## pressed), slide-off cancel, tap-to-rig toggles, ring timing callbacks, double tap.
extends TestBase

const V := HudModel.Verb

var b: ActionButton
var ev: Array = []
var C := Vector2(120, 120)


func before_each() -> void:
	UiKit.now_override = 10000
	b = ActionButton.new()
	ev = []
	b.action_down.connect(func(v: int) -> void: ev.append(["down", v]))
	b.action_up.connect(func(v: int, c: bool) -> void: ev.append(["up", v, c]))
	b.action_double_tap.connect(func(v: int) -> void: ev.append(["double", v]))
	b.ring_half.connect(func() -> void: ev.append(["half"]))
	b.ring_complete.connect(func() -> void: ev.append(["complete"]))


func after_each() -> void:
	b.free()
	UiKit.now_override = -1


func _at(ms: int) -> void:
	UiKit.now_override = ms
	b.tick()


func test_sizes() -> void:
	assert_eq(b.size, Vector2(240, 240), "240 px hit box")
	assert_eq(ActionButton.VISUAL, 190.0)
	assert_eq(ActionButton.ICON, 96.0)
	assert_eq(ActionButton.RING_W, 14.0)
	assert_true(b.hit_circle, "hit is a circle")
	assert_true(b._has_point(C + Vector2(119, 0)), "inside the 120 px radius")
	assert_false(b._has_point(Vector2(2, 2)), "the square's corner is outside the circle")


func test_first_verb_shows_at_once() -> void:
	b.set_verb(V.RIG)
	assert_eq(b.shown_verb, V.RIG)


func test_hysteresis_250ms() -> void:
	b.set_verb(V.RIG)
	_at(10100)
	b.set_verb(V.FREEZE)
	assert_eq(b.shown_verb, V.RIG, "100 ms after RIG appeared: still RIG")
	assert_eq(b.pending_verb(), V.FREEZE)
	_at(10249)
	assert_eq(b.shown_verb, V.RIG, "249 ms: still RIG")
	_at(10250)
	assert_eq(b.shown_verb, V.FREEZE, "250 ms: FREEZE shows")


func test_flicker_back_cancels_pending() -> void:
	b.set_verb(V.RIG)
	_at(10050)
	b.set_verb(V.FREEZE)
	_at(10100)
	b.set_verb(V.RIG)
	_at(10400)
	assert_eq(b.shown_verb, V.RIG, "a verb that flickered away and back never showed")


func test_latch_at_touch_down() -> void:
	b.set_verb(V.RIG)
	_at(11000)
	b.touch(true, C, 3)
	assert_eq(ev, [["down", V.RIG]])
	b.set_verb(V.FREEZE)
	_at(12000)
	assert_eq(b.shown_verb, V.RIG, "never changes while pressed")
	b.touch(false, C, 3)
	assert_eq(ev[1], ["up", V.RIG, false], "the press ends as the verb it started as")
	assert_eq(b.shown_verb, V.FREEZE, "the pending verb shows after the lift")


func test_hold_verbs_report_down_and_up() -> void:
	b.set_verb(V.FREEZE)
	b.touch(true, C, 0)
	_at(12000)
	b.touch(false, C, 0)
	assert_eq(ev, [["down", V.FREEZE], ["up", V.FREEZE, false]])


func test_slide_off_more_than_80px_cancels() -> void:
	b.set_verb(V.RIG)
	b.touch(true, C, 0)
	b.drag(C + Vector2(120 + 79, 0), 0)
	assert_eq(ev.size(), 1, "79 px off the edge: still held")
	b.drag(C + Vector2(120 + 81, 0), 0)
	assert_eq(ev[1], ["up", V.RIG, true], "81 px off: cancelled")
	b.drag(C, 0)
	b.touch(false, C, 0)
	assert_eq(ev.size(), 2, "sliding back and lifting does nothing more")


func test_other_touch_indices_are_ignored() -> void:
	b.set_verb(V.FREEZE)
	b.touch(true, C, 1)
	b.touch(true, C, 2)
	b.touch(false, C, 2)
	assert_eq(ev.size(), 1, "a second finger on the button is ignored")
	b.touch(false, C, 1)
	assert_eq(ev.size(), 2)


func test_tap_verbs_commit_on_touch_up_and_detect_double() -> void:
	b.set_verb(V.POP_OUT)
	b.touch(true, C, 0)
	b.touch(false, C, 0)
	assert_eq(ev, [["down", V.POP_OUT], ["up", V.POP_OUT, false]])
	_at(10000 + 200)
	b.touch(true, C, 0)
	b.touch(false, C, 0)
	assert_eq(ev[-1], ["double", V.POP_OUT], "a second tap within 280 ms is a double (pop out and run)")
	_at(10000 + 900)
	b.touch(true, C, 0)
	b.touch(false, C, 0)
	assert_ne(ev[-1][0], "double", "a slow third tap is a plain tap")


func test_tap_to_rig_toggles_hold_verbs() -> void:
	b.set_tap_to_rig(true)
	b.set_verb(V.FREEZE)
	b.touch(true, C, 0)
	assert_eq(ev, [["down", V.FREEZE]], "first tap starts on touch-down")
	b.touch(false, C, 0)
	assert_eq(ev.size(), 1, "lifting keeps the statue")
	assert_true(b.is_toggled())
	b.set_verb(V.POP_OUT)
	_at(11000)
	assert_eq(b.shown_verb, V.FREEZE, "no verb change while toggled on")
	b.touch(true, C, 0)
	assert_eq(ev[1], ["up", V.FREEZE, false], "second tap stops")
	b.touch(false, C, 0)
	assert_eq(ev.size(), 2)
	assert_false(b.is_toggled())
	assert_eq(b.shown_verb, V.POP_OUT, "the pending verb shows")


func test_tap_to_rig_leaves_tap_verbs_alone() -> void:
	b.set_tap_to_rig(true)
	b.set_verb(V.GO)
	b.touch(true, C, 0)
	b.touch(false, C, 0)
	assert_eq(ev, [["down", V.GO], ["up", V.GO, false]])


func test_tap_to_rig_rig_toggle_ends_at_ring_complete() -> void:
	b.set_tap_to_rig(true)
	b.set_verb(V.RIG)
	b.touch(true, C, 0)
	b.touch(false, C, 0)
	b.set_ring(0.6)
	b.set_ring(1.0)
	assert_has(ev, ["complete"])
	assert_eq(ev[-1], ["up", V.RIG, false], "the toggle releases itself when the step completes")
	assert_false(b.is_toggled())


func test_ring_callbacks_at_half_and_full() -> void:
	b.set_verb(V.RIG)
	b.set_ring(0.2)
	b.set_ring(0.49)
	assert_eq(ev.size(), 0)
	b.set_ring(0.5)
	assert_eq(ev, [["half"]], "50 % tick")
	b.set_ring(0.8)
	b.set_ring(1.0)
	assert_eq(ev, [["half"], ["complete"]], "completion")
	b.set_ring(1.0)
	assert_eq(ev.size(), 2, "no repeat at the same value")


func test_ring_half_and_complete_in_one_jump() -> void:
	b.set_verb(V.RIG)
	b.set_ring(0.3)
	b.set_ring(1.0)
	assert_eq(ev, [["complete"]], "a jump straight to 1.0 completes (no half tick afterwards)")


func test_ring_ignored_for_other_verbs() -> void:
	b.set_verb(V.FREEZE)
	b.set_ring(0.6)
	b.set_ring(1.0)
	assert_eq(ev.size(), 0, "FREEZE has no ring")


func test_release_touch_cancels_a_hold() -> void:
	b.set_verb(V.FREEZE)
	b.touch(true, C, 0)
	b.release_touch()
	assert_eq(ev[-1], ["up", V.FREEZE, true])
