## ContentInfo — read-only content lookups the view needs for staging (captions, sizes,
## reaction marks, camera zooms, combo captions, trigger marks). Sources, in order: the
## world's own `prank_info / reaction_info / combo_info / activity_info` methods (FakeWorld),
## the world's ContentDB (`world.db`, soft: typed defs or dictionaries), then the raw JSON
## files under res://data (content data, never sim state), then design defaults.
class_name ContentInfo
extends RefCounted

## GDD §3.7 / comedy.md §2: punch-in zoom and hit-stop frames by prank size.
const SIZE_ZOOM := {"S": 1.15, "M": 1.3, "L": 1.3, "SIG": 1.6}
const SIZE_HITSTOP := {"S": 3, "M": 5, "L": 5, "SIG": 8}
const FINALE_ZOOM := 1.6

var world: Object = null
var db: Object = null
var _pranks: Dictionary = {}
var _reactions: Dictionary = {}
var _json_pranks: Dictionary = {}
var _json_reactions: Dictionary = {}
var _json_combos: Dictionary = {}
var _ids: PackedStringArray = PackedStringArray()
var _ids_ready := false
var _preps: Dictionary = {}


static func of(w: Object) -> ContentInfo:
	var ci := ContentInfo.new()
	ci.world = w
	if w != null:
		var d: Variant = w.get("db")
		if d is Object:
			ci.db = d
	var pj: Variant = ViewKit.json("res://data/pranks.json")
	if pj is Dictionary:
		ci._json_pranks = (pj as Dictionary).get("pranks", {})
	var rj: Variant = ViewKit.json("res://data/reactions.json")
	if rj is Dictionary:
		ci._json_reactions = (rj as Dictionary).get("archetypes", {})
	var cj: Variant = ViewKit.json("res://data/residues.json")
	if cj is Dictionary:
		ci._json_combos = (cj as Dictionary).get("combos", {})
	return ci


## {id, caption, size, signature, trigger_type, activity, mark_ticks, rig_point, archetype}.
func prank(id: String) -> Dictionary:
	if _pranks.has(id):
		return _pranks[id]
	var out := {"id": id, "caption": id.to_upper().replace("_", " ") + "!", "size": "M", "signature": false,
		"trigger_type": "use", "activity": "", "mark_ticks": -1, "rig_point": "", "archetype": ""}
	var src: Variant = null
	if world != null and world.has_method("prank_info"):
		src = world.call("prank_info", id)
	if src == null and db != null:
		var tbl: Variant = db.get("pranks")
		if tbl is Dictionary:
			src = (tbl as Dictionary).get(id, null)
	if src == null:
		src = _json_pranks.get(id, null)
	if src != null:
		var cap: Variant = _g(src, "caption")
		if cap != null:
			out["caption"] = ViewKit.s(cap)
		var size: Variant = _g(src, "size")
		if size != null:
			out["size"] = ViewKit.s(size)
		var rp: Variant = _g(src, "rig_point")
		if rp != null:
			out["rig_point"] = ViewKit.s(rp)
		var tr: Variant = _g(src, "trigger")
		if tr != null:
			out["trigger_type"] = ViewKit.s(_g(tr, "type", "use"))
			out["activity"] = ViewKit.s(_g(tr, "activity", ""))
			var mt: Variant = _g(tr, "mark_ticks")
			if mt == null:
				mt = _g(tr, "mark_t")
			if mt != null:
				out["mark_ticks"] = int(mt)
			else:
				var ms: Variant = _g(tr, "mark_s")
				if ms != null:
					out["mark_ticks"] = int(round(float(ms) * 60.0))
		var rx: Variant = _g(src, "reaction")
		if rx != null:
			out["archetype"] = ViewKit.s(_g(rx, "archetype", ""))
	out["signature"] = ViewKit.s(out["size"]) == "SIG" or ViewKit.s(out["archetype"]).begins_with("sig_")
	_pranks[id] = out
	return out


## Reaction timing + camera for `<archetype>_<variant>`: {frames, antic, accent, hold0, hold1,
## release, zoom, hitstop, t3_prop_f}. Defaults scale with `len_hint` (the event's `len`).
func reaction(archetype: String, variant: String, size: String = "M", len_hint: int = 0) -> Dictionary:
	var key := archetype if variant == "" or archetype.begins_with("sig_") else "%s_%s" % [archetype, variant]
	var ck := "%s|%s|%d" % [key, size, len_hint]
	if _reactions.has(ck):
		return _reactions[ck]
	var frames := len_hint if len_hint > 0 else 150
	var out := {"frames": frames, "antic": int(frames * 0.25), "accent": int(frames * 0.4),
		"hold0": int(frames * 0.42), "hold1": int(frames * 0.85), "release": frames,
		"zoom": float(SIZE_ZOOM.get(size, 1.3)), "hitstop": int(SIZE_HITSTOP.get(size, 5)),
		"t3_prop_f": int(frames * 0.4) + 20}
	var src: Variant = null
	if world != null and world.has_method("reaction_info"):
		src = world.call("reaction_info", key)
	if src == null and db != null:
		var tbl: Variant = db.get("reactions")
		if tbl is Object:
			tbl = (tbl as Object).get("archetypes")
		elif tbl is Dictionary and (tbl as Dictionary).has("archetypes"):
			tbl = (tbl as Dictionary)["archetypes"]
		if tbl is Dictionary:
			src = (tbl as Dictionary).get(key, null)
	if src == null:
		src = _json_reactions.get(key, null)
	if src != null:
		var fr: Variant = _g(src, "frames")
		if fr != null:
			out["frames"] = int(fr)
			out["release"] = int(fr)
		var marks: Variant = _g(src, "marks")
		if marks != null:
			var ac: Variant = _g(marks, "accent")
			if ac != null:
				out["accent"] = int(ac)
			var an: Variant = _g(marks, "antic")
			if an != null:
				out["antic"] = int(an)
			var hd: Variant = _g(marks, "hold")
			if hd is Array and (hd as Array).size() >= 2:
				out["hold0"] = int(hd[0])
				out["hold1"] = int(hd[1])
			var rl: Variant = _g(marks, "release")
			if rl != null:
				out["release"] = int(rl)
		var cam: Variant = _g(src, "cam")
		if cam != null:
			var z: Variant = _g(cam, "zoom")
			if z != null:
				out["zoom"] = float(z)
			var hs: Variant = _g(cam, "hitstop")
			if hs != null:
				out["hitstop"] = int(hs)
		var t3: Variant = _g(src, "t3_prop_f")
		if t3 != null:
			out["t3_prop_f"] = int(t3)
	_reactions[ck] = out
	return out


## A combo's caption ("DOUGH MAN!").
func combo_caption(id: String) -> String:
	var src: Variant = null
	if world != null and world.has_method("combo_info"):
		src = world.call("combo_info", id)
	if src == null and db != null:
		var tbl: Variant = db.get("combos")
		if tbl is Dictionary:
			src = (tbl as Dictionary).get(id, null)
	if src == null:
		src = _json_combos.get(id, null)
	if src != null and _g(src, "caption") != null:
		return ViewKit.s(_g(src, "caption"))
	return id.to_upper().replace("_", " ") + "!"


## Every prank id known (for armed-prank ETAs).
func prank_ids() -> PackedStringArray:
	if _ids_ready:
		return _ids
	var out := PackedStringArray()
	if world != null and world.has_method("prank_ids"):
		out = PackedStringArray(world.call("prank_ids"))
	if out.is_empty() and db != null:
		var tbl: Variant = db.get("pranks")
		if tbl is Dictionary:
			for k in tbl:
				out.append(ViewKit.s(k))
	if out.is_empty():
		for k in _json_pranks:
			out.append(ViewKit.s(k))
	out.sort()
	_ids = out
	_ids_ready = true
	return out


## Ticks until the nearest RIGGED prank with a USE trigger fires (from the snapshot: his
## current activity + the trigger mark), or −1. Used for the suspense music and the
## first-time approach slow-mo. `out_prank` receives the prank id.
func armed_eta(snap: ViewSnapshot, out_prank: PackedStringArray = PackedStringArray()) -> int:
	var best := -1
	out_prank.clear()
	var b := snap.bellows
	if not b.present or b.activity == "" or b.reacting:
		return -1
	for id in prank_ids():
		var p := prank(id)
		if ViewKit.s(p["activity"]) != b.activity or int(p["mark_ticks"]) < 0:
			continue
		var rp := ViewKit.s(p["rig_point"])
		var hs: Variant = snap.hotspots.get(rp, null)
		if not (hs is Dictionary) or not bool((hs as Dictionary).get("rigged", false)):
			continue
		var eta := int(p["mark_ticks"]) - b.activity_t
		if eta < 0:
			continue
		if best < 0 or eta < best:
			best = eta
			out_prank.clear()
			out_prank.append(id)
	return best


static func _g(o: Variant, key: String, def: Variant = null) -> Variant:
	if o is Dictionary:
		return (o as Dictionary).get(key, def)
	if o is Object:
		var v: Variant = (o as Object).get(key)
		return def if v == null else v
	return def


## The rigging tier of a prank step ("q" | "s" | "b"; "" unknown) — pranks.json `steps[i].prep`.
func step_prep(prank_id: String, step: int) -> String:
	var ck := "%s|%d" % [prank_id, step]
	if _preps.has(ck):
		return _preps[ck]
	var out := ""
	var src: Variant = _json_pranks.get(prank_id, null)
	if src is Dictionary:
		var steps: Variant = (src as Dictionary).get("steps", [])
		if steps is Array and step >= 0 and step < (steps as Array).size() and (steps as Array)[step] is Dictionary:
			out = ViewKit.s(((steps as Array)[step] as Dictionary).get("prep", "")).to_lower()
	_preps[ck] = out
	return out


## The COSTUME look a prank dresses him in (pranks.json `residue[].look` of kind COSTUME; "" none).
func costume_look(prank_id: String) -> String:
	var src: Variant = _json_pranks.get(prank_id, null)
	if not (src is Dictionary):
		return ""
	for r in (src as Dictionary).get("residue", []):
		if r is Dictionary and ViewKit.s((r as Dictionary).get("kind", "")) == "COSTUME":
			return ViewKit.s((r as Dictionary).get("look", ""))
	return ""
