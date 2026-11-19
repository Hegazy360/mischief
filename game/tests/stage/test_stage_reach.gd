## Reaches on the real stage (docs/research/animation.md, the stage Acts): every timeline beat that plays a
## baked reach clip (tools/bakery/clips.json `reach`, IK-solved in the Bakery) is played headless through the
## real show script, and at the clip's contact moment the hand — placed exactly as show.gd draws it
## (show.hand_point) — must land on the stage point the clip was baked for. Also checks the actor stands
## and faces where the bake assumed, and that the clip is still playing at contact (a later beat did not
## replace it). "mean" reaches (sawing) must centre their stroke on the target.
extends TestBase

const SHEETS := "res://proto/bakery/sheets/index.json"
const SCENES: Array[String] = ["res://proto/act1/Act1.tscn", "res://proto/act2/Act2.tscn", "res://proto/act3/Act3.tscn",
	"res://proto/act4/Act4.tscn", "res://proto/act5/Act5.tscn"]
## Stage px: a glove is ~30 across.
const TOL := 12.0
const STAND_TOL := 3.0


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _target(stage: Dictionary, layout: Dictionary) -> Vector2:
	if stage.has("at"):
		return Vector2(float(stage["at"][0]), float(stage["at"][1]))
	var m: Array = (layout.get("marks", {}) as Dictionary).get(str(stage.get("mark", "")), [0, 0])
	return Vector2(float(m[0]), float(m[1]))


func _length(info: Dictionary) -> float:
	var t := 0.0
	for d: Variant in (info.get("durations", []) as Array):
		t += float(d)
	return t


func test_every_reach_beat_lands_on_its_target() -> void:
	var cast: Dictionary = _json(SHEETS).get("cast", {})
	var fps := Engine.max_fps
	var checked := 0
	for path: String in SCENES:
		var show: Control = (load(path) as PackedScene).instantiate()
		tree.root.add_child(show)
		var tl: Dictionary = show.get("_tl")
		var layout: Dictionary = show.get("_layout")
		var checks: Array = []
		for e: Dictionary in (tl.get("events", []) as Array):
			if str(e.get("do", "")) != "clip":
				continue
			var who := str(e.get("who", ""))
			var info: Dictionary = (((cast.get(who, {}) as Dictionary).get("clips", {}) as Dictionary).get(str(e.get("name", "")), {}))
			var r: Dictionary = info.get("reach", {}) if info.get("reach") is Dictionary else {}
			if r.is_empty() or not (r.get("stage") is Dictionary):
				continue
			var mean := str(r.get("ref_at", "")) == "mean"
			var t0 := float(e["t"])
			checks.append({"who": who, "clip": str(e["name"]), "t0": t0, "mean": mean,
				"at": t0 + (0.0 if mean else float(r["ref_at"])) + 0.001, "until": t0 + _length(info),
				"hands": r["hands"], "stage": r["stage"], "target": _target(r["stage"], layout),
				"sum": Vector2.ZERO, "n": 0, "done": false})
		if checks.is_empty():
			show.queue_free()
			continue
		var last := 0.0
		for c: Dictionary in checks:
			last = maxf(last, float(c["until"]) if bool(c["mean"]) else float(c["at"]))
		while float(show.get("_t")) <= last + 0.05:
			show._process(1.0 / 60.0)
			var t := float(show.get("_t"))
			for c: Dictionary in checks:
				if bool(c["done"]):
					continue
				var a: Variant = (show.get("_actors") as Dictionary).get(c["who"])
				var where := "%s %s/%s @ %.2fs" % [path.get_file(), c["who"], c["clip"], float(c["t0"])]
				var playing := a != null and str(a.clip) == str(c["clip"])
				var mid := Vector2.ZERO
				if playing:
					for h: String in c["hands"]:
						mid += show.hand_point(str(c["who"]), h)
					mid /= float((c["hands"] as Array).size())
				if bool(c["mean"]):
					if t >= float(c["t0"]) and t < float(c["until"]) and playing:
						c["sum"] = (c["sum"] as Vector2) + mid
						c["n"] = int(c["n"]) + 1
						c["xmin"] = minf(float(c.get("xmin", INF)), float(a.x))
						c["xmax"] = maxf(float(c.get("xmax", -INF)), float(a.x))
					elif t >= float(c["until"]) or (t > float(c["t0"]) + 0.1 and not playing):
						c["done"] = true
						checked += 1
						if assert_gt(int(c["n"]), 0, "%s: never played" % where):
							var stx := float((c["stage"] as Dictionary)["stand"])
							assert_lt(maxf(absf(float(c["xmin"]) - stx), absf(float(c["xmax"]) - stx)), STAND_TOL,
								"%s: stands at %.0f..%.0f during the stroke, baked for %.0f" % [where, float(c["xmin"]), float(c["xmax"]), stx])
							var m := (c["sum"] as Vector2) / float(c["n"])
							assert_lt(m.distance_to(c["target"]), TOL, "%s: the stroke centres %.1f px from the target %s (at %s)" % [where, m.distance_to(c["target"]), c["target"], m])
				elif t >= float(c["at"]):
					c["done"] = true
					checked += 1
					if not assert_true(playing, "%s: the clip was replaced before its contact (%.2fs)" % [where, float(c["at"])]):
						continue
					var st: Dictionary = c["stage"]
					assert_lt(absf(float(a.x) - float(st["stand"])), STAND_TOL, "%s: stands at %.0f, baked for %.0f" % [where, float(a.x), float(st["stand"])])
					assert_eq(int(a.dir), int(st.get("dir", 1)), "%s: faces %d, baked for %d" % [where, int(a.dir), int(st.get("dir", 1))])
					assert_lt(mid.distance_to(c["target"]), TOL, "%s: the hand lands %.1f px from the target %s (at %s)" % [where, mid.distance_to(c["target"]), c["target"], mid])
		for c: Dictionary in checks:
			assert_true(bool(c["done"]), "%s %s/%s @ %.2fs: never reached its contact" % [path.get_file(), c["who"], c["clip"], float(c["t0"])])
		show.queue_free()
	Engine.max_fps = fps
	assert_ge(checked, 19, "every reach beat in the five Acts was measured (%d)" % checked)


## A prop riding a hand (`prop` with `"hand"`) is drawn exactly at that hand on every frame it rides, and
## when the ride ends it stays where the hand let go (no jump back to its old offset).
func test_props_ride_in_the_hand() -> void:
	var fps := Engine.max_fps
	var checked := 0
	for path: String in SCENES:
		var show: Control = (load(path) as PackedScene).instantiate()
		tree.root.add_child(show)
		var tl: Dictionary = show.get("_tl")
		var rides: Array = []
		for e: Dictionary in (tl.get("events", []) as Array):
			if str(e.get("do", "")) == "prop" and str(e.get("hand", "")) != "":
				rides.append(e)
		if rides.is_empty():
			show.queue_free()
			continue
		var last := 0.0
		for e: Dictionary in rides:
			last = maxf(last, float(e["t"]) + 3.0)
		var was_riding := {}
		while float(show.get("_t")) <= last:
			show._process(1.0 / 60.0)
			var props: Dictionary = show.get("_props")
			for e: Dictionary in rides:
				var name := str(e["name"])
				var pr: Dictionary = props[name]
				var at: Vector2 = show._hand_prop_at(pr)
				if at != Vector2.INF:
					var hp: Vector2 = show.hand_point(str(e["ride"]), str(e["hand"]))
					assert_lt(at.distance_to(hp + (pr["hoff"] as Vector2)), 0.01, "%s %s: drawn at the hand" % [path.get_file(), name])
					was_riding[name] = at
					checked += 1
				elif was_riding.has(name):
					# the frame the ride ended: the prop is where the hand left it
					var piv: Vector2 = show._piv(name)
					var now := piv + Vector2(float(pr["dx"]), float(pr["dy"]))
					assert_lt(now.distance_to(was_riding[name]), 40.0, "%s %s: let go where the hand had it (moved %.1f px)" % [path.get_file(), name, now.distance_to(was_riding[name])])
					was_riding.erase(name)
		show.queue_free()
	Engine.max_fps = fps
	assert_gt(checked, 0, "some prop rode a hand")
