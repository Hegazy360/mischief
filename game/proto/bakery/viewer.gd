## BakeryViewer — the game's cast (Hush, Gus) baked from KayKit and played as a game would.
##
## Top: a stage scene (routine.json), one timeline per actor. Every clip switch is pinned on the feet
## anchor, locomotion travels at the ground speed the bake measured from the planted foot, actors
## mirror for direction, and both share one cast-wide scale. If feet slide, sizes pop or a body
## jumps at a switch, the bake is wrong — this scene exists to make that visible.
## Bottom: every clip of every character at its true timing, on one floor line per character.
##
## The whole runtime is still: advance a clock, pick a frame from the clip's durations, blit a region
## of a PNG. No rig, no IK, no springs.
extends Control

const SHEETS := "res://proto/bakery/sheets/"
const ROUTINE := "res://proto/bakery/routine.json"
## Gallery one-shots rest on their last frame this long before replaying.
const GALLERY_HOLD := 0.8
## Clips whose name starts with this are FREEZE statues (labelled as a family in the gallery).
const STATUE_PREFIX := "freeze_"
## Draw order on stage: first is furthest back.
const STAGE_ORDER := ["gus", "hush"]


## One performer on the stage, walking through its own list of steps.
class Actor:
	var who: String = ""
	var steps: Array = []
	var start_x: float = 0.5
	var start_dir: int = 1
	var step: int = 0
	var step_t: float = 0.0
	var step_len: float = 0.0
	var x: float = 0.0
	var dir: int = 1
	var cue: String = ""
	var done: bool = false


var _index: Dictionary = {}
var _tex: Dictionary = {}
var _actors: Array[Actor] = []
var _font_d: Font = null
var _font_b: Font = null
var _t: float = 0.0
var _stage_scale: float = 1.0
var _caption: String = ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#141A33"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_d = load("res://ui/theme/fonts/LilitaOne-Regular.ttf")
	_font_b = load("res://ui/theme/fonts/Nunito-Bold.ttf")
	_index = _load_json(SHEETS + "index.json")
	if _index.is_empty():
		push_error("no index.json — run: python3 tools/bakery/run.py")
		return
	for who: String in _cast():
		for name: String in _clips(who):
			var p := SHEETS + str((_clips(who)[name] as Dictionary)["sheet"])
			if ResourceLoader.exists(p):
				_tex[who + "/" + name] = load(p)
	var routine := _load_json(ROUTINE)
	var specs: Dictionary = routine.get("actors", {})
	for who: String in STAGE_ORDER:
		if not specs.has(who) or not _cast().has(who):
			continue
		var spec: Dictionary = specs[who]
		var a := Actor.new()
		a.who = who
		a.steps = spec.get("steps", [])
		a.start_x = float(spec.get("start_x", 0.5))
		a.start_dir = int(spec.get("dir", 1))
		_actors.append(a)
	_stage_scale = 1.35 * get_viewport_rect().size.y / 1080.0
	_restart_all()
	set_process(true)


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _cast() -> Dictionary:
	return _index.get("cast", {})


func _clips(who: String) -> Dictionary:
	return ((_cast().get(who, {}) as Dictionary).get("clips", {}))


func _clip(who: String, name: String) -> Dictionary:
	return _clips(who).get(name, {})


## Total screen time of a clip, from its per-frame durations.
func _length(info: Dictionary) -> float:
	var total := 0.0
	for d: Variant in (info.get("durations", []) as Array):
		total += float(d)
	return maxf(total, 0.05)


## Frame index at time `t`: loops wrap, one-shots stop on their last frame.
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


## Draw one frame with the clip's anchor (root on the floor) at `foot`. `flip` mirrors about the anchor.
func _blit(who: String, name: String, frame: int, foot: Vector2, s: float, flip: bool) -> void:
	var info := _clip(who, name)
	var key := who + "/" + name
	if info.is_empty() or not _tex.has(key):
		return
	var fw := float(info["frame_w"])
	var fh := float(info["frame_h"])
	var anc: Array = info.get("anchor", [fw * 0.5, fh])
	# sheets wrap into a grid (<= 4096 px a side, the phone texture limit): frame -> (col, row)
	var cols := maxi(1, int(info.get("cols", int(info.get("count", 1)))))
	var cell := Vector2(float(frame % cols) * fw, float(frame / cols) * fh)
	draw_set_transform(foot, 0.0, Vector2(-s if flip else s, s))
	draw_texture_rect_region(_tex[key], Rect2(Vector2(-float(anc[0]), -float(anc[1])), Vector2(fw, fh)),
		Rect2(cell, Vector2(fw, fh)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- the stage -------------------------------------------------------------------------------------

func _restart_all() -> void:
	var w := get_viewport_rect().size.x
	for a: Actor in _actors:
		a.x = w * a.start_x
		a.dir = a.start_dir
		a.step = -1
		a.done = false
		a.cue = ""
		_next_step(a)


func _faces(who: String) -> int:
	return int((_cast().get(who, {}) as Dictionary).get("faces", -1))


func _flip(a: Actor) -> bool:
	return a.dir != _faces(a.who)


func _next_step(a: Actor) -> void:
	var prev := ""
	if a.step >= 0 and a.step < a.steps.size():
		prev = str((a.steps[a.step] as Dictionary).get("clip", ""))
	if a.step + 1 >= a.steps.size():
		a.done = true          # hold the last step until every actor has finished
		return
	a.step += 1
	var st: Dictionary = a.steps[a.step]
	var info := _clip(a.who, str(st.get("clip", "idle")))
	if st.has("dir"):
		a.dir = int(st["dir"])
	if st.has("cue"):
		a.cue = str(st["cue"])
		_caption = a.cue
	# a clip baked to follow this one knows how far the body moved between the two library clips
	if str(info.get("follows", "")) == prev and info.has("enter_dx"):
		a.x -= float(info["enter_dx"]) * _stage_scale * (-1.0 if _flip(a) else 1.0)
	a.step_t = 0.0
	a.step_len = float(st["secs"]) if st.has("secs") else _length(info) + float(st.get("hold", 0.0))


func _process(delta: float) -> void:
	_t += delta
	var all_done := not _actors.is_empty()
	for a: Actor in _actors:
		a.step_t += delta
		if not a.done:
			var st: Dictionary = a.steps[a.step]
			var info := _clip(a.who, str(st.get("clip", "")))
			a.x += float(info.get("ground_speed_px", 0.0)) * _stage_scale * float(a.dir) * delta
			if a.step_t >= a.step_len:
				_next_step(a)
		all_done = all_done and a.done
	if all_done:
		_restart_all()
	queue_redraw()


# --- drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	var vs := get_viewport_rect().size
	if _index.is_empty():
		draw_string(_font_b, Vector2(40, 80), "no sheets — run:  python3 tools/bakery/run.py",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#FFD98A"))
		return
	var u := vs.y / 1080.0
	draw_string(_font_d, Vector2(40, 64) * u, "THE BAKERY — the cast",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * u), Color("#FFF4E0"))
	draw_string(_font_b, Vector2(40, 100) * u,
		"Hush and Gus Thudd, baked in headless Blender on CC0 KayKit bodies: library motion, composed statues (ice-blue) and reactions, built faces and props.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u), Color("#8E97BF"))
	_draw_stage(vs, u)
	_draw_gallery(vs, u)


func _draw_stage(vs: Vector2, u: float) -> void:
	var top := 130.0 * u
	var floor_y := 560.0 * u
	# a plain set: back wall, skirting, boards
	draw_rect(Rect2(0, top, vs.x, floor_y - top), Color("#2B3460"))
	draw_rect(Rect2(0, floor_y - 18.0 * u, vs.x, 18.0 * u), Color("#3C4780"))
	draw_rect(Rect2(0, floor_y, vs.x, 70.0 * u), Color("#5A3E2E"))
	draw_rect(Rect2(0, floor_y, vs.x, 4.0 * u), Color("#7A5640"))
	for a: Actor in _actors:
		# contact shadow: grounds the sprite more than any outline does
		draw_set_transform(Vector2(a.x, floor_y + 2.0 * u), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 52.0 * _stage_scale, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for a: Actor in _actors:
		var st: Dictionary = a.steps[a.step] if a.step >= 0 else {}
		var name := str(st.get("clip", "idle"))
		var info := _clip(a.who, name)
		_blit(a.who, name, _frame_at(info, a.step_t), Vector2(a.x, floor_y), _stage_scale, _flip(a))
		draw_string(_font_b, Vector2(a.x - 200.0 * u, floor_y + 52.0 * u), "%s · %s" % [a.who, name],
			HORIZONTAL_ALIGNMENT_CENTER, 400.0 * u, int(18 * u), Color("#E9D9C4"))
	draw_string(_font_d, Vector2(vs.x - 760.0 * u, top + 52.0 * u), _caption.to_upper(),
		HORIZONTAL_ALIGNMENT_RIGHT, 720.0 * u, int(36 * u), Color("#FFC93C"))


func _draw_gallery(vs: Vector2, u: float) -> void:
	var row := 0
	for who: String in STAGE_ORDER:
		var names: Array = _clips(who).keys()
		if names.is_empty():
			continue
		var floor_y := (790.0 + 205.0 * float(row)) * u
		var left := 230.0 * u
		var cell := (vs.x - left - 30.0 * u) / float(maxi(15, names.size()))
		var s := minf(0.6 * u, cell / 150.0)
		draw_string(_font_d, Vector2(30.0 * u, floor_y - 60.0 * u), str((_cast()[who] as Dictionary).get("label", who)).split(" — ")[0],
			HORIZONTAL_ALIGNMENT_LEFT, left - 40.0 * u, int(26 * u), Color("#FFC93C"))
		draw_line(Vector2(left, floor_y), Vector2(vs.x - 30.0 * u, floor_y), Color("#3C4780"), 2.0)
		for i in names.size():
			var name := str(names[i])
			var info := _clip(who, name)
			var cx := left + cell * (float(i) + 0.5)
			var t := _t
			if not bool(info.get("loop", false)):
				t = fmod(_t, _length(info) + GALLERY_HOLD)
			_blit(who, name, _frame_at(info, t), Vector2(cx, floor_y), s, false)
			# FREEZE statues are a family: short name, own colour, so the row stays readable
			var statue := name.begins_with(STATUE_PREFIX)
			draw_string(_font_b, Vector2(cx - cell * 0.5, floor_y + 24.0 * u), name.trim_prefix(STATUE_PREFIX),
				HORIZONTAL_ALIGNMENT_CENTER, cell, int(17 * u), Color("#9FE3FF") if statue else Color("#FFF4E0"))
			draw_string(_font_b, Vector2(cx - cell * 0.5, floor_y + 43.0 * u),
				"%.2fs" % _length(info), HORIZONTAL_ALIGNMENT_CENTER, cell, int(14 * u), Color("#6E78A0"))
		row += 1
