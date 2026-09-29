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
			"bellows/mg_pinkie_up", "bellows/mg_trill", "bellows/beat_slow_burn", "hush/loco_walk", "hush/act_dive",
			"hush/act_pop", "hush/freeze_1", "hush/act_snicker", "hush/act_tinker_b"]:
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
