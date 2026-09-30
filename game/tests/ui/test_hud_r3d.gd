## The decluttered HUD (REDESIGN_3D §2.1–§2.4, r3d-hud brief §4.1–§4.3, §5): exactly four always-on
## pieces in every PLAY state (`debug_pieces`), the contextual rules (meter 2.5 s after a change and
## during a Running Gag, chips only while carrying, Figgis 4 s, BOW after ★, overview hidden, the edge
## badge incl. `lean`), QUIET / LIVE with hysteresis, the Script pips (+ the lines fallback) and the
## tag flight.
extends TestBase

var hud: Hud
var t: int = 100000


func before_each() -> void:
	t = 100000
	UiKit.now_override = t
	hud = Hud.new()
	hud.layout_size_override = Vector2(2400, 1080)
	hud.insets_override = Vector4.ZERO
	hud.relayout()


func after_each() -> void:
	hud.free()
	UiKit.now_override = -1


func _step(ms: int) -> void:
	t += ms
	UiKit.now_override = t
	hud.action.tick()
	hud._tick_contextual()


func _rest() -> HudModel:
	var m := HudModel.new()
	m.applause = 20
	m.lines_done = 1
	m.lines_total = 3
	m.verb = HudModel.Verb.FREEZE
	return m


func _always_on_names() -> PackedStringArray:
	var out := PackedStringArray()
	for p in hud.debug_pieces():
		if bool((p as Dictionary)["always_on"]):
			out.append(String((p as Dictionary)["name"]))
	return out


func test_exactly_four_always_on_pieces_in_every_play_state() -> void:
	var states := {}
	var m := _rest()
	states["rest"] = m
	var rig := _rest()
	rig.verb = HudModel.Verb.RIG
	rig.ring_frac = 0.5
	rig.tray = PackedStringArray(["squeaker"])
	states["rigging"] = rig
	var hid := _rest()
	hid.verb = HudModel.Verb.POP_OUT
	hid.clarence_mode = HudModel.ClarenceMode.FF
	states["hidden"] = hid
	var danger := _rest()
	danger.freeze_danger = 2
	danger.pip_visible = true
	states["danger"] = danger
	var busy := _rest()
	busy.link = 2
	busy.bow_visible = true
	busy.figgis_visible = true
	busy.edge_bubble_dir = Vector2(1, 0)
	busy.tray = PackedStringArray(["kipper", "flour"])
	states["busy"] = busy
	for k in states:
		hud.apply(states[k])
		var names := _always_on_names()
		names.sort()
		assert_eq(names, PackedStringArray(["action", "clarence", "pause", "script"]), "state %s" % k)
		assert_eq(hud.always_on_rects().size(), 4)


func test_at_rest_only_the_four_are_on_screen() -> void:
	hud.apply(_rest())
	var shown := PackedStringArray()
	for p in hud.debug_pieces():
		shown.append(String((p as Dictionary)["name"]))
	shown.sort()
	assert_eq(shown, PackedStringArray(["action", "clarence", "pause", "script"]), "no empty tray, no meter, no Figgis")


func test_no_persistent_piece_in_the_middle_band_but_the_action_circle() -> void:
	var m := _rest()
	m.link = 2
	m.tray = PackedStringArray(["kipper"])
	m.pip_visible = true
	hud.apply(m)
	var band := HudLayout.middle_band(hud.viewport_size())
	for p in hud.debug_pieces():
		var d: Dictionary = p
		if not (bool(d["always_on"]) or bool(d["persistent"])) or d["name"] == "action":
			continue
		assert_false(band.intersects(d["rect"]), "%s %s in y 250–880" % [d["name"], d["rect"]])


func test_meter_shows_2_5_s_after_an_applause_change() -> void:
	var m := _rest()
	hud.apply(m)
	assert_false(hud.meter.visible, "no change yet: hidden")
	m.applause = 55
	hud.apply(m)
	assert_true(hud.meter.visible)
	assert_eq(hud.meter.delta_text(), "+35", "the delta stamp")
	_step(2400)
	assert_true(hud.meter.visible)
	_step(200)
	assert_false(hud.meter.visible, "gone after 2.5 s")


func test_meter_stays_while_a_running_gag_is_live() -> void:
	var m := _rest()
	m.link = 1
	m.mult_pct = 150
	hud.apply(m)
	_step(6000)
	assert_true(hud.meter.visible)
	assert_true(hud.banner.visible or hud.banner.link > 0, "the fuse under it")
	m.link = 0
	hud.apply(m)
	_step(10)
	assert_false(hud.meter.visible)


func test_meter_until_from_the_model() -> void:
	var m := _rest()
	m.meter_until_s = float(t + 1000) / 1000.0
	hud.apply(m)
	assert_true(hud.meter.visible)
	_step(1100)
	assert_false(hud.meter.visible)


func test_tomatoes_show_in_the_meter_on_a_catch() -> void:
	var m := _rest()
	m.tomatoes_max = 3
	m.tomatoes_left = 3
	hud.apply(m)
	m.tomatoes_left = 2
	hud.apply(m)
	assert_true(hud.meter.visible)
	assert_true(hud.meter.tomatoes_showing())
	_step(2600)
	assert_false(hud.meter.visible)


func test_chips_only_while_carrying() -> void:
	var m := _rest()
	hud.apply(m)
	assert_false(hud.tray.visible, "no empty slots")
	m.tray = PackedStringArray(["squeaker"])
	hud.apply(m)
	assert_true(hud.tray.visible)
	var r := Rect2(hud.tray.position, hud.tray.size * hud.tray.scale)
	assert_eq(r.position, Vector2(224, 1080 - 188), "(S+224, H−B−188)")
	m.tray = PackedStringArray()
	hud.apply(m)
	assert_false(hud.tray.visible)
	m.carrying = true
	hud.apply(m)
	assert_true(hud.tray.visible, "carrying forces the chips on")


func test_figgis_4_s_after_a_nudge_and_with_a_card() -> void:
	var m := _rest()
	hud.apply(m)
	assert_false(hud.figgis.visible, "no idle Figgis chip")
	m.figgis_pulse = true
	hud.apply(m)
	assert_true(hud.figgis.visible)
	_step(3900)
	assert_true(hud.figgis.visible)
	_step(200)
	assert_false(hud.figgis.visible, "auto-hides after 4 s")
	hud.show_figgis_card(PackedStringArray(["squeaker", "arrow", "tea"]), 4.0)
	assert_true(hud.figgis.visible, "a card cue shows him")
	_step(4100)
	assert_false(hud.figgis.visible)
	m.figgis_visible = true
	hud.apply(m)
	assert_true(hud.figgis.visible, "forced on")


func test_bow_after_the_star_and_overview_hidden_by_default() -> void:
	var m := _rest()
	hud.apply(m)
	assert_false(hud.bow.visible)
	assert_false(hud.overview.visible, "hidden in Act I")
	m.bow_visible = true
	m.overview_visible = true
	hud.apply(m)
	assert_true(hud.bow.visible)
	assert_true(hud.overview.visible)
	var got := []
	hud.bow_tap.connect(func() -> void: got.append(1))
	hud.bow.touch(true, Vector2(160, 56), 0)
	hud.bow.touch(false, Vector2(160, 56), 0)
	assert_eq(got.size(), 1, "BOW → bow_tap")


func test_edge_badge_rules() -> void:
	var m := _rest()
	m.edge_bubble_dir = Vector2(-1, 0)
	m.edge_badge_icon = "tea"
	hud.apply(m)
	assert_true(hud.edge_bubble.visible, "off-screen, no window: the badge")
	assert_eq(hud.edge_bubble.position, (hud.layout[&"edge_left"] as Rect2).position, "left edge zone")
	m.pip_visible = true
	hud.apply(m)
	assert_false(hud.edge_bubble.visible, "the window shows him instead")
	m.pip_visible = false
	m.edge_bubble_dir = Vector2.ZERO
	m.edge_badge_lean = true
	m.edge_badge_side = 1
	hud.apply(m)
	assert_true(hud.edge_bubble.visible, "lean: the badge stands in for the closed window")
	assert_eq(hud.edge_bubble.position, (hud.layout[&"edge_right"] as Rect2).position)


func test_quiet_and_live_faces() -> void:
	var m := _rest()
	hud.apply(m)
	assert_false(hud.action.shown_live, "FREEZE with no danger is QUIET")
	m.freeze_danger = 1
	hud.apply(m)
	assert_true(hud.action.shown_live, "exposed in his room: FREEZE LIVE (at once: nothing changed for ≥ 250 ms)")
	assert_eq(hud.action.freeze_danger, 1)
	_step(100)
	m.freeze_danger = 0
	hud.apply(m)
	assert_true(hud.action.shown_live, "hysteresis ≥ 250 ms: no flicker back")
	_step(200)
	assert_false(hud.action.shown_live, "QUIET again once 250 ms passed")
	m.verb = HudModel.Verb.RIG
	hud.apply(m)
	_step(300)
	assert_true(hud.action.shown_live, "RIG is always LIVE")
	assert_true(Hud.is_live(m))
	m.verb = HudModel.Verb.FREEZE
	m.verb_live = true
	assert_true(Hud.is_live(m), "MIRROR's FREEZE LIVE")


func test_script_pips_from_the_model_and_the_fallbacks() -> void:
	var m := _rest()
	m.script_pips = PackedInt32Array([HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_OPEN, HudModel.Pip.OPT_OPEN,
		HudModel.Pip.BIG_SEALED])
	hud.apply(m)
	assert_eq(hud.script_chip.pips, m.script_pips)
	assert_eq(hud.script_chip.counts(), Vector2i(2, 1))
	assert_almost_eq(hud.script_chip.pill_width(), 112.0 + 92.0 + 22.0 + 50.0, 0.01)
	var m2 := _rest()
	m2.script_lines = [{"id": "a", "req": true, "done": true}, {"id": "b", "req": true}, {"id": "c"},
		{"id": "bn", "big_number": true, "sealed": true}]
	hud.apply(m2)
	assert_eq(hud.script_chip.pips, PackedInt32Array([HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_OPEN,
		HudModel.Pip.OPT_OPEN, HudModel.Pip.BIG_SEALED]), "derived from the Script lines")
	assert_eq(ScriptChip.pips_from_counts(1, 3), PackedInt32Array([HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_OPEN,
		HudModel.Pip.REQ_OPEN]))


func test_script_chip_grows_and_relayouts() -> void:
	var m := _rest()
	var p := PackedInt32Array()
	for i in 6:
		p.append(HudModel.Pip.REQ_OPEN)
	p.append(HudModel.Pip.BIG_SEALED)
	m.script_pips = p
	hud.apply(m)
	assert_almost_eq((hud.layout[&"script"] as Rect2).size.x, 112.0 + 276.0 + 50.0, 0.01)
	assert_eq(Rect2(hud.script_chip.position, hud.script_chip.size), hud.layout[&"script"])


func test_script_chip_tap_opens_the_script() -> void:
	var got := []
	hud.meter_tap.connect(func() -> void: got.append(1))
	hud.script_chip.touch(true, Vector2(100, 72), 0)
	hud.script_chip.touch(false, Vector2(100, 72), 0)
	assert_eq(got.size(), 1)


func test_tag_flight_lands_on_its_pip() -> void:
	var m := _rest()
	m.script_pips = PackedInt32Array([HudModel.Pip.REQ_OPEN, HudModel.Pip.REQ_OPEN])
	hud.apply(m)
	var landed := []
	hud.tag_arrived.connect(func(i: int) -> void: landed.append(i))
	hud.fly_tag(Vector2(1200, 600), 1)
	var f: TagFlight = null
	for x in hud.flights:
		if x.running:
			f = x
	assert_true(f != null, "a flight started")
	assert_eq(f.to, hud.script_pip_center(1))
	f._process(0.3)
	assert_true(f.running)
	f._process(0.31)
	assert_false(f.running, "0.6 s")
	assert_eq(landed, [1])
	var mid := TagFlight.point_at(Vector2(0, 500), Vector2(400, 100), 0.5)
	assert_lt(mid.y, 300.0, "it arcs up")
	# the model path (consumed once)
	m.tag_flights = [{"line_index": 0, "from": Vector2(900, 500)}]
	hud.apply(m)
	assert_true(m.tag_flights.is_empty(), "consumed")


func test_open_pause_menu_reemits_hint_and_map() -> void:
	var got := []
	hud.hint_tap.connect(func() -> void: got.append("hint"))
	hud.map_open.connect(func() -> void: got.append("map"))
	var p := hud.open_pause_menu(false, {"applause": 12})
	assert_true(p.actions().has("hint") and p.actions().has("map"))
	p.closed.emit("map")
	assert_eq(got, ["map"])


func test_apply_repeat_is_a_no_op_with_the_r3d_fields() -> void:
	var m := _rest()
	m.freeze_danger = 1
	m.bow_visible = true
	m.script_pips = PackedInt32Array([HudModel.Pip.REQ_DONE])
	m.edge_badge_icon = "tea"
	m.pip_next_icon = "tea"
	m.lure_ring = HudModel.LureRing.ON
	hud.apply(m)
	hud.apply(m)
	assert_eq(hud.last_changes, 0)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_usec()
	for i in 500:
		hud.apply(m)
	var per := float(Time.get_ticks_usec() - t0) / 500.0
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no objects per apply")
	print("[perf] Hud.apply steady state: %.1f µs" % per)
	assert_lt(per, 250.0 * TestBase.cpu_load_scale())
