## Settings — persisted player preferences (`user://settings.cfg`, TECH §7, GDD §3.11).
##
## Keys (DEFAULTS): music_vol, sfx_vol, voice_vol, crowd_vol (linear 0..1), haptics, relaxed,
## tap_to_rig, left_handed, hints ("always" | "long_press" | "off"), stare_strip, reduce_motion,
## reduce_flash, text_scale (1.0 or 1.2 = "Text +20 %").
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
}
## Allowed values of string keys (anything else falls back to the default).
const CHOICES := {"hints": ["always", "long_press", "off"]}
## Clamp ranges of numeric keys.
const RANGES := {
	"music_vol": [0.0, 1.0], "sfx_vol": [0.0, 1.0], "voice_vol": [0.0, 1.0], "crowd_vol": [0.0, 1.0],
	"text_scale": [1.0, 1.2],
}
## Volume key → Audio bus (TECH §5.8).
const BUSES := {"music_vol": "Music", "sfx_vol": "SFX", "voice_vol": "Voice", "crowd_vol": "Crowd"}

## Override before _ready / load_settings (tests) to use another file.
var path: String = PATH
## Number of completed writes (tests).
var save_count: int = 0

var _values: Dictionary = {}
var _cfg := ConfigFile.new()
var _save_pending := false
var _save_timer: float = 0.0


func _init() -> void:
	_values = DEFAULTS.duplicate(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_values = DEFAULTS.duplicate(true)
	_cfg = ConfigFile.new()
	if SafeFile.load_config(_cfg, path) == OK:
		for k in DEFAULTS:
			if _cfg.has_section_key(SECTION, k):
				_values[k] = _coerce(k, _cfg.get_value(SECTION, k))


## Write all values now (cancels a pending debounced save).
func save() -> void:
	_save_pending = false
	for k in _values:
		_cfg.set_value(SECTION, k, _values[k])
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
	return _values.get(key, DEFAULTS.get(key, fallback))


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
		set_value(k, DEFAULTS[k])


func _coerce(key: String, value: Variant) -> Variant:
	var d: Variant = DEFAULTS[key]
	var v: Variant = value
	match typeof(d):
		TYPE_BOOL:
			v = bool(value) if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else d
		TYPE_FLOAT:
			v = float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else d
		TYPE_STRING:
			v = String(value) if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] else d
	if CHOICES.has(key) and not (CHOICES[key] as Array).has(v):
		v = d
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
