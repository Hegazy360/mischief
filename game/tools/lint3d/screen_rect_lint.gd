## ScreenRectLint3D — the REDESIGN §6.3 screen-rect lint (`lint3d.sh --screen --aspects=20x9,16x9,4x3`, headless;
## index §6 row 10, brief r3d-tools-b §4.2).
##
## For every live hotspot of every final Night (+ g0): its **hit box** (`House3D.hotspot_box` = `SetGeo.hit_box`: the
## rect's x/y + `visual_offset`, or the explicit `hit_box`; z = prop z ± 0.3 m — index R5a) projected with a real
## `CameraDirector3D` (its 8 corners → the screen bounding rect, `project_aabb`) at the base framing, for **every camera
## position the room can use**: Hush is swept across her room in 0.25 m steps walking both ways, the director snaps
## (C1 room framing, C2 edge clamp, C6 keep-visible with the room's live boxes inside the aspect's safe rect) and each
## distinct camera x is one framing. Aspects (logical px): 20:9 2400 × 1080 with a punch-hole phone's side insets
## S = 96; 16:9 1920 × 1080 and 4:3 1440 × 1080 with none (the brief's numbers). **4:3 HUD:** a real 4:3 device's
## canvas is 1920 × 1440 (base 1920 × 1080, stretch aspect `expand`) where REDESIGN §2.6 scales the HUD ×0.8
## (`UiScale`); the HUD rects are computed there (`Hud.always_on_rects()` at that aspect) and mapped into the 1440 × 1080
## frame (× 0.75), while the world rects are measured in the 1440 × 1080 frame — 1.33× smaller than on the device, so
## the size rule stays the stricter proxy.
##
## Rules for each live rect of the framed room, at every framing: **min_size** ≥ 144 × 144 px; **gap** ≥ 24 px from
## every other live rect on screen (`Lint3D.rect_gap`: side by side or stacked); **safe_rect** inside the safe rect;
## **hud_overlap** not under an always-on HUD hit rect (`Hud.always_on_rects()` at that aspect — error);
## **window_overlap** not under the Bellows window rect (warning); **back_wall** the framing keeps ≥ 201 px/m at the
## back wall (≤ 10 m away). Issues are folded per (Night, room, aspect, rule, hotspot) with the worst value and the
## camera-x range where it happens.
class_name ScreenRectLint3D
extends RefCounted

const LINT := "screen"
const MIN_PX := 144.0
const MIN_GAP := 24.0
const MIN_PX_PER_M := 201.0
const SWEEP_M := 0.25
## aspect → [logical size of the lint frame, symmetric side inset S, the device canvas the HUD lays out in].
const ASPECTS := {"20x9": [Vector2(2400.0, 1080.0), 96.0, Vector2(2400.0, 1080.0)],
	"16x9": [Vector2(1920.0, 1080.0), 0.0, Vector2(1920.0, 1080.0)],
	"4x3": [Vector2(1440.0, 1080.0), 0.0, Vector2(1920.0, 1440.0)]}
const ALWAYS_ON: PackedStringArray = ["pause", "script", "clarence", "action"]
const HUD_SCRIPT := "res://ui/hud.gd"


## The HUD rects at an aspect for a Night: {always_on: {name: Rect2}, pip: Rect2, safe: Rect2, source}. Uses a real
## `Hud` (its `always_on_rects()`, with the Night's Script pips so the chip has its real width) when the HUD module is
## present, else `HudLayout.compute` (the same numbers — the Hud lays its widgets out from it).
static func hud_rects(episode: EpisodeDef, aspect: String) -> Dictionary:
	var a: Array = ASPECTS.get(aspect, ASPECTS["20x9"])
	var frame: Vector2 = a[0]
	var vp: Vector2 = a[2]
	var f := frame.y / vp.y
	var s := float(a[1]) / f
	var ins := Vector4(s, 0.0, s, 0.0)
	var lines: Array = []
	if episode != null:
		for l in episode.script_lines:
			lines.append({"req": l.req, "done": false, "big_number": l.big_number, "sealed": true})
	var pips := ScriptChip.pips_from_lines(lines)
	var sw := HudLayout.PILL_MIN_HIT
	var c := Vector2i.ZERO
	for p in pips:
		if p == HudModel.Pip.REQ_OPEN or p == HudModel.Pip.REQ_DONE:
			c.x += 1
		elif p == HudModel.Pip.OPT_OPEN or p == HudModel.Pip.OPT_DONE:
			c.y += 1
	sw = HudLayout.script_pill_width(c.x, c.y)
	var out := {"always_on": {}, "source": "HudLayout", "viewport": frame, "device": vp, "hud_scale": UiScale.factor_for(vp),
		"side": float(a[1])}
	var lay := HudLayout.compute(vp, ins, false, UiScale.factor_for(vp), sw)
	if ResourceLoader.exists(HUD_SCRIPT):
		var hs := load(HUD_SCRIPT) as Script
		var hud: Object = hs.new() if hs != null and hs.can_instantiate() else null
		if hud != null and hud.has_method("always_on_rects"):
			hud.set("layout_size_override", vp)
			hud.set("insets_override", ins)
			var chip: Variant = hud.get("script_chip")
			if chip is Object and (chip as Object).has_method("set_pips"):
				(chip as Object).call("set_pips", pips)
			hud.call("relayout")
			var rects: Array = hud.call("always_on_rects")
			if rects.size() == 4:
				for i in 4:
					out["always_on"][ALWAYS_ON[i]] = rects[i]
				out["source"] = "Hud.always_on_rects"
			var l2: Variant = hud.get("layout")
			if l2 is Dictionary and not (l2 as Dictionary).is_empty():
				lay = l2
			if hud is Node:
				(hud as Node).free()
	if (out["always_on"] as Dictionary).is_empty():
		for n in ALWAYS_ON:
			out["always_on"][n] = lay[StringName(n)]
	for n in ALWAYS_ON:
		out["always_on"][n] = _scaled(out["always_on"][n], f)
	out["pip"] = _scaled(lay[&"pip"], f)
	out["safe"] = _scaled(lay[&"safe"], f)
	return out


static func _scaled(r: Rect2, f: float) -> Rect2:
	return Rect2(r.position * f, r.size * f)


## A CameraDirector3D at an aspect for tonight's set (off-tree; projection is headless-safe).
static func make_camera(db: ContentDB, result: SetList.Result, aspect: String, safe: Rect2) -> CameraDirector3D:
	var cam := CameraDirector3D.new()
	cam.logical_size_override = (ASPECTS.get(aspect, ASPECTS["20x9"]) as Array)[0]
	cam.setup(db, result)
	cam.set_safe_rect(safe)
	return cam


## Frames a camera on Hush at lane x `x_m` walking `lead` (±1) and snaps it (C1/C2/C6 applied).
static func frame_at(cam: CameraDirector3D, target: Node3D, x_m: float, floor_i: int, lead: float) -> void:
	target.position = Vector3(x_m, View3DConst.floor_y(floor_i), View3DConst.LANE_Z)
	cam.follow(target, func() -> float: return lead)
	cam.snap_now()
	cam.advance(1.0 / 60.0, 1.0 / 60.0)


## Every framing the room can use: [{cam_x, hush_x, lead, px_per_m_back, rects: {hotspot: Rect2}}] (rects of every
## live hotspot of the Night whose box is on screen). `keep` = the room's live boxes (C6), `boxes` = {id: AABB} of
## every live hotspot of the Night.
static func sweep(cam: CameraDirector3D, room: RoomDef, boxes: Dictionary, keep: Array) -> Array:
	var target := Node3D.new()
	cam.set_keep_visible(func() -> Array: return keep)
	var out: Array = []
	var seen := {}
	var x0 := float(room.x0) / View3DConst.PX_PER_M + 0.3
	var x1 := float(room.x1) / View3DConst.PX_PER_M - 0.3
	var n := maxi(1, int(ceil((x1 - x0) / SWEEP_M)))
	var view := Rect2(Vector2.ZERO, cam.view_size())
	for i in n + 1:
		var x := minf(x1, x0 + SWEEP_M * float(i))
		for lead in [1.0, -1.0]:
			frame_at(cam, target, x, room.floor, lead)
			var cx := snappedf(cam.aim().x, 0.01)
			if seen.has(cx):
				continue
			seen[cx] = true
			var rects := {}
			for id in boxes.keys():
				var r := cam.project_aabb(boxes[id])
				if r.intersects(view):
					rects[id] = r
			out.append({"cam_x": cx, "hush_x": snappedf(x, 0.01), "lead": lead,
				"px_per_m_back": snappedf(cam.px_per_m_at(View3DConst.BACK_WALL_Z), 0.1), "rects": rects})
	target.free()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cam_x"]) < float(b["cam_x"]))
	return out


## The rules on one framing (pure; the fixtures call it): `room_ids` = the framed room's live hotspots, `frame` =
## {cam_x, rects: {id: Rect2}, px_per_m_back}, `view` the screen, `hud` {always_on: {name: Rect2}, pip, safe}.
static func check_frame(night: String, room: String, aspect: String, frame: Dictionary, room_ids: PackedStringArray,
		view: Rect2, hud: Dictionary) -> Array:
	var out: Array = []
	var rects: Dictionary = frame.get("rects", {})
	var safe: Rect2 = hud.get("safe", view)
	var pip: Rect2 = hud.get("pip", Rect2())
	var ao: Dictionary = hud.get("always_on", {})
	var cx: Variant = frame.get("cam_x", null)
	var at := "%s cam x %s" % [aspect, Lint3D.fmt(cx)]
	var ppm := float(frame.get("px_per_m_back", 999.0))
	if ppm < MIN_PX_PER_M:
		out.append(Lint3D.issue(LINT, "back_wall", Lint3D.ERROR, night, room, "", ppm, MIN_PX_PER_M, "r3d-view3d",
			at + ": the back wall is further than 10 m (REDESIGN §5.5)"))
	for id in room_ids:
		if not rects.has(id):
			out.append(Lint3D.issue(LINT, "on_screen", Lint3D.ERROR, night, room, id, "off screen", "on screen", "r3d-view3d",
				at + ": a live prop of the framed room is not on screen (C6)"))
			continue
		var r: Rect2 = rects[id]
		if r.size.x < MIN_PX or r.size.y < MIN_PX:
			out.append(Lint3D.issue(LINT, "min_size", Lint3D.ERROR, night, room, id, r.size, "%d×%d" % [MIN_PX, MIN_PX],
				"r3d-sets", at + ": hit box too small (house3d.json hit_box / visual_offset)"))
		for other in rects.keys():
			if String(other) == id:
				continue
			var g := Lint3D.rect_gap(r, rects[other])
			if g < MIN_GAP and (not room_ids.has(String(other)) or String(other) > id):
				out.append(Lint3D.issue(LINT, "gap", Lint3D.ERROR, night, room, "%s|%s" % [id, other], g, MIN_GAP,
					"r3d-sets", at + (": the hit boxes overlap" if g < 0.0 else ": hit boxes closer than 24 px")))
		if not safe.encloses(r):
			out.append(Lint3D.issue(LINT, "safe_rect", Lint3D.ERROR, night, room, id, r, safe, "r3d-view3d",
				at + ": outside the safe rect (C6)"))
		for n in ao.keys():
			if r.intersects(ao[n]):
				out.append(Lint3D.issue(LINT, "hud_overlap", Lint3D.ERROR, night, room, "%s|%s" % [id, n],
					r.intersection(ao[n]).get_area(), 0, "r3d-view3d",
					at + ": under the always-on %s hit rect (camera C6 keeps it clear, or house3d.json moves it)" % n))
		if pip.has_area() and r.intersects(pip):
			out.append(Lint3D.issue(LINT, "window_overlap", Lint3D.WARNING, night, room, id, r.intersection(pip).get_area(), 0,
				"r3d-view3d", at + ": under the Bellows window rect"))
	return out


## Folds per-framing issues: one per (Night, room, rule, subject, aspect) with the framing count, the camera-x
## range and the worst value (smallest size / gap, largest overlap).
static func fold(issues: Array, aspect: String) -> Array:
	var groups := {}
	var order: Array = []
	for i in issues:
		var d: Dictionary = i
		var key := "%s|%s|%s|%s|%s" % [d["night"], d["room"], d["rule"], d["subject"], aspect]
		var det := String(d.get("detail", ""))
		var cam := det.get_slice(":", 0)
		if not groups.has(key):
			groups[key] = {"i": d.duplicate(), "n": 0, "cams": []}
			order.append(key)
		var g: Dictionary = groups[key]
		g["n"] = int(g["n"]) + 1
		(g["cams"] as Array).append(cam.trim_prefix(aspect + " cam x "))
		var cur: Variant = (g["i"] as Dictionary)["value"]
		var v: Variant = d["value"]
		if typeof(v) == TYPE_VECTOR2 and typeof(cur) == TYPE_VECTOR2:
			if minf((v as Vector2).x, (v as Vector2).y) < minf((cur as Vector2).x, (cur as Vector2).y):
				(g["i"] as Dictionary)["value"] = v
		elif (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and (typeof(cur) == TYPE_FLOAT or typeof(cur) == TYPE_INT):
			var rule := String(d["rule"])
			if (rule in ["gap", "back_wall"] and float(v) < float(cur)) or (rule in ["hud_overlap", "window_overlap"] and float(v) > float(cur)):
				(g["i"] as Dictionary)["value"] = v
	var out: Array = []
	for key in order:
		var g2: Dictionary = groups[key]
		var d2: Dictionary = g2["i"]
		var cams: Array = g2["cams"]
		var rest := String(d2.get("detail", "")).get_slice(":", 1).strip_edges()
		d2["detail"] = "%s: %d framing(s), cam x %s…%s: %s" % [aspect, int(g2["n"]), cams[0], cams[cams.size() - 1], rest]
		d2["aspect"] = aspect
		d2["framings"] = int(g2["n"])
		out.append(d2)
	return out


## Runs the lint for Nights × aspects. Returns {issues, results: {night: {aspect: {room: {framings, rects_min, hud}}}}}.
static func run(db: ContentDB, nights: PackedStringArray, aspects: PackedStringArray, house3d: Dictionary = {}) -> Dictionary:
	var issues: Array = []
	var results := {}
	var h3 := house3d if not house3d.is_empty() else SetGeo.load_house3d()
	for ep_id in nights:
		var ep: EpisodeDef = db.episodes.get(ep_id, null)
		if ep == null:
			issues.append(Lint3D.skip(LINT, "episode", "episode %s not in the content" % ep_id, "r3d-content", ep_id))
			continue
		var res := SetList.for_episode(db, ep, h3)
		var boxes := {}
		for id in res.live.keys():
			var hdef := db.house.hotspot(String(id))
			if hdef != null:
				boxes[String(id)] = SetGeo.hit_box(hdef.rect, (h3.get("hotspots", {}) as Dictionary).get(String(id), {}))
		results[ep_id] = {}
		for aspect in aspects:
			var hud := hud_rects(ep, aspect)
			var cam := make_camera(db, res, aspect, hud["safe"])
			var view := Rect2(Vector2.ZERO, cam.view_size())
			var per_room := {}
			var raw: Array = []
			for rid in res.rooms_lit:
				var room := db.house.room(rid)
				if room == null:
					continue
				var ids := PackedStringArray()
				var keep: Array = []
				for id in boxes.keys():
					if res.room_of(id) == rid:
						ids.append(id)
						if not (String(res.live[id]) in ["door", "stairs", "exit"]):
							keep.append(boxes[id])
				if ids.is_empty():
					continue
				var frames := sweep(cam, room, boxes, keep)
				var min_size := {}
				for fr in frames:
					raw.append_array(check_frame(ep_id, rid, aspect, fr, ids, view, hud))
					for id in ids:
						if (fr["rects"] as Dictionary).has(id):
							var r: Rect2 = fr["rects"][id]
							var cur: Vector2 = min_size.get(id, Vector2(INF, INF))
							min_size[id] = Vector2(minf(cur.x, r.size.x), minf(cur.y, r.size.y))
				per_room[rid] = {"framings": frames.size(), "cam_x": [frames[0]["cam_x"], frames[frames.size() - 1]["cam_x"]] if not frames.is_empty() else [],
					"min_size": min_size, "frames": frames}
			cam.free()
			issues.append_array(fold(raw, aspect))
			(results[ep_id] as Dictionary)[aspect] = {"rooms": per_room, "hud": {"always_on": hud["always_on"], "pip": hud["pip"],
				"safe": hud["safe"], "source": hud["source"]}}
	return {"issues": issues, "results": results}
