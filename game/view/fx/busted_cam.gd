## BustedCam — the view-side ring buffer behind the Busted Cam (GDD §4.6, TECH §5.7): both
## characters' (room, x, facing, clip, frame, state) for the last 120 ticks, plus a frozen
## copy of the moment he saw her (45 ticks before `spotted` + 15 after), so a catch after a
## long chase still replays the "?" window. `replay_frames()` picks the 60 ticks to re-stage;
## WorldView poses the characters from them while FxLayer draws the red vignette, the
## split-frame border, "SPOTTED!" and the dotted sight line. Allocation-free after setup.
class_name BustedCam
extends RefCounted

const CAP := 120
const REPLAY := 60
const BEFORE := 45
const AFTER := 15


class Frame:
	var tick: int = -1
	var h_pos: Vector2 = Vector2.ZERO
	var h_facing: int = 1
	var h_clip: String = ""
	var h_frame: float = 0.0
	var h_state: String = ""
	var h_room: String = ""
	var b_pos: Vector2 = Vector2.ZERO
	var b_facing: int = 1
	var b_clip: String = ""
	var b_frame: float = 0.0
	var b_state: String = ""
	var b_room: String = ""

	func copy_from(o: Frame) -> void:
		tick = o.tick
		h_pos = o.h_pos
		h_facing = o.h_facing
		h_clip = o.h_clip
		h_frame = o.h_frame
		h_state = o.h_state
		h_room = o.h_room
		b_pos = o.b_pos
		b_facing = o.b_facing
		b_clip = o.b_clip
		b_frame = o.b_frame
		b_state = o.b_state
		b_room = o.b_room


var _ring: Array[Frame] = []
var _head := 0
var _count := 0
var _spot: Array[Frame] = []
var _spot_n := 0
var _spot_tick := -1
var _spot_capturing := false
var _replay: Array[Frame] = []
var _replay_n := 0


func _init() -> void:
	for i in CAP:
		_ring.append(Frame.new())
	for i in REPLAY:
		_spot.append(Frame.new())
		_replay.append(Frame.new())


## Record one tick (called after every sim tick).
func record(tick: int, h: ViewSnapshot.Actor, h_clip: String, h_frame: float,
		b: ViewSnapshot.Actor, b_clip: String, b_frame: float) -> void:
	var f := _ring[_head]
	f.tick = tick
	f.h_pos = Vector2(h.x, h.y)
	f.h_facing = h.facing
	f.h_clip = h_clip
	f.h_frame = h_frame
	f.h_state = h.state
	f.h_room = h.room
	f.b_pos = Vector2(b.x, b.y)
	f.b_facing = b.facing
	f.b_clip = b_clip
	f.b_frame = b_frame
	f.b_state = b.state
	f.b_room = b.room
	_head = (_head + 1) % CAP
	_count = mini(_count + 1, CAP)
	if _spot_capturing:
		if _spot_n < REPLAY:
			_spot[_spot_n].copy_from(f)
			_spot_n += 1
		if tick >= _spot_tick + AFTER or _spot_n >= REPLAY:
			_spot_capturing = false


## `spotted` happened at `tick`: freeze the 45 ticks before it and keep capturing 15 after.
func on_spotted(tick: int) -> void:
	_spot_tick = tick
	_spot_n = 0
	var start := maxi(0, _count - BEFORE)
	for i in range(start, _count):
		var f := _frame_at(i)
		if f.tick > tick:
			break
		_spot[_spot_n].copy_from(f)
		_spot_n += 1
	_spot_capturing = true


## Frames recorded so far (≤ CAP).
func count() -> int:
	return _count


## i-th oldest recorded frame (0 = oldest).
func _frame_at(i: int) -> Frame:
	var idx := (_head - _count + i + CAP * 2) % CAP
	return _ring[idx]


## Fill the replay window for a catch whose "?" became "!" at `spotted_tick` (−1 = unknown):
## the frozen spot capture when it matches, else [spotted − 45, spotted + 15] from the ring,
## else the last 60 ticks. Returns the number of frames (read them with replay_frame(i)).
func replay_frames(spotted_tick: int) -> int:
	_replay_n = 0
	if spotted_tick >= 0 and spotted_tick == _spot_tick and _spot_n > 0:
		for i in _spot_n:
			_replay[_replay_n].copy_from(_spot[i])
			_replay_n += 1
		return _replay_n
	var lo := spotted_tick - BEFORE
	var hi := spotted_tick + AFTER
	if spotted_tick >= 0:
		for i in _count:
			var f := _frame_at(i)
			if f.tick >= lo and f.tick <= hi and _replay_n < REPLAY:
				_replay[_replay_n].copy_from(f)
				_replay_n += 1
	if _replay_n < 10:
		_replay_n = 0
		var start := maxi(0, _count - REPLAY)
		for i in range(start, _count):
			_replay[_replay_n].copy_from(_frame_at(i))
			_replay_n += 1
	return _replay_n


func replay_frame(i: int) -> Frame:
	return _replay[clampi(i, 0, maxi(0, _replay_n - 1))]


func replay_count() -> int:
	return _replay_n


func clear() -> void:
	_head = 0
	_count = 0
	_spot_n = 0
	_spot_tick = -1
	_spot_capturing = false
	_replay_n = 0
