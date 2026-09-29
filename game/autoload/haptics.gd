## Haptics — named vibration pulses (GDD §3.10) via `Input.vibrate_handheld` (VIBRATE only).
##
## Pulses (ms / amplitude): tap 8/0.3 · ui 8/0.3 · ring_half 8/0.35 · rig_done 30/0.7 ·
## accent 40 + 60 (two pulses 90 ms apart) · near_miss 20/0.5 · caught 3 × 30 (110 ms apart) ·
## stomp 60/1.0 (the view calls it on each Meltdown stomp).
## Rate limit: at most MAX_PER_SEC pulses start in any rolling second; extra pulses are dropped
## (`dropped` counts them). Respects Settings.haptics. A no-op on desktop / web unless
## `force_enabled` (tests). Multi-pulse patterns are queued and fired from `_process` (or
## `pump()`), never with timers, so they are deterministic in tests (`now_override`).
## Registered as the `Haptics` autoload by the orchestrator.
extends Node

const MAX_PER_SEC := 6
const WINDOW_MS := 1000
## name → Array of [delay_ms, duration_ms, amplitude].
const PATTERNS := {
	&"tap": [[0, 8, 0.3]],
	&"ui": [[0, 8, 0.3]],
	&"ring_half": [[0, 8, 0.35]],
	&"rig_done": [[0, 30, 0.7]],
	&"accent": [[0, 40, 0.8], [90, 60, 1.0]],
	&"near_miss": [[0, 20, 0.5]],
	&"caught": [[0, 30, 0.8], [110, 30, 0.8], [220, 30, 0.8]],
	&"stomp": [[0, 60, 1.0]],
}

## Force vibration on non-mobile platforms (tests / debug). Calls are recorded either way.
var force_enabled: bool = false
## Test hook: when ≥ 0, used instead of Time.get_ticks_msec().
var now_override: int = -1
## Test hook: record instead of vibrating.
var dry_run: bool = false
## Last pulses actually fired: [kind, ms, amplitude] (≤ 32 kept).
var fired: Array = []
## Pulses dropped by the rate limit.
var dropped: int = 0

var _window := PackedInt64Array()        # start times of pulses in the last second
var _queue: Array = []                   # [due_ms, kind, ms, amp] sorted by due


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not _queue.is_empty():
		pump()


## True when a pulse would reach the motor (Settings.haptics on, and a phone or forced).
func is_available() -> bool:
	if not _setting_on():
		return false
	return force_enabled or OS.has_feature("android") or OS.has_feature("ios")


## Fire a named pulse pattern (see PATTERNS). Unknown names are ignored. Returns false when
## haptics are off / unavailable.
func pulse(kind: StringName) -> bool:
	if not PATTERNS.has(kind):
		return false
	if not is_available():
		return false
	var now := _now()
	for step in PATTERNS[kind]:
		var s: Array = step
		if int(s[0]) == 0:
			_fire(kind, int(s[1]), float(s[2]), now)
		else:
			_enqueue(now + int(s[0]), kind, int(s[1]), float(s[2]))
	return true


## Named shortcuts (the view and HUD call these or `pulse(&"…")`).
func tap() -> void:
	pulse(&"tap")


func ui() -> void:
	pulse(&"ui")


func ring_half() -> void:
	pulse(&"ring_half")


func rig_done() -> void:
	pulse(&"rig_done")


func accent() -> void:
	pulse(&"accent")


func near_miss() -> void:
	pulse(&"near_miss")


func caught() -> void:
	pulse(&"caught")


func stomp() -> void:
	pulse(&"stomp")


## Fire queued pattern steps that are due (called every frame; public for tests).
func pump() -> void:
	var now := _now()
	while not _queue.is_empty() and int((_queue[0] as Array)[0]) <= now:
		var q: Array = _queue.pop_front()
		if is_available():
			_fire(StringName(q[1]), int(q[2]), float(q[3]), now)


## Pulses started in the last second.
func pulses_in_window() -> int:
	_trim(_now())
	return _window.size()


## Forget the rate-limit history and queued steps (tests, or after a pause).
func reset() -> void:
	_window = PackedInt64Array()
	_queue.clear()
	fired.clear()
	dropped = 0


func _fire(kind: StringName, ms: int, amp: float, now: int) -> void:
	_trim(now)
	if _window.size() >= MAX_PER_SEC:
		dropped += 1
		return
	_window.append(now)
	fired.append([String(kind), ms, amp])
	if fired.size() > 32:
		fired.pop_front()
	if not dry_run:
		Input.vibrate_handheld(ms, amp)


func _enqueue(due: int, kind: StringName, ms: int, amp: float) -> void:
	var item := [due, String(kind), ms, amp]
	var i := _queue.size()
	while i > 0 and int((_queue[i - 1] as Array)[0]) > due:
		i -= 1
	_queue.insert(i, item)


func _trim(now: int) -> void:
	var keep := 0
	while keep < _window.size() and now - _window[keep] >= WINDOW_MS:
		keep += 1
	if keep > 0:
		_window = _window.slice(keep)


func _now() -> int:
	return now_override if now_override >= 0 else Time.get_ticks_msec()


func _setting_on() -> bool:
	var s := get_node_or_null(^"/root/Settings") if is_inside_tree() else null
	if s != null and s.has_method("get_value"):
		return bool(s.call("get_value", "haptics", true))
	return true
