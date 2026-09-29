## SettingsPanel — every GDD §3.11 setting on three tabs, with ≥ 144 px hit rows and 24 px dead
## space between targets:
##   Play     Relaxed mode · Tap to rig · Left-handed · Hotspot hints (Always / Long-press / Off) ·
##            Stare strip
##   Sound    Audience · Voices · Music · Sound effects (sliders) · Vibration
##   Comfort  Reduce motion · Reduce flashing · Bigger text (+20 %)
##   Debug    (debug builds only — `show_debug`, default `OS.is_debug_build()`): the three Gate-0
##            A/B keys — Bellows' voice (Baritone / Tuba = voice_style formant / tuba), Audience
##            (Voices / Kazoo = crowd_style formant / fallback) and Hush (Mime / Pip = hush_skin
##            "" / "pip"). The release build has no such tab.
## "Hotspot hints" is the view's hotspot outlines only (ruling L16); Figgis's ladder has no setting.
## Reads and writes the Settings autoload (or `settings_node` when injected; a local copy of the
## defaults when neither exists, e.g. in the UiDemo). Every change is live (Settings emits
## `changed`; the Hud re-lays out for left-handed, etc.). `closed("done")`; Back = done.
class_name SettingsPanel
extends UiPanel

const ROW_H := 144.0
const GAP := 24.0
const HEADER_H := 144.0
const MAX_W := 1560.0
const SETTINGS_SCRIPT := "res://autoload/settings.gd"
const TABS := {
	"play": [["relaxed", "toggle"], ["tap_to_rig", "toggle"], ["left_handed", "toggle"], ["hints", "choice"],
		["stare_strip", "toggle"]],
	"sound": [["crowd_vol", "slider"], ["voice_vol", "slider"], ["music_vol", "slider"], ["sfx_vol", "slider"],
		["haptics", "toggle"]],
	"comfort": [["reduce_motion", "toggle"], ["reduce_flash", "toggle"], ["text_scale", "text_toggle"]],
	"debug": [["voice_style", "choice"], ["crowd_style", "choice"], ["hush_skin", "choice"]],
}
const TAB_ORDER: PackedStringArray = ["play", "sound", "comfort"]
const DEBUG_TAB := "debug"
const HINT_CHOICES: PackedStringArray = ["always", "long_press", "off"]
## Values of every choice row, in segment order (Settings.CHOICES holds the same sets).
const CHOICES := {
	"hints": ["always", "long_press", "off"],
	"voice_style": ["formant", "tuba"],
	"crowd_style": ["formant", "fallback"],
	"hush_skin": ["", "pip"],
}
## String key of each choice segment's label.
const CHOICE_LABELS := {
	"hints": ["settings.hints_always", "settings.hints_long_press", "settings.hints_off"],
	"voice_style": ["settings.voice_formant", "settings.voice_tuba"],
	"crowd_style": ["settings.crowd_formant", "settings.crowd_fallback"],
	"hush_skin": ["settings.skin_mime", "settings.skin_pip"],
}
const TAB_W := 250.0
const TAB_W_MIN := 200.0

## The Settings node to edit (defaults to /root/Settings).
var settings_node: Node = null
## Show the debug-only Gate-0 tab (set before the panel enters the tree; tests / the stage door).
var show_debug: bool = OS.is_debug_build()
var tab: String = "play"
var rows: Dictionary = {}          # key -> row widget
var tab_buttons: Dictionary = {}

var _local: Dictionary = {}
var _done: UiButton
var _title: String = ""
var _title_fits: bool = true
var _gear: Texture2D = null


func _build() -> void:
	back_action = "done"
	_title = UiStrings.t("settings.title")
	_gear = UiIcons.get_icon(&"gear")
	if settings_node == null:
		settings_node = get_node_or_null(^"/root/Settings")
	if settings_node == null:
		var s := load(SETTINGS_SCRIPT) as GDScript if ResourceLoader.exists(SETTINGS_SCRIPT) else null
		if s != null:
			_local = (s.get_script_constant_map().get("DEFAULTS", {}) as Dictionary).duplicate()
	for t in tab_order():
		var b := UiButton.make(UiStrings.t("settings.tab_" + t), Vector2(TAB_W, HEADER_H))
		b.hit_pad = Vector2(0, 24)
		b.font_size = 48
		b.pressed.connect(select_tab.bind(t))
		card.add_child(b)
		tab_buttons[t] = b
	_done = UiButton.make(UiStrings.t("settings.done"), Vector2(250, HEADER_H), UiKit.GOLD, UiKit.GOLD_SHADE)
	_done.hit_pad = Vector2(0, 24)
	_done.font_size = 48
	_done.pressed.connect(close.bind("done"))
	card.add_child(_done)
	select_tab(tab)


## The tabs shown, left to right ("debug" only when `show_debug`).
func tab_order() -> PackedStringArray:
	var o := TAB_ORDER.duplicate()
	if show_debug:
		o.append(DEBUG_TAB)
	return o


## The values a choice row cycles through (segment order).
static func choices_for(key: String) -> Array:
	return CHOICES.get(key, HINT_CHOICES) as Array


## Show tab `t` ("play", "sound", "comfort", "debug").
func select_tab(t: String) -> void:
	if t == DEBUG_TAB and not show_debug:
		t = "play"
	tab = t
	for r in rows.values():
		(r as Node).queue_free()
	rows.clear()
	for spec in TABS.get(t, []):
		var key := String(spec[0])
		var kind := String(spec[1])
		var row := _SettingRow.new()
		row.panel = self
		row.key = key
		row.kind = kind
		row.label = UiStrings.t("settings." + key)
		var dk := "settings.%s_desc" % key
		row.desc = UiStrings.t(dk) if UiStrings.has(dk) else ""
		row.name = "Row_" + key
		card.add_child(row)
		rows[key] = row
	for k in tab_buttons:
		var b: UiButton = tab_buttons[k]
		b.fill = UiKit.GOLD if k == t else UiKit.CREAM
		b.shade = UiKit.GOLD_SHADE if k == t else UiKit.CREAM_SHADE
		b.queue_redraw()
	if is_inside_tree():
		_relayout()


## Current value of a setting (never null: falls back to the defaults).
func value(key: String) -> Variant:
	var v: Variant = null
	if is_instance_valid(settings_node) and settings_node.has_method("get_value"):
		v = settings_node.call("get_value", key, _local.get(key))
	if v == null:
		v = _local.get(key, _default_for(key))
	return v


func _default_for(key: String) -> Variant:
	if CHOICES.has(key):
		return (CHOICES[key] as Array)[0]
	if key.ends_with("_vol") or key == "text_scale":
		return 1.0
	return false


## Write a setting (live).
func set_setting(key: String, v: Variant) -> void:
	if is_instance_valid(settings_node) and settings_node.has_method("set_value"):
		settings_node.call("set_value", key, v)
	else:
		_local[key] = v
	for r in rows.values():
		(r as Control).queue_redraw()


func _layout(rect: Rect2) -> void:
	var w := minf(MAX_W, rect.size.x - 64.0)
	var n := 5
	var h := HEADER_H + GAP + float(n) * ROW_H + float(n - 1) * GAP + 32.0
	h = minf(h, rect.size.y - 16.0)
	card.size = Vector2(w, h)
	card.position = rect.get_center() - card.size * 0.5
	var x := w - 32.0 - _done.size.x
	_done.position = Vector2(x, 8.0)
	x -= 24.0
	# tabs shrink (never below TAB_W_MIN) to leave the title room; if even that does not fit the
	# title gives way to a gear icon
	var order := tab_order()
	var nt := float(order.size())
	var title_w := UiKit.display_font().get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	var room := x - (44.0 + title_w + 32.0) - (nt - 1.0) * 24.0
	var tw := clampf(room / nt, TAB_W_MIN, TAB_W)
	_title_fits = room / nt >= TAB_W_MIN
	for i in range(order.size() - 1, -1, -1):
		var b: UiButton = tab_buttons[order[i]]
		b.custom_minimum_size = Vector2(tw, HEADER_H)
		b.size = Vector2(tw, HEADER_H)
		b.font_size = ScriptPanel.fit_size(UiKit.display_font(), b.text, tw - 36.0, 48)
		x -= tw
		b.position = Vector2(x, 8.0)
		x -= 24.0
	var y := HEADER_H + GAP
	for spec in TABS.get(tab, []):
		var row: Control = rows.get(String(spec[0]))
		if row == null:
			continue
		row.position = Vector2(32.0, y)
		row.size = Vector2(w - 64.0, ROW_H)
		y += ROW_H + GAP


func _draw_card(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	UiKit.draw_chunky_rect(ci, r, 40.0, UiKit.PAPER, UiKit.PAPER_SHADE, UiKit.BUTTON_OUTLINE, 14.0)
	UiKit.draw_chunky_rect(ci, Rect2(6, 6, r.size.x - 12, HEADER_H), 34.0, UiKit.CURTAIN, UiKit.CURTAIN_SHADE, 0.0, 8.0)
	ci.draw_rect(Rect2(6, HEADER_H - 28, r.size.x - 12, 30), UiKit.CURTAIN)
	ci.draw_rect(Rect2(6, HEADER_H + 2, r.size.x - 12, 6), UiKit.GOLD)
	if _title_fits:
		ci.draw_string(UiKit.display_font(), Vector2(44, HEADER_H * 0.5 + 24.0), _title, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 60, UiKit.CREAM)
	else:
		UiKit.draw_icon(ci, _gear, Rect2(36, HEADER_H * 0.5 - 44.0, 88, 88))


## One setting row: label (+ description) on the left, its control on the right. The whole row
## is the target for toggles; sliders track the finger on the right; choices are 3 segments.
class _SettingRow:
	extends TouchWidget

	const CTRL_W := 640.0
	const KNOB := 88.0

	var panel: SettingsPanel
	var key: String = ""
	var kind: String = "toggle"
	var label: String = ""
	var desc: String = ""
	var _press_seg: int = -1

	func _init() -> void:
		super()
		size = Vector2(1400, 144)

	func _n_seg() -> int:
		return SettingsPanel.choices_for(key).size()

	func _ctrl_rect() -> Rect2:
		match kind:
			"slider":
				return Rect2(size.x - CTRL_W - 16.0, 0, CTRL_W, size.y)
			"choice":
				var n := float(_n_seg())
				return Rect2(size.x - n * 220.0 - (n - 1.0) * 24.0 - 8.0, 0, n * 220.0 + (n - 1.0) * 24.0, size.y)
		return Rect2(size.x - 220.0, 0, 220.0, size.y)

	func _has_point(p: Vector2) -> bool:
		if kind == "slider" or kind == "choice":
			return _ctrl_rect().has_point(p)
		return Rect2(Vector2.ZERO, size).has_point(p)

	func _seg_at(p: Vector2) -> int:
		var cr := _ctrl_rect()
		for i in _n_seg():
			if Rect2(cr.position.x + float(i) * 244.0, 0, 220.0, size.y).has_point(p):
				return i
		return -1

	func _touch_down(p: Vector2) -> bool:
		UiKit.haptic(&"ui")
		if kind == "slider":
			_slide(p)
		elif kind == "choice":
			_press_seg = _seg_at(p)
			return _press_seg >= 0
		return true

	func _touch_move(p: Vector2) -> void:
		if kind == "slider":
			_slide(p)

	func _touch_up(p: Vector2, inside: bool) -> void:
		match kind:
			"toggle":
				if inside:
					panel.set_setting(key, not bool(panel.value(key)))
			"text_toggle":
				if inside:
					panel.set_setting(key, 1.0 if float(panel.value(key)) > 1.05 else 1.2)
			"choice":
				if _press_seg >= 0 and _seg_at(p) == _press_seg:
					panel.set_setting(key, SettingsPanel.choices_for(key)[_press_seg])
				_press_seg = -1
		queue_redraw()

	func _slide(p: Vector2) -> void:
		var cr := _ctrl_rect()
		var x0 := cr.position.x + KNOB * 0.5
		var x1 := cr.end.x - KNOB * 0.5
		var v := clampf((p.x - x0) / maxf(1.0, x1 - x0), 0.0, 1.0)
		panel.set_setting(key, snappedf(v, 0.05))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_chunky_rect(self, r.grow(-4.0), 28.0, Color(UiKit.PAPER_SHADE, 0.4), Color(UiKit.PAPER_SHADE, 0.4), 0.0, 0.0)
		var f := UiKit.ui_font()
		var ly := size.y * 0.5 + (0.0 if desc == "" else -10.0) + 16.0
		draw_string(f, Vector2(36, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.text_size(UiKit.SIZE_PLAY), UiKit.NAVY)
		if desc != "":
			draw_string(f, Vector2(36, ly + 44.0), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN, Color(UiKit.NAVY, 0.55))
		var cr := _ctrl_rect()
		match kind:
			"slider":
				var v := clampf(float(panel.value(key)), 0.0, 1.0)
				var ty := size.y * 0.5
				var x0 := cr.position.x + KNOB * 0.5
				var x1 := cr.end.x - KNOB * 0.5
				draw_line(Vector2(x0, ty), Vector2(x1, ty), UiKit.NAVY, 26.0, true)
				draw_line(Vector2(x0, ty), Vector2(x1, ty), Color("#4A3B5E"), 16.0, true)
				draw_line(Vector2(x0, ty), Vector2(lerpf(x0, x1, v), ty), UiKit.GOLD, 16.0, true)
				var kx := lerpf(x0, x1, v)
				var kk := UiKit.PRESS_SCALE if is_pressed else 1.0
				UiKit.draw_disc(self, Vector2(kx, ty), KNOB * 0.5 * kk, UiKit.CREAM, UiKit.CREAM_SHADE)
				var pct := "%d" % int(round(v * 100.0))
				UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(kx, ty), pct, UiKit.SIZE_MIN, UiKit.NAVY, 0)
			"choice":
				var cur := String(panel.value(key))
				var vals := SettingsPanel.choices_for(key)
				var labels: Array = SettingsPanel.CHOICE_LABELS.get(key, [])
				for i in vals.size():
					var sr := Rect2(cr.position.x + float(i) * 244.0, 24.0, 220.0, 96.0)
					var on := String(vals[i]) == cur
					var pressed := is_pressed and _press_seg == i
					var fill := UiKit.GOLD if on else UiKit.CREAM
					if pressed:
						fill = UiKit.pressed(fill)
					UiKit.draw_chunky_rect(self, sr, 26.0, fill, UiKit.GOLD_SHADE if on else UiKit.CREAM_SHADE, 5.0, 8.0)
					var t := UiStrings.t(String(labels[i])) if i < labels.size() else String(vals[i])
					UiKit.draw_text_centered(self, UiKit.display_font(), sr.get_center() + Vector2(0, -3), t, UiKit.SIZE_MIN,
						UiKit.NAVY, 0)
			_:
				var on := bool(panel.value(key)) if kind == "toggle" else float(panel.value(key)) > 1.05
				var pr := Rect2(cr.end.x - 200.0, size.y * 0.5 - 44.0, 176.0, 88.0)
				var kk := UiKit.PRESS_SCALE if is_pressed else 1.0
				var fill := UiKit.GREEN if on else Color("#B9B4C7")
				UiKit.draw_chunky_rect(self, pr, 44.0, fill, UiKit.GREEN_SHADE if on else Color("#8E89A3"), 6.0, 6.0)
				var kx := pr.end.x - 44.0 if on else pr.position.x + 44.0
				UiKit.draw_disc(self, Vector2(kx, pr.get_center().y - 2.0), 34.0 * kk, UiKit.CREAM, UiKit.CREAM_SHADE, 5.0)
				var t := UiStrings.t("settings.on" if on else "settings.off")
				draw_string(UiKit.display_font(), Vector2(pr.position.x - 110.0, size.y * 0.5 + 14.0), t,
					HORIZONTAL_ALIGNMENT_RIGHT, 96.0, UiKit.SIZE_MIN, UiKit.NAVY)
