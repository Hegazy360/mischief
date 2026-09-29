## Fx — integer maths helpers for the deterministic sim (TECH §2, §3.1).
##
## Units: positions are sub-pixels (`SimConst.SUB` = 60 per px), time is ticks (60 per second).
## JSON carries px and seconds as floats; they are converted ONLY at load time with `px()` and
## `ticks()` (round half away from zero). Every division in the sim goes through `div()` (floor).
class_name Fx
extends RefCounted


## px (float, from JSON) → sub-pixels, round half away from zero.
static func px(v: float) -> int:
	return roundi(v * 60.0)


## seconds (float, from JSON) → ticks, round half away from zero.
static func ticks(sec: float) -> int:
	return roundi(sec * 60.0)


## Floor division (GDScript `/` on ints truncates toward zero). `b` must not be 0.
@warning_ignore("integer_division")
static func div(a: int, b: int) -> int:
	var q: int = a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


## Ceiling division for non-negative `a` and positive `b`.
@warning_ignore("integer_division")
static func div_ceil(a: int, b: int) -> int:
	if a <= 0:
		return 0
	return (a + b - 1) / b


## `v * pct / 100` with floor rounding.
static func mul_pct(v: int, pct: int) -> int:
	return div(v * pct, 100)


## Clamp `v` into [lo, hi].
static func clampi(v: int, lo: int, hi: int) -> int:
	return lo if v < lo else (hi if v > hi else v)


## Absolute value.
static func absi(v: int) -> int:
	return -v if v < 0 else v


## Sign: -1, 0 or +1.
static func signi(v: int) -> int:
	return 1 if v > 0 else (-1 if v < 0 else 0)


## Integer lerp: a + (b - a) * num / den (floor), den > 0.
static func lerp_i(a: int, b: int, num: int, den: int) -> int:
	if den <= 0:
		return b
	return a + div((b - a) * num, den)


## Smaller of two ints.
static func mini(a: int, b: int) -> int:
	return a if a < b else b


## Larger of two ints.
static func maxi(a: int, b: int) -> int:
	return a if a > b else b


## Sub-pixels → px (floor), for event payloads.
static func to_px(sub: int) -> int:
	return div(sub, 60)
