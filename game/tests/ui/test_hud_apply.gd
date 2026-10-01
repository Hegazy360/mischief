## Hud.apply (TECH §5.9): idempotent (a repeat apply changes nothing), every field reaches its
## widget, intents are forwarded, pause dims and disables the targets.
extends TestBase

var hud: Hud


func before_each() -> void:
	UiKit.now_override = 100000
	hud = Hud.new()
	hud.layout_size_override = Vector2(2400, 1080)
	hud.insets_override = Vector4.ZERO
	hud.relayout()


func after_each() -> void:
	hud.free()
	UiKit.now_override = -1


func _model() -> HudModel:
	var m := HudModel.new()
	m.applause = 42
	m.lines_done = 2
	m.lines_total = 5
	m.tomatoes_left = 2
	m.tomatoes_max = 3
	m.link = 2
	m.mult_pct = 150
	m.fuse_frac = 0.5
	m.verb = HudModel.Verb.RIG
	m.verb_item_icon = "squeaker"
	m.verb_target_icon = "tea"
	m.ring_frac = 0.25
	m.clarence_mode = HudModel.ClarenceMode.SQUEAK
	m.tray = PackedStringArray(["squeaker", "kipper"])
	m.tray_highlight = 0
	m.pip_visible = true
	m.pip_frame_tier = 2
	m.pip_glyph = "specs_on"
	m.edge_bubble_dir = Vector2(1, 0)
	m.edge_bubble_label = "2 rooms →"
	m.pick_strip_items = PackedStringArray(["flour", "salt"])
	m.pick_strip_pos = Vector2(1200, 600)
	return m


func test_second_identical_apply_changes_nothing() -> void:
	var m := _model()
	hud.apply(m)
	assert_gt(hud.last_changes, 10, "the first apply pushes everything")
	hud.apply(m)
	assert_eq(hud.last_changes, 0, "an identical apply is a no-op")
	var m2 := HudModel.new()
	m2.copy_from(m)
	hud.apply(m2)
	assert_eq(hud.last_changes, 0, "an equal copy is a no-op too (value compare, not identity)")


func test_one_changed_field_is_one_change() -> void:
	var m := _model()
	hud.apply(m)
	m.applause = 43
	hud.apply(m)
	assert_eq(hud.last_changes, 1)
	m.tray = PackedStringArray(["squeaker", "kipper", "flour"])
	hud.apply(m)
	assert_eq(hud.last_changes, 1)
	hud.apply(m)
	assert_eq(hud.last_changes, 0)


func test_fields_reach_widgets() -> void:
	var m := _model()
	hud.apply(m)
	assert_eq(hud.meter.applause, 42)
	assert_eq(hud.meter.lines_total, 5)
	assert_eq(hud.banner.link, 2)
	assert_eq(hud.banner.mult_pct, 150)
	assert_eq(hud.action.shown_verb, HudModel.Verb.RIG)
	assert_almost_eq(hud.action.ring_frac, 0.25)
	assert_eq(hud.tray.items, PackedStringArray(["squeaker", "kipper"]))
	assert_eq(hud.tray.highlight, 0)
	assert_true(hud.pip.shown)
	assert_eq(hud.pip.tier, 2)
	assert_eq(hud.pip.glyph_id, "specs_on")
	assert_false(hud.edge_bubble.visible, "no edge bubble while the PiP shows")
	assert_true(hud.pick_strip.visible)
	assert_eq(hud.pick_strip.items, PackedStringArray(["flour", "salt"]))
	m.pip_visible = false
	hud.apply(m)
	assert_true(hud.edge_bubble.visible, "the edge bubble stands in for the hidden PiP")
	assert_eq(hud.edge_bubble.label, "2 rooms →")
	m.pick_strip_items = PackedStringArray()
	hud.apply(m)
	assert_false(hud.pick_strip.visible, "cleared strip closes")


func test_escalated_pip_moves_the_overview_button() -> void:
	var m := _model()
	hud.apply(m)
	var normal := hud.overview.position
	m.pip_escalated = true
	hud.apply(m)
	assert_eq(hud.pip.size, PipFrame.SIZE_ESCALATED, "704 × 396")
	assert_eq(hud.pip.position, (hud.layout[&"pip_escalated"] as Rect2).position)
	assert_gt(hud.overview.position.y, normal.y, "overview drops below the Gag-Cam window")


func test_intents_are_forwarded() -> void:
	var got := []
	hud.action_down.connect(func(v: int) -> void: got.append(["action_down", v]))
	hud.action_up.connect(func(v: int, c: bool) -> void: got.append(["action_up", v, c]))
	hud.tray_tap.connect(func(i: int) -> void: got.append(["tray_tap", i]))
	hud.pause_tap.connect(func() -> void: got.append(["pause"]))
	hud.meter_tap.connect(func() -> void: got.append(["meter"]))
	hud.pick.connect(func(item: String) -> void: got.append(["pick", item]))
	hud.pip_tap.connect(func() -> void: got.append(["pip"]))
	var m := _model()
	hud.apply(m)
	hud.action.touch(true, Vector2(120, 120), 0)
	hud.action.touch(false, Vector2(120, 120), 0)
	hud.tray.touch(true, ItemTray.slot_rect(1).get_center(), 1)
	hud.tray.touch(false, ItemTray.slot_rect(1).get_center(), 1)
	hud.pause_button.touch(true, Vector2(72, 72), 2)
	hud.pause_button.touch(false, Vector2(72, 72), 2)
	hud.meter.touch(true, Vector2(300, 72), 3)
	hud.meter.touch(false, Vector2(300, 72), 3)
	hud.pick_strip.touch(true, PickStrip.cell_rect(1).get_center(), 4)
	hud.pick_strip.touch(false, PickStrip.cell_rect(1).get_center(), 4)
	hud.pip.touch(true, Vector2(100, 100), 5)
	assert_eq(got, [["action_down", HudModel.Verb.RIG], ["action_up", HudModel.Verb.RIG, false], ["tray_tap", 1],
		["pause"], ["meter"], ["pick", "salt"], ["pip"]])


func test_empty_tray_slot_does_not_tap() -> void:
	var got := []
	hud.tray_tap.connect(func(i: int) -> void: got.append(i))
	hud.apply(_model())
	hud.tray.touch(true, ItemTray.slot_rect(3).get_center(), 0)
	hud.tray.touch(false, ItemTray.slot_rect(3).get_center(), 0)
	assert_eq(got, [], "slot 3 is empty")


func test_tray_drag_emits_on_release() -> void:
	var got := []
	hud.tray_drag.connect(func(i: int, p: Vector2) -> void: got.append([i, p]))
	hud.tray_tap.connect(func(_i: int) -> void: got.append("tap"))
	hud.apply(_model())
	var c := ItemTray.slot_rect(0).get_center()
	hud.tray.touch(true, c, 0)
	hud.tray.drag(c + Vector2(0, -200), 0)
	hud.tray.touch(false, c + Vector2(0, -400), 0)
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], 0, "dragged slot 0")


func test_pause_dims_and_disables() -> void:
	var m := _model()
	m.paused = true
	hud.apply(m)
	assert_lt(hud.action.modulate.a, 1.0, "widgets dimmed")
	assert_eq(hud.dim.modulate.a, 1.0, "the stage dim keeps its strength")
	var got := []
	hud.action_down.connect(func(v: int) -> void: got.append(v))
	hud.action.touch(true, Vector2(120, 120), 0)
	assert_eq(got, [], "no intents while paused")
	m.paused = false
	hud.apply(m)
	hud.action.touch(true, Vector2(120, 120), 0)
	assert_eq(got.size(), 1)


func test_running_gag_banner_text() -> void:
	assert_eq(RunningGagBanner.mult_text(100), "×1")
	assert_eq(RunningGagBanner.mult_text(150), "×1.5")
	assert_eq(RunningGagBanner.mult_text(200), "×2")
	assert_eq(RunningGagBanner.mult_text(300), "×3")
	var m := _model()
	hud.apply(m)
	assert_true(hud.banner.visible, "live Running Gag")
	assert_eq(hud.banner.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never a target")


func test_meter_counts_up_and_hides_unlimited_tomatoes() -> void:
	var m := _model()
	hud.apply(m)
	hud.meter.snap()
	assert_eq(hud.meter.displayed(), 42)
	m.tomatoes_max = -1
	m.tomatoes_left = -1
	hud.apply(m)
	var tr: Control = hud.meter.get_node("Tomatoes")
	assert_false(tr.visible, "unlimited tomatoes are hidden")


func test_figgis_states() -> void:
	var m := _model()
	m.figgis_pulse = true
	hud.apply(m)
	assert_eq(hud.figgis.state, FiggisChip.State.PULSE)
	hud.show_figgis_card(PackedStringArray(["squeaker", "tea"]))
	assert_eq(hud.figgis.state, FiggisChip.State.CARD)
	UiKit.now_override = 100000 + 4100
	hud.figgis._refresh_state()
	assert_eq(hud.figgis.state, FiggisChip.State.PULSE, "the card goes after 4 s")
	m.figgis_ghost = true
	hud.apply(m)
	assert_eq(hud.figgis.state, FiggisChip.State.GHOST)


func test_pick_strip_times_out_after_3s() -> void:
	hud.apply(_model())
	assert_true(hud.pick_strip.visible)
	UiKit.now_override = 100000 + 2900
	hud.pick_strip.tick()
	assert_true(hud.pick_strip.visible)
	UiKit.now_override = 100000 + 3000
	hud.pick_strip.tick()
	assert_false(hud.pick_strip.visible, "3 s timeout")
	hud.apply(_model())
	assert_false(hud.pick_strip.visible, "the same items do not reopen it")


func test_non_targets_ignore_touches() -> void:
	assert_eq(hud.root.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.panel_host.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for w in [hud.action, hud.clarence, hud.tray, hud.meter, hud.pip, hud.pause_button, hud.overview, hud.figgis]:
		assert_eq((w as Control).mouse_filter, Control.MOUSE_FILTER_STOP, "%s is a STOP target" % w.name)


# --- D17 / r3d-fix-perf RQ1: the contextual pieces' first show is primed under the curtain ------------------

func test_warm_contextual_shows_then_restores() -> void:
	var m := HudModel.new()
	hud.apply(m)
	assert_false(hud.meter.visible)
	assert_false(hud.banner.visible)
	assert_false(hud.edge_bubble.visible)
	hud.warm_contextual()
	assert_eq(hud.warm_left, Hud.WARM_FRAMES)
	assert_true(hud.meter.visible, "the meter is shown for the warm frames")
	assert_true(hud.banner.visible, "the Running Gag fuse too")
	assert_ne(hud.banner._text, "", "with its real string")
	assert_true(hud.edge_bubble.visible, "and the edge badge")
	assert_true(hud.get_node_or_null(^"Root/WarmPrimer") != null, "the glyph primer draws the pieces' glyph sets")
	hud._process(0.016)
	hud.apply(m)
	assert_true(hud.meter.visible, "apply() keeps the meter up while warming")
	for f in Hud.WARM_FRAMES:
		hud._process(0.016)
	assert_eq(hud.warm_left, 0)
	assert_false(hud.meter.visible, "then everything is back to the model")
	assert_false(hud.banner.visible)
	assert_eq(hud.banner._text, "")
	assert_false(hud.edge_bubble.visible)
	hud.apply(m)
	assert_eq(hud.last_changes, 0, "the warm-up changed no model state")


func test_warm_contextual_leaves_a_live_running_gag_alone() -> void:
	var m := _model()
	hud.apply(m)
	var txt: String = hud.banner._text
	hud.warm_contextual()
	for f in Hud.WARM_FRAMES:
		hud._process(0.016)
	assert_true(hud.banner.visible, "a live Running Gag keeps its fuse")
	assert_eq(hud.banner._text, txt)
	assert_true(hud.meter.visible, "and its meter")


func test_warm_activity_icons_rasterise_before_play() -> void:
	var ids := PackedStringArray(["exit", "fixup_mirror", ""])
	assert_eq(Hud.warm_activity_icons(ids), 2, "the empty id is skipped")
	assert_true(UiIcons._cache.has("res://art/icons/activities/exit.svg@%s" % UiIcons.RASTER_SCALE))
	var t0 := Time.get_ticks_usec()
	Hud._activity_icon("res://art/icons/activities/fixup_mirror.svg")
	assert_lt(Time.get_ticks_usec() - t0, 300, "the edge badge's later lookup is a cache hit")
