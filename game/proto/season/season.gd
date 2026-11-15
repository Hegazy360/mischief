## Season — the game's front end, as a prototype: a title screen (main menu) with PLAY / CONTINUE,
## SCENES (the Playbill wall), SETTINGS and QUIT; the Acts (proto/stage/show.gd, told not to loop) with
## a pause menu (⏸, Esc or Android back: Resume / Restart / Scenes / Main menu); each Act's Curtain Call
## with Retry / Next ▶ / Menu; after the last Act "To be continued…" and back to the Playbill.
## Progress (scenes seen) and settings are saved to user://season_save.json; a scene unlocks when the
## one before it has had its Curtain Call.
##
## Content (order, titles, taglines, teasers) is season.json.
## Dev args: --season=title | playbill | settings | act:<id> | paused:<id> | call:<id>   --season-unlock
## --season-fresh (ignore the save)   (and SKIP ▸▸ on screen during an Act jumps to its Curtain Call).
extends Control

const DATA := "res://proto/season/season.json"
const SAVE := "user://season_save.json"
const SHEETS := "res://proto/bakery/sheets/"
const STAGE := Vector2(2400, 1080)
const COL_INK := Color("#2A2036")
const COL_GOLD := Color("#FFC93C")
const COL_CREAM := Color("#FFF4E0")
const COL_PAPER := Color("#F6E7C8")
const COL_RED := Color("#B3263A")
const COL_DIM := Color(0.06, 0.03, 0.08, 0.62)

var _data: Dictionary = {}
var _acts: Array = []
var _seen: Dictionary = {}              # act id -> true once its Curtain Call has come up
var _state: String = "title"            # title | playbill | settings | act | paused | call | continued
var _settings: Dictionary = {"sound": true, "music": true}
var _reset_armed: bool = false          # "Reset progress" needs a second tap
var _cast: Dictionary = {}              # who -> {info, tex} for the title screen's idle loops
var _save_enabled: bool = true
var _cur: int = 0                       # index of the Act being shown / announced
var _st: float = 0.0                    # seconds in the current state
var _fade: float = 1.0                  # black cover, fades out on every state change
var _show: Control = null
var _call_at: float = -1.0              # state time at which the Curtain Call buttons appear
var _press: String = ""                 # button being held (drawn pressed)
var _buttons: Dictionary = {}           # name -> Rect2 in stage px (rebuilt every draw)
var _tex: Dictionary = {}
var _font_d: Font = null
var _font_b: Font = null
var _ui: Control = null


func _ready() -> void:
	Engine.max_fps = 60
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color("#120D18"))
	_font_d = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
	_font_b = load("res://ui/theme/fonts/Nunito-ExtraBold.ttf")
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_data = v if v is Dictionary else {}
	_acts = _data.get("acts", [])
	for key: String in ["backdrop", "frame"]:
		_tex[key] = load(str(_data.get(key, "")))
	for a: Dictionary in _acts:
		_tex[str(a["id"])] = load(str(a["art"]))
	# the overlay sits above whatever Act is playing
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_ui)
	_ui.draw.connect(_draw_ui)
	_ui.gui_input.connect(_on_input)
	var idx_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "index.json"))
	if idx_v is Dictionary:
		for who: String in ["hush", "gus"]:
			var info: Dictionary = ((idx_v["cast"] as Dictionary).get(who, {}) as Dictionary).get("clips", {}).get("idle", {})
			if not info.is_empty():
				_cast[who] = {"info": info, "tex": load(SHEETS + str(info["sheet"])),
					"faces": int(((idx_v["cast"] as Dictionary)[who] as Dictionary).get("faces", 1))}
	var start := "title"
	if "--season-fresh" in OS.get_cmdline_user_args():
		_save_enabled = false
	elif _save_enabled:
		# saving switched off (tests) means a fresh state too: never read the player's real save
		_load_save()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--season-unlock":
			for a: Dictionary in _acts:
				_seen[str(a["id"])] = true
		elif arg.begins_with("--season="):
			start = arg.substr(9)
	var parts := start.split(":")
	var idx := maxi(0, _index_of(parts[1])) if parts.size() > 1 else 0
	match parts[0]:
		"act":
			_play(idx)
		"call":
			_play(idx)
			_show.call("skip_to_card")
		"paused":
			_play(idx)
			_pause(true)
		"playbill", "settings":
			_go(parts[0])
		_:
			_go("title")


# --- save -------------------------------------------------------------------------------------------
func _load_save() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if v is Dictionary:
		for id: Variant in (v.get("seen", []) as Array):
			_seen[str(id)] = true
		var st: Dictionary = v.get("settings", {})
		for k: String in _settings:
			if st.has(k):
				_settings[k] = bool(st[k])


func _write_save() -> void:
	if not _save_enabled:
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"seen": _seen.keys(), "settings": _settings}, " "))


## The Act CONTINUE resumes at: the first not yet seen (or the last, when every Act has been seen).
func _next_unseen() -> int:
	for i in _acts.size():
		if not _seen.has(str(_acts[i]["id"])):
			return i
	return _acts.size() - 1


func _index_of(id: String) -> int:
	for i in _acts.size():
		if str(_acts[i]["id"]) == id:
			return i
	return -1


# --- the flow -------------------------------------------------------------------------------------
func _go(state: String) -> void:
	_state = state
	_st = 0.0
	_fade = 1.0
	_press = ""
	_reset_armed = false
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP


func _unlocked(i: int) -> bool:
	return i == 0 or _seen.has(str(_acts[i - 1]["id"]))


func _play(i: int) -> void:
	_clear_show()
	_cur = i
	var packed: PackedScene = load(str(_acts[i]["scene"]))
	_show = packed.instantiate()
	_show.set("loop", false)
	_show.connect("curtain_call", _on_curtain_call)
	add_child(_show)
	move_child(_show, 0)
	_call_at = -1.0
	_go("act")
	_fade = 0.0                       # the Act opens on its own closed curtain: no black needed


func _clear_show() -> void:
	if _show != null:
		_show.queue_free()
		_show = null


func _on_curtain_call() -> void:
	_seen[str(_acts[_cur]["id"])] = true
	_write_save()
	_call_at = _st + 1.2              # let the card land before the buttons arrive


func _process(delta: float) -> void:
	_st += delta
	_fade = maxf(0.0, _fade - delta * 3.0)
	match _state:
		"act":
			if _call_at >= 0.0 and _st >= _call_at:
				_state = "call"
				_st = 0.0
		"continued":
			if _st >= 2.6:
				_go("playbill")
	_ui.queue_redraw()


## Esc / Android back: pause a running Act, resume a paused one, step back out of a menu page.
func _unhandled_input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match _state:
		"act":
			_pause(true)
		"paused":
			_pause(false)
		"playbill", "settings":
			_go("title")
		"call", "continued":
			_to_title()


func _pause(on: bool) -> void:
	if _show == null:
		return
	_show.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	_state = "paused" if on else "act"
	_press = ""


func _to_title() -> void:
	_clear_show()
	_go("title")


func _on_input(ev: InputEvent) -> void:
	var down := (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or ev is InputEventScreenTouch
	if not down:
		return
	var pressed: bool = ev.pressed
	var at := _to_stage((ev as InputEventMouseButton).position if ev is InputEventMouseButton else (ev as InputEventScreenTouch).position)
	var hit := ""
	for name: String in _buttons:
		if (_buttons[name] as Rect2).has_point(at):
			hit = name
	if pressed:
		_press = hit
		# a tap anywhere skips "To be continued…"
		if hit == "" and _state == "continued":
			_go("playbill")
		elif hit == "" and _state == "act":
			# let the Act's own taps through (it has none yet, but the show must not feel frozen)
			pass
		return
	if hit != "" and hit == _press:
		_activate(hit)
	_press = ""


func _activate(name: String) -> void:
	if name.begins_with("poster:"):
		var i := int(name.substr(7))
		if _unlocked(i):
			_play(i)
		return
	match name:
		"play":
			_play(_next_unseen() if not _seen.is_empty() else 0)
		"scenes":
			_clear_show()
			_go("playbill")
		"settings":
			_go("settings")
		"quit":
			get_tree().quit()
		"back":
			_go("title")
		"menu":
			_to_title()
		"pause":
			_pause(true)
		"resume":
			_pause(false)
		"restart":
			_play(_cur)
		"sound", "music":
			_settings[name] = not bool(_settings[name])
			_write_save()
		"reset":
			if _reset_armed:
				_seen.clear()
				_write_save()
				_reset_armed = false
			else:
				_reset_armed = true
		"skip":
			if _show != null and _call_at < 0.0:
				_show.call("skip_to_card")
		"next":
			if _cur + 1 < _acts.size():
				_play(_cur + 1)
			else:
				_clear_show()
				_go("continued")
		"retry":
			_play(_cur)
		"playbill":
			_clear_show()
			_go("playbill")


# --- drawing ---------------------------------------------------------------------------------------------
func _u() -> float:
	return get_viewport_rect().size.y / STAGE.y


func _off() -> Vector2:
	return Vector2((get_viewport_rect().size.x - STAGE.x * _u()) * 0.5, 0.0)


func _to_stage(p: Vector2) -> Vector2:
	return (p - _off()) / _u()


func _draw_ui() -> void:
	_buttons.clear()
	_ui.draw_set_transform(_off(), 0.0, Vector2(_u(), _u()))
	match _state:
		"title":
			_draw_title()
		"settings":
			_draw_settings()
		"playbill":
			_draw_playbill()
			_button("back", Rect2(110, 90, 220, 76), "◀  BACK", false, 32)
		"act":
			_button("pause", Rect2(96, 140, 92, 92), "II", false, 40)
			if _call_at < 0.0:
				_button("skip", Rect2(2080, 150, 230, 64), "SKIP  ▸▸", false, 30)
		"paused":
			_draw_paused()
		"call":
			_draw_call()
		"continued":
			_draw_curtain_card("", "To be continued…", "More Acts coming soon.")
	if _fade > 0.0:
		_ui.draw_rect(Rect2(Vector2(-2000, -100), Vector2(STAGE.x + 4000, STAGE.y + 200)), Color(0.07, 0.04, 0.09, _fade))


func _draw_title() -> void:
	_backdrop(0.3)
	# the marquee: a dark sign, bulbs chasing round its edge, the logo
	var m := Rect2(560, 110, 1280, 290)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2A1730")
	sb.set_corner_radius_all(40)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(8)
	sb.draw(_ui.get_canvas_item(), m)
	var n := 44
	for i in n:
		var t := float(i) / float(n)
		var p := _perimeter(m.grow(-22), t)
		var lit := (i + int(_st * 8.0)) % 4 == 0
		_ui.draw_circle(p, 9.0, Color("#FFE7A8") if lit else Color("#8A6A3A"))
		if lit:
			_ui.draw_circle(p, 16.0, Color(1.0, 0.9, 0.6, 0.25))
	var bob := sin(_st * 2.0) * 4.0
	_text_c("MISCHIEF", Vector2(1200, 228 + bob), 112, COL_GOLD, COL_INK)
	_text_c("NEXT DOOR", Vector2(1200, 340 + bob), 112, COL_GOLD, COL_INK)
	_text_b("A slapstick farce in five Acts", Vector2(1200, 452), 34, COL_CREAM)
	# the cast on the apron, facing each other
	_draw_cast("hush", Vector2(560, 960), 1, 1.9)
	_draw_cast("gus", Vector2(1860, 960), -1, 1.75)
	# the menu
	var y := 520.0
	var fresh := _seen.is_empty()
	var label := "▶  PLAY" if fresh else "▶  CONTINUE"
	_button("play", Rect2(900, y, 600, 120), label, true, 54)
	if not fresh:
		var nx := _next_unseen()
		_text_b("%s · %s" % [_acts[nx]["number"], _acts[nx]["title"]], Vector2(1200, y + 152), 28, COL_CREAM)
	y += 190.0
	_button("scenes", Rect2(950, y, 500, 92), "SCENES", false, 40)
	y += 112.0
	_button("settings", Rect2(950, y, 500, 92), "SETTINGS", false, 40)
	if not OS.has_feature("mobile"):
		_button("quit", Rect2(2150, 940, 170, 70), "QUIT", false, 30)


func _perimeter(r: Rect2, t: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := t * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.end - Vector2(d, 0)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


func _draw_cast(who: String, foot: Vector2, dir: int, scale: float) -> void:
	var c: Dictionary = _cast.get(who, {})
	if c.is_empty() or c["tex"] == null:
		return
	var info: Dictionary = c["info"]
	var count := int(info.get("count", 1))
	var durs: Array = info.get("durations", [])
	var total := 0.0
	for d: Variant in durs:
		total += float(d)
	var tt := fmod(_st, maxf(total, 0.05))
	var fr := 0
	for k in count:
		tt -= float(durs[k]) if k < durs.size() else 0.1
		if tt < 0.0:
			fr = k
			break
	var fw := float(info["frame_w"])
	var fh := float(info["frame_h"])
	var cols := maxi(1, int(info.get("cols", count)))
	var anc: Array = info["anchor"]
	var flip := dir * int(c["faces"]) < 0
	_ui.draw_set_transform(_off() + foot * _u(), 0.0, Vector2((-1.0 if flip else 1.0) * scale, scale) * _u())
	_ui.draw_texture_rect_region(c["tex"], Rect2(Vector2(-float(anc[0]), -float(anc[1])), Vector2(fw, fh)),
		Rect2(Vector2(float(fr % cols) * fw, float(fr / cols) * fh), Vector2(fw, fh)))
	_ui.draw_set_transform(_off(), 0.0, Vector2(_u(), _u()))
	# a pool of footlight under each of them
	_ui.draw_set_transform(_off() + (foot + Vector2(0, 6)) * _u(), 0.0, Vector2(150, 26) * _u())
	_ui.draw_circle(Vector2.ZERO, 1.0, Color(1.0, 0.85, 0.5, 0.18))
	_ui.draw_set_transform(_off(), 0.0, Vector2(_u(), _u()))


func _draw_settings() -> void:
	_backdrop(0.45)
	_text_c("SETTINGS", Vector2(1200, 250), 86, COL_GOLD, COL_INK)
	var rows := [["sound", "Sound effects"], ["music", "Music"]]
	var y := 340.0
	for row: Array in rows:
		_text_b(str(row[1]), Vector2(1020, y + 64), 40, COL_CREAM)
		var on := bool(_settings[str(row[0])])
		_button(str(row[0]), Rect2(1280, y, 220, 92), "ON" if on else "OFF", on, 40)
		y += 130.0
	_button("reset", Rect2(900, y + 20, 600, 92), "TAP AGAIN TO RESET" if _reset_armed else "RESET PROGRESS", false, 36)
	_text_b("Progress: %d of %d scenes seen" % [_seen.size(), _acts.size()], Vector2(1200, y + 170), 30, Color(COL_CREAM, 0.8))
	_button("back", Rect2(110, 90, 220, 76), "◀  BACK", false, 32)


func _draw_paused() -> void:
	_ui.draw_rect(Rect2(Vector2(-2000, -100), Vector2(STAGE.x + 4000, STAGE.y + 200)), Color(0.05, 0.02, 0.07, 0.62))
	var box := Rect2(820, 170, 760, 760)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.12, 0.95)
	sb.set_corner_radius_all(40)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(6)
	sb.draw(_ui.get_canvas_item(), box)
	_text_c("PAUSED", Vector2(1200, 290), 80, COL_GOLD, COL_INK)
	_text_b("%s · %s" % [_acts[_cur]["number"], _acts[_cur]["title"]], Vector2(1200, 345), 30, COL_CREAM)
	var y := 390.0
	_button("resume", Rect2(930, y, 540, 112), "▶  RESUME", true, 48)
	for row: Array in [["restart", "RESTART SCENE"], ["scenes", "SCENES"], ["menu", "MAIN MENU"]]:
		y += 132.0
		_button(str(row[0]), Rect2(960, y, 480, 96), str(row[1]), false, 38)


func _backdrop(dim: float) -> void:
	var bd: Texture2D = _tex.get("backdrop")
	if bd != null:
		_ui.draw_texture_rect(bd, Rect2(Vector2.ZERO, STAGE), false)
	_ui.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.05, 0.02, 0.06, dim))
	var fr: Texture2D = _tex.get("frame")
	if fr != null:
		_ui.draw_texture_rect(fr, Rect2(Vector2.ZERO, STAGE), false)


func _draw_playbill() -> void:
	_backdrop(0.35)
	_text_c("MISCHIEF NEXT DOOR", Vector2(1200, 215), 76, COL_GOLD, COL_INK)
	_text_c("CHOOSE A SCENE", Vector2(1200, 272), 34, COL_CREAM, COL_INK)
	# posters are laid out at 500 x 640 and scaled to fit however many scenes there are
	var w := 500.0
	var h := 640.0
	var n := maxi(1, _acts.size())
	var gap := 70.0 if n <= 3 else 44.0
	var ps := minf(1.0, (2060.0 - gap * float(n - 1)) / (w * float(n)))
	var x0 := 1200.0 - (w * ps * float(n) + gap * float(n - 1)) * 0.5
	for i in _acts.size():
		var a: Dictionary = _acts[i]
		var r := Rect2(x0 + float(i) * (w * ps + gap), 320 + (h * (1.0 - ps)) * 0.35, w * ps, h * ps)
		var open := _unlocked(i)
		var lift := -10.0 if _press == "poster:%d" % i and open else 0.0
		r.position.y += lift
		_buttons["poster:%d" % i] = r
		# a little sway so the wall feels alive
		var tilt: float = 0.012 * sin(_st * 1.3 + float(i) * 2.0) + [-0.02, 0.01, -0.012][i % 3]
		var c := r.get_center()
		_ui.draw_set_transform(_off() + c * _u(), tilt, Vector2(_u(), _u()) * ps)
		var lr := Rect2(-Vector2(w, h) * 0.5, Vector2(w, h))
		_ui.draw_rect(Rect2(lr.position + Vector2(10, 14), lr.size), Color(0, 0, 0, 0.35))
		_ui.draw_rect(lr, COL_PAPER)
		_ui.draw_rect(lr.grow(-14), COL_RED, false, 6.0)
		_ui.draw_rect(lr.grow(-24), Color(COL_GOLD, 0.8), false, 2.0)
		var art: Texture2D = _tex.get(str(a["id"]))
		var pic := Rect2(lr.position + Vector2(40, 40), Vector2(w - 80, 270))
		if art != null:
			_ui.draw_texture_rect_region(art, pic, Rect2(560, 150, 1280, 864))
		_ui.draw_rect(pic, COL_INK, false, 4.0)
		var mid := lr.position.x + w * 0.5
		_text_at(str(a["number"]).to_upper(), Vector2(mid, pic.end.y + 62), 36, COL_RED)
		_text_at(str(a["title"]), Vector2(mid, pic.end.y + 120), 52, COL_INK)
		_text_b(str(a["tagline"]), Vector2(mid, pic.end.y + 168), 28, Color(COL_INK, 0.8))
		for k in 3:
			_star(Vector2(mid - 70.0 + 70.0 * float(k), pic.end.y + 222), 26.0, _seen.has(str(a["id"])))
		if not open:
			_ui.draw_rect(lr, Color(0.1, 0.06, 0.12, 0.6))
			_ui.draw_rect(pic, Color(0.1, 0.06, 0.12, 0.55))
			_text_c("LOCKED", pic.get_center() + Vector2(0, 8), 64, COL_CREAM, COL_INK)
			_text_b("Finish %s first" % _acts[i - 1]["number"], pic.get_center() + Vector2(0, 58), 28, COL_CREAM)
		else:
			var pr := Rect2(mid - 110.0, lr.end.y - 92.0, 220.0, 64.0)
			_pill(pr, COL_GOLD, "▶  PLAY", 32)
		_ui.draw_set_transform(_off(), 0.0, Vector2(_u(), _u()))


func _draw_curtain_card(kicker: String, title: String, line: String) -> void:
	_backdrop(0.15)
	var a := clampf(_st * 4.0, 0.0, 1.0)
	var drop := (1.0 - a) * -40.0
	if kicker != "":
		_text_c(kicker, Vector2(1200, 430 + drop), 46, Color(COL_CREAM, a), Color(COL_INK, a))
	_text_c(title, Vector2(1200, 545 + drop), 98, Color(COL_GOLD, a), Color(COL_INK, a))
	_text_b(line, Vector2(1200, 625 + drop), 40, Color(COL_CREAM, a))


func _draw_call() -> void:
	var a := clampf(_st * 4.0, 0.0, 1.0)
	var y := 800.0 + (1.0 - a) * 60.0
	var teaser := str(_acts[_cur].get("teaser", ""))
	if _cur + 1 >= _acts.size():
		teaser = "That's the last Act — for now."
	_ui.draw_rect(Rect2(560, y - 50, 1280, 250), Color(0.08, 0.05, 0.1, 0.78 * a))
	_text_b(teaser, Vector2(1200, y), 32, Color(COL_CREAM, a))
	_button("retry", Rect2(640, y + 40, 260, 100), "RETRY", false, 38)
	_button("next", Rect2(1040, y + 28, 320, 124), "NEXT  ▶", true, 48)
	_button("menu", Rect2(1500, y + 40, 260, 100), "MENU", false, 38)


func _button(name: String, r: Rect2, label: String, primary: bool, size: int) -> void:
	_buttons[name] = r
	var down := _press == name
	var rr := r.grow(-4.0) if down else r
	_pill(rr, COL_GOLD if primary else Color("#3A2A48"), label, size, Color.WHITE if not primary else COL_INK)


func _pill(r: Rect2, fill: Color, label: String, size: int, ink: Color = COL_INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.border_color = COL_INK
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 6)
	sb.draw(_ui.get_canvas_item(), r)
	_text_at(label, r.get_center() + Vector2(0, size * 0.36), size, ink)


func _star(c: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var ang := -PI / 2.0 + PI * float(i) / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	if on:
		_ui.draw_colored_polygon(pts, COL_GOLD)
	pts.append(pts[0])
	_ui.draw_polyline(pts, COL_INK, 3.0, true)


func _text_c(text: String, at: Vector2, size: int, col: Color, outline: Color) -> void:
	var w := _font_d.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5, 0)
	if outline.a > 0.0:
		_ui.draw_string_outline(_font_d, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 7), outline)
	_ui.draw_string(_font_d, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_at(text: String, at: Vector2, size: int, col: Color) -> void:
	var w := _font_d.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_ui.draw_string(_font_d, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_b(text: String, at: Vector2, size: int, col: Color) -> void:
	var w := _font_b.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_ui.draw_string(_font_b, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
