## HiddenEyes — Hush's eyes in the dark gap of a hiding spot (GDD §3.4 "the hidden eyes", STYLE
## §8 `eyes`, rig.json `hidden`): the whites sprite at the hotspot's `eyes` point, the pupils
## sprite shifted within ±`pupil_range` (6 × 3 px) toward Bellows' head, and the blink sprite for
## 6 frames every 2–6 s (seeded per spot, so two spots never blink together). The art comes from
## Hush's rig.json `hidden` block (Pip skin files swapped by `skins.pip.files`); the complete
## `file` sprite is the fallback when whites / pupils are missing.
##
## Pure helpers (`pupil_offset`, `blink_gap_s`) are static so tests check the math headless.
class_name HiddenEyes
extends Node2D

const RIG_JSON := "res://data/rigs/hush/rig.json"
const BLINK_FRAMES := 6.0
const BLINK_MIN_S := 2.0
const BLINK_MAX_S := 6.0
## Pupils ease toward their target (s).
const TRACK_TAU := 0.12

## World point the pupils look at (Bellows' head); Vector2.INF = straight ahead.
var look_target: Vector2 = Vector2.INF
var pupil_range: Vector2 = Vector2(6, 3)
var pivot: Vector2 = Vector2(77, 44)

var _whites: Texture2D = null
var _pupils: Texture2D = null
var _blink_tex: Texture2D = null
var _full: Texture2D = null
var _seed: int = 1
var _blink_in: float = 3.0
var _blink_f: float = 0.0
var _pupil: Vector2 = Vector2.ZERO
var _loaded := false


func _init() -> void:
	name = "HiddenEyes"
	visible = false


## Load the eye sprites for a skin ("" | "pip") and seed the blink timer.
func setup(skin: String, seed_: int) -> void:
	_seed = maxi(1, seed_ & 0x7fffffff)
	_blink_in = HiddenEyes.blink_gap_s(_seed)
	var d: Variant = ViewKit.json(RIG_JSON)
	var hid: Dictionary = {}
	var swaps: Dictionary = {}
	if d is Dictionary:
		var hv: Variant = (d as Dictionary).get("hidden", {})
		hid = hv if hv is Dictionary else {}
		if skin != "":
			var sk: Variant = ((d as Dictionary).get("skins", {}) as Dictionary).get(skin, {}) if (d as Dictionary).get("skins", {}) is Dictionary else {}
			if sk is Dictionary and (sk as Dictionary).get("files", null) is Dictionary:
				swaps = (sk as Dictionary)["files"]
	var pv: Variant = hid.get("pivot", null)
	if pv is Array and (pv as Array).size() >= 2:
		pivot = Vector2(float(pv[0]), float(pv[1]))
	var pr: Variant = hid.get("pupil_range", null)
	if pr is Array and (pr as Array).size() >= 2:
		pupil_range = Vector2(float(pr[0]), float(pr[1]))
	_whites = _load(ViewKit.s(hid.get("whites", "")), swaps)
	_pupils = _load(ViewKit.s(hid.get("pupils", "")), swaps)
	_blink_tex = _load(ViewKit.s(hid.get("blink", "")), swaps)
	_full = _load(ViewKit.s(hid.get("file", "")), swaps)
	if _full == null and _whites == null:
		_full = FxArt.sprite("fallback/eyes")
	_loaded = true
	queue_redraw()


func _load(path: String, swaps: Dictionary) -> Texture2D:
	if path == "":
		return null
	return ViewKit.tex(ViewKit.s(swaps.get(path, path)))


## The pupil offset (px) for eyes at `eye_pos` looking at `target`: the direction scaled into the
## ±`rng` box (x and y independently, so a target far to the side slides the pupils fully
## sideways while a small height difference only nudges them).
static func pupil_offset(eye_pos: Vector2, target: Vector2, rng: Vector2) -> Vector2:
	if target == Vector2.INF:
		return Vector2.ZERO
	var d := target - eye_pos
	var l := d.length()
	if l < 1.0:
		return Vector2.ZERO
	var n := d / l
	# Full deflection from ~260 px away; closer targets deflect less (eyes converge).
	var k := clampf(l / 260.0, 0.0, 1.0)
	return Vector2(clampf(n.x * k * 1.6, -1.0, 1.0) * rng.x, clampf(n.y * k * 1.6, -1.0, 1.0) * rng.y)


## Seconds until the next blink for a seed: 2–6 s, deterministic.
static func blink_gap_s(seed_: int) -> float:
	var h := (seed_ * 1103515245 + 12345) & 0x7fffffff
	return BLINK_MIN_S + float(h % 1000) / 1000.0 * (BLINK_MAX_S - BLINK_MIN_S)


## True while the blink sprite shows.
func is_blinking() -> bool:
	return _blink_f > 0.0


## The current (eased) pupil offset.
func pupil() -> Vector2:
	return _pupil


## Per frame (view time).
func tick(dt: float) -> void:
	if not visible:
		return
	_blink_in -= dt
	if _blink_in <= 0.0:
		_blink_f = BLINK_FRAMES
		_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
		_blink_in = HiddenEyes.blink_gap_s(_seed)
	if _blink_f > 0.0:
		_blink_f = maxf(0.0, _blink_f - dt * 60.0)
	var want := HiddenEyes.pupil_offset(global_position, look_target, pupil_range)
	_pupil = _pupil.lerp(want, 1.0 - exp(-dt / TRACK_TAU)) if dt > 0.0 else want
	queue_redraw()


func _draw() -> void:
	if not _loaded:
		return
	if _blink_f > 0.0 and _blink_tex != null:
		draw_texture(_blink_tex, -pivot)
		return
	if _whites != null:
		draw_texture(_whites, -pivot)
		if _pupils != null:
			draw_texture(_pupils, -pivot + _pupil.round())
		return
	if _full != null:
		if _blink_f > 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.15))
		draw_texture(_full, -pivot if _full.get_size().x > 100.0 else -_full.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
