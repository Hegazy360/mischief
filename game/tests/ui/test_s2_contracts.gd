## Stage-2 UI contracts other tasks call (s2-ui §4.1): the Gate-0 Settings keys (+ migration),
## the debug-only `stage_door` route, UiIcons.CARD_ALIASES completeness against barks.json (+ `ff`)
## and the Stage-2 string key sets.
extends TestBase

const SETTINGS_SCRIPT := "res://autoload/settings.gd"
const DIR := "user://test_s2_contracts"
## s2-ui §4.1.6 — every other task uses only these keys.
const KEY_SETS := {
	"stage_door": ["title", "prologue", "night1", "night2", "gate0", "gate0_card_honey", "gate0_card_hold",
		"gate0_card_hide", "cast", "cast_next", "cast_skin", "voice_ab", "crowd_ab", "play_a", "play_b", "use_this",
		"play_g0_voice_a", "play_g0_voice_b", "play_g0_crowd_a", "play_g0_crowd_b", "hush_pip", "reset_save",
		"reset_confirm", "device_log", "back"],
	"playbill": ["title", "play", "seen", "curtain_calls", "locked", "coming_soon", "prologue", "night1", "night2",
		"night3"],
	"overlay": ["fps", "p95", "frame_ms", "draw_calls", "sim_ms", "tex_mb", "laugh_clock", "copy_log", "copied",
		"stage_door"],
	"curtain": ["next_night", "night1", "retry", "again", "playbill", "stage_door", "to_be_continued", "applause", "new",
		"tap_to_skip"],
	"ftue": ["psst", "show_me", "tap_to_skip"],
	"fx": ["spotted", "fell_for_it", "running_gag", "behind_you", "boo", "near_miss", "pardon"],
}

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


# --- Settings: the Gate-0 A/B keys ----------------------------------------------------------

func test_gate0_keys_defaults_and_choices() -> void:
	var s := _settings()
	assert_eq(s.call("get_value", "voice_style"), "formant")
	assert_eq(s.call("get_value", "crowd_style"), "formant")
	assert_eq(s.call("get_value", "hush_skin"), "")
	var got := []
	s.connect("changed", func(k: String, v: Variant) -> void: got.append([k, v]))
	assert_true(bool(s.call("set_value", "voice_style", "tuba")))
	assert_true(bool(s.call("set_value", "crowd_style", "fallback")))
	assert_true(bool(s.call("set_value", "hush_skin", "pip")))
	assert_eq(got, [["voice_style", "tuba"], ["crowd_style", "fallback"], ["hush_skin", "pip"]], "changed emitted")
	s.call("set_value", "voice_style", "kazoo")
	assert_eq(s.call("get_value", "voice_style"), "formant", "unknown style → default")
	s.call("set_value", "hush_skin", "clown")
	assert_eq(s.call("get_value", "hush_skin"), "", "unknown skin → the mime")
	s.free()


func test_gate0_keys_persist() -> void:
	var s := _settings()
	s.call("set_value", "voice_style", "tuba")
	s.call("set_value", "hush_skin", "pip")
	s.call("save")
	s.free()
	var s2 := _settings()
	assert_eq(s2.call("get_value", "voice_style"), "tuba")
	assert_eq(s2.call("get_value", "hush_skin"), "pip")
	assert_eq(s2.call("get_value", "crowd_style"), "formant", "untouched key keeps its default")
	assert_eq(int(s2.get("loaded_version")), 2, "the file is stamped")
	s2.free()


func test_stage1_file_migrates() -> void:
	# a Stage-1 settings.cfg: no meta section, no A/B keys, one stale key
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "left_handed", true)
	cfg.set_value("settings", "music_vol", 0.3)
	cfg.set_value("settings", "old_removed_key", 7)
	assert_eq(cfg.save(path), OK)
	var s := _settings()
	assert_eq(int(s.get("loaded_version")), 1, "no stamp = a Stage-1 file")
	assert_eq(s.call("get_value", "left_handed"), true, "old values survive")
	assert_almost_eq(float(s.call("get_value", "music_vol")), 0.3)
	assert_eq(s.call("get_value", "voice_style"), "formant", "new keys take defaults")
	assert_eq(s.call("get_value", "hush_skin"), "")
	assert_false((s.call("all") as Dictionary).has("old_removed_key"), "unknown keys are ignored")
	s.call("save")
	var back := ConfigFile.new()
	assert_eq(back.load(path), OK)
	assert_eq(int(back.get_value("meta", "version", 0)), 2, "rewritten at the current version")
	assert_eq(back.get_value("settings", "voice_style", ""), "formant")
	s.free()


func test_wrong_types_in_file_fall_back() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 99)
	cfg.set_value("settings", "voice_style", 3)
	cfg.set_value("settings", "hush_skin", true)
	assert_eq(cfg.save(path), OK)
	var s := _settings()
	assert_eq(s.call("get_value", "voice_style"), "formant")
	assert_eq(s.call("get_value", "hush_skin"), "")
	s.free()


# --- Router ------------------------------------------------------------------------------------

func test_stage_door_route_debug_only() -> void:
	var rs := load("res://autoload/router.gd") as GDScript
	var dbg: Dictionary = rs.call("routes_for", true)
	var rel: Dictionary = rs.call("routes_for", false)
	assert_eq(dbg.get("stage_door"), "res://scenes/stage_door/StageDoor.tscn")
	assert_false(rel.has("stage_door"), "a release build has no stage door")
	for k in ["boot", "night", "playbill"]:
		assert_true(rel.has(k) and dbg.has(k), "%s in both builds" % k)
	var r: Node = rs.new()
	r.set("debug_routes", true)
	assert_true(bool(r.call("has_route", "stage_door")))
	assert_eq(r.call("scene_path_for", "stage_door"), "res://scenes/stage_door/StageDoor.tscn")
	r.set("debug_routes", false)
	assert_false(bool(r.call("has_route", "stage_door")), "release: the key is absent")
	assert_eq(r.call("scene_path_for", "stage_door"), "")
	assert_false(bool(r.call("has_scene", "stage_door")))
	r.free()


# --- cards --------------------------------------------------------------------------------------

## Every icon key barks.json can hand to UiIcons.card(): loading-card icon + new_rule, cue-card
## keys and the icons inside figgis_cards / line_cards.
func _barks_card_keys() -> PackedStringArray:
	var out := PackedStringArray()
	var b := UiIcons.barks()
	assert_false(b.is_empty(), "barks.json loads")
	for sec in ["figgis_cards", "line_cards"]:
		var d: Dictionary = b.get(sec, {})
		for key in d:
			if sec == "figgis_cards":
				out.append(String(key))
			for ic in (d[key] as Dictionary).get("icons", []):
				out.append(String(ic))
	var lc: Dictionary = b.get("loading_cards", {})
	for ep in lc:
		out.append(String((lc[ep] as Dictionary).get("icon", "")))
		out.append(String((lc[ep] as Dictionary).get("new_rule", "")))
	return out


func test_every_barks_card_key_has_a_real_icon() -> void:
	var keys := _barks_card_keys()
	keys.append_array(["tray", "freeze", "specs", "items", "freeze_specs", "fixup", "meltdown", "beryl", "panto", "herd",
		"delphine", "chase_trip", "nerves", "spotlight", "figgis_psst", "ff"])
	assert_gt(keys.size(), 50)
	for k in keys:
		if k == "":
			continue
		var p := UiIcons.card_path(k)
		assert_ne(p, "", "card key '%s' has an icon" % k)
		assert_false(p.ends_with("item_fallback.svg"), "card key '%s' is not the ? box" % k)
		assert_true(UiIcons.card(k) != null, "card key '%s' rasterises" % k)


func test_ff_lesson_card_is_clarence_held_to_a_fast_clock() -> void:
	var cs := UiIcons.card_set("ff")
	assert_eq(cs.size(), 3)
	assert_eq(UiIcons.card_path(cs[0]), "res://art/ui/clarence_hold.svg")
	assert_eq(UiIcons.card_path(cs[2]), "res://art/ui/clock_fast.svg")
	assert_eq(UiIcons.card_path("ff"), "res://art/ui/clock_fast.svg")


func test_card_sets_come_from_barks() -> void:
	assert_eq(UiIcons.card_set("card_tray"), PackedStringArray(["tray", "arrow", "rig"]))
	var line := UiIcons.card_set("n01_throat_tea:kettle")
	assert_eq(line.size(), 3, "a Script line id gives its step-2 card")
	assert_eq(line[0], "squeaker")
	assert_eq(UiIcons.card_set("no_such_card"), PackedStringArray(["no_such_card"]))


# --- strings -----------------------------------------------------------------------------------

func test_stage2_string_key_sets_exist_and_are_short() -> void:
	UiStrings.reload()
	for prefix in KEY_SETS:
		for k in KEY_SETS[prefix]:
			var key := "%s.%s" % [prefix, k]
			assert_true(UiStrings.has(key), "strings.json has %s" % key)
			var v := UiStrings.t(key)
			assert_ne(v, "", key)
			# short: they sit on 144 px buttons and 88 px captions
			assert_le(v.length(), 22, "%s is short ('%s')" % [key, v])
