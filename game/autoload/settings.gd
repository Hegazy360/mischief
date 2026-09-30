## Settings — persisted player preferences (`user://settings.cfg`, TECH §7, GDD §3.11).
##
## Keys (DEFAULTS): music_vol, sfx_vol, voice_vol, crowd_vol (linear 0..1), haptics, relaxed,
## tap_to_rig, left_handed, hints ("always" | "long_press" | "off"), stare_strip, reduce_motion,
## reduce_flash, text_scale (1.0 or 1.2 = "Text +20 %"), plus the Stage-2 Gate-0 A/B keys
## voice_style ("formant" | "tuba"), crowd_style ("formant" | "fallback") and hush_skin
## ("" = Hush the mime | "pip") — applied by Audio (styles) and the view (skin); the owner's
## Gate-0 decisions become the DEFAULTS (one line each).
## R3D (REDESIGN_3D §2, GDD §3.11 amendments; r3d-index §7.10): previews ("always" | "idle_6s" |
## "off"), room_dimming, outline_boost ("Outline +50 %"), and the debug keys hush_head ("" |
## "head_b", R6), bellows_window ("sim" | "lean", R15), msaa_3d, render_scale (1.0 | 0.85) and
## show_previews (the Night 1/2 stage-door previews). The debug keys that `boot_config.json` names
## (`bellows_window`, `show_previews`, `render.msaa_3d`, `render.render_scale`) take their DEFAULT
## from it (BOOT_KEYS), and are written to the file only while they differ from that default — so an
## orchestrator value flip reaches a device whose player never touched the setting.
## Migration-safe: a file written by an older build (no `meta/version`, or missing keys) loads
## with defaults for every missing key; unknown keys and invalid values are ignored / reset;
## the file is rewritten at FILE_VERSION on the next save.
## Every change emits `changed(key, value)` and schedules a debounced save (SAVE_DELAY_SEC);
## the file is written crash-safely (tmp + rename, `.bak` fallback — SafeFile). Volumes are
## pushed to the Audio autoload's buses (`set_bus_volume`) when it exists.
## Registered by the orchestrator as the `Settings` autoload; tests instantiate the script and
## set `path` before adding it (or call `load_settings()` directly).
extends Node

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const SECTION := "settings"
const SAVE_DELAY_SEC := 0.5
## Version stamped into the file's `meta` section (1 = Stage 1, no stamp; 2 = the A/B keys;
## 3 = the R3D keys).
const FILE_VERSION := 3
const META := "meta"
const DEFAULTS := {
	"music_vol": 0.7,
	"sfx_vol": 0.9,
	"voice_vol": 0.9,
	"crowd_vol": 0.8,
	"haptics": true,
	"relaxed": false,
	"tap_to_rig": false,
	"left_handed": false,
	"hints": "always",
	"stare_strip": true,
	"reduce_motion": false,
	"reduce_flash": false,
	"text_scale": 1.0,
	"voice_style": "formant",
	"crowd_style": "formant",
	"hush_skin": "",
	# R3D
	"previews": "always",
	"room_dimming": true,
	"outline_boost": false,
	"hush_head": "",
	"bellows_window": "sim",
	"msaa_3d": true,
	"render_scale": 1.0,
	"show_previews": false,
}
## The R3D debug keys (the Settings panel's debug section).
const DEBUG_KEYS: PackedStringArray = ["hush_head", "bellows_window", "msaa_3d", "render_scale", "show_previews"]
## Debug keys whose default comes from `boot_config.json` (key → its path in the file).
const BOOT_KEYS := {
	"bellows_window": ["bellows_window"],
	"show_previews": ["show_previews"],
	"msaa_3d": ["render", "msaa_3d"],
	"render_scale": ["render", "render_scale"],
}
const BOOT_CONFIG_PATH := "res://scenes/boot/boot_config.json"
## Allowed values of string keys (anything else falls back to the default).
const CHOICES := {
	"hints": ["always", "long_press", "off"],
	"voice_style": ["formant", "tuba"],
	"crowd_style": ["formant", "fallback"],
	"hush_skin": ["", "pip"],
	"previews": ["always", "idle_6s", "off"],
	"hush_head": ["", "head_b"],
	"bellows_window": ["sim", "lean"],
}
## Clamp ranges of numeric keys.
const RANGES := {
	"music_vol": [0.0, 1.0], "sfx_vol": [0.0, 1.0], "voice_vol": [0.0, 1.0], "crowd_vol": [0.0, 1.0],
	"text_scale": [1.0, 1.2],
	"render_scale": [0.5, 1.0],
}
## Volume key → Audio bus (TECH §5.8).
const BUSES := {"music_vol": "Music", "sfx_vol": "SFX", "voice_vol": "Voice", "crowd_vol": "Crowd"}

## Override before _ready / load_settings (tests) to use another file.
var path: String = PATH
## Override before load_settings (tests) to read another boot config ("" = none).
var boot_config_path: String = BOOT_CONFIG_PATH
## Number of completed writes (tests).
var save_count: int = 0
## Version of the file last loaded (0 = no file, 1 = a Stage-1 file without a stamp).
var loaded_version: int = 0

var _values: Dictionary = {}
## DEFAULTS with the boot_config.json values applied (see BOOT_KEYS).
var _defaults: Dictionary = {}
var _cfg := ConfigFile.new()
var _save_pending := false
var _save_timer: float = 0.0


func _init() -> void:
	_defaults = DEFAULTS.duplicate(true)
	_values = _defaults.duplicate(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# UiKit sets the shared fonts' MSDF range / size at first use; do it here, before anything draws
	# text, or captions already drawn by the view keep stale glyph textures (white bars)
	UiKit.warm_fonts()
	load_settings()
	_apply_audio_all.call_deferred()


func _process(delta: float) -> void:
	if not _save_pending:
		return
	_save_timer -= delta
	if _save_timer <= 0.0:
		save()


## (Re)load from disk; unknown keys are ignored, missing / invalid keys take defaults.
func load_settings() -> void:
	reload_boot_defaults()
	_values = _defaults.duplicate(true)
	_cfg = ConfigFile.new()
	loaded_version = 0
	if SafeFile.load_config(_cfg, path) == OK:
		loaded_version = int(_cfg.get_value(META, "version", 1)) if _cfg.has_section(META) else 1
		for k in DEFAULTS:
			if _cfg.has_section_key(SECTION, k):
				_values[k] = _coerce(k, _cfg.get_value(SECTION, k))


## Recompute the effective defaults: DEFAULTS with `boot_config.json`'s BOOT_KEYS applied.
func reload_boot_defaults() -> void:
	_defaults = DEFAULTS.duplicate(true)
	var bc := read_boot_config(boot_config_path)
	for k in BOOT_KEYS:
		var v: Variant = bc
		for part in BOOT_KEYS[k]:
			v = (v as Dictionary).get(part, null) if v is Dictionary else null
		if v != null:
			_defaults[k] = _coerce(k, v)


## The effective default of `key` (DEFAULTS, or boot_config.json's value for a BOOT_KEYS key).
func default_of(key: String) -> Variant:
	return _defaults.get(key, DEFAULTS.get(key))


## `boot_config.json` as a Dictionary ({} when absent or malformed; pure).
static func read_boot_config(p: String = BOOT_CONFIG_PATH) -> Dictionary:
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
		return {}
	return j.data


## Write all values now (cancels a pending debounced save). A BOOT_KEYS key equal to its default is
## left out of the file (so a later boot_config flip applies).
func save() -> void:
	_save_pending = false
	for k in _values:
		if BOOT_KEYS.has(k) and _values[k] == _defaults.get(k):
			if _cfg.has_section_key(SECTION, k):
				_cfg.erase_section_key(SECTION, k)
			continue
		_cfg.set_value(SECTION, k, _values[k])
	_cfg.set_value(META, "version", FILE_VERSION)
	var err := SafeFile.save_config(_cfg, path)
	if err != OK:
		push_warning("Settings: could not save %s (%d)" % [path, err])
		return
	save_count += 1


## Write now if a save is pending.
func flush() -> void:
	if _save_pending:
		save()


## True while a debounced save is waiting.
func is_save_pending() -> bool:
	return _save_pending


## Value of `key` (`fallback` for unknown keys).
func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, _defaults.get(key, fallback))


## Set `key` (coerced to the default's type, clamped / validated). Emits `changed` and schedules
## a save when the value actually changed. Returns true if it changed.
func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		push_warning("Settings: unknown key %s" % key)
		return false
	var v: Variant = _coerce(key, value)
	if _values.has(key) and typeof(_values[key]) == typeof(v) and _values[key] == v:
		return false
	_values[key] = v
	if BUSES.has(key):
		_apply_audio(key)
	changed.emit(key, v)
	_queue_save()
	return true


func get_bool(key: String) -> bool:
	return bool(get_value(key, false))


func get_float(key: String) -> float:
	return float(get_value(key, 0.0))


func get_string(key: String) -> String:
	return String(get_value(key, ""))


## All current values (copy).
func all() -> Dictionary:
	return _values.duplicate(true)


## Reset every key to its default (emits `changed` for each key that differs).
func reset_to_defaults() -> void:
	for k in DEFAULTS:
		set_value(k, _defaults.get(k, DEFAULTS[k]))


func _coerce(key: String, value: Variant) -> Variant:
	var d: Variant = DEFAULTS[key]
	# an invalid value falls back to the effective default (boot_config.json's for BOOT_KEYS)
	var fb: Variant = _defaults.get(key, d) if not _defaults.is_empty() else d
	var v: Variant = value
	match typeof(d):
		TYPE_BOOL:
			v = bool(value) if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else fb
		TYPE_FLOAT:
			v = float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fb
		TYPE_STRING:
			v = String(value) if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] else fb
	if CHOICES.has(key) and not (CHOICES[key] as Array).has(v):
		v = fb
	if RANGES.has(key):
		var r: Array = RANGES[key]
		v = clampf(float(v), float(r[0]), float(r[1]))
	return v


func _queue_save() -> void:
	if not is_inside_tree():
		save()
		return
	_save_pending = true
	_save_timer = SAVE_DELAY_SEC


func _apply_audio(key: String) -> void:
	var a := get_node_or_null(^"/root/Audio") if is_inside_tree() else null
	if a != null and a.has_method("set_bus_volume"):
		a.call("set_bus_volume", String(BUSES[key]), float(_values[key]))


func _apply_audio_all() -> void:
	for k in BUSES:
		_apply_audio(k)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_PREDELETE:
		if _save_pending:
			save()
