## StageLighting3D — the lighting model's runtime side (REDESIGN §5.3, R3D index §7.6, ruling R8).
## The `mnd_*` globals are registered in project.godot `[shader_globals]` by the orchestrator; this node only SETS
## values (`RenderingServer.global_shader_parameter_set`) and computes the per-room stage light:
##   Hush's room 1.0 · Bellows' room when it is not hers 0.9 · other built rooms 0.78 + 40 % desaturation ·
##   backstage 0.3 — except a backstage room holding Bellows, lit at 0.9 · Settings `room_dimming` off → every built
##   room 1.0 · every change tweened over 0.4 s.
## Bellows' own char_toon `stage_light` never drops below 0.9 (`bellows_level()`); Hush's follows her room.
## `levels_for()` is pure (tests); `advance(dt)` eases the current levels toward the targets without allocating.
class_name StageLighting3D
extends Node

## Every global the 3D shaders read, with its index §7.6 default (the same values as project.godot).
const DEFAULTS := {
	&"mnd_key_dir": Vector3(-0.451039, 0.751731, 0.481108),
	&"mnd_key_color": Color(1.0, 0.956863, 0.878431, 1.0),
	&"mnd_key_lit": 0.28,
	&"mnd_key_top": 0.08,
	&"mnd_fill": 0.66,
	&"mnd_fill_color": Color(0.658824, 0.643137, 0.682353, 1.0),
	&"mnd_band_soft": 0.08,
	&"mnd_rim_color": Color(0.74902, 0.878431, 1.0, 1.0),
	&"mnd_rim_power": 2.5,
	&"mnd_foot_strength": 0.12,
	&"mnd_foot_fade_m": 1.2,
	&"mnd_lip_z": 0.25,
	&"mnd_outline_scale": 1.0,
	&"mnd_shadow_tint": Color(0.72549, 0.639216, 0.878431, 1.0),
	&"mnd_bounce": 0.14,
	&"mnd_sheen": 0.10,
}

const LIGHT_OF_UNKNOWN := 1.0
## The widest level change (backstage 0.3 → 1.0): every change completes within LIGHT_EASE_S.
const LEVEL_SPAN := 0.7

## Emitted when a room's eased level or desaturation changes this frame: listeners (House3D via WorldView3D) apply it.
signal room_light_changed(room: String, level: float, desat: float)

var _dimming := true
var _rooms: PackedStringArray = []
var _backstage: PackedStringArray = []
var _cur_level: Dictionary = {}   # room → float
var _cur_desat: Dictionary = {}   # room → float
var _tgt_level: Dictionary = {}
var _tgt_desat: Dictionary = {}
var _hush_room := ""
var _bellows_room := ""
var _globals_ok := -1


func _ready() -> void:
	apply_defaults()


## Sets every global to its default (a fresh Night, tests).
func apply_defaults() -> void:
	for k in DEFAULTS:
		set_global(k, DEFAULTS[k])


## Sets one `mnd_*` global when it is registered (the headless dummy renderer has none; that is fine).
func set_global(name: StringName, value: Variant) -> void:
	if not _globals_available():
		return
	RenderingServer.global_shader_parameter_set(name, value)


## Settings "Outline +50 %" → 1.5 (every outline shader multiplies by it).
func set_outline_scale(k: float) -> void:
	set_global(&"mnd_outline_scale", k)


## The built rooms (lit) and the backstage rooms of tonight's set (SetList.Result rooms_lit / rooms_backstage).
func setup_rooms(rooms_lit: PackedStringArray, rooms_backstage: PackedStringArray) -> void:
	_rooms = rooms_lit.duplicate()
	_backstage = rooms_backstage.duplicate()
	_cur_level.clear()
	_cur_desat.clear()
	_tgt_level.clear()
	_tgt_desat.clear()
	for r in _all_rooms():
		_cur_level[r] = LIGHT_OF_UNKNOWN
		_cur_desat[r] = 0.0
	_retarget()
	snap_now()


## Settings `room_dimming` (off → every built room 1.0, backstage still 0.3).
func set_dimming(on: bool) -> void:
	_dimming = on
	_retarget()


## Where the two characters are this frame ("" = unknown / off stage).
func set_rooms_of(hush_room: String, bellows_room: String) -> void:
	if hush_room == _hush_room and bellows_room == _bellows_room:
		return
	_hush_room = hush_room
	_bellows_room = bellows_room
	_retarget()


## Eases the current levels toward the targets (0.4 s linear) and emits `room_light_changed` for rooms that moved.
func advance(dt: float) -> void:
	var step := dt / View3DConst.LIGHT_EASE_S
	for r in _cur_level:
		var l: float = _cur_level[r]
		var d: float = _cur_desat[r]
		var tl: float = _tgt_level.get(r, l)
		var td: float = _tgt_desat.get(r, d)
		if is_equal_approx(l, tl) and is_equal_approx(d, td):
			continue
		l = move_toward(l, tl, step * LEVEL_SPAN)
		d = move_toward(d, td, step * View3DConst.DESAT_OTHER)
		_cur_level[r] = l
		_cur_desat[r] = d
		room_light_changed.emit(r, l, d)


## Jumps to the targets (retry, seek, first frame) and emits every room once.
func snap_now() -> void:
	for r in _cur_level:
		_cur_level[r] = _tgt_level.get(r, _cur_level[r])
		_cur_desat[r] = _tgt_desat.get(r, _cur_desat[r])
		room_light_changed.emit(r, _cur_level[r], _cur_desat[r])


## The current (eased) level of a room; 1.0 for an unknown room.
func level(room: String) -> float:
	return float(_cur_level.get(room, 1.0))


## The current (eased) desaturation of a room.
func desat(room: String) -> float:
	return float(_cur_desat.get(room, 0.0))


## Hush's char_toon stage_light: her room's level.
func hush_level() -> float:
	return level(_hush_room) if _hush_room != "" else 1.0


## Bellows' char_toon stage_light: max(his room's level, 0.9).
func bellows_level() -> float:
	return maxf(level(_bellows_room) if _bellows_room != "" else 1.0, View3DConst.LIGHT_BELLOWS_MIN)


## Pure: the target {room: [level, desat]} for a set of rooms (the rules of the class doc).
static func levels_for(rooms_lit: PackedStringArray, rooms_backstage: PackedStringArray, hush_room: String,
		bellows_room: String, dimming: bool = true) -> Dictionary:
	var out := {}
	for r in rooms_lit:
		var lv := View3DConst.LIGHT_OTHER
		var ds := View3DConst.DESAT_OTHER
		if not dimming or r == hush_room:
			lv = View3DConst.LIGHT_HUSH
			ds = 0.0
		elif r == bellows_room:
			lv = View3DConst.LIGHT_BELLOWS
			ds = 0.0
		out[r] = [lv, ds]
	for r in rooms_backstage:
		if r == bellows_room:
			out[r] = [View3DConst.LIGHT_BACKSTAGE_BELLOWS, 0.0]
		else:
			out[r] = [View3DConst.LIGHT_BACKSTAGE, 0.0]
	return out


func _retarget() -> void:
	var t := levels_for(_rooms, _backstage, _hush_room, _bellows_room, _dimming)
	for r in t:
		_tgt_level[r] = t[r][0]
		_tgt_desat[r] = t[r][1]
		if not _cur_level.has(r):
			_cur_level[r] = t[r][0]
			_cur_desat[r] = t[r][1]


func _all_rooms() -> PackedStringArray:
	var out := _rooms.duplicate()
	out.append_array(_backstage)
	return out


func _globals_available() -> bool:
	if _globals_ok == -1:
		var names := RenderingServer.global_shader_parameter_get_list()
		_globals_ok = 1 if names.has(&"mnd_fill") else 0
	return _globals_ok == 1
