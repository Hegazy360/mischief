## Gate-0 A/B (s2-sound §4.1.4): `data/audio/ab.json` schema + every side resolves in its
## style; `Audio.preview(id, style)` plays the right style's file (a sequence part by part)
## and leaves Settings and the current styles alone; the Settings `voice_style` /
## `crowd_style` keys switch the styles on ready and on `changed` (against the real Settings
## autoload when it is registered — its values are restored after each test — else a stand-in).
extends TestBase

const AB := "res://data/audio/ab.json"
const AUDIO := "res://autoload/audio.gd"
const VOICE_PAIRS: PackedStringArray = ["warmup", "sneeze", "pipe_down", "lecture_a", "the_pipes"]
const CROWD_PAIRS: PackedStringArray = ["t2", "sneeze_t3", "t4", "relief", "behind_you"]

var audio: Node = null
var ab: Dictionary = {}


func before_each() -> void:
	var d: Variant = load_json(AB)
	ab = d if d is Dictionary else {}
	audio = _make()


func after_each() -> void:
	if audio != null:
		audio.free()
		audio = null
	var s := tree.root.get_node_or_null("Settings")
	if s != null and s.has_meta("fake_settings"):
		s.free()
	elif s != null and not _saved.is_empty():
		for k: String in _saved:
			s.call("set_value", k, _saved[k])
	_saved = {}
	_emitted = 0


var _saved: Dictionary = {}
var _emitted: int = 0


## The Settings node the Audio autoload reads: the real autoload (its style keys saved, restored in
## after_each) or a stand-in with `vstyle` / `cstyle` when none is registered.
func _settings_with(vstyle: String, cstyle: String) -> Node:
	var real := tree.root.get_node_or_null("Settings")
	if real == null:
		return _fake_settings(vstyle, cstyle)
	for k: String in ["voice_style", "crowd_style"]:
		if not _saved.has(k):
			_saved[k] = real.call("get_value", k)
	real.call("set_value", "voice_style", vstyle)
	real.call("set_value", "crowd_style", cstyle)
	return real


func _count_changed(_k: String, _v: Variant) -> void:
	_emitted += 1


## Emit a style change the way the real Settings does (set_value) or the stand-in does (the signal).
func _change(s: Node, key: String, value: Variant) -> void:
	if s.has_meta("fake_settings"):
		s.emit_signal("changed", key, value)
	else:
		s.call("set_value", key, value)


func _make() -> Node:
	var a: Node = (load(AUDIO) as GDScript).new()
	a.auto_advance = false
	tree.root.add_child(a)
	return a


func _has_map() -> bool:
	return FileAccess.file_exists("res://audio/sfx_map.json")


## A stand-in Settings autoload with the style keys; records set_value calls.
func _fake_settings(vstyle: String, cstyle: String) -> Node:
	var sc := GDScript.new()
	sc.source_code = "extends Node\nsignal changed(key: String, value: Variant)\n" \
		+ "var sets := 0\n" \
		+ "var vals := {\"voice_style\": \"%s\", \"crowd_style\": \"%s\"}\n" % [vstyle, cstyle] \
		+ "func get_value(k: String, fb: Variant = null) -> Variant:\n\treturn vals.get(k, fb)\n" \
		+ "func set_value(k: String, v: Variant) -> bool:\n\tsets += 1\n\tvals[k] = v\n\treturn true\n"
	sc.reload()
	var fake: Node = sc.new()
	fake.name = "Settings"
	fake.set_meta("fake_settings", true)
	tree.root.add_child(fake)
	return fake


func test_ab_json_schema() -> void:
	assert_eq(int(ab.get("version", 0)), 1, "ab.json parses, version 1")
	var want := {"voice": [VOICE_PAIRS, "formant", "tuba"], "crowd": [CROWD_PAIRS, "formant", "fallback"]}
	for sect: String in want:
		var pairs: Array = ab.get(sect, [])
		var ids := PackedStringArray()
		for pair: Dictionary in pairs:
			ids.append(String(pair.get("id", "")))
			assert_true(pair.get("label", "") is String and String(pair["label"]) != "", "%s.%s label" % [sect, pair.get("id")])
			assert_eq(String((pair.get("a", {}) as Dictionary).get("style", "")), want[sect][1], "%s.%s a = %s" % [sect, pair.get("id"), want[sect][1]])
			assert_eq(String((pair.get("b", {}) as Dictionary).get("style", "")), want[sect][2], "%s.%s b = %s" % [sect, pair.get("id"), want[sect][2]])
		for must: String in want[sect][0]:
			assert_true(ids.has(must), "%s pair %s" % [sect, must])


func test_every_pair_resolves_in_its_style() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	for sect in ["voice", "crowd"]:
		for pair: Dictionary in ab.get(sect, []):
			for side in ["a", "b"]:
				var sd: Dictionary = pair.get(side, {})
				var id := String(sd.get("id", ""))
				var style := String(sd.get("style", ""))
				assert_true(audio.has_preview(id), "%s.%s.%s '%s' can be previewed" % [sect, pair.get("id"), side, id])
				var fs: PackedStringArray = audio.preview_files(id, style)
				assert_false(fs.is_empty(), "%s.%s.%s plays something" % [sect, pair.get("id"), side])
				for f: String in fs:
					match style:
						"tuba":
							assert_true(f.begins_with("vo_bellows_tuba_"), "%s is a tuba take" % f)
						"fallback":
							assert_true(f.begins_with("crowd_fb_"), "%s is a fallback-crowd take" % f)
						"formant":
							assert_false(f.begins_with("vo_bellows_tuba_") or f.begins_with("crowd_fb_"), "%s is formant" % f)
			var fa: PackedStringArray = audio.preview_files(String(pair["a"]["id"]), String(pair["a"]["style"]))
			var fb: PackedStringArray = audio.preview_files(String(pair["b"]["id"]), String(pair["b"]["style"]))
			assert_eq(fa.size(), fb.size(), "%s.%s: both sides play the same number of parts" % [sect, pair.get("id")])


func test_preview_plays_the_style_and_leaves_settings_alone() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.free()
	var st := _settings_with("formant", "formant")
	audio = _make()
	var fake := st.has_meta("fake_settings")
	var sets0 := int(st.get("sets")) if fake else 0
	st.connect("changed", _count_changed)
	audio.preview("vo_bellows_pipe_down_1", "tuba")
	assert_eq(audio.last_preview_files(), PackedStringArray(["vo_bellows_tuba_pipe_down_1"]))
	audio.preview("vo_bellows_pipe_down_1", "formant")
	assert_eq(audio.last_preview_files(), PackedStringArray(["vo_bellows_pipe_down_1"]))
	audio.preview("crowd_t3_1", "fallback")
	assert_eq(audio.last_preview_files(), PackedStringArray(["crowd_fb_t3_1"]))
	audio.preview("t2", "fallback")
	assert_true(audio.last_preview_files()[0].begins_with("crowd_fb_t2_"), "a crowd kind previews its bank")
	audio.preview("vo_bellows_hmph", "tuba")
	assert_eq(audio.last_preview_files(), PackedStringArray(["vo_bellows_tuba_hmph_1"]), "a bank previews its first take")
	audio.preview("vo_bellows_sneeze_seq", "tuba")
	assert_true(audio.is_previewing(), "a preview is sounding")
	assert_eq(audio.voice_style, "formant", "preview never switches the voice style")
	assert_eq(audio.crowd_style, "formant", "…or the crowd style")
	assert_eq(_emitted, 0, "preview never changes a Setting")
	if fake:
		assert_eq(int(st.get("sets")), sets0, "preview never writes Settings")
	assert_eq(String(st.call("get_value", "voice_style")), "formant")
	assert_eq(String(st.call("get_value", "crowd_style")), "formant")
	audio.play_voice("vo_bellows_pipe_down")
	assert_false(audio.last_voice_file().begins_with("vo_bellows_tuba_"), "the game voice stays formant")
	st.disconnect("changed", _count_changed)


func test_preview_sequence_plays_part_by_part() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	var fs: PackedStringArray = audio.preview_files("vo_bellows_sneeze_seq", "tuba")
	assert_eq(fs.size(), 5, "ah, ahh, AHHH, hm, CHOO")
	assert_true(fs[0].begins_with("vo_bellows_tuba_sneeze_ah1"), fs[0])
	assert_true(fs[4].begins_with("vo_bellows_tuba_sneeze_choo"), fs[4])
	audio.preview("vo_bellows_sneeze_seq", "formant")
	assert_true(audio.is_previewing(), "parts are queued")
	var queued := 0
	for t: float in audio._preview_q_t:
		if t >= 0.0:
			queued += 1
	assert_eq(queued, 4, "four parts after the first wait on their frames")
	audio.advance(1.0)
	queued = 0
	for t: float in audio._preview_q_t:
		if t >= 0.0:
			queued += 1
	assert_eq(queued, 2, "by 1.0 s: ahh and AHHH have played; hm (1.27 s) and CHOO (1.57 s) wait")
	audio.advance(1.0)
	for t: float in audio._preview_q_t:
		assert_lt(t, 0.0, "every part has played by 2 s")
	audio.preview("vo_bellows_sneeze_seq", "tuba")
	audio.stop_preview()
	for t: float in audio._preview_q_t:
		assert_lt(t, 0.0, "stop_preview drops the queued parts")
	assert_false(audio.has_sfx("vo_bellows_sneeze_seq"), "a preview sequence is not a playable sfx")


func test_settings_styles_apply_on_ready_and_on_changed() -> void:
	audio.free()
	var st := _settings_with("tuba", "fallback")
	audio = _make()
	assert_eq(audio.voice_style, "tuba", "voice_style applied on ready")
	assert_eq(audio.crowd_style, "fallback", "crowd_style applied on ready")
	_change(st, "voice_style", "formant")
	assert_eq(audio.voice_style, "formant", "changed(voice_style) switches")
	_change(st, "crowd_style", "formant")
	assert_eq(audio.crowd_style, "formant", "changed(crowd_style) switches")
	if st.has_meta("fake_settings"):
		_change(st, "voice_style", "banjo")
		assert_eq(audio.voice_style, "formant", "an unknown style is ignored")
		_change(st, "crowd_style", 3)
		assert_eq(audio.crowd_style, "formant", "a non-string is ignored")
	else:
		# the real Settings refuses unknown values itself; the autoload must still ignore them
		audio._on_setting_changed("voice_style", "banjo")
		assert_eq(audio.voice_style, "formant", "an unknown style is ignored")
		audio._on_setting_changed("crowd_style", 3)
		assert_eq(audio.crowd_style, "formant", "a non-string is ignored")
	if _has_map():
		_change(st, "voice_style", "tuba")
		audio.play_voice("vo_bellows_sneeze_choo")
		assert_true(audio.last_voice_file().begins_with("vo_bellows_tuba_sneeze_choo_"), audio.last_voice_file())
		_change(st, "crowd_style", "fallback")
		audio.crowd("t3")
		assert_true(audio.last_pick("crowd_t3").begins_with("crowd_fb_t3_"), audio.last_pick("crowd_t3"))


func test_hush_tiptoe_walks_up_the_scale() -> void:
	assert_eq(audio.cycle_index(0, 8, "pingpong"), 0)
	assert_eq(audio.cycle_index(7, 8, "pingpong"), 7)
	assert_eq(audio.cycle_index(8, 8, "pingpong"), 6, "turns at the top without repeating it")
	assert_eq(audio.cycle_index(14, 8, "pingpong"), 0)
	assert_eq(audio.cycle_index(15, 8, "pingpong"), 1)
	assert_eq(audio.cycle_index(9, 8, "wrap"), 1)
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	assert_true(audio.has_sfx("step_pizz_up"))
	var got := PackedStringArray()
	for i in 10:
		audio.play_sfx("step_pizz_up")
		got.append(audio.last_pick("step_pizz_up"))
		audio.advance(10.0 / 60.0)
	assert_eq(got[0], "step_pizz_1")
	assert_eq(got[7], "step_pizz_8", "E4 → E5")
	assert_eq(got[8], "step_pizz_7", "…and back down")
	audio.advance(1.0)
	audio.play_sfx("step_pizz_up")
	assert_eq(audio.last_pick("step_pizz_up"), "step_pizz_1", "a new walk starts at the bottom")


func test_shush_is_a_crowd_kind() -> void:
	if not _has_map():
		skip("sfx_map.json not generated")
		return
	audio.crowd("shush")
	assert_true(audio.last_pick("crowd_shh").begins_with("crowd_shh_"), "shush plays the Stalls' shh")
