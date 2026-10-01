## AudioDirector (TECH §5.8, GDD §6.5): laugh tiers from applause deltas and links, the
## laugh starting 8 frames later (at the hold), merging, specials for the Stalls, music-state
## rules, panning and room attenuation — on synthetic events.
extends TestBase

var _w: FakeWorld = null
var _d: SimDriver = null
var _a: AudioDirector = null
var _laughs: Array = []
var _specials: Array = []


func before_each() -> void:
	_w = FakeWorld.create()
	_w.loop = false
	_d = SimDriver.new()
	_d.juice.test_now_us = 1
	_d.setup(_w)
	_a = AudioDirector.new()
	_a.record = true
	_a.setup(_d, null, null)
	_a.load_cues("res://__no_such_cues__.json")   # the built-in defaults: tests don't depend on the audio task's file
	_laughs.clear()
	_specials.clear()
	_a.laugh.connect(func(t: int) -> void: _laughs.append(t))
	_a.crowd_special.connect(func(k: String) -> void: _specials.append(k))


func after_each() -> void:
	_a.free()
	_d.free()


func _frames(n: int) -> void:
	for i in n:
		_d.advance(1.0 / 60.0)
		_a.advance(1.0 / 60.0)


func test_laugh_tier_table() -> void:
	assert_eq(AudioDirector.laugh_tier(100, 1, false, false), 1, "< 12 Applause → T1")
	assert_eq(AudioDirector.laugh_tier(120, 1, false, false), 2, "12 → T2")
	assert_eq(AudioDirector.laugh_tier(240, 1, false, false), 2, "24 → T2")
	assert_eq(AudioDirector.laugh_tier(241, 1, false, false), 3, "> 24 → T3")
	assert_eq(AudioDirector.laugh_tier(50, 2, false, false), 3, "link 2 → T3")
	assert_eq(AudioDirector.laugh_tier(50, 3, false, false), 4, "link 3 → T4")
	assert_eq(AudioDirector.laugh_tier(50, 1, true, false), 4, "signature → T4")
	assert_eq(AudioDirector.laugh_tier(50, 1, false, true), 4, "Meltdown → T4")


func test_gag_laugh_starts_at_the_hold() -> void:
	_a.on_ticked([{"e": "applause", "delta": 350, "total": 350, "kind": "gag", "label": "x", "t": 1}])
	_frames(6)
	assert_eq(_laughs, [], "not before the hold")
	_frames(4)
	assert_eq(_laughs, [3], "T3 after ~8 frames")
	assert_has(_a.calls, ["crowd", "t3"])


func test_laughs_merge_to_the_max_tier() -> void:
	_a.on_ticked([{"e": "applause", "delta": 100, "kind": "gag", "t": 1},
		{"e": "applause", "delta": 80, "kind": "bonus", "label": "MELTDOWN!", "t": 1}])
	_frames(12)
	assert_eq(_laughs, [4])


func test_rigged_titter_and_cue_calls() -> void:
	_a.on_ticked([{"e": "rigged", "prank": "achoo_ria", "t": 1}])
	_frames(2)
	assert_eq(_laughs, [], "the titter waits for its delay")
	_frames(25)
	assert_eq(_laughs, [0], "T0 titter")
	assert_has(_a.calls, ["sting", "rigged"])


func test_specials_for_the_stalls() -> void:
	_a.on_ticked([{"e": "spot_start", "by": "bellows", "t": 1}])
	_a.on_ticked([{"e": "near_miss", "by": "bellows", "t": 2}])
	_a.on_ticked([{"e": "caught", "cause": "grab", "spotted_tick": 1, "t": 3}])
	_a.on_ticked([{"e": "entry_warning", "room": "kitchen", "eta": 90, "t": 4}])
	_frames(30)
	assert_eq(_specials, ["gasp", "relief", "aww", "behind_you"])


func test_behind_you_only_when_exposed() -> void:
	_w.hush.state = "HIDDEN"
	_d.step_now()
	_a.on_ticked([{"e": "entry_warning", "room": "kitchen", "eta": 90, "t": 4}])
	_frames(30)
	assert_false(_specials.has("behind_you"))


func test_music_state_rules() -> void:
	assert_eq(AudioDirector.music_for("CHASE", 0.0, false, -1), "chase")
	assert_eq(AudioDirector.music_for("ROUTINE", 0.4, true, -1), "suspense", "a ? filling")
	assert_eq(AudioDirector.music_for("ROUTINE", 0.4, false, -1), "sneak", "a ? draining")
	assert_eq(AudioDirector.music_for("ROUTINE", 0.0, false, 100), "suspense", "≤ 2 s from an armed prank")
	assert_eq(AudioDirector.music_for("ROUTINE", 0.0, false, 200), "sneak")


func test_music_follows_the_world() -> void:
	_frames(1)
	assert_eq(_a.music(), "sneak")
	_w.seek(2500)
	_d.step_now()
	_frames(1)
	assert_eq(_a.music(), "chase", "CHASE at 2500 on the fake timeline")
	assert_has(_a.calls, ["music_state", "chase"])


func test_armed_prank_eta_drives_suspense() -> void:
	_w.seek(554)       # ACHOO-RIA! is rigged and he is at tea (fires at 680)
	for i in SimDriver.SLOW_REFRESH_TICKS:
		_d.step_now()
	_a.info = ContentInfo.of(_w)
	_frames(1)
	assert_eq(_a.music(), "suspense")


func test_chain_sections_follow_the_link() -> void:
	_a.on_ticked([{"e": "running_gag", "link": 2, "mult": 150, "t": 1}])
	_a.on_ticked([{"e": "running_gag", "link": 6, "mult": 300, "t": 2}])
	_a.on_ticked([{"e": "running_gag_end", "t": 3}])
	assert_has(_a.calls, ["chain_section", 2])
	assert_has(_a.calls, ["chain_section", 4])
	assert_has(_a.calls, ["chain_section", 0])


func test_pan_and_attenuation() -> void:
	assert_almost_eq(AudioDirector.pan_for(0.0, 2400.0), -0.85, 0.001)
	assert_almost_eq(AudioDirector.pan_for(1200.0, 2400.0), 0.0, 0.001)
	assert_almost_eq(AudioDirector.pan_for(2400.0, 2400.0), 0.85, 0.001)
	assert_eq(AudioDirector.attenuation_db(0), 0.0)
	assert_eq(AudioDirector.attenuation_db(1), -6.0)
	assert_eq(AudioDirector.attenuation_db(3), -18.0)
	assert_eq(AudioDirector.attenuation_db(9), -24.0)
	assert_eq(AudioDirector.attenuation_db(-1), -24.0)


func test_cues_json_overrides_defaults() -> void:
	var path := "user://test_cues.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"events": {"rigged": {"sfx": ["ding", "pluck"], "crowd": "t0"}},
		"laugh_tiers": {"t1_max": 100, "t2_max": 200}}))
	f.close()
	ViewKit.clear_json_cache()
	_a.load_cues(path)
	_a.calls.clear()
	_a.on_ticked([{"e": "rigged", "prank": "x", "t": 1}])
	assert_eq(_a.t1_max, 100)
	var sfx := 0
	for c in _a.calls:
		if c[0] == "play_sfx":
			sfx += 1
	assert_eq(sfx, 2, "both sfx played")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_audio_task_cues_json_runs_if_present() -> void:
	if not FileAccess.file_exists(AudioDirector.CUES):
		skip("data/audio/cues.json not written yet (audio)")
		return
	ViewKit.clear_json_cache()
	_a.load_cues()
	assert_gt(_a.events.size(), 10, "events parsed")
	_a.calls.clear()
	var evs := [{"e": "rigged", "prank": "achoo_ria"}, {"e": "hide", "spot": "kitchen_pantry_curtain", "watched": true},
		{"e": "specs", "on": true}, {"e": "entry_warning", "room": "kitchen", "eta": 90},
		{"e": "prank_fire", "prank": "achoo_ria", "link": 1}, {"e": "reaction_start", "prank": "achoo_ria",
		"archetype": "sneeze_blast", "variant": "a", "len": 150}, {"e": "reaction_accent", "prank": "achoo_ria"},
		{"e": "applause", "delta": 350, "kind": "gag"}, {"e": "running_gag", "link": 2}, {"e": "temper_tier", "tier": 3},
		{"e": "squeak_bit", "bit": "bit_warmup", "score": 20}, {"e": "caught", "cause": "grab"},
		{"e": "lecture", "variant": 1}, {"e": "meltdown_start"}]
	for ev in evs:
		ev["t"] = 1
	_a.on_ticked(evs)
	_frames(120)
	assert_gt(_a.calls.size(), 10, "cue actions were played")
	assert_has(_laughs, 4, "Meltdown → T4")


# --- s2-view §4.1.11: sound timing and ownership (ruling L12) --------------------------------

func test_cue_delays_count_in_view_time_so_hitstop_holds_them() -> void:
	_a.events = {"prank_fire": {"sfx": "splash", "delay_s": 0.1}}
	_a.on_ticked([{"e": "prank_fire", "prank": "x", "t": 1}])
	_d.juice.test_now_us = 1000
	_d.juice.request_kind(&"hit_big")
	# 5 frames of hit-stop: view time frozen → the splash waits.
	for i in 5:
		_d.juice.test_now_us += 16667
		_frames(1)
	var n := 0
	for c in _a.calls:
		if c[0] == "play_sfx" and c[1] == "splash":
			n += 1
	assert_eq(n, 0, "held by the hit-stop")
	for i2 in 12:
		_d.juice.test_now_us += 16667
		_frames(1)
	n = 0
	for c2 in _a.calls:
		if c2[0] == "play_sfx" and c2[1] == "splash":
			n += 1
	assert_eq(n, 1, "plays once view time has passed 0.1 s")


func test_no_sound_id_twice_within_100_ms() -> void:
	_a.events = {"bump": {"sfx": "woodblock_bonk"}}
	_a.on_ticked([{"e": "bump", "t": 1}, {"e": "bump", "t": 1}])
	_frames(3)
	_a.on_ticked([{"e": "bump", "t": 4}])
	var n := 0
	for c in _a.calls:
		if c[0] == "play_sfx" and c[1] == "woodblock_bonk":
			n += 1
	assert_eq(n, 1, "three bonks within 100 ms → one")
	assert_eq(_a.skipped_repeats, 2)
	_frames(8)
	_a.on_ticked([{"e": "bump", "t": 20}])
	n = 0
	for c2 in _a.calls:
		if c2[0] == "play_sfx" and c2[1] == "woodblock_bonk":
			n += 1
	assert_eq(n, 2, "after 100 ms it may play again")


## A stand-in CharacterView3D: the clip it plays (AudioDirector reads current_clip / overlay_clip, duck-typed).
class _StubCV:
	extends RefCounted
	var clip: String = ""
	func current_clip() -> String:
		return clip
	func overlay_clip() -> String:
		return ""


class _StubWV:
	extends RefCounted
	var bellows_view := _StubCV.new()
	var hush_view := _StubCV.new()


## L12 in 3D: an event-level cue whose sound the playing 3D clip already carries (its sidecar) is skipped.
func test_event_cue_repeating_a_clip_sound_is_skipped() -> void:
	var wv := _StubWV.new()
	_a.world_view = wv
	AudioDirector.prefer3d = true
	_a.events = {"reaction_accent": {"voice": "vo_bellows_sneeze_choo"}}
	wv.bellows_view.clip = "bellows/rx_sneeze_blast_a"
	assert_has(AudioDirector.clip_sounds("bellows/rx_sneeze_blast_a"), "vo_bellows_sneeze_choo")
	allow_errors()
	_a.on_ticked([{"e": "reaction_accent", "prank": "achoo_ria", "t": 1}])
	var n := 0
	for c in _a.calls:
		if c[0] == "play_voice" and c[1] == "vo_bellows_sneeze_choo":
			n += 1
	assert_eq(n, 0, "the clip owns the CHOO: the event-level cue never doubles it")
	assert_eq(_a.skipped_dups, 1)
	_a.world_view = null


## One mouth (R3D): a new voice line of his cuts the one still sounding (counted), a repeat within 100 ms does not.
func test_one_mouth_a_new_line_cuts_the_last() -> void:
	_a.on_clip_event({"type": "voice", "id": "vo_bellows_yodel", "actor": "bellows"})
	assert_eq(_a.voice_cuts, 0, "nothing to cut")
	_frames(30)
	_a.on_clip_event({"type": "voice", "id": "vo_bellows_the_pipes", "actor": "bellows"})
	assert_eq(_a.voice_cuts, 1, "the pipes cut the yodel")
	var n := 0
	for c in _a.calls:
		if c[0] == "play_voice":
			n += 1
	assert_eq(n, 2, "both lines started")
	_frames(200)
	_a.on_clip_event({"type": "voice", "id": "vo_bellows_hum", "actor": "bellows"})
	assert_eq(_a.voice_cuts, 1, "a line 3 s later is not a cut")
