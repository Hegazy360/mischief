## The staged Acts (res://proto/stage/show.gd): every Act timeline only uses verbs the show knows,
## names actors, clips, sequences, props, marks and layers that exist in its art layout and the cast
## sheets, and plays from curtain up to loop without a single script or engine error.
extends TestBase

const SHEETS := "res://proto/bakery/sheets/index.json"
const ACTS: Array[String] = ["res://proto/act1/act1.json", "res://proto/act2/act2.json", "res://proto/act3/act3.json",
	"res://proto/act4/act4.json", "res://proto/act5/act5.json"]
const SCENES: Array[String] = ["res://proto/act1/Act1.tscn", "res://proto/act2/Act2.tscn", "res://proto/act3/Act3.tscn",
	"res://proto/act4/Act4.tscn", "res://proto/act5/Act5.tscn"]
const VERBS: Array[String] = ["curtain", "hud", "show", "face", "clip", "move", "path", "say", "pop", "tap", "press",
	"ring", "freeze", "aware", "stamp", "unstamp", "prop", "seq", "dust", "cam", "spot", "squash", "lift", "rustle",
	"laugh", "shake", "stars", "confetti", "card", "uncard", "dark"]
const PASSES: Array[String] = ["shaft", "shadows", "stamps", "dust", "spot", "fx", "bubbles", "aware", "audience",
	"curtains", "card", "dark"]
const DRAW_ACT1: Array[String] = ["bg", "shaft", "seq:seq_door", "prop:butter", "shadows", "seq:seq_pedestal",
	"stamps", "actor:gus", "seq:seq_trophy", "actor:hush", "seq:seq_dumbbells", "seq:seq_glove", "fg:fg_plant",
	"dust", "spot", "fx", "bubbles", "aware", "audience", "curtains", "frame", "card"]


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _check_place(v: Variant, layout: Dictionary, where: String) -> void:
	if not v is String:
		return
	var s: String = (v as String).trim_prefix("@")
	for sep: String in ["+", "-"]:
		var i := s.rfind(sep)
		if i > 0:
			s = s.substr(0, i)
			break
	var known: bool = (layout.get("marks", {}) as Dictionary).has(s) or (layout.get("pivots", {}) as Dictionary).has(s)
	assert_true(known, "%s: unknown mark %s" % [where, v])


func test_timelines_name_only_what_exists() -> void:
	var cast: Dictionary = _json(SHEETS).get("cast", {})
	if not assert_false(cast.is_empty(), "cast sheets index missing"):
		return
	for path: String in ACTS:
		var tl := _json(path)
		if not assert_false(tl.is_empty(), "%s does not load" % path):
			continue
		var art := str(tl.get("art", "res://proto/act1/art/"))
		var layout := _json(art + "layout.json")
		if not assert_false(layout.is_empty(), "%s: no layout at %s" % [path, art]):
			continue
		var layers: Dictionary = layout.get("layers", {})
		var seqs: Dictionary = layout.get("seqs", {})
		var props: Array = tl.get("props", ["butter"])
		for p: Variant in props:
			assert_true(layers.has("prop_" + str(p)), "%s: prop %s has no layer" % [path, p])
		for p: Variant in tl.get("props_visible", []):
			assert_true(str(p) in props.map(func(x: Variant) -> String: return str(x)), "%s: visible prop %s not listed" % [path, p])
		for item: Variant in tl.get("draw", DRAW_ACT1):
			var s := str(item)
			var c := s.find(":")
			var kind := s.substr(0, c) if c > 0 else ""
			var arg := s.substr(c + 1) if c > 0 else s
			match kind:
				"seq", "seq0", "seq1":
					assert_true(seqs.has(arg), "%s: draw seq %s missing" % [path, arg])
				"prop":
					assert_true(arg in props.map(func(x: Variant) -> String: return str(x)), "%s: draw prop %s not in props" % [path, arg])
				"actor":
					assert_true((tl.get("start", {}) as Dictionary).has(arg), "%s: draw actor %s not started" % [path, arg])
				"fg":
					assert_true(layers.has(arg), "%s: fg layer %s missing" % [path, arg])
				_:
					assert_true(arg in PASSES or layers.has(arg), "%s: draw %s is neither a pass nor a layer" % [path, arg])
		var start: Dictionary = tl.get("start", {})
		for who: String in start:
			assert_true(cast.has(who), "%s: start actor %s has no sheets" % [path, who])
			_check_place((start[who] as Dictionary).get("x", 0), layout, path)
		var loop_at := float(tl.get("loop_at", 70.0))
		for e: Dictionary in tl.get("events", []):
			var where := "%s @%.2f %s" % [path.get_file(), float(e.get("t", -1)), e.get("do", "?")]
			assert_true(str(e.get("do", "")) in VERBS, "%s: unknown verb" % where)
			assert_true(float(e.get("t", -1)) >= 0.0 and float(e["t"]) < loop_at, "%s: time outside the Act" % where)
			var who := str(e.get("who", ""))
			if who != "":
				assert_true(start.has(who), "%s: unknown actor %s" % [where, who])
			var clips: Dictionary = (cast.get(who, {}) as Dictionary).get("clips", {})
			match str(e["do"]):
				"clip":
					assert_true(clips.has(str(e.get("name", ""))), "%s: no clip %s/%s" % [where, who, e.get("name")])
				"move":
					assert_true(clips.has(str(e.get("clip", ""))), "%s: no clip %s/%s" % [where, who, e.get("clip")])
					_check_place(e.get("to"), layout, where)
				"path":
					_check_place(e.get("to"), layout, where)
				"seq":
					assert_true(seqs.has("seq_" + str(e.get("name", ""))), "%s: no sequence %s" % [where, e.get("name")])
				"prop":
					assert_true(str(e.get("name", "")) in props.map(func(x: Variant) -> String: return str(x)), "%s: prop %s not listed" % [where, e.get("name")])
					if e.has("ride") and str(e["ride"]) != "":
						assert_true(start.has(str(e["ride"])), "%s: rides unknown actor %s" % [where, e["ride"]])
				"rustle":
					assert_true(layers.has(str(e.get("name", "fg_plant"))), "%s: rustles missing layer" % where)
				"spot", "stars", "squash", "lift", "face", "show", "say":
					assert_true(start.has(str(e.get("who", "hush"))), "%s: needs a known actor" % where)
			if e.has("at") and e["at"] is String:
				_check_place(e["at"], layout, where)


## Plays every Act from curtain up to its loop point through the real script, headless: every verb
## runs, nothing errors, and the show ends back at the start (the loop).
func test_acts_play_through() -> void:
	var fps := Engine.max_fps
	for path: String in SCENES:
		var packed: PackedScene = load(path)
		if not assert_true(packed != null, "%s does not load" % path):
			continue
		var show: Control = packed.instantiate()
		tree.root.add_child(show)
		var tl: Dictionary = show.get("_tl")
		assert_false(tl.is_empty(), "%s: no timeline" % path)
		var steps := int(float(tl.get("loop_at", 70.0)) * 60.0) + 2
		var max_ei := 0
		for i in steps:
			show._process(1.0 / 60.0)
			max_ei = maxi(max_ei, int(show.get("_ei")))
		assert_eq(max_ei, (tl.get("events", []) as Array).size(), "%s: every event applied" % path)
		assert_lt(float(show.get("_t")), 1.0, "%s: looped back to the start" % path)
		show.queue_free()
	Engine.max_fps = fps
