## GameplaySample — one scripted Act in the parlour, played on the baked cast.
##
## This is the integration sample the stage viewer cannot be: the same sheets, but inside the game's
## staging from the GDD — hotspot badges, ghost-finger taps, the RIG ring, FREEZE in plain sight,
## Clarence the lure, Gus's thought bubble, the awareness "?" and stare strip, the Stalls and the
## Applause meter. Everything scripted lives in gameplay.json (one event list); this script only
## knows the verbs. The runtime is still only: advance a clock, pick a frame, blit a region.
extends Control

const SHEETS := "res://proto/bakery/sheets/"
const SCRIPT_JSON := "res://proto/bakery/gameplay.json"

const COL_BG := Color("#141A33")
const COL_WALL := Color("#4A3A63")
const COL_WALL2 := Color("#51406C")
const COL_SKIRT := Color("#352A4C")
const COL_FLOOR := Color("#5A3E2E")
const COL_FLOOR_TOP := Color("#7A5640")
const COL_CURTAIN := Color("#8E2F3C")
const COL_CURTAIN2 := Color("#6E222E")
const COL_GOLD := Color("#FFC93C")
const COL_WOOD := Color("#9A6638")
const COL_BRASS := Color("#D8A43C")
const COL_INK := Color("#1A1420")
const COL_TEXT := Color("#FFF4E0")
const COL_DIM := Color("#8E97BF")
const COL_AMBER := Color("#FFB63C")
const CONFETTI := [Color("#E23B4E"), Color("#FFC93C"), Color("#4FA845"), Color("#5AC8E0"), Color("#F27BB0")]


class Actor:
	var who: String = ""
	var x: float = 0.0
	var dir: int = 1
	var clip: String = "idle"
	var t: float = 0.0
	var k: float = 1.0
	var hold: float = 0.0
	var target: float = INF        # INF = not moving
	var hidden: bool = false


var _index: Dictionary = {}
var _tex: Dictionary = {}
var _cfg: Dictionary = {}
var _events: Array = []
var _ei: int = 0
var _t: float = 0.0
var _scale: float = 1.5
var _floor: float = 880.0
var _actors: Dictionary = {}

var _caption: String = ""
var _stalls: String = ""
var _stalls_t: float = -10.0
var _bubble: String = "none"
var _aware: float = 0.0
var _aware_to: float = 0.0
var _aware_rate: float = 0.0
var _strip: bool = false
var _ring: float = 0.0            # RIG progress shown on the action button, 0..1
var _ring_to: float = 0.0
var _ring_rate: float = 0.0
var _freeze_on: bool = false
var _clar_on: bool = false
var _applause: float = 0.0
var _rigged: bool = false
var _gag_t: float = -1.0          # seconds since the gag fired, <0 = armed/idle
var _ghosts: Array = []           # {x, y, kind, label, t}
var _font_d: Font = null
var _font_b: Font = null


func _ready() -> void:
	# a virtual display can run unthrottled (~1000 fps), which turns a real-time timeline into
	# slow motion on camera; the cap keeps live play and frame captures on the same clock
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(COL_BG)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_d = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
	_font_b = load("res://ui/theme/fonts/Nunito-Bold.ttf")
	_index = _load_json(SHEETS + "index.json")
	_cfg = _load_json(SCRIPT_JSON)
	if _index.is_empty() or _cfg.is_empty():
		push_error("missing sheets or gameplay.json — run: python3 tools/bakery/run.py")
		return
	for who: String in _cast():
		for name: String in _clips(who):
			var p := SHEETS + str((_clips(who)[name] as Dictionary)["sheet"])
			if ResourceLoader.exists(p):
				_tex[who + "/" + name] = load(p)
	_scale = float(_cfg.get("scale", 1.5))
	_floor = float(_cfg.get("floor_y", 880.0))
	_events = _cfg.get("events", [])
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	_restart()


func _restart() -> void:
	_t = 0.0
	_ei = 0
	_caption = ""
	_stalls_t = -10.0
	_bubble = "none"
	_aware = 0.0
	_aware_to = 0.0
	_ring = 0.0
	_ring_to = 0.0
	_freeze_on = false
	_clar_on = false
	_applause = 0.0
	_rigged = false
	_gag_t = -1.0
	_ghosts.clear()
	_actors.clear()
	for who: String in (_cfg.get("start", {}) as Dictionary):
		var st: Dictionary = _cfg["start"][who]
		var a := Actor.new()
		a.who = who
		a.x = float(st.get("x", 400))
		a.dir = int(st.get("dir", 1))
		a.clip = str(st.get("clip", "idle"))
		_actors[who] = a


# --- data ---------------------------------------------------------------------------------------
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var out: Variant = JSON.parse_string(txt)
	return out if out is Dictionary else {}


func _cast() -> Dictionary:
	return _index.get("cast", {})


func _clips(who: String) -> Dictionary:
	return (_cast().get(who, {}) as Dictionary).get("clips", {})


func _clip(who: String, name: String) -> Dictionary:
	return _clips(who).get(name, {})


func _length(info: Dictionary) -> float:
	var total := 0.0
	for d: Variant in (info.get("durations", []) as Array):
		total += float(d)
	return maxf(total, 0.05)


func _frame_at(info: Dictionary, t: float) -> int:
	var durs: Array = info.get("durations", [])
	var count := int(info.get("count", 1))
	if durs.size() != count or count <= 1:
		return 0
	var total := _length(info)
	var tt := fmod(t, total) if bool(info.get("loop", false)) else minf(t, total - 0.0001)
	for i in count:
		tt -= float(durs[i])
		if tt < 0.0:
			return i
	return count - 1


func _faces(who: String) -> int:
	return int((_cast().get(who, {}) as Dictionary).get("faces", 1))


# --- the timeline -------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	while _ei < _events.size() and float(_events[_ei]["t"]) <= _t:
		_apply(_events[_ei])
		_ei += 1
	if _t >= float(_cfg.get("loop_at", 40.0)):
		_restart()
	for who: String in _actors:
		_advance(_actors[who], delta)
	_aware = move_toward(_aware, _aware_to, absf(_aware_rate) * delta)
	_ring = move_toward(_ring, _ring_to, absf(_ring_rate) * delta)
	if _gag_t >= 0.0:
		_gag_t += delta
	for g: Dictionary in _ghosts:
		g["t"] = float(g["t"]) + delta
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return float(g["t"]) < 2.2)
	queue_redraw()


func _apply(e: Dictionary) -> void:
	var who := str(e.get("who", ""))
	var a: Actor = _actors.get(who)
	match str(e["do"]):
		"caption":
			_caption = str(e["text"])
		"stalls":
			_stalls = str(e["text"])
			_stalls_t = _t
		"bubble":
			_bubble = str(e.get("icon", "none"))
		"clip":
			_set_clip(a, str(e["name"]), float(e.get("k", 1.0)), float(e.get("hold", 0.0)))
			a.target = INF
		"move":
			_set_clip(a, str(e["clip"]), float(e.get("k", 1.0)), 0.0)
			a.target = float(e["to"])
			a.dir = 1 if a.target > a.x else -1
		"freeze":
			_freeze_on = bool(e.get("on", false))
		"hide":
			a.hidden = bool(e.get("on", false))
		"ghost":
			_ghosts.append({"x": float(e["x"]), "y": float(e["y"]), "kind": str(e.get("kind", "tap")),
				"label": str(e.get("label", "")), "t": 0.0})
		"button":
			if str(e["name"]) == "freeze":
				_freeze_on = bool(e.get("on", false))
			else:
				_clar_on = bool(e.get("on", false))
		"ring":
			_ring_to = float(e.get("frac", 1.0))
			_ring_rate = (_ring_to - _ring) / maxf(0.05, float(e.get("secs", 1.0)))
		"rigged":
			_rigged = bool(e.get("on", false))
			if not _rigged:
				_ring = 0.0
				_ring_to = 0.0
		"awareness":
			_aware_to = clampf(float(e.get("to", 0.0)), 0.0, 1.0)
			_aware_rate = (_aware_to - _aware) / maxf(0.05, float(e.get("secs", 1.0)))
		"strip":
			_strip = bool(e.get("on", false))
		"gag":
			_gag_t = 0.0
		"applause":
			_applause = clampf(_applause + float(e.get("add", 0.0)), 0.0, 1.0)


func _set_clip(a: Actor, name: String, k: float, hold: float) -> void:
	if a == null or not _clips(a.who).has(name):
		return
	var info := _clip(a.who, name)
	# a chained clip (getup follows knocked) starts where the body ended, not where the root was
	if str(info.get("follows", "")) == a.clip:
		a.x += float(info.get("enter_dx", 0.0)) * _scale * float(a.dir)
	a.clip = name
	a.t = 0.0
	a.k = k
	a.hold = hold


func _advance(a: Actor, delta: float) -> void:
	a.t += delta * a.k
	var info := _clip(a.who, a.clip)
	if a.target != INF:
		# locomotion travels at the speed the bake measured off the planted foot (x the time multiplier)
		var sp := float(info.get("ground_speed_px", 60.0)) * a.k * _scale
		a.x = move_toward(a.x, a.target, sp * delta)
		if is_equal_approx(a.x, a.target):
			a.target = INF
			_set_clip(a, "idle", 1.0, 0.0)
	elif not bool(info.get("loop", false)) and a.t > _length(info) * a.k + a.hold and a.hold < 50.0:
		_set_clip(a, "idle", 1.0, 0.0)


# --- drawing ------------------------------------------------------------------------------------
func _draw() -> void:
	var vs := get_viewport_rect().size
	var u := vs.y / 1080.0
	if _index.is_empty() or _cfg.is_empty():
		draw_string(_font_b, Vector2(40, 80), "no sheets — run:  python3 tools/bakery/run.py",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_GOLD)
		return
	var fy := _floor * u
	var setd: Dictionary = _cfg.get("set", {})
	_draw_room(vs, u, fy, setd)
	if _strip:
		_draw_strip(u, fy)
	_draw_badges(u, fy, setd)
	# upstage first: Gus, then Hush, then the plant's front leaves when she hides behind it
	var gus: Actor = _actors["gus"]
	var hush: Actor = _actors["hush"]
	_draw_actor(gus, u, fy)
	_draw_actor(hush, u, fy)
	if hush.hidden:
		_draw_plant(u, fy, float(setd.get("plant_x", 330)), true)
	_draw_gag(u, fy, setd)
	_draw_bubble(gus, u, fy)
	_draw_awareness(hush, u, fy)
	for g: Dictionary in _ghosts:
		_draw_ghost(g, u)
	_draw_hud(vs, u)


func _draw_room(vs: Vector2, u: float, fy: float, setd: Dictionary) -> void:
	draw_rect(Rect2(0, 0, vs.x, fy), COL_WALL)
	for i in 16:
		if i % 2 == 0:
			draw_rect(Rect2(float(i) * 160.0 * u, 0, 80.0 * u, fy), COL_WALL2)
	draw_rect(Rect2(0, fy - 56.0 * u, vs.x, 56.0 * u), COL_SKIRT)
	draw_rect(Rect2(0, fy, vs.x, vs.y - fy), COL_FLOOR)
	draw_rect(Rect2(0, fy, vs.x, 5.0 * u), COL_FLOOR_TOP)
	# the door he owns the house through
	var dx := float(setd.get("door_x", 2250)) * u
	draw_rect(Rect2(dx - 110.0 * u, fy - 500.0 * u, 220.0 * u, 500.0 * u), Color("#3A2E52"))
	draw_rect(Rect2(dx - 90.0 * u, fy - 482.0 * u, 180.0 * u, 482.0 * u), Color("#2A2140"))
	draw_circle(Vector2(dx - 60.0 * u, fy - 240.0 * u), 9.0 * u, COL_BRASS)
	# proscenium curtains: this is still a stage
	draw_rect(Rect2(0, 0, 90.0 * u, vs.y), COL_CURTAIN)
	draw_rect(Rect2(vs.x - 90.0 * u, 0, 90.0 * u, vs.y), COL_CURTAIN)
	for i in 13:
		var cx := float(i) * 200.0 * u
		draw_circle(Vector2(cx, 26.0 * u), 44.0 * u, COL_CURTAIN2)
		draw_circle(Vector2(cx + 100.0 * u, 20.0 * u), 50.0 * u, COL_CURTAIN)
	_draw_mirror(u, fy, float(setd.get("mirror_x", 1300)))
	_draw_plant(u, fy, float(setd.get("plant_x", 330)), false)
	_draw_gramophone(u, fy, float(setd.get("gramophone_x", 620)))


func _draw_mirror(u: float, fy: float, mx: float) -> void:
	var c := Vector2(mx * u, fy - 250.0 * u)
	draw_line(Vector2(c.x - 40.0 * u, fy), Vector2(c.x, fy - 90.0 * u), COL_WOOD, 10.0 * u)
	draw_line(Vector2(c.x + 40.0 * u, fy), Vector2(c.x, fy - 90.0 * u), COL_WOOD, 10.0 * u)
	draw_set_transform(c, 0.08, Vector2(1.0, 1.55))
	draw_circle(Vector2.ZERO, 92.0 * u, COL_BRASS)
	draw_circle(Vector2.ZERO, 80.0 * u, Color("#BFD9E8"))
	draw_circle(Vector2(-26.0 * u, -30.0 * u), 16.0 * u, Color("#E6F4FC"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_plant(u: float, fy: float, px: float, front_only: bool) -> void:
	var bx := px * u
	if not front_only:
		for blob: Vector3 in [Vector3(-38, -300, 58), Vector3(30, -350, 64), Vector3(-6, -420, 56),
				Vector3(58, -280, 46), Vector3(-64, -360, 44)]:
			draw_circle(Vector2(bx + blob.x * u, fy + blob.y * u), blob.z * u, Color("#2E6B38"))
	else:
		for blob: Vector3 in [Vector3(-30, -260, 52), Vector3(34, -300, 56), Vector3(2, -360, 50)]:
			draw_circle(Vector2(bx + blob.x * u, fy + blob.y * u), blob.z * u, Color("#3C8A48"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx - 70.0 * u, fy - 240.0 * u), Vector2(bx + 70.0 * u, fy - 240.0 * u),
		Vector2(bx + 46.0 * u, fy), Vector2(bx - 46.0 * u, fy)]), Color("#B4552E"))
	draw_rect(Rect2(bx - 76.0 * u, fy - 252.0 * u, 152.0 * u, 26.0 * u), Color("#C96636"))


func _draw_gramophone(u: float, fy: float, gx: float) -> void:
	var bx := gx * u
	draw_rect(Rect2(bx - 110.0 * u, fy - 200.0 * u, 220.0 * u, 20.0 * u), COL_WOOD)
	draw_rect(Rect2(bx - 90.0 * u, fy - 180.0 * u, 18.0 * u, 180.0 * u), Color("#6E4424"))
	draw_rect(Rect2(bx + 72.0 * u, fy - 180.0 * u, 18.0 * u, 180.0 * u), Color("#6E4424"))
	draw_rect(Rect2(bx - 80.0 * u, fy - 262.0 * u, 130.0 * u, 62.0 * u), Color("#6E4424"))
	draw_circle(Vector2(bx - 92.0 * u, fy - 232.0 * u), 9.0 * u, COL_BRASS)
	# the horn aims stage right, where he stands to crank it
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx + 20.0 * u, fy - 268.0 * u), Vector2(bx + 150.0 * u, fy - 390.0 * u),
		Vector2(bx + 190.0 * u, fy - 300.0 * u), Vector2(bx + 52.0 * u, fy - 246.0 * u)]), COL_BRASS)
	draw_circle(Vector2(bx + 174.0 * u, fy - 344.0 * u), 50.0 * u, COL_BRASS)
	draw_circle(Vector2(bx + 174.0 * u, fy - 344.0 * u), 36.0 * u, Color("#8A6322"))
	if _rigged:
		# her beret stamp: the GDD's mark for an armed prank
		draw_set_transform(Vector2(bx + 174.0 * u, fy - 344.0 * u), -0.12, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, 26.0 * u, Color("#E23B4E"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_strip(u: float, fy: float) -> void:
	var gus: Actor = _actors["gus"]
	if gus.clip in ["knocked", "getup", "hit"]:
		return
	var dirf := float(gus.dir)
	var x0 := gus.x * u + dirf * 70.0 * u
	var x1 := gus.x * u + dirf * 630.0 * u
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, fy + 6.0 * u), Vector2(x1, fy + 6.0 * u),
		Vector2(x1, fy + 40.0 * u), Vector2(x0, fy + 52.0 * u)]), Color(COL_AMBER, 0.22))
	draw_line(Vector2(x1, fy + 6.0 * u), Vector2(x1, fy + 40.0 * u), Color(COL_AMBER, 0.6), 3.0 * u)


func _draw_badges(u: float, fy: float, setd: Dictionary) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 + 0.08 * sin(t * 6.0)
	var gx := float(setd.get("gramophone_x", 620)) * u
	var col := Color("#8E97BF") if _rigged else COL_GOLD
	draw_arc(Vector2(gx, fy - 420.0 * u), 26.0 * u * (pulse if not _rigged else 1.0), 0, TAU, 24, col, 5.0 * u)
	if _rigged:
		draw_line(Vector2(gx - 12.0 * u, fy - 420.0 * u), Vector2(gx + 12.0 * u, fy - 420.0 * u), col, 5.0 * u)
	var px := float(setd.get("plant_x", 330)) * u
	# hiding spot: the blue closed-eye badge; it breathes while she is in there
	var hidden: bool = (_actors["hush"] as Actor).hidden
	var br := (26.0 + (3.0 * sin(t * 5.0) if hidden else 0.0)) * u
	draw_circle(Vector2(px, fy - 470.0 * u), br, Color("#3C6CC8"))
	draw_arc(Vector2(px, fy - 474.0 * u), br * 0.5, 0.3, PI - 0.3, 12, COL_TEXT, 4.0 * u)


func _draw_actor(a: Actor, u: float, fy: float) -> void:
	var info := _clip(a.who, a.clip)
	if info.is_empty():
		return
	var s := _scale * u
	draw_set_transform(Vector2(a.x * u, fy + 2.0 * u), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 50.0 * s, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var flip := a.dir * _faces(a.who) < 0
	# hiding = tucked behind the plant: ghosted so the demo still shows where she is
	var mod := Color(1, 1, 1, 0.45) if a.hidden else Color.WHITE
	_blit(a.who, a.clip, _frame_at(info, a.t), Vector2(a.x * u, fy), s, flip, mod)
	if a.clip.begins_with("freeze_"):
		var plinth := Color(0.6, 0.85, 1.0, 0.35 + 0.1 * sin(_t * 5.0))
		draw_arc(Vector2(a.x * u, fy - 140.0 * u), 120.0 * u, 0, TAU, 32, plinth, 4.0 * u)


func _blit(who: String, name: String, frame: int, foot: Vector2, s: float, flip: bool,
		mod: Color = Color.WHITE) -> void:
	var info := _clip(who, name)
	var tex: Texture2D = _tex.get(who + "/" + name)
	if tex == null or info.is_empty():
		return
	var fw := float(info.get("frame_w", 64))
	var fh := float(info.get("frame_h", 64))
	var cols := maxi(1, int(info.get("cols", int(info.get("count", 1)))))
	var cell := Vector2(float(frame % cols) * fw, float(frame / cols) * fh)
	var anc: Array = info.get("anchor", [fw * 0.5, fh])
	draw_set_transform(foot, 0.0, Vector2(-s if flip else s, s))
	draw_texture_rect_region(tex, Rect2(Vector2(-float(anc[0]), -float(anc[1])), Vector2(fw, fh)),
		Rect2(cell, Vector2(fw, fh)), mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gag(u: float, fy: float, setd: Dictionary) -> void:
	if _gag_t < 0.0:
		return
	var horn := Vector2(float(setd.get("gramophone_x", 620)) * u + 174.0 * u, fy - 344.0 * u)
	var reach := 260.0 * u * clampf(_gag_t / 0.12, 0.0, 1.0)
	if _gag_t > 0.8:
		reach = maxf(0.0, 260.0 * u * (1.0 - (_gag_t - 0.8) / 0.3))
	if reach > 1.0:
		var tip := horn + Vector2(reach, 36.0 * u * (reach / (260.0 * u)))
		var pts := PackedVector2Array()
		for i in 9:
			var f := float(i) / 8.0
			pts.append(horn.lerp(tip, f) + Vector2(0, (6.0 if i % 2 == 0 else -6.0) * u))
		draw_polyline(pts, Color("#8E97BF"), 5.0 * u)
		draw_circle(tip, 34.0 * u, Color("#E23B4E"))
	# confetti burst, deterministic
	if _gag_t < 1.6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 30:
			var a0 := rng.randf_range(-2.6, -0.5)
			var v0 := rng.randf_range(260.0, 620.0) * u
			var life := _gag_t - rng.randf_range(0.0, 0.2)
			if life < 0.0:
				continue
			var p := horn + Vector2(cos(a0), sin(a0)) * v0 * life + Vector2(0, 460.0 * u * life * life)
			draw_rect(Rect2(p, Vector2(10.0 * u, 7.0 * u)), CONFETTI[i % CONFETTI.size()])


func _draw_bubble(gus: Actor, u: float, fy: float) -> void:
	if _bubble == "none":
		return
	var c := Vector2(gus.x * u, fy - 500.0 * u)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14.0 * u, 28.0 * u),
		c + Vector2(16.0 * u, 28.0 * u), c + Vector2(-2.0 * u, 62.0 * u)]), COL_TEXT)
	draw_circle(c, 46.0 * u, COL_TEXT)
	match _bubble:
		"mirror":
			draw_set_transform(c, 0.0, Vector2(0.72, 1.0))
			draw_arc(Vector2.ZERO, 26.0 * u, 0, TAU, 20, COL_BRASS, 5.0 * u)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"gramophone":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20.0 * u, 12.0 * u),
				c + Vector2(10.0 * u, -22.0 * u), c + Vector2(22.0 * u, 2.0 * u)]), COL_BRASS)
			draw_circle(c + Vector2(14.0 * u, -14.0 * u), 12.0 * u, COL_BRASS)
		"query":
			draw_string(_font_d, c + Vector2(-12.0 * u, 14.0 * u), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * u), COL_AMBER)


func _draw_awareness(target: Actor, u: float, fy: float) -> void:
	# the GDD's "?" fills on HUSH: the danger is hers to read
	if _aware < 0.02:
		return
	var c := Vector2(target.x * u, fy - 360.0 * u)
	draw_arc(c, 30.0 * u, 0, TAU, 28, Color(COL_INK, 0.5), 10.0 * u)
	draw_arc(c, 30.0 * u, -PI / 2.0, -PI / 2.0 + TAU * _aware, 28, COL_AMBER, 10.0 * u)
	draw_string(_font_d, c + Vector2(-9.0 * u, 11.0 * u), "?", HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(32 * u), COL_AMBER)


func _draw_ghost(g: Dictionary, u: float) -> void:
	var t := float(g["t"])
	var c := Vector2(float(g["x"]) * u, float(g["y"]) * u)
	var hold := str(g["kind"]) == "hold"
	var fade := clampf(1.6 - t, 0.0, 1.0)
	if t < 0.5:
		draw_arc(c, (24.0 + 70.0 * t) * u, 0, TAU, 24, Color(1, 1, 1, 0.8 - t), 4.0 * u)
	draw_circle(c, 16.0 * u, Color(1, 1, 1, 0.85 * fade))
	if hold:
		draw_arc(c, 26.0 * u, -PI / 2.0, -PI / 2.0 + TAU * clampf(t / 1.2, 0.0, 1.0), 24,
			Color(COL_GOLD, fade), 5.0 * u)
	if fade > 0.0:
		draw_string(_font_b, c + Vector2(-160.0 * u, -34.0 * u), str(g["label"]),
			HORIZONTAL_ALIGNMENT_CENTER, 320.0 * u, int(20 * u), Color(COL_TEXT, fade))


func _draw_hud(vs: Vector2, u: float) -> void:
	# act card + caption + Stalls
	draw_string(_font_b, Vector2(110.0 * u, 92.0 * u), "GAMEPLAY SAMPLE — baked cast in game staging",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * u), COL_DIM)
	draw_string(_font_d, Vector2(vs.x - 1010.0 * u, 150.0 * u), _caption.to_upper(),
		HORIZONTAL_ALIGNMENT_RIGHT, 900.0 * u, int(34 * u), COL_GOLD)
	var st := _t - _stalls_t
	if st < 1.4:
		var pop := 1.0 + 0.3 * clampf(1.0 - st * 3.0, 0.0, 1.0)
		draw_set_transform(Vector2(vs.x * 0.5, 300.0 * u), -0.04, Vector2(pop, pop))
		draw_string(_font_d, Vector2(-300.0 * u, 0), _stalls, HORIZONTAL_ALIGNMENT_CENTER,
			600.0 * u, int(64 * u), Color(COL_TEXT, clampf(2.0 - st * 1.6, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# applause meter
	var mc := Vector2(vs.x * 0.5 - 240.0 * u, 36.0 * u)
	draw_string(_font_b, mc + Vector2(0, 14.0 * u), "APPLAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(19 * u), COL_DIM)
	draw_rect(Rect2(mc + Vector2(120.0 * u, 0), Vector2(480.0 * u, 22.0 * u)), Color(COL_INK, 0.6))
	draw_rect(Rect2(mc + Vector2(120.0 * u, 0), Vector2(480.0 * u * _applause, 22.0 * u)), COL_GOLD)
	# action button (RIG): ring shows held progress; kept when released early (GDD)
	var ab := Vector2(vs.x - 190.0 * u, vs.y - 165.0 * u)
	draw_circle(ab, 86.0 * u, Color("#2B3460"))
	draw_arc(ab, 86.0 * u, 0, TAU, 40, Color("#3C4780"), 6.0 * u)
	var rc := Color("#4FA845") if _ring >= 0.99 else COL_GOLD
	if _ring > 0.01:
		draw_arc(ab, 72.0 * u, -PI / 2.0, -PI / 2.0 + TAU * _ring, 40, rc, 12.0 * u)
	_draw_spanner(ab, u, Color("#8E97BF") if _rigged else COL_TEXT)
	draw_string(_font_b, ab + Vector2(-80.0 * u, 122.0 * u), "RIG", HORIZONTAL_ALIGNMENT_CENTER,
		160.0 * u, int(20 * u), COL_DIM)
	# FREEZE
	var fb := Vector2(vs.x - 456.0 * u, vs.y - 165.0 * u)
	draw_circle(fb, 70.0 * u, Color("#9FE3FF") if _freeze_on else Color("#2B3460"))
	draw_arc(fb, 70.0 * u, 0, TAU, 36, Color("#3C4780"), 6.0 * u)
	var fcol := COL_INK if _freeze_on else Color("#9FE3FF")
	for k in 3:
		var ang := float(k) * PI / 3.0
		draw_line(fb - Vector2(cos(ang), sin(ang)) * 34.0 * u,
			fb + Vector2(cos(ang), sin(ang)) * 34.0 * u, fcol, 7.0 * u)
	draw_string(_font_b, fb + Vector2(-80.0 * u, 106.0 * u), "FREEZE", HORIZONTAL_ALIGNMENT_CENTER,
		160.0 * u, int(20 * u), Color("#9FE3FF") if _freeze_on else COL_DIM)
	# Clarence
	var cb := Vector2(210.0 * u, vs.y - 165.0 * u)
	var cs := 1.18 if _clar_on else 1.0
	draw_circle(cb, 66.0 * u * cs, Color("#FFD23F"))
	for k in 3:
		draw_circle(cb + Vector2((-16.0 + 16.0 * float(k)) * u, -62.0 * u * cs), 11.0 * u, Color("#E23B4E"))
	draw_circle(cb + Vector2(18.0 * u, -14.0 * u), 6.0 * u, COL_INK)
	draw_colored_polygon(PackedVector2Array([cb + Vector2(40.0 * u, -8.0 * u),
		cb + Vector2(66.0 * u, 2.0 * u), cb + Vector2(40.0 * u, 10.0 * u)]), Color("#F28C28"))
	if _clar_on:
		draw_arc(cb, 84.0 * u, 0, TAU, 32, COL_GOLD, 5.0 * u)
	draw_string(_font_b, cb + Vector2(-80.0 * u, 102.0 * u), "CLARENCE", HORIZONTAL_ALIGNMENT_CENTER,
		160.0 * u, int(20 * u), COL_DIM)


func _draw_spanner(c: Vector2, u: float, col: Color) -> void:
	draw_set_transform(c, -0.7, Vector2.ONE)
	draw_rect(Rect2(Vector2(-8.0 * u, -34.0 * u), Vector2(16.0 * u, 68.0 * u)), col)
	draw_arc(Vector2(0, -40.0 * u), 16.0 * u, 0.6, TAU - 0.6, 16, col, 9.0 * u)
	draw_arc(Vector2(0, 40.0 * u), 16.0 * u, PI + 0.6, PI - 0.6 + TAU, 16, col, 9.0 * u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
