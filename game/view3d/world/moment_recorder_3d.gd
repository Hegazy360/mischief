## MomentRecorder3D — the 3D view's memory of the last ≥ 6 s (the 2D MomentRecorder's contract; brief r3d-view3d
## §4.6) for the Busted Cam and `r3d-night`'s Gag Reel: a fixed ring of per-frame buffers of what was drawn (after the
## characters applied — hit-stop frames included) for **both** actors (room, world position incl. lane depth, facing,
## cheat, base clip + frame, overlay clip + frame, residue looks, tint tier, shown, state) plus the props (every
## hotspot's state code) and the decor pieces' visibility. `keep(from_tick, to_tick, tag, applause)` copies a window
## out of the ring into one of 8 pooled Moments (evicting the lowest applause); a window that ends in the future stays
## open and fills as ticks arrive. Allocation-free after `setup()`. Re-stage a frame with
## `WorldView3D.show_moment_frame(f)` (CharacterView3D.show_world per actor).
class_name MomentRecorder3D
extends RefCounted

## Ring length in frames (≥ 6 s at 60 fps).
const CAP := 400
const POOL := 8
## Prop state → code (Frame.props).
const STATE_CODES: PackedStringArray = ["idle", "armed", "spent", "occupied"]


class ActorFrame:
	var room: String = ""
	var pos: Vector3 = Vector3.ZERO
	var facing: int = 1
	var cheat: float = 35.0
	var clip: String = ""
	var frame: float = 0.0
	var ov_clip: String = ""
	var ov_frame: float = 0.0
	var looks: PackedStringArray = PackedStringArray()
	var tint: int = 0
	var shown: bool = true
	var state: String = ""

	func copy_from(o: ActorFrame) -> void:
		room = o.room
		pos = o.pos
		facing = o.facing
		cheat = o.cheat
		clip = o.clip
		frame = o.frame
		ov_clip = o.ov_clip
		ov_frame = o.ov_frame
		looks = o.looks
		tint = o.tint
		shown = o.shown
		state = o.state


class Frame:
	var tick: int = -1
	var hush: ActorFrame = ActorFrame.new()
	var bellows: ActorFrame = ActorFrame.new()
	## Per hotspot (MomentRecorder3D.hotspot_ids order): a STATE_CODES index.
	var props: PackedByteArray = PackedByteArray()
	## Per decor piece (MomentRecorder3D.decor_ids order): 1 visible.
	var decor: PackedByteArray = PackedByteArray()

	func copy_from(o: Frame) -> void:
		tick = o.tick
		hush.copy_from(o.hush)
		bellows.copy_from(o.bellows)
		for i in mini(props.size(), o.props.size()):
			props[i] = o.props[i]
		for i2 in mini(decor.size(), o.decor.size()):
			decor[i2] = o.decor[i2]


class Moment:
	var id: int = 0
	var used: bool = false
	var open: bool = false
	var tag: String = ""
	var from_tick: int = 0
	var to_tick: int = 0
	var applause: int = 0
	var n: int = 0
	var frames: Array[Frame] = []

	func count() -> int:
		return n

	func frame(i: int) -> Frame:
		return frames[clampi(i, 0, maxi(0, n - 1))]

	func frame_at_tick(t: int) -> Frame:
		for i in n:
			if frames[i].tick >= t:
				return frames[i]
		return frame(n - 1)


var hotspot_ids: PackedStringArray = PackedStringArray()
var decor_ids: PackedStringArray = PackedStringArray()
var _wv: WorldView3D = null
var _ring: Array[Frame] = []
var _head := 0
var _count := 0
var _pool: Array[Moment] = []


## Preallocate the ring and the pool for `wv`'s set (call once after the set is built).
func setup(wv: WorldView3D) -> void:
	_wv = wv
	hotspot_ids.clear()
	decor_ids.clear()
	if wv != null and wv.layout != null:
		for hs in wv.layout.hotspots:
			hotspot_ids.append(hs.id)
	if wv != null and wv.house3d.get("decor", null) is Dictionary:
		for id in (wv.house3d["decor"] as Dictionary):
			decor_ids.append(String(id))
	_ring.clear()
	for i in CAP:
		_ring.append(_new_frame())
	_pool.clear()
	for k in POOL:
		var m := Moment.new()
		m.id = k
		for i2 in CAP:
			m.frames.append(_new_frame())
		_pool.append(m)
	_head = 0
	_count = 0


func _new_frame() -> Frame:
	var f := Frame.new()
	f.props.resize(hotspot_ids.size())
	f.decor.resize(decor_ids.size())
	return f


## Frames recorded (≤ CAP).
func count() -> int:
	return _count


## The i-th oldest frame of the ring.
func ring_frame(i: int) -> Frame:
	return _ring[(_head - _count + clampi(i, 0, maxi(0, _count - 1)) + CAP * 2) % CAP]


## The latest recorded tick (−1 none).
func last_tick() -> int:
	return ring_frame(_count - 1).tick if _count > 0 else -1


## Record this frame (after the sim stepped and the views applied).
func record(snap: ViewSnapshot) -> void:
	if _ring.is_empty():
		return
	var f := _ring[_head]
	f.tick = snap.tick
	if _wv != null:
		_fill_actor(f.hush, snap.hush, _wv.hush_view)
		_fill_actor(f.bellows, snap.bellows, _wv.bellows_view)
		for i in hotspot_ids.size():
			var p := _wv.prop(hotspot_ids[i])
			var code := 0
			if p != null:
				code = MomentRecorder3D.state_code(str(p.get_meta("mnd_state", &"idle")))
				if bool(p.get_meta("mnd_occ", false)):
					code = 3
			f.props[i] = code
		var has_decor := _wv.set3d != null and _wv.set3d.has_method("decor")
		for j in decor_ids.size():
			var d: Variant = _wv.set3d.call("decor", decor_ids[j]) if has_decor else null
			f.decor[j] = 1 if (d is Node3D and (d as Node3D).visible) else 0
	_head = (_head + 1) % CAP
	_count = mini(_count + 1, CAP)
	for m in _pool:
		if m.used and m.open:
			_append(m, f)


static func state_code(state: String) -> int:
	var i := STATE_CODES.find(state)
	return i if i >= 0 else 0


func _fill_actor(af: ActorFrame, a: ViewSnapshot.Actor, cv: CharacterView3D) -> void:
	af.room = a.room
	af.state = a.state
	if cv == null:
		af.pos = View3DConst.px_to_world(Vector2(a.x, a.y))
		af.facing = a.facing
		return
	af.pos = cv.global_position if cv.is_inside_tree() else cv.position
	af.facing = cv.get_facing()
	af.cheat = cv.cheat_deg()
	af.clip = cv.current_clip()
	af.frame = cv.current_frame()
	af.ov_clip = cv.overlay_clip()
	af.ov_frame = cv.overlay_frame()
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


## Keep the window [from_tick, to_tick] as a Moment (tag e.g. "gag:achoo_ria", "busted"); returns its id (0–7): a
## free slot, else the one with the lowest applause.
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


## A kept Moment by id (null when out of range or free).
func moment(id: int) -> Moment:
	if id < 0 or id >= _pool.size() or not _pool[id].used:
		return null
	return _pool[id]


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
