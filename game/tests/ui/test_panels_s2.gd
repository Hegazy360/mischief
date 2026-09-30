## Stage-2 panels and the Figgis chip (s2-ui §4.2.3, §4.2.6, §4.2.7; R3D index R7): the chip on its
## SVG level only (no 2D rig class named, one SVG per mood, the 320 × 200 card), the
## SettingsPanel's debug-only Gate-0 tab, the LoadingCard taking a live Texture2D (s2-ftue's rule
## vignette) and the PauseMenu's Take a Bow only with a ★.
extends TestBase

var _made: Array = []


func after_each() -> void:
	for p in _made:
		if is_instance_valid(p):
			(p as Node).free()
	_made.clear()
	UiKit.now_override = -1


func _add(p: Node) -> Node:
	tree.root.add_child(p)
	_made.append(p)
	if p is Control:
		(p as Control).size = Vector2(2400, 1080)
	return p


# --- the Figgis chip (R3D: its SVG level only, index R7) -------------------------------------------

## The 2D rig runtime classes the chip must never name (r3d-integrate deletes them, index §5.4).
const RIG_CLASSES: PackedStringArray = ["RigPlayer", "ClipLib", "AtlasBuilder", "AtlasSet", "RigDef", "PropSim"]


func _chip() -> FiggisChip:
	var c := FiggisChip.new()
	tree.root.add_child(c)
	_made.append(c)
	return c


func test_chip_source_names_no_2d_rig_class() -> void:
	var src := FileAccess.get_file_as_string("res://ui/widgets/figgis_chip.gd")
	assert_gt(src.length(), 100)
	for cls in RIG_CLASSES:
		assert_eq(src.find(cls), -1, "figgis_chip.gd must not reference %s" % cls)


func test_chip_is_always_the_svg_level() -> void:
	assert_eq(FiggisChip.level_for(true, true), FiggisChip.Level.SVG, "no rig level any more")
	var c := _chip()
	assert_eq(c.level, FiggisChip.Level.SVG)
	assert_eq(c.mood_source, "svg:idle")
	assert_eq(c.get_child_count(), 0, "no RigPlayer child: the chip instantiates with only its SVGs")


func test_every_mood_has_its_svg() -> void:
	for m in FiggisChip.MOODS:
		var p := FiggisChip.art_path(m)
		assert_true(FileAccess.file_exists(p), "missing %s" % p)
		var src := FileAccess.get_file_as_string(p)
		assert_true(src.contains("#1B2340"), "%s: navy ink outline" % p)
		assert_not_null_tex(UiIcons.texture(p), p)


func assert_not_null_tex(t: Texture2D, what: String) -> void:
	assert_true(t != null and t.get_width() > 0, "%s rasterises" % what)


func test_moods_swap_svgs_with_a_short_bob() -> void:
	UiKit.now_override = 50000
	var c := _chip()
	c.set_pulse(true)
	assert_eq(c.mood, "psst")
	assert_eq(c.mood_source, "svg:psst")
	assert_true(c.is_processing(), "the 0.15 s swap bob runs")
	c.react("shh", 1.0)
	assert_eq(c.mood_source, "svg:shh")
	UiKit.now_override = 50000 + 1200
	c._refresh_state()
	assert_eq(c.mood, "psst", "back to the state's mood after the one-shot")


func test_card_opens_to_the_right_with_item_to_target() -> void:
	UiKit.now_override = 50000
	var c := _chip()
	c.show_card(PackedStringArray(["rig", "arrow", "tea"]), 4.0)
	assert_eq(c.state, FiggisChip.State.CARD)
	assert_eq(c.mood, "point")
	assert_eq(c.card_icon_count(), 2, "cue icons: item → target (the arrow is drawn, not an icon)")
	var r := c.card_rect()
	assert_eq(r.size, Vector2(320, 200), "REDESIGN §2.2: card 320 × 200")
	assert_ge(r.position.x, FiggisChip.HIT, "to the bust's right")
	c.flip = true
	assert_le(c.card_rect().end.x, 0.0, "left-handed: to its left")
	UiKit.now_override = 50000 + 4100
	c._refresh_state()
	assert_eq(c.state, FiggisChip.State.IDLE, "the card goes after 4 s")


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
