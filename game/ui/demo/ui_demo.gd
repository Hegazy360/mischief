## UiDemo — the whole HUD over a neutral stage backdrop, driven by a scripted fake HudModel, for
## screenshots and frame sequences (TECH §5.9, ui brief §3.7).
##
## User args (after `--`):
##   --state=<name>   one of STATES (default "rig_50")
##   --left-handed    mirror the clusters
##   --safe-area=L,T,R,B   fake notch insets (logical px; SafeArea reads it)
##   --cycle          step through every state (CYCLE_FRAMES apart) — pair with DevShot
##                    `--shot-seq=/abs/dir --every=<CYCLE_FRAMES> --count=<n>`
## The backdrop is a greybox parlour (or art-house's parlour art when it exists) with two
## stand-in characters, so the HUD is judged over a busy world.
extends Node

const STATES: PackedStringArray = [
	"rig_0", "rig_50", "rig_100", "rig_dim", "freeze", "pop_green", "pop_amber", "pop_red", "go", "ff",
	"lure_grey", "tray_highlight", "figgis_pulse", "figgis_card", "pip_steaming", "edge_bubble", "pick_strip",
	"script", "pause", "settings", "loading", "results", "encore",
]
const CYCLE_FRAMES := 40
const PANELS := {
	"script": "res://ui/panels/script_panel.gd",
	"pause": "res://ui/panels/pause_menu.gd",
	"settings": "res://ui/panels/settings_panel.gd",
	"loading": "res://ui/panels/loading_card.gd",
	"results": "res://ui/panels/results_screen.gd",
}

var hud: Hud
var model: HudModel
var state: String = "rig_50"
var _cycle: bool = false
var _frame: int = 0
var _cycle_i: int = 0
var _backdrop: Node2D
var _stalls: Control
var _pip_vp: SubViewport


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--state="):
			state = a.substr(8)
		elif a == "--cycle":
			_cycle = true
	_backdrop = _Backdrop.new()
	add_child(_backdrop)
	var stalls_layer := CanvasLayer.new()
	stalls_layer.layer = 9
	add_child(stalls_layer)
	_stalls = _StallsStandIn.new()
	stalls_layer.add_child(_stalls)
	_pip_vp = SubViewport.new()
	_pip_vp.size = Vector2i(448, 252)
	_pip_vp.transparent_bg = false
	_pip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pip_vp.add_child(_PipScene.new())
	add_child(_pip_vp)
	hud = Hud.new()
	add_child(hud)
	if UiKit.has_flag("--left-handed"):
		hud.set_left_handed(true)
	hud.set_pip_texture(_pip_vp.get_texture())
	model = HudModel.new()
	if _cycle:
		state = STATES[0]
	_enter(state)


func _process(_delta: float) -> void:
	_frame += 1
	(_stalls as _StallsStandIn).band = hud.layout.get(&"band", Rect2())
	_stalls.queue_redraw()
	if _cycle and _frame % CYCLE_FRAMES == 0:
		_cycle_i = (_cycle_i + 1) % STATES.size()
		_enter(STATES[_cycle_i])
	_animate()
	hud.apply(model)


## Configure the fake model (and panels) for `name`.
func _enter(name_: String) -> void:
	state = name_
	hud.close_panels()
	hud.ghost_finger(&"")
	hud.figgis.hide_card()
	if hud.action.is_pressed:
		hud.action.release_touch()
	if hud.clarence.is_pressed:
		hud.clarence.release_touch()
	var m := HudModel.new()
	m.applause = 64
	m.lines_done = 3
	m.lines_total = 5
	m.tomatoes_left = 2
	m.tomatoes_max = 3
	m.verb = HudModel.Verb.FREEZE
	m.tray = PackedStringArray(["squeaker", "kipper", "flour"])
	m.clarence_mode = HudModel.ClarenceMode.SQUEAK
	m.pip_glyph = "specs_off"
	m.script_lines = _fake_script()
	m.script_loop = _fake_loop()
	match name_:
		"rig_0", "rig_50", "rig_100":
			m.verb = HudModel.Verb.RIG
			m.verb_item_icon = "squeaker"
			m.verb_target_icon = "tea"
			m.tray_highlight = 0
			m.ring_frac = {"rig_0": 0.0, "rig_50": 0.5, "rig_100": 0.62}[name_]
		"rig_dim":
			m.verb = HudModel.Verb.RIG_DIM
			m.verb_item_icon = "butter"
		"freeze":
			m.verb = HudModel.Verb.FREEZE
		"pop_green", "pop_amber", "pop_red":
			m.verb = HudModel.Verb.POP_OUT
			m.clarence_mode = HudModel.ClarenceMode.FF
			m.rim = {"pop_green": HudModel.Rim.GREEN, "pop_amber": HudModel.Rim.AMBER, "pop_red": HudModel.Rim.RED}[name_]
			if name_ == "pop_red":
				m.pip_visible = true
				m.pip_frame_tier = 3
				m.pip_glyph = "specs_on"
		"go":
			m.verb = HudModel.Verb.GO
			m.rim = HudModel.Rim.AMBER
			m.clarence_mode = HudModel.ClarenceMode.FF
		"ff":
			m.verb = HudModel.Verb.POP_OUT
			m.rim = HudModel.Rim.GREEN
			m.clarence_mode = HudModel.ClarenceMode.FF
		"lure_grey":
			m.lure_grey = true
		"tray_highlight":
			m.verb = HudModel.Verb.RIG
			m.verb_item_icon = "kipper"
			m.verb_target_icon = "phone"
			m.tray_highlight = 1
		"figgis_pulse":
			m.figgis_pulse = true
		"figgis_card":
			m.figgis_pulse = false
		"pip_steaming":
			m.pip_visible = true
			m.pip_frame_tier = 2
			m.pip_glyph = "specs_on"
			m.link = 2
			m.mult_pct = 150
			m.fuse_frac = 0.62
			m.temper_tier = 2
			m.applause = 81
		"edge_bubble":
			m.edge_bubble_dir = Vector2(0, -1)
			m.edge_bubble_label = UiStrings.t("hud.edge_upstairs")
		"pick_strip":
			m.pick_strip_container = "kitchen_pantry_shelf"
			m.pick_strip_items = PackedStringArray(["flour", "sherbet", "treacle"])
			m.pick_strip_pos = Vector2(hud.viewport_size().x * 0.55, 560)
		"encore":
			m.applause = 118
			m.lines_done = 5
			m.link = 3
			m.mult_pct = 200
			m.fuse_frac = 0.35
		"script", "pause", "settings", "loading", "results":
			m.paused = name_ != "loading"
	model = m
	hud.apply(model)
	_after_enter(name_)


func _after_enter(name_: String) -> void:
	var c := hud.action.size * 0.5
	match name_:
		"rig_50", "rig_100":
			hud.action.touch(true, c, 7)
		"freeze":
			hud.action.touch(true, c, 7)
		"ff":
			hud.clarence.touch(true, hud.clarence.size * 0.5, 8)
		"figgis_card":
			hud.show_figgis_card(PackedStringArray(["clarence", "bellows"]), 60.0)
		"rig_0":
			hud.ghost_finger(&"action", GhostFinger.Mode.HOLD)
	if PANELS.has(name_):
		_open_panel(name_)


func _open_panel(name_: String) -> void:
	var path: String = PANELS[name_]
	if not ResourceLoader.exists(path):
		return
	var p: Control = (load(path) as GDScript).new()
	match name_:
		"script":
			p.call("setup", model.script_lines, model.script_loop, 3, 5)
		"pause":
			p.call("setup", true)
		"loading":
			p.call("setup", {"title": UiStrings.t("loading.night", {"n": 2}), "subtitle": "Something Fishy",
				"text": "Hold FREEZE to be a statue. Specs off, he only spots what moves. Specs on, get out of sight.",
				"icon": "freeze"})
		"results":
			p.call("setup", {"applause": 91, "stars": [true, true, false], "why": "Applause 91 — land one more prank inside a Running Gag",
				"new": ["ACHOO-RIA!", "KETTLE DRUM"], "has_next": true, "night_title": "Night 1 · Throat Tea"})
	hud.show_panel(p)


func _animate() -> void:
	var t := float(_frame) / 60.0
	if state == "rig_100":
		model.ring_frac = minf(1.0, 0.62 + t * 0.6)
	elif state == "pip_steaming":
		model.fuse_frac = maxf(0.0, 0.62 - t * 0.02)


func _fake_script() -> Array:
	return [
		{"id": "kettle", "text": "Bellows sings a duet with his kettle", "req": true, "done": true, "rigged": true,
			"discovered": true, "icon": "tea"},
		{"id": "sneeze", "text": "A sneeze worthy of the opera", "req": true, "done": true, "rigged": true,
			"discovered": true, "icon": "tea", "candle": true},
		{"id": "pickle", "text": "He gets himself in a pickle", "req": true, "done": false, "rigged": true,
			"discovered": true, "icon": "pickles"},
		{"id": "news", "text": "The news makes his eyes pop", "req": false, "done": true, "rigged": false,
			"discovered": true, "icon": "paper"},
		{"id": "tap", "text": "", "req": false, "done": false, "rigged": false, "discovered": false},
		{"id": "bn", "text": "HOT & COLD: sneeze him into the sink", "req": false, "done": false, "rigged": false,
			"discovered": true, "big_number": true, "sealed": true},
	]


func _fake_loop() -> Array:
	return [
		{"activity": "warmup", "rigged": false, "current": false},
		{"activity": "tea", "rigged": true, "current": true},
		{"activity": "pickles", "rigged": true, "current": false},
		{"activity": "paper", "rigged": false, "current": false},
		{"activity": "rinse", "rigged": false, "current": false},
	]


## A greybox parlour: wallpaper, dado, floorboards, a door, props and two stand-in characters.
class _Backdrop:
	extends Node2D

	var _art: Texture2D = null

	func _ready() -> void:
		for p in ["res://art/house/rooms/parlour_bg.svg", "res://art/house/rooms/kitchen_bg.svg"]:
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				_art = UiIcons.texture(p, 1.0)
				if _art != null:
					break

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var floor_y := vs.y * 0.86
		if _art != null:
			var ts := _art.get_size()
			var k := maxf(vs.y / ts.y, vs.x / ts.x)
			draw_texture_rect(_art, Rect2((vs - ts * k) * 0.5, ts * k), false)
		else:
			draw_rect(Rect2(Vector2.ZERO, vs), Color("#6E7F66"))
			var x := 0.0
			while x < vs.x:
				draw_rect(Rect2(x, 0, 38, floor_y), Color("#7C8E73"))
				x += 96.0
			draw_rect(Rect2(0, floor_y - 170, vs.x, 170), Color("#5B3A2E"))
			draw_rect(Rect2(0, floor_y - 180, vs.x, 14), Color("#8A5A3C"))
			draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("#8A5A3C"))
			draw_rect(Rect2(0, floor_y, vs.x, 10), Color("#4A2E22"))
			draw_rect(Rect2(vs.x * 0.08, floor_y - 520, 230, 520), Color("#4A2E22"))
			draw_rect(Rect2(vs.x * 0.08 + 18, floor_y - 500, 194, 500), Color("#6B4430"))
			draw_rect(Rect2(vs.x * 0.62, floor_y - 300, 360, 300), Color("#2B1E1A"))
			draw_rect(Rect2(vs.x * 0.62 + 20, floor_y - 340, 320, 50), Color("#3A2A22"))
			draw_circle(Vector2(vs.x * 0.4, floor_y - 560), 70, Color("#E8B33A"))
			draw_rect(Rect2(vs.x * 0.36, floor_y - 620, 140, 12), Color("#4A2E22"))
		# stand-ins: Hush (stripes, beret) and Bellows (plum barrel, silver bouffant)
		var hx := vs.x * 0.42
		draw_rect(Rect2(hx - 50, floor_y - 250, 100, 170), Color("#2B3566"))
		for i in 5:
			draw_rect(Rect2(hx - 50, floor_y - 240 + i * 34, 100, 14), Color("#FFF6EA"))
		draw_circle(Vector2(hx, floor_y - 300), 64, Color("#FFF6EA"))
		draw_circle(Vector2(hx - 10, floor_y - 360), 40, Color("#E23B4E"))
		draw_rect(Rect2(hx - 40, floor_y - 80, 24, 80), Color("#1B2340"))
		draw_rect(Rect2(hx + 16, floor_y - 80, 24, 80), Color("#1B2340"))
		var bx := vs.x * 0.66
		draw_circle(Vector2(bx, floor_y - 150), 110, Color("#7B3F8C"))
		draw_circle(Vector2(bx, floor_y - 300), 72, Color("#F4C9A8"))
		draw_circle(Vector2(bx - 40, floor_y - 360), 50, Color("#D9DCE6"))
		draw_circle(Vector2(bx + 30, floor_y - 370), 56, Color("#D9DCE6"))
		draw_rect(Rect2(bx - 50, floor_y - 50, 30, 50), Color("#1B2340"))
		draw_rect(Rect2(bx + 20, floor_y - 50, 30, 50), Color("#1B2340"))


## The Stalls band stand-in (StallsView is the view task's): silhouetted heads, never a target.
class _StallsStandIn:
	extends Control

	var band: Rect2 = Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if band.size.x <= 0.0:
			return
		var n := 14
		for i in n:
			var x := band.position.x + (float(i) + 0.5) * band.size.x / float(n)
			var r := 26.0 + float((i * 7) % 3) * 6.0
			var y := band.end.y - r * 0.6
			draw_circle(Vector2(x, y), r, Color(0.165, 0.118, 0.227, 0.6))
			if i % 4 == 1:
				draw_rect(Rect2(x - r * 0.8, y - r * 1.5, r * 1.6, r * 0.8), Color(0.165, 0.118, 0.227, 0.6))


## What the fake Bellows-Cam sees: a kitchen corner and Bellows at the kettle.
class _PipScene:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 448, 252), Color("#A9B79A"))
		draw_rect(Rect2(0, 190, 448, 62), Color("#8A5A3C"))
		draw_rect(Rect2(40, 110, 150, 80), Color("#E9E2D0"))
		draw_circle(Vector2(110, 96), 22, Color("#B8BDC9"))
		draw_circle(Vector2(290, 150), 58, Color("#7B3F8C"))
		draw_circle(Vector2(290, 70), 38, Color("#F59A94"))
		draw_circle(Vector2(268, 40), 26, Color("#D9DCE6"))
		draw_circle(Vector2(308, 36), 28, Color("#D9DCE6"))
		draw_circle(Vector2(278, 70), 5, Color("#1B2340"))
		draw_circle(Vector2(302, 70), 5, Color("#1B2340"))
