## Settings R3D keys (r3d-index §7.10, brief §4.6): defaults, choices, persistence, and the debug keys
## whose default comes from boot_config.json (written to the file only while they differ from it, so
## an orchestrator value flip reaches a player who never touched the setting).
extends TestBase

const SETTINGS_SCRIPT := "res://autoload/settings.gd"
const DIR := "user://test_ui_settings_r3d"

var path: String = ""
var boot: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var n := randi()
	path = "%s/settings_%d.cfg" % [DIR, n]
	boot = "%s/boot_%d.json" % [DIR, n]


func after_each() -> void:
	for p in [path, path + ".tmp", path + ".bak", boot]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _settings(boot_path: String = "") -> Node:
	var s: Node = (load(SETTINGS_SCRIPT) as GDScript).new()
	s.set("path", path)
	s.set("boot_config_path", boot_path)
	s.call("load_settings")
	return s


func _write_boot(d: Dictionary) -> void:
	var f := FileAccess.open(boot, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func test_r3d_defaults() -> void:
	var s := _settings()
	assert_eq(s.call("get_value", "previews"), "always")
	assert_eq(s.call("get_value", "room_dimming"), true)
	assert_eq(s.call("get_value", "outline_boost"), false)
	assert_eq(s.call("get_value", "hush_head"), "")
	assert_eq(s.call("get_value", "bellows_window"), "sim")
	assert_eq(s.call("get_value", "msaa_3d"), true)
	assert_eq(s.call("get_value", "render_scale"), 1.0)
	assert_eq(s.call("get_value", "show_previews"), false)
	s.free()


func test_choices_are_validated() -> void:
	var s := _settings()
	s.call("set_value", "previews", "idle_6s")
	assert_eq(s.call("get_value", "previews"), "idle_6s")
	s.call("set_value", "previews", "sometimes")
	assert_eq(s.call("get_value", "previews"), "always", "unknown value → default")
	s.call("set_value", "hush_head", "head_b")
	assert_eq(s.call("get_value", "hush_head"), "head_b")
	s.call("set_value", "bellows_window", "lean")
	assert_eq(s.call("get_value", "bellows_window"), "lean")
	s.call("set_value", "render_scale", 0.85)
	assert_almost_eq(float(s.call("get_value", "render_scale")), 0.85)
	s.free()


func test_r3d_keys_persist() -> void:
	var s := _settings()
	s.call("set_value", "previews", "off")
	s.call("set_value", "room_dimming", false)
	s.call("set_value", "outline_boost", true)
	s.call("set_value", "bellows_window", "lean")
	s.call("save")
	s.free()
	var s2 := _settings()
	assert_eq(s2.call("get_value", "previews"), "off")
	assert_eq(s2.call("get_value", "room_dimming"), false)
	assert_eq(s2.call("get_value", "outline_boost"), true)
	assert_eq(s2.call("get_value", "bellows_window"), "lean")
	s2.free()


func test_debug_defaults_come_from_boot_config() -> void:
	_write_boot({"start": "stage_door", "bellows_window": "lean", "show_previews": true,
		"render": {"msaa_3d": false, "render_scale": 0.85, "outline": true}})
	var s := _settings(boot)
	assert_eq(s.call("get_value", "bellows_window"), "lean")
	assert_eq(s.call("get_value", "show_previews"), true)
	assert_eq(s.call("get_value", "msaa_3d"), false)
	assert_almost_eq(float(s.call("get_value", "render_scale")), 0.85)
	assert_eq(s.call("default_of", "bellows_window"), "lean")
	s.free()


func test_untouched_debug_keys_follow_a_later_flip() -> void:
	_write_boot({"bellows_window": "sim"})
	var s := _settings(boot)
	s.call("set_value", "previews", "idle_6s")   # something else is saved
	s.call("save")
	s.free()
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_false(cfg.has_section_key("settings", "bellows_window"), "a default-valued boot key is not written")
	_write_boot({"bellows_window": "lean"})   # the orchestrator flips it
	var s2 := _settings(boot)
	assert_eq(s2.call("get_value", "bellows_window"), "lean", "the flip reaches the device")
	s2.call("set_value", "bellows_window", "sim")   # the owner picks it explicitly
	s2.call("save")
	s2.free()
	var s3 := _settings(boot)
	assert_eq(s3.call("get_value", "bellows_window"), "sim", "his explicit choice sticks")
	s3.free()


func test_the_shipped_boot_config_reads() -> void:
	var bc: Dictionary = (load(SETTINGS_SCRIPT) as GDScript).call("read_boot_config", "res://scenes/boot/boot_config.json")
	assert_true(bc.has("start"), "boot_config.json parses")
