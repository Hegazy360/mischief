## The clip-event frame table (ruling L12): `data/audio/clip_events.json`, generated with
## docs/review/s2-sound/clip_events.md by tools/audio/clip_events.py (gen_audio --check fails
## when either is stale). Every row resolves; the sneeze is cut to reactions.json's beats; the
## crash → 300 ms of silence → ladle rule holds; the warm-up sings once per 6 s; and no id is
## both a cues.json action of an event and a row of a clip that event plays over.
extends TestBase

const TABLE := "res://data/audio/clip_events.json"
const CUES := "res://data/audio/cues.json"
const MAP := "res://audio/sfx_map.json"
const REACTIONS := "res://data/reactions.json"
const AUDIO := "res://autoload/audio.gd"
const FPS := 60.0
## Ids allowed in both cues.json and the clip table (never over the same clip — the per-event
## test still checks that), each with the reason. Phase M moves these event cues into their clips.
const SHARED_OK := {
	"vo_bellows_hum": "b_activity pickles / mirror hum until act_pickles / act_mirror carry it (Phase M)",
	"vo_bellows_ahem": "doorway_pause 'ahem' until st_straighten_cravat carries it (Phase M)",
}

var audio: Node = null
var table: Dictionary = {}
var cues: Dictionary = {}
var files: Dictionary = {}


func before_each() -> void:
	var t: Variant = load_json(TABLE)
	table = t if t is Dictionary else {}
	var c: Variant = load_json(CUES)
	cues = c if c is Dictionary else {}
	var m: Variant = load_json(MAP)
	files = (m as Dictionary).get("files", {}) if m is Dictionary else {}
	audio = (load(AUDIO) as GDScript).new()
	audio.auto_advance = false
	tree.root.add_child(audio)


func after_each() -> void:
	if audio != null:
		audio.free()
		audio = null


func _events(clip: String) -> Array:
	return ((table.get("clips", {}) as Dictionary).get(clip, {}) as Dictionary).get("events", [])


func _row(clip: String, id: String) -> Dictionary:
	for ev: Dictionary in _events(clip):
		if String(ev["id"]) == id:
			return ev
	return {}


## Length in frames of an id (its longest file), from sfx_map.json.
func _len_f(id: String) -> int:
	var best := 0.0
	for f: String in audio.resolve_files(id):
		best = maxf(best, float((files.get(f, {}) as Dictionary).get("len", 0.0)))
	return int(ceil(best * FPS))


func test_table_parses_and_every_row_resolves() -> void:
	assert_eq(int(table.get("version", 0)), 1, "clip_events.json parses")
	var clips: Dictionary = table.get("clips", {})
	assert_ge(clips.size(), 30, "the Phase-G set: sneeze, tea, warm-up, micro-gags, last beats, loco, Hush's kitchen")
	if files.is_empty():
		skip("sfx_map.json not generated")
		return
	var n := 0
	for clip: String in clips:
		assert_true(clip.begins_with("bellows/") or clip.begins_with("hush/"), "%s is a rig clip id" % clip)
		var len_f: Variant = (clips[clip] as Dictionary).get("len_f")
		for ev: Dictionary in (clips[clip] as Dictionary).get("events", []):
			n += 1
			assert_true(["sfx", "voice"].has(String(ev.get("type", ""))), "%s f%s type" % [clip, ev.get("f")])
			assert_true(audio.has_sfx(String(ev.get("id", ""))), "%s f%s '%s' resolves" % [clip, ev.get("f"), ev.get("id")])
			assert_ge(int(ev.get("f", -1)), 0)
			if len_f != null:
				assert_lt(int(ev.get("f", 0)), int(len_f), "%s f%s inside the clip" % [clip, ev.get("f")])
	assert_ge(n, 60, "%d rows" % n)
	for must in ["bellows/rx_sneeze_blast_a", "bellows/act_tea", "bellows/act_warmup", "bellows/mg_hum",
			"bellows/mg_admire_in_kettle", "bellows/mg_pinkie_up", "bellows/mg_trill", "bellows/beat_slow_burn",
			"hush/loco_walk", "hush/act_dive", "hush/act_pop", "hush/freeze_1", "hush/act_snicker", "hush/act_tinker_b"]:
		assert_true(clips.has(must), "table covers %s" % must)


func test_the_sneeze_is_cut_to_its_beats() -> void:
	var r: Variant = load_json(REACTIONS)
	if not (r is Dictionary) or files.is_empty():
		skip("reactions.json / sfx_map.json missing")
		return
	var rx: Dictionary = ((r as Dictionary).get("archetypes", {}) as Dictionary).get("sneeze_blast_a", {})
	var marks: Dictionary = rx.get("marks", {})
	var beats: Dictionary = rx.get("beats", {})
	var clip := "bellows/rx_sneeze_blast_a"
	assert_eq(int(_row(clip, "vo_bellows_sneeze_choo").get("f", -1)), int(marks.get("accent", -2)), "CHOO on the accent")
	assert_eq(int(_row(clip, "sink_crash").get("f", -1)), int(marks.get("knock_on", -2)), "the crash on the sink contact")
	var parts := [["vo_bellows_sneeze_ah1", "ah"], ["vo_bellows_sneeze_ah2", "ahh"], ["vo_bellows_sneeze_ah3", "ahhh"]]
	for p: Array in parts:
		var b: Array = beats.get(p[1], [0, 0])
		var f := int(_row(clip, p[0]).get("f", -1))
		assert_eq(f, int(b[0]), "%s starts its beat" % p[0])
		assert_le(f + _len_f(p[0]), int(b[1]), "%s is over before the next beat" % p[0])
	var fs: Array = beats.get("false_stop", [74, 94])
	var hm := int(_row(clip, "vo_bellows_sneeze_hm").get("f", -1))
	assert_between(hm, int(fs[0]), int(fs[1]) - 1, "the relieved 'hm' sits in the false stop")
	assert_le(hm + _len_f("vo_bellows_sneeze_hm"), int(fs[1]) - 4, "≥ 4 f of near-silence before the CHOO")
	var levels := []
	for id in ["vo_bellows_sneeze_ah1", "vo_bellows_sneeze_ah2", "vo_bellows_sneeze_ah3"]:
		levels.append(_row(clip, id))
	assert_eq(levels.size(), 3)
	# Treg-Brown: crash → ≥ 300 ms of silence → one ladle
	var crash := int(_row(clip, "sink_crash").get("f", 0))
	var ladle := int(_row(clip, "ladle_spin").get("f", 0))
	assert_ge(ladle, crash + _len_f("sink_crash") + 18, "300 ms of silence after the crash before the ladle")
	# the flight: stool scrape and whistle start with the recoil and end by the landing
	var travel: Dictionary = rx.get("travel", {})
	var wh := int(_row(clip, "slide_up_flight").get("f", 0))
	assert_between(wh, int(travel.get("from_f", 94)), int(travel.get("from_f", 94)) + 3, "the whistle starts the flight")
	assert_le(wh + _len_f("slide_up_flight"), int(travel.get("to_f", 112)) + 1, "…and ends on the landing")
	for ev: Dictionary in _events(clip):
		assert_ne(String(ev.get("type", "")), "laugh", "the T3 laugh is event-level, not a clip event")


func test_the_warmup_sings_once_per_6_s() -> void:
	var c: Dictionary = (table.get("clips", {}) as Dictionary).get("bellows/act_warmup", {})
	var len_f := int(c.get("len_f", 0))
	var starts: Array = []
	var nudges := 0
	for ev: Dictionary in c.get("events", []):
		if String(ev["type"]) == "voice":
			starts.append(int(ev["f"]))
		elif String(ev["id"]) == "vase_nudge":
			nudges += 1
	assert_ge(starts.size(), 1)
	assert_ge(nudges, starts.size() * 3, "the vase nudges on each note")
	for i in starts.size():
		var nxt: int = int(starts[i + 1]) if i + 1 < starts.size() else int(starts[0]) + len_f
		assert_ge(nxt - int(starts[i]), 360, "≤ 1 sung line per 6 s (loop wrap included)")


func test_l12_no_sound_is_both_an_event_cue_and_a_clip_event() -> void:
	var events: Dictionary = cues.get("events", {})
	var n := 0
	for row: Dictionary in table.get("event_clips", []):
		var e := String(row.get("event", ""))
		var flt := String(row.get("filter", ""))
		var cue_ids := {}
		_collect(events.get(e, null), flt, cue_ids)
		if e == "prank_fire":
			var pr := flt.get_slice("=", 1) if flt.contains("=") else ""
			for p: String in (cues.get("pranks", {}) as Dictionary):
				if pr == "" or p == pr:
					_collect(((cues["pranks"] as Dictionary)[p] as Dictionary).get("fire"), "", cue_ids)
		if e == "reaction_accent":
			for a: String in (cues.get("archetypes", {}) as Dictionary):
				_collect(((cues["archetypes"] as Dictionary)[a] as Dictionary).get("accent"), "", cue_ids)
		if e == "squeak_bit":
			_collect(cues.get("squeak_bits", {}), "", cue_ids)
		for clip: String in row.get("clips", []):
			for ev: Dictionary in _events(clip):
				n += 1
				var id := String(ev["id"])
				assert_false(cue_ids.has(id), "'%s' plays both on %s(%s) and inside %s (L12)" % [id, e, flt, clip])
	assert_gt(n, 40, "checked %d clip rows against their events" % n)


func test_no_clip_sound_is_any_event_level_cue() -> void:
	var cue_ids := {}
	for sect in ["events", "pranks", "archetypes", "squeak_bits"]:
		_collect(cues.get(sect, {}), "", cue_ids)
	for clip: String in (table.get("clips", {}) as Dictionary):
		for ev: Dictionary in _events(clip):
			var id := String(ev["id"])
			assert_false(cue_ids.has(id) and not SHARED_OK.has(id),
				"'%s' (a %s clip event) is also a cues.json action — one owner per sound" % [id, clip])


## Every sfx / voice id of an action tree into `out`; `flt` "field=value" follows only that
## `by` branch (or its default).
func _collect(v: Variant, flt: String, out: Dictionary) -> void:
	if v is Array:
		for x in v:
			_collect(x, flt, out)
		return
	if not (v is Dictionary):
		return
	var d: Dictionary = v
	if d.get("by", null) is Dictionary and flt.contains("="):
		var by: Dictionary = d["by"]
		if String(by.get("field", "")) == flt.get_slice("=", 0):
			var m: Dictionary = by.get("map", {})
			var key := flt.get_slice("=", 1)
			_collect(m.get(key, by.get("default", null)), "", out)
			return
	for k: String in d:
		if k == "sfx" or k == "voice":
			for id in (d[k] if d[k] is Array else [d[k]]):
				out[String(id)] = true
		elif d[k] is Dictionary or d[k] is Array:
			_collect(d[k], flt, out)


## Every Gate-0 micro-gag (activities.json `warmup` + `tea`) has its `bellows/mg_<id>` rows, sized to the
## gag's `len_f`; the brief's three are there (a trill, a hum, a teacup clink for pinkie_up); the tea's base
## clip carries no voice (the micro-gags do), and last beats end in silence (the slow burn: one note).
func test_gate0_micro_gags_and_last_beats() -> void:
	var a: Variant = load_json("res://data/activities.json")
	if not (a is Dictionary):
		skip("activities.json missing")
		return
	var acts: Dictionary = (a as Dictionary).get("activities", {})
	var clips: Dictionary = table.get("clips", {})
	var n := 0
	for aid: String in ["warmup", "tea"]:
		for mg: Dictionary in (acts.get(aid, {}) as Dictionary).get("micro_gags", []):
			var clip := "bellows/mg_" + String(mg.get("id", ""))
			n += 1
			assert_true(clips.has(clip), "%s micro-gag %s has clip events" % [aid, clip])
			var c: Dictionary = clips.get(clip, {})
			assert_eq(int(c.get("len_f", -1)), int(mg.get("len_f", -2)), "%s is sized to the gag" % clip)
			assert_false((c.get("events", []) as Array).is_empty(), "%s makes a sound" % clip)
			for ev: Dictionary in c.get("events", []):
				assert_lt(int(ev["f"]), int(mg.get("len_f", 0)), "%s f%d inside the gag" % [clip, int(ev["f"])])
	assert_ge(n, 6, "the six Gate-0 micro-gags")
	assert_eq(String(_row("bellows/mg_trill", "vo_bellows_trill").get("type", "")), "voice", "a trill")
	assert_eq(String(_row("bellows/mg_hum", "vo_bellows_hum").get("type", "")), "voice", "a hum")
	assert_false(_row("bellows/mg_pinkie_up", "teacup_clink").is_empty(), "a teacup clink for pinkie_up")
	for ev: Dictionary in _events("bellows/act_tea"):
		assert_ne(String(ev["type"]), "voice", "the tea's base clip is voice-free (f%d)" % int(ev["f"]))
	var burn: Array = _events("bellows/beat_slow_burn")
	assert_eq(burn.size(), 1, "the slow burn: ONE low bassoon note, then silence")
	if burn.size() == 1:
		assert_eq(String((burn[0] as Dictionary)["id"]), "bassoon_burn")
		assert_le(int((burn[0] as Dictionary)["f"]) + _len_f("bassoon_burn"), 60, "…and ≥ 10 f of dry silence")
	for beat in ["bellows/beat_dignity_fail", "bellows/beat_bow_topple", "bellows/beat_tear"]:
		assert_false(_events(beat).is_empty(), "%s has its sounds" % beat)


## The tea ends in the sip that ACHOO-RIA! fires on: the slurp lands before the trigger mark and the
## sneeze's first 'ah' answers it at the reaction's f0.
func test_the_sip_leads_into_the_sneeze() -> void:
	var p: Variant = load_json("res://data/pranks.json")
	if not (p is Dictionary):
		skip("pranks.json missing")
		return
	var pr: Dictionary = ((p as Dictionary).get("pranks", {}) as Dictionary).get("achoo_ria", {})
	var mark_f := int(round(float((pr.get("trigger", {}) as Dictionary).get("mark_s", 7.0)) * FPS))
	var sip := _row("bellows/act_tea", "tea_slurp")
	assert_false(sip.is_empty(), "the tea has its sip")
	assert_le(int(sip.get("f", 9999)) + _len_f("tea_slurp"), mark_f, "the slurp is over by the trigger (f%d)" % mark_f)
	assert_ge(int(sip.get("f", 0)), mark_f - 45, "…and close to it (the joke reads as sip → ah…)")
	assert_eq(int(_row("bellows/rx_sneeze_blast_a", "vo_bellows_sneeze_ah1").get("f", -1)), 0)


## The contract with the anim tasks, checked on every clip that exists (L12): every sfx / voice event in a
## clip is a row of the table — the id, and the frame ± 1 f when the clip has the table's length (a clip the
## table sizes as "the anim task's", len_f null, may retime its rows). A row the anim task has not placed yet
## is listed (soft: the anim tasks are placing them in this batch; `clip_events.py --status` writes the list
## to docs/review/s2-sound/placement.md), a sound the table doesn't publish fails.
func test_existing_clips_carry_their_rows() -> void:
	var checked := 0
	var pending := PackedStringArray()
	for clip: String in (table.get("clips", {}) as Dictionary):
		var path := "res://data/anim/%s.json" % clip
		if not FileAccess.file_exists(path):
			continue
		var d: Variant = load_json(path)
		if not (d is Dictionary):
			continue
		checked += 1
		var have: Array = []
		for ev: Dictionary in (d as Dictionary).get("events", []):
			var t := String(ev.get("type", ""))
			if t == "sfx" or t == "voice":
				have.append([int(ev.get("f", -1)), String(ev.get("id", ev.get("bank", "")))])
		var tlen: Variant = ((table["clips"] as Dictionary)[clip] as Dictionary).get("len_f")
		var exact := tlen != null and int(tlen) == int((d as Dictionary).get("length", -1))
		var left := have.duplicate()
		for r: Dictionary in _events(clip):
			var hit := -1
			for i in left.size():
				var h: Array = left[i]
				if String(h[1]) == String(r["id"]) and (not exact or absi(int(h[0]) - int(r["f"])) <= 1):
					hit = i
					break
			if hit >= 0:
				left.remove_at(hit)
			else:
				pending.append("%s f%d %s" % [clip, int(r["f"]), r["id"]])
		assert_true(left.is_empty(), "%s: sounds not published in clip_events.md (or off their frame): %s" % [clip, left])
	if not pending.is_empty():
		print("  [clip events] %d row(s) still to place: %s" % [pending.size(), ", ".join(pending)])
	if checked == 0:
		skip("no clip of the table exists yet")
