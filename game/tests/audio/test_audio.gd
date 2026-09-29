## Audio autoload (TECH §5.8): resolution, no-ops, no-repeat banks, buses and volumes,
## ducking, the music state machine and the bar-synced chain switch.
extends TestBase

const AUDIO := "res://autoload/audio.gd"

var audio: Node = null


func before_each() -> void:
	audio = _make()


func after_each() -> void:
	if audio != null:
		audio.free()
		audio = null
	for b in ["Music", "SFX", "Voice", "Crowd", "UI"]:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, 0.0)
			AudioServer.set_bus_mute(i, false)
	var fake := tree.root.get_node_or_null("Settings")
	if fake != null and fake.has_meta("fake_settings"):
		fake.free()


func _make() -> Node:
	var a: Node = (load(AUDIO) as GDScript).new()
	a.auto_advance = false
	tree.root.add_child(a)
	return a


func _has_map() -> bool:
	return FileAccess.file_exists("res://audio/sfx_map.json")


# --- resolution + no-ops ---------------------------------------------------------------

func test_unknown_ids_are_silent_noops() -> void:
	audio.play_sfx("definitely_not_a_sound", 0.3, -3.0, 1.2)
	audio.play_voice("vo_nobody_nothing")
	audio.crowd("t9")
	audio.crowd("")
	audio.sting("nonexistent")
	audio.music_state("disco")
	audio.chain_section(99)
	audio.set_bus_volume("Kazoo", 0.5)
	audio.set_voice_style("banjo")
	audio.set_crowd_style("robots")
	audio.advance(0.5)
	assert_false(audio.has_sfx("definitely_not_a_sound"))
	assert_eq(audio.voice_style, "formant")
	assert_eq(audio.crowd_style, "formant")
	assert_eq(audio.current_state(), "silence", "unknown music state is ignored")


func test_ids_resolve_through_files_banks_and_aliases() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	assert_true(audio.has_sfx("woodblock_bonk"), "file id")
	assert_true(audio.has_sfx("bonk"), "alias → file")
	assert_true(audio.has_sfx("vo_bellows_hmph"), "bank")
	assert_eq(audio.resolve_files("vo_bellows_hmph").size(), 3, "12 nonverbals × 3 variants")
	assert_true(audio.has_sfx("sneeze_choo"), "TECH §4.8 clip-event name")
	assert_eq(audio.resolve_files("step_pizz").size(), 8, "8 pizzicato tiptoe notes")
	assert_eq(audio.resolve_files("clarence_squeak").size(), 5, "5 Clarence pitches")
	for tier in ["t0", "t1", "t2", "t3", "t4"]:
		assert_ge(audio.resolve_files("crowd_" + tier).size(), 3, "≥ 3 variants of %s" % tier)
	for s in ["rigged", "bit", "fizzle", "caught", "near_miss", "combo", "new", "meltdown", "link2", "link3"]:
		assert_true(audio.has_sfx("sting_" + s), "sting_" + s)


func test_streams_load_and_music_loops() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var s: AudioStream = audio._stream("woodblock_bonk")
	assert_true(s != null, "woodblock_bonk imports")
	var m: AudioStream = audio._stream("mus_sneak")
	assert_true(m is AudioStreamWAV, "mus_sneak is a WAV stream")
	if m is AudioStreamWAV:
		assert_eq((m as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "sneak loops")
	var c: AudioStream = audio._stream("mus_curtain")
	if c is AudioStreamWAV:
		assert_eq((c as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "the curtain is a one-shot")
	assert_gt(audio.warm_up(), 300, "every file loads")


# --- no immediate repeats ----------------------------------------------------------------

func test_pick_index_never_repeats() -> void:
	var script: GDScript = load(AUDIO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for count in [2, 3, 5]:
		var last := -1
		var seen := {}
		for _i in 200:
			var i: int = script.pick_index(count, last, rng.randi() & 0x7FFFFFFF)
			assert_between(i, 0, count - 1)
			if last >= 0:
				assert_ne(i, last, "never the same index twice (count %d)" % count)
			seen[i] = true
			last = i
		assert_eq(seen.size(), count, "every variant gets played")
	assert_eq(script.pick_index(1, 0, 12345), 0)


func test_no_immediate_repeats_over_50_voice_calls() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var last := ""
	var seen := {}
	for _i in 50:
		audio.play_voice("vo_bellows_hmph")
		var f: String = audio.last_voice_file()
		assert_true(f.begins_with("vo_bellows_hmph_"), "picked %s" % f)
		assert_ne(f, last, "no immediate repeat")
		seen[f] = true
		last = f
	assert_eq(seen.size(), 3)


func test_no_immediate_repeats_over_50_crowd_calls() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var last := ""
	for _i in 50:
		audio.crowd("t2")
		var f: String = audio.last_pick("crowd_t2")
		assert_ne(f, last, "no immediate repeat")
		last = f
		audio.advance(0.05)


# --- buses and volumes ---------------------------------------------------------------------

func test_buses_exist_and_route() -> void:
	for b in ["Music", "SFX", "Voice", "Crowd", "UI"]:
		var i := AudioServer.get_bus_index(b)
		assert_ge(i, 0, "bus %s exists" % b)
		assert_eq(String(AudioServer.get_bus_send(i)), "Master", "%s → Master" % b)
	for b in ["SFX_PanL2", "SFX_PanL1", "SFX_PanR1", "SFX_PanR2"]:
		assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index(b))), "SFX")
	for b in ["Voice_PanL", "Voice_PanR"]:
		assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index(b))), "Voice")


func test_bus_volume_mapping() -> void:
	for b in ["Music", "SFX", "Voice", "Crowd", "UI"]:
		var i := AudioServer.get_bus_index(b)
		audio.set_bus_volume(b, 0.5)
		assert_almost_eq(AudioServer.get_bus_volume_db(i), linear_to_db(0.5), 0.01, b)
		assert_false(AudioServer.is_bus_mute(i))
		assert_almost_eq(audio.bus_volume(b), 0.5, 0.0001)
		audio.set_bus_volume(b, 0.0)
		assert_true(AudioServer.is_bus_mute(i), "%s muted at 0" % b)
		audio.set_bus_volume(b, 1.0)
		assert_almost_eq(AudioServer.get_bus_volume_db(i), 0.0, 0.01)
		assert_false(AudioServer.is_bus_mute(i))
		audio.set_bus_volume(b, 3.0)
		assert_almost_eq(audio.bus_volume(b), 1.0, 0.0001, "clamped to 1")


func test_settings_keys_drive_volumes() -> void:
	if tree.root.get_node_or_null("Settings") != null:
		skip("a real Settings autoload is registered")
		return
	audio.free()
	var sc := GDScript.new()
	sc.source_code = "extends Node\nsignal changed(key: String, value: Variant)\n" \
		+ "var vals := {\"music_vol\": 0.25, \"sfx_vol\": 0.5, \"voice_vol\": 0.75, \"crowd_vol\": 0.0}\n" \
		+ "func get_value(k: String, fb: Variant = null) -> Variant:\n\treturn vals.get(k, fb)\n"
	sc.reload()
	var fake: Node = sc.new()
	fake.name = "Settings"
	fake.set_meta("fake_settings", true)
	tree.root.add_child(fake)
	audio = _make()
	assert_almost_eq(audio.bus_volume("Music"), 0.25, 0.0001)
	assert_almost_eq(audio.bus_volume("SFX"), 0.5, 0.0001)
	assert_almost_eq(audio.bus_volume("UI"), 0.5, 0.0001, "UI follows sfx_vol")
	assert_almost_eq(audio.bus_volume("Voice"), 0.75, 0.0001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Crowd")), "crowd_vol 0 mutes")
	fake.emit_signal("changed", "music_vol", 1.0)
	assert_almost_eq(audio.bus_volume("Music"), 1.0, 0.0001, "changed() re-applies")
	fake.emit_signal("changed", "haptics", false)
	assert_almost_eq(audio.bus_volume("Music"), 1.0, 0.0001)


# --- ducking -------------------------------------------------------------------------------

func test_sting_ducks_music_and_restores() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var mi := AudioServer.get_bus_index("Music")
	audio.set_bus_volume("Music", 0.5)
	audio.sting("rigged")
	audio.advance(0.1)
	assert_almost_eq(audio.music_duck_db(), -6.0, 0.01, "ducked −6 dB during the sting")
	assert_almost_eq(AudioServer.get_bus_volume_db(mi), linear_to_db(0.5) - 6.0, 0.05)
	var len: float = audio._length("sting_rigged")
	assert_gt(len, 0.3)
	for _i in int((len + 0.6) / 0.05):
		audio.advance(0.05)
	assert_almost_eq(audio.music_duck_db(), 0.0, 0.001, "duck released")
	assert_almost_eq(AudioServer.get_bus_volume_db(mi), linear_to_db(0.5), 0.05, "user volume restored")


func test_crowd_ducks_under_voice() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.play_voice("vo_bellows_pipe_down")
	audio.advance(0.1)
	assert_almost_eq(audio.crowd_duck_db(), -6.0, 0.01)
	for _i in 60:
		audio.advance(0.05)
	assert_almost_eq(audio.crowd_duck_db(), 0.0, 0.001)


# --- music ---------------------------------------------------------------------------------

func test_next_bar_delay_helper() -> void:
	var s: GDScript = load(AUDIO)
	assert_almost_eq(s.next_bar_delay(0.5, 2.0), 1.5, 0.0001)
	assert_almost_eq(s.next_bar_delay(2.0, 2.0), 0.0, 0.0001, "on the bar line: switch now")
	assert_almost_eq(s.next_bar_delay(3.9, 2.0), 0.1, 0.0001)
	assert_almost_eq(s.next_bar_delay(64.001, 2.0), 0.0, 0.0001, "within 5 ms of the line")
	assert_almost_eq(s.next_bar_delay(1.0, 0.0), 0.0, 0.0001, "no bar info → now")
	assert_almost_eq(s.bar_seconds(120.0, 4), 2.0, 0.0001)
	assert_almost_eq(s.bar_seconds(180.0, 3), 1.0, 0.0001)
	if _has_map():
		assert_almost_eq(audio.bar_length_of("sneak"), 10336.0 * 4.0 / 22050.0, 0.0001)
		assert_almost_eq(audio.bar_length_of("chain_4"), 6300.0 * 4.0 / 22050.0, 0.0001)
		assert_almost_eq(audio.bar_length_of("results"), 7350.0 * 3.0 / 22050.0, 0.0001)


func test_track_for_state_machine() -> void:
	var s: GDScript = load(AUDIO)
	assert_eq(s.track_for("silence", 0), "")
	assert_eq(s.track_for("curtain", 3), "curtain")
	assert_eq(s.track_for("sneak", 0), "sneak")
	assert_eq(s.track_for("suspense", 0), "sneak", "suspense is a layer on the sneak track")
	assert_eq(s.track_for("sneak", 2), "chain_2", "a live chain replaces sneak")
	assert_eq(s.track_for("suspense", 4), "chain_4")
	assert_eq(s.track_for("chase", 3), "chase", "a chase beats the chain")
	assert_eq(s.track_for("results", 1), "results")


func test_music_state_transitions() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.music_state("curtain")
	assert_eq(audio.current_track(), "curtain")
	audio.music_state("sneak")
	assert_eq(audio.current_track(), "sneak")
	audio.music_state("suspense")
	assert_eq(audio.current_track(), "sneak", "sneak keeps playing under suspense")
	for _i in 12:
		audio.advance(0.05)
	assert_almost_eq(audio.suspense_gain(), 1.0, 0.001, "suspense stem faded in")
	audio.music_state("sneak")
	for _i in 12:
		audio.advance(0.05)
	assert_almost_eq(audio.suspense_gain(), 0.0, 0.001, "and out")
	audio.music_state("chase")
	assert_eq(audio.current_track(), "chase", "chase cuts in at once")
	audio.chain_section(2)
	assert_eq(audio.current_track(), "chase", "the chain waits for the chase to end")
	assert_eq(audio.pending_track(), "")
	audio.music_state("sneak")
	assert_eq(audio.current_track(), "chain_2", "back from the chase into the live chain")
	audio.music_state("results")
	assert_eq(audio.current_track(), "results")
	audio.music_state("silence")
	assert_eq(audio.current_track(), "")


func test_chain_switches_on_the_next_bar() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.music_state("sneak")
	var bar: float = audio.bar_length_of("sneak")
	audio.debug_music_pos = 1.0
	audio.chain_section(1)
	assert_eq(audio.current_track(), "sneak", "not yet: waits for the bar line")
	assert_eq(audio.pending_track(), "chain_1")
	assert_almost_eq(audio.pending_in(), bar - 1.0, 0.0001)
	audio.advance(bar - 1.0 - 0.05)
	assert_eq(audio.current_track(), "sneak")
	audio.advance(0.1)
	assert_eq(audio.current_track(), "chain_1", "switched on the bar")
	assert_eq(audio.pending_track(), "")
	# link 2 while chain_1 plays: next bar of chain_1
	var bar1: float = audio.bar_length_of("chain_1")
	audio.debug_music_pos = bar1 * 3.0 + 0.25
	audio.chain_section(2)
	assert_almost_eq(audio.pending_in(), bar1 - 0.25, 0.0001)
	# a newer link before the bar fires retargets the same boundary
	audio.chain_section(3)
	assert_eq(audio.pending_track(), "chain_3")
	assert_almost_eq(audio.pending_in(), bar1 - 0.25, 0.0001)
	audio.advance(bar1)
	assert_eq(audio.current_track(), "chain_3")
	# a "?" while a bar-synced switch waits keeps the bar line
	audio.debug_music_pos = 0.5
	audio.chain_section(2)
	var left: float = audio.pending_in()
	audio.music_state("suspense")
	assert_eq(audio.pending_track(), "chain_2", "suspense does not cancel the pending switch")
	assert_almost_eq(audio.pending_in(), left, 0.0001)
	audio.music_state("sneak")
	audio.advance(left + 0.01)
	assert_eq(audio.current_track(), "chain_2")
	# exactly on a bar line: switch at once
	audio.debug_music_pos = 0.0
	audio.chain_section(4)
	assert_eq(audio.current_track(), "chain_4")
	# the Running Gag ends: back to sneak on the bar
	audio.debug_music_pos = 0.1
	audio.chain_section(0)
	assert_eq(audio.pending_track(), "sneak")
	audio.advance(audio.bar_length_of("chain_4"))
	assert_eq(audio.current_track(), "sneak")


# --- styles --------------------------------------------------------------------------------

func test_voice_and_crowd_styles() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.set_voice_style("tuba")
	audio.play_voice("vo_bellows_hmph")
	assert_true(audio.last_voice_file().begins_with("vo_bellows_tuba_hmph_"), audio.last_voice_file())
	audio.play_voice("vo_b_pipe_down")
	assert_true(audio.last_voice_file().begins_with("vo_bellows_tuba_pipe_down_"), "aliases then style")
	audio.set_voice_style("formant")
	audio.set_voice_squeaky(true)
	audio.play_voice("vo_bellows_aria")
	assert_true(audio.last_voice_file().begins_with("vo_bellows_squeaky_aria_"), audio.last_voice_file())
	audio.play_voice("vo_bellows_hmph")
	assert_true(audio.last_voice_file().begins_with("vo_bellows_hmph_"), "no squeaky variant → normal")
	audio.set_voice_squeaky(false)
	audio.set_crowd_style("fallback")
	audio.crowd("t1")
	assert_true(audio.last_pick("crowd_t1").begins_with("crowd_fb_t1_"), audio.last_pick("crowd_t1"))
	audio.advance(3.0)
	audio.crowd("shh")
	assert_true(audio.last_pick("crowd_shh").begins_with("crowd_shh_"), "no fallback shh → formant")
	audio.advance(3.0)
	audio.crowd("behind_you")
	assert_true(audio.last_pick("crowd_behind_you").begins_with("crowd_fb_behind_you_"),
		"BEHIND YOU! exists in both styles (it plays in the Gate-0 scene)")
	audio.set_crowd_style("formant")
	audio.advance(3.0)
	audio.crowd("t1")
	assert_true(audio.last_pick("crowd_t1").begins_with("crowd_t1_"))


func test_crowd_priority_keeps_the_big_laugh() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.crowd("t4")
	audio.advance(0.1)
	audio.crowd("t3")
	audio.advance(0.1)
	audio.crowd("t0")
	var prios: PackedInt32Array = audio._crowd_prio
	assert_true(prios.has(4), "the roar is still playing")
	assert_true(prios.has(3))
	assert_false(prios.has(0), "a titter never cuts a bigger laugh")


func test_sfx_pool_caps_and_steals() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var ids := ["woodblock_bonk", "boing_small", "boing_med", "boing_big", "slide_up", "slide_down", "whoosh", "zip",
		"crash_tail", "record_scratch", "dizzy_tweets", "stamp_thunk", "pepper_shake", "stool_scrape", "sink_splash"]
	for i in ids.size():
		audio.play_sfx(ids[i], -1.0 + 2.0 * float(i) / float(ids.size() - 1))
		audio.advance(0.04)
	assert_eq(audio._sfx.size(), 12, "12 players, never more")
	var buses := {}
	for p: AudioStreamPlayer in audio._sfx:
		buses[String(p.bus)] = true
	assert_true(buses.has("SFX_PanL2") or buses.has("SFX_PanL1"), "left pan buses used")
	audio.stop_all()
	for p: AudioStreamPlayer in audio._sfx:
		assert_false(p.playing)
