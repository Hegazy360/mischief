## Settings persistence (TECH §7, GDD §3.11) and the Haptics rate limit (GDD §3.10).
extends TestBase

const SETTINGS_SCRIPT := "res://autoload/settings.gd"
const HAPTICS_SCRIPT := "res://autoload/haptics.gd"
const DIR := "user://test_ui_settings"

var path: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	path = "%s/settings_%d.cfg" % [DIR, Time.get_ticks_usec()]


func after_each() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _settings() -> Node:
	var s: Node = (load(SETTINGS_SCRIPT) as GDScript).new()
	s.set("path", path)
	s.call("load_settings")
	return s


func test_keys_and_defaults_match_tech_7() -> void:
	var s := _settings()
	var all: Dictionary = s.call("all")
	var keys := all.keys()
	keys.sort()
	var want := ["crowd_style", "crowd_vol", "haptics", "hints", "hush_skin", "left_handed", "music_vol",
		"reduce_flash", "reduce_motion", "relaxed", "sfx_vol", "stare_strip", "tap_to_rig", "text_scale", "voice_style",
		"voice_vol"]
	assert_eq(keys, want, "exactly the TECH §7 keys + the Stage-2 Gate-0 A/B keys")
	assert_eq(s.call("get_value", "hints"), "always", "hints default Always (GDD §3.5)")
	assert_eq(s.call("get_value", "haptics"), true)
	assert_eq(s.call("get_value", "stare_strip"), true)
	assert_eq(s.call("get_value", "relaxed"), false)
	assert_eq(s.call("get_value", "text_scale"), 1.0)
	s.free()


func test_changes_persist_and_emit() -> void:
	var s := _settings()
	var got := []
	s.connect("changed", func(k: String, v: Variant) -> void: got.append([k, v]))
	assert_true(bool(s.call("set_value", "left_handed", true)))
	assert_false(bool(s.call("set_value", "left_handed", true)), "same value: no change")
	s.call("set_value", "hints", "long_press")
	s.call("set_value", "music_vol", 0.25)
	s.call("set_value", "text_scale", 1.2)
	assert_eq(got, [["left_handed", true], ["hints", "long_press"], ["music_vol", 0.25], ["text_scale", 1.2]])
	s.free()
	var s2 := _settings()
	assert_eq(s2.call("get_value", "left_handed"), true, "persisted")
	assert_eq(s2.call("get_value", "hints"), "long_press")
	assert_almost_eq(float(s2.call("get_value", "music_vol")), 0.25)
	assert_almost_eq(float(s2.call("get_value", "text_scale")), 1.2)
	s2.free()


func test_invalid_values_are_coerced() -> void:
	var s := _settings()
	s.call("set_value", "hints", "sometimes")
	assert_eq(s.call("get_value", "hints"), "always", "unknown choice → default")
	s.call("set_value", "sfx_vol", 7.0)
	assert_eq(s.call("get_value", "sfx_vol"), 1.0, "clamped")
	s.call("set_value", "text_scale", 3.0)
	assert_eq(s.call("get_value", "text_scale"), 1.2, "text +20 % max")
	allow_errors()
	assert_false(bool(s.call("set_value", "no_such_key", 1)), "unknown keys rejected")
	s.free()


func test_debounced_save_in_tree() -> void:
	var s := _settings()
	tree.root.add_child(s)
	var n0 := int(s.get("save_count"))
	s.call("set_value", "relaxed", true)
	s.call("set_value", "reduce_motion", true)
	assert_true(bool(s.call("is_save_pending")), "debounced")
	assert_eq(int(s.get("save_count")), n0)
	await tree.create_timer(0.7).timeout
	assert_eq(int(s.get("save_count")), n0 + 1, "one write after the debounce")
	s.queue_free()


func test_corrupt_settings_fall_back_to_defaults() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[settings]\nleft_handed = ???garbage")
	f.close()
	allow_errors()
	var s := _settings()
	assert_eq(s.call("get_value", "left_handed"), false)
	s.free()


# --- haptics -----------------------------------------------------------------------------------

func _haptics() -> Node:
	var h: Node = (load(HAPTICS_SCRIPT) as GDScript).new()
	h.set("force_enabled", true)
	h.set("dry_run", true)
	h.set("now_override", 1000)
	return h


func test_named_pulses() -> void:
	var h := _haptics()
	h.call("tap")
	h.call("rig_done")
	var fired: Array = h.get("fired")
	assert_eq(fired[0], ["tap", 8, 0.3], "tap 8 ms / 0.3")
	assert_eq(fired[1], ["rig_done", 30, 0.7], "rig done 30 ms / 0.7")
	assert_false(bool(h.call("pulse", &"nope")), "unknown pulse ignored")
	h.free()


func test_patterns_fire_on_schedule() -> void:
	var h := _haptics()
	h.call("caught")
	assert_eq((h.get("fired") as Array).size(), 1, "first of 3 now")
	h.set("now_override", 1110)
	h.call("pump")
	assert_eq((h.get("fired") as Array).size(), 2, "second at 110 ms")
	h.set("now_override", 1220)
	h.call("pump")
	var fired: Array = h.get("fired")
	assert_eq(fired.size(), 3, "3 × 30 ms")
	assert_eq(fired[2][1], 30)
	h.call("accent")
	h.set("now_override", 1310)
	h.call("pump")
	fired = h.get("fired")
	assert_eq([fired[3][1], fired[4][1]], [40, 60], "accent 40 + 60")
	h.free()


func test_rate_limit_six_per_second() -> void:
	var h := _haptics()
	for i in 10:
		h.set("now_override", 1000 + i * 50)
		h.call("tap")
	assert_eq((h.get("fired") as Array).size(), 6, "≤ 6 pulses in any second")
	assert_eq(int(h.get("dropped")), 4)
	h.set("now_override", 2001)
	h.call("tap")
	assert_eq((h.get("fired") as Array).size(), 7, "the window slides")
	h.free()


func test_respects_the_setting() -> void:
	var s: Node = tree.root.get_node_or_null(^"Settings")
	var own := s == null
	var old: Variant = true
	if own:
		s = _settings()
		s.name = "Settings"
		tree.root.add_child(s)
	else:
		old = s.call("get_value", "haptics", true)
	var h := _haptics()
	tree.root.add_child(h)
	s.call("set_value", "haptics", false)
	h.call("tap")
	assert_eq((h.get("fired") as Array).size(), 0, "haptics off → nothing")
	s.call("set_value", "haptics", true)
	h.call("tap")
	assert_eq((h.get("fired") as Array).size(), 1)
	h.queue_free()
	if own:
		s.call("flush")
		s.queue_free()
	else:
		s.call("set_value", "haptics", old)


func test_desktop_is_a_no_op_unless_forced() -> void:
	var h: Node = (load(HAPTICS_SCRIPT) as GDScript).new()
	h.set("dry_run", true)
	if OS.has_feature("android") or OS.has_feature("ios"):
		skip("running on a phone")
		h.free()
		return
	assert_false(bool(h.call("is_available")))
	h.call("tap")
	assert_eq((h.get("fired") as Array).size(), 0)
	h.free()
