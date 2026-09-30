## Stage-2 D1 content checks (s2-content): the timed micro-gag schema on every slice activity and detour,
## the Gate-0 episode `g0_sneeze`, the D1 expect keys on every route, scenario routes, `rules.combos: []`,
## the `ghost_ff` lesson, Script hints, loading cards, icons and voice banks — plus soft-hooked real-sim
## checks (Hush-idle loop length ≤ 60 s in Act I, N02 first prank ≤ 25 s, no `combo` event on N01/N02
## routes) that skip until the sim + solver load cleanly.
extends TestBase

const C := preload("res://tests/content/content_canon.gd")

## The slice: Gate 0, the Prologue, Night 1, Night 2.
const SLICE: Array[String] = ["g0_sneeze", "p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]
const ACT_ONE: Array[String] = ["n01_throat_tea", "n02_something_fishy"]
## Fix-up detours the slice's residues reach (FRAZZLED/COSTUME → MIRROR, SOAKED → DRY, STICKY → SINK;
## HONEY for SQUEAKY, reachable in no slice Night but kept to the same cadence).
const SLICE_DETOURS: Array[String] = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror"]
const EMOTES: Array[String] = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]
## D1 targets per persona (lead decision D1, ruling L2).
const DEAD_AIR_MAX := {"ideal": 20, "required": 25, "slow": 30}
const MAX_GAP_S := 12
const LOOP_MAX_S := 60.0
const N02_FIRST_PRANK_MAX_S := 25.0
const MG_MAX_GAP_S := 8.0
const MG_MIN_SPACING_S := 5.0

## Real-sim route reports shared by the soft tests (one run per route per suite run).
static var _reports: Dictionary = {}
static var _why_cached: String = "unset"
static var _db: Object = null
static var _data: SolverData = null

var acts: Dictionary = {}
var detours: Dictionary = {}
var walk_beats: Dictionary = {}
var eps: Dictionary = {}
var sols: Dictionary = {}


func before_each() -> void:
	var a: Variant = C.read("activities.json")
	acts = a.get("activities", {}) if a is Dictionary else {}
	detours = a.get("detours", {}) if a is Dictionary else {}
	walk_beats = a.get("walk_beats", {}) if a is Dictionary else {}
	eps.clear()
	sols.clear()
	for e in SLICE:
		var d: Variant = C.read("episodes/%s.json" % e)
		if d is Dictionary:
			eps[e] = d
		var s: Variant = C.read("solutions/%s.json" % e)
		if s is Dictionary:
			sols[e] = s


# --- helpers ----------------------------------------------------------------------------------

## Activities a slice Night's loop uses (plus the Prologue's scripted hunt).
func _slice_activities() -> Array[String]:
	var out: Array[String] = []
	for e in eps:
		for le in (eps[e] as Dictionary).get("bellows", {}).get("loop", []):
			var id := String(le.get("a", ""))
			if id != "" and not out.has(id):
				out.append(id)
	return out


## True when the activity is a loop entry with a gate in any slice Night (it may perform past `dur_s`).
func _gated(id: String) -> bool:
	for e in eps:
		for le in (eps[e] as Dictionary).get("bellows", {}).get("loop", []):
			if String(le.get("a", "")) == id and le.get("gate") is Dictionary:
				return true
	return false


## Cadence problems of one activity/detour ([] = OK): first beat 2–3 s, spacing 5–8 s, no gap > 8 s over
## `dur_s` (and over the `mg_cycle_s` wrap when gated), `len_f` 36–72, emote in the vocabulary, ids unique.
func _cadence(id: String, a: Dictionary, gated: bool) -> Array[String]:
	var out: Array[String] = []
	var mg: Array = a.get("micro_gags", [])
	if mg.is_empty():
		return ["%s: no micro-gags" % id]
	var ids: Array[String] = []
	var ats: Array[float] = []
	for g in mg:
		if not g is Dictionary:
			out.append("%s: legacy (string) micro-gag %s" % [id, str(g)])
			continue
		var gd: Dictionary = g
		var gid := String(gd.get("id", ""))
		if gid == "" or ids.has(gid):
			out.append("%s: micro-gag id '%s' empty or duplicated" % [id, gid])
		ids.append(gid)
		ats.append(float(gd.get("at_s", -1.0)))
		var lf := int(gd.get("len_f", 0))
		if lf < 36 or lf > 72:
			out.append("%s.%s: len_f %d not in 36–72" % [id, gid, lf])
		var em: Variant = gd.get("emote", null)
		if em != null and not EMOTES.has(String(em)):
			out.append("%s.%s: emote '%s' not in the vocabulary" % [id, gid, str(em)])
		if String(gd.get("gag", "")).strip_edges() == "":
			out.append("%s.%s: no one-line gag for the animator" % [id, gid])
	if ats.is_empty():
		return out
	if ats[0] < 2.0 or ats[0] > 3.0:
		out.append("%s: first beat at %.1f s (want 2–3 s)" % [id, ats[0]])
	for i in range(1, ats.size()):
		var sp := ats[i] - ats[i - 1]
		if sp < MG_MIN_SPACING_S or sp > MG_MAX_GAP_S:
			out.append("%s: spacing %.1f s between beats %d and %d (want 5–8 s)" % [id, sp, i - 1, i])
	var dur := float(a.get("dur_s", 0.0))
	var last_played := ats[0]
	for t in ats:
		if t < dur:
			last_played = t
	if dur - last_played > MG_MAX_GAP_S:
		out.append("%s: %.1f s from the last beat to the end of dur_s" % [id, dur - last_played])
	if gated:
		var cyc := float(a.get("mg_cycle_s", ats[ats.size() - 1] + 6.0))
		var wrap := cyc - ats[ats.size() - 1] + ats[0]
		if wrap < MG_MIN_SPACING_S or wrap > MG_MAX_GAP_S:
			out.append("%s: mg_cycle_s %.1f leaves a %.1f s wrap gap (want 5–8 s)" % [id, cyc, wrap])
	return out


## Why the real sim/solver can't run ("" when they can); cached for the suite run.
func _real_why() -> String:
	if _why_cached != "unset":
		return _why_cached
	_why_cached = SolverHooks.sim_missing_reason()
	if _why_cached == "":
		_data = SolverData.load_dir("res://data")
		_db = SolverHooks.load_db("res://data")
		var errs := SolverHooks.db_errors(_db)
		if not errs.is_empty():
			_why_cached = "ContentDB reports %d error(s) (first: %s)" % [errs.size(), errs[0]]
	return _why_cached


## The solver report of one authored route on the real sim (cached).
func _report(ep: String, rn: String) -> Dictionary:
	var key := "%s/%s" % [ep, rn]
	if _reports.has(key):
		return _reports[key]
	var sol := SolutionDef.load_file("res://data/solutions/%s.json" % ep)
	var rep := {}
	if sol.has_route(rn):
		var r := sol.resolve(rn)
		var w := SolverHooks.make_world(_db, ep, {"invariants": true})
		if w != null:
			var ex := Executor.new(w, r, r["persona"], Callable(), _data, {"episode": ep})
			rep = ex.run(60 * 900)
	_reports[key] = rep
	return rep


# --- the timed micro-gag schema -----------------------------------------------------------------

func test_every_slice_activity_and_detour_has_timed_micro_gags() -> void:
	var ids := _slice_activities()
	assert_true(ids.has("hunt"), "the Prologue's hunt is a slice activity")
	for id in ids:
		if not assert_true(acts.has(id), "slice activity %s in activities.json" % id):
			continue
		for p in _cadence(id, acts[id], _gated(id)):
			assert_true(false, p)
	for id in SLICE_DETOURS:
		if not assert_true(detours.has(id), "slice detour %s in activities.json" % id):
			continue
		for p in _cadence(id, detours[id], false):
			assert_true(false, p)


func test_micro_gag_ids_are_unique_and_named_for_clips() -> void:
	var seen := {}
	for blk in [acts, detours]:
		for id in blk:
			for g in (blk[id] as Dictionary).get("micro_gags", []):
				if not g is Dictionary:
					continue
				var gid := String((g as Dictionary).get("id", ""))
				assert_true(gid.is_valid_identifier(), "%s: micro-gag id '%s' is a clip-safe identifier" % [id, gid])
				if seen.has(gid) and seen[gid] != id:
					# one clip per id: the same id on two activities must be the same gag (host_tea reuses pinkie_up)
					assert_true(gid == "pinkie_up", "micro-gag id %s on both %s and %s" % [gid, seen[gid], id])
				seen[gid] = id


func test_walk_beats_schema() -> void:
	assert_between(float(walk_beats.get("min_leg_s", 0.0)), 4.0, 6.0, "walk_beats.min_leg_s")
	assert_between(float(walk_beats.get("every_s", 0.0)), 3.0, 8.0, "walk_beats.every_s")
	var wb: Array = walk_beats.get("ids", [])
	assert_gt(wb.size(), 1, "several walk beats cycle")
	for g in wb:
		assert_between(int(g.get("len_f", 0)), 36, 72, "walk beat %s len_f" % g.get("id"))
		assert_true(g.get("emote") == null or EMOTES.has(String(g.get("emote"))), "walk beat %s emote" % g.get("id"))


func test_exit_detour_shows_the_exit_icon() -> void:
	if not assert_true(detours.has("exit"), "activities.json detours.exit (the Prologue walk-off)"):
		return
	var ex: Dictionary = detours["exit"]
	assert_eq(ex.get("icon"), "res://art/icons/activities/exit.svg")
	assert_eq(ex.get("clip"), "bellows/loco_stomp")
	assert_eq(ex.get("kind"), null, "exit is no fix-up")


# --- Gate 0 ---------------------------------------------------------------------------------------

func test_g0_sneeze_is_a_cant_fail_draft_that_ends_after_the_sneeze() -> void:
	if not assert_true(eps.has("g0_sneeze"), "episodes/g0_sneeze.json"):
		return
	var g: Dictionary = eps["g0_sneeze"]
	assert_eq(g.get("status"), "draft", "Gate 0 is a dev episode (stage door only)")
	assert_eq(g.get("rooms"), ["parlour", "kitchen"])
	assert_eq(g.get("backstage"), ["hall"])
	assert_eq(g.get("card"), null, "no loading card")
	assert_eq(g.get("cold_open"), null, "no cold open")
	var r: Dictionary = g.get("rules", {})
	assert_eq(r.get("senses"), false, "senses off: he never starts a '?' (s2-sim §4.5.9)")
	assert_eq(r.get("cant_fail"), true)
	assert_eq(float(r.get("spot_fill_s", 0)), 2.0)
	assert_eq(int(r.get("tomatoes", 0)), -1)
	assert_eq(r.get("curtain_calls"), false)
	assert_eq(r.get("loop_repeat"), false)
	assert_eq(g.get("hush", {}).get("start", {}).get("room"), "kitchen", "Hush starts in the kitchen (no climb-in)")
	assert_false(g.get("hush", {}).has("enter"), "no climb-in")
	var loop: Array = g.get("bellows", {}).get("loop", [])
	assert_eq(loop.map(func(x): return x.get("a")), ["warmup", "tea", "warmup"])
	var gate: Dictionary = loop[0].get("gate", {})
	assert_eq(gate.get("until"), "rigged:achoo_ria")
	assert_eq(float(gate.get("plus_s", 0)), 2.0)
	assert_eq(gate.get("max_s", "x"), null, "the warm-up waits for the player")
	assert_eq(gate.get("first_loop_only"), true)
	var script: Array = g.get("script", [])
	assert_eq(script.size(), 1, "one line: the sneeze")
	assert_eq(script[0].get("prank"), "achoo_ria")
	assert_eq(script[0].get("req"), true)
	var end: Dictionary = g.get("director", {}).get("end", {})
	assert_eq(end.get("reason"), "g0_done")
	assert_eq(end.get("when"), {"event_seen": {"event": "reaction_end", "match": {"prank": "achoo_ria"}, "after_s": 3.0}})


func test_g0_sneeze_copies_the_prologue_ghost_cues_and_safety_net() -> void:
	if not (eps.has("g0_sneeze") and eps.has("p00_curtain_up")):
		skip("g0_sneeze or p00_curtain_up missing")
		return
	var g: Dictionary = eps["g0_sneeze"]["director"]
	var p: Dictionary = eps["p00_curtain_up"]["director"]
	var pc := {}
	for c in p.get("cues", []):
		pc[c["id"]] = c
	var ids: Array = []
	for c in g.get("cues", []):
		ids.append(c["id"])
		if assert_true(pc.has(c["id"]), "g0 cue %s is a Prologue cue id" % c["id"]):
			for k in ["target", "mode", "until"]:
				assert_eq(c.get(k), pc[c["id"]].get(k), "g0 cue %s.%s matches the Prologue" % [c["id"], k])
	assert_eq(ids, ["ghost_honey", "ghost_hold", "ghost_hide"])
	assert_eq(g.get("safety_net"), p.get("safety_net"), "the Prologue safety net")


func test_g0_ideal_route_gates() -> void:
	if not sols.has("g0_sneeze"):
		assert_true(false, "solutions/g0_sneeze.json")
		return
	var ex: Dictionary = sols["g0_sneeze"]["routes"]["ideal"]["expect"]
	assert_eq(int(ex.get("first_prank_s_max", 0)), 30)
	assert_eq(ex.get("lines"), ["sneeze"])
	var steps: Array = sols["g0_sneeze"]["routes"]["ideal"]["steps"]
	var last: Dictionary = steps[steps.size() - 1]
	assert_eq(last.get("event"), "night_end")
	assert_eq(last.get("match"), {"reason": "g0_done"}, "the route ends by g0_done")


# --- D1 expects, scenario routes, rules ----------------------------------------------------------

func test_every_route_carries_the_d1_gates() -> void:
	for e in sols:
		for rn in sols[e]["routes"]:
			var r: Dictionary = sols[e]["routes"][rn]
			var ex: Dictionary = r.get("expect", {})
			for k in ex:
				assert_false(String(k).begins_with("warn_"), "%s/%s: no warn_ expect key left (%s)" % [e, rn, k])
			var persona := String(r.get("persona", rn))
			if persona == "scenario":
				assert_true(ex.get("events_min") is Dictionary and not (ex["events_min"] as Dictionary).is_empty(),
					"%s/%s: a scenario route states its events_min" % [e, rn])
				continue
			assert_true(DEAD_AIR_MAX.has(persona), "%s/%s persona %s" % [e, rn, persona])
			assert_eq(int(ex.get("dead_air_pct_max", -1)), int(DEAD_AIR_MAX.get(persona, 0)), "%s/%s dead_air_pct_max" % [e, rn])
			assert_eq(int(ex.get("max_gap_s_max", -1)), MAX_GAP_S, "%s/%s max_gap_s_max" % [e, rn])


func test_scenario_routes_cover_the_staging_set_pieces() -> void:
	var want := {
		"n01_throat_tea": {"caught": ["caught", "doorstep"], "chase": ["chase_start", "door_slam"], "meltdown": ["meltdown_start"]},
	}
	# R3D (REDESIGN_3D §6.2 C2): the in-use hiding lesson (hall_clock_case, struck in Night 2) moves to Night 3.
	for rn in ["face_to_face", "face_to_face_lost"]:
		assert_false((sols.get("n02_something_fishy", {}).get("routes", {}) as Dictionary).has(rn),
			"n02_something_fishy/%s is retired" % rn)
	for e in want:
		if not assert_true(sols.has(e), "solutions/%s.json" % e):
			continue
		for rn in want[e]:
			var r: Dictionary = sols[e]["routes"].get(rn, {})
			if not assert_eq(r.get("persona"), "scenario", "%s/%s is a scenario route" % [e, rn]):
				continue
			for ev in want[e][rn]:
				assert_gt(int(r["expect"].get("events_min", {}).get(ev, 0)), 0, "%s/%s events_min.%s" % [e, rn, ev])


func test_act_one_allows_no_combo() -> void:
	for e in ACT_ONE:
		if assert_true(eps.has(e), e):
			assert_eq(eps[e].get("rules", {}).get("combos", null), [], "%s rules.combos is [] (POODLE stays Night 3's, L4)" % e)


func test_ghost_ff_is_taught_once_at_a_hidden_wait() -> void:
	var found: Array[String] = []
	for e in eps:
		var dir: Variant = eps[e].get("director", null)
		if not dir is Dictionary:
			continue
		for c in (dir as Dictionary).get("cues", []):
			if c.get("id") == "ghost_ff":
				found.append(e)
				assert_eq(c.get("target"), "clarence", "ghost_ff points at Clarence (⏩ lives on the left thumb)")
				assert_eq(c.get("mode"), "hold")
				assert_eq(c.get("card"), "ff")
				assert_eq(c.get("until"), {"hush_hidden": false})
				assert_true(JSON.stringify(c.get("when")).contains("hush_hidden"), "ghost_ff only while Hush is hidden")
	assert_eq(found, ["p00_curtain_up"], "exactly one ghost_ff cue in the slice (the Prologue)")


func test_slice_script_hints_are_complete() -> void:
	for e in eps:
		for ln in eps[e].get("script", []):
			var h: Variant = ln.get("hint", null)
			if not assert_true(h is Dictionary, "%s line %s has a hint" % [e, ln.get("id")]):
				continue
			for k in ["item", "container", "rig_point", "when"]:
				assert_true((h as Dictionary).has(k), "%s line %s hint.%s" % [e, ln.get("id"), k])
			assert_true(acts.has(String(h.get("when", ""))), "%s line %s hint.when names an activity" % [e, ln.get("id")])
			assert_true(C.all_hotspots().has(String(h.get("rig_point", ""))), "%s line %s hint.rig_point" % [e, ln.get("id")])
			if h.get("item") != null:
				assert_true(C.all_hotspots().has(String(h.get("container", ""))), "%s line %s hint.container" % [e, ln.get("id")])


func test_act_one_loading_cards() -> void:
	for e in ACT_ONE:
		var card: Dictionary = eps[e].get("card", {})
		var words := String(card.get("text", "")).split(" ", false).size()
		assert_between(words, 1, 25, "%s loading card ≤ 25 words" % e)
		assert_true(UiIcons.CARD_ALIASES.has(String(card.get("icon", ""))), "%s card icon key in UiIcons.CARD_ALIASES" % e)


func test_slice_icons_and_voice_banks_exist() -> void:
	var it: Variant = C.read("items.json")
	var icons: Array[String] = []
	for blk in [acts, detours, (it as Dictionary).get("items", {}) if it is Dictionary else {}]:
		for id in blk:
			icons.append(String((blk[id] as Dictionary).get("icon", "")))
	for p in icons:
		assert_true(FileAccess.file_exists(p) or ResourceLoader.exists(p), "icon %s exists" % p)
	var sfx: Variant = null
	if FileAccess.file_exists("res://audio/sfx_map.json"):
		sfx = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx_map.json"))
	if not sfx is Dictionary:
		skip("game/audio/sfx_map.json not readable")
		return
	var banks: Dictionary = (sfx as Dictionary).get("banks", {})
	var aliases: Dictionary = (sfx as Dictionary).get("aliases", {})
	var files: Dictionary = (sfx as Dictionary).get("files", {})
	var barks: Variant = C.read("barks.json")
	for k in (barks as Dictionary).get("voice", {}):
		var v: Dictionary = barks["voice"][k]
		if int(v.get("stage", 1)) > 2:
			continue
		var b := String(v.get("bank", ""))
		assert_true(b.begins_with("vo_") and (banks.has(b) or aliases.has(b) or files.has(b)), "bark %s bank %s in sfx_map.json" % [k, b])


# --- real sim (soft) ----------------------------------------------------------------------------

func test_act_one_loops_fit_sixty_seconds_hush_idle() -> void:
	var why := _real_why()
	if why != "":
		skip(why)
		return
	for e in ACT_ONE:
		var w := SolverHooks.make_world(_db, e, {})
		var pl := Planner.new(_data, e)
		var pred := pl.predict(w, 3)
		var first := String((eps[e]["bellows"]["loop"] as Array)[0].get("a", ""))
		var starts: Array[int] = []
		for a in pred.get("activities", []):
			if String(a.get("id", "")) == first:
				starts.append(int(a.get("t", 0)))
		if not assert_gt(starts.size(), 2, "%s: three loop starts in a Hush-idle run" % e):
			continue
		# the first loop may hold on a player-led gate (N01's warm-up: 25 s); later loops are the clock
		var steady := (starts[2] - starts[1]) / 60.0
		print("  [content] %s Hush-idle loop %.1f s (first loop %.1f s)" % [e, steady, (starts[1] - starts[0]) / 60.0])
		assert_true(steady <= LOOP_MAX_S, "%s loop %.1f s ≤ %.0f s (D1)" % [e, steady, LOOP_MAX_S])


func test_n02_first_prank_within_twenty_five_seconds() -> void:
	var why := _real_why()
	if why != "":
		skip(why)
		return
	for rn in ["ideal", "required"]:
		var rep := _report("n02_something_fishy", rn)
		var fp := float(rep.get("first_prank_s", -1.0))
		assert_true(fp > 0.0 and fp <= N02_FIRST_PRANK_MAX_S, "N02 %s first prank %.1f s ≤ 25 s" % [rn, fp])
	var slow := float(_report("n02_something_fishy", "slow").get("first_prank_s", -1.0))
	assert_true(slow > 0.0 and slow <= 30.0, "N02 slow first prank %.1f s ≤ 30 s" % slow)


func test_no_combo_on_act_one_routes() -> void:
	var why := _real_why()
	if why != "":
		skip(why)
		return
	for e in ACT_ONE:
		for rn in ["ideal", "required", "slow"]:
			var rep := _report(e, rn)
			var counts: Dictionary = rep.get("event_counts", {})
			assert_eq(int(counts.get("combo", 0)), 0, "%s/%s forms no combo" % [e, rn])
			assert_false(rep.is_empty(), "%s/%s ran on the real sim" % [e, rn])
