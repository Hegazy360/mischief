## Content data checks (standalone JSON, no ContentDB): files, items, activities, pranks, Double Acts,
## reactions (GDD §9.3 timing rules), residues/combos and barks. Episodes + solutions: test_content_episodes.gd.
extends TestBase

const C := preload("res://tests/content/content_canon.gd")

var items: Dictionary = {}
var acts: Dictionary = {}
var detours: Dictionary = {}
var bits: Dictionary = {}
var pranks: Dictionary = {}
var das: Dictionary = {}
var rx: Dictionary = {}
var residues: Dictionary = {}
var combos: Dictionary = {}
var barks: Dictionary = {}


func before_each() -> void:
	items = _sub(C.read("items.json"), "items")
	var a: Variant = C.read("activities.json")
	acts = _sub(a, "activities")
	detours = _sub(a, "detours")
	bits = _sub(a, "squeak_bits")
	var p: Variant = C.read("pranks.json")
	pranks = _sub(p, "pranks")
	das = _sub(p, "double_acts")
	rx = C.read("reactions.json") if C.read("reactions.json") is Dictionary else {}
	var r: Variant = C.read("residues.json")
	residues = _sub(r, "residues")
	combos = _sub(r, "combos")
	barks = C.read("barks.json") if C.read("barks.json") is Dictionary else {}


static func _sub(d: Variant, key: String) -> Dictionary:
	if d is Dictionary and (d as Dictionary).get(key) is Dictionary:
		return d[key]
	return {}


static func _keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in d.keys():
		out.append(String(k))
	out.sort()
	return out


static func _sorted(a: Array[String]) -> Array[String]:
	var b := a.duplicate()
	b.sort()
	return b


func test_every_file_parses_with_version_1() -> void:
	var files := ["items.json", "pranks.json", "activities.json", "reactions.json", "residues.json", "barks.json"]
	for e in C.EPISODES:
		files.append("episodes/%s.json" % e)
	for e in C.FINAL_EPISODES:
		files.append("solutions/%s.json" % e)
	for f in files:
		var d: Variant = C.read(f)
		if not assert_true(d is Dictionary, "%s parses to an object" % f):
			continue
		assert_eq(int(d.get("version", 0)), 1, "%s version" % f)


func test_items_match_canon_and_cross_reference() -> void:
	assert_eq(_keys(items), _sorted(C.ITEMS), "item ids")
	for id in items:
		var it: Dictionary = items[id]
		assert_true(String(it.get("name", "")) != "", "%s name" % id)
		assert_eq(it.get("icon"), "res://art/house/items/%s.svg" % id, "%s icon" % id)
		assert_true(C.CONTAINERS.has(it.get("source")), "%s source container %s" % [id, it.get("source")])
		assert_eq(int(it.get("count", 0)), 3 if id == "coins" else 1, "%s count" % id)
		for p in it.get("pranks", []):
			if not assert_true(pranks.has(p), "%s serves unknown prank %s" % [id, p]):
				continue
			var needs: Array = []
			for s in pranks[p]["steps"]:
				needs.append(s.get("needs"))
				if s.get("setup") is Dictionary:
					needs.append(s["setup"].get("item"))
			assert_has(needs, id, "%s is used by %s's steps" % [id, p])
	# every needed item lists the prank back
	for p in pranks:
		for s in pranks[p]["steps"]:
			var n: Variant = s.get("needs")
			if n != null:
				assert_has(items.get(n, {}).get("pranks", []), p, "item %s lists %s" % [n, p])


func test_activities_match_canon() -> void:
	assert_eq(_keys(acts), _sorted(C.ACTIVITIES), "activity ids")
	assert_eq(_keys(detours), _sorted(C.DETOURS), "detour ids")
	assert_eq(_keys(bits), _sorted(C.SQUEAK_BITS), "squeak bit ids")
	var used_bits: Array[String] = []
	for id in acts:
		var a: Dictionary = acts[id]
		assert_true(C.STATIONS.has(a.get("station")), "%s station %s" % [id, a.get("station")])
		assert_gt(float(a.get("dur_s", 0)), 0.0, "%s dur" % id)
		assert_true(int(a.get("facing", 0)) in [-1, 1], "%s facing" % id)
		assert_true(a.get("specs") is bool, "%s specs bool" % id)
		assert_has(["normal", "absorbed", "asleep", "blind"], a.get("awareness"), "%s awareness" % id)
		var b: Variant = a.get("squeak_bit")
		if b != null:
			assert_true(bits.has(b), "%s bit %s" % [id, b])
			used_bits.append(String(b))
		assert_true(a.get("bar") in [null, "sleep", "bath"], "%s bar" % id)
		if a.get("in_use") != null:
			assert_true(C.HIDING.has(a["in_use"]), "%s in_use %s" % [id, a["in_use"]])
			assert_eq(C.HIDING[a["in_use"]][1], id, "%s in-use spot is that activity's" % id)
		assert_eq(a.get("clip"), "bellows/act_%s" % id, "%s clip" % id)
		assert_eq(a.get("icon"), "res://art/icons/activities/%s.svg" % id, "%s icon" % id)
	# GDD §4.1.1 flags
	for id in ["warmup", "piano", "rehearse"]:
		assert_true(acts[id]["panto"], "%s panto" % id)
	for id in ["feed_beryl", "marrow"]:
		assert_true(acts[id]["bend"], "%s bend" % id)
	for id in ["paper", "polish", "hunt"]:
		assert_true(acts[id]["specs"], "%s specs on" % id)
	assert_eq(acts["clock"]["in_use"], "hall_clock_case")
	assert_eq(acts["bath"]["in_use"], "bathroom_bath")
	assert_eq(acts["dress"]["in_use"], "bedroom_wardrobe")
	assert_eq(acts["bath"]["awareness"], "absorbed")
	assert_eq(acts["nap"]["awareness"], "asleep")
	assert_eq([acts["stroll"]["path"]["from_x"], acts["stroll"]["path"]["to_x"]], [5260, 5560], "stroll path")
	var durs := {"warmup": 10, "tea": 10, "pickles": 6, "snack": 6, "rinse": 5, "paper": 12, "fire": 6, "mirror": 6,
		"phone": 8, "clock": 5, "piano": 12, "gargle": 5, "bath": 24, "radiator": 5, "dress": 6, "nap": 18,
		"feed_beryl": 6, "roses": 8, "marrow": 6, "stroll": 6, "polish": 8, "cloak": 6, "answer_door": 6,
		"host_tea": 14, "tango": 12, "rehearse": 14, "hunt": 6}
	for id in durs:
		if C.D1_DURATIONS.has(id):
			assert_eq(int(acts[id]["dur_s"]), int(C.D1_DURATIONS[id]), "%s duration (D1 deviation from GDD §4.1.1)" % id)
		else:
			assert_eq(int(acts[id]["dur_s"]), durs[id], "%s duration (GDD §4.1.1)" % id)
		assert_true(float(acts[id]["dur_s"]) >= 5.0, "%s dur_s >= 5 s (the bubble ring reads)" % id)
	for id in bits:
		var bit: Dictionary = bits[id]
		assert_eq(bit.get("clip"), "bellows/%s" % id, "%s clip" % id)
		assert_between(int(bit.get("len_f", 0)), 60, 120, "%s length" % id)
		if id != "bit_livid":
			assert_has(used_bits, id, "%s used by an activity" % id)
	for id in detours:
		var d: Dictionary = detours[id]
		assert_true(String(d.get("clip", "")).begins_with("bellows/"), "%s clip" % id)
		assert_eq(d.get("icon"), "res://art/icons/activities/%s.svg" % id, "%s icon" % id)
		if id.begins_with("fixup_"):
			assert_eq(d.get("kind"), id.trim_prefix("fixup_").to_upper(), "%s kind" % id)
			assert_eq(float(d.get("dur_s")), 4.0, "%s 4 s" % id)
			assert_eq(float(d.get("mark_s")), 1.0, "%s hooks at 1 s" % id)


func test_pranks_match_canon_and_resolve() -> void:
	assert_eq(_keys(pranks), _sorted(C.PRANKS), "prank ids")
	var sizes := {"S": 0, "M": 0, "L": 0, "SIG": 0}
	for id in pranks:
		var p: Dictionary = pranks[id]
		assert_between(String(p.get("caption", "")).length(), 1, 18, "%s caption <= 18" % id)
		assert_true(sizes.has(p.get("size")), "%s size" % id)
		sizes[p["size"]] = int(sizes.get(p["size"], 0)) + 1
		var rp := String(p.get("rig_point", ""))
		if assert_true(C.RIG_POINTS.has(rp), "%s rig point %s" % [id, rp]):
			assert_has(C.RIG_POINTS[rp][1], id, "%s rig point maps to it (TECH §14)" % id)
		var steps: Array = p.get("steps", [])
		assert_between(steps.size(), 1, 3, "%s steps" % id)
		for s in steps:
			assert_has(["Q", "S", "B"], s.get("prep"), "%s prep" % id)
			if s.get("needs") != null:
				assert_true(items.has(s["needs"]), "%s needs %s" % [id, s["needs"]])
			if s.has("at"):
				assert_true(C.RIG_POINTS.has(s["at"]), "%s step at %s" % [id, s["at"]])
			for c in s.get("conditions", []):
				_check_prank_condition(id, c)
		_check_trigger(id, p)
		for c in p.get("conditions", []):
			_check_prank_condition(id, c)
		_check_reaction_ref(id, p)
		for r in p.get("residue", []):
			assert_has(C.RESIDUES, r.get("kind"), "%s residue" % id)
		for n in p.get("nights", []):
			assert_has(C.EPISODES, n, "%s night %s" % [id, n])
		assert_gt((p.get("nights", []) as Array).size(), 0, "%s appears in a Night" % id)
	assert_eq(sizes, {"S": 1, "M": 18, "L": 7, "SIG": 6}, "size mix (GDD §5.7)")
	# GDD-specified shapes
	assert_eq(pranks["in_over_his_head"]["steps"].size(), 2, "IN OVER HIS HEAD has 2 steps")
	var pp: Array = pranks["penny_pincher"]["steps"]
	assert_eq(pp.size(), 3, "PENNY PINCHER 3 steps")
	for i in pp.size():
		assert_eq(pp[i].get("at"), "garden_coin_%d" % (i + 1))
		assert_eq(pp[i].get("needs"), "coins")
	assert_eq(pranks["kidding_around"]["steps"][0]["conditions"], [{"beryl_within": 150}], "tuck-in condition")
	assert_eq(pranks["rug_burn"]["conditions"], [{"tier_min": "steaming", "or_chase": true}])
	assert_eq(pranks["hosed"]["conditions"], [{"beryl_on": "garden_hose"}])
	assert_eq(pranks["penny_pincher"]["conditions"], [{"beryl_within": 300}])
	assert_eq(pranks["mirror_mirror"]["conditions"], [{"hush_in_frame_frozen": true}])
	assert_true(pranks["achoo_ria"]["residue"][0]["blind"], "ACHOO-RIA! FRAZZLED is blind")
	for id in ["hosed", "penny_pincher", "mirror_mirror"]:
		assert_true(pranks[id]["fizzle"] is Dictionary, "%s has a fizzle" % id)
	# GDD activity-table marks
	var marks := {"allegro_go_go": 0.5, "kettle_drum": 3.0, "achoo_ria": 7.0, "in_a_pickle": 1.0, "cold_open": 1.0,
		"tap_dance": 1.0, "lift_off": 1.0, "eye_popping_news": 2.0, "bellows_blows": 2.0, "mirror_mirror": 0.5,
		"something_fishy": 1.0, "times_up": 1.0, "grand_exit": 2.0, "sopran_oh_no": 1.0, "snap_decision": 1.0,
		"in_over_his_head": 4.0, "pipe_down": 1.0, "pillow_talk": 1.0, "kidding_around": 1.0, "butter_fingers": 18.0,
		"sweet_tooth": 2.0, "hosed": 3.0, "marrow_escape": 2.0, "award_winning": 2.0, "tutu_much": 1.0,
		"spit_take": 3.0, "fan_mail": 8.0, "it_takes_two": 4.0, "spotlight_stealer": 2.0}
	for id in marks:
		assert_eq(float(pranks[id]["trigger"]["mark_s"]), marks[id], "%s mark" % id)
	assert_true(pranks["kettle_drum"]["trigger"]["resume"], "KETTLE DRUM resumes")


func _check_trigger(id: String, p: Dictionary) -> void:
	var t: Dictionary = p.get("trigger", {})
	var ty := String(t.get("type", ""))
	assert_has(["use", "step", "quake", "third_party", "knock_on_only"], ty, "%s trigger type" % id)
	if t.get("activity") != null:
		var a := String(t["activity"])
		if assert_true(acts.has(a), "%s trigger activity %s" % [id, a]) and t.has("mark_s"):
			assert_between(float(t.get("mark_s", -1)), 0.0, float(acts[a]["dur_s"]), "%s mark inside %s" % [id, a])
			if ty == "use":
				assert_eq(C.RIG_POINTS[p["rig_point"]][0], C.STATIONS[acts[a]["station"]][0],
						"%s rig point is in %s's room" % [id, a])
	if ty in ["use", "third_party"]:
		assert_true(t.get("activity") != null, "%s use needs an activity" % id)
	for k in t.get("fixup_kinds", []):
		assert_has(C.FIXUP_KINDS, k, "%s fixup kind" % id)
		var st := String(t.get("fixup_station", ""))
		if assert_true(C.STATIONS.has(st), "%s fixup_station %s" % [id, st]):
			assert_has(C.STATIONS[st][1], k, "%s fixup station has kind %s" % [id, k])
	if ty == "step":
		var at: Variant = t.get("at")
		var ats: Array = at if at is Array else [at]
		for h in ats:
			assert_has(C.all_hotspots(), h, "%s step at %s" % [id, h])
	if ty == "quake":
		assert_has(C.ROOMS, t.get("room"), "%s quake room" % id)
	if ty == "third_party":
		assert_has(["beryl", "delphine"], t.get("actor"), "%s actor" % id)
		assert_true(String(t.get("event", "")) != "", "%s event" % id)


func _check_prank_condition(id: String, c: Dictionary) -> void:
	for k in c:
		assert_has(C.PRANK_CONDITIONS, k, "%s condition key %s" % [id, k])
	if c.has("beryl_on"):
		assert_has(C.all_hotspots(), c["beryl_on"], "%s beryl_on" % id)
	if c.has("tier_min"):
		assert_has(["calm", "irked", "steaming", "livid"], c["tier_min"], "%s tier_min" % id)


func _check_reaction_ref(id: String, p: Dictionary) -> void:
	var r: Dictionary = p.get("reaction", {})
	var arch: Dictionary = rx.get("archetypes", {})
	var base := String(r.get("archetype", ""))
	var variants: Array = r.get("variants", [])
	if p.get("size") == "SIG":
		assert_has(C.SIGNATURES, base, "%s signature archetype" % id)
		assert_eq(variants.size(), 0, "%s signatures have no variants" % id)
		assert_true(arch.has(base), "%s reaction %s in reactions.json" % [id, base])
	else:
		assert_has(C.ARCHETYPES, base, "%s archetype" % id)
		assert_gt(variants.size(), 0, "%s variants" % id)
		for v in variants:
			assert_true(arch.has("%s_%s" % [base, v]), "%s reaction %s_%s in reactions.json" % [id, base, v])
	var e: Variant = r.get("end")
	if e is Dictionary:
		var room := String(e.get("room", ""))
		if assert_has(C.ROOMS, room, "%s end room" % id):
			assert_between(int(e.get("x", -1)), int(C.ROOM_X[room][0]), int(C.ROOM_X[room][1]), "%s end x in room" % id)
	var ko: Variant = p.get("knock_on")
	if ko is Dictionary:
		var key := base if variants.is_empty() else "%s_%s" % [base, variants[0]]
		var def: Dictionary = arch.get(key, {})
		var f := int(ko.get("frame", -1))
		assert_gt(f, int(def.get("marks", {}).get("accent", 0)), "%s knock-on after A's accent" % id)
		assert_lt(f, int(def.get("frames", 0)), "%s knock-on inside A's reaction" % id)
		assert_eq(int(def.get("marks", {}).get("knock_on", -1)), f, "%s knock-on frame = reaction mark" % id)
		if ko.get("headbutt", false):
			assert_eq(ko.get("requires"), {"beryl_within": 300}, "%s headbutt requires Beryl" % id)
		else:
			assert_true(pranks.has(ko.get("prank")), "%s knock-on prank" % id)


func test_double_acts() -> void:
	assert_eq(_keys(das), _sorted(C.DOUBLE_ACTS), "double act ids")
	var pairs := {"hot_and_cold": ["achoo_ria", "tap_dance"], "up_in_smoke": ["lift_off", "bellows_blows"],
		"marrow_mayhem": ["marrow_escape", null], "encore": ["grand_exit", "rug_burn"],
		"tea_for_two": ["spit_take", "fan_mail"], "curtain_call": ["spotlight_stealer", null]}
	for id in das:
		var d: Dictionary = das[id]
		assert_eq(d.get("a"), pairs[id][0], "%s a" % id)
		assert_eq(d.get("b"), pairs[id][1], "%s b" % id)
		assert_between(String(d.get("caption", "")).length(), 1, 18, "%s caption" % id)
		var ko: Variant = pranks.get(d["a"], {}).get("knock_on")
		if assert_true(ko is Dictionary, "%s: A carries the knock-on" % id):
			if d["b"] == null:
				assert_true(ko.get("headbutt", false), "%s headbutt knock-on" % id)
			else:
				assert_eq(ko.get("prank"), d["b"], "%s knock-on target" % id)


func test_reaction_timings_obey_gdd_9_3() -> void:
	var arch: Dictionary = rx.get("archetypes", {})
	var allowed: Array[String] = ["suppressed"]
	allowed.append_array(C.SIGNATURES)
	for a in C.ARCHETYPES:
		for v in ["a", "b", "c"]:
			allowed.append("%s_%s" % [a, v])
	for key in arch:
		assert_has(allowed, key, "reaction key %s is canonical" % key)
		var d: Dictionary = arch[key]
		var clip := String(d.get("clip", ""))
		if key == "suppressed":
			assert_eq(clip, "bellows/beat_suppressed")
			assert_eq(int(d.get("frames")), 60, "suppressed is 60 f (TECH §3.7.4)")
			continue
		var is_sig := String(key).begins_with("sig_")
		assert_eq(clip, "bellows/%s" % key if is_sig else "bellows/rx_%s" % key, "%s clip id" % key)
		assert_false(d.has("variation") or d.has("time_jitter"), "%s: no jitter fields on timed reactions" % key)
		var m: Dictionary = d.get("marks", {})
		var frames := int(d.get("frames", 0))
		var antic := int(m.get("antic", -1))
		var accent := int(m.get("accent", -1))
		var hold: Array = m.get("hold", [0, 0])
		var release := int(m.get("release", -1))
		var cls := String(d.get("scale", ""))
		if not assert_true(C.TIMING.has(cls), "%s scale %s" % [key, cls]):
			continue
		var r: Dictionary = C.TIMING[cls]
		assert_eq(cls == "sig", is_sig, "%s signature class" % key)
		assert_between(accent - antic, r["antic"][0], r["antic"][1], "%s anticipation" % key)
		assert_between(int(hold[0]) - accent, 2, 4, "%s accent <= 4 f" % key)
		assert_between(int(hold[1]) - int(hold[0]), r["hold"][0], r["hold"][1], "%s hold" % key)
		assert_between(release - int(hold[1]), r["settle"][0], r["settle"][1], "%s settle" % key)
		assert_eq(release, frames, "%s release = frames" % key)
		assert_between(frames, r["total"][0], r["total"][1], "%s total" % key)
		var tr: Variant = d.get("travel")
		if tr is Dictionary:
			assert_between(int(tr["from_f"]), 0, frames, "%s travel from" % key)
			assert_between(int(tr["to_f"]), int(tr["from_f"]) + 1, frames, "%s travel to" % key)
		assert_between(int(d.get("t3_prop_f", -1)), accent, frames, "%s t3 prop frame" % key)
		assert_true(float(d.get("cam", {}).get("zoom", 0)) >= 1.15, "%s cam zoom" % key)
		assert_has([3, 5, 8], int(d.get("cam", {}).get("hitstop", 0)), "%s hitstop" % key)
	# every archetype variant the pranks use exists; every authored variant is used
	var used := {}
	for p in pranks.values():
		var base := String(p["reaction"]["archetype"])
		if p["reaction"]["variants"].is_empty():
			used[base] = true
		for v in p["reaction"]["variants"]:
			used["%s_%s" % [base, v]] = true
	for k in arch:
		if k != "suppressed" and k != "headbutt_launch_a":
			assert_true(used.has(k), "reaction %s is used by a prank" % k)
	assert_true(arch.has("headbutt_launch_a"), "headbutt archetype for the knock-ons")


func test_sneeze_rule_of_three() -> void:
	var s: Dictionary = rx.get("archetypes", {}).get("sneeze_blast_a", {})
	var b: Dictionary = s.get("beats", {})
	var want := {"ah": 20, "ahh": 24, "ahhh": 30, "false_stop": 20, "choo": 3}
	for k in want:
		if assert_true(b.has(k), "sneeze beat %s" % k):
			assert_eq(int(b[k][1]) - int(b[k][0]), want[k], "sneeze %s length (GDD §2.3)" % k)
	assert_eq(int(s["marks"]["accent"]), int(b["choo"][0]), "the CHOO is the accent")
	assert_eq(int(s["cam"]["hitstop"]), 5, "5 f hit-stop")


func test_reaction_side_tables() -> void:
	var t: Dictionary = rx.get("clip_timings", {})
	for key in ["meltdown", "lecture", "t3_last_beats", "combo_beats"]:
		var n: int = int({"meltdown": 3, "lecture": 3, "t3_last_beats": 4, "combo_beats": 4}[key])
		var ids: Array = rx.get(key, [])
		assert_eq(ids.size(), n, "%s count" % key)
		for cid in ids:
			assert_true(t.has(cid), "%s timing for %s" % [key, cid])
	for cid in rx.get("meltdown", []):
		assert_eq(int(t[cid]["frames"]), 330, "%s 5.5 s" % cid)
		assert_eq(t[cid]["marks"]["stomps"], [60, 150, 240], "%s stomps" % cid)
	for cid in rx.get("lecture", []):
		assert_eq(int(t[cid]["frames"]), 132, "%s 2.2 s" % cid)
	var c: Dictionary = rx.get("caught", {})
	assert_eq(int(c.get("total_f", 0)), 240)
	assert_eq(int(c.get("hush_placed_f", 0)), 204)
	assert_eq(c.get("busted_cam"), [0, 60])
	assert_eq(c.get("lecture"), [60, 192])
	for cid in rx.get("combo_beats", []):
		assert_eq(int(t[cid]["frames"]), 90, "%s is a 1.5 s beat" % cid)
	assert_eq(rx.get("mirror_rounds", {}).get("rounds_f"), [72, 72, 60], "Mirror, Mirror rounds")
	assert_eq(int(t.get("bellows/melt_exhausted", {}).get("frames", 0)), 480, "Exhausted 8 s")


func test_residues_and_combos() -> void:
	assert_eq(_keys(residues), _sorted(C.RESIDUES), "residue kinds")
	var fix := {"SOAKED": "DRY", "FLOURY": "SINK", "STICKY": "SINK", "SQUEAKY": "HONEY", "FRAZZLED": "MIRROR",
		"FEATHERED": "MIRROR", "COSTUME": "MIRROR"}
	for k in residues:
		assert_eq(residues[k].get("fixup"), fix[k], "%s fix-up kind (GDD §5.4)" % k)
		assert_eq(residues[k].get("overlay"), k, "%s overlay = the bellows rig residue key" % k)
	assert_eq(_keys(combos), _sorted(C.COMBOS), "combo ids")
	var of := {"dough_man": ["SOAKED", "FLOURY"], "poodle": ["SOAKED", "FRAZZLED"], "chicken": ["STICKY", "FEATHERED"],
		"mad_maestro": ["FRAZZLED", "SQUEAKY"]}
	for k in combos:
		assert_eq(combos[k].get("of"), of[k], "%s residues" % k)
		assert_eq(combos[k].get("clip"), "bellows/combo_%s" % k, "%s clip" % k)
		assert_eq(combos[k].get("overlay"), "COMBO:%s" % k, "%s overlay = the bellows rig combo key" % k)
		assert_between(String(combos[k].get("caption", "")).length(), 1, 18, "%s caption" % k)
		assert_has(rx.get("combo_beats", []), "bellows/combo_%s" % k, "%s combo beat timing" % k)


func test_barks() -> void:
	var v: Dictionary = barks.get("voice", {})
	for k in ["pipe_down", "the_pipes", "lecture_a", "lecture_b", "lecture_c", "who_squeaked", "pardon"]:
		assert_true(v.has(k), "voice bark %s" % k)
	for k in v:
		assert_true(String(v[k].get("bank", "")).begins_with("vo_"), "%s bank id" % k)
		assert_has(["bellows", "beryl", "delphine"], v[k].get("speaker"), "%s speaker" % k)
	var cards: Dictionary = barks.get("figgis_cards", {})
	for cue in C.DIRECTOR_CUES:
		if not String(cue).begins_with("laugh_"):
			assert_true(cards.has(cue), "Figgis card for Prologue cue %s" % cue)
	var res: Dictionary = barks.get("results", {})
	for k in ["missed_required", "missed_optional", "missed_big_number", "short_link", "short_meltdown", "short_combo",
			"short_near_misses"]:
		assert_true(res.has(k), "results template %s" % k)
	var missed: Dictionary = barks.get("missed", {})
	for p in C.PRANKS:
		assert_true(missed.has(p), "why-missed phrase for %s" % p)
	assert_eq((barks.get("loading_cards", {}) as Dictionary).size(), 11, "a loading card icon per Night")
	assert_eq((barks.get("cold_opens", {}) as Dictionary).size(), 11, "cold opens (none for the Prologue)")


func test_soft_cross_checks_with_rig_and_audio() -> void:
	var rig: Variant = C.read("rigs/bellows/rig.json")
	var smap: Variant = null
	if FileAccess.file_exists("res://audio/sfx_map.json"):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string("res://audio/sfx_map.json")) == OK:
			smap = j.data
	if not rig is Dictionary and not smap is Dictionary:
		skip("bellows rig and audio sfx_map not present yet")
		return
	if rig is Dictionary:
		var keys: Dictionary = rig.get("residues", {})
		for k in residues:
			assert_true(keys.has(residues[k]["overlay"]), "bellows rig has residue key %s" % residues[k]["overlay"])
		for look in residues.get("COSTUME", {}).get("looks", {}).values():
			assert_true(keys.has(look), "bellows rig has costume key %s" % look)
		for c in combos:
			assert_true(keys.has(combos[c]["overlay"]), "bellows rig has combo key %s" % combos[c]["overlay"])
	if smap is Dictionary:
		var names := {}
		for sect in ["files", "banks", "aliases"]:
			for k in (smap.get(sect, {}) as Dictionary).keys():
				names[k] = true
		var voice: Dictionary = barks.get("voice", {})
		for k in voice:
			var v: Dictionary = voice[k]
			var fb: Variant = v.get("fallback")
			if fb != null:
				assert_true(names.has(fb), "bark %s fallback bank %s exists" % [k, fb])
			elif int(v.get("stage", 1)) <= 1:
				assert_true(names.has(v["bank"]), "bark %s bank %s exists in sfx_map.json" % [k, v["bank"]])
		for b in bits:
			var vb: Variant = bits[b].get("voice")
			if vb != null and not names.has(vb):
				print("  [content] squeak bit %s voice %s not rendered yet (request to audio)" % [b, vb])
