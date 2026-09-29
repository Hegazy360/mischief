## Stage-2 panels and the Figgis chip (s2-ui §4.2.3, §4.2.6, §4.2.7): the chip's fallback chain
## (clips → the rig's poses → the single-image bust) with the card prop only in point / proud, the
## SettingsPanel's debug-only Gate-0 tab, the LoadingCard taking a live Texture2D (s2-ftue's rule
## vignette) and the PauseMenu's Take a Bow only with a ★.
extends TestBase

const FIXTURE_CLIP := "figgis/f_idle"

var _made: Array = []
var _registered: bool = false


func after_each() -> void:
	for p in _made:
		if is_instance_valid(p):
			(p as Node).free()
	_made.clear()
	if _registered:
		ClipLib.invalidate(FIXTURE_CLIP)
		_registered = false
	UiKit.now_override = -1


func _add(p: Node) -> Node:
	tree.root.add_child(p)
	_made.append(p)
	if p is Control:
		(p as Control).size = Vector2(2400, 1080)
	return p


func _chip(rig_id: String = FiggisChip.RIG_ID) -> FiggisChip:
	var c := FiggisChip.new()
	c.rig_id = rig_id
	tree.root.add_child(c)
	_made.append(c)
	return c


# --- the Figgis chip ----------------------------------------------------------------------------

func test_fallback_chain_is_pure() -> void:
	assert_eq(FiggisChip.level_for(false, false), FiggisChip.Level.SVG)
	assert_eq(FiggisChip.level_for(false, true), FiggisChip.Level.SVG, "clips without a rig are useless")
	assert_eq(FiggisChip.level_for(true, false), FiggisChip.Level.POSES)
	assert_eq(FiggisChip.level_for(true, true), FiggisChip.Level.CLIPS)


func test_no_rig_is_the_single_image_bust() -> void:
	var c := _chip("")
	assert_eq(c.level, FiggisChip.Level.SVG)
	assert_eq(c.rig, null)
	assert_eq(c.mood_source, "svg")
	c.show_card(PackedStringArray(["tray", "arrow", "rig"]))
	assert_eq(c.state, FiggisChip.State.CARD, "the card still works without the rig")
	assert_false(c.card_prop_up(), "no rig, no prop")


func test_the_figgis_rig_is_used_when_it_exists() -> void:
	if RigDef.for_id("figgis") == null:
		skip("no figgis rig in data/rigs (s2-anim-hush)")
		return
	var c := _chip()
	assert_true(c.rig != null, "a RigPlayer inside the chip")
	var has_clip := ClipLib.get_clip(FIXTURE_CLIP) != null
	assert_eq(c.level, FiggisChip.Level.CLIPS if has_clip else FiggisChip.Level.POSES)
	if not has_clip:
		assert_eq(c.mood_source, "pose:f_rest", "idle = the rest pose")
		c.set_pulse(true)
		assert_eq(c.mood, "psst")
		assert_eq(c.mood_source, "pose:f_psst")
		c.react("shh", 1.0)
		assert_eq(c.mood_source, "pose:f_shh")


func test_card_prop_only_while_pointing_or_proud() -> void:
	if RigDef.for_id("figgis") == null:
		skip("no figgis rig")
		return
	UiKit.now_override = 50000
	var c := _chip()
	var pi := c.rig.props.index_of(FiggisChip.CARD_PROP)
	assert_ge(pi, 0, "the rig has the card prop")
	assert_eq(c.rig.props.mode[pi], PropSim.HIDDEN, "idle: the card is down")
	c.show_card(PackedStringArray(["rig", "arrow", "tea"]), 4.0)
	assert_eq(c.mood, "point")
	assert_true(c.card_prop_up())
	assert_ne(c.rig.props.mode[pi], PropSim.HIDDEN, "pointing: the card is up")
	assert_eq(c.card_icon_count(), 2, "cue icons: item → target (the arrow is drawn, not an icon)")
	UiKit.now_override = 50000 + 4100
	c._refresh_state()
	assert_eq(c.mood, "idle")
	assert_eq(c.rig.props.mode[pi], PropSim.HIDDEN, "card down again")
	c.react("proud", 1.0)
	assert_eq(c.mood, "proud")
	assert_ne(c.rig.props.mode[pi], PropSim.HIDDEN, "proud: the card held high")


func test_fixture_clip_lifts_the_chip_to_clips() -> void:
	if RigDef.for_id("figgis") == null:
		skip("no figgis rig")
		return
	if ClipLib.get_clip(FIXTURE_CLIP) == null:
		var d := {"version": 1, "clip": FIXTURE_CLIP, "rig": "figgis", "loop": true, "length": 60,
			"keys": [{"f": 0, "pose": "f_rest"}, {"f": 59, "pose": "f_rest"}]}
		ClipLib.register(ClipLib.from_dict(d, FIXTURE_CLIP))
		_registered = true
	var c := _chip()
	assert_eq(c.level, FiggisChip.Level.CLIPS)
	assert_eq(c.mood_source, "clip:" + FIXTURE_CLIP)
	c.set_pulse(true)
	# f_psst has no clip here → its pose
	if ClipLib.get_clip("figgis/f_psst") == null:
		assert_eq(c.mood_source, "pose:f_psst", "a mood without its clip uses its pose")


func test_chip_rig_is_cheap() -> void:
	if RigDef.for_id("figgis") == null:
		skip("no figgis rig")
		return
	var c := _chip()
	c.rig.advance(0.016)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		c.rig.advance(0.016)
	var per := float(Time.get_ticks_usec() - t0) / 200.0
	print("[perf] Figgis chip RigPlayer.advance: %.1f µs" % per)
	assert_lt(per, 1000.0, "well under a millisecond (budget 0.1 ms on device; measured %.1f µs here)" % per)


# --- SettingsPanel: the debug-only Gate-0 tab ---------------------------------------------------

func test_debug_tab_only_when_asked() -> void:
	var p := SettingsPanel.new()
	p.show_debug = false
	_add(p)
	assert_eq(p.tab_order(), PackedStringArray(["play", "sound", "comfort"]), "a release build has no Debug tab")
	assert_false(p.tab_buttons.has("debug"))
	p.select_tab("debug")
	assert_eq(p.tab, "play", "and it cannot be selected")
	var q := SettingsPanel.new()
	q.show_debug = true
	_add(q)
	assert_eq(q.tab_order(), PackedStringArray(["play", "sound", "comfort", "debug"]))
	q.select_tab("debug")
	assert_eq(q.rows.keys(), ["voice_style", "crowd_style", "hush_skin"], "the three Gate-0 keys")


func test_debug_rows_write_the_gate0_keys() -> void:
	var fake := _FakeSettings.new()
	_made.append(fake)
	var p := SettingsPanel.new()
	p.show_debug = true
	p.settings_node = fake
	_add(p)
	p.select_tab("debug")
	for spec in [["voice_style", 1, "tuba"], ["crowd_style", 1, "fallback"], ["hush_skin", 1, "pip"],
			["voice_style", 0, "formant"], ["hush_skin", 0, ""]]:
		var row: TouchWidget = p.rows[spec[0]]
		var cr: Rect2 = row.call("_ctrl_rect")
		var pos := Vector2(cr.position.x + float(spec[1]) * 244.0 + 110.0, 72)
		row.touch(true, pos, 0)
		row.touch(false, pos, 0)
		assert_eq(fake.values.get(spec[0]), spec[2], "%s segment %d" % [spec[0], spec[1]])
	for k in ["voice_style", "crowd_style", "hush_skin"]:
		for lab in SettingsPanel.CHOICE_LABELS[k]:
			assert_true(UiStrings.has(String(lab)), "label key " + String(lab))
		assert_eq(SettingsPanel.choices_for(k).size(), (SettingsPanel.CHOICE_LABELS[k] as Array).size())


func test_debug_choices_match_the_settings_autoload() -> void:
	var s := load("res://autoload/settings.gd") as GDScript
	var choices: Dictionary = s.get_script_constant_map()["CHOICES"]
	for k in SettingsPanel.CHOICES:
		assert_eq(Array(SettingsPanel.CHOICES[k]), Array(choices[k]), "same values as Settings.CHOICES." + k)


func test_settings_header_fits_four_tabs_at_every_width() -> void:
	for w in [2400.0, 1920.0, 2076.0]:
		var p := SettingsPanel.new()
		p.show_debug = true
		tree.root.add_child(p)
		_made.append(p)
		p.size = Vector2(w, 1080)
		var rects: Array[Rect2] = []
		for t in p.tab_order():
			var b: UiButton = p.tab_buttons[t]
			rects.append(Rect2(b.position, b.size))
			assert_ge(b.size.x, SettingsPanel.TAB_W_MIN, "tab ≥ %d px" % int(SettingsPanel.TAB_W_MIN))
			assert_ge(b.position.x, 0.0, "inside the card")
		rects.append(Rect2(p._done.position, p._done.size))
		for i in rects.size() - 1:
			assert_ge(rects[i + 1].position.x - rects[i].end.x, 24.0 - 0.01, "24 px between header buttons at %d" % int(w))


func test_settings_rows_on_every_tab_are_big_and_apart() -> void:
	var p := SettingsPanel.new()
	p.show_debug = true
	_add(p)
	for t in p.tab_order():
		p.select_tab(t)
		var ys: Array[float] = []
		for k in p.rows:
			var r: Control = p.rows[k]
			assert_ge(r.size.y, 144.0, "%s/%s row ≥ 144" % [t, k])
			ys.append(r.position.y)
		ys.sort()
		for i in ys.size() - 1:
			assert_ge(ys[i + 1] - ys[i], 144.0 + 24.0 - 0.01, "24 px between rows on " + t)
		var last: Control = null
		for k in p.rows:
			last = p.rows[k]
		assert_le(last.position.y + last.size.y, p.card.size.y + 0.5, "the last row fits the card on " + t)


# --- LoadingCard / PauseMenu -------------------------------------------------------------------

func test_loading_card_takes_a_live_texture() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	_add(vp)
	var p := LoadingCard.new()
	p.setup({"title": "NIGHT 2", "subtitle": "Something Fishy", "text": "Hold FREEZE to be a statue.",
		"icon": vp.get_texture()})
	_add(p)
	assert_eq(p.icon_texture, vp.get_texture(), "a Texture2D icon is kept as is")
	assert_eq(p.icon_key, "")
	var box := p.icon_box()
	assert_almost_eq(box.y, LoadingCard.VIGNETTE_H, 0.01, "framed at the vignette height")
	assert_ge(box.x, 144.0, "≥ 144 px")
	var q := LoadingCard.new()
	q.setup({"title": "NIGHT 1", "text": "x", "icon": "tray"})
	_add(q)
	assert_ge(q.icon_box().x, 144.0, "a key icon is ≥ 144 px")
	assert_true(q._icon != null, "the tray card icon is real art")


func test_loading_card_rule_stays_at_44px_and_fits() -> void:
	var p := LoadingCard.new()
	p.setup({"title": "NIGHT 2", "text": "Hold FREEZE to be a statue. Specs off, he only spots what moves. Specs on, get out of sight.",
		"icon": "freeze"})
	_add(p)
	assert_le(p.word_count(), 25)
	assert_ge(LoadingCard.TEXT_SIZE, 44, "the rule is read during play: 44 px")
	assert_le(p.card.size.y, 1080.0, "fits the screen")


func test_pause_menu_bow_only_with_a_star() -> void:
	var p := PauseMenu.new()
	p.setup(false)
	_add(p)
	assert_false(p.buttons.has("bow"))
	p.setup(true)
	assert_true(p.buttons.has("bow"))


class _FakeSettings:
	extends Node
	var values := {"voice_style": "formant", "crowd_style": "formant", "hush_skin": ""}

	func get_value(key: String, fallback: Variant = null) -> Variant:
		return values.get(key, fallback)

	func set_value(key: String, v: Variant) -> bool:
		values[key] = v
		return true
