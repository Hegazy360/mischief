## StageDoor — the debug-build dev menu (s2-night §4.1, ruling L8; Router key `stage_door`, debug only).
## Big buttons (≥ 144 px tall, 24 px gaps), every label from `stage_door.*` keys:
## * **Gate 0: the Sneeze** — the 3-icon card (Gate0Card, 2.5 s or a tap), then `g0_sneeze`; *Prologue* — P00;
## * **R3D (brief r3d-night §4.3):** only when `r3d-cast-hush` shipped the `head_b` variant
##   (`data/rigs3d/hush/rig3d_head_b.json`): **Gate 0 · Hush, B's head** (Settings `hush_head` = "") and
##   **Gate 0 · Hush, head ×<scale>** (`hush_head` = "head_b"; the scale read from that file) — never "head A / B";
##   **Night 1 (preview)** / **Night 2 (preview)** are hidden unless boot_config.json `show_previews` (the debug
##   setting's default) or Settings `show_previews` is on, and then open behind a "Work in progress" card first;
##   the Hush / Pip toggle is gone from the 3D menu (Pip falls back to Hush, ruling R7);
## * *Cast* — `cast.tscn`: Hush and Bellows in 3D on the lane at the base framing (Next / Turn);
## * *Voice A/B*, *Crowd A/B* — the pairs of `data/audio/ab.json` (Play A / Play B through
##   `Audio.preview(id, style)`, "Use this" → Settings `voice_style` / `crowd_style`);
## * **Gate 0 · voice A / B**, **Gate 0 · crowd A / B** — set the style and launch `g0_sneeze`, so the
##   owner judges the voices in the scene, not as isolated lines;
## * *Hush / Pip* (Settings `hush_skin`), *Reset save* (tap twice), *Device log* (the log + Copy).
## Reached from `boot_config.json` (`start: stage_door`) or the debug overlay.
class_name StageDoor
extends Control

const SCENE := "res://scenes/stage_door/StageDoor.tscn"
const CAST_SCENE := "res://scenes/stage_door/cast.tscn"
const AB_PATH := "res://data/audio/ab.json"
const BTN_H := 144.0
const GAP := 24.0
const COLS := 3
const G0 := "g0_sneeze"
const HEAD_B_RIG := "res://data/rigs3d/hush/rig3d_head_b.json"
## Main menu (2D view): [id, string key].
const MENU := [
	["gate0", "stage_door.gate0"], ["g0_voice_a", "stage_door.play_g0_voice_a"], ["g0_voice_b", "stage_door.play_g0_voice_b"],
	["cast", "stage_door.cast"], ["g0_crowd_a", "stage_door.play_g0_crowd_a"], ["g0_crowd_b", "stage_door.play_g0_crowd_b"],
	["prologue", "stage_door.prologue"], ["night1", "stage_door.night1"], ["night2", "stage_door.night2"],
	["voice_ab", "stage_door.voice_ab"], ["crowd_ab", "stage_door.crowd_ab"], ["hush_pip", "stage_door.hush_pip"],
	["device_log", "stage_door.device_log"], ["reset_save", "stage_door.reset_save"]]
## Main menu (3D view, R3D): the head buttons and the N1/N2 previews are added by `menu3d()` when they apply.
const MENU3D := [
	["gate0", "stage_door.gate0"], ["prologue", "stage_door.prologue"], ["cast", "stage_door.cast"],
	["g0_voice_a", "stage_door.play_g0_voice_a"], ["g0_voice_b", "stage_door.play_g0_voice_b"],
	["g0_crowd_a", "stage_door.play_g0_crowd_a"], ["g0_crowd_b", "stage_door.play_g0_crowd_b"],
	["voice_ab", "stage_door.voice_ab"], ["crowd_ab", "stage_door.crowd_ab"],
	["device_log", "stage_door.device_log"], ["reset_save", "stage_door.reset_save"]]
## Labels of keys `r3d-hud` has not added to strings.json yet (debug-only screen; UiStrings wins once they land).
const FALLBACK_TEXT := {
	"stage_door.g0_head_b": "Gate 0 · Hush, B's head",
	"stage_door.g0_head_scaled": "Gate 0 · Hush, head ×{s}",
	"stage_door.night1_preview": "Night 1 (preview)",
	"stage_door.night2_preview": "Night 2 (preview)",
	"stage_door.wip_title": "Work in progress",
	"stage_door.wip_text": "Work in progress: Bellows' reactions in these Nights are not animated yet",
	"stage_door.wip_play": "Play anyway",
	"stage_door.cast_turn": "Turn",
}
const EPISODES := {"prologue": "p00_curtain_up", "night1": "n01_throat_tea", "night2": "n02_something_fishy",
	"night1_preview": "n01_throat_tea", "night2_preview": "n02_something_fishy"}
## Style values per A/B side.
const STYLES := {"voice": ["formant", "tuba"], "crowd": ["formant", "fallback"]}

## Emitted for every launch (tests): {episode, from, …} or the page id.
signal launched(what: String, params: Dictionary)

var page: String = "main"
var buttons: Dictionary = {}          ## id → UiButton (the current page)
var ab: Dictionary = {}
## Test hook: record launches instead of changing scene.
var dry_run: bool = false
var _reset_armed: bool = false
var _content: Control = null
var _title: String = ""
var _log_text: String = ""
var _card: Gate0Card = null
## "3d" (the R3D menu) | "2d" (boot_config.json `view`).
var view: String = "3d"
## The WIP card over the menu (null when closed) and the episode it guards.
var wip_card: Control = null
var _wip_episode: String = ""


func _init() -> void:
	name = "StageDoor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()


func _ready() -> void:
	view = BootConfig.view()
	ab = _read_ab()
	_title = UiStrings.t("stage_door.title")
	var first := "main"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			first = a.substr(7)   # shots: voice_ab | crowd_ab | device_log
	show_page(first)
	resized.connect(func() -> void: show_page(page))


## Android back: a sub page → the menu; the menu → nothing (never quits).
func handle_back() -> bool:
	if _card != null:
		return true
	if wip_card != null:
		close_wip()
		return true
	if page != "main":
		show_page("main")
	return true


static func _read_ab() -> Dictionary:
	var v: Variant = ViewKit.json(AB_PATH)
	return v if v is Dictionary else {}


## The view rect minus the safe-area insets.
func safe_rect() -> Rect2:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	var ins := SafeArea.insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	return Rect2(ins.x, ins.y, vs.x - ins.x - ins.z, vs.y - ins.y - ins.w)


## Rebuild the page `p` (main | voice_ab | crowd_ab | device_log).
func show_page(p: String) -> void:
	page = p
	_reset_armed = false
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.name = "Page_" + p
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	buttons.clear()
	match p:
		"voice_ab":
			_build_ab("voice")
		"crowd_ab":
			_build_ab("crowd")
		"device_log":
			_build_log()
		_:
			_build_main()
	queue_redraw()


## Grid cell `i` (COLS columns) inside `r`, rows of BTN_H with GAP.
static func cell(r: Rect2, i: int, cols: int = COLS, top: float = 150.0) -> Rect2:
	var w := (r.size.x - 96.0 - GAP * float(cols - 1)) / float(cols)
	var col := i % cols
	var row := i / cols
	return Rect2(r.position.x + 48.0 + float(col) * (w + GAP), r.position.y + top + float(row) * (BTN_H + GAP), w, BTN_H)


func _add_button(id: String, text: String, rect: Rect2, fill: Color = UiKit.CREAM, shade: Color = UiKit.CREAM_SHADE) -> UiButton:
	var b := UiButton.make(text, rect.size, fill, shade)
	b.name = "Btn_" + id
	b.position = rect.position
	b.font_size = UiKit.SIZE_PLAY
	b.pressed.connect(_on_press.bind(id))
	_content.add_child(b)
	buttons[id] = b
	return b


func _build_main() -> void:
	var r := safe_rect()
	var i := 0
	var items: Array = MENU if view == "2d" else menu3d(head_b_scale(), previews_on())
	var cols := COLS if items.size() <= 15 else 4
	for m in items:
		var id := String(m[0])
		var text := label(String(m[1]), m[2] if (m as Array).size() > 2 else {})
		if id == "hush_pip":
			text = "%s: %s" % [text, "Pip" if _skin() == "pip" else "Hush"]
		var gold := id == "gate0" or id.begins_with("g0_")
		_add_button(id, text, cell(r, i, cols), UiKit.GOLD if gold else UiKit.CREAM, UiKit.GOLD_SHADE if gold else UiKit.CREAM_SHADE)
		i += 1


## The 3D menu (pure): MENU3D + the two head buttons right after Gate 0 when `head_scale` > 0 (the `head_b` variant
## exists), + the N1/N2 previews when `previews`. Rows are [id, string key] or [id, key, args].
static func menu3d(head_scale: float, previews: bool) -> Array:
	var out: Array = []
	for m in MENU3D:
		out.append(m)
		if String(m[0]) == "cast" and head_scale > 0.0:
			out.append(["g0_head_b", "stage_door.g0_head_b"])
			out.append(["g0_head_scaled", "stage_door.g0_head_scaled", {"s": head_label(head_scale)}])
	if previews:
		out.insert(3, ["night1_preview", "stage_door.night1_preview"])
		out.insert(4, ["night2_preview", "stage_door.night2_preview"])
	return out


## "1.2" for 1.2, "1.25" for 1.25 (the label's scale).
static func head_label(scale: float) -> String:
	var t := "%.2f" % scale
	while t.ends_with("0"):
		t = t.substr(0, t.length() - 1)
	return t.trim_suffix(".")


## The `head_b` variant's head scale (0 when `r3d-cast-hush` has not shipped it).
static func head_b_scale(path: String = HEAD_B_RIG) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return 0.0
	return float((j.data as Dictionary).get("head_scale", 0.0))


## The N1/N2 previews show: Settings `show_previews` (its default is boot_config.json's `show_previews`).
static func previews_on() -> bool:
	return bool(ViewKit.setting("show_previews", bool(BootConfig.read().get("show_previews", false))))


## A label: UiStrings when the key exists, else FALLBACK_TEXT (debug-only screen), formatted with `args`.
static func label(key: String, args: Variant = {}) -> String:
	var a: Dictionary = args if args is Dictionary else {}
	if UiStrings.has(key):
		return UiStrings.t(key, a)
	var t := String(FALLBACK_TEXT.get(key, key))
	for k in a:
		t = t.replace("{%s}" % k, String(a[k]))
	return t


func _build_ab(kind: String) -> void:
	var r := safe_rect()
	var pairs: Array = ab.get(kind, [])
	var cur := String(ViewKit.setting("%s_style" % kind, STYLES[kind][0]))
	var y := r.position.y + 150.0
	var lw := r.size.x * 0.42
	var bw := (r.size.x - 96.0 - lw - GAP * 2.0) * 0.5
	var row_h := minf(BTN_H, (r.size.y - 150.0 - BTN_H - GAP * 2.0 - 40.0) / float(maxi(1, pairs.size())) - GAP * 0.5)
	row_h = maxf(row_h, 96.0)
	var idx := 0
	for pr in pairs:
		if not (pr is Dictionary):
			continue
		var d: Dictionary = pr
		var lab := String(d.get("label", d.get("id", "")))
		if d.get("label_key") != null and UiStrings.has(String(d["label_key"])):
			lab = UiStrings.t(String(d["label_key"]))
		var l := Label.new()
		l.text = lab
		l.position = Vector2(r.position.x + 48.0, y)
		l.size = Vector2(lw, row_h)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", UiKit.ui_font())
		l.add_theme_font_size_override("font_size", UiKit.SIZE_MIN)
		l.add_theme_color_override("font_color", UiKit.CREAM)
		_content.add_child(l)
		var x := r.position.x + 48.0 + lw + GAP
		_add_button("play_a:%d" % idx, UiStrings.t("stage_door.play_a"), Rect2(x, y, bw, row_h))
		_add_button("play_b:%d" % idx, UiStrings.t("stage_door.play_b"), Rect2(x + bw + GAP, y, bw, row_h))
		y += row_h + GAP * 0.5
		idx += 1
	var by := r.end.y - BTN_H - 32.0
	var w := (r.size.x - 96.0 - GAP * 2.0) / 3.0
	var use := UiStrings.t("stage_door.use_this")
	var a_on := cur == String(STYLES[kind][0])
	_add_button("use_a", "%s: A%s" % [use, " ✓" if a_on else ""], Rect2(r.position.x + 48.0, by, w, BTN_H),
		UiKit.GOLD if a_on else UiKit.CREAM, UiKit.GOLD_SHADE if a_on else UiKit.CREAM_SHADE)
	_add_button("use_b", "%s: B%s" % [use, " ✓" if not a_on else ""], Rect2(r.position.x + 48.0 + w + GAP, by, w, BTN_H),
		UiKit.GOLD if not a_on else UiKit.CREAM, UiKit.GOLD_SHADE if not a_on else UiKit.CREAM_SHADE)
	_add_button("back", UiStrings.t("stage_door.back"), Rect2(r.position.x + 48.0 + (w + GAP) * 2.0, by, w, BTN_H))


func _build_log() -> void:
	var r := safe_rect()
	_log_text = DeviceLog.to_text()
	if FileAccess.file_exists(DeviceLog.PATH):
		_log_text = FileAccess.get_file_as_string(DeviceLog.PATH)
	var t := RichTextLabel.new()
	t.name = "LogText"
	t.position = Vector2(r.position.x + 48.0, r.position.y + 150.0)
	t.size = Vector2(r.size.x - 96.0, r.size.y - 150.0 - BTN_H - 64.0)
	t.bbcode_enabled = false
	t.text = _log_text.substr(0, 20000)
	t.add_theme_font_size_override("normal_font_size", 26)
	t.add_theme_color_override("default_color", UiKit.CREAM)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(t)
	var by := r.end.y - BTN_H - 32.0
	var w := (r.size.x - 96.0 - GAP) * 0.5
	_add_button("copy_log", UiStrings.t("overlay.copy_log"), Rect2(r.position.x + 48.0, by, w, BTN_H), UiKit.GOLD, UiKit.GOLD_SHADE)
	_add_button("back", UiStrings.t("stage_door.back"), Rect2(r.position.x + 48.0 + w + GAP, by, w, BTN_H))


func _skin() -> String:
	return String(ViewKit.setting("hush_skin", ""))


func _set_setting(key: String, v: Variant) -> void:
	var s := ViewKit.autoload("Settings")
	if s != null and s.has_method("set_value"):
		s.call("set_value", key, v)


## A button by id (also the tests' entry point).
func press(id: String) -> void:
	_on_press(id)


func _on_press(id: String) -> void:
	if wip_card != null and id != "wip_play" and id != "wip_back":
		return
	if id == "night1_preview" or id == "night2_preview":
		open_wip(String(EPISODES[id]))
		return
	if EPISODES.has(id):
		launch(String(EPISODES[id]))
		return
	match id:
		"g0_head_b", "g0_head_scaled":
			_set_setting("hush_head", "" if id == "g0_head_b" else "head_b")
			launch(G0, {"card": "g0"})
		"wip_play":
			var ep := _wip_episode
			close_wip()
			launch(ep)
		"wip_back":
			close_wip()
		"gate0":
			launch(G0, {"card": "g0"})
		"g0_voice_a", "g0_voice_b":
			_set_setting("voice_style", STYLES["voice"][0 if id.ends_with("_a") else 1])
			launch(G0, {"card": "g0"})
		"g0_crowd_a", "g0_crowd_b":
			_set_setting("crowd_style", STYLES["crowd"][0 if id.ends_with("_a") else 1])
			launch(G0, {"card": "g0"})
		"cast":
			launched.emit("cast", {})
			if not dry_run:
				get_tree().change_scene_to_file(CAST_SCENE)
		"hush_pip":
			_set_setting("hush_skin", "" if _skin() == "pip" else "pip")
			show_page("main")
		"voice_ab", "crowd_ab", "device_log":
			show_page(id)
		"reset_save":
			if not _reset_armed:
				_reset_armed = true
				var b: UiButton = buttons.get("reset_save")
				if b != null:
					b.text = UiStrings.t("stage_door.reset_confirm")
					b.fill = UiKit.CHERRY
					b.shade = UiKit.CHERRY_SHADE
					b.queue_redraw()
				return
			reset_save()
			show_page("main")
		"copy_log":
			DisplayServer.clipboard_set(_log_text)
			var b2: UiButton = buttons.get("copy_log")
			if b2 != null:
				b2.text = UiStrings.t("overlay.copied")
				b2.queue_redraw()
		"use_a", "use_b":
			var kind := "voice" if page == "voice_ab" else "crowd"
			_set_setting("%s_style" % kind, STYLES[kind][0 if id == "use_a" else 1])
			show_page(page)
		"back":
			show_page("main")
		_:
			if id.begins_with("play_a:") or id.begins_with("play_b:"):
				_play_pair(id)


func _play_pair(id: String) -> void:
	var kind := "voice" if page == "voice_ab" else "crowd"
	var idx := int(id.get_slice(":", 1))
	var pairs: Array = ab.get(kind, [])
	if idx < 0 or idx >= pairs.size():
		return
	var side: Variant = (pairs[idx] as Dictionary).get("a" if id.begins_with("play_a") else "b", null)
	if not (side is Dictionary):
		return
	var au := ViewKit.autoload("Audio")
	if au != null and au.has_method("preview"):
		au.call("preview", String((side as Dictionary).get("id", "")), String((side as Dictionary).get("style", "")))
	launched.emit("preview", side)


## The "Work in progress" card in front of a Night 1 / Night 2 preview (Play anyway / Back).
func open_wip(episode: String) -> void:
	close_wip()
	_wip_episode = episode
	var c := _WipCard.new()
	c.name = "WipCard"
	c.text = label("stage_door.wip_text")
	c.title = label("stage_door.wip_title")
	add_child(c)
	c.position = Vector2.ZERO
	c.size = size if size.x > 0.0 else Vector2(1920, 1080)
	var r := safe_rect()
	var w := minf(1100.0, r.size.x - 96.0)
	var bw := (w - GAP) * 0.5
	var by := r.get_center().y + 120.0
	var x0 := r.get_center().x - w * 0.5
	for spec in [["wip_play", label("stage_door.wip_play"), UiKit.GOLD, UiKit.GOLD_SHADE, x0],
			["wip_back", UiStrings.t("stage_door.back"), UiKit.CREAM, UiKit.CREAM_SHADE, x0 + bw + GAP]]:
		var b := UiButton.make(String(spec[1]), Vector2(bw, BTN_H), spec[2], spec[3])
		b.name = "Btn_" + String(spec[0])
		b.position = Vector2(float(spec[4]), by)
		b.font_size = UiKit.SIZE_PLAY
		b.pressed.connect(_on_press.bind(String(spec[0])))
		c.add_child(b)
		buttons[String(spec[0])] = b
	wip_card = c
	launched.emit("wip", {"episode": episode})


func close_wip() -> void:
	if wip_card != null and is_instance_valid(wip_card):
		wip_card.queue_free()
	wip_card = null
	buttons.erase("wip_play")
	buttons.erase("wip_back")


## The WIP card: a scrim + a cream card with the warning (the buttons are its children).
class _WipCard:
	extends Control
	var text: String = ""
	var title: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiKit.NAVY, 0.72))
		var w := minf(1180.0, size.x - 96.0)
		var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - 260.0, w, 560.0)
		UiKit.draw_chunky_rect(self, r, 36.0, UiKit.CREAM, UiKit.NAVY, 8.0, 12.0)
		UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(r.get_center().x, r.position.y + 90.0), title,
			UiKit.SIZE_TITLE, UiKit.CHERRY, 10)
		draw_multiline_string(UiKit.ui_font(), Vector2(r.position.x + 60.0, r.position.y + 190.0), text, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x - 120.0, UiKit.SIZE_PLAY, 3, UiKit.NAVY)


## Wipe the save (progress, seen keys) — Settings stay.
func reset_save() -> void:
	var sv := ViewKit.autoload("Save")
	if sv != null and sv.has_method("reset"):
		sv.call("reset")
		if sv.has_method("flush"):
			sv.call("flush")
	launched.emit("reset_save", {})


## Launch a Night from the stage door (`from: stage_door`). For Gate 0 `card: g0` makes the NightScene
## show the 3-icon card on its curtain while the Night warms up underneath.
func launch(episode: String, extra: Dictionary = {}) -> void:
	var p := {"episode": episode, "from": "stage_door"}
	p.merge(extra, true)
	launched.emit("night", p)
	if dry_run:
		return
	var r := ViewKit.autoload("Router")
	if r != null and r.has_method("goto"):
		r.call("goto", "night", p)
	else:
		var ps := load(NightScene.SCENE) as PackedScene
		var n := ps.instantiate()
		if n.has_method("setup"):
			n.call("setup", p)
		var tree := get_tree()
		var old := tree.current_scene
		tree.root.add_child(n)
		tree.current_scene = n
		if old != null:
			old.queue_free()


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	draw_rect(Rect2(Vector2.ZERO, vs), UiKit.PLUM)
	var fold := vs.x / 16.0
	for i in 16:
		draw_rect(Rect2(float(i) * fold + fold * 0.62, 0, fold * 0.38, vs.y), Color(UiKit.NAVY, 0.25))
	var r := safe_rect()
	var t := _title
	match page:
		"voice_ab":
			t = UiStrings.t("stage_door.voice_ab")
		"crowd_ab":
			t = UiStrings.t("stage_door.crowd_ab")
		"device_log":
			t = UiStrings.t("stage_door.device_log")
	UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(vs.x * 0.5, r.position.y + 76.0), t, UiKit.SIZE_TITLE,
		UiKit.GOLD_LIGHT, 16)
