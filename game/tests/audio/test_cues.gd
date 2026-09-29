## data/audio/cues.json (TECH §5.8) and audio/sfx_map.json: event keys are sim events
## (`SimEvents.ALL`, TECH §3.8), every referenced id resolves, content keys are canonical ids
## (TECH §14), and ruling L12 holds: no prank fire voice, no archetype accent kit, no squeak-bit
## line (those live in clips), no title-card cue during play, the command-feedback and the
## Prologue director-laugh cues exist.
extends TestBase

const CUES := "res://data/audio/cues.json"
const MAP := "res://audio/sfx_map.json"
const AUDIO := "res://autoload/audio.gd"

## TECH §3.8 — every sim event name (the fallback when SimEvents is not loadable).
const SIM_EVENTS: PackedStringArray = [
	"hush_go", "hush_arrive", "hush_room", "rummage", "pick_window", "pick", "item_home", "restock", "rig_start",
	"rig_pause", "rig_step_done", "rigged", "hide", "pop_out", "freeze", "noise", "squeak", "pin",
	"b_activity", "b_activity_end", "b_next", "b_detour", "b_room", "entry_warning", "doorway_pause", "specs", "glyph",
	"look_back", "ear_pip", "squeak_bit", "head_turn", "lure", "lure_fatigue",
	"spot_start", "near_miss", "spotted", "chase_start", "wheeze", "door_slam", "chase_end", "search", "on_guard",
	"bump", "face_to_face", "caught", "busted_cam", "lecture", "doorstep", "tomato", "hook",
	"prank_fire", "reaction_start", "reaction_accent", "reaction_end", "knock_on", "fizzle", "residue_add",
	"residue_clear", "combo", "temper_tier", "running_gag", "running_gag_end", "meltdown_start", "meltdown_stomp",
	"exhausted", "panto_round", "panto_bit", "mirror_round", "wink", "headbutt",
	"applause", "bonus", "line_done", "big_number_unsealed", "all_lines_done", "star",
	"director_cue", "safety_net", "figgis_hook", "night_end", "cmd_rejected", "cmd_queued",
	"beryl_mood", "bleat", "herd_start", "herd_end", "delphine_arrive", "glasses", "high_c", "embarrassed"]
## TECH §14 canonical ids.
const PRANKS: PackedStringArray = [
	"achoo_ria", "tap_dance", "kettle_drum", "in_a_pickle", "cold_open", "allegro_go_go", "lift_off",
	"eye_popping_news", "bellows_blows", "prima_ballerina", "grand_exit", "it_takes_two", "something_fishy", "times_up",
	"mirror_mirror", "rug_burn", "sopran_oh_no", "snap_decision", "in_over_his_head", "pipe_down", "pillow_talk",
	"butter_fingers", "kidding_around", "tutu_much", "award_winning", "hosed", "marrow_escape", "penny_pincher",
	"sweet_tooth", "spit_take", "fan_mail", "spotlight_stealer"]
const ARCHETYPES: PackedStringArray = [
	"sneeze_blast", "drench", "sing_crack", "strain_slip", "avalanche_helmet", "dizzy_spin", "launch_ceiling",
	"blind_bumble", "poof", "drop_on", "fish_slap", "jackhammer_cling", "surf_out", "squeaky_voice", "scare_leap",
	"steam_duel", "feather_burst", "costume_burn", "balloon_chase", "headbutt_launch", "goat_kiss", "suppressed",
	"sig_mirror_mirror", "sig_in_over_his_head", "sig_grand_exit", "sig_kidding_around", "sig_it_takes_two",
	"sig_spotlight_stealer"]
const SQUEAK_BITS: PackedStringArray = ["bit_warmup", "bit_tea", "bit_paper", "bit_mirror", "bit_phone", "bit_bath",
	"bit_nap", "bit_feed", "bit_piano", "bit_livid"]
const ACTION_KEYS: PackedStringArray = ["sfx", "voice", "sting", "crowd", "music", "chain", "delay_s", "vol_db", "pan",
	"when", "by", "then", "ooh", "accent", "fire"]

var audio: Node = null
var cues: Dictionary = {}


func before_each() -> void:
	var d: Variant = load_json(CUES)
	cues = d if d is Dictionary else {}
	audio = (load(AUDIO) as GDScript).new()
	audio.auto_advance = false
	tree.root.add_child(audio)


func after_each() -> void:
	if audio != null:
		audio.free()
		audio = null


func test_cues_parse() -> void:
	assert_false(cues.is_empty(), "cues.json parses")
	assert_eq(int(cues.get("version", 0)), 1)
	assert_true(cues.get("events") is Dictionary)


func test_event_keys_are_sim_events() -> void:
	var events: Dictionary = cues.get("events", {})
	assert_ge(events.size(), 40, "cues cover the Stage-1 events")
	var all: Array = SimEvents.ALL
	for k: String in events:
		assert_true(all.has(k), "'%s' is in SimEvents.ALL" % k)
	for must in ["rigged", "spot_start", "near_miss", "caught", "running_gag", "running_gag_end", "meltdown_start",
			"entry_warning", "squeak", "squeak_bit", "spotted", "chase_start", "chase_end", "fizzle", "lecture"]:
		assert_true(events.has(must), "cue for %s" % must)


func test_content_keys_are_canonical() -> void:
	for k: String in (cues.get("pranks", {}) as Dictionary):
		assert_true(PRANKS.has(k), "prank %s" % k)
	for k: String in (cues.get("archetypes", {}) as Dictionary):
		assert_true(ARCHETYPES.has(k), "archetype %s" % k)
	for k: String in (cues.get("squeak_bits", {}) as Dictionary):
		assert_true(SQUEAK_BITS.has(k), "squeak bit %s" % k)
	for p in ["kettle_drum", "tap_dance", "allegro_go_go", "something_fishy", "times_up"]:
		assert_true((cues.get("pranks", {}) as Dictionary).has(p), "slice prank %s has a (prop) fire cue" % p)


# --- ruling L12 -------------------------------------------------------------------------

func test_l12_no_clip_sounds_in_event_sections() -> void:
	for p: String in (cues.get("pranks", {}) as Dictionary):
		var ids := _action_ids((cues["pranks"] as Dictionary)[p], "voice")
		assert_true(ids.is_empty(), "pranks.%s.fire plays no voice line (his voice is in the clip): %s" % [p, ids])
	for a: String in (cues.get("archetypes", {}) as Dictionary):
		assert_false(((cues["archetypes"] as Dictionary)[a] as Dictionary).has("accent"),
			"archetypes.%s has no accent kit (the reaction clip carries its sounds)" % a)
	for b: String in (cues.get("squeak_bits", {}) as Dictionary):
		assert_true(_action_ids((cues["squeak_bits"] as Dictionary)[b], "voice").is_empty(),
			"squeak_bits.%s plays no voice line (the bit clip carries it)" % b)
	assert_false((cues.get("pranks", {}) as Dictionary).has("achoo_ria"),
		"the sneeze fires no event-level sound: all of it is rx_sneeze_blast_a's clip events")


func test_no_title_card_cue_during_play() -> void:
	var dc: Dictionary = (cues.get("events", {}) as Dictionary).get("director_cue", {})
	var m: Dictionary = (dc.get("by", {}) as Dictionary).get("map", {})
	assert_false(m.has("title_card"), "NightScene swallows title_card; the curtain call plays the sting")


func test_command_feedback_cues_on_the_ui_bus() -> void:
	var events: Dictionary = cues.get("events", {})
	var files: Dictionary = {}
	var m: Variant = load_json(MAP)
	if m is Dictionary:
		files = (m as Dictionary).get("files", {})
	for e in ["cmd_queued", "cmd_rejected"]:
		assert_true(events.has(e), "cue for %s" % e)
		var ids := _action_ids(events.get(e, {}), "sfx")
		assert_eq(ids.size(), 1, "%s plays one sound" % e)
		for id: String in ids:
			assert_true(audio.has_sfx(id), "%s → %s resolves" % [e, id])
			for f: String in audio.resolve_files(id):
				assert_eq(String((files.get(f, {}) as Dictionary).get("bus", "")), "UI", "%s is on the UI bus" % f)


func test_director_laughs_have_a_crowd_within_0_3_s() -> void:
	var dc: Dictionary = (cues.get("events", {}) as Dictionary).get("director_cue", {})
	var m: Dictionary = (dc.get("by", {}) as Dictionary).get("map", {})
	for id in ["laugh_vase", "laugh_doorframe", "laugh_relief", "laugh_picture"]:
		assert_true(m.has(id), "director cue %s" % id)
		var acts: Array = m.get(id, []) if m.get(id, []) is Array else [m.get(id, {})]
		var crowd_at := -1.0
		for a: Dictionary in acts:
			if a.has("crowd"):
				crowd_at = float(a.get("delay_s", 0.0))
		assert_between(crowd_at, 0.0, 0.3, "%s: the Stalls react within 0.3 s (pre-gate row 14)" % id)


func test_laugh_starts_at_the_hold() -> void:
	var lt: Dictionary = cues.get("laugh_tiers", {})
	var f := float(lt.get("hold_delay_s", 0.0)) * 60.0
	assert_between(f, 6.0, 12.0, "the laugh starts 6–12 f after the accent (GDD §6.5)")
	assert_almost_eq(float(lt.get("duck_under_voice_db", 0.0)), -6.0, 0.01)


## Every id under `key` ("sfx" / "voice") anywhere in an action tree.
func _action_ids(v: Variant, key: String) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array:
		for x in v:
			out.append_array(_action_ids(x, key))
	elif v is Dictionary:
		var d: Dictionary = v
		for k: String in d:
			if k == key:
				for id in (d[k] if d[k] is Array else [d[k]]):
					out.append(String(id))
			elif d[k] is Dictionary or d[k] is Array:
				out.append_array(_action_ids(d[k], key))
	return out


func test_every_referenced_id_resolves() -> void:
	if not FileAccess.file_exists(MAP):
		skip("sfx_map.json not generated")
		return
	var n := [0]
	for sect in ["events", "pranks", "archetypes", "squeak_bits"]:
		_walk(cues.get(sect, {}), sect, n)
	assert_gt(n[0], 60, "checked %d references" % n[0])


func _walk(v: Variant, where: String, n: Array) -> void:
	if v is Array:
		for i in (v as Array).size():
			_walk(v[i], "%s[%d]" % [where, i], n)
		return
	if not (v is Dictionary):
		return
	var d: Dictionary = v
	for k: String in d:
		var x: Variant = d[k]
		match k:
			"sfx", "voice":
				var ids: Array = x if x is Array else [x]
				for id in ids:
					n[0] += 1
					assert_true(audio.has_sfx(String(id)), "%s.%s '%s' resolves" % [where, k, id])
			"sting":
				n[0] += 1
				var sid := String(x)
				assert_true(audio.has_sfx(sid if sid.begins_with("sting_") else "sting_" + sid), "%s sting %s" % [where, x])
			"crowd":
				n[0] += 1
				assert_true(audio.CROWD_KINDS.has(String(x)), "%s crowd kind %s" % [where, x])
				assert_true(audio.has_sfx("crowd_" + String(x)), "%s crowd_%s resolves" % [where, x])
			"music":
				n[0] += 1
				assert_true(audio.MUSIC_STATES.has(String(x)), "%s music state %s" % [where, x])
			"chain":
				assert_true(x is float or x is int or String(x) == "link", "%s chain %s" % [where, x])
			"by":
				var by: Dictionary = x
				assert_true(by.has("field"), "%s.by has a field" % where)
				_walk(by.get("map", {}), where + ".by", n)
				_walk(by.get("default", {}), where + ".by.default", n)
			_:
				if x is Dictionary or x is Array:
					_walk(x, "%s.%s" % [where, k], n)


func test_laugh_tier_thresholds() -> void:
	var lt: Dictionary = cues.get("laugh_tiers", {})
	assert_eq(int(lt.get("t1_max", 0)), 120, "T1 below 12 Applause")
	assert_eq(int(lt.get("t2_max", 0)), 240, "T2 up to 24")
	assert_eq(int(lt.get("t3_link", 0)), 2)
	assert_eq(int(lt.get("t4_link", 0)), 3)
	assert_has(lt.get("t4_on", []), "meltdown_start")
	assert_has(lt.get("t4_on", []), "signature")


func test_music_meta_in_map() -> void:
	var m: Variant = load_json(MAP)
	if not (m is Dictionary):
		skip("sfx_map.json not generated")
		return
	var music: Dictionary = (m as Dictionary).get("music", {})
	for fid in ["mus_sneak", "mus_suspense", "mus_chase", "mus_chain_1", "mus_chain_2", "mus_chain_3", "mus_chain_4",
			"mus_curtain", "mus_results"]:
		assert_true(music.has(fid), fid)
		var md: Dictionary = music.get(fid, {})
		var frames := int(md.get("bars", 0)) * int(md.get("beats_per_bar", 0)) * int(md.get("spb", 0))
		assert_almost_eq(float(md.get("len", 0.0)), float(frames) / 22050.0, 0.002, "%s is a whole number of bars" % fid)
	var sneak := float((music.get("mus_sneak", {}) as Dictionary).get("len", 0.0))
	var sus := float((music.get("mus_suspense", {}) as Dictionary).get("len", 1.0))
	assert_between(sneak, 60.0, 90.0, "sneak loop 60–90 s")
	var ratio := sneak / sus
	assert_almost_eq(ratio, roundf(ratio), 0.001, "suspense divides the sneak loop (stays bar-synced)")
	assert_eq((m as Dictionary).get("stems", {}).get("sneak", []), ["mus_sneak", "mus_suspense"])
	var bpms := []
	for i in 4:
		bpms.append(float((music.get("mus_chain_%d" % (i + 1), {}) as Dictionary).get("bpm", 0.0)))
	for i in 3:
		assert_lt(bpms[i], bpms[i + 1], "chain tempos step up")


# --- the AudioDirector's names (view request: confirm the ids it plays) ------------------

## Every id / kind `view/audio_director.gd` plays by name (its fallback footsteps, its built-in default
## cues, its laugh path and the Stalls' specials) resolves in the Audio autoload.
func test_audio_director_names_resolve() -> void:
	if not FileAccess.file_exists(MAP):
		skip("sfx_map.json not generated")
		return
	var ids: PackedStringArray = ["bellows_step", "rig_done", "dive", "pop_out", "clarence_squeak", "door_jiggle",
		"door_slam_bonk", "tomato_splat", "stomp_quake", "specs_tink", "woodblock_bonk"]
	for i in range(1, 9):
		ids.append("step_pizz_%d" % i)
	for id: String in ids:
		assert_true(audio.has_sfx(id), "AudioDirector id '%s' resolves" % id)
	for s: String in ["rigged", "bit", "spot", "near_miss", "alert", "caught", "fizzle", "combo", "meltdown"]:
		assert_true(audio.has_sfx("sting_" + s), "sting %s" % s)
	# laugh tiers + StallsView.special() kinds (shush is the Stalls' spelling of shh)
	for k: String in ["t0", "t1", "t2", "t3", "t4", "relief", "gasp", "shush", "behind_you", "boo", "aww", "chant",
			"ooh", "cheer", "bow_chant"]:
		assert_true(audio.CROWD_KINDS.has(k), "crowd kind %s" % k)
		audio.crowd(k)
		var bank := "crowd_" + String(audio.CROWD_ALIASES.get(k, k))
		assert_true(String(audio.last_pick(bank)).begins_with(bank + "_"), "crowd(%s) plays a %s take" % [k, bank])
	# the director's laugh-tier names in clip `laugh` events
	var names: Dictionary = (cues.get("laugh_tiers", {}) as Dictionary).get("names", {})
	for n: String in ["titter", "chuckle", "laugh", "big", "roar"]:
		assert_true(names.has(n), "laugh tier name %s" % n)


## The events added in Stage 2 have cues: command feedback (event-level, UI bus) — and a micro-gag
## has none (its sounds are the mg_<id> clip's events, L12).
func test_stage2_event_cues() -> void:
	var events: Dictionary = cues.get("events", {})
	assert_true(events.has("cmd_queued") and events.has("cmd_rejected"), "command feedback cues")
	assert_false(events.has("micro_gag"), "no event-level micro-gag sound (clip events own them)")
	assert_false(cues.has("micro_gags"), "no cues.json micro-gag map")
