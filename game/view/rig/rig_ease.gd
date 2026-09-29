## RigEase — the closed ease vocabulary of clips (TECH §4.8): `linear, hold, pop` and
## `in_ / out_ / in_out_` × `quad, cubic, quart, expo, sine, back, elastic, bounce`.
##
## A key's ease is the curve used to travel FROM the previous key TO this key. Names are
## resolved to int ids at load (ClipLib); `apply(id, t)` evaluates the curve with the same
## equations as Godot's `Tween.interpolate_value(0, 1, t, 1, TRANS_*, EASE_*)` (the Penner
## equations of the engine's easing_equations.h, including its expo end corrections), so a
## clip plays exactly like a Tween would (tests compare them at 11 points per curve).
## `hold` and `pop` step: the value stays on the previous key until this key's frame, then
## jumps (pop = a deliberate pose pop: the animation lint allows > 45°/f jumps into it).
## Pure and allocation-free.
class_name RigEase
extends RefCounted

const LINEAR := 0
const HOLD := 1
const POP := 2
## Ids 3.. are FAMILY_BASE + family * 3 + kind (kind 0 = in, 1 = out, 2 = in_out).
const FAMILY_BASE := 3
const FAMILIES: PackedStringArray = ["quad", "cubic", "quart", "expo", "sine", "back", "elastic", "bounce"]
const KINDS: PackedStringArray = ["in", "out", "in_out"]
const _TRANS: PackedInt32Array = [Tween.TRANS_QUAD, Tween.TRANS_CUBIC, Tween.TRANS_QUART, Tween.TRANS_EXPO,
	Tween.TRANS_SINE, Tween.TRANS_BACK, Tween.TRANS_ELASTIC, Tween.TRANS_BOUNCE]
const _EASE: PackedInt32Array = [Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT]

static var _ids: Dictionary = {}


## Ease id for `name` ("" → LINEAR); -1 when unknown.
static func id(name: String) -> int:
	if name == "" or name == "linear":
		return LINEAR
	if name == "hold":
		return HOLD
	if name == "pop":
		return POP
	if _ids.is_empty():
		for f in FAMILIES.size():
			for k in KINDS.size():
				_ids["%s_%s" % [KINDS[k], FAMILIES[f]]] = FAMILY_BASE + f * 3 + k
	return int(_ids.get(name, -1))


## Name of an ease id ("" when unknown).
static func name_of(ease_id: int) -> String:
	match ease_id:
		LINEAR:
			return "linear"
		HOLD:
			return "hold"
		POP:
			return "pop"
	var i := ease_id - FAMILY_BASE
	if i < 0 or i >= FAMILIES.size() * 3:
		return ""
	return "%s_%s" % [KINDS[i % 3], FAMILIES[i / 3]]


## Every valid ease name.
static func all_names() -> PackedStringArray:
	var out := PackedStringArray(["linear", "hold", "pop"])
	for f in FAMILIES:
		for k in KINDS:
			out.append("%s_%s" % [k, f])
	return out


## True for the stepped eases (hold, pop).
static func is_step(ease_id: int) -> bool:
	return ease_id == HOLD or ease_id == POP


## The Godot [trans, ease] pair of a family ease (for tests); [-1, -1] for linear/hold/pop.
static func tween_pair(ease_id: int) -> PackedInt32Array:
	var i := ease_id - FAMILY_BASE
	if i < 0 or i >= FAMILIES.size() * 3:
		return PackedInt32Array([-1, -1])
	return PackedInt32Array([_TRANS[i / 3], _EASE[i % 3]])


## Eased progress for t in [0, 1] (t is clamped), identical to Godot's
## `Tween.interpolate_value(0.0, 1.0, t, 1.0, trans, ease)` — including the engine's expo
## ends (expo in reaches 0.999 at t = 1). Steps (hold, pop) return 0 below 1 and 1 at 1.
static func apply(ease_id: int, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match ease_id:
		LINEAR:
			return t
		HOLD, POP:
			return 1.0 if t >= 1.0 else 0.0
	var i := ease_id - FAMILY_BASE
	if i < 0 or i >= FAMILIES.size() * 3:
		return t
	var fam := i / 3
	var kind := i % 3
	if fam == 3 or fam == 6:
		# Expo / elastic special-case their ends exactly like the engine.
		if t == 0.0:
			return 0.0
		if t == 1.0 and not (fam == 3 and kind == 0):
			return 1.0
	if kind == 0:
		return _in(fam, t)
	if kind == 1:
		return _out(fam, t)
	if t < 0.5:
		return _in_out_lo(fam, t)
	return _in_out_hi(fam, t)


static func _in(fam: int, t: float) -> float:
	match fam:
		0:
			return t * t
		1:
			return t * t * t
		2:
			return t * t * t * t
		3:
			return pow(2.0, 10.0 * (t - 1.0)) - 0.001
		4:
			return -cos(t * PI * 0.5) + 1.0
		5:
			var s := 1.70158
			return t * t * ((s + 1.0) * t - s)
		6:
			var t1 := t - 1.0
			var p := 0.3
			var s2 := p / 4.0
			return -(pow(2.0, 10.0 * t1) * sin((t1 - s2) * TAU / p))
		7:
			return 1.0 - _bounce_out(1.0 - t)
	return t


static func _out(fam: int, t: float) -> float:
	match fam:
		0:
			return -t * (t - 2.0)
		1:
			var u := t - 1.0
			return u * u * u + 1.0
		2:
			var u2 := t - 1.0
			return -(u2 * u2 * u2 * u2 - 1.0)
		3:
			return 1.001 * (1.0 - pow(2.0, -10.0 * t))
		4:
			return sin(t * PI * 0.5)
		5:
			var s := 1.70158
			var u3 := t - 1.0
			return u3 * u3 * ((s + 1.0) * u3 + s) + 1.0
		6:
			var p := 0.3
			var s2 := p / 4.0
			return pow(2.0, -10.0 * t) * sin((t - s2) * TAU / p) + 1.0
		7:
			return _bounce_out(t)
	return t


static func _in_out_lo(fam: int, t: float) -> float:
	var u := t * 2.0
	match fam:
		0:
			return 0.5 * u * u
		1:
			return 0.5 * u * u * u
		2:
			return 0.5 * u * u * u * u
		3:
			return 0.5 * pow(2.0, 10.0 * (u - 1.0)) - 0.0005
		4:
			return -0.5 * (cos(PI * t) - 1.0)
		5:
			var s := 1.70158 * 1.525
			return 0.5 * (u * u * ((s + 1.0) * u - s))
		6:
			var p := 0.3 * 1.5
			var s2 := p / 4.0
			var u1 := u - 1.0
			return -0.5 * (pow(2.0, 10.0 * u1) * sin((u1 - s2) * TAU / p))
		7:
			return 0.5 * (1.0 - _bounce_out(1.0 - u))
	return t


static func _in_out_hi(fam: int, t: float) -> float:
	var u := t * 2.0
	match fam:
		0:
			return -0.5 * ((u - 1.0) * (u - 3.0) - 1.0)
		1:
			var v := u - 2.0
			return 0.5 * (v * v * v + 2.0)
		2:
			var v2 := u - 2.0
			return -0.5 * (v2 * v2 * v2 * v2 - 2.0)
		3:
			return 0.5 * 1.0005 * (-pow(2.0, -10.0 * (u - 1.0)) + 2.0)
		4:
			return -0.5 * (cos(PI * t) - 1.0)
		5:
			var s := 1.70158 * 1.525
			var v3 := u - 2.0
			return 0.5 * (v3 * v3 * ((s + 1.0) * v3 + s) + 2.0)
		6:
			var p := 0.3 * 1.5
			var s2 := p / 4.0
			var u1 := u - 1.0
			return pow(2.0, -10.0 * u1) * sin((u1 - s2) * TAU / p) * 0.5 + 1.0
		7:
			return 0.5 + 0.5 * _bounce_out(u - 1.0)
	return t


static func _bounce_out(t: float) -> float:
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	if t < 2.0 / 2.75:
		var a := t - 1.5 / 2.75
		return 7.5625 * a * a + 0.75
	if t < 2.5 / 2.75:
		var b := t - 2.25 / 2.75
		return 7.5625 * b * b + 0.9375
	var c := t - 2.625 / 2.75
	return 7.5625 * c * c + 0.984375
