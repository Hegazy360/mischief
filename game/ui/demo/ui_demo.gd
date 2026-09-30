## UiDemo — the whole R3D HUD and the world overlays over a greybox 3D kitchen (FakeAnchors at the
## REDESIGN §5.2 base framing, house.json's frozen rects), driven by a scripted fake HudModel and — for
## the overlay states — by the REAL OverlayRules on a fake ViewSnapshot of the real content, for
## screenshots and frame sequences (r3d-hud brief §6).
##
## User args (after `--`):
##   --state=<name>        one of STATES (default "play_quiet")
##   --anchors=fake_kitchen  the 3D greybox anchor source (default); `--backdrop=2d` = the old 2D parlour
##   --left-handed         mirror the clusters
##   --safe-area=L,T,R,B   fake notch insets (logical px; SafeArea reads it)
##   --text-big            render with "Text +20 %" (the setting, not persisted)
##   --cycle               step through every state (CYCLE_FRAMES apart) — pair with DevShot
##                         `--shot-seq=/abs/dir --every=<CYCLE_FRAMES> --count=<n>`
extends Node

const STATES: PackedStringArray = [
	# R3D play states (the four always-on pieces + what shows when)
	"play_quiet", "rig_live", "rig_dim", "freeze_live", "freeze_filling", "hidden_green", "hidden_red", "go",
	"carrying", "meter", "running_gag", "catch", "bellows_window", "window_escalated", "edge_badge", "edge_lean",
	"emote_sing", "figgis_nudge", "figgis_card", "bow", "bow_window", "script_full", "tag_flight", "tray_arrows",
	"pick_strip", "lure_ring", "lure_grey",
	# world overlays (REDESIGN §4.1, §4.5)
	"overlays_v4", "overlays_v1", "overlays_rigging", "overlays_v2", "overlays_v3", "overlays_n4", "overlays_needs",
	"overlays_items", "overlays_his_ring", "overlays_combine", "placement",
	# panels
	"script", "pause", "pause_nobow", "settings", "settings_debug", "loading", "results", "encore",
]
const CYCLE_FRAMES := 40
const PANELS := {
	"script": "res://ui/panels/script_panel.gd",
	"pause": "res://ui/panels/pause_menu.gd",
	"pause_nobow": "res://ui/panels/pause_menu.gd",
	"settings": "res://ui/panels/settings_panel.gd",
	"settings_debug": "res://ui/panels/settings_panel.gd",
	"loading": "res://ui/panels/loading_card.gd",
	"results": "res://ui/panels/results_screen.gd",
}
## Where Hush and Bellows stand per state (metres on the lane; NAN = off stage).
const KITCHEN := "kitchen"

var hud: Hud
var model: HudModel
var overlays: WorldOverlays
var anchors: FakeAnchors
var omodel: OverlayModel = OverlayModel.new()
var octx: OverlayCtx = null
var osnap: ViewSnapshot = null
var db: ContentDB = null
var state: String = "play_quiet"
var _cycle: bool = false
var _frame: int = 0
var _cycle_i: int = 0
var _backdrop_2d: Node2D = null
var _stalls: Control
var _pip_vp: SubViewport
var _overlay_state: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--state="):
			state = a.substr(8)
		elif a == "--cycle":
			_cycle = true
		elif a == "--text-big":
			UiKit.text_scale_override = 1.2   # Settings "Text +20 %" without touching the user's file
	if UiKit.flag_value("--backdrop") == "2d":
		_backdrop_2d = _Backdrop.new()
		add_child(_backdrop_2d)
	else:
		anchors = FakeAnchors.new()
		anchors.name = "FakeKitchen"
		add_child(anchors)
		anchors.build_room(KITCHEN, 17.0, NAN)
	var stalls_layer := CanvasLayer.new()
	stalls_layer.layer = 9
	add_child(stalls_layer)
	_stalls = _StallsStandIn.new()
	stalls_layer.add_child(_stalls)
	_pip_vp = SubViewport.new()
	_pip_vp.size = Vector2i(400, 225)
	_pip_vp.transparent_bg = false
	_pip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pip_vp.add_child(_PipScene.new())
	add_child(_pip_vp)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = WorldOverlays.LAYER
	add_child(fx_layer)
	_fx = _FxStandIn.new()
	_fx.demo = self
	fx_layer.add_child(_fx)
	overlays = WorldOverlays.new()
	add_child(overlays)
	hud = Hud.new()
	add_child(hud)
	if anchors != null:
		overlays.setup(anchors, hud)
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
	if _overlay_state and octx != null and osnap != null:
		octx.now_s = float(UiKit.now_ms()) / 1000.0 + 100.0
		OverlayRules.fill(omodel, osnap, octx)
		if state == "placement" and anchors != null:
			_register_fx()
	elif not _overlay_state:
		omodel.clear()
		omodel.hidden = true
	overlays.apply(omodel)


## Configure the fake model (and panels) for `name`.
func _enter(name_: String) -> void:
	state = name_
	hud.close_panels()
	hud.ghost_finger(&"")
	hud.hide_figgis_card()
	hud.set_dim(false)
	if hud.action.is_pressed:
		hud.action.release_touch()
	if hud.clarence.is_pressed:
		hud.clarence.release_touch()
	_overlay_state = name_.begins_with("overlays") or name_ == "placement"
	var m := HudModel.new()
	m.applause = 64
	m.lines_done = 2
	m.lines_total = 3
	m.tomatoes_left = -1
	m.tomatoes_max = -1
	m.verb = HudModel.Verb.FREEZE
	m.clarence_mode = HudModel.ClarenceMode.SQUEAK
	m.pip_glyph = "specs_off"
	m.script_lines = _fake_script()
	m.script_loop = _fake_loop()
	m.script_pips = PackedInt32Array([HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_OPEN,
		HudModel.Pip.OPT_DONE, HudModel.Pip.OPT_OPEN, HudModel.Pip.BIG_SEALED])
	var hush_x := 17.0
	var bellows_x := NAN
	match name_:
		"rig_live":
			m.verb = HudModel.Verb.RIG
			m.verb_item_icon = ""
			m.verb_target_icon = "tea"
			m.ring_frac = 0.5
			hush_x = 15.0
		"rig_dim":
			m.verb = HudModel.Verb.RIG_DIM
			m.verb_item_icon = "squeaker"
			m.tray_arrows = PackedVector2Array([Vector2(-1, -0.2)])
			m.tray_arrows_item = "squeaker"
			hush_x = 14.9
		"freeze_live":
			m.freeze_danger = HudModel.FreezeDanger.EXPOSED
			bellows_x = 15.2
		"freeze_filling":
			m.freeze_danger = HudModel.FreezeDanger.FILLING
			bellows_x = 16.0
		"hidden_green", "hidden_red":
			m.verb = HudModel.Verb.POP_OUT
			m.clarence_mode = HudModel.ClarenceMode.FF
			m.rim = HudModel.Rim.GREEN if name_ == "hidden_green" else HudModel.Rim.RED
			hush_x = NAN
			if name_ == "hidden_red":
				bellows_x = 16.4
		"go":
			m.verb = HudModel.Verb.GO
			m.rim = HudModel.Rim.AMBER
			m.clarence_mode = HudModel.ClarenceMode.FF
			hush_x = NAN
		"carrying":
			m.tray = PackedStringArray(["squeaker", "kipper"])
		"meter":
			m.applause = 64
		"running_gag":
			m.link = 2
			m.mult_pct = 150
			m.fuse_frac = 0.62
		"catch":
			m.tomatoes_max = 3
			m.tomatoes_left = 3
		"bellows_window", "window_escalated":
			m.pip_visible = true
			m.pip_frame_tier = 1
			m.pip_next_icon = "tea"
			m.pip_ring_frac = 0.55
			m.pip_escalated = name_ == "window_escalated"
		"edge_badge":
			m.edge_bubble_dir = Vector2(-1, 0)
			m.edge_badge_icon = "warmup"
		"edge_lean":
			m.edge_badge_lean = true
			m.edge_badge_side = 1
			m.edge_bubble_dir = Vector2(1, 0)
			m.edge_badge_icon = "tea"
		"emote_sing":
			m.edge_bubble_dir = Vector2(1, 0)
			m.edge_badge_icon = "warmup"
			m.edge_bubble_emote = "sing"
		"figgis_nudge":
			m.figgis_pulse = true
		"bow":
			m.bow_visible = true
			m.script_pips = PackedInt32Array([HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_DONE, HudModel.Pip.REQ_DONE,
				HudModel.Pip.OPT_DONE, HudModel.Pip.OPT_OPEN, HudModel.Pip.BIG_OPEN])
		"bow_window":
			m.bow_visible = true
			m.pip_visible = true
			m.pip_next_icon = "paper"
			m.pip_ring_frac = 0.3
		"script_full":
			var p := PackedInt32Array()
			for i in 5:
				p.append(HudModel.Pip.REQ_DONE if i < 3 else HudModel.Pip.REQ_OPEN)
			for i in 3:
				p.append(HudModel.Pip.OPT_OPEN)
			p.append(HudModel.Pip.BIG_SEALED)
			m.script_pips = p
		"tray_arrows":
			m.tray = PackedStringArray(["kipper"])
			m.tray_arrows = PackedVector2Array([Vector2(1, -0.35), Vector2(-1, 0.1)])
			m.tray_arrows_item = "kipper"
		"pick_strip":
			m.pick_strip_container = "kitchen_pantry_shelf"
			m.pick_strip_items = PackedStringArray(["flour", "sherbet", "treacle"])
			m.pick_strip_pos = Vector2(hud.viewport_size().x * 0.62, 520)
		"lure_ring":
			m.lure_ring = HudModel.LureRing.ON
		"lure_grey":
			m.lure_ring = HudModel.LureRing.GREY
		"encore":
			m.applause = 118
			m.link = 3
			m.mult_pct = 200
			m.fuse_frac = 0.35
		_:
			if PANELS.has(name_):
				m.paused = not name_.begins_with("loading")
	if _overlay_state:
		var pos := _overlay_setup(name_, m)
		hush_x = pos.x
		bellows_x = pos.y
	if anchors != null:
		_place_actors(hush_x, bellows_x)
	model = m
	hud.apply(model)
	_after_enter(name_)


func _place_actors(hush_x: float, bellows_x: float) -> void:
	anchors.build_room(KITCHEN, hush_x, bellows_x)
	anchors.hush_at = ""
	if octx != null and _overlay_state:
		anchors.hush_at = octx.at_hotspot


## The overlay scenes: the real OverlayRules on a fake snapshot of the real content. Returns (Hush x m,
## Bellows x m) for the greybox.
func _overlay_setup(name_: String, m: HudModel) -> Vector2:
	if db == null:
		db = ContentDB.load_dir("res://data")
	var ep_id := "n02_something_fishy" if name_ in ["overlays_items", "placement"] else "n01_throat_tea"
	octx = OverlayCtx.new()
	octx.prepare(db, db.episodes.get(ep_id), null, OverlayCtx.load_previews())
	if octx.previews.is_empty():
		var fx := "res://tests/ui/fixtures/previews.json"
		if FileAccess.file_exists(fx):
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(fx)) == OK:
				octx.prepare(db, db.episodes.get(ep_id), null, j.data)
	var s := ViewSnapshot.new()
	s.hush.present = true
	s.hush.room = KITCHEN
	s.hush.state = "IDLE"
	s.bellows.present = true
	s.bellows.room = "parlour"
	s.bellows.state = "ROUTINE"
	for hs in octx.rig_pranks:
		s.hotspots[hs] = {"kind": "rig_point", "enabled": true, "rigged": false, "spent": false}
	for r in octx.room_hides:
		for hs in octx.room_hides[r]:
			s.hotspots[hs] = {"kind": "hiding", "enabled": true, "occupant": false}
	for r in octx.room_containers:
		for c in octx.room_containers[r]:
			var stock := []
			for it in octx.item_source:
				if octx.item_source[it] == c:
					stock.append(it)
			s.hotspots[c] = {"kind": "container", "enabled": true, "stock": stock}
	var hush_x := 16.9
	var bellows_x := NAN
	match name_:
		"overlays_v1", "overlays_rigging":
			octx.at_hotspot = "kitchen_honey"
			hush_x = 15.05
			m.verb = HudModel.Verb.RIG
			m.verb_target_icon = "tea"
			if name_ == "overlays_rigging":
				s.hush.state = "RIGGING"
				s.hush.rig_pm = 550
				m.ring_frac = 0.55
		"overlays_v2":
			octx.entry_warning = true
			bellows_x = 13.2
			m.freeze_danger = HudModel.FreezeDanger.NONE
			m.pip_visible = true
			m.pip_next_icon = "tea"
			m.pip_ring_frac = 0.2
		"overlays_v3":
			s.hush.state = "HIDDEN"
			s.hush.hidden_spot = "kitchen_pantry_curtain"
			octx.prev_hidden = true
			hush_x = NAN
			m.verb = HudModel.Verb.POP_OUT
			m.clarence_mode = HudModel.ClarenceMode.FF
		"overlays_n4":
			octx.idle_s = 7.0
			octx.next_useful = "kitchen_pickle_jar"
		"overlays_needs":
			octx.seen_containers["hall_confiscated_box"] = true
		"overlays_his_ring":
			for a in octx.trig_hotspots:
				if (octx.trig_hotspots[a] as PackedStringArray).has("kitchen_kettle"):
					s.bubble_next = a
			s.bubble_ring_ticks = 120
			octx.ring_peak = 240
		"overlays_combine":
			s.hotspots["kitchen_honey"]["rigged"] = true
			s.hotspots["kitchen_sink_tap"]["rigged"] = true
		"placement":
			# a crowded moment: Hush between the stacked kettle / honey and the fridge, the caption
			# and his bubble registered by the view's FX in the same placer
			octx.at_hotspot = "kitchen_fridge_shelf"
			hush_x = 16.2
			bellows_x = 17.3
			m.verb = HudModel.Verb.RIG
			m.verb_target_icon = "snack"
	octx.prev_armed = 0
	for hs in octx.rig_pranks:
		if bool((s.hotspots[hs] as Dictionary).get("rigged", false)):
			octx.prev_armed += 1
	octx.prev_carry = 0
	s.hush.x = (hush_x if not is_nan(hush_x) else 18.1) * 200.0
	osnap = s
	return Vector2(hush_x, bellows_x)


func _after_enter(name_: String) -> void:
	var c := hud.action.size * 0.5
	match name_:
		"rig_live":
			hud.action.touch(true, c, 7)
		"meter":
			model.applause = 99
		"catch":
			model.tomatoes_left = 2
		"figgis_card":
			hud.show_figgis_card(UiIcons.card_set("card_tray"), 60.0)
		"tag_flight":
			hud.fly_tag(Vector2(hud.viewport_size().x * 0.5, 560.0), 2)
	hud.root.visible = not name_.begins_with("results")
	if PANELS.has(name_):
		_open_panel(name_)


func _open_panel(name_: String) -> void:
	var path: String = PANELS[name_]
	if not ResourceLoader.exists(path):
		return
	var p: Control = (load(path) as GDScript).new()
	if name_.begins_with("loading"):
		p.set("auto_close", false)
	match name_:
		"script":
			p.call("setup", model.script_lines, model.script_loop, 2, 3)
		"pause":
			p.call("setup", true, {"applause": 87, "tomatoes_left": 2, "tomatoes_max": 3, "curtain_calls": 1})
		"pause_nobow":
			p.call("setup", false, {"applause": 12})
		"settings_debug":
			p.set("tab", "debug")
			p.set("show_debug", true)
		"loading":
			p.call("setup", {"title": UiStrings.t("loading.night", {"n": 1}), "subtitle": "Throat Tea",
				"text": "Tap a cupboard to take what's inside. At the right spot the button lights up. Hold to rig.",
				"icon": "tray"})
		"results":
			p.call("setup", {"applause": 91, "stars": [true, true, false], "why": "Applause 91 — land one more prank inside a Running Gag",
				"new": ["ACHOO-RIA!", "KETTLE DRUM"], "has_next": true, "night_title": "Night 1 · Throat Tea", "stage": true})
	hud.show_panel(p)


## The view's 2D FX register in the SAME placer every frame (as WorldView3D's will): his thought
## bubble over his head (fixed, the top priority) and a pun caption by it (the lowest).
func _register_fx() -> void:
	var head := anchors.project(anchors.actor_anchor(&"bellows", &"head"))
	if not head.is_finite():
		return
	var it := overlays.placer.request(&"fx_bubble", OverlayPlacer.Pri.BUBBLE,
		Rect2(head + Vector2(-100, -230), Vector2(200, 170)), head, true)
	_bubble_rect = it.rect
	var cap := overlays.placer.request(&"fx_caption", OverlayPlacer.Pri.CAPTION,
		Rect2(head + Vector2(-60, -120), Vector2(420, 110)), head)
	_caption_rect = cap.rect if cap.visible else Rect2()
	_fx.queue_redraw()


var _bubble_rect := Rect2()
var _caption_rect := Rect2()
var _fx: Node2D = null


func _animate() -> void:
	var t := float(_frame) / 60.0
	if state == "running_gag":
		model.fuse_frac = maxf(0.0, 0.62 - t * 0.02)
	elif state == "overlays_rigging" and osnap != null:
		osnap.hush.rig_pm = mini(1000, 450 + int(float(_frame % CYCLE_FRAMES) * 6.0))


func _fake_script() -> Array:
	return [
		{"id": "kettle", "text": "Bellows sings a duet with his kettle", "req": true, "done": true, "rigged": true,
			"discovered": true, "icon": "tea"},
		{"id": "tap", "text": "The tap gives him a bath", "req": true, "done": true, "rigged": true,
			"discovered": true, "icon": "rinse"},
		{"id": "pickle", "text": "He gets himself in a pickle", "req": true, "done": false, "rigged": false,
			"discovered": true, "icon": "pickles"},
		{"id": "lift", "text": "Lift-off from the recliner", "req": false, "done": true, "rigged": false,
			"discovered": true, "icon": "paper"},
		{"id": "sneeze", "text": "", "req": false, "done": false, "rigged": false, "discovered": false},
		{"id": "bn", "text": "HOT & COLD: sneeze him into the sink", "req": false, "done": false, "rigged": false,
			"discovered": true, "big_number": true, "sealed": true},
	]


func _fake_loop() -> Array:
	return [
		{"activity": "warmup", "rigged": false, "current": false},
		{"activity": "tea", "rigged": true, "current": true},
		{"activity": "pickles", "rigged": false, "current": false},
		{"activity": "paper", "rigged": false, "current": false},
		{"activity": "rinse", "rigged": true, "current": false},
	]


## Stand-ins for the view's 2D FX in the placement demo: his thought bubble and a pun caption.
class _FxStandIn:
	extends Node2D

	var demo: Node = null

	func _draw() -> void:
		if demo == null or String(demo.get("state")) != "placement":
			return
		var b: Rect2 = demo.get("_bubble_rect")
		if b.has_area():
			UiKit.draw_chunky_rect(self, b, 40.0, UiKit.CREAM, UiKit.CREAM_SHADE, 5.0, 8.0)
			UiShapes.begin()
			UiShapes.arc(b.get_center(), 62.0, -PI * 0.5, PI * 0.9, 12.0, UiKit.RED, 40)
			UiShapes.flush(self)
			UiKit.draw_icon(self, UiIcons.activity("snack"), Rect2(b.get_center() - Vector2(56, 56), Vector2(112, 112)))
		var c: Rect2 = demo.get("_caption_rect")
		if c.has_area():
			UiKit.draw_text_centered(self, UiKit.display_font(), c.get_center(), "COLD OPEN!", 88, UiKit.GOLD_LIGHT, 12)


## The old 2D greybox parlour (`--backdrop=2d`).
class _Backdrop:
	extends Node2D

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var floor_y := vs.y * 0.86
		draw_rect(Rect2(Vector2.ZERO, vs), Color("#6E7F66"))
		draw_rect(Rect2(0, floor_y - 170, vs.x, 170), Color("#5B3A2E"))
		draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("#8A5A3C"))


## The Stalls band stand-in (StallsView is the view task's, hidden at rest in R3D): nothing drawn at
## rest; kept so a laugh state can be staged later.
class _StallsStandIn:
	extends Control

	var band: Rect2 = Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)


## What the fake Bellows window sees: a kitchen corner and Bellows at the kettle.
class _PipScene:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 400, 225), Color("#C7B684"))
		draw_rect(Rect2(0, 170, 400, 55), Color("#8E6E52"))
		draw_rect(Rect2(30, 100, 140, 70), Color("#E9E2D0"))
		draw_circle(Vector2(100, 86), 20, Color("#4E9C9A"))
		draw_circle(Vector2(260, 132), 52, Color("#7B3F8C"))
		draw_circle(Vector2(260, 62), 34, Color("#F4C9A8"))
		draw_circle(Vector2(240, 36), 24, Color("#D9DCE6"))
		draw_circle(Vector2(278, 32), 26, Color("#D9DCE6"))
		draw_circle(Vector2(250, 62), 4, Color("#1B2340"))
		draw_circle(Vector2(272, 62), 4, Color("#1B2340"))
