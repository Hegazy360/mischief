## Small s2-view pieces: hidden-eyes tracking math and blink seeding, HapticsDirector mapping +
## the Settings toggle, SimDriver's ⏩ drop parity with SimFf and scripted command replay,
## PropView state rules (rigged_<prank>, open, occupied), outline tint per room, words from the
## `fx.*` keys, the stare strip from the sim's sight ranges, PipView.warm.
extends TestBase


class _FakeHaptics extends Node:
	var got: Array = []

	func pulse(kind: StringName) -> bool:
		got.append(kind)
		return true


func test_pupils_track_within_the_range() -> void:
	var r := Vector2(6, 3)
	var right := HiddenEyes.pupil_offset(Vector2.ZERO, Vector2(900, 0), r)
	assert_almost_eq(right.x, 6.0, 0.01, "far right → full +6")
	assert_almost_eq(right.y, 0.0, 0.01)
	var left_up := HiddenEyes.pupil_offset(Vector2.ZERO, Vector2(-900, -900), r)
	assert_almost_eq(left_up.x, -6.0, 0.01)
	assert_almost_eq(left_up.y, -3.0, 0.01, "clamped to ±3 vertically")
	var near := HiddenEyes.pupil_offset(Vector2.ZERO, Vector2(40, 0), r)
	assert_lt(absf(near.x), 6.0, "close targets deflect less")
	assert_eq(HiddenEyes.pupil_offset(Vector2.ZERO, Vector2.INF, r), Vector2.ZERO)


func test_blinks_are_seeded_between_2_and_6_seconds() -> void:
	var seen := {}
	for sd in range(1, 200):
		var g := HiddenEyes.blink_gap_s(sd)
		assert_between(g, 2.0, 6.0)
		seen[snappedf(g, 0.5)] = true
	assert_ge(seen.size(), 5, "gaps vary with the seed")
	assert_eq(HiddenEyes.blink_gap_s(42), HiddenEyes.blink_gap_s(42), "deterministic")


func test_hidden_eyes_blink_for_six_frames() -> void:
	var e := HiddenEyes.new()
	tree.root.add_child(e)
	e.setup("", 3)
	e.visible = true
	var blinking := 0
	for i in 60 * 7:
		e.tick(1.0 / 60.0)
		if e.is_blinking():
			blinking += 1
	assert_between(blinking, 6, 30, "one to four 6-frame blinks in 7 s")
	e.queue_free()


func test_haptics_mapping_and_toggle() -> void:
	assert_eq(HapticsDirector.pulse_for({"e": "rigged"}), &"rig_done")
	assert_eq(HapticsDirector.pulse_for({"e": "reaction_accent"}), &"accent")
	assert_eq(HapticsDirector.pulse_for({"e": "near_miss"}), &"near_miss")
	assert_eq(HapticsDirector.pulse_for({"e": "caught"}), &"caught")
	assert_eq(HapticsDirector.pulse_for({"e": "meltdown_stomp"}), &"stomp")
	assert_eq(HapticsDirector.pulse_for({"e": "cmd_rejected"}), &"", "a rejected tap never buzzes")
	var hd := HapticsDirector.new()
	var fh := _FakeHaptics.new()
	tree.root.add_child(hd)
	tree.root.add_child(fh)
	hd.setup(null, fh)
	hd.on_ticked([{"e": "rigged"}, {"e": "hush_go"}, {"e": "meltdown_stomp", "n": 1}, {"e": "meltdown_stomp", "n": 2}])
	assert_eq(fh.got, [&"rig_done", &"stomp", &"stomp"])
	var st := ViewKit.autoload("Settings")
	if st != null and st.has_method("set_value"):
		var was: Variant = st.call("get_value", "haptics", true)
		st.call("set_value", "haptics", false)
		hd.on_ticked([{"e": "caught"}])
		assert_eq(fh.got.size(), 3, "Settings haptics off → nothing")
		st.call("set_value", "haptics", was)
	hd.queue_free()
	fh.queue_free()


func test_ff_drop_rule_matches_sim_ff() -> void:
	for ev in [{"e": "prank_fire"}, {"e": "spot_start"}, {"e": "entry_warning", "room": "kitchen"},
			{"e": "entry_warning", "room": "hall"}, {"e": "entry_warning"}, {"e": "micro_gag"}]:
		var want := SimFf.drops(ev, "kitchen")
		assert_eq(SimDriver.ff_drops(ev, "kitchen"), want, "same ⏩ drop as SimFf for %s" % ev)


func test_scripted_commands_feed_their_tick() -> void:
	var by := SimDriver.cmds_by_tick({"cmds": [[3, {"c": "go"}], [3, {"c": "freeze"}], [7, {"c": "pop"}]]})
	assert_eq((by[3] as Array).size(), 2)
	assert_eq((by[7] as Array).size(), 1)
	var d := SimDriver.new()
	tree.root.add_child(d)
	var fw := FakeWorld.create()
	d.setup(fw)
	d.set_script_cmds(by)
	assert_eq(d.script_last_tick(), 7)
	d.queue_free()


func test_prop_state_rules() -> void:
	var have := {"idle": 1, "open": 1, "rigged": 1, "rigged_it_takes_two": 1, "occupied": 1}
	assert_eq(PropView.state_for({}, false, "", have), "idle")
	assert_eq(PropView.state_for({}, true, "", have), "open")
	assert_eq(PropView.state_for({"rigged": true}, false, "allegro_go_go", have), "rigged")
	assert_eq(PropView.state_for({"rigged": true}, false, "it_takes_two", have), "rigged_it_takes_two",
		"rigged_<prank> when that prank is the rigged one")
	assert_eq(PropView.state_for({"occupant": true}, false, "", have), "occupied")
	assert_eq(PropView.state_for({"spent": true, "rigged": true}, false, "", have), "spent")


func test_outlines_are_gold_on_the_pale_rooms() -> void:
	assert_eq(PropView.outline_tint("kitchen"), Color("#FFC93C"))
	assert_eq(PropView.outline_tint("hall"), Color("#FFC93C"))
	assert_ne(PropView.outline_tint("bedroom"), Color("#FFC93C"))


func test_words_come_from_fx_keys_with_a_fallback() -> void:
	assert_eq(ViewKit.word("fx.no_such_key_s2_view", "LITERAL"), "LITERAL")
	var us := ViewKit.soft_script(ViewKit.UI_STRINGS)
	if us != null and bool(us.call("has", "fx.spotted")):
		assert_eq(ViewKit.word("fx.spotted", "X"), String(us.call("t", "fx.spotted")))


func test_stare_strip_uses_the_sims_sight() -> void:
	var b := ViewSnapshot.Actor.new()
	b.present = true
	b.sight_known = true
	b.sight_moving = 480.0
	b.sight_frozen = 200.0
	var r := FxStareStrip.ranges(b, "specs_off", "normal")
	assert_eq(r, Vector3(480, 200, FxStareStrip.Mode.AMBER), "the sim's numbers, not the table")
	b.sight_wall = true
	r = FxStareStrip.ranges(b, "specs_on", "normal")
	assert_eq(r.x, FxStareStrip.WALL)
	assert_eq(int(r.z), FxStareStrip.Mode.SPECS)
	b.sight_wall = false
	b.sight_moving = 0.0
	b.sight_frozen = 0.0
	assert_eq(int(FxStareStrip.ranges(b, "", "normal").z), FxStareStrip.Mode.GREY, "blind → grey")
	b.sight_known = false
	b.sight_moving = 0.0
	assert_eq(FxStareStrip.ranges(b, "specs_off", "normal"), Vector3(600, 250, FxStareStrip.Mode.AMBER), "table fallback")


func test_pip_warm_renders_once_while_hidden() -> void:
	var p := PipView.new()
	tree.root.add_child(p)
	await tree.process_frame
	var n0 := p.renders()
	assert_true(p.warm())
	assert_false(p.is_shown(), "warming never shows it")
	assert_eq(p.renders(), n0 + 1)
	assert_eq(p.canvas_cull_mask & PipView.FX_LAYER_BIT, 0, "FX layer 2 is culled")
	p.queue_free()


func test_detour_and_exit_bubble_icons() -> void:
	assert_true(ViewSnapshot.is_detour("fixup_mirror"))
	assert_true(ViewSnapshot.is_detour("hunt"))
	assert_false(ViewSnapshot.is_detour("tea"))
	assert_eq(ViewSnapshot.icon_for("exit"), "res://art/icons/activities/exit.svg")
	assert_eq(ViewSnapshot.icon_for("fixup_dry"), "res://art/icons/activities/fixup_dry.svg")


## Texture memory of the slice rooms at ART_SCALE 2 (room art + every prop state + outlines at
## 1× + decor, with per-prop `raster` hints), reported for the atlas budget (art-house request 9).
func test_slice_room_texture_budget_report() -> void:
	var h := HouseLayout.load_default()
	if h.source == "greybox":
		skip("no house.json")
		return
	var total := 0.0
	var lines := PackedStringArray()
	for room in ["porch", "hall", "parlour", "kitchen"]:
		var px := 0.0
		var r := h.room(room)
		if r != null and r.art_size != Vector2.ZERO:
			px += r.art_size.x * r.art_size.y * 4.0 * (1 if r.art_fg == "" else 2)
		for hs in h.hotspots:
			if hs.room != room:
				continue
			for k in hs.art:
				var t := ViewKit.tex(ViewKit.s(hs.art[k])) if hs.art[k] is String else null
				if t == null:
					continue
				var s := 1.0 if ViewKit.s(k) == "outline" else (hs.raster if hs.raster > 0.0 else 2.0)
				px += t.get_size().x * t.get_size().y * s * s
		for d in h.decor:
			if d.room != room:
				continue
			var s2 := d.raster if d.raster > 0.0 else 2.0
			var n := maxi(1, d.frames.size()) + maxi(0, d.art.size() - 1)
			px += d.size.x * d.size.y * s2 * s2 * float(n)
		var mb := px * 4.0 / 1048576.0
		total += mb
		lines.append("%s %.1f MB" % [room, mb])
	print("[view tex] slice rooms at ART_SCALE: %s; total %.1f MB" % [", ".join(lines), total])
	assert_lt(total, 150.0, "slice rooms under the 150 MB texture target (rigs extra)")
