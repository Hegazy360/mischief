## SliceClips — the one clip manifest of the Stage-2 slice (ruling L14; s2-view brief §4.1.10).
## Pure and headless: `build(skin := "") -> Array[Dictionary]` lists every clip the slice
## (P00, N01, N02 and the `g0_sneeze` dev episode) can play, one row per clip id:
##   {clip, rig, why, expect_f, tol_f, loop_ok, max_f, keys}
## `expect_f` = the length the clip must have (−1 = no fixed length: any length, or a loop where
## `loop_ok`), `tol_f` = the allowed difference, `loop_ok` = a looping clip is acceptable (the sim
## holds the state for a variable time), `max_f` = an upper bound (0 = none), `why` = every
## reason it is on the list, `keys` = the map keys / tables that select it.
##
## Sources, all data: `data/anim/clip_rules.json` (the one-shot / staging / curtain / cold-open
## rows), each rig's merged `map.json` keys the slice can select (its activities and detours,
## states, loco variants, doors / stairs only where a slice leg has them), the slice pranks'
## reactions from `reactions.json` (`<clip>_ko` where a knock-on can enter them, signature
## rounds), the `last_beat` pool, `bit_*` (`len_f` ± 2 f) and `mg_*` (`len_f` ± 12 f) from
## `activities.json`, the Figgis chip clips, and `SimOneshots.duration(id)` for `sim:` rows
## (s2-sim, soft; SimConst numbers until it lands). Combos only where `rules.combos` allows
## them; `skin: "pip"` swaps in the `skin:pip` overrides. Deterministic (sorted by clip id).
## Consumers: s2-sim's coverage lint, s2-rig's lint A24/A25/A29, `test_*_clips.gd`,
## `tests/slice/`, s2-integrate. A human-readable dump: `docs/review/s2-view/slice_clips.md`.
class_name SliceClips
extends RefCounted

const EPISODES: PackedStringArray = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy", "g0_sneeze"]
const SIM_ONESHOTS := "res://sim/world/sim_oneshots.gd"
const SIM_CONST := "res://sim/core/sim_const.gd"
const FIGGIS_CLIPS: PackedStringArray = ["figgis/f_idle", "figgis/f_psst", "figgis/f_point_card", "figgis/f_shh",
	"figgis/f_proud"]
const TEMPER_GAIN := {"S": 25, "M": 35, "L": 45, "SIG": 55}
const PREP_TIER := {"Q": "q", "S": "s", "B": "b"}
const BIT_TOL := 2
const MG_TOL := 12
const RX_TOL := 2
const LEGACY_MG_LEN := 48


## Every clip the slice can play (real data), for `skin` ("" | "pip").
static func build(skin: String = "") -> Array[Dictionary]:
	return SliceClips.build_from(SliceClips.load_db(), skin)


## The real data as a db Dictionary for build_from().
static func load_db() -> Dictionary:
	var db := {}
	var eps := {}
	for id in EPISODES:
		var e: Variant = ViewKit.json("res://data/episodes/%s.json" % id)
		if e is Dictionary:
			eps[id] = e
	db["episodes"] = eps
	db["pranks"] = SliceClips._dget(ViewKit.json("res://data/pranks.json"), "pranks", {})
	db["double_acts"] = SliceClips._dget(ViewKit.json("res://data/pranks.json"), "double_acts", {})
	var acts: Variant = ViewKit.json("res://data/activities.json")
	db["activities"] = acts if acts is Dictionary else {}
	var rx: Variant = ViewKit.json("res://data/reactions.json")
	db["reactions"] = rx if rx is Dictionary else {}
	db["residues"] = SliceClips._dget(ViewKit.json("res://data/residues.json"), "residues", {})
	db["combos"] = SliceClips._dget(ViewKit.json("res://data/residues.json"), "combos", {})
	db["rules"] = ClipRules.rows()
	db["maps"] = {"bellows": ClipMap.load_map("bellows"), "hush": ClipMap.load_map("hush")}
	db["oneshots"] = SliceClips.sim_durations(eps)
	var house: Variant = ViewKit.json(HouseLayout.HOUSE_JSON)
	db["house"] = house if house is Dictionary else {}
	return db


## `SimOneshots.DURATIONS` (s2-sim, soft) or the same numbers from SimConst; `enter` from the
## episodes' `hush.enter.busy_s`. −1 = variable.
static func sim_durations(episodes: Dictionary) -> Dictionary:
	var out := {}
	var so := ViewKit.soft_script(SIM_ONESHOTS)
	if so != null:
		var cm := so.get_script_constant_map()
		if cm.get("DURATIONS", null) is Dictionary:
			for k in cm["DURATIONS"]:
				out[ViewKit.s(k)] = int(cm["DURATIONS"][k])
	var sc := ViewKit.soft_script(SIM_CONST)
	var c: Dictionary = sc.get_script_constant_map() if sc != null else {}
	var fb := {
		"head_turn": int(c.get("HEAD_TURN_TICKS", 60)),
		"specs_on": int(c.get("SPECS_ON_TICKS", 12)),
		"doorway_pause": -1,
		"look_back": int(c.get("LOOK_BACK_TICKS", 60)),
		"bump": int(c.get("BUMP_PAT_TICKS", 30)) + int(c.get("BUMP_WALK_ON_TICKS", 40)) + int(c.get("BUMP_TURN_TICKS", 12)),
		"bump_look": -1,
		"curious_stop": int(c.get("CURIOUS_STOP_TICKS", 60)),
		"curious_look": int(c.get("CURIOUS_LOOK_TICKS", 180)),
		"chase_wheeze": int(c.get("CHASE_WHEEZE", 90)),
		"stun": int(c.get("DOOR_SLAM_STUN", 60)),
		"face_to_face": int(c.get("FACE_TO_FACE_TICKS", 48)),
		"fizzle": int(c.get("FIZZLE_TICKS", 30)),
		"caught:grab": int(c.get("CAUGHT_BUSTED", 60)),
		"caught:busted": int(c.get("CAUGHT_BUSTED", 60)),
		"caught:lecture": int(c.get("CAUGHT_LECTURE", 132)),
		"caught:wipe": int(c.get("CAUGHT_WIPE", 12)),
		"caught:doorstep": int(c.get("CAUGHT_HOLD", 240)) - int(c.get("CAUGHT_DOORSTEP_AT", 204)),
		"wheeze": -1,
	}
	for k in fb:
		if not out.has(k):
			out[k] = fb[k]
	if not out.has("enter"):
		var n := -1
		for id in episodes:
			var h: Variant = (episodes[id] as Dictionary).get("hush", {})
			var en: Variant = (h as Dictionary).get("enter", null) if h is Dictionary else null
			if en is Dictionary:
				n = maxi(n, int(round(float((en as Dictionary).get("busy_s", 0.0)) * 60.0)))
		out["enter"] = n
	return out


## The manifest from a db Dictionary (fixture tests build their own; see load_db for keys).
static func build_from(db: Dictionary, skin: String = "") -> Array[Dictionary]:
	var acc := {}
	var eps: Dictionary = db.get("episodes", {})
	var ids := PackedStringArray()
	for id in EPISODES:
		if eps.has(id):
			ids.append(id)
	for id in eps:
		if not ids.has(ViewKit.s(id)):
			ids.append(ViewKit.s(id))
	for ep_id in ids:
		SliceClips._episode(acc, db, ep_id, eps[ep_id], skin)
	for f in FIGGIS_CLIPS:
		SliceClips._add(acc, f, "figgis", "figgis chip", -1, 0, f == "figgis/f_idle", "figgis", 0)
	var keys := acc.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for k in keys:
		var row: Dictionary = acc[k]
		row["why"] = "; ".join(row["why"])
		row["keys"] = ", ".join(row["keys"])
		out.append(row)
	return out


# --- one episode ------------------------------------------------------------------------

static func _episode(acc: Dictionary, db: Dictionary, ep_id: String, ep: Dictionary, skin: String) -> void:
	var pranks_db: Dictionary = db.get("pranks", {})
	var acts_db: Dictionary = db.get("activities", {})
	var rx: Dictionary = db.get("reactions", {})
	var maps: Dictionary = db.get("maps", {})
	var bm: Dictionary = maps.get("bellows", {})
	var hm: Dictionary = maps.get("hush", {})
	var tag := SliceClips._short(ep_id)
	var rules_d: Dictionary = ep.get("rules", {}) if ep.get("rules", {}) is Dictionary else {}
	var senses := bool(rules_d.get("senses", true))
	var cant_fail := bool(rules_d.get("cant_fail", false))
	var can_catch := senses and not cant_fail
	# pranks of this Night (script lines + double acts)
	var pranks := PackedStringArray()
	for l in ep.get("script", []):
		if not (l is Dictionary):
			continue
		var ld: Dictionary = l
		var pv := ViewKit.s(ld.get("prank", ""))
		if pv != "" and not pranks.has(pv):
			pranks.append(pv)
		var da := ViewKit.s(ld.get("double_act", ""))
		if da != "":
			var dd: Variant = (db.get("double_acts", {}) as Dictionary).get(da, null)
			if dd is Dictionary:
				for side in ["a", "b"]:
					var sp := ViewKit.s((dd as Dictionary).get(side, ""))
					if sp != "" and not pranks.has(sp):
						pranks.append(sp)
	# activities (loop + detours this Night's residues can queue + the scripted ones)
	var acts := PackedStringArray()
	var bl: Dictionary = ep.get("bellows", {}) if ep.get("bellows", {}) is Dictionary else {}
	for e in bl.get("loop", []):
		var a := ViewKit.s((e as Dictionary).get("a", "")) if e is Dictionary else ViewKit.s(e)
		if a != "" and not acts.has(a):
			acts.append(a)
	var temper := 0
	var blind := false
	var residues := PackedStringArray()
	for p in pranks:
		var pd: Dictionary = pranks_db.get(p, {})
		temper += int(TEMPER_GAIN.get(ViewKit.s(pd.get("size", "M")), 35))
		for r in pd.get("residue", []):
			if r is Dictionary:
				var kind := ViewKit.s((r as Dictionary).get("kind", ""))
				if kind != "" and not residues.has(kind):
					residues.append(kind)
				blind = blind or bool((r as Dictionary).get("blind", false))
	var res_db: Dictionary = db.get("residues", {})
	var det_db: Dictionary = acts_db.get("detours", {})
	for kind in residues:
		var fix := ViewKit.s((res_db.get(kind, {}) as Dictionary).get("fixup", "")) if res_db.get(kind, null) is Dictionary else ""
		if fix != "":
			var did := "fixup_" + fix.to_lower()
			if not acts.has(did):
				acts.append(did)
	if det_db.has("curious") and not acts.has("curious"):
		acts.append("curious")
	var livid := temper >= 70
	var melt := temper >= 100 and not cant_fail
	# Bellows: loco + states
	var bw := "%s: bellows" % tag
	SliceClips._key(acc, bm, "idle", "bellows", bw, skin)
	SliceClips._key(acc, bm, "walk", "bellows", bw, skin)
	SliceClips._key(acc, bm, "turn", "bellows", bw, skin)
	SliceClips._key(acc, bm, "walk@tier2", "bellows", bw, skin)
	if livid:
		SliceClips._key(acc, bm, "walk@tier3", "bellows", bw, skin)
	if blind:
		SliceClips._key(acc, bm, "walk@blind", "bellows", bw, skin)
	if SliceClips._has_link(db, ep, "door"):
		SliceClips._key(acc, bm, "door", "bellows", bw, skin)
		SliceClips._key(acc, hm, "door", "hush", "%s: hush" % tag, skin)
	if SliceClips._has_link(db, ep, "stairs"):
		for k in ["stairs_up", "stairs_down"]:
			SliceClips._key(acc, bm, k, "bellows", bw, skin)
			SliceClips._key(acc, hm, k, "hush", "%s: hush" % tag, skin)
	if can_catch:
		for k in ["run", "state:spotted", "state:chase", "state:search", "walk@on_guard"]:
			SliceClips._key(acc, bm, k, "bellows", bw, skin)
	if melt:
		SliceClips._key(acc, bm, "state:meltdown", "bellows", bw, skin)
		SliceClips._key(acc, bm, "state:exhausted", "bellows", bw, skin)
	for a in acts:
		var ak := "activity:" + a
		if bm.has(ak) or ClipMap.entry(bm, ak, skin) != null:
			SliceClips._key(acc, bm, ak, "bellows", bw, skin)
		else:
			var ad: Variant = (acts_db.get("activities", {}) as Dictionary).get(a, (det_db.get(a, null)))
			var ac := ViewKit.s((ad as Dictionary).get("clip", "")) if ad is Dictionary else ""
			if ac != "":
				SliceClips._add(acc, ac, "bellows", "%s %s (activities.json)" % [bw, ak], -1, 0, true, ak, 0)
	# squeak bits of the Night's activities (+ the Livid bit where Livid is reachable)
	var bits_db: Dictionary = acts_db.get("squeak_bits", {})
	for bit_id in bits_db:
		var bd: Dictionary = bits_db[bit_id]
		var ba := ViewKit.s(bd.get("activity", "")) if bd.get("activity", null) != null else ""
		var ok := acts.has(ba) or (ba == "" and ViewKit.s(bd.get("while_tier", "")) == "livid" and livid)
		if not ok:
			continue
		var key := "bit:%s" % bit_id
		var clip := ClipMap.clip_of(ClipMap.entry(bm, key, skin))
		if clip == "":
			clip = ViewKit.s(bd.get("clip", ""))
		SliceClips._add(acc, clip, "bellows", "%s %s" % [bw, key], int(bd.get("len_f", -1)), BIT_TOL, false, key, 0)
	# micro-gags of the Night's activities (+ walk beats)
	for a2 in acts:
		var ad2: Variant = (acts_db.get("activities", {}) as Dictionary).get(a2, det_db.get(a2, null))
		if not (ad2 is Dictionary):
			continue
		for mg in (ad2 as Dictionary).get("micro_gags", []):
			var mid := ViewKit.s((mg as Dictionary).get("id", "")) if mg is Dictionary else ViewKit.s(mg)
			var mlen := int((mg as Dictionary).get("len_f", LEGACY_MG_LEN)) if mg is Dictionary else LEGACY_MG_LEN
			SliceClips._mg(acc, bm, mid, mlen, "%s activity:%s" % [bw, a2], skin)
	var wb: Variant = acts_db.get("walk_beats", null)
	if wb is Dictionary:
		for mg2 in (wb as Dictionary).get("ids", []):
			if mg2 is Dictionary:
				SliceClips._mg(acc, bm, ViewKit.s((mg2 as Dictionary).get("id", "")), int((mg2 as Dictionary).get("len_f", LEGACY_MG_LEN)),
					"%s walk beat" % bw, skin)
	# reactions of the Night's pranks
	var arch_db: Dictionary = rx.get("archetypes", {}) if rx.get("archetypes", {}) is Dictionary else {}
	var ko_targets := PackedStringArray()
	for p2 in pranks:
		var ko: Variant = (pranks_db.get(p2, {}) as Dictionary).get("knock_on", null)
		if ko is Dictionary and pranks.has(ViewKit.s((ko as Dictionary).get("prank", ""))):
			ko_targets.append(ViewKit.s((ko as Dictionary).get("prank", "")))
	for p3 in pranks:
		var pd3: Dictionary = pranks_db.get(p3, {})
		var rd: Dictionary = pd3.get("reaction", {}) if pd3.get("reaction", {}) is Dictionary else {}
		var arch := ViewKit.s(rd.get("archetype", ""))
		if arch == "":
			continue
		var variants: Array = rd.get("variants", [])
		var keys_v: Array = []
		if arch.begins_with("sig_") or variants.is_empty():
			keys_v.append(arch)
		else:
			for v in variants:
				keys_v.append("%s_%s" % [arch, ViewKit.s(v)])
		for ak2 in keys_v:
			var ae: Variant = arch_db.get(ak2, null)
			var clip2 := ViewKit.s((ae as Dictionary).get("clip", "")) if ae is Dictionary else ""
			if clip2 == "":
				clip2 = ViewSnapshot.reaction_clip(null, arch, ViewKit.s(ak2).trim_prefix(arch + "_") if not arch.begins_with("sig_") else "")
			var frames := int((ae as Dictionary).get("frames", -1)) if ae is Dictionary else -1
			SliceClips._add(acc, clip2, "bellows", "%s %s reaction (%s)" % [bw, p3, ak2], frames, RX_TOL, false, "reaction", 0)
			if ko_targets.has(p3):
				SliceClips._add(acc, clip2 + "_ko", "bellows", "%s %s knock-on entry" % [bw, p3], frames, RX_TOL, false, "reaction:_ko", 0)
		if arch == "sig_mirror_mirror":
			var mr: Variant = rx.get("mirror_rounds", {})
			if mr is Dictionary:
				var cl: Array = (mr as Dictionary).get("clips", [])
				var rf: Array = (mr as Dictionary).get("rounds_f", [])
				for i in cl.size():
					SliceClips._add(acc, ViewKit.s(cl[i]), "bellows", "%s %s round %d" % [bw, p3, i + 1],
						int(rf[i]) if i < rf.size() else -1, RX_TOL, false, "mirror_rounds", 0)
	# last beats: the T3 pool + the every-4th slow burn (L5)
	var ct: Dictionary = rx.get("clip_timings", {}) if rx.get("clip_timings", {}) is Dictionary else {}
	var pool: Array = rx.get("t3_last_beats", []) if rx.get("t3_last_beats", []) is Array else []
	var beats := PackedStringArray()
	if livid:
		for b in pool:
			beats.append(ViewKit.s(b))
	if not beats.has("bellows/beat_slow_burn") and pranks.size() >= 1:
		beats.append("bellows/beat_slow_burn")
	for b2 in beats:
		SliceClips._add(acc, b2, "bellows", "%s last beat" % bw, SliceClips._ct_frames(ct, b2), RX_TOL, false, "reaction:last_beat", 0)
	# combos this Night allows (and can form from its residues)
	var allowed: Variant = rules_d.get("combos", null)
	var combos_db: Dictionary = db.get("combos", {})
	for cid in combos_db:
		var cd: Dictionary = combos_db[cid]
		if allowed is Array and not (allowed as Array).has(cid):
			continue
		var of: Array = cd.get("of", [])
		var can := not of.is_empty()
		for k in of:
			can = can and residues.has(ViewKit.s(k))
		if not can:
			continue
		var cc := ViewKit.s(cd.get("clip", "bellows/combo_%s" % cid))
		SliceClips._add(acc, cc, "bellows", "%s combo %s" % [bw, cid], SliceClips._ct_frames(ct, cc), RX_TOL, false, "combo", 0)
	# Hush
	var hw := "%s: hush" % tag
	for k2 in ["idle", "idle_fidgets", "walk", "run", "turn", "state:rummage", "state:pick_window", "state:rigging",
			"state:diving", "state:popping", "state:squeaking", "freeze", "freeze_midjob"]:
		SliceClips._key(acc, hm, k2, "hush", hw, skin)
	var tiers := PackedStringArray()
	for p4 in pranks:
		for st in (pranks_db.get(p4, {}) as Dictionary).get("steps", []):
			if st is Dictionary:
				var t := ViewKit.s(PREP_TIER.get(ViewKit.s((st as Dictionary).get("prep", "Q")), "q"))
				if not tiers.has(t):
					tiers.append(t)
	tiers.sort()
	for t2 in tiers:
		SliceClips._key(acc, hm, "rigging@" + t2, "hush", hw, skin)
	if can_catch:
		SliceClips._key(acc, hm, "state:caught", "hush", hw, skin)
	if not cant_fail and ep_id != "g0_sneeze":
		SliceClips._key(acc, hm, "state:bowing", "hush", hw, skin)
	# clip_rules.json rows that apply to this Night
	for r in db.get("rules", []):
		if not (r is Dictionary):
			continue
		SliceClips._rule(acc, db, r, ep_id, tag, maps, skin, {"can_catch": can_catch, "melt": melt, "cant_fail": cant_fail,
			"acts": acts})


static func _rule(acc: Dictionary, db: Dictionary, r: Dictionary, ep_id: String, tag: String, maps: Dictionary, skin: String,
		flags: Dictionary) -> void:
	var can_catch := bool(flags.get("can_catch", true))
	var melt := bool(flags.get("melt", true))
	var acts: PackedStringArray = flags.get("acts", PackedStringArray())
	var eps: Variant = r.get("episodes", "all")
	if eps is Array and not (eps as Array).has(ep_id):
		return
	var key := ViewKit.s(r.get("key", ""))
	var rig := ViewKit.s(r.get("rig", ""))
	if key.ends_with("*"):
		return   # bit:* / mg:* are expanded from activities.json above
	if key.begins_with("oneshot:caught") and not can_catch:
		return
	if (key == "state:meltdown" or key == "state:exhausted") and not melt:
		return
	if key.begins_with("cold:") and key != "cold:" + ep_id:
		return
	if key == "oneshot:yanked" and not bool(flags.get("cant_fail", false)):
		return
	if key == "oneshot:curious_stop" or key == "oneshot:curious_look":
		if not acts.has("curious"):
			return
	var layer := ViewKit.s(r.get("layer", "base"))
	if layer == "fx" or layer == "none":
		return
	var m: Dictionary = maps.get(rig, {})
	var clips := PackedStringArray()
	var e: Variant = ClipMap.entry(m, key, skin) if not m.is_empty() else null
	if e != null:
		clips = ClipMap.clips_of(e)
	else:
		var skv: Variant = (r.get("skin", {}) as Dictionary).get(skin, null) if skin != "" and r.get("skin", null) is Dictionary else null
		clips = ClipMap.clips_of(skv if skv != null else r.get("clips", r.get("clip", "")))
		var th := ViewKit.s(r.get("then", ""))
		if th != "":
			clips.append(th)
	var ln: Dictionary = r.get("len", {}) if r.get("len", {}) is Dictionary else {}
	var src := ViewKit.s(ln.get("src", "clip"))
	var loop_ok := bool(ln.get("loop_ok", false))
	var tol := int(ln.get("tol_f", 0))
	var max_f := int(ln.get("max_f", 0))
	var rx: Dictionary = db.get("reactions", {})
	var ct: Dictionary = rx.get("clip_timings", {}) if rx.get("clip_timings", {}) is Dictionary else {}
	var then_c := ViewKit.s(r.get("then", ""))
	if e is Dictionary and ViewKit.s((e as Dictionary).get("then", "")) != "":
		then_c = ViewKit.s((e as Dictionary)["then"])
	var ep: Dictionary = (db.get("episodes", {}) as Dictionary).get(ep_id, {})
	if key == "oneshot:enter":
		var hd: Variant = ep.get("hush", {})
		if not (hd is Dictionary and (hd as Dictionary).get("enter", null) is Dictionary):
			return   # this Night has no climb-in
	for c in clips:
		var expect := int(ln.get("expect_f", -1))
		if src == "sim:enter":
			var en: Dictionary = (ep.get("hush", {}) as Dictionary).get("enter", {})
			expect = int(round(float(en.get("busy_s", 0.0)) * 60.0)) if en.has("busy_s") else -1
		elif src.begins_with("sim:"):
			expect = int((db.get("oneshots", {}) as Dictionary).get(src.substr(4), -1))
		elif src == "clip_timings":
			expect = SliceClips._ct_frames(ct, c)
		elif src.begins_with("caught:"):
			var span: Variant = (rx.get("caught", {}) as Dictionary).get(src.substr(7), null) if rx.get("caught", null) is Dictionary else null
			if span is Array and (span as Array).size() >= 2:
				expect = int(span[1]) - int(span[0])
		var mx := max_f
		# A clip pair sharing one phase (doorstep → tomato): together they fill it, so neither
		# has a fixed length; both stay within it.
		if then_c != "":
			if expect > 0:
				mx = expect
			expect = -1
		var lok := loop_ok
		if expect < 0 and src.begins_with("sim:") and then_c == "":
			lok = true
		SliceClips._add(acc, c, rig, "%s: %s %s" % [tag, rig, key], expect, tol, lok, key, mx)


static func _mg(acc: Dictionary, bm: Dictionary, mid: String, mlen: int, why: String, skin: String) -> void:
	if mid == "":
		return
	var key := "mg:" + mid
	var clip := ClipMap.clip_of(ClipMap.entry(bm, key, skin))
	if clip == "":
		clip = "bellows/mg_" + mid
	SliceClips._add(acc, clip, "bellows", "%s %s" % [why, key], mlen, MG_TOL, false, key, 0)


## Every clip a map key names, with the clip_rules.json row's expectation when it has one.
static func _key(acc: Dictionary, m: Dictionary, key: String, rig: String, why: String, skin: String) -> void:
	if not ClipRules.row(key, rig).is_empty():
		return   # the clip_rules.json row owns this key's expectation (added by _rule)
	var e: Variant = ClipMap.entry(m, key, skin)
	if e == null:
		return
	var loop_ok := true
	if e is Dictionary and (e as Dictionary).has("loop"):
		loop_ok = bool((e as Dictionary)["loop"])
	var one_shot := ["turn", "state:spotted", "state:diving", "state:popping", "state:squeaking", "state:rummage",
		"state:caught", "door", "idle_fidgets"].has(key)
	for c in ClipMap.clips_of(e):
		SliceClips._add(acc, c, rig, "%s %s" % [why, key], -1, 0, loop_ok and not one_shot, key, 0)


static func _add(acc: Dictionary, clip: String, rig: String, why: String, expect_f: int, tol_f: int, loop_ok: bool, key: String,
		max_f: int) -> void:
	if clip == "":
		return
	if not acc.has(clip):
		acc[clip] = {"clip": clip, "rig": rig if rig != "" else clip.get_slice("/", 0), "why": PackedStringArray(),
			"expect_f": expect_f, "tol_f": tol_f, "loop_ok": loop_ok, "max_f": max_f, "keys": PackedStringArray()}
	var row: Dictionary = acc[clip]
	var w: PackedStringArray = row["why"]
	if not w.has(why):
		w.append(why)
	var ks: PackedStringArray = row["keys"]
	if not ks.has(key):
		ks.append(key)
	# Merge: the first fixed length wins, a loop is fine if any source allows it, the tightest
	# tolerance and bound win.
	if int(row["expect_f"]) < 0 and expect_f >= 0:
		row["expect_f"] = expect_f
		row["tol_f"] = tol_f
	elif expect_f >= 0 and tol_f < int(row["tol_f"]):
		row["tol_f"] = tol_f
	row["loop_ok"] = bool(row["loop_ok"]) or loop_ok
	if max_f > 0 and (int(row["max_f"]) == 0 or max_f < int(row["max_f"])):
		row["max_f"] = max_f


static func _has_link(db: Dictionary, ep: Dictionary, kind: String) -> bool:
	var h: Dictionary = db.get("house", {})
	var rooms := PackedStringArray()
	for r in ep.get("rooms", []):
		rooms.append(ViewKit.s(r))
	var bs: Variant = ep.get("backstage", [])
	if bs is Array:
		for r2 in bs:
			rooms.append(ViewKit.s(r2))
	for l in h.get("links", []):
		if not (l is Dictionary):
			continue
		var ld: Dictionary = l
		if ViewKit.s(ld.get("kind", "")) == kind and rooms.has(ViewKit.s(ld.get("a", ""))) and rooms.has(ViewKit.s(ld.get("b", ""))):
			return true
	return false


static func _ct_frames(ct: Dictionary, clip: String) -> int:
	var e: Variant = ct.get(clip, null)
	return int((e as Dictionary).get("frames", -1)) if e is Dictionary else -1


static func _short(ep_id: String) -> String:
	return ep_id.get_slice("_", 0)


static func _dget(d: Variant, k: String, def: Variant) -> Variant:
	if d is Dictionary:
		var v: Variant = (d as Dictionary).get(k, def)
		return v if v != null else def
	return def


## A human-readable dump (docs/review/s2-view/slice_clips.md).
static func to_markdown(rows: Array[Dictionary], title: String = "Slice clip manifest") -> String:
	var lines := PackedStringArray()
	lines.append("# %s" % title)
	lines.append("")
	lines.append("Generated by `SliceClips.build()` (`game/view/world/slice_clips.gd`) from `data/anim/clip_rules.json`, the rigs' merged `map.json`, `reactions.json`, `activities.json`, the slice episodes and `SimOneshots`. %d clips. `expect` = frames the clip must have (± tol; −1 = any), `loop` = a looping clip is acceptable, `max` = an upper bound." % rows.size())
	lines.append("")
	lines.append("| clip | rig | expect | tol | loop | max | keys | why |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r in rows:
		lines.append("| `%s` | %s | %d | %d | %s | %d | %s | %s |" % [r["clip"], r["rig"], int(r["expect_f"]), int(r["tol_f"]),
			"yes" if bool(r["loop_ok"]) else "", int(r["max_f"]), ViewKit.s(r["keys"]), ViewKit.s(r["why"])])
	return "\n".join(lines) + "\n"
