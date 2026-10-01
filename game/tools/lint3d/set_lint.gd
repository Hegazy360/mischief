## SetLint3D — the REDESIGN §6.3 set lint (`lint3d.sh --set [--night=<id> | --all-nights]`; index §6 row 9, brief
## r3d-tools-b §4.1). Per final Night (+ g0) and per built lit room, over **facts** derived from `SetList.for_episode`
## + `house3d.json` + `house.json` (`facts_for`), so every rule also runs on hand-written fixtures:
##
## * **live_count** ≤ 5 (rig points with a prank tonight + containers with an item tonight + listed hiding spots —
##   `SetList.Result.live_props_in`; doors / exits / stairs excluded) → `r3d-content` (the live mask is content's).
## * **dressing_count** ≤ 4 (`dressing` + the `decor` pieces marked `"dressing": true`; quake props count) → `r3d-sets`.
## * **hides_act1** — one hiding spot per room in Act I (acts 0–1) → `r3d-content` (episode `hides`).
## * **dressing_size** — every dressing piece ≥ 0.5 m on its longest side.
## * **dressing_lane** — never in the acting lane (front z > −1.6) above 0.45 m.
## * **preview_band** — never inside the 0.6 m band above a live prop (x-extent of its visual, from its top up 0.6 m).
## * **quake_height** — quake props hang ≥ 2.2 m or sit on the mantel (a `*mantel*` built-in's top) (REDESIGN §3.5).
## * **negative_space** — a ≥ 1.5 m stretch of the room's lane with nothing behind it at head height (y 1.1–1.8 m:
##   live props, furniture, dressing, decor and built-ins all block; §3.3).
## * **silhouette_family** — no two live props of a room (merged zones = one prop) share a `house3d.json` family.
## * **stack** — no two live props of a room closer than 24 px on screen (projected hit boxes, 20:9 base framing, every
##   framing the room can use; the two allowed stacks — kettle/honey N1, fridge shelf/door N2 — too).
## * **silhouette_iou** — rendered 64 px masks (`LintShot3D --pass=mask:<hotspot>` → `sil64.py`), IoU ≥ 0.80 in a room =
##   same family = error (from the measure file `render_measure.py` writes).
## * **colour** — `lab.py regions` + `lab.py rules --rules=set` on the `beauty` + `id` passes (walls, wainscot, floors,
##   dressing, live props, characters — REDESIGN §3.7): every FAIL is an error, every measured value is reported.
## Owners: geometry, dressing, colours → `r3d-sets`; the character value rule → the cast task of that character.
class_name SetLint3D
extends RefCounted

const LINT := "set"
const MAX_LIVE := 5
const MAX_DRESSING := 4
const MIN_DRESSING_M := 0.5
const LANE_FRONT_Z := -1.6
const LANE_MAX_Y := 0.45
const PREVIEW_BAND_M := 0.6
const QUAKE_MIN_Y := 2.2
const HEAD_BAND := Vector2(1.1, 1.8)
const NEG_SPACE_M := 1.5
const MAX_IOU := 0.80
const MANTEL_TOL := 0.06
const OWNER_SETS := "r3d-sets"
const OWNER_CONTENT := "r3d-content"
const CAST_OWNER := {"hush": "r3d-cast-hush", "bellows": "r3d-cast-bellows"}


# --- facts ------------------------------------------------------------------------------------------------

## The facts of one Night: {night, act, rooms: {room: {lit, x0, x1, live: [{id, kind, silhouette, merge, hit, visual}],
## dressing: [{id, box, quake, source}], furniture: [{id, box}], decor: [{id, box}], built_ins: [{id, box}]}}} —
## world metres, AABBs.
static func facts_for(db: ContentDB, episode: EpisodeDef, house3d: Dictionary = {}, res: SetList.Result = null) -> Dictionary:
	var h3 := house3d if not house3d.is_empty() else SetGeo.load_house3d()
	var r := res if res != null else SetList.for_episode(db, episode, h3)
	var hs3: Dictionary = h3.get("hotspots", {})
	var rooms := {}
	for rid in r.rooms_lit:
		var room := db.house.room(rid)
		if room == null:
			continue
		rooms[rid] = {"lit": true, "x0": float(room.x0) / SetGeo.PX_PER_M, "x1": float(room.x1) / SetGeo.PX_PER_M,
			"live": [], "dressing": [], "furniture": [], "decor": [], "built_ins": []}
	for id in r.live.keys():
		var rid := r.room_of(String(id))
		if not rooms.has(rid) or not (String(r.live[id]) in ["rig", "take", "hide"]):
			continue
		var h := db.house.hotspot(String(id))
		var e: Dictionary = hs3.get(String(id), {})
		if h == null:
			continue
		(rooms[rid]["live"] as Array).append({"id": String(id), "kind": String(r.live[id]),
			"silhouette": SetGeo.s(e.get("silhouette", "")), "merge": SetGeo.s(e.get("merge", "")),
			"hit": SetGeo.hit_box(h.rect, e), "visual": SetGeo.world_aabb(SetGeo.prop_xform(h.rect, e), e)})
	for id in r.furniture:
		var rid2 := r.room_of(String(id))
		var h2 := db.house.hotspot(String(id))
		var e2: Dictionary = hs3.get(String(id), {})
		if rooms.has(rid2) and h2 != null and not e2.is_empty() and not e2.has("part_of"):
			(rooms[rid2]["furniture"] as Array).append({"id": String(id), "box": SetGeo.world_aabb(SetGeo.prop_xform(h2.rect, e2), e2)})
	var fur3: Dictionary = h3.get("furniture", {})
	for fid in r.furniture_pieces:
		var fd: Dictionary = fur3.get(fid, {})
		if rooms.has(SetGeo.s(fd.get("room", ""))):
			(rooms[SetGeo.s(fd["room"])]["furniture"] as Array).append({"id": String(fid), "box": piece_box(fd)})
	var dr3: Dictionary = h3.get("dressing", {})
	for did in r.dressing:
		var dd: Dictionary = dr3.get(did, {})
		var room2 := SetGeo.s(dd.get("room", ""))
		if rooms.has(room2):
			(rooms[room2]["dressing"] as Array).append({"id": String(did), "box": piece_box(dd), "quake": bool(dd.get("quake", false)),
				"source": "dressing"})
	var dc3: Dictionary = h3.get("decor", {})
	for cid in r.decor:
		var cd: Dictionary = dc3.get(cid, {})
		var room3 := SetGeo.s(cd.get("room", ""))
		if not rooms.has(room3) or bool(cd.get("hidden", false)):
			continue
		if bool(cd.get("dressing", false)):
			(rooms[room3]["dressing"] as Array).append({"id": String(cid), "box": piece_box(cd), "quake": bool(cd.get("quake", false)),
				"source": "decor"})
		else:
			(rooms[room3]["decor"] as Array).append({"id": String(cid), "box": piece_box(cd)})
	var rooms3: Dictionary = h3.get("rooms", {})
	for rid3 in rooms.keys():
		var bi: Dictionary = (rooms3.get(rid3, {}) as Dictionary).get("built_ins", {})
		for bid in bi.keys():
			var bd: Dictionary = bi[bid]
			var w := SetGeo.s(bd.get("with", ""))
			if w != "" and not r.is_built(w):
				continue
			var b: Array = bd.get("box", [])
			if b.size() >= 6:
				(rooms[rid3]["built_ins"] as Array).append({"id": String(bid), "box": AABB(Vector3(float(b[0]), float(b[1]), float(b[2])),
					Vector3(float(b[3]) - float(b[0]), float(b[4]) - float(b[1]), float(b[5]) - float(b[2])))})
	return {"night": episode.id, "act": episode.act, "rooms": rooms}


## The world AABB of a furniture / dressing / decor piece ({x_m, y_m, z, yaw, box [x0, y0, z0, x1, y1, z1] local}).
static func piece_box(d: Dictionary) -> AABB:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0)))),
		Vector3(float(d.get("x_m", 0.0)), float(d.get("y_m", 0.0)), float(d.get("z", -2.2))))
	return SetGeo.world_aabb(xf, {"bounds": d.get("box", [-0.2, 0.0, -0.2, 0.2, 0.4, 0.2]), "scale": 1.0})


# --- the rules on facts (pure) -------------------------------------------------------------------------------

## Every count and geometry rule on a Night's facts. `mantels` = the mantel-top boxes of the house (AABB; quake props
## "on the mantel" sit on one).
## Lead ruling D13 (issues.md): the negative-space row of a room at the five-live-prop cap listed here is a WARNING,
## not an error — the N02 hall holds five sim-anchored live props 0.84 m apart + the MIRROR, MIRROR landing (frozen
## house.json, C3); N01/N02 are stage-door previews in the slice and R3 must re-space it.
const NEG_SPACE_EXEMPT := {"n02_something_fishy": ["hall"]}


## True when `night` / `room` holds the live-prop cap and D13 exempts its negative-space row.
static func neg_space_exempt(night: String, room: String, live_n: int) -> bool:
	return live_n >= MAX_LIVE and (NEG_SPACE_EXEMPT.get(night, []) as Array).has(room)


static func check_facts(facts: Dictionary, mantels: Array = []) -> Array:
	var out: Array = []
	var night := String(facts.get("night", ""))
	var act := int(facts.get("act", 1))
	var rooms: Dictionary = facts.get("rooms", {})
	for rid in rooms.keys():
		var rm: Dictionary = rooms[rid]
		var live: Array = rm.get("live", [])
		var dressing: Array = rm.get("dressing", [])
		var ids := PackedStringArray()
		var hides := PackedStringArray()
		for l in live:
			ids.append(String(l["id"]))
			if String(l.get("kind", "")) == "hide":
				hides.append(String(l["id"]))
		out.append(Lint3D.issue(LINT, "live_count", Lint3D.ERROR if live.size() > MAX_LIVE else Lint3D.INFO, night, rid,
			", ".join(ids), live.size(), MAX_LIVE, OWNER_CONTENT, "live props (rig + take + hide)"))
		var dids := PackedStringArray()
		for d in dressing:
			dids.append(String(d["id"]))
		out.append(Lint3D.issue(LINT, "dressing_count", Lint3D.ERROR if dressing.size() > MAX_DRESSING else Lint3D.INFO, night,
			rid, ", ".join(dids), dressing.size(), MAX_DRESSING, OWNER_SETS, "set-dressing pieces"))
		if act <= 1 and hides.size() > 1:
			out.append(Lint3D.issue(LINT, "hides_act1", Lint3D.ERROR, night, rid, ", ".join(hides), hides.size(), 1, OWNER_CONTENT,
				"one hiding spot per room in Act I (episode hides)"))
		for d in dressing:
			var b: AABB = d["box"]
			var longest := maxf(b.size.x, maxf(b.size.y, b.size.z))
			if longest < MIN_DRESSING_M - 1e-4:
				out.append(Lint3D.issue(LINT, "dressing_size", Lint3D.ERROR, night, rid, String(d["id"]), longest, MIN_DRESSING_M,
					OWNER_SETS, "dressing is big (≥ 0.5 m on its longest side, REDESIGN §3.5)"))
			if b.end.z > LANE_FRONT_Z + 1e-4 and b.end.y > LANE_MAX_Y + 1e-4:
				out.append(Lint3D.issue(LINT, "dressing_lane", Lint3D.ERROR, night, rid, String(d["id"]),
					"front z %.2f, top %.2f m" % [b.end.z, b.end.y], "z ≤ −1.6 or top ≤ 0.45 m", OWNER_SETS,
					"dressing in the acting lane above 0.45 m"))
			for l in live:
				var v: AABB = l["visual"]
				var band := Rect2(v.position.x, v.end.y, v.size.x, PREVIEW_BAND_M)
				var br := Rect2(b.position.x, b.position.y, b.size.x, b.size.y)
				if band.intersects(br):
					out.append(Lint3D.issue(LINT, "preview_band", Lint3D.ERROR, night, rid, "%s|%s" % [d["id"], l["id"]],
						band.intersection(br).get_area(), 0.0, OWNER_SETS,
						"dressing inside the 0.6 m band above a live prop (where its preview sits)"))
			if bool(d.get("quake", false)):
				var on_mantel := false
				for m in mantels:
					var mb: AABB = m
					if absf(b.position.y - mb.end.y) <= MANTEL_TOL and b.position.x >= mb.position.x - MANTEL_TOL \
							and b.end.x <= mb.end.x + MANTEL_TOL:
						on_mantel = true
				if b.position.y < QUAKE_MIN_Y - 1e-4 and not on_mantel:
					out.append(Lint3D.issue(LINT, "quake_height", Lint3D.ERROR, night, rid, String(d["id"]), b.position.y,
						QUAKE_MIN_Y, OWNER_SETS, "quake props hang ≥ 2.2 m or sit on the mantel (REDESIGN §3.5)"))
		var gap := free_stretch(rm)
		# a room nobody acts in (no live prop: the porch's doorstep) only warns; so does a room the lead exempted at
		# the five-live-prop cap (D13: the N02 hall, a stage-door preview — R3 re-spaces it)
		var ns_err := not live.is_empty() and not neg_space_exempt(night, rid, live.size())
		var ns_level := (Lint3D.ERROR if ns_err else Lint3D.WARNING) if float(gap["len"]) < NEG_SPACE_M - 0.005 \
			else Lint3D.INFO
		var ns_why := "longest lane stretch with nothing behind it at head height; blockers %s" % ", ".join(gap["blockers"])
		if not ns_err and not live.is_empty() and float(gap["len"]) < NEG_SPACE_M - 0.005:
			ns_why += " — WARNING by lead ruling D13 (a room at the %d-live-prop cap; R3 re-spaces it)" % MAX_LIVE
		out.append(Lint3D.issue(LINT, "negative_space", ns_level,
			night, rid, "x %.2f–%.2f m" % [gap["x0"], gap["x1"]], float(gap["len"]), NEG_SPACE_M, OWNER_SETS, ns_why))
		var fam := {}
		var groups := {}
		for l in live:
			var key := String(l.get("merge", "")) if String(l.get("merge", "")) != "" else String(l["id"])
			if groups.has(key):
				continue
			groups[key] = true
			var f := String(l.get("silhouette", ""))
			if f == "":
				continue
			if fam.has(f):
				out.append(Lint3D.issue(LINT, "silhouette_family", Lint3D.ERROR, night, rid, "%s|%s" % [fam[f], l["id"]], f, "distinct",
					OWNER_SETS, "two live props of one room share a house3d.json silhouette family"))
			else:
				fam[f] = String(l["id"])
	return out


## The longest stretch of the room's lane with nothing behind it at head height: {x0, x1, len, blockers}.
static func free_stretch(rm: Dictionary) -> Dictionary:
	var x0 := float(rm.get("x0", 0.0))
	var x1 := float(rm.get("x1", 0.0))
	var spans: Array = []
	var blockers := PackedStringArray()
	for key in ["live", "furniture", "dressing", "decor", "built_ins"]:
		for p in rm.get(key, []):
			var b: AABB = p.get("visual", p.get("box", AABB()))
			if b.end.y <= HEAD_BAND.x or b.position.y >= HEAD_BAND.y:
				continue
			if b.end.x <= x0 or b.position.x >= x1:
				continue
			spans.append(Vector2(maxf(x0, b.position.x), minf(x1, b.end.x)))
			blockers.append(String(p["id"]))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var best := {"x0": x0, "x1": x0, "len": 0.0}
	var cur := x0
	for s in spans:
		var sp: Vector2 = s
		if sp.x - cur > float(best["len"]):
			best = {"x0": cur, "x1": sp.x, "len": sp.x - cur}
		cur = maxf(cur, sp.y)
	if x1 - cur > float(best["len"]):
		best = {"x0": cur, "x1": x1, "len": x1 - cur}
	best["blockers"] = blockers
	return best


## The stack rule on one room's projected rects at every framing: `frames` = ScreenRectLint3D.sweep rows, `ids` the
## room's live hotspots. One issue per pair (worst gap).
static func check_stacks(night: String, room: String, frames: Array, ids: PackedStringArray) -> Array:
	var worst := {}
	for fr in frames:
		var rects: Dictionary = fr.get("rects", {})
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if not rects.has(ids[i]) or not rects.has(ids[j]):
					continue
				var g := Lint3D.rect_gap(rects[ids[i]], rects[ids[j]])
				var key := "%s|%s" % [ids[i], ids[j]]
				if not worst.has(key) or g < float((worst[key] as Array)[0]):
					worst[key] = [g, fr.get("cam_x", 0.0)]
	var out: Array = []
	for key in worst.keys():
		var w: Array = worst[key]
		var bad := float(w[0]) < ScreenRectLint3D.MIN_GAP
		out.append(Lint3D.issue(LINT, "stack", Lint3D.ERROR if bad else Lint3D.INFO, night, room, key, float(w[0]),
			ScreenRectLint3D.MIN_GAP, OWNER_SETS, "20x9 worst framing cam x %s (projected hit boxes)" % Lint3D.fmt(w[1])))
	return out


# --- measured rules (render_measure.py output) ---------------------------------------------------------------

## The colour / value and silhouette rules from the measure file of `render_measure.py`: {rooms: [{night, room,
## rules: <lab.py rules JSON>, regions: <lab.py regions JSON>, sil: <sil64.py JSON>, …}], missing: [...]}.
static func check_measures(measure: Variant, nights: PackedStringArray) -> Array:
	var out: Array = []
	if typeof(measure) != TYPE_DICTIONARY:
		out.append(Lint3D.skip(LINT, "colour", "no render measures (LintShot3D beauty/id passes + render_measure.py did not run)",
			"r3d-tools-b"))
		out.append(Lint3D.skip(LINT, "silhouette_iou", "no 64 px masks (LintShot3D mask passes + sil64.py did not run)",
			"r3d-tools-b"))
		return out
	var seen := {}
	for m in (measure as Dictionary).get("rooms", []):
		var md: Dictionary = m
		var night := String(md.get("night", ""))
		if not nights.is_empty() and not nights.has(night):
			continue
		var room := String(md.get("room", ""))
		seen[night + "|" + room] = true
		out.append_array(colour_issues(night, room, md.get("rules", null)))
		out.append_array(iou_issues(night, room, md.get("sil", null)))
	for miss in (measure as Dictionary).get("missing", []):
		out.append(Lint3D.skip(LINT, "render", String(miss), "r3d-tools-b"))
	return out


## lab.py `rules --rules=set` results → issues (FAIL = error; PASS / EXEMPT / INFO kept as info with the value).
static func colour_issues(night: String, room: String, rules: Variant) -> Array:
	var out: Array = []
	if typeof(rules) != TYPE_DICTIONARY:
		out.append(Lint3D.skip(LINT, "colour", "no lab.py rules result for %s %s" % [Lint3D.label(night), room], "r3d-tools-b",
			night, room))
		return out
	for r in (rules as Dictionary).get("results", []):
		var rd: Dictionary = r
		var st := String(rd.get("status", ""))
		var cls := String(rd.get("class", ""))
		var owner := OWNER_SETS
		if cls == "character":
			owner = String(CAST_OWNER.get(String(rd.get("name", "")), "r3d-cast-hush / r3d-cast-bellows"))
		# lab.py's SKIP = the region is not visible in this framing (a backstage room off screen, an occluded piece) or has
		# no reference wall: a measurement note, not a missing input — info, so the strict pre-gate does not trip on it
		var level := Lint3D.ERROR if st == "FAIL" else Lint3D.INFO
		var i := Lint3D.issue(LINT, "colour", level, night, room, "%s [%s]: %s" % [rd.get("name", ""), cls, rd.get("rule", "")],
			rd.get("value", null), rd.get("limit", null), owner, "%s %s" % [st, rd.get("detail", "")])
		out.append(i)
	return out


## sil64.py masks JSON → issues: every pair of one room at IoU ≥ 0.80 is an error; the room's maximum is info.
static func iou_issues(night: String, room: String, sil: Variant) -> Array:
	var out: Array = []
	if typeof(sil) != TYPE_DICTIONARY:
		out.append(Lint3D.skip(LINT, "silhouette_iou", "no sil64.py result for %s %s" % [Lint3D.label(night), room],
			"r3d-tools-b", night, room))
		return out
	var names: Array = (sil as Dictionary).get("names", [])
	var iou: Array = (sil as Dictionary).get("iou", [])
	var mx := 0.0
	var mx_pair := ""
	for i in names.size():
		for j in range(i + 1, names.size()):
			if i >= iou.size() or j >= (iou[i] as Array).size():
				continue
			var v := float(iou[i][j])
			if v > mx:
				mx = v
				mx_pair = "%s|%s" % [names[i], names[j]]
			if v >= MAX_IOU:
				out.append(Lint3D.issue(LINT, "silhouette_iou", Lint3D.ERROR, night, room, "%s|%s" % [names[i], names[j]], v, MAX_IOU,
					OWNER_SETS, "64 px masks of one family (IoU ≥ 0.80)"))
	if names.size() >= 2:
		out.append(Lint3D.issue(LINT, "silhouette_iou", Lint3D.INFO, night, room, mx_pair, mx, MAX_IOU, OWNER_SETS,
			"highest IoU of the room's %d live-prop masks" % names.size()))
	return out


# --- the run -----------------------------------------------------------------------------------------------

## The mantel tops of the house (built-ins named *mantel*).
static func mantels(house3d: Dictionary) -> Array:
	var out: Array = []
	for rid in (house3d.get("rooms", {}) as Dictionary).keys():
		var bi: Dictionary = (house3d["rooms"][rid] as Dictionary).get("built_ins", {})
		for bid in bi.keys():
			if String(bid).contains("mantel"):
				var b: Array = (bi[bid] as Dictionary).get("box", [])
				if b.size() >= 6:
					out.append(AABB(Vector3(float(b[0]), float(b[1]), float(b[2])),
						Vector3(float(b[3]) - float(b[0]), float(b[4]) - float(b[1]), float(b[5]) - float(b[2]))))
	return out


## The headless part of the lint (counts, geometry, families, stacks) + the measured part when `measure` is given.
## Returns {issues, results: {night: {room: facts summary}}}.
static func run(db: ContentDB, nights: PackedStringArray, measure: Variant = null, house3d: Dictionary = {}) -> Dictionary:
	var h3 := house3d if not house3d.is_empty() else SetGeo.load_house3d()
	var issues: Array = []
	var results := {}
	var mts := mantels(h3)
	for ep_id in nights:
		var ep: EpisodeDef = db.episodes.get(ep_id, null)
		if ep == null:
			issues.append(Lint3D.skip(LINT, "episode", "episode %s not in the content" % ep_id, OWNER_CONTENT, ep_id))
			continue
		var res := SetList.for_episode(db, ep, h3)
		var facts := facts_for(db, ep, h3, res)
		issues.append_array(check_facts(facts, mts))
		var hud := ScreenRectLint3D.hud_rects(ep, "20x9")
		var cam := ScreenRectLint3D.make_camera(db, res, "20x9", hud["safe"])
		var summary := {}
		for rid in (facts["rooms"] as Dictionary).keys():
			var rm: Dictionary = facts["rooms"][rid]
			var ids := PackedStringArray()
			var boxes := {}
			var keep: Array = []
			for l in rm["live"]:
				ids.append(String(l["id"]))
				boxes[String(l["id"])] = l["hit"]
				keep.append(l["hit"])
			var room := db.house.room(rid)
			if room != null and ids.size() >= 2:
				issues.append_array(check_stacks(ep_id, rid, ScreenRectLint3D.sweep(cam, room, boxes, keep), ids))
			var dr := PackedStringArray()
			for d in rm["dressing"]:
				dr.append(String(d["id"]))
			summary[rid] = {"live": Array(ids), "dressing": Array(dr), "free_stretch": free_stretch(rm)}
		cam.free()
		results[ep_id] = {"rooms_lit": Array(res.rooms_lit), "rooms_backstage": Array(res.rooms_backstage), "rooms": summary}
	issues.append_array(check_measures(measure, nights))
	return {"issues": issues, "results": results}
