## Panels (ui brief §3.4) and the Router's generated Coming-soon route.
extends TestBase


func after_each() -> void:
	UiKit.now_override = -1


func _add(p: Control) -> Control:
	tree.root.add_child(p)
	p.size = Vector2(2400, 1080)
	return p


func test_pause_menu_actions_and_bow_only_with_a_star() -> void:
	var p := PauseMenu.new()
	p.setup(false)
	_add(p)
	assert_eq(p.actions(), PackedStringArray(["resume", "retry", "hint", "map", "settings", "playbill"]),
		"no Take a Bow before ★; R3D adds Hint and Map")
	p.setup(true)
	assert_eq(p.actions(), PackedStringArray(["resume", "retry", "bow", "hint", "map", "settings", "playbill"]))
	var b: UiButton = p.buttons["resume"]
	assert_eq(b.visual_rect().size.y, 96.0, "96 px-tall buttons")
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	var bow: UiButton = p.buttons["bow"]
	bow.touch(true, bow.size * 0.5, 0)
	bow.touch(false, bow.size * 0.5, 0)
	assert_eq(got, ["bow"])
	p.queue_free()


func test_pause_menu_back_resumes() -> void:
	var p := PauseMenu.new()
	_add(p)
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	assert_true(p.handle_back())
	assert_eq(got, ["resume"])
	p.queue_free()


func test_pause_buttons_are_24px_apart_and_fit() -> void:
	var p := PauseMenu.new()
	p.setup(true, {"applause": 87, "tomatoes_left": 2, "tomatoes_max": 3, "curtain_calls": 1})
	_add(p)
	var acts := p.actions()
	var rects: Array[Rect2] = []
	for a in acts:
		var b: UiButton = p.buttons[a]
		rects.append(Rect2(b.position, b.size))
		assert_ge(b.size.y, 120.0, "%s: 120 px hit" % a)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].grow(11.9).intersects(rects[j].grow(11.9)), "%s / %s ≥ 24 px apart" % [acts[i], acts[j]])
	assert_le(p.card.size.y, 1080.0, "seven buttons + header fit a phone")
	p.queue_free()


func test_script_panel_rows() -> void:
	var p := ScriptPanel.new()
	var lines := [{"id": "a", "text": "Bellows sings a duet with his kettle", "req": true, "done": true},
		{"id": "b", "text": "", "discovered": false}, {"id": "bn", "text": "x", "big_number": true, "sealed": true}]
	p.setup(lines, [{"activity": "tea", "rigged": true}])
	assert_eq(p.done_count, 1)
	assert_eq(p.total_count, 2, "the Big Number is not counted")
	_add(p)
	assert_eq(p.card.size, Vector2(1000, 680), "1000 × 680")
	assert_eq(ScriptPanel.row_height(6), 84.0, "84 px rows for up to 6 lines")
	assert_lt(ScriptPanel.row_height(7), 84.0, "7 lines compress to fit")
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	UiKit.now_override = Time.get_ticks_msec() + 1000
	p._scrim_tap(Vector2.ZERO)
	assert_eq(got, ["close"], "a tap closes the Script")
	p.queue_free()


func test_script_text_fits() -> void:
	var f := UiKit.ui_font()
	var long := "Bellows discovers that his favourite kettle can sing a far better duet than he ever could"
	var s := ScriptPanel.fit_size(f, long, 700.0, 44)
	assert_ge(s, UiKit.SIZE_MIN, "never below 36 px")
	var clipped := ScriptPanel.clip_text(f, long, 700.0, s)
	assert_le(f.get_string_size(clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x, 700.0)
	assert_true(clipped.ends_with("…"))


func test_settings_panel_covers_every_setting_with_big_rows() -> void:
	var keys := []
	for t in SettingsPanel.TAB_ORDER:
		for spec in SettingsPanel.TABS[t]:
			keys.append(String(spec[0]))
	keys.sort()
	var want := ["crowd_vol", "haptics", "hints", "left_handed", "music_vol", "reduce_flash", "reduce_motion",
		"relaxed", "sfx_vol", "stare_strip", "tap_to_rig", "text_scale", "voice_vol"]
	assert_eq(keys, want, "every GDD §3.11 setting")
	assert_ge(SettingsPanel.ROW_H, 144.0, "rows ≥ 144 px hit")
	var p := SettingsPanel.new()
	_add(p)
	for t in SettingsPanel.TAB_ORDER:
		p.select_tab(t)
		for k in p.rows:
			var r: Control = p.rows[k]
			assert_ge(r.size.y, 144.0, "%s row hit ≥ 144" % k)
	p.queue_free()


func test_settings_panel_writes_values() -> void:
	var p := SettingsPanel.new()
	var fake := _FakeSettings.new()
	p.settings_node = fake
	_add(p)
	p.select_tab("play")
	var row: TouchWidget = p.rows["left_handed"]
	row.touch(true, Vector2(100, 72), 0)
	row.touch(false, Vector2(100, 72), 0)
	assert_eq(fake.values.get("left_handed"), true, "tapping the row toggles")
	p.select_tab("sound")
	var sl: TouchWidget = p.rows["music_vol"]
	var cr: Rect2 = sl.call("_ctrl_rect")
	sl.touch(true, Vector2(cr.position.x + 44.0, 72), 0)
	sl.touch(false, Vector2(cr.position.x + 44.0, 72), 0)
	assert_almost_eq(float(fake.values.get("music_vol")), 0.0, 0.001, "slider left end = 0")
	p.select_tab("play")
	var ch: TouchWidget = p.rows["hints"]
	var chr: Rect2 = ch.call("_ctrl_rect")
	var seg := Vector2(chr.position.x + 244.0 + 110.0, 72)
	ch.touch(true, seg, 0)
	ch.touch(false, seg, 0)
	assert_eq(fake.values.get("hints"), "long_press")
	p.free()
	fake.free()


func test_loading_card_timing() -> void:
	var p := LoadingCard.new()
	p.setup({"title": "NIGHT 2", "text": "Hold FREEZE to be a statue. Specs off, he only spots what moves. Specs on, get out of sight.",
		"icon": "freeze"})
	assert_le(p.word_count(), 25, "≤ 25 words")
	_add(p)
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	# the card's own clock (its curtain art rasterises in _ready, which can take a while on a busy box)
	var t0 := p._open_ms
	p.set_process(false)   # only the test's clock drives it
	UiKit.now_override = t0 + 500
	p._scrim_tap(Vector2.ZERO)
	assert_eq(got, [], "taps in the first second are ignored")
	UiKit.now_override = t0 + 1100
	p._scrim_tap(Vector2.ZERO)
	assert_eq(got, ["start"], "tap to start after 1 s")
	p.queue_free()
	var p2 := LoadingCard.new()
	p2.setup({"text": "x"})
	_add(p2)
	var got2 := []
	p2.closed.connect(func(a: String) -> void: got2.append(a))
	# relative to the card's own open time, whatever the clock did while it was built (s2-fix G #6)
	UiKit.now_override = p2._open_ms + 4100
	p2._tick()
	assert_eq(got2, ["start"], "auto after 4 s")
	p2.queue_free()


func test_results_screen_buttons() -> void:
	var p := ResultsScreen.new()
	p.setup({"applause": 91, "stars": [true, false, false], "why": "Applause 91 — land one more prank inside a Running Gag",
		"new": ["ACHOO-RIA!"], "has_next": true})
	_add(p)
	assert_eq(p.next_button.size.y, 240.0, "Next Night ▶ is the big 240 px default")
	assert_gt(p.next_button.position.x, p.size.x * 0.5, "…under the right thumb")
	assert_eq(p.gag_reel_rect().size, ResultsScreen.REEL)
	var got := []
	p.closed.connect(func(a: String) -> void: got.append(a))
	p.next_button.touch(true, p.next_button.size * 0.5, 0)
	p.next_button.touch(false, p.next_button.size * 0.5, 0)
	assert_eq(got, ["next"])
	p.queue_free()


func test_results_count_up() -> void:
	var p := ResultsScreen.new()
	p.setup({"applause": 120})
	_add(p)
	assert_eq(p.shown_applause(), 0, "starts at 0")
	UiKit.now_override = UiKit.now_ms() + 5000
	assert_eq(p.shown_applause(), 120, "ends at the total")
	p.queue_free()


func test_router_coming_soon_for_missing_routes() -> void:
	var rs := load("res://autoload/router.gd") as GDScript
	var r: Node = rs.new()
	tree.root.add_child(r)
	r.set("instant", true)
	(r.get("scene_overrides") as Dictionary)["playbill"] = "res://no/such/Playbill.tscn"
	var prev := tree.current_scene
	await r.call("goto", "playbill", {"from": "test"})
	var cur := tree.current_scene
	assert_true(cur is ComingSoonScreen, "a missing scene becomes the Coming soon screen")
	assert_eq(r.get("current_key"), "playbill")
	assert_true(bool(r.call("has_scene", "boot")), "boot exists")
	assert_false(bool(r.call("has_scene", "playbill")))
	if cur != null:
		cur.queue_free()
	tree.current_scene = prev
	r.queue_free()


class _FakeSettings:
	extends Node
	var values := {"left_handed": false, "music_vol": 0.7, "hints": "always"}

	func get_value(key: String, fallback: Variant = null) -> Variant:
		return values.get(key, fallback)

	func set_value(key: String, v: Variant) -> bool:
		values[key] = v
		return true
