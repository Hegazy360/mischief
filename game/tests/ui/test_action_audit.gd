## Action-button audit against GDD §3.2 (s2-ui §4.2.9): 1.08× pop on arrival at a rig point,
## ring yellow → green, 3 Hz pulse over the last 20 %, Haptics.ring_half at 50 %, a 1.0 → 1.18 →
## 1.0 pop over 180 ms (+ rig_done) on completion, the partial ring kept on an early release,
## slide-off > 80 px cancels, verb latch + 250 ms hysteresis + 120 ms cross-fade, rim
## green / amber / red.
extends TestBase

const V := HudModel.Verb
const C := Vector2(120, 120)

var b: ActionButton
var ev: Array = []
var hap: Node = null
var _own_hap: bool = false


func before_each() -> void:
	UiKit.now_override = 20000
	b = ActionButton.new()
	ev = []
	b.action_down.connect(func(v: int) -> void: ev.append(["down", v]))
	b.action_up.connect(func(v: int, c: bool) -> void: ev.append(["up", v, c]))
	b.ring_half.connect(func() -> void: ev.append(["half"]))
	b.ring_complete.connect(func() -> void: ev.append(["complete"]))
	hap = tree.root.get_node_or_null(^"Haptics")
	_own_hap = hap == null
	if _own_hap:
		hap = (load("res://autoload/haptics.gd") as GDScript).new()
		hap.name = "Haptics"
		tree.root.add_child(hap)
	hap.set("force_enabled", true)
	hap.set("dry_run", true)
	hap.call("reset")


func after_each() -> void:
	b.free()
	if _own_hap:
		hap.free()
	else:
		hap.set("force_enabled", false)
		hap.set("dry_run", false)
		hap.call("reset")
	UiKit.now_override = -1


func _fired() -> PackedStringArray:
	var out := PackedStringArray()
	for f in hap.get("fired"):
		out.append(String((f as Array)[0]))
	return out


func test_arrival_pops_1_08() -> void:
	b.set_verb(V.FREEZE)
	UiKit.now_override = 20400
	b.set_verb(V.RIG)
	assert_eq(b.shown_verb, V.RIG)
	assert_almost_eq(b.pop_scale(20400 + ActionButton.POP_MS / 2), ActionButton.ARRIVAL_POP, 0.001, "1.08× at the peak")
	assert_almost_eq(ActionButton.ARRIVAL_POP, 1.08, 0.0001)
	assert_almost_eq(b.pop_scale(20400 + ActionButton.POP_MS + 1), 1.0, 0.0001, "back to 1.0")


func test_ring_is_yellow_to_green_and_pulses_3hz_over_the_last_fifth() -> void:
	assert_true(ActionButton.ring_color(0.0).is_equal_approx(UiKit.YELLOW), "yellow at the start")
	assert_true(ActionButton.ring_color(1.0).is_equal_approx(UiKit.GREEN), "green when full")
	var mid := ActionButton.ring_color(0.5)
	assert_true(mid.g > UiKit.YELLOW.g - 0.3 and mid != UiKit.YELLOW and mid != UiKit.GREEN, "a blend half way")
	assert_eq(ActionButton.PULSE_HZ, 3.0)
	assert_almost_eq(ActionButton.PULSE_FROM, 0.8, 0.0001)
	for t in [0, 40, 83, 120, 166]:
		assert_eq(ActionButton.ring_pulse(0.79, t), 0.0, "no pulse before 80 %")
		assert_eq(ActionButton.ring_pulse(1.0, t), 0.0, "no pulse once complete")
	# 3 Hz: the pulse repeats every 333 ms
	assert_almost_eq(ActionButton.ring_pulse(0.9, 1000), ActionButton.ring_pulse(0.9, 1333), 0.02, "period 1/3 s")
	assert_gt(absf(ActionButton.ring_pulse(0.9, 1083) - ActionButton.ring_pulse(0.9, 1250)), 0.5, "and it throbs")


func test_haptic_at_half_and_pop_with_rig_done_at_completion() -> void:
	b.set_verb(V.RIG)
	b.touch(true, C, 0)
	hap.call("reset")
	b.set_ring(0.3)
	assert_eq(_fired(), PackedStringArray(), "nothing before half")
	b.set_ring(0.52)
	assert_eq(_fired(), PackedStringArray(["ring_half"]), "Haptics.ring_half at 50 %")
	b.set_ring(0.7)
	assert_eq(_fired().size(), 1, "once")
	UiKit.now_override = 21000
	b.set_ring(1.0)
	assert_has(_fired(), "rig_done", "30 ms rig_done on completion")
	assert_almost_eq(b.pop_scale(21000 + ActionButton.POP_MS / 2), 1.18, 0.001, "1.18× at the middle of 180 ms")
	assert_almost_eq(b.pop_scale(21000 + ActionButton.POP_MS), 1.0, 0.001, "1.0 after 180 ms")
	assert_eq(ActionButton.POP_MS, 180)


func _ups() -> int:
	var n := 0
	for e in ev:
		if (e as Array)[0] == "up":
			n += 1
	return n


func test_early_release_keeps_the_partial_ring() -> void:
	b.set_verb(V.RIG)
	b.touch(true, C, 0)
	b.set_ring(0.4)
	b.touch(false, C, 0)
	assert_eq(ev[-1], ["up", V.RIG, false], "rig off on release")
	assert_almost_eq(b.ring_frac, 0.4, 0.0001, "the partial ring stays on the icon")
	assert_eq(b.shown_verb, V.RIG)
	# coming back resumes from there
	b.touch(true, C, 0)
	b.set_ring(0.55)
	assert_almost_eq(b.ring_frac, 0.55, 0.0001)


func test_slide_off_more_than_80px_cancels_and_keeps_progress() -> void:
	b.set_verb(V.RIG)
	b.touch(true, C, 0)
	b.set_ring(0.6)
	b.drag(C + Vector2(ActionButton.HIT * 0.5 + 79.0, 0), 0)
	assert_eq(_ups(), 0, "79 px off: still holding")
	b.drag(C + Vector2(ActionButton.HIT * 0.5 + 81.0, 0), 0)
	assert_eq(ev[-1], ["up", V.RIG, true], "81 px off: cancelled")
	assert_almost_eq(b.ring_frac, 0.6, 0.0001, "progress kept")


func test_latch_hysteresis_and_cross_fade() -> void:
	b.set_verb(V.FREEZE)
	b.touch(true, C, 0)
	UiKit.now_override = 20600
	b.set_verb(V.RIG)
	b.tick()
	assert_eq(b.shown_verb, V.FREEZE, "latched while pressed")
	assert_eq(b.latched_verb, V.FREEZE)
	b.touch(false, C, 0)
	assert_eq(ev[-1], ["up", V.FREEZE, false], "the press does what it began as")
	assert_eq(b.shown_verb, V.RIG, "shown after release (FREEZE had been up ≥ 250 ms)")
	assert_eq(b._prev_verb, V.FREEZE, "cross-fading from FREEZE")
	assert_eq(b._fade_from_ms, 20600)
	assert_eq(ActionButton.FADE_MS, 120)
	UiKit.now_override = 20700
	b.set_verb(V.FREEZE)
	assert_eq(b.shown_verb, V.RIG, "a verb stays ≥ 250 ms")
	UiKit.now_override = 20851
	b.tick()
	assert_eq(b.shown_verb, V.FREEZE)


func test_rim_colours() -> void:
	assert_eq(ActionButton.RIM_COLORS[HudModel.Rim.GREEN], UiKit.GREEN)
	assert_eq(ActionButton.RIM_COLORS[HudModel.Rim.AMBER], UiKit.AMBER)
	assert_eq(ActionButton.RIM_COLORS[HudModel.Rim.RED], UiKit.RED)
	b.set_verb(V.POP_OUT)
	b.set_rim(HudModel.Rim.RED)
	assert_eq(b.rim, HudModel.Rim.RED)
