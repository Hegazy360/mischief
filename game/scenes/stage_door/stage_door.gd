## StageDoor — the debug-build dev menu (s2-night §4.1, ruling L8; Router key `stage_door`, debug only).
## Big buttons (≥ 144 px tall, 24 px gaps), every label from `stage_door.*` keys:
## * *Prologue*, *Night 1*, *Night 2* — play that Night (`Router.goto("night", {episode, from})`);
## * **Gate 0: the Sneeze** — the 3-icon card (Gate0Card, 2.5 s or a tap), then `g0_sneeze`;
## * *Cast* — `cast.tscn`: live RigPlayers (Hush with a Hush/Pip toggle, Bellows, Figgis, the Stalls);
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
## Main menu: [id, string key].
const MENU := [
	["gate0", "stage_door.gate0"], ["g0_voice_a", "stage_door.play_g0_voice_a"], ["g0_voice_b", "stage_door.play_g0_voice_b"],
	["cast", "stage_door.cast"], ["g0_crowd_a", "stage_door.play_g0_crowd_a"], ["g0_crowd_b", "stage_door.play_g0_crowd_b"],
	["prologue", "stage_door.prologue"], ["night1", "stage_door.night1"], ["night2", "stage_door.night2"],
	["voice_ab", "stage_door.voice_ab"], ["crowd_ab", "stage_door.crowd_ab"], ["hush_pip", "stage_door.hush_pip"],
	["device_log", "stage_door.device_log"], ["reset_save", "stage_door.reset_save"]]
const EPISODES := {"prologue": "p00_curtain_up", "night1": "n01_throat_tea", "night2": "n02_something_fishy"}
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


func _init() -> void:
	name = "StageDoor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()


func _ready() -> void:
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
	for m in MENU:
		var id := String(m[0])
		var text := UiStrings.t(String(m[1]))
		if id == "hush_pip":
			text = "%s: %s" % [text, "Pip" if _skin() == "pip" else "Hush"]
		var gold := id == "gate0" or id.begins_with("g0_")
		_add_button(id, text, cell(r, i), UiKit.GOLD if gold else UiKit.CREAM, UiKit.GOLD_SHADE if gold else UiKit.CREAM_SHADE)
		i += 1


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
	if EPISODES.has(id):
		launch(String(EPISODES[id]))
		return
	match id:
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
