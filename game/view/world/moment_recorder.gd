## MomentRecorder — the view's memory of the last ≥ 6 s (s2-view brief §4.2.3) for the Busted Cam
## and `s2-night`'s Gag Reel: a fixed ring of per-frame buffers (what was drawn, after the
## characters applied — hit-stop frames included, ⏩ frames skip ticks) for **both** actors (room, x, y,
## facing, base clip + frame, overlay clip + frame, fallback face, residue looks, tint tier,
## shown) plus the props (every hotspot's visual state code, every decor item's visibility).
## `keep(from_tick, to_tick, tag, applause)` copies a window out of the ring into one of 8
## pooled Moments (evicting the lowest applause); a window that ends in the future stays open and
## keeps filling as ticks arrive. Allocation-free after `setup()` (strings are shared, arrays are
## preallocated). Re-stage a Moment with `CharacterView.show_explicit()` per frame and
## `RoomView.build_backdrop()` for the set.
class_name MomentRecorder
extends RefCounted

## Ring length in frames (≥ 6 s at 60 fps).
const CAP := 400
const POOL := 8
## PropView state → code (MomentRecorder.Frame.props).
const STATE_CODES: PackedStringArray = ["idle", "open", "rigged", "spent", "occupied"]


## One actor at one tick.
class ActorFrame:
	var room: String = ""
	var pos: Vector2 = Vector2.ZERO
	var facing: int = 1
	var clip: String = ""
	var frame: float = 0.0
	var ov_clip: String = ""
	var ov_frame: float = 0.0
	var face: String = ""
	var looks: PackedStringArray = PackedStringArray()
	var tint: int = 0
	var shown: bool = true
	var state: String = ""

	func copy_from(o: ActorFrame) -> void:
		room = o.room
		pos = o.pos
		facing = o.facing
		clip = o.clip
		frame = o.frame
		ov_clip = o.ov_clip
		ov_frame = o.ov_frame
		face = o.face
		looks = o.looks
		tint = o.tint
		shown = o.shown
		state = o.state


## One recorded tick.
class Frame:
	var tick: int = -1
	var hush: ActorFrame = ActorFrame.new()
	var bellows: ActorFrame = ActorFrame.new()
	## Per hotspot (MomentRecorder.hotspot_ids order): STATE_CODES index (5 = rigged_<prank>).
	var props: PackedByteArray = PackedByteArray()
	## Per decor item (WorldView.decor.items order): 1 visible.
	var decor: PackedByteArray = PackedByteArray()

	func copy_from(o: Frame) -> void:
		tick = o.tick
		hush.copy_from(o.hush)
		bellows.copy_from(o.bellows)
		for i in props.size():
			props[i] = o.props[i] if i < o.props.size() else 0
		for j in decor.size():
			decor[j] = o.decor[j] if j < o.decor.size() else 0


## A kept window.
class Moment:
	var id: int = -1
	var tag: String = ""
	var from_tick: int = 0
	var to_tick: int = 0
	var applause: int = 0
	## Still filling (its window ends after the latest recorded tick).
	var open: bool = false
	var used: bool = false
	var frames: Array[Frame] = []
	var n: int = 0

	## Frames kept so far.
	func count() -> int:
		return n

	## The i-th frame (clamped).
	func frame(i: int) -> Frame:
		return frames[clampi(i, 0, maxi(0, n - 1))]

	## The first kept frame at or after tick `t` (the last one when none).
	func frame_at_tick(t: int) -> Frame:
		for i in n:
			if frames[i].tick >= t:
				return frames[i]
		return frame(n - 1)


var hotspot_ids: PackedStringArray = PackedStringArray()
var _wv: WorldView = null
var _ring: Array[Frame] = []
var _head := 0
var _count := 0
var _pool: Array[Moment] = []


## Preallocate the ring and the pool for `wv`'s house (call once after the set is built).
func setup(wv: WorldView) -> void:
	_wv = wv
	hotspot_ids.clear()
	if wv != null and wv.layout != null:
		for hs in wv.layout.hotspots:
			hotspot_ids.append(hs.id)
	var nd := wv.decor.items.size() if wv != null else 0
	_ring.clear()
	for i in CAP:
		_ring.append(_new_frame(nd))
	_pool.clear()
	for k in POOL:
		var m := Moment.new()
		m.id = k
		for i2 in CAP:
			m.frames.append(_new_frame(nd))
		_pool.append(m)
	_head = 0
	_count = 0


func _new_frame(nd: int) -> Frame:
	var f := Frame.new()
	f.props.resize(hotspot_ids.size())
	f.decor.resize(nd)
	return f


## Ticks recorded (≤ CAP).
func count() -> int:
	return _count


## The i-th oldest frame of the ring.
func ring_frame(i: int) -> Frame:
	return _ring[(_head - _count + clampi(i, 0, maxi(0, _count - 1)) + CAP * 2) % CAP]


## The latest recorded tick (−1 none).
func last_tick() -> int:
	return ring_frame(_count - 1).tick if _count > 0 else -1


## Record the current tick (after the sim stepped and the views applied).
func record(snap: ViewSnapshot) -> void:
	if _ring.is_empty():
		return
	var f := _ring[_head]
	f.tick = snap.tick
	if _wv != null:
		_fill_actor(f.hush, snap.hush, _wv.hush_view)
		_fill_actor(f.bellows, snap.bellows, _wv.bellows_view)
		for i in hotspot_ids.size():
			var pv: PropView = _wv.props.get(hotspot_ids[i], null)
			f.props[i] = MomentRecorder.state_code(pv.state) if pv != null else 0
		_wv.decor.snapshot_into(f.decor)
	_head = (_head + 1) % CAP
	_count = mini(_count + 1, CAP)
	for m in _pool:
		if m.used and m.open:
			_append(m, f)


static func state_code(state: String) -> int:
	var i := STATE_CODES.find(state)
	if i >= 0:
		return i
	return 5 if state.begins_with("rigged_") else 0


func _fill_actor(af: ActorFrame, a: ViewSnapshot.Actor, cv: CharacterView) -> void:
	af.room = a.room
	af.state = a.state
	if cv == null:
		af.pos = Vector2(a.x, a.y)
		af.facing = a.facing
		return
	af.pos = cv.global_position
	af.facing = cv.get_facing()
	af.clip = cv.current_clip()
	af.frame = cv.current_frame()
	af.ov_clip = cv.overlay_clip()
	af.ov_frame = cv.overlay_frame()
	af.face = cv.fallback_face()
	af.looks = cv.looks()
	af.tint = clampi(a.tier, 0, 3)
	af.shown = cv.visible and not (a.state == "HIDDEN" or cv.pick().hidden)


func _append(m: Moment, f: Frame) -> void:
	if f.tick < m.from_tick:
		return
	if f.tick > m.to_tick or m.n >= CAP:
		m.open = false
		return
	m.frames[m.n].copy_from(f)
	m.n += 1
	if f.tick >= m.to_tick:
		m.open = false


## Keep the window [from_tick, to_tick] as a Moment (tag e.g. "gag:achoo_ria", "busted").
## Returns its id (0–7): a free slot, else the one with the lowest applause. A window reaching
## past the latest tick stays open and fills as ticks arrive.
func keep(from_tick: int, to_tick: int, tag: String, applause: int = 0) -> int:
	if _pool.is_empty():
		return -1
	var slot: Moment = null
	for m in _pool:
		if not m.used:
			slot = m
			break
	if slot == null:
		slot = _pool[0]
		for m2 in _pool:
			if m2.applause < slot.applause:
				slot = m2
	slot.used = true
	slot.tag = tag
	slot.from_tick = from_tick
	slot.to_tick = maxi(from_tick, to_tick)
	slot.applause = applause
	slot.n = 0
	slot.open = true
	for i in _count:
		var f := ring_frame(i)
		if f.tick >= from_tick and f.tick <= slot.to_tick:
			_append(slot, f)
	if last_tick() >= slot.to_tick:
		slot.open = false
	return slot.id


## A kept Moment by id (null when the id is out of range or the slot is free).
func moment(id: int) -> Moment:
	if id < 0 or id >= _pool.size() or not _pool[id].used:
		return null
	return _pool[id]


## Moments kept (used slots).
func kept() -> int:
	var n := 0
	for m in _pool:
		if m.used:
			n += 1
	return n


## Forget the ring and every Moment (retry).
func clear() -> void:
	_head = 0
	_count = 0
	for m in _pool:
		m.used = false
		m.n = 0
		m.open = false
