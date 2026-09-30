## ContentLint — design rules over the raw `game/data/**` JSON (TECH §10.5), independent of
## `ContentDB`. Every message is "<file>: <where>: <what>".
##
##   var errs := ContentLint.lint_dir("res://data")          # PackedStringArray, [] = clean
##   var errs2 := ContentLint.lint_dir(bad_dir, good_dir)    # files missing in bad_dir come from good_dir
##
## Rules: ids resolve across items / pranks / activities / reactions / residues / episodes / house;
## each prank's trigger activity is in the loop of every episode that lists the prank (or a fix-up of
## one of its `fixup_kinds` can reach it there); needed items have a source container in the episode's
## rooms; Script 3–6 lines + one Big Number, ≤ 7 in all (the Prologue: 1–6, Big Number optional);
## one `new_rule` per Night (unique); loading card ≤ 25 words; captions ≤ 18 characters; fix-up
## station kinds exist on each floor the episode uses (unless the Night's `fixup_overrides` names the
## station for that kind, GDD §5.4); reactions.json covers every archetype used;
## `time_jitter == 0` on `rx_*` clips; prank-line bases normalise to exactly 700 tenths; (D1, BeatLint) every
## activity / fix-up a final Night uses has a micro-gag at least every 8 s and never two within 5 s, and every
## `emote` is in the edge-bubble vocabulary; (R3D) `hides` lists and solution hides (REDESIGN_3D §6.2 C1) and the
## view data `previews.json` + `rig_actions.json` (C4, ViewDataLint).
class_name ContentLint
extends RefCounted

const FIXUP_KINDS: PackedStringArray = ["DRY", "SINK", "HONEY", "MIRROR"]
const LINE_KINDS: PackedStringArray = ["prank", "double_act", "combo", "combo_witnessed", "prank_witnessed",
	"meltdown", "panto", "witness", "herd", "chase_trip", "chain"]
const SIZES: PackedStringArray = ["S", "M", "L", "SIG"]
const PREPS: PackedStringArray = ["Q", "S", "B"]
const TRIGGERS: PackedStringArray = ["use", "step", "quake", "third_party", "knock_on_only"]
const MAX_CAPTION := 18
## Hint `when` values that aren't activities: moments of Bellows' behaviour a ghost demo can show.
const HINT_MOMENTS: PackedStringArray = ["chase", "meltdown", "stairs_up", "stairs_down", "search", "curious",
	"reacting", "exhausted"]
const MAX_CARD_WORDS := 25
## The R3D view-data rules (preloaded, so the lint never depends on a fresh global class cache).
const _ViewData := preload("res://tools/lint/view_data_lint.gd")


## Load `root` (with `base_root` as a fallback for missing files) and lint it.
static func lint_dir(root: String, base_root: String = "") -> PackedStringArray:
	return lint(load_parts(root, base_root))


## Parsed inputs: {house, items, pranks, activities, reactions, residues, episodes {id: dict},
## clips {path: dict}, missing [files], parse_errors [..]}.
static func load_parts(root: String, base_root: String = "") -> Dictionary:
	var parts := {}
	var missing := PackedStringArray()
	var perr: Array = []
	for f in ["house/house.json", "items.json", "pranks.json", "activities.json", "reactions.json", "residues.json"]:
		var key: String = f.get_file().get_basename()
		var n0 := perr.size()
		var v: Variant = _read_overlay(root, base_root, f, perr)
		if v is Dictionary:
			parts[key] = v
		else:
			parts[key] = {}
			if perr.size() == n0:
				missing.append(f)
	var eps := {}
	var dir := _pick_dir(root, base_root, "episodes")
	for n in SolverData._list_json(dir):
		var v: Variant = SolverData.read_json("%s/%s" % [dir, n], perr)
		if v is Dictionary:
			eps[SolverData.sv((v as Dictionary).get("id", n.get_basename()))] = v
	parts["episodes"] = eps
	var clips := {}
	_collect_clips(_pick_dir(root, base_root, "anim"), clips, perr)
	parts["clips"] = clips
	# R3D view data (REDESIGN_3D §6.2 C4; ViewDataLint) and the solutions (hides ∈ the episode's `hides`, C1)
	for pair in [["previews", "view/previews.json"], ["rig_actions", "anim/hush3d/rig_actions.json"], ["house3d", "house/house3d.json"]]:
		var rel: String = pair[1]
		var pth := "%s/%s" % [root, rel]
		if not FileAccess.file_exists(pth) and base_root != "":
			pth = "%s/%s" % [base_root, rel]
		parts[pair[0]] = SolverData.read_json(pth, perr) if FileAccess.file_exists(pth) else {}
	var sols := {}
	var sdir := _pick_dir(root, base_root, "solutions")
	for n in SolverData._list_json(sdir):
		var v: Variant = SolverData.read_json("%s/%s" % [sdir, n], perr)
		if v is Dictionary:
			sols[SolverData.sv((v as Dictionary).get("episode", n.get_basename()))] = v
	parts["solutions"] = sols
	parts["missing"] = missing
	parts["parse_errors"] = PackedStringArray(perr)
	return parts


static func _read_overlay(root: String, base_root: String, rel: String, errs: Array) -> Variant:
	var p := "%s/%s" % [root, rel]
	if FileAccess.file_exists(p) or base_root == "":
		return SolverData.read_json(p, errs)
	return SolverData.read_json("%s/%s" % [base_root, rel], errs)


static func _pick_dir(root: String, base_root: String, sub: String) -> String:
	var p := "%s/%s" % [root, sub]
	if DirAccess.dir_exists_absolute(p) or base_root == "":
		return p
	return "%s/%s" % [base_root, sub]


static func _collect_clips(dir: String, out: Dictionary, errs: Array) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for sub in da.get_directories():
		_collect_clips("%s/%s" % [dir, sub], out, errs)
	for f in da.get_files():
		if f.ends_with(".json"):
			var v: Variant = SolverData.read_json("%s/%s" % [dir, f], errs)
			if v is Dictionary:
				out["%s/%s" % [dir, f]] = v


## Lint parsed parts (see `load_parts`).
static func lint(parts: Dictionary) -> PackedStringArray:
	var e := PackedStringArray()
	e.append_array(parts.get("parse_errors", PackedStringArray()))
	var house: Dictionary = parts.get("house", {})
	var items: Dictionary = (parts.get("items", {}) as Dictionary).get("items", {})
	var pr_file: Dictionary = parts.get("pranks", {})
	var pranks: Dictionary = pr_file.get("pranks", {})
	var das: Dictionary = pr_file.get("double_acts", {})
	var ac_file: Dictionary = parts.get("activities", {})
	var acts: Dictionary = (ac_file.get("activities", {}) as Dictionary).duplicate()
	var det: Variant = ac_file.get("detours", {})
	if det is Dictionary:
		acts.merge(det)
	var bits: Dictionary = ac_file.get("squeak_bits", {})
	var rx: Dictionary = (parts.get("reactions", {}) as Dictionary).get("archetypes", {})
	var rs_file: Dictionary = parts.get("residues", {})
	var residues: Dictionary = rs_file.get("residues", {})
	var combos: Dictionary = rs_file.get("combos", {})
	var eps: Dictionary = parts.get("episodes", {})
	var data := SolverData.from_dicts({"house": house, "items": items, "pranks": pranks, "double_acts": das,
		"activities": acts, "residues": residues, "combos": combos, "episodes": eps})
	var has_house := not house.is_empty()
	var has_items := not items.is_empty()
	var has_acts := not acts.is_empty()
	var has_rx := not rx.is_empty()
	var has_res := not residues.is_empty()

	# --- house references -------------------------------------------------------------------
	for h in house.get("hotspots", []):
		var hid := SolverData.sv(h.get("id", ""))
		if h.get("station", null) != null and not data.has_station(SolverData.sv(h["station"])):
			e.append("house.json: hotspot %s.station '%s' not in stations" % [hid, h["station"]])
		if h.get("in_use_by", null) != null and has_acts and not acts.has(SolverData.sv(h["in_use_by"])):
			e.append("house.json: hotspot %s.in_use_by '%s' not in activities.json" % [hid, h["in_use_by"]])
		if not data.has_room(SolverData.sv(h.get("room", ""))):
			e.append("house.json: hotspot %s.room '%s' not a room" % [hid, h.get("room", "")])
	for s in house.get("stations", []):
		if not data.has_room(SolverData.sv(s.get("room", ""))):
			e.append("house.json: station %s.room '%s' not a room" % [s.get("id", ""), s.get("room", "")])
		for k in s.get("kinds", []):
			if not FIXUP_KINDS.has(SolverData.sv(k)):
				e.append("house.json: station %s kind '%s' not in %s" % [s.get("id", ""), k, FIXUP_KINDS])
	for l in house.get("links", []):
		for side in ["a", "b"]:
			if not data.has_room(SolverData.sv(l.get(side, ""))):
				e.append("house.json: link %s.%s '%s' not a room" % [l.get("id", ""), side, l.get(side, "")])

	# --- items ------------------------------------------------------------------------------
	for iid in items:
		var it: Dictionary = items[iid]
		var src := SolverData.sv(it.get("source", ""))
		if has_house:
			if not data.has_hotspot(src):
				e.append("items.json: %s.source '%s' not in house.json" % [iid, src])
			elif data.hotspot_kind(src) != "container":
				e.append("items.json: %s.source '%s' is a %s, not a container" % [iid, src, data.hotspot_kind(src)])
		for p in it.get("pranks", []):
			if not pranks.is_empty() and not pranks.has(SolverData.sv(p)):
				e.append("items.json: %s.pranks '%s' not in pranks.json" % [iid, p])

	# --- activities -------------------------------------------------------------------------
	for aid in acts:
		var a: Dictionary = acts[aid]
		if a.get("station", null) != null and has_house and not data.has_station(SolverData.sv(a["station"])):
			e.append("activities.json: %s.station '%s' not in house.json" % [aid, a["station"]])
		if a.get("in_use", null) != null and has_house and not data.has_hotspot(SolverData.sv(a["in_use"])):
			e.append("activities.json: %s.in_use '%s' not in house.json" % [aid, a["in_use"]])
		if a.get("squeak_bit", null) != null and not bits.has(SolverData.sv(a["squeak_bit"])):
			e.append("activities.json: %s.squeak_bit '%s' not in squeak_bits" % [aid, a["squeak_bit"]])

	# --- pranks -----------------------------------------------------------------------------
	for pid in pranks:
		var p: Dictionary = pranks[pid]
		var where := "pranks.json: %s" % pid
		var cap := SolverData.sv(p.get("caption", ""))
		if cap.length() > MAX_CAPTION:
			e.append("%s.caption '%s' is %d characters (max %d)" % [where, cap, cap.length(), MAX_CAPTION])
		if not SIZES.has(SolverData.sv(p.get("size", ""))):
			e.append("%s.size '%s' not in %s" % [where, p.get("size", ""), SIZES])
		var rp := SolverData.sv(p.get("rig_point", ""))
		if has_house and not data.has_hotspot(rp):
			e.append("%s.rig_point '%s' not in house.json" % [where, rp])
		var steps: Array = p.get("steps", [])
		if steps.is_empty():
			e.append("%s has no steps" % where)
		for i in steps.size():
			var st: Dictionary = steps[i]
			if not PREPS.has(SolverData.sv(st.get("prep", ""))):
				e.append("%s.steps[%d].prep '%s' not in %s" % [where, i, st.get("prep", ""), PREPS])
			if st.get("needs", null) != null and has_items and not items.has(SolverData.sv(st["needs"])):
				e.append("%s.steps[%d].needs '%s' not in items.json" % [where, i, st["needs"]])
			if st.get("at", null) != null and has_house and not data.has_hotspot(SolverData.sv(st["at"])):
				e.append("%s.steps[%d].at '%s' not in house.json" % [where, i, st["at"]])
		var tr: Dictionary = p.get("trigger", {}) if p.get("trigger", {}) is Dictionary else {}
		var tt := SolverData.sv(tr.get("type", ""))
		if not TRIGGERS.has(tt):
			e.append("%s.trigger.type '%s' not in %s" % [where, tt, TRIGGERS])
		if tt == "use" and has_acts and not acts.has(SolverData.sv(tr.get("activity", ""))):
			e.append("%s.trigger.activity '%s' not in activities.json" % [where, tr.get("activity", "")])
		if tt == "step" and has_house and tr.get("at", null) != null:
			# One hotspot, or several (PENNY PINCHER passes one per coin).
			for at in (tr["at"] if tr["at"] is Array else [tr["at"]]):
				if not data.has_hotspot(SolverData.sv(at)):
					e.append("%s.trigger.at '%s' not in house.json" % [where, at])
		if tt == "quake" and has_house and not data.has_room(SolverData.sv(tr.get("room", ""))):
			e.append("%s.trigger.room '%s' not a room" % [where, tr.get("room", "")])
		for fk in tr.get("fixup_kinds", []):
			if not FIXUP_KINDS.has(SolverData.sv(fk)):
				e.append("%s.trigger.fixup_kinds '%s' not in %s" % [where, fk, FIXUP_KINDS])
		var ko: Variant = p.get("knock_on", null)
		if ko is Dictionary and (ko as Dictionary).get("prank", null) != null and not pranks.has(SolverData.sv(ko["prank"])):
			e.append("%s.knock_on.prank '%s' not in pranks.json" % [where, ko["prank"]])
		for r in p.get("residue", []):
			if has_res and not residues.has(SolverData.sv(r.get("kind", ""))):
				e.append("%s.residue '%s' not in residues.json" % [where, r.get("kind", "")])
		var reac: Dictionary = p.get("reaction", {}) if p.get("reaction", {}) is Dictionary else {}
		var arch := SolverData.sv(reac.get("archetype", ""))
		if arch == "":
			e.append("%s.reaction.archetype missing" % where)
		elif has_rx:
			var vs: Array = reac.get("variants", [])
			if vs.is_empty():
				if not rx.has(arch) and not rx.has(arch + "_a"):
					e.append("%s: reaction archetype '%s' not in reactions.json" % [where, arch])
			else:
				for v in vs:
					var key := "%s_%s" % [arch, SolverData.sv(v)]
					if not rx.has(key):
						e.append("%s: reaction '%s' not in reactions.json" % [where, key])
		var end_v: Variant = reac.get("end", null)
		if end_v is Dictionary and has_house and not data.has_room(SolverData.sv((end_v as Dictionary).get("room", ""))):
			e.append("%s.reaction.end.room '%s' not a room" % [where, (end_v as Dictionary).get("room", "")])
		for n in p.get("nights", []):
			if not eps.is_empty() and not eps.has(SolverData.sv(n)):
				e.append("%s.nights '%s' not in episodes/" % [where, n])
	if has_rx and not rx.has("suppressed"):
		e.append("reactions.json: no 'suppressed' archetype")
	for did in das:
		var d: Dictionary = das[did]
		for side in ["a", "b"]:
			if side == "b" and d.get("b", null) == null:
				# A headbutt Double Act (MARROW MAYHEM, CURTAIN CALL) ends in Beryl, not in a prank.
				var ko: Variant = pranks.get(SolverData.sv(d.get("a", "")), {}).get("knock_on", null)
				if ko is Dictionary and bool((ko as Dictionary).get("headbutt", false)):
					continue
			if not pranks.has(SolverData.sv(d.get(side, ""))):
				e.append("pranks.json: double_acts %s.%s '%s' not in pranks" % [did, side, SolverData.sv(d.get(side, null))])
		var dc := SolverData.sv(d.get("caption", ""))
		if dc.length() > MAX_CAPTION:
			e.append("pranks.json: double_acts %s.caption '%s' is %d characters (max %d)" % [did, dc, dc.length(), MAX_CAPTION])

	# --- residues ---------------------------------------------------------------------------
	for k in residues:
		if not FIXUP_KINDS.has(SolverData.sv(residues[k].get("fixup", ""))):
			e.append("residues.json: %s.fixup '%s' not in %s" % [k, residues[k].get("fixup", ""), FIXUP_KINDS])
	for cid in combos:
		var c: Dictionary = combos[cid]
		for k in c.get("of", []):
			if not residues.has(SolverData.sv(k)):
				e.append("residues.json: combo %s.of '%s' not a residue" % [cid, k])
		var cc := SolverData.sv(c.get("caption", ""))
		if cc.length() > MAX_CAPTION:
			e.append("residues.json: combo %s.caption '%s' is %d characters (max %d)" % [cid, cc, cc.length(), MAX_CAPTION])

	# --- clips ------------------------------------------------------------------------------
	var clips: Dictionary = parts.get("clips", {})
	for path in clips:
		var clip: Dictionary = clips[path]
		var cid := SolverData.sv(clip.get("clip", path.get_file().get_basename()))
		if not cid.get_file().begins_with("rx_"):
			continue
		var var_d: Variant = clip.get("variation", {})
		if var_d is Dictionary and float((var_d as Dictionary).get("time_jitter", 0.0)) != 0.0:
			e.append("%s: rx clip %s has variation.time_jitter %s (must be 0: the sim times reactions)" % [
				path.get_file(), cid, var_d["time_jitter"]])

	# --- episodes ---------------------------------------------------------------------------
	var rules_seen := {}
	for eid in data.sorted_ids("episodes"):
		e.append_array(_lint_episode(eid, eps[eid], data, pranks, das, combos, acts, items, residues, rules_seen))
	# --- D1: micro-gag cadence + the edge-bubble emote vocabulary (BeatLint; coverage runs in run_lints) -----
	e.append_array(BeatLint.lint(parts))
	# --- R3D: hides (C1) and the view data (C4) ---------------------------------------------------------------
	e.append_array(_lint_hides(parts, data))
	if parts.has("previews") or parts.has("rig_actions"):
		e.append_array(_ViewData.lint(parts, data))
	return e


## REDESIGN_3D §6.2 C1: every listed hiding spot is a hiding hotspot in the Night's rooms; one per room in Act I
## (final Nights); the safety-net pulse and hiding-spot cue targets are listed; every solution step that hides in,
## goes to or pops out towards a hotspot uses a live one.
static func _lint_hides(parts: Dictionary, data: SolverData) -> PackedStringArray:
	var e := PackedStringArray()
	var eps: Dictionary = parts.get("episodes", {})
	for eid in data.sorted_ids("episodes"):
		var ep: Dictionary = eps[eid]
		var f := "episodes/%s.json" % eid
		if ep.has("hides") and ep["hides"] != null:
			var listed := SolverData.as_ids(ep["hides"])
			var rooms := SolverData.as_ids(ep.get("rooms", []))
			var per := {}
			for hid in listed:
				if not data.has_hotspot(hid) or data.hotspot_kind(hid) != "hiding":
					e.append("%s: hides '%s' is not a hiding hotspot in house.json" % [f, hid])
					continue
				var r := data.hotspot_room(hid)
				if not rooms.has(r):
					e.append("%s: hides '%s' is in %s, not one of the Night's rooms" % [f, hid, r])
				per[r] = int(per.get(r, 0)) + 1
			if int(ep.get("act", 1)) <= 1 and SolverData.sv(ep.get("status", "draft")) == "final":
				for r in per:
					if int(per[r]) > 1:
						e.append("%s: hides lists %d hiding spots in %s (Act I: one per room)" % [f, per[r], r])
			var dir: Dictionary = ep.get("director", {}) if ep.get("director", {}) is Dictionary else {}
			var sn: Variant = dir.get("safety_net", {})
			var pulse := SolverData.sv((sn as Dictionary).get("pulse", "")) if sn is Dictionary else ""
			if pulse != "" and data.hotspot_kind(pulse) == "hiding" and not listed.has(pulse):
				e.append("%s: director.safety_net.pulse '%s' is struck (not in hides)" % [f, pulse])
			for c in dir.get("cues", []):
				var tgt := SolverData.sv((c as Dictionary).get("target", "")) if c is Dictionary else ""
				if tgt != "" and data.has_hotspot(tgt) and data.hotspot_kind(tgt) == "hiding" and not listed.has(tgt):
					e.append("%s: director cue %s targets the struck spot '%s'" % [f, (c as Dictionary).get("id", ""), tgt])
	var sols: Dictionary = parts.get("solutions", {})
	for eid in sols:
		if not data.episodes.has(String(eid)):
			continue
		var routes: Variant = (sols[eid] as Dictionary).get("routes", {})
		if not (routes is Dictionary):
			continue
		for rn in routes:
			var steps: Variant = (routes[rn] as Dictionary).get("steps", []) if routes[rn] is Dictionary else []
			if not (steps is Array):
				continue
			for i in (steps as Array).size():
				for m in SolutionDef.validate_live(steps[i], data, String(eid)):
					e.append("solutions/%s.json: %s step %d: %s" % [eid, rn, i + 1, m])
	return e


static func _lint_episode(eid: String, ep: Dictionary, data: SolverData, pranks: Dictionary, das: Dictionary,
		combos: Dictionary, acts: Dictionary, items: Dictionary, residues: Dictionary, rules_seen: Dictionary) -> PackedStringArray:
	var e := PackedStringArray()
	var f := "episodes/%s.json" % eid
	var prologue := ep.get("director", null) is Dictionary or int(ep.get("act", 1)) == 0
	var has_house := not data.house.is_empty()
	var rooms := PackedStringArray()
	for r in ep.get("rooms", []):
		rooms.append(SolverData.sv(r))
		if has_house and not data.has_room(SolverData.sv(r)):
			e.append("%s: rooms '%s' not in house.json" % [f, r])
	var status := SolverData.sv(ep.get("status", ""))
	if status != "draft" and status != "final":
		e.append("%s: status '%s' must be draft or final" % [f, status])
	for who in ["hush", "bellows"]:
		var st: Variant = (ep.get(who, {}) as Dictionary).get("start", null) if ep.get(who, {}) is Dictionary else null
		if st is Dictionary and has_house and not data.has_room(SolverData.sv((st as Dictionary).get("room", ""))):
			e.append("%s: %s.start.room '%s' not in house.json" % [f, who, (st as Dictionary).get("room", "")])
	# Loop.
	var loop := data.loop_ids(eid)
	if loop.is_empty():
		e.append("%s: bellows.loop is empty" % f)
	for a in loop:
		if not acts.is_empty() and not acts.has(a):
			e.append("%s: loop activity '%s' not in activities.json" % [f, a])
	# new_rule + card.
	var nr: Variant = ep.get("new_rule", null)
	if nr is Array:
		e.append("%s: new_rule must be ONE rule (a string), got %d" % [f, (nr as Array).size()])
	elif nr is String and String(nr) != "":
		if rules_seen.has(nr):
			e.append("%s: new_rule '%s' already introduced by %s (one new rule per Night)" % [f, nr, rules_seen[nr]])
		else:
			rules_seen[nr] = eid
	elif not prologue:
		e.append("%s: no new_rule (one per Night)" % f)
	var card: Variant = ep.get("card", null)
	if card is Dictionary:
		var words := SolverData.sv((card as Dictionary).get("text", "")).split(" ", false).size()
		if words > MAX_CARD_WORDS:
			e.append("%s: card is %d words (max %d)" % [f, words, MAX_CARD_WORDS])
	elif not prologue:
		e.append("%s: no loading card" % f)
	# Script shape.
	var lines: Array = ep.get("script", [])
	var bn := 0
	var normal := 0
	var ids := {}
	for l in lines:
		if not (l is Dictionary):
			e.append("%s: script entries must be objects" % f)
			continue
		var d: Dictionary = l
		var lid := SolverData.sv(d.get("id", ""))
		if ids.has(lid):
			e.append("%s: duplicate line id '%s'" % [f, lid])
		ids[lid] = true
		if bool(d.get("big_number", false)):
			bn += 1
		else:
			normal += 1
		var kind := SolverData.sv(d.get("kind", ""))
		if not LINE_KINDS.has(kind):
			e.append("%s: line %s kind '%s' not in %s" % [f, lid, kind, LINE_KINDS])
		if d.has("prank") and d["prank"] != null and not pranks.has(SolverData.sv(d["prank"])):
			e.append("%s: line %s prank '%s' not in pranks.json" % [f, lid, d["prank"]])
		if kind == "double_act" and not das.has(SolverData.sv(d.get("double_act", ""))):
			e.append("%s: line %s double_act '%s' not in pranks.json double_acts" % [f, lid, d.get("double_act", "")])
		if (kind == "combo" or kind == "combo_witnessed") and not combos.has(SolverData.sv(d.get("combo", ""))):
			e.append("%s: line %s combo '%s' not in residues.json combos" % [f, lid, d.get("combo", "")])
		var hint: Variant = d.get("hint", null)
		if hint is Dictionary:
			var h: Dictionary = hint
			if h.get("item", null) != null and not items.is_empty() and not items.has(SolverData.sv(h["item"])):
				e.append("%s: line %s hint.item '%s' not in items.json" % [f, lid, h["item"]])
			for hk in ["container", "rig_point"]:
				if h.get(hk, null) != null and has_house and not data.has_hotspot(SolverData.sv(h[hk])):
					e.append("%s: line %s hint.%s '%s' not in house.json" % [f, lid, hk, h[hk]])
			var when := SolverData.sv(h.get("when", null))
			if when != "" and not acts.is_empty() and not acts.has(when) and not HINT_MOMENTS.has(when):
				e.append("%s: line %s hint.when '%s' is neither an activity nor a moment %s" % [f, lid, when, HINT_MOMENTS])
	if prologue:
		if normal < 1 or normal > 6 or bn > 1:
			e.append("%s: the Prologue Script has %d line(s) + %d Big Number (want 1–6 + at most 1)" % [f, normal, bn])
	else:
		if normal < 3 or normal > 6:
			e.append("%s: Script has %d line(s) before the Big Number (want 3–6)" % [f, normal])
		if bn != 1:
			e.append("%s: Script has %d Big Number(s) (want exactly 1)" % [f, bn])
	if lines.size() > 7:
		e.append("%s: Script has %d lines (max 7)" % [f, lines.size()])
	# Bases.
	var prank_lines := 0
	for l in lines:
		if l is Dictionary and SolverData.sv(l.get("kind", "")) == "prank":
			prank_lines += 1
			var sz := SolverData.sv(pranks.get(SolverData.sv(l.get("prank", "")), {}).get("size", ""))
			if not SolverData.SIZE_WEIGHTS.has(sz) and pranks.has(SolverData.sv(l.get("prank", ""))):
				e.append("%s: line %s prank size '%s' has no weight" % [f, l.get("id", ""), sz])
	if prank_lines == 0:
		e.append("%s: no prank lines: prank bases cannot normalise to 700 tenths" % f)
	else:
		var bases := SolverData.normalise_bases(lines, pranks)
		var total := 0
		for k in bases:
			total += int(bases[k])
		if total != 700:
			e.append("%s: prank-line bases sum to %d tenths (want exactly 700)" % [f, total])
		for l in lines:
			if l is Dictionary and l.has("base_tenths"):
				e.append("%s: line %s stores base_tenths (derived at load; remove it)" % [f, l.get("id", "")])
	# Triggers in the loop; items in the rooms; fix-up stations on each floor.
	var ep_pranks := data.episode_pranks(eid)
	var fix_kinds_reachable := PackedStringArray()
	for p in ep_pranks:
		for r in pranks.get(p, {}).get("residue", []):
			var fk := SolverData.sv(residues.get(SolverData.sv(r.get("kind", "")), {}).get("fixup", ""))
			if fk != "" and not fix_kinds_reachable.has(fk):
				fix_kinds_reachable.append(fk)
	for p in ep_pranks:
		if not pranks.has(p):
			continue
		var tr: Dictionary = data.trigger(p)
		var tt := SolverData.sv(tr.get("type", ""))
		if tt == "use":
			var act := SolverData.sv(tr.get("activity", ""))
			if not loop.has(act):
				var via_fix := false
				for fk in tr.get("fixup_kinds", []):
					if fix_kinds_reachable.has(SolverData.sv(fk)):
						via_fix = true
				if not via_fix:
					e.append("%s: prank %s triggers on '%s', which is not in this Night's loop %s (and no fix-up reaches it)" % [f, p, act, loop])
		elif tt == "knock_on_only":
			var src_found := false
			for q in ep_pranks:
				if data.knock_on_target(q) == p:
					src_found = true
			if not src_found:
				e.append("%s: prank %s fires only by knock-on but no prank here knocks into it" % [f, p])
		elif tt == "quake" and not rooms.has(SolverData.sv(tr.get("room", ""))):
			e.append("%s: quake prank %s's room '%s' not in this Night's rooms" % [f, p, tr.get("room", "")])
		for i in data.prank_steps(p).size():
			var need := data.step_needs(p, i)
			if need == "":
				continue
			var src := data.item_source(need)
			if src == "":
				continue
			var sroom := data.hotspot_room(src)
			if has_house and not rooms.has(sroom):
				e.append("%s: prank %s needs '%s' from %s (%s), which is not in this Night's rooms %s" % [f, p, need, src, sroom, rooms])
		if has_house:
			for i2 in data.prank_steps(p).size():
				var rp := data.rig_point(p, i2)
				if data.has_hotspot(rp) and not rooms.has(data.hotspot_room(rp)):
					e.append("%s: prank %s rig point %s (%s) is not in this Night's rooms" % [f, p, rp, data.hotspot_room(rp)])
	if has_house:
		var floors := {}
		for r in rooms:
			floors[data.room_floor(r)] = true
		var overrides: Variant = ep.get("fixup_overrides", {})
		for fk in fix_kinds_reachable:
			# A Night may name the station for a kind (GDD §5.4): then any floor is fine.
			if overrides is Dictionary and (overrides as Dictionary).has(fk) and data.has_station(SolverData.sv(overrides[fk])):
				continue
			for fl in floors:
				var ok := false
				for s in data.house.get("stations", []):
					if (s.get("kinds", []) as Array).has(fk) and data.room_floor(SolverData.sv(s.get("room", ""))) == int(fl):
						ok = true
						break
				if not ok:
					e.append("%s: residue fix-up kind %s has no station on floor %d (used by this Night)" % [f, fk, int(fl)])
	return e
