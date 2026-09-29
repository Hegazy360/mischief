## JuiceClock — hit-stop, slow-mo and freeze-frame segments for the Night view (TECH §5.2).
## Port of Booby's clock with one big change: it NEVER touches `Engine.time_scale`. It only
## computes a scale that `SimDriver` multiplies into its tick rate (and that world visuals
## read through `SimDriver.view_delta()`), so UI tweens and input stay real-time.
##
## * Every duration is REAL time (`Time.get_ticks_usec`, or `test_now_us` in tests): a 5-frame
##   hit-stop lasts 83 ms on the wall clock whatever the frame rate.
## * A freeze runs at FREEZE_SCALE (0.05). Segments merge: the lowest scale and the longest
##   remaining time win.
## * Cap: at most CAP_MS (150) ms of hit-stop freeze inside any 1 s window (GDD §3.7).
## * A slow segment (approach slow-mo) starts when the freeze ends and eases back to 1.0 over
##   its ease time.
## * A freeze-frame (the biggest gag of a chain, 45–60 f) is a separate, deliberate stop at
##   scale 0: it is not hit-stop, so it is exempt from the cap; `freeze_frame_changed` lets
##   the FX layer draw the paper border.
## * `enabled = false` makes every request a no-op (reduce-motion previews, tests).
class_name JuiceClock
extends Node

## True while a hit-stop freeze is running (on) / just ended (off).
signal freeze_changed(on: bool)
## True while a freeze-frame is running (on) / just ended (off).
signal freeze_frame_changed(on: bool)

const FREEZE_SCALE := 0.05
const CAP_MS := 150
const CAP_WINDOW_US := 1000000
const FRAME_US := 16667

## Request kinds (TECH §5.2 / GDD §9.3): kind → [freeze_frames, slow_scale, slow_frames,
## ease_frames, freeze_frame_frames].
const KINDS := {
	"hit_small": [3, 1.0, 0, 0, 0],
	"hit_big": [5, 1.0, 0, 0, 0],
	"hit_sig": [8, 1.0, 0, 0, 0],
	"approach_slowmo": [0, 0.5, 24, 6, 0],
	"freeze_frame": [0, 1.0, 0, 0, 52],
}

var enabled: bool = true:
	set(v):
		if enabled == v:
			return
		enabled = v
		if not v:
			reset()
## Test hook: a fixed "now" in µs (>= 0) instead of Time.get_ticks_usec().
var test_now_us: int = -1

var _freeze_until := 0
var _slow_scale := 1.0
var _slow_start := 0
var _slow_until := 0
var _ease_us := 0
var _ff_until := 0
var _frozen := false
var _ff_on := false
var _applied := 1.0
## Freeze grants inside the cap window, as a flat ring: [start_us, granted_us, ...].
var _grants := PackedInt64Array()
var _last_kind: StringName = &""


func _init() -> void:
	name = "JuiceClock"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	advance()


## Drop every segment (scale back to 1.0).
func reset() -> void:
	_freeze_until = 0
	_slow_until = 0
	_slow_scale = 1.0
	_ff_until = 0
	_grants.clear()
	if _frozen:
		_frozen = false
		freeze_changed.emit(false)
	if _ff_on:
		_ff_on = false
		freeze_frame_changed.emit(false)
	_applied = 1.0


## Request a named segment from KINDS (`freeze_frame` accepts `frames` 45–60; 0 = default).
func request_kind(kind: StringName, frames: int = 0) -> void:
	var row: Variant = KINDS.get(String(kind), null)
	if row == null:
		push_warning("JuiceClock: unknown kind %s" % kind)
		return
	var r: Array = row
	if int(r[4]) > 0:
		freeze_frame(clampi(frames if frames > 0 else int(r[4]), 45, 60), kind)
		return
	request(kind, int(r[0]) * FRAME_US / 1000, float(r[1]), float(r[2]) / 60.0, float(r[3]) / 60.0)


## Ask for a freeze of `freeze_ms` (real ms, capped) followed by `slow_scale` for
## `slow_sec` (easing back to 1.0 over `ease_sec`). Merges with what is running.
func request(kind: StringName, freeze_ms: int, slow_scale: float = 1.0, slow_sec: float = 0.0, ease_sec: float = 0.0) -> void:
	if not enabled:
		return
	var now := _now()
	_last_kind = kind
	var fz_end := maxi(_freeze_until, now)
	if freeze_ms > 0:
		var want := freeze_ms * 1000
		var grant := mini(want, maxi(0, CAP_MS * 1000 - freeze_used_us(now)))
		var new_end := maxi(_freeze_until, now + grant)
		var added := new_end - maxi(_freeze_until, now)
		if added > 0:
			_grants.append(now)
			_grants.append(added)
		_freeze_until = new_end
		fz_end = maxi(new_end, now)
	if slow_sec > 0.0 and slow_scale < 0.999:
		var s_end := fz_end + int(slow_sec * 1000000.0)
		if now >= _slow_until:
			_slow_scale = slow_scale
			_slow_start = fz_end
			_ease_us = int(maxf(0.0, ease_sec) * 1000000.0)
		else:
			_slow_scale = minf(_slow_scale, slow_scale)
			_ease_us = maxi(_ease_us, int(maxf(0.0, ease_sec) * 1000000.0))
		_slow_until = maxi(_slow_until, s_end)
	advance()


## A freeze-frame of `frames` (real 60 fps frames) at scale 0 — exempt from the hit-stop cap.
func freeze_frame(frames: int, kind: StringName = &"freeze_frame") -> void:
	if not enabled:
		return
	var now := _now()
	_last_kind = kind
	_ff_until = maxi(_ff_until, now + maxi(1, frames) * FRAME_US)
	advance()


## µs of hit-stop freeze granted inside the last CAP window ending at `now`.
func freeze_used_us(now: int = -1) -> int:
	if now < 0:
		now = _now()
	var used := 0
	var i := 0
	# Drop expired grants from the front (they are appended in time order).
	while i < _grants.size() and _grants[i] <= now - CAP_WINDOW_US:
		i += 2
	if i > 0:
		_grants = _grants.slice(i)
	for j in range(0, _grants.size(), 2):
		used += int(_grants[j + 1])
	return used


## Pure: the scale at `now` for a freeze ending at `freeze_until` and a slow segment
## [slow_start, slow_until) at `slow_scale` easing back over `ease_us`.
static func scale_at(now: int, freeze_until: int, slow_start: int, slow_until: int, slow_scale: float, ease_us: int) -> float:
	if now < freeze_until:
		return FREEZE_SCALE
	if now < slow_until and now >= slow_start - 1:
		var left := slow_until - now
		if ease_us > 0 and left < ease_us:
			var u := 1.0 - float(left) / float(ease_us)
			return lerpf(slow_scale, 1.0, u * u * (3.0 - 2.0 * u))
		return slow_scale
	return 1.0


## Re-evaluate the scale (called every frame; public for tests).
func advance() -> void:
	var now := _now()
	var s := 1.0
	if enabled:
		s = JuiceClock.scale_at(now, _freeze_until, _slow_start, _slow_until, _slow_scale, _ease_us)
		if now < _ff_until:
			s = 0.0
	var fr := enabled and now < _freeze_until
	if fr != _frozen:
		_frozen = fr
		freeze_changed.emit(fr)
	var ff := enabled and now < _ff_until
	if ff != _ff_on:
		_ff_on = ff
		freeze_frame_changed.emit(ff)
	_applied = s


## Time scale this clock wants right now (1.0 when idle, 0.05 in hit-stop, 0 in a
## freeze-frame). SimDriver multiplies it into its tick rate.
func scale() -> float:
	return _applied


## Alias of scale() (Booby naming).
func current_scale() -> float:
	return _applied


func is_frozen() -> bool:
	return _frozen


func is_freeze_frame() -> bool:
	return _ff_on


## True while any segment (freeze, slow, freeze-frame) is running.
func is_busy() -> bool:
	var now := _now()
	return now < _freeze_until or now < _slow_until or now < _ff_until


## The kind of the latest request (debug / tests).
func last_kind() -> StringName:
	return _last_kind


func _now() -> int:
	return test_now_us if test_now_us >= 0 else Time.get_ticks_usec()
