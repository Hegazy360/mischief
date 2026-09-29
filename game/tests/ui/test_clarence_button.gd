## ClarenceButton (GDD §3.3, TECH §6.4): tap vs hold at 500 ms, 150 ms two-thumb suppression,
## FF mode, lure ring state; the Hud feeds the action-down time.
extends TestBase

var c: ClarenceButton
var ev: Array = []
var P := Vector2(84, 84)


func before_each() -> void:
	UiKit.now_override = 50000
	c = ClarenceButton.new()
	ev = []
	c.clarence_down.connect(func() -> void: ev.append("down"))
	c.clarence_hold.connect(func() -> void: ev.append("hold"))
	c.clarence_up.connect(func(ms: int) -> void: ev.append(["up", ms]))


func after_each() -> void:
	c.free()
	UiKit.now_override = -1


func _at(ms: int) -> void:
	UiKit.now_override = ms
	c.tick()


func test_sizes() -> void:
	assert_eq(c.size, Vector2(168, 168), "168 px hit")
	assert_eq(ClarenceButton.VISUAL, 128.0, "128 px visual")
	assert_eq(ClarenceButton.LURE_W, 8.0, "8 px lure ring")


func test_tap_is_under_500ms() -> void:
	c.touch(true, P, 0)
	_at(50000 + 499)
	c.touch(false, P, 0)
	assert_eq(ev, ["down", ["up", 499]], "no hold before 500 ms; held_ms reported")


func test_hold_fires_at_500ms_once() -> void:
	c.touch(true, P, 0)
	_at(50000 + 500)
	_at(50000 + 900)
	assert_eq(ev, ["down", "hold"], "hold once at 500 ms")
	_at(51200)
	c.touch(false, P, 0)
	assert_eq(ev[-1], ["up", 1200])


func test_press_within_150ms_of_action_press_is_ignored() -> void:
	c.last_action_down_ms = 50000 - 149
	c.touch(true, P, 0)
	c.touch(false, P, 0)
	assert_eq(ev.size(), 0, "149 ms after an action press: ignored")
	assert_eq(c.suppressed_count, 1)
	c.last_action_down_ms = 50000 - 150
	c.touch(true, P, 0)
	c.touch(false, P, 0)
	assert_eq(ev, ["down", ["up", 0]], "150 ms after: accepted")


func test_hud_records_action_down_time() -> void:
	var hud := Hud.new()
	UiKit.now_override = 70000
	hud.action.set_verb(HudModel.Verb.FREEZE)
	hud.action.touch(true, Vector2(120, 120), 0)
	assert_eq(hud.clarence.last_action_down_ms, 70000)
	var got := []
	hud.clarence_down.connect(func() -> void: got.append(1))
	UiKit.now_override = 70100
	hud.clarence.touch(true, P, 1)
	assert_eq(got.size(), 0, "left thumb 100 ms after the right thumb: ignored")
	hud.clarence.touch(false, P, 1)
	UiKit.now_override = 70300
	hud.clarence.touch(true, P, 1)
	assert_eq(got.size(), 1, "300 ms after: squeaks")
	hud.free()


func test_ff_mode_uses_the_same_signals() -> void:
	c.set_mode(HudModel.ClarenceMode.FF)
	assert_eq(c.mode, HudModel.ClarenceMode.FF)
	c.touch(true, P, 0)
	_at(50000 + 2000)
	c.touch(false, P, 0)
	assert_eq(ev[0], "down", "⏩ starts on touch-down")
	assert_eq(ev[-1], ["up", 2000], "and stops on the lift")


func test_lure_grey_flag() -> void:
	assert_false(c.lure_grey)
	c.set_lure_grey(true)
	assert_true(c.lure_grey)


func test_cancel_reports_up() -> void:
	c.touch(true, P, 0)
	c.release_touch()
	assert_eq(ev[-1], ["up", 0], "a cancelled press still ends the wheeze / ⏩")
