## SimDriver — owns the SimWorld (or a FakeWorld) and ticks it from the frame clock
## (TECH §5.2).
##
## `_process(delta)`: `acc += delta × 60 × rate` with `rate = juice.scale() × ff × safety`
## (0 while paused); whole ticks run (at most MAX_TICKS_PER_FRAME per frame, the rest is
## dropped); after each tick `ticked(events)` fires with that tick's drained events.
## It NEVER touches `Engine.time_scale`: UI tweens stay real-time and world visuals use
## `view_delta()`.
##
## After every tick the driver refills a pooled `ViewSnapshot` (swapping `prev` / `current`),
## so every view class reads plain snapshot data — never the sim (TECH §5.4). Hotspot states
## and the path preview are refreshed at 10 Hz, and at once on events that change them.
##
## Fast-forward (×3) is honoured only while Hush is hidden, and drops to ×1 on an
## `entry_warning` for Hush's room, a `prank_fire` or a `spot_start` (GDD §3.3).
class_name SimDriver
extends Node

## After every sim tick, with that tick's events (Array of Dictionaries).
signal ticked(events: Array)
## Fast-forward request changed (the HUD's ⏩ state).
signal ff_changed(on: bool)

const TPS := 60.0
const MAX_TICKS_PER_FRAME := 8
const FF_RATE := 3.0
const SAFETY_RATE := 0.5
## Ticks between hotspot / path-preview refreshes.
const SLOW_REFRESH_TICKS := 6
## Events that refresh hotspot states immediately.
const HOTSPOT_EVENTS: PackedStringArray = ["rigged", "rig_step_done", "rig_start", "rig_pause", "pick", "rummage",
	"pick_window", "hide", "pop_out", "restock", "item_home", "reaction_end", "prank_fire", "line_done",
	"big_number_unsealed", "hush_room", "b_activity", "b_next", "fizzle"]

## The SimWorld (TECH §3.4) or any object with the same accessors (FakeWorld). Typed loosely
## as a soft hook until Stage 2 (TECH §13).
var world: RefCounted = null
## Hit-stop / slow-mo segments (real time).
var juice: JuiceClock = null
## Every command pushed, as [tick, cmd] (debug replay, TECH §6.7).
var cmd_log: Array = []
var log_commands: bool = true

var _acc := 0.0
var _ff := false
var _safety := false
var _paused := false
var _last_delta := 0.0
var _rate := 1.0
var _cmds: Array = []
var _empty: Array = []
var _snap: ViewSnapshot = ViewSnapshot.new()
var _prev: ViewSnapshot = ViewSnapshot.new()
var _hotspots: Dictionary = {}
var _hotspot_ids := PackedStringArray()
var _since_slow := 0
var _hotspots_dirty := true
var _ticks_this_frame := 0


func _init() -> void:
	name = "SimDriver"
	process_priority = -100
	juice = JuiceClock.new()
	add_child(juice)
	_snap.hotspots = _hotspots
	_prev.hotspots = _hotspots


## Attach a world (SimWorld or FakeWorld) and take the first snapshot.
func setup(w: RefCounted) -> void:
	world = w
	_acc = 0.0
	_cmds.clear()
	cmd_log.clear()
	_hotspots.clear()
	_hotspot_ids = ViewSnapshot.hotspot_ids_of(world) if world != null else PackedStringArray()
	_hotspots_dirty = true
	_take_snapshot(true)


## Queue a command for the next tick (array order preserved).
func push_cmd(cmd: Dictionary) -> void:
	_cmds.append(cmd)
	if log_commands and world != null:
		cmd_log.append([int(world.get("tick")) + 1, cmd])


## Request ×3 fast-forward (only honoured while Hush is hidden).
func set_ff(on: bool) -> void:
	if _ff == on:
		return
	_ff = on
	ff_changed.emit(on)


## The Director's safety net: ×0.5 while on.
func set_safety_slowmo(on: bool) -> void:
	_safety = on


func set_paused(on: bool) -> void:
	_paused = on
	if on and juice != null:
		juice.reset()


func is_paused() -> bool:
	return _paused


## True while ⏩ is requested AND honoured (Hush hidden).
func ff_active() -> bool:
	return _ff and _snap.hush.present and _snap.hush.state == "HIDDEN"


func ff_requested() -> bool:
	return _ff


## Current tick rate multiplier (juice × ff × safety; 0 when paused).
func rate() -> float:
	if _paused:
		return 0.0
	var r := juice.scale() if juice != null else 1.0
	if ff_active():
		r *= FF_RATE
	if _safety:
		r *= SAFETY_RATE
	return r


## 0..1 fraction toward the next tick (render interpolation).
func alpha() -> float:
	return clampf(_acc, 0.0, 1.0)


## This frame's delta × the current rate (view-time animation: follow, zooms, FX).
func view_delta() -> float:
	return _last_delta * _rate


## Real (unscaled) delta of this frame.
func real_delta() -> float:
	return _last_delta


## Ticks run during the last frame.
func ticks_last_frame() -> int:
	return _ticks_this_frame


## The latest tick's snapshot and the one before it (for interpolation).
func snapshot() -> ViewSnapshot:
	return _snap


func prev_snapshot() -> ViewSnapshot:
	return _prev


## Retry in place: world.reset(), juice cleared, snapshots retaken.
func reset() -> void:
	if world != null and world.has_method("reset"):
		world.call("reset")
	if juice != null:
		juice.reset()
	_acc = 0.0
	_cmds.clear()
	cmd_log.clear()
	_hotspots.clear()
	_hotspots_dirty = true
	set_ff(false)
	_safety = false
	_take_snapshot(true)


func _process(delta: float) -> void:
	advance(delta)


## Advance by a frame of `delta` real seconds (public so tests can drive it headless).
## Returns the number of ticks run.
func advance(delta: float) -> int:
	_last_delta = delta
	if juice != null:
		juice.advance()
	_rate = rate()
	_ticks_this_frame = 0
	if world == null:
		return 0
	_acc += delta * TPS * _rate
	var n := 0
	while _acc >= 1.0 and n < MAX_TICKS_PER_FRAME:
		_acc -= 1.0
		n += 1
		_step_once()
	if _acc >= 1.0:
		_acc -= floorf(_acc)   # drop the rest (never spiral)
	_ticks_this_frame = n
	return n


## Run exactly one tick now, regardless of rate (tests, scenario seeking).
func step_now() -> void:
	if world != null:
		_step_once()


func _step_once() -> void:
	var cmds := _cmds
	if cmds.is_empty():
		world.call("step", _empty)
	else:
		var batch := cmds.duplicate()
		_cmds.clear()
		world.call("step", batch)
	var events: Array = world.call("drain_events")
	_scan(events)
	_take_snapshot(false)
	ticked.emit(events)


func _scan(events: Array) -> void:
	for ev in events:
		var e := String((ev as Dictionary).get("e", ""))
		if HOTSPOT_EVENTS.has(e):
			_hotspots_dirty = true
		if not _ff:
			continue
		match e:
			"prank_fire", "spot_start":
				set_ff(false)
			"entry_warning":
				var room := String((ev as Dictionary).get("room", ""))
				if room == "" or room == _snap.hush.room:
					set_ff(false)


func _take_snapshot(first: bool) -> void:
	if world == null:
		return
	var t := _prev
	_prev = _snap
	_snap = t
	_snap.fill(world, null if first else _prev)
	_since_slow += 1
	if first or _hotspots_dirty or _since_slow >= SLOW_REFRESH_TICKS:
		_snap.refresh_hotspots(world, _hotspot_ids)
		_hotspots_dirty = false
	if first or _since_slow >= SLOW_REFRESH_TICKS:
		_snap.refresh_path(world)
		_since_slow = 0
	else:
		# Keep the preview across the swap without reallocating.
		_snap.path_rooms = _prev.path_rooms
		_snap.path_x = _prev.path_x
	if first:
		_prev.copy_from(_snap)
