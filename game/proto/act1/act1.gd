## Act1 — one complete scene of the game, staged on a set rendered in headless Blender.
##
## Gus Thudd's front room (tools/stage/act1_set.py -> art/), the baked cast (Hush, Gus), and one full
## Act scripted in act1.json: curtain up, three rigs (gramophone, trophy pedestal, butter), a FREEZE
## in plain sight, a Clarence lure, the slip-and-bonk chain, the gramophone finale, the bow, curtain
## down and the Applause card. Nothing on screen but the show and the game's own HUD.
##
## The runtime stays what the Bakery promised: advance a clock, pick frames, blit PNG regions.
extends Control

const ART := "res://proto/act1/art/"
const SHEETS := "res://proto/bakery/sheets/"
const TIMELINE := "res://proto/act1/act1.json"
## Baked sheets are drawn at this scale; the set was rendered to match (1 model unit = 128 px).
const CAST_SCALE := 1.6
const STAGE := Vector2(2400, 1080)

const COL_INK := Color("#2A2036")
const COL_GOLD := Color("#FFC93C")
const COL_CREAM := Color("#FFF4E0")
const COL_AMBER := Color("#FFB63C")
const COL_ICE := Color("#9FE3FF")
const COL_HUD := Color(0.08, 0.06, 0.12, 0.72)
const CONFETTI := [Color("#E23B4E"), Color("#FFC93C"), Color("#4FA845"), Color("#5AC8E0"), Color("#F27BB0")]


class Actor:
	var who: String = ""
	var x: float = 0.0
	var y: float = 0.0              # lift off the floor (flying)
	var dir: int = 1
	var clip: String = "idle"
	var t: float = 0.0
	var k: float = 1.0
	var hold_last: bool = false
	var target: float = INF
	var visible: bool = true
	var tween: Dictionary = {}      # scripted path: {x0, x1, arc, t, secs}
	var trail: Array = []           # recent positions while flying (motion smear)
	var squash: float = 0.0         # landing squash, decays


## A tweened value: from -> to over secs with an ease; read with _tv().
class Tw:
	var a: float = 0.0
	var b: float = 0.0
	var t: float = 0.0
	var secs: float = 0.0
	var ease: String = "out"


var _layout: Dictionary = {}
var _art: Dictionary = {}
var _index: Dictionary = {}
var _sheets: Dictionary = {}
var _tl: Dictionary = {}
var _events: Array = []
var _ei: int = 0
var _t: float = 0.0
var _actors: Dictionary = {}
var _font_d: Font = null
var _font_b: Font = null
var _bubble_box: StyleBoxFlat = null

# show state
var _curtain: Tw = Tw.new()          # 0 = closed, 1 = open
var _card: float = 0.0               # applause card visibility
var _card_t: float = 0.0
var _hud: Tw = Tw.new()
var _applause: Tw = Tw.new()
var _say: Dictionary = {}            # who -> {text, t, secs}
var _pops: Array = []                # {x, y, text, t, secs, kind}
var _taps: Array = []                # {x, y, t}
var _press: Dictionary = {}          # button -> seconds left lit
var _ring: Tw = Tw.new()             # RIG progress
var _freeze: bool = false
var _aware: Tw = Tw.new()
var _stamps: Array = []              # [x, y]
var _props: Dictionary = {}          # name -> {x, y, rot, vis, path}
var _laugh_t: float = -10.0
var _laugh_amp: float = 0.0
var _shake: Tw = Tw.new()
var _stars: Dictionary = {}          # who -> seconds left
var _confetti_t: float = -10.0
var _seq: Dictionary = {}            # name -> {f: Tw, vis: bool}
var _dust: Array = []                # {x, y, s, t}
var _cam_z: Tw = Tw.new()            # camera zoom (1 = the whole proscenium)
var _cam_x: Tw = Tw.new()            # camera focus, stage px
var _cam_y: Tw = Tw.new()
var _spot: Tw = Tw.new()             # bow spotlight strength 0..1
var _spot_who: String = "hush"
var _rustle_t: float = -10.0
## Captures pass --fixed-step: every rendered frame advances the show exactly 1/60 s, so frame N
## is always second N/60 whatever the capture machine's frame rate.
var _fixed_step: bool = false


func _ready() -> void:
	# a virtual display can run unthrottled; the show runs on a 60 fps clock everywhere
	Engine.max_fps = 60
	_fixed_step = "--fixed-step" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color("#120D18"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_d = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
	_font_b = load("res://ui/theme/fonts/Nunito-Bold.ttf")
	_layout = _load_json(ART + "layout.json")
	_index = _load_json(SHEETS + "index.json")
	_tl = _load_json(TIMELINE)
	if _layout.is_empty() or _index.is_empty() or _tl.is_empty():
		push_error("act1: missing art/sheets — run tools/stage/build.py and tools/bakery/run.py")
		return
	for name: String in (_layout["layers"] as Dictionary):
		var p := ART + str(_layout["layers"][name]["png"])
		if ResourceLoader.exists(p):
			_art[name] = load(p)
	for who: String in _cast():
		for clip: String in _clips(who):
			var p := SHEETS + str((_clips(who)[clip] as Dictionary)["sheet"])
			if ResourceLoader.exists(p):
				_sheets[who + "/" + clip] = load(p)
	_bubble_box = StyleBoxFlat.new()
	_bubble_box.bg_color = COL_CREAM
	_bubble_box.set_corner_radius_all(26)
	_bubble_box.border_color = COL_INK
	_bubble_box.set_border_width_all(4)
	_events = _tl.get("events", [])
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	_restart()
	# --start=SECONDS fast-forwards the show (captures and reviews of a single beat)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--start="):
			var until := float(arg.substr(8))
			while _t < until:
				_process(1.0 / 60.0)


func _restart() -> void:
	_t = 0.0
	_ei = 0
	_curtain = _tw(0.0)
	_hud = _tw(0.0)
	_applause = _tw(0.0)
	_ring = _tw(0.0)
	_aware = _tw(0.0)
	_shake = _tw(0.0)
	_cam_z = _tw(1.0)
	_cam_x = _tw(STAGE.x * 0.5)
	_cam_y = _tw(STAGE.y * 0.5)
	_spot = _tw(0.0)
	_rustle_t = -10.0
	_dust.clear()
	_seq.clear()
	for name: String in (_layout.get("seqs", {}) as Dictionary):
		_seq[name] = {"f": _tw(0.0), "vis": not name in ["seq_glove", "fxs_dust"]}
	_card = 0.0
	_freeze = false
	_say.clear()
	_pops.clear()
	_taps.clear()
	_press.clear()
	_stamps.clear()
	_stars.clear()
	_laugh_t = -10.0
	_confetti_t = -10.0
	_props.clear()
	for name: String in ["butter"]:
		_props[name] = {"dx": 0.0, "dy": 0.0, "rot": 0.0, "vis": false, "path": {}}
	_actors.clear()
	for who: String in (_tl.get("start", {}) as Dictionary):
		var st: Dictionary = _tl["start"][who]
		var a := Actor.new()
		a.who = who
		a.x = _x(st.get("x", 0))
		a.dir = int(st.get("dir", 1))
		a.clip = str(st.get("clip", "idle"))
		a.visible = bool(st.get("visible", true))
		_actors[who] = a


# --- data -----------------------------------------------------------------------------------------
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


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


## A position in stage px: a number, or "@mark" / "@mark+40" from layout.json.
func _x(v: Variant) -> float:
	if v is String:
		var s: String = v
		var off := 0.0
		for sep: String in ["+", "-"]:
			var i := s.rfind(sep)
			if i > 1:
				off = float(s.substr(i)) if sep == "+" else -float(s.substr(i + 1))
				s = s.substr(0, i)
				break
		var key := s.trim_prefix("@")
		var m: Dictionary = _layout.get("marks", {})
		var p: Dictionary = _layout.get("pivots", {})
		var pt: Array = m.get(key, p.get(key, [0, 0]))
		return float(pt[0]) + off
	return float(v)


func _piv(name: String) -> Vector2:
	var p: Array = (_layout.get("pivots", {}) as Dictionary).get(name, [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func _mark(name: String) -> Vector2:
	var p: Array = (_layout.get("marks", {}) as Dictionary).get(name, [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func _tw(v: float) -> Tw:
	var w := Tw.new()
	w.a = v
	w.b = v
	return w


func _go(w: Tw, to: float, secs: float, ease: String = "out") -> void:
	w.a = _tv(w)
	w.b = to
	w.t = 0.0
	w.secs = maxf(secs, 0.001)
	w.ease = ease


func _tv(w: Tw) -> float:
	var s := clampf(w.t / w.secs, 0.0, 1.0) if w.secs > 0.0 else 1.0
	match w.ease:
		"out":
			s = 1.0 - pow(1.0 - s, 3.0)
		"inout":
			s = s * s * (3.0 - 2.0 * s)
		"back":
			s = 1.0 + 2.2 * pow(s - 1.0, 3.0) + 1.2 * pow(s - 1.0, 2.0)
	return lerpf(w.a, w.b, s)


# --- the timeline -----------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _tl.is_empty():
		return
	if _fixed_step:
		delta = 1.0 / 60.0
	_t += delta
	while _ei < _events.size() and float(_events[_ei]["t"]) <= _t:
		_apply(_events[_ei])
		_ei += 1
	if _t >= float(_tl.get("loop_at", 70.0)):
		_restart()
		return
	for w: Tw in [_curtain, _hud, _applause, _ring, _aware, _shake, _cam_z, _cam_x, _cam_y, _spot]:
		w.t += delta
	for sq: Dictionary in _seq.values():
		(sq["f"] as Tw).t += delta
	for d: Dictionary in _dust:
		d["t"] = float(d["t"]) + delta
	_dust = _dust.filter(func(d: Dictionary) -> bool: return float(d["t"]) < 0.6)
	for who: String in _actors:
		_advance(_actors[who], delta)
	for name: String in _props:
		_advance_prop(_props[name], delta)
	for d: Dictionary in _say.values():
		d["t"] = float(d["t"]) + delta
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["secs"]))
	for p: Dictionary in _taps:
		p["t"] = float(p["t"]) + delta
	_taps = _taps.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.6)
	for b: String in _press.keys():
		_press[b] = float(_press[b]) - delta
	for w: String in _stars.keys():
		_stars[w] = float(_stars[w]) - delta
	if _card > 0.0:
		_card_t += delta
	queue_redraw()


func _apply(e: Dictionary) -> void:
	var a: Actor = _actors.get(str(e.get("who", "")))
	match str(e["do"]):
		"curtain":
			_go(_curtain, 1.0 if bool(e["open"]) else 0.0, float(e.get("secs", 2.0)), "inout")
		"hud":
			_go(_hud, 1.0 if bool(e["on"]) else 0.0, 0.5)
		"show":
			a.visible = bool(e.get("on", true))
			if e.has("x"):
				a.x = _x(e["x"])
		"face":
			a.dir = int(e["dir"])
		"clip":
			_set_clip(a, str(e["name"]), float(e.get("k", 1.0)))
			a.hold_last = bool(e.get("hold", false))
			a.target = INF
			if e.has("dir"):
				a.dir = int(e["dir"])
		"move":
			_set_clip(a, str(e["clip"]), float(e.get("k", 1.0)))
			a.target = _x(e["to"])
			a.dir = 1 if a.target > a.x else -1
			a.hold_last = false
		"path":
			# scripted travel (slides, flights): x0 -> x1 with an arc, clip unchanged
			a.tween = {"x0": a.x, "x1": _x(e["to"]), "arc": float(e.get("arc", 0.0)), "t": 0.0,
				"secs": float(e.get("secs", 1.0))}
		"say":
			_say[str(e["who"])] = {"text": str(e["text"]), "t": 0.0, "secs": float(e.get("secs", 2.2))}
		"pop":
			var at := _pop_at(e)
			_pops.append({"x": at.x, "y": at.y, "text": str(e.get("text", "")), "t": 0.0,
				"secs": float(e.get("secs", 1.0)), "kind": str(e.get("kind", "burst"))})
		"tap":
			var at := _pop_at(e)
			_taps.append({"x": at.x, "y": at.y, "t": 0.0})
		"press":
			_press[str(e["button"])] = float(e.get("secs", 0.35))
		"ring":
			_go(_ring, float(e.get("to", 1.0)), float(e.get("secs", 1.0)), "lin")
		"freeze":
			_freeze = bool(e["on"])
		"aware":
			_go(_aware, float(e.get("to", 0.0)), float(e.get("secs", 1.0)), "lin")
		"stamp":
			var p := _pop_at(e)
			_stamps.append([p.x, p.y])
		"unstamp":
			_stamps.clear()
		"prop":
			var pr: Dictionary = _props[str(e["name"])]
			if e.has("vis"):
				pr["vis"] = bool(e["vis"])
			if e.has("rot") or e.has("dx") or e.has("dy"):
				pr["path"] = {"r0": float(pr["rot"]), "r1": float(e.get("rot", pr["rot"])),
					"x0": float(pr["dx"]), "x1": float(e.get("dx", pr["dx"])),
					"y0": float(pr["dy"]), "y1": float(e.get("dy", pr["dy"])),
					"arc": float(e.get("arc", 0.0)), "bounce": float(e.get("bounce", 0.0)),
					"t": 0.0, "secs": float(e.get("secs", 0.5)), "ease": str(e.get("ease", "in"))}
		"seq":
			# play a Blender-baked sequence toward frame `to` (frames stay in place on the stage)
			var sq: Dictionary = _seq.get("seq_" + str(e["name"]), {})
			if sq.is_empty():
				push_warning("act1: no sequence %s" % e["name"])
				return
			if e.has("vis"):
				sq["vis"] = bool(e["vis"])
			if e.has("from"):
				sq["f"] = _tw(float(e["from"]))
			_go(sq["f"], float(e.get("to", 0)), float(e.get("secs", 0.5)), str(e.get("ease", "lin")))
		"dust":
			var at := _pop_at(e)
			_dust.append({"x": at.x, "y": at.y, "s": float(e.get("s", 1.0)), "t": 0.0})
		"cam":
			var secs := float(e.get("secs", 1.0))
			var ez := str(e.get("ease", "inout"))
			_go(_cam_z, float(e.get("zoom", 1.0)), secs, ez)
			var f := _pop_at(e) if (e.has("who") or e.has("at") or e.has("x")) else STAGE * 0.5
			_go(_cam_x, f.x, secs, ez)
			_go(_cam_y, f.y, secs, ez)
		"spot":
			_spot_who = str(e.get("who", _spot_who))
			_go(_spot, float(e.get("to", 0.0)), float(e.get("secs", 0.6)), "inout")
		"squash":
			a.squash = float(e.get("amount", 0.2))
		"rustle":
			_rustle_t = _t
		"laugh":
			_laugh_t = _t
			_laugh_amp = float(e.get("amp", 1.0))
			_go(_applause, minf(1.0, _tv(_applause) + float(e.get("add", 0.0))), 0.9)
			if e.has("text"):
				_pops.append({"x": STAGE.x * 0.5 + float(e.get("dx", 0.0)), "y": 930.0, "text": str(e["text"]),
					"t": 0.0, "secs": 1.6, "kind": "stalls"})
		"shake":
			_shake = _tw(float(e.get("amp", 14.0)))
			_go(_shake, 0.0, float(e.get("secs", 0.4)), "out")
		"stars":
			_stars[str(e["who"])] = float(e.get("secs", 3.0))
		"confetti":
			_confetti_t = _t
		"card":
			_card = 1.0
			_card_t = 0.0
		"uncard":
			_card = 0.0


func _pop_at(e: Dictionary) -> Vector2:
	if e.has("who"):
		var a: Actor = _actors[str(e["who"])]
		return Vector2(a.x + float(e.get("dx", 0.0)), _floor() - a.y + float(e.get("dy", -330.0)))
	if e.has("at"):
		var name := str(e["at"])
		var p := _mark(name) if (_layout.get("marks", {}) as Dictionary).has(name) else _piv(name)
		return p + Vector2(float(e.get("dx", 0.0)), float(e.get("dy", 0.0)))
	return Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))


func _floor() -> float:
	return float(_layout.get("floor_px", 880.0))


func _set_clip(a: Actor, name: String, k: float) -> void:
	if a == null or not _clips(a.who).has(name):
		push_warning("act1: no clip %s/%s" % [a.who if a else "?", name])
		return
	var info := _clip(a.who, name)
	if str(info.get("follows", "")) == a.clip:
		# a chained clip starts where the body ended (knocked -> getup)
		var flip := a.dir * int((_cast()[a.who] as Dictionary).get("faces", 1)) < 0
		a.x -= float(info.get("enter_dx", 0.0)) * CAST_SCALE * (-1.0 if flip else 1.0)
	a.clip = name
	a.t = 0.0
	a.k = k


func _advance(a: Actor, delta: float) -> void:
	a.t += delta * a.k
	a.squash = move_toward(a.squash, 0.0, delta * 1.2)
	if not a.tween.is_empty():
		a.trail.push_front(Vector2(a.x, a.y))
		if a.trail.size() > 6:
			a.trail.pop_back()
	elif not a.trail.is_empty():
		a.trail.pop_back()
	var info := _clip(a.who, a.clip)
	if not a.tween.is_empty():
		var tw := a.tween
		tw["t"] = float(tw["t"]) + delta
		var s := clampf(float(tw["t"]) / float(tw["secs"]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - s, 2.0)
		a.x = lerpf(float(tw["x0"]), float(tw["x1"]), e)
		a.y = float(tw["arc"]) * 4.0 * s * (1.0 - s)
		if s >= 1.0:
			a.tween = {}
			a.y = 0.0
	elif a.target != INF:
		# feet stay planted: travel at the bake's measured ground speed x the clip's time multiplier
		var sp := float(info.get("ground_speed_px", 60.0)) * a.k * CAST_SCALE
		a.x = move_toward(a.x, a.target, sp * delta)
		if is_equal_approx(a.x, a.target):
			a.target = INF
			_set_clip(a, "idle", 1.0)
	elif not bool(info.get("loop", false)) and not a.hold_last and a.t > _length(info) + 0.15:
		_set_clip(a, "idle", 1.0)


func _advance_prop(pr: Dictionary, delta: float) -> void:
	var p: Dictionary = pr["path"]
	if p.is_empty():
		return
	p["t"] = float(p["t"]) + delta
	var s := clampf(float(p["t"]) / float(p["secs"]), 0.0, 1.0)
	var e := s * s if str(p["ease"]) == "in" else 1.0 - pow(1.0 - s, 2.0)
	pr["rot"] = lerpf(float(p["r0"]), float(p["r1"]), e)
	pr["dx"] = lerpf(float(p["x0"]), float(p["x1"]), s)
	pr["dy"] = lerpf(float(p["y0"]), float(p["y1"]), e) - float(p["arc"]) * 4.0 * s * (1.0 - s)
	if s >= 1.0:
		var bounce := float(p["bounce"])
		if bounce > 1.0:
			# one small hop where it lands, then rest
			pr["path"] = {"r0": pr["rot"], "r1": float(pr["rot"]) + 12.0, "x0": pr["dx"],
				"x1": float(pr["dx"]) + bounce * 0.4, "y0": pr["dy"], "y1": pr["dy"], "arc": bounce,
				"bounce": 0.0, "t": 0.0, "secs": 0.32, "ease": "out"}
		else:
			pr["path"] = {}


# --- drawing --------------------------------------------------------------------------------------
func _draw() -> void:
	if _layout.is_empty():
		draw_string(_font_b, Vector2(40, 80), "act1: run tools/stage/build.py", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_GOLD)
		return
	var vs := get_viewport_rect().size
	_unxform()
	_layer("bg")
	_draw_shaft()
	_draw_seq("seq_door")
	_draw_prop("butter")
	_draw_shadows()
	_draw_seq("seq_pedestal")
	for st: Array in _stamps:
		_icon("icon_stamp", Vector2(float(st[0]), float(st[1])), 0.32, 0.0)
	var gus: Actor = _actors["gus"]
	var hush: Actor = _actors["hush"]
	_draw_actor(gus)
	_draw_seq("seq_trophy")
	_draw_actor(hush)
	_draw_seq("seq_dumbbells")
	_draw_seq("seq_glove")
	_draw_plant()
	_draw_dust()
	_draw_spot()
	_draw_fx()
	_draw_bubbles()
	_draw_aware(hush)
	_layer("audience", Vector2(0, _crowd_bob()))
	_draw_curtains()
	_layer("frame")
	_draw_card()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud(vs, get_viewport_rect().size.y / STAGE.y)


func _draw_seq(name: String) -> void:
	var sq: Dictionary = _seq.get(name, {})
	if sq.is_empty() or not bool(sq["vis"]):
		return
	var frames: Array = _layout["seqs"][name]
	var i := clampi(int(round(_tv(sq["f"]))), 0, frames.size() - 1)
	_layer(str(frames[i]))


func _draw_shaft() -> void:
	var tex: Texture2D = _art.get("fx_shaft")
	if tex == null:
		return
	var L: Dictionary = _layout["layers"]["fx_shaft"]
	var pos := Vector2(float(L["pos"][0]), float(L["pos"][1]))
	var breathe := 0.85 + 0.15 * sin(_t * 0.7)
	draw_texture(tex, pos, Color(1, 1, 1, breathe))
	# dust motes drifting in the light
	var sz := Vector2(float(L["size"][0]), float(L["size"][1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var fx := rng.randf()
		var fy := rng.randf()
		var sp := rng.randf_range(0.01, 0.03)
		var y := fposmod(fy - _t * sp, 1.0)
		var x := fx + 0.04 * sin(_t * 0.6 + float(i))
		# the beam slants: shift with depth so the motes stay inside it
		var p := pos + Vector2((x * 0.7 + 0.15 + (1.0 - y) * 0.15) * sz.x, y * sz.y)
		draw_circle(p, 2.0 + 1.5 * fmod(float(i) * 0.37, 1.0), Color(1.0, 0.97, 0.85, 0.55 * breathe))


func _draw_plant() -> void:
	var tex: Texture2D = _art.get("fg_plant")
	if tex == null:
		return
	var L: Dictionary = _layout["layers"]["fg_plant"]
	var pos := Vector2(float(L["pos"][0]), float(L["pos"][1]))
	var base := pos + Vector2(float(L["size"][0]) * 0.5, float(L["size"][1]))
	var rt := _t - _rustle_t
	var sway := 0.0
	if rt < 0.9:
		sway = sin(rt * 28.0) * 0.035 * (1.0 - rt / 0.9)
	# leaves shake about the pot: a skew anchored at the base
	var xf := Transform2D(Vector2(_u(), 0), Vector2(-sway * _u(), _u()), _off() + base * _u())
	draw_set_transform_matrix(xf)
	draw_texture(tex, pos - base)
	_unxform()


func _draw_dust() -> void:
	var frames: Array = (_layout.get("seqs", {}) as Dictionary).get("fxs_dust", [])
	if frames.is_empty():
		return
	var canvas: Dictionary = _layout.get("fx_canvas", {"size": 256, "units": 4.0})
	var px_unit := float(canvas["size"]) / float(canvas["units"])
	var k := float(_layout.get("px_per_unit", 128.0)) / px_unit
	for d: Dictionary in _dust:
		var i := clampi(int(float(d["t"]) / 0.6 * float(frames.size())), 0, frames.size() - 1)
		var name := str(frames[i])
		var tex: Texture2D = _art.get(name)
		var L: Dictionary = _layout["layers"][name]
		var s := k * float(d["s"])
		_xform(Vector2(float(d["x"]), float(d["y"])), 0.0, s)
		# canvas anchor: world (0,0) sits at (size/2, size*3/4)
		draw_texture(tex, Vector2(float(L["pos"][0]), float(L["pos"][1])) - Vector2(float(canvas["size"]) * 0.5, float(canvas["size"]) * 0.75),
			Color(1, 1, 1, 0.85))
		_unxform()


func _draw_spot() -> void:
	var a := _tv(_spot)
	if a < 0.01:
		return
	var who: Actor = _actors[_spot_who]
	var c := Vector2(who.x, _floor() - 150.0)
	var r0 := 230.0
	var r1 := 420.0
	var col := Color(0.03, 0.01, 0.05, 0.62 * a)
	var clear := Color(col, 0.0)
	var n := 48
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := Vector2(cos(a0), sin(a0) * 1.15)
		var d1 := Vector2(cos(a1), sin(a1) * 1.15)
		draw_polygon(PackedVector2Array([c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1]),
			PackedColorArray([clear, clear, col, col]))
		draw_colored_polygon(PackedVector2Array([c + d0 * r1, c + d1 * r1, c + d1 * 4000.0, c + d0 * 4000.0]), col)
	# a warm pool on the boards
	_ellipse(Vector2(who.x, _floor() + 6.0), 210.0, 34.0, Color(1.0, 0.9, 0.6, 0.18 * a))


func _layer(name: String, d: Vector2 = Vector2.ZERO) -> void:
	var tex: Texture2D = _art.get(name)
	if tex == null:
		return
	var L: Dictionary = _layout["layers"][name]
	draw_texture(tex, Vector2(float(L["pos"][0]), float(L["pos"][1])) + d)


func _draw_prop(name: String) -> void:
	var pr: Dictionary = _props.get(name, {})
	if pr.is_empty() or not bool(pr["vis"]):
		return
	var lname := "prop_" + name
	var tex: Texture2D = _art.get(lname)
	if tex == null:
		return
	var L: Dictionary = _layout["layers"][lname]
	var pos := Vector2(float(L["pos"][0]), float(L["pos"][1]))
	var piv := _piv(name)
	var at := piv + Vector2(float(pr["dx"]), float(pr["dy"]))
	_xform(at, deg_to_rad(float(pr["rot"])), 1.0)
	draw_texture(tex, pos - piv)
	_unxform()


func _draw_shadows() -> void:
	var fy := _floor()
	for who: String in _actors:
		var a: Actor = _actors[who]
		if not a.visible:
			continue
		var w := (62.0 if who == "gus" else 46.0) * (1.0 - clampf(a.y / 600.0, 0.0, 0.6))
		var lying := a.clip in ["knocked", "getup"] and a.t > 0.5
		var wx := w * (2.4 if lying else 1.6)
		for k in 3:
			var f := 1.0 - float(k) * 0.28
			_ellipse(Vector2(a.x, fy + 4.0), wx * (1.0 + 0.25 * float(k)), w * 0.3 * (1.0 + 0.25 * float(k)), Color(0.12, 0.05, 0.08, 0.16 * f))


func _draw_actor(a: Actor) -> void:
	if not a.visible:
		return
	var info := _clip(a.who, a.clip)
	var tex: Texture2D = _sheets.get(a.who + "/" + a.clip)
	if info.is_empty() or tex == null:
		return
	var fw := float(info.get("frame_w", 64))
	var fh := float(info.get("frame_h", 64))
	var cols := maxi(1, int(info.get("cols", int(info.get("count", 1)))))
	var fr := _frame_at(info, a.t)
	var cell := Vector2(float(fr % cols) * fw, float(fr / cols) * fh)
	var anc: Array = info.get("anchor", [fw * 0.5, fh])
	var flip := a.dir * int((_cast()[a.who] as Dictionary).get("faces", 1)) < 0
	var src := Rect2(cell, Vector2(fw, fh))
	var dst := Rect2(Vector2(-float(anc[0]), -float(anc[1])), Vector2(fw, fh))
	# motion smear while flying: fading copies along the path
	for i in range(a.trail.size() - 1, 0, -1):
		var p: Vector2 = a.trail[i]
		draw_set_transform(_off() + Vector2(p.x, _floor() - p.y) * _u(), 0.0, Vector2(-1.0 if flip else 1.0, 1.0) * CAST_SCALE * _u())
		draw_texture_rect_region(tex, dst, src, Color(1, 0.95, 0.85, 0.22 * (1.0 - float(i) / 6.0)))
	var foot := Vector2(a.x, _floor() - a.y)
	# landing squash: wider and shorter for a beat, about the feet
	var sq := 1.0 + a.squash * sin(minf(1.0, a.squash * 5.0) * PI * 0.5)
	draw_set_transform(_off() + foot * _u(), 0.0, Vector2((-1.0 if flip else 1.0) * sq, 1.0 / sq) * CAST_SCALE * _u())
	# a warm tint so the cast sits in the room's lamp light
	draw_texture_rect_region(tex, dst, src, Color(1.0, 0.97, 0.92))
	_unxform()
	if _freeze and a.who == "hush":
		var g := 0.5 + 0.5 * sin(_t * 6.0)
		_ellipse(Vector2(a.x, _floor() + 4.0), 92.0 + 6.0 * g, 18.0, Color(COL_ICE, 0.35 + 0.2 * g))


func _draw_fx() -> void:
	for p: Dictionary in _pops:
		var s := float(p["t"]) / float(p["secs"])
		var at := Vector2(float(p["x"]), float(p["y"]))
		match str(p["kind"]):
			"burst":
				var sc := (0.55 + 0.35 * clampf(s * 6.0, 0.0, 1.0)) * (1.0 - clampf((s - 0.75) * 4.0, 0.0, 1.0))
				_icon("icon_burst", at, sc * 1.1, 0.12 * sin(_t * 9.0))
				_text_c(str(p["text"]), at + Vector2(0, 16.0 * sc), int(46.0 * sc), COL_INK, Color(0, 0, 0, 0))
			"q":
				var sc2 := clampf(s * 8.0, 0.0, 1.0) * (1.0 - clampf((s - 0.85) * 7.0, 0.0, 1.0))
				_text_c(str(p["text"]), at - Vector2(0, 20.0 * s), int(110.0 * sc2), COL_AMBER, COL_INK)
			"stalls":
				var rise := at - Vector2(0, 140.0 * s)
				var al := 1.0 - clampf((s - 0.6) * 2.5, 0.0, 1.0)
				_text_c(str(p["text"]), rise, int(78.0 * minf(1.0, s * 7.0)), Color(COL_GOLD, al), Color(COL_INK, al))
	# dazed stars orbiting a head
	for who: String in _stars:
		if float(_stars[who]) <= 0.0:
			continue
		var a: Actor = _actors[who]
		var head := Vector2(a.x, _floor() - a.y - (110.0 if a.clip in ["knocked"] else 330.0))
		for i in 4:
			var ang := _t * 5.0 + TAU * float(i) / 4.0
			_icon("icon_star", head + Vector2(cos(ang) * 80.0, sin(ang) * 22.0), 0.18, ang)
	# confetti from the flies (deterministic)
	var ct := _t - _confetti_t
	if ct < 4.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		for i in 90:
			var x0 := rng.randf_range(120.0, 2280.0)
			var sp := rng.randf_range(180.0, 320.0)
			var y := -40.0 + sp * (ct - rng.randf_range(0.0, 0.8))
			if y < -30.0 or y > 1100.0:
				continue
			var x := x0 + sin(ct * 3.0 + float(i)) * 30.0
			_xform(Vector2(x, y), ct * 4.0 + float(i), 1.0)
			draw_rect(Rect2(-8, -5, 16, 10), CONFETTI[i % CONFETTI.size()])
			_unxform()


func _draw_bubbles() -> void:
	for who: String in _say:
		var d: Dictionary = _say[who]
		var t := float(d["t"])
		var secs := float(d["secs"])
		if t > secs:
			continue
		var a: Actor = _actors[who]
		var text := str(d["text"])
		var fs := 34
		var tw := _font_b.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pop := clampf(t * 8.0, 0.0, 1.0) * (1.0 - clampf((t - secs + 0.2) * 5.0, 0.0, 1.0))
		var head := Vector2(clampf(a.x, 300.0, 2100.0), _floor() - a.y - (430.0 if who == "gus" else 330.0))
		var r := Rect2(head - Vector2(tw * 0.5 + 30.0, 78.0), Vector2(tw + 60.0, 70.0))
		_xform(head, 0.0, pop)
		var rr := Rect2(r.position - head, r.size)
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -12), Vector2(18, -12), Vector2(-2 - 20 * a.dir, 24)]), COL_INK)
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -14), Vector2(12, -14), Vector2(-2 - 18 * a.dir, 16)]), COL_CREAM)
		_bubble_box.draw(get_canvas_item(), rr)
		# typed out, ~45 characters a second: it reads as speech, not a caption
		var shown := text.substr(0, mini(text.length(), int(t * 45.0) + 1))
		draw_string(_font_b, rr.position + Vector2(30, 47), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_INK)
		_unxform()


func _draw_aware(h: Actor) -> void:
	var v := _tv(_aware)
	if v < 0.02:
		return
	var c := Vector2(h.x, _floor() - 330.0)
	draw_circle(c, 40.0, Color(COL_INK, 0.75))
	draw_arc(c, 34.0, -PI / 2.0, -PI / 2.0 + TAU * v, 36, COL_AMBER, 9.0, true)
	_text_c("?", c + Vector2(0, 16), 50, COL_AMBER, Color(0, 0, 0, 0))


func _draw_curtains() -> void:
	var open := _tv(_curtain)
	var frames: Array = (_layout.get("seqs", {}) as Dictionary).get("seq_curtain", [])
	if frames.is_empty():
		return
	if open < 0.999:
		_layer(str(frames[clampi(int(round(open * float(frames.size() - 1))), 0, frames.size() - 1)]))
	if open < 0.05 and _card <= 0.0 and _t < 10.0:
		var a := 1.0 - open * 20.0
		_text_c("MISCHIEF NEXT DOOR", Vector2(STAGE.x * 0.5, 470), 104, Color(COL_GOLD, a), Color(COL_INK, a))
		_text_c("Act I  ·  The Front Room", Vector2(STAGE.x * 0.5, 560), 46, Color(COL_CREAM, a), Color(COL_INK, a))


func _draw_card() -> void:
	if _card <= 0.0:
		return
	var t := _card_t
	var c := Vector2(STAGE.x * 0.5, 500)
	var pop := 0.85 + 0.15 * clampf(t * 4.0, 0.0, 1.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.06, 0.12, 0.9)
	box.set_corner_radius_all(36)
	box.border_color = COL_GOLD
	box.set_border_width_all(6)
	_xform(c, 0.0, pop)
	box.draw(get_canvas_item(), Rect2(-520, -260, 1040, 520))
	_unxform()
	_text_c("CURTAIN CALL", c + Vector2(0, -160) * pop, int(66 * pop), COL_GOLD, Color(0, 0, 0, 0))
	for i in 3:
		var st := clampf((t - 0.5 - 0.35 * float(i)) * 5.0, 0.0, 1.0)
		if st > 0.0:
			_icon("icon_star", c + Vector2(-200.0 + 200.0 * float(i), -10.0) * pop, 0.66 * (st + 0.3 * sin(st * PI)), 0.0)
	if t > 1.8:
		_text_c("STANDING OVATION!", c + Vector2(0, 170) * pop, int(60 * pop), COL_CREAM, Color(0, 0, 0, 0))


func _draw_hud(vs: Vector2, u: float) -> void:
	var h := _tv(_hud)
	if h < 0.01:
		return
	var al := h
	# Applause meter (top centre, under the valance)
	var mw := 640.0 * u
	var mc := Vector2(vs.x * 0.5, 64.0 * u)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(COL_HUD, 0.7 * al)
	back.set_corner_radius_all(int(22 * u))
	back.draw(get_canvas_item(), Rect2(mc - Vector2(mw * 0.5 + 50.0 * u, 26.0 * u), Vector2(mw + 100.0 * u, 52.0 * u)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(COL_GOLD, al)
	fill.set_corner_radius_all(int(14 * u))
	var v := _tv(_applause)
	if v > 0.01:
		fill.draw(get_canvas_item(), Rect2(mc - Vector2(mw * 0.5 - 30.0 * u, 13.0 * u), Vector2((mw - 40.0 * u) * v, 26.0 * u)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_hud_icon("icon_star", mc - Vector2(mw * 0.5 + 10.0 * u, 0), 0.32 * u * (1.0 + 0.25 * _laugh_pulse()), al)
	# buttons: Clarence (left thumb), FREEZE + RIG (right thumb)
	_button(Vector2(150.0 * u, vs.y - 120.0 * u), 80.0 * u, "icon_clarence", "clarence", al)
	_button(Vector2(vs.x - 340.0 * u, vs.y - 104.0 * u), 70.0 * u, "icon_freeze", "freeze", al)
	_button(Vector2(vs.x - 140.0 * u, vs.y - 124.0 * u), 88.0 * u, "icon_rig", "rig", al)
	for p: Dictionary in _taps:
		var s := float(p["t"]) / 0.6
		var at := _off() + Vector2(float(p["x"]), float(p["y"])) * u
		draw_arc(at, (22.0 + 60.0 * s) * u, 0, TAU, 32, Color(1, 1, 1, 0.9 * (1.0 - s)), 5.0 * u, true)
		draw_circle(at, 12.0 * u, Color(1, 1, 1, 0.7 * (1.0 - s)))


func _button(c: Vector2, r: float, icon: String, name: String, al: float) -> void:
	var lit := float(_press.get(name, 0.0)) > 0.0 or (name == "freeze" and _freeze)
	var sc := 1.12 if lit else 1.0
	var bg := COL_ICE if (name == "freeze" and _freeze) else Color(0.16, 0.12, 0.24)
	draw_circle(c, r * sc + 6.0, Color(COL_INK, 0.85 * al))
	draw_circle(c, r * sc, Color(bg, 0.92 * al))
	if name == "rig":
		var v := _tv(_ring)
		if v > 0.01:
			var col := Color("#5BD16B") if v >= 0.99 else COL_GOLD
			draw_arc(c, r * sc - 8.0, -PI / 2.0, -PI / 2.0 + TAU * v, 48, Color(col, al), 13.0, true)
	if lit and name != "freeze":
		draw_arc(c, r * sc + 14.0, 0, TAU, 48, Color(COL_GOLD, 0.8 * al), 6.0, true)
	_hud_icon(icon, c, r / 128.0 * 1.15 * sc, al)


func _hud_icon(name: String, c: Vector2, s: float, al: float) -> void:
	var tex: Texture2D = _art.get(name)
	if tex == null:
		return
	var sz := tex.get_size() * s
	draw_texture_rect(tex, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, al))


# --- helpers --------------------------------------------------------------------------------------
func _u() -> float:
	return get_viewport_rect().size.y / STAGE.y * _tv(_cam_z)


## The camera: zoom about a focus point (clamped so the frame never leaves the stage) + shake.
func _focus() -> Vector2:
	var z := maxf(1.0, _tv(_cam_z))
	var hx := STAGE.x * 0.5 / z
	var hy := STAGE.y * 0.5 / z
	return Vector2(clampf(_tv(_cam_x), hx, STAGE.x - hx), clampf(_tv(_cam_y), hy, STAGE.y - hy))


func _off() -> Vector2:
	var vs := get_viewport_rect().size
	var off := vs * 0.5 - _focus() * _u()
	var sh := _tv(_shake)
	if sh > 0.5:
		off += Vector2(sin(_t * 71.0), cos(_t * 53.0)) * sh * _u()
	return off


func _xform(at: Vector2, rot: float, s: float) -> void:
	draw_set_transform(_off() + at * _u(), rot, Vector2(s, s) * _u())


func _unxform() -> void:
	draw_set_transform(_off(), 0.0, Vector2(_u(), _u()))


func _icon(name: String, at: Vector2, s: float, rot: float) -> void:
	var tex: Texture2D = _art.get(name)
	if tex == null:
		return
	_xform(at, rot, s)
	draw_texture(tex, -tex.get_size() * 0.5)
	_unxform()


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(_off() + c * _u(), 0.0, Vector2(rx, ry) * _u())
	draw_circle(Vector2.ZERO, 1.0, col)
	_unxform()


func _text_c(text: String, at: Vector2, size: int, col: Color, outline: Color) -> void:
	if size < 2:
		return
	var w := _font_d.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5, 0)
	if outline.a > 0.0:
		draw_string_outline(_font_d, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 7), outline)
	draw_string(_font_d, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _crowd_bob() -> float:
	return -absf(sin(_t * 14.0)) * 12.0 * _laugh_pulse()


func _laugh_pulse() -> float:
	var lt := _t - _laugh_t
	return _laugh_amp * clampf(1.0 - lt / 1.8, 0.0, 1.0)
