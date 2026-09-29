## Episode, Script, normalisation, solution and house cross-checks (standalone JSON, no ContentDB).
extends TestBase

const C := preload("res://tests/content/content_canon.gd")

var eps: Dictionary = {}
var pranks: Dictionary = {}
var das: Dictionary = {}
var acts: Dictionary = {}
var items: Dictionary = {}
var residues: Dictionary = {}
var combos: Dictionary = {}
var house: Variant = null


func before_each() -> void:
	eps.clear()
	for e in C.EPISODES:
		var d: Variant = C.read("episodes/%s.json" % e)
		if d is Dictionary:
			eps[e] = d
	var p: Variant = C.read("pranks.json")
	pranks = p.get("pranks", {}) if p is Dictionary else {}
	das = p.get("double_acts", {}) if p is Dictionary else {}
	var a: Variant = C.read("activities.json")
	acts = a.get("activities", {}) if a is Dictionary else {}
	var i: Variant = C.read("items.json")
	items = i.get("items", {}) if i is Dictionary else {}
	var r: Variant = C.read("residues.json")
	residues = r.get("residues", {}) if r is Dictionary else {}
	combos = r.get("combos", {}) if r is Dictionary else {}
	house = C.read("house/house.json")


func _loop_acts(ep: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in ep.get("bellows", {}).get("loop", []):
		out.append(String(e.get("a", "")))
	return out


## Pranks a Night uses: prank lines, prank_witnessed lines, and every Double Act member.
func _night_pranks(ep: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for ln in ep.get("script", []):
		if ln.get("prank") != null and not out.has(ln["prank"]):
			out.append(String(ln["prank"]))
		if ln.get("kind") == "double_act":
			var d: Dictionary = das.get(ln.get("double_act"), {})
			for k in ["a", "b"]:
				if d.get(k) != null and not out.has(d[k]):
					out.append(String(d[k]))
	return out


func test_twelve_episodes_named_by_id() -> void:
	assert_eq(eps.size(), 12, "12 episode files")
	var seen_rules: Array[String] = []
	for id in eps:
		var ep: Dictionary = eps[id]
		assert_eq(ep.get("id"), id, "%s id matches file name" % id)
		assert_eq(ep.get("status"), "final" if id in C.FINAL_EPISODES else "draft", "%s status" % id)
		assert_true(String(ep.get("title", "")) != "", "%s title" % id)
		var nr := String(ep.get("new_rule", ""))
		assert_true(nr != "", "%s has exactly one new_rule" % id)
		assert_false(seen_rules.has(nr), "%s new_rule '%s' is new" % [id, nr])
		seen_rules.append(nr)
		for room in ep.get("rooms", []):
			assert_has(C.ROOMS, room, "%s room %s" % [id, room])
		var idx := C.EPISODES.find(id)
		assert_eq(int(ep.get("index", -1)), idx, "%s index" % id)
		assert_eq(ep.get("entry"), "window" if idx <= 4 else "gate", "%s entry" % id)
		var r: Dictionary = ep.get("rules", {})
		var fill := 2.0 if idx == 0 else (1.0 if idx <= 4 else 0.8)
		assert_eq(float(r.get("spot_fill_s", 0)), fill, "%s '?' fill" % id)
		assert_eq(int(r.get("tomatoes", 0)), -1 if idx <= 3 else 3, "%s tomatoes" % id)
		assert_eq(bool(r.get("cant_fail", false)), idx == 0, "%s cant_fail" % id)
		assert_eq(bool(r.get("nerves", false)), id == "n10_it_takes_two", "%s nerves" % id)
		assert_eq(int(ep.get("seed", 0)), 100 + idx, "%s seed" % id)
		if idx == 0:
			assert_eq(ep.get("card"), null, "the Prologue has no loading card")
			assert_eq(ep.get("cold_open"), null, "the Prologue has no cold open")
		else:
			var text := String(ep.get("card", {}).get("text", ""))
			assert_between(text.split(" ", false).size(), 5, 25, "%s card <= 25 words" % id)
			assert_true(String(ep.get("card", {}).get("icon", "")) != "", "%s card icon" % id)
			assert_eq(ep.get("cold_open", {}).get("clip"), "cold/%s" % id, "%s cold open clip" % id)
			assert_true(String(ep.get("cold_open", {}).get("desc", "")) != "", "%s cold open description" % id)
		for who in ["hush", "bellows"]:
			var s: Dictionary = ep.get(who, {}).get("start", {})
			if assert_has(ep.get("rooms", []) + ep.get("backstage", []), s.get("room"), "%s %s start room" % [id, who]):
				var rx: Array = C.ROOM_X[s["room"]]
				assert_between(int(s.get("x", -1)), int(rx[0]), int(rx[1]), "%s %s start x" % [id, who])


func test_loops_and_gates() -> void:
	for id in eps:
		var ep: Dictionary = eps[id]
		var loop: Array = ep.get("bellows", {}).get("loop", [])
		assert_between(loop.size(), 4, 6, "%s loop of 4-6 activities" % id)
		var reach: Array = ep.get("rooms", []) + ep.get("backstage", [])
		for e in loop:
			var a := String(e.get("a", ""))
			if not assert_true(acts.has(a), "%s loop activity %s" % [id, a]):
				continue
			var st := String(e.get("station", acts[a]["station"]))
			assert_true(C.STATIONS.has(st), "%s %s station %s" % [id, a, st])
			assert_has(reach, C.STATIONS.get(st, [""])[0], "%s %s station room is open" % [id, a])
			if e.has("gate"):
				var g: Dictionary = e["gate"]
				var u := String(g.get("until", ""))
				assert_true(u in ["first_squeak", "first_rig"] or u.begins_with("rigged:"), "%s gate until %s" % [id, u])
				if u.begins_with("rigged:"):
					assert_true(pranks.has(u.trim_prefix("rigged:")), "%s gate prank" % id)
				assert_true(id in ["p00_curtain_up", "n01_throat_tea"], "%s: player-led gates only in P and N1" % id)
	var n1: Array = eps["n01_throat_tea"]["bellows"]["loop"]
	assert_eq(n1[0], {"a": "warmup", "gate": {"until": "first_rig", "plus_s": 2, "max_s": 25, "first_loop_only": true}})
	var p: Dictionary = eps["p00_curtain_up"]
	var pl: Array = p["bellows"]["loop"]
	assert_eq(_loop_acts(p), ["warmup", "warmup", "tea", "warmup", "hunt"] as Array[String], "Prologue loop")
	assert_eq(pl[0]["gate"]["until"], "first_squeak")
	assert_eq(float(pl[0]["gate"]["max_s"]), 15.0)
	assert_eq(pl[1]["gate"]["until"], "rigged:achoo_ria")
	assert_eq(pl[1]["gate"]["max_s"], null, "the honey step waits for the player")
	assert_eq(pl[3]["gate"]["until"], "rigged:allegro_go_go")
	assert_eq(float(pl[3]["gate"]["max_s"]), 25.0)
	for g in p["director"]["gates"]:
		assert_eq(pl[int(g["loop"])]["gate"], g["gate"], "director gate mirrors loop gate %d" % int(g["loop"]))


func test_prologue_director() -> void:
	var d: Dictionary = eps["p00_curtain_up"].get("director", {})
	assert_eq(float(d.get("launch_offset_s", 0)), 2.3)
	var ids: Array[String] = []
	for c in d.get("cues", []):
		ids.append(String(c["id"]))
		_check_when("p00 cue %s" % c["id"], c.get("when"))
	for cue in C.DIRECTOR_CUES:
		assert_has(ids, cue, "cue %s" % cue)
	var vase: Dictionary = d["cues"][ids.find("laugh_vase")]
	assert_eq(float(vase["when"]["tick_ge_s"]), 2.3, "vase at 4.6 s after launch = 2.3 s after curtain-up")
	var sn: Dictionary = d.get("safety_net", {})
	assert_eq(float(sn.get("hide_before_entry_s", 0)), 1.5)
	assert_eq(float(sn.get("slowmo", 0)), 0.5)
	assert_eq(sn.get("pulse"), "kitchen_pantry_curtain")
	assert_eq(d.get("hunt", {}).get("activity"), "hunt")
	assert_true(d.get("exit") is Dictionary, "exit after the hunt")
	assert_eq(d.get("end", {}).get("reason"), "prologue_done")


func _check_when(ctx: String, c: Variant) -> void:
	if c == null:
		return
	if not assert_true(c is Dictionary, "%s condition is an object" % ctx):
		return
	for k in c:
		assert_has(C.WHEN_CONDITIONS, k, "%s condition key %s" % [ctx, k])
		if k in ["and", "or"]:
			for sub in c[k]:
				_check_when(ctx, sub)
		elif k == "not":
			_check_when(ctx, c[k])
		elif k == "event_seen":
			assert_true(String(c[k].get("event", "")) != "", "%s event_seen names an event" % ctx)
		elif k == "prank_state":
			assert_true(pranks.has(c[k][0]), "%s prank_state prank" % ctx)
		elif k in ["bellows_in_room", "bellows_not_in_room"]:
			assert_has(C.ROOMS, c[k], "%s room" % ctx)
		elif k == "bellows_activity":
			assert_true(acts.has(c[k]), "%s activity %s" % [ctx, c[k]])


func test_scripts() -> void:
	var req_count := {0: 2, 1: 3, 2: 3, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3, 8: 3, 9: 3, 10: 3, 11: 4}
	for id in eps:
		var ep: Dictionary = eps[id]
		var idx := C.EPISODES.find(id)
		var script: Array = ep.get("script", [])
		var ids: Array[String] = []
		var bn := 0
		var req := 0
		for ln in script:
			var lid := String(ln.get("id", ""))
			assert_false(ids.has(lid), "%s line id %s unique" % [id, lid])
			ids.append(lid)
			assert_has(C.LINE_KINDS, ln.get("kind"), "%s line kind" % id)
			assert_true(String(ln.get("text", "")) != "", "%s %s text" % [id, lid])
			assert_true(ln.get("hint") is Dictionary, "%s %s hint block" % [id, lid])
			if ln.get("big_number", false):
				bn += 1
				assert_false(ln.get("req", false), "%s BN is not required" % id)
			if ln.get("req", false):
				req += 1
			_check_line_refs(id, ln)
			for p in ln.get("rearm_on_unseal", []):
				assert_true(pranks.has(p), "%s rearm %s" % [id, p])
		assert_eq(req, req_count[idx], "%s required lines (GDD §7.2/§7.3)" % id)
		if idx == 0:
			assert_eq(script.size(), 2, "Prologue: 2 lines")
			assert_eq(bn, 0, "Prologue: no Big Number")
		else:
			assert_eq(bn, 1, "%s exactly one Big Number" % id)
			assert_between(script.size() - 1, 3, 6, "%s 3-6 lines + BN" % id)
			assert_le(script.size(), 7, "%s <= 7 lines" % id)


func _check_line_refs(id: String, ln: Dictionary) -> void:
	var k := String(ln.get("kind", ""))
	match k:
		"prank", "prank_witnessed":
			assert_true(pranks.has(ln.get("prank")), "%s %s prank" % [id, ln.get("id")])
		"double_act":
			assert_true(das.has(ln.get("double_act")), "%s double act" % id)
		"combo", "combo_witnessed":
			assert_true(combos.has(ln.get("combo")), "%s combo" % id)
		"meltdown", "witness", "herd":
			assert_gt(int(ln.get("count", 0)), 0, "%s %s count" % [id, k])
		"chain":
			assert_gt(int(ln.get("link", 0)), 1, "%s chain link" % id)
	var h: Dictionary = ln.get("hint", {})
	if h.get("item") != null:
		assert_true(items.has(h["item"]), "%s hint item" % id)
		assert_eq(h.get("container"), items.get(h["item"], {}).get("source"), "%s hint container" % id)
	if h.get("rig_point") != null:
		assert_true(C.RIG_POINTS.has(h["rig_point"]), "%s hint rig point %s" % [id, h["rig_point"]])


func test_nights_lists_match_scripts() -> void:
	for id in eps:
		var used := _night_pranks(eps[id])
		for p in used:
			assert_has(pranks.get(p, {}).get("nights", []), id, "%s lists %s in its nights" % [p, id])
	for p in pranks:
		for n in pranks[p].get("nights", []):
			if eps.has(n):
				assert_has(_night_pranks(eps[n]), p, "%s's Night %s uses it" % [p, n])


func test_trigger_activity_and_items_available() -> void:
	for id in eps:
		var ep: Dictionary = eps[id]
		var loop := _loop_acts(ep)
		var rooms: Array = ep.get("rooms", [])
		var used := _night_pranks(ep)
		# residue kinds any prank of the Night can leave -> fix-up kinds reachable
		var fix_kinds: Array[String] = []
		var knocked: Array[String] = []
		for p in used:
			for r in pranks[p].get("residue", []):
				var fk := String(residues.get(r["kind"], {}).get("fixup", ""))
				if not fix_kinds.has(fk):
					fix_kinds.append(fk)
			var ko: Variant = pranks[p].get("knock_on")
			if ko is Dictionary and ko.get("prank") != null and used.has(ko["prank"]):
				knocked.append(String(ko["prank"]))
		for p in used:
			var t: Dictionary = pranks[p]["trigger"]
			var ok := false
			match String(t["type"]):
				"use", "third_party":
					ok = loop.has(t["activity"])
					for fk in t.get("fixup_kinds", []):
						ok = ok or fix_kinds.has(fk)
				"step":
					ok = t.get("activity") == null or loop.has(t["activity"])
					if p == "rug_burn":
						ok = rooms.has("landing") or knocked.has(p)
				"quake":
					ok = rooms.has(t["room"])
			ok = ok or knocked.has(p)
			assert_true(ok, "%s: %s can trigger (loop, fix-up or knock-on)" % [id, p])
			for s in pranks[p]["steps"]:
				var need: Variant = s.get("needs")
				if s.get("setup") is Dictionary:
					need = s["setup"]["item"]
				if need != null:
					assert_has(rooms, C.CONTAINERS[items[need]["source"]], "%s: %s's %s container room is open" % [id, p, need])
			assert_has(rooms, C.RIG_POINTS[pranks[p]["rig_point"]][0], "%s: %s rig point room is open" % [id, p])
		# every fix-up kind the Night can produce has a station Bellows can reach
		var reach: Array = rooms + ep.get("backstage", [])
		for fk in fix_kinds:
			var found := false
			for st in C.STATIONS:
				if C.STATIONS[st][1].has(fk) and reach.has(C.STATIONS[st][0]):
					found = true
			assert_true(found, "%s: a %s station is reachable" % [id, fk])


func test_script_bases_normalise_to_700_tenths() -> void:
	var report: Array[String] = []
	for id in eps:
		var weights: Array = []
		for ln in eps[id]["script"]:
			if ln.get("kind") == "prank":
				weights.append(C.SIZE_WEIGHT[pranks[ln["prank"]]["size"]])
		var bases := C.largest_remainder(weights, 700)
		var sum := 0
		for b in bases:
			sum += int(b)
			assert_gt(int(b), 0, "%s base > 0" % id)
		assert_eq(sum, 700, "%s bases sum to 700 tenths" % id)
		report.append("%s %s" % [id, str(bases)])
	assert_eq(C.largest_remainder([14, 10, 20, 20, 14], 700), [126, 90, 179, 179, 126], "N1 worked example")
	print("  [content] prank-line bases (tenths): ", "; ".join(report))


func test_solutions_reference_real_content() -> void:
	for e in C.FINAL_EPISODES:
		var sol: Variant = C.read("solutions/%s.json" % e)
		if not assert_true(sol is Dictionary, "solution for %s" % e):
			continue
		assert_eq(sol.get("episode"), e)
		var used := _night_pranks(eps[e])
		var routes: Dictionary = sol.get("routes", {})
		for r in ["ideal", "required", "slow"]:
			if not assert_true(routes.has(r), "%s route %s" % [e, r]):
				continue
			var route: Dictionary = routes[r]
			for k in route.get("expect", {}):
				assert_has(C.EXPECT_KEYS, k, "%s %s expect key" % [e, r])
			for s in route.get("steps", []):
				var ctx := "%s/%s step %s" % [e, r, s.get("do")]
				assert_has(C.SOLUTION_STEPS, s.get("do"), ctx)
				if s.has("prank"):
					assert_has(used, s["prank"], "%s prank is in the Night" % ctx)
				if s.has("spot"):
					assert_true(C.HIDING.has(s["spot"]), "%s hiding spot" % ctx)
					assert_has(eps[e]["rooms"], C.HIDING.get(s["spot"], [""])[0], "%s spot room open" % ctx)
				if s.get("do") == "pick":
					assert_eq(items.get(s["item"], {}).get("source"), s.get("from"), "%s item source" % ctx)
				if s.has("until"):
					_check_when(ctx, s["until"])
		var ideal: Dictionary = routes.get("ideal", {}).get("expect", {})
		if e != "p00_curtain_up":
			assert_eq(ideal.get("stars"), [true, true, true], "%s ideal is 3 stars" % e)
			assert_eq(ideal.get("applause"), [100, 140], "%s ideal applause band" % e)
			assert_eq(routes["required"]["expect"].get("stars"), [true, null, null], "%s required is 1 star" % e)
		assert_eq(int(ideal.get("catches_max", -1)), 0, "%s ideal has no catches" % e)
	var p: Dictionary = C.read("solutions/p00_curtain_up.json")
	assert_eq(p["routes"]["ideal"]["expect"]["laughs_by_s"], [[60, 6]], "6 laughs in 60 s")
	var slow: Dictionary = p["routes"]["slow"]["expect"]
	assert_eq(int(slow["first_player_laugh_s_max"]), 10)
	assert_eq(int(slow["first_prank_s_max"]), 30)
	assert_eq(slow["laughs_by_s"], [[75, 4]])
	var n1: Array = C.read("solutions/n01_throat_tea.json")["routes"]["ideal"]["steps"]
	var n1_pranks: Array = []
	for s in n1:
		n1_pranks.append(s.get("prank"))
	assert_has(n1_pranks, "achoo_ria", "N1 ideal rigs ACHOO-RIA! (HOT & COLD)")
	assert_has(n1_pranks, "tap_dance", "N1 ideal rigs TAP DANCE (HOT & COLD)")
	var n2: Array = C.read("solutions/n02_something_fishy.json")["routes"]["ideal"]["steps"]
	# TIME'S UP lands (the Big Number unseals and re-arms it), he is rigged again, then Hush stands in
	var saw_times_up := false
	var rearmed := false
	var chained := false
	for s in n2:
		if s.get("do") == "wait_event" and s.get("match", {}).get("prank") == "times_up" \
				and s.get("event") in ["prank_fire", "reaction_end"]:
			saw_times_up = true
		if saw_times_up and s.get("do") == "rig" and s.get("prank") == "times_up":
			rearmed = true
		if saw_times_up and s.get("do") == "stand_in":
			chained = true
	assert_true(rearmed, "N2 ideal re-rigs TIME'S UP after it lands (rearm_on_unseal)")
	assert_true(chained, "N2 ideal stands in for MIRROR, MIRROR after TIME'S UP lands")


func test_against_house_json_if_present() -> void:
	if not house is Dictionary:
		skip("game/data/house/house.json not present yet")
		return
	var hs := {}
	for h in house.get("hotspots", []):
		hs[h["id"]] = h
	var st := {}
	for s in house.get("stations", []):
		st[s["id"]] = s
	var landings: Dictionary = house.get("landings", {})
	for id in C.STATIONS:
		assert_true(st.has(id), "house station %s" % id)
	for id in C.all_hotspots():
		assert_true(hs.has(id), "house hotspot %s" % id)
	for a in acts:
		var s: String = acts[a]["station"]
		if st.has(s):
			assert_eq(st[s]["room"], C.STATIONS[s][0], "station %s room" % s)
	for p in pranks:
		var pr: Dictionary = pranks[p]
		var t: Dictionary = pr["trigger"]
		# IT TAKES TWO: the record plays on the gramophone while they tango on the parlour floor.
		if t["type"] == "use" and p != "it_takes_two" and hs.has(pr["rig_point"]) \
				and hs[pr["rig_point"]].get("station") != null:
			var want := String(acts[t["activity"]]["station"])
			assert_eq(hs[pr["rig_point"]]["station"], want, "%s rig point station = %s's station" % [p, t["activity"]])
		var e: Variant = pr["reaction"].get("end")
		if e is Dictionary and e.get("landing") != null:
			var lr: Dictionary = landings.get(e["room"], {})
			if assert_true(lr.has(e["landing"]), "%s landing %s.%s in house.json" % [p, e["room"], e["landing"]]):
				assert_eq(int(lr[e["landing"]]), int(e["x"]), "%s landing x matches house.json" % p)
	for it in items:
		assert_true(hs.has(items[it]["source"]), "item %s container in house" % it)
	# facing differences are reported, not failed (activities.json owns Bellows' facing)
	var diffs: Array[String] = []
	for a in acts:
		var s2: String = acts[a]["station"]
		if st.has(s2) and st[s2].has("facing") and int(st[s2]["facing"]) != int(acts[a]["facing"]) and a != "hunt":
			diffs.append("%s(%s: house %d, activity %d)" % [a, s2, int(st[s2]["facing"]), int(acts[a]["facing"])])
	if not diffs.is_empty():
		print("  [content] station facing differs from activity facing: ", ", ".join(diffs))
