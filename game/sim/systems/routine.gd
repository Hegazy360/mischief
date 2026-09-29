## Routine — the loop index, the loop count and the detour queue (TECH §3.7.1, GDD §4.1).
##
## Detours are stored flat (stride 5) so clones copy one packed array:
##   fix-up  [D_FIXUP, station idx, residue idx, 0, 0]
##   curious [D_CURIOUS, room idx, x_sub, why (WHY_*), look ticks]
## Interruptions never reorder or skip the loop: detours run before the next loop activity.
class_name Routine
extends RefCounted

const D_FIXUP := 0
const D_CURIOUS := 1
const STRIDE := 5
const WHY_LURE := 0
const WHY_NOISE := 1
const WHY_NEAR_MISS := 2
const WHY_NAMES: Array[String] = ["lure", "noise", "near_miss"]

## Index of the current or upcoming loop activity.
var loop_index: int = 0
## Completed loops.
var loop_count: int = 0
var dq: PackedInt32Array = PackedInt32Array()


## Queued detours.
func dq_size() -> int:
	return Fx.div(dq.size(), STRIDE)


## Detour i as [kind, a, b, c, d].
func peek(i: int) -> PackedInt32Array:
	return dq.slice(i * STRIDE, i * STRIDE + STRIDE)


## Remove and return the first detour.
func pop_front() -> PackedInt32Array:
	var d := peek(0)
	dq = dq.slice(STRIDE)
	return d


## Insert a detour at the front.
func push_front(kind: int, a: int, b: int, c: int, d: int) -> void:
	var n := PackedInt32Array([kind, a, b, c, d])
	n.append_array(dq)
	dq = n


## Append a detour.
func push_back(kind: int, a: int, b: int, c: int, d: int) -> void:
	dq.append_array(PackedInt32Array([kind, a, b, c, d]))


## Drop queued fix-ups for a residue (it was cleared another way).
func remove_fixups_for(residue_i: int) -> void:
	var out := PackedInt32Array()
	for i in dq_size():
		var base := i * STRIDE
		if dq[base] == D_FIXUP and dq[base + 2] == residue_i:
			continue
		out.append_array(dq.slice(base, base + STRIDE))
	dq = out


## True when a fix-up for this residue is queued.
func has_fixup_for(residue_i: int) -> bool:
	for i in dq_size():
		if dq[i * STRIDE] == D_FIXUP and dq[i * STRIDE + 2] == residue_i:
			return true
	return false


## Deep copy.
func copy() -> Routine:
	var o := Routine.new()
	o.loop_index = loop_index
	o.loop_count = loop_count
	o.dq = dq.duplicate()
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix(h, loop_index)
	h = StateHash.mix(h, loop_count)
	return StateHash.mix_arr(h, dq)
