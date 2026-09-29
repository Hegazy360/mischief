## NavPath — a walker following legs {room, x, kind: WALK|DOOR|STAIRS|PAUSE, ticks} (TECH §3.3).
##
## The path owns the walker's position while it is followed: `advance()` moves `x` by `speed`
## sub-px per tick (no carry-over between legs: a WALK leg of length d takes exactly ceil(d / speed)
## ticks) or counts down a timed leg. `room` is the room of the current leg: it changes at the START
## of a leg (crossing a doorway, starting a door or the stairs), which is what `eta_to_room()` measures.
## A STAIRS leg also puts `x` at the far end when it starts (the ends' x differ; the climb is timed).
## No allocations per tick; paths are rebuilt only for a new target.
class_name NavPath
extends RefCounted

const WALK := 0
const DOOR := 1
const STAIRS := 2
const PAUSE := 3
const KIND_NAMES: Array[String] = ["WALK", "DOOR", "STAIRS", "PAUSE"]

## PAUSE aux codes.
const AUX_LOOK_BACK := 1
const AUX_DOORWAY_PAUSE := 2
const AUX_BUMP := 3

## advance() flags.
const F_ROOM := 1
const F_LEG := 2
const F_DONE := 4
const F_PORTAL := 8
const F_STAIRS := 16

var rooms: PackedInt32Array = PackedInt32Array()
var xs: PackedInt32Array = PackedInt32Array()
var kinds: PackedInt32Array = PackedInt32Array()
var ticks: PackedInt32Array = PackedInt32Array()
## WALK after a doorway / DOOR / STAIRS: the link idx crossed at the leg start (-1 none);
## PAUSE: an AUX_* code.
var aux: PackedInt32Array = PackedInt32Array()

var cursor: int = 0
var leg_t: int = 0
var x: int = 0
var room: int = -1
var speed: int = 1
var facing: int = 1
## False when no route exists.
var ok: bool = true
## Serial of the path (per owner), used to key entry warnings.
var serial: int = 0


## Number of legs.
func size() -> int:
	return kinds.size()


## Append a leg (building only).
func add_leg(r: int, tx: int, kind: int, t: int, a: int = -1) -> void:
	rooms.append(r)
	xs.append(tx)
	kinds.append(kind)
	ticks.append(t)
	aux.append(a)


## True once every leg is complete.
func is_done() -> bool:
	return cursor >= kinds.size()


## Kind of the current leg (-1 when done).
func current_kind() -> int:
	return kinds[cursor] if cursor < kinds.size() else -1


## Final room / x of the path.
func final_room() -> int:
	return rooms[rooms.size() - 1] if rooms.size() > 0 else room


func final_x() -> int:
	return xs[xs.size() - 1] if xs.size() > 0 else x


## Advance one tick. Returns F_* flags.
func advance() -> int:
	var flags := 0
	var n := kinds.size()
	var guard := 0
	while cursor < n and guard < 16:
		guard += 1
		var k := kinds[cursor]
		if k == WALK:
			var tx := xs[cursor]
			if x == tx:
				flags |= _next_leg()
				continue
			var dx := tx - x
			facing = 1 if dx > 0 else -1
			if (dx if dx > 0 else -dx) <= speed:
				x = tx
				flags |= _next_leg()
			else:
				x += speed * facing
			return flags
		leg_t += 1
		if leg_t >= ticks[cursor]:
			x = xs[cursor]
			flags |= _next_leg()
		return flags
	if cursor >= n:
		flags |= F_DONE
	return flags


func _next_leg() -> int:
	var flags := F_LEG
	cursor += 1
	leg_t = 0
	if cursor >= kinds.size():
		return flags | F_DONE
	var nr := rooms[cursor]
	if nr != room:
		room = nr
		flags |= F_ROOM
	var k := kinds[cursor]
	if k == STAIRS:
		# the climb happens "in" the arrival end: room and x are the far end's for the whole leg
		x = xs[cursor]
		flags |= F_STAIRS | F_PORTAL
	elif k == DOOR or (k == WALK and aux[cursor] >= 0):
		flags |= F_PORTAL
	return flags


## Ticks until the walker enters `target` (0 if already in it, -1 if the path never does).
## Uses the current `speed` for the remaining WALK legs; a lower bound on the real arrival
## (later pauses and look-backs only delay it).
func eta_to_room(target: int) -> int:
	if room == target:
		return 0
	var t := 0
	var cx := x
	var n := kinds.size()
	var sp := speed if speed > 0 else 1
	for i in range(cursor, n):
		if rooms[i] == target:
			return t
		if kinds[i] == WALK:
			var d := xs[i] - cx
			if d < 0:
				d = -d
			t += Fx.div_ceil(d, sp)
		else:
			t += maxi(0, ticks[i] - (leg_t if i == cursor else 0))
		cx = xs[i]
	return -1


## Index of the first leg (≥ cursor) whose room is `target`, -1 if none.
func entry_leg(target: int) -> int:
	for i in range(cursor, kinds.size()):
		if rooms[i] == target:
			return i
	return -1


## Ticks until the path is complete.
func remaining_ticks() -> int:
	var t := 0
	var cx := x
	var sp := speed if speed > 0 else 1
	for i in range(cursor, kinds.size()):
		if kinds[i] == WALK:
			var d := xs[i] - cx
			if d < 0:
				d = -d
			t += Fx.div_ceil(d, sp)
		else:
			t += maxi(0, ticks[i] - (leg_t if i == cursor else 0))
		cx = xs[i]
	return t


## Insert a PAUSE leg before leg `at` (at ≥ cursor). The pause stands at the end of the previous leg,
## in that leg's room.
func insert_pause(at: int, t: int, a: int) -> void:
	if t <= 0:
		return
	at = clampi(at, cursor, kinds.size())
	var r := room if at == cursor else rooms[at - 1]
	var px := x if at == cursor else xs[at - 1]
	rooms.insert(at, r)
	xs.insert(at, px)
	kinds.insert(at, PAUSE)
	ticks.insert(at, t)
	aux.insert(at, a)
	if at == cursor:
		leg_t = 0


## Aux code of the current leg when it is a PAUSE (0 otherwise).
func current_pause_aux() -> int:
	if cursor < kinds.size() and kinds[cursor] == PAUSE:
		return aux[cursor]
	return 0


## Deep copy.
func duplicate_path() -> NavPath:
	var p := NavPath.new()
	p.rooms = rooms.duplicate()
	p.xs = xs.duplicate()
	p.kinds = kinds.duplicate()
	p.ticks = ticks.duplicate()
	p.aux = aux.duplicate()
	p.cursor = cursor
	p.leg_t = leg_t
	p.x = x
	p.room = room
	p.speed = speed
	p.facing = facing
	p.ok = ok
	p.serial = serial
	return p


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix_arr(h, rooms)
	h = StateHash.mix_arr(h, xs)
	h = StateHash.mix_arr(h, kinds)
	h = StateHash.mix_arr(h, ticks)
	h = StateHash.mix_arr(h, aux)
	h = StateHash.mix(h, cursor)
	h = StateHash.mix(h, leg_t)
	h = StateHash.mix(h, x)
	h = StateHash.mix(h, room)
	h = StateHash.mix(h, speed)
	h = StateHash.mix(h, facing)
	return StateHash.mix(h, serial)


## Debug text.
func describe() -> String:
	var parts := PackedStringArray()
	for i in kinds.size():
		parts.append("%s(r%d,x%d,t%d)" % [KIND_NAMES[kinds[i]], rooms[i], Fx.to_px(xs[i]), ticks[i]])
	return "[%s] @%d" % [", ".join(parts), cursor]
