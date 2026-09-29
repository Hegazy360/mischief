## Rng — seeded xorshift32 (port of the Booby sim generator; TECH §3.1).
##
## The ONLY randomness in the sim. v1 gameplay uses none (routines are pure clocks); it exists for
## deterministic tie-breaks (freeze pose seeds) and the Stage-3 actors.
class_name Rng
extends RefCounted

const MASK := 0xFFFFFFFF
const DEFAULT_SEED := 0x9E3779B9

var state: int = DEFAULT_SEED


func _init(seed_value: int = DEFAULT_SEED) -> void:
	state = seed_value & MASK
	if state == 0:
		state = DEFAULT_SEED


## Next unsigned 32-bit value.
func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x & MASK
	return state


## Uniform int in [lo, hi] inclusive.
func range_int(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + (next_u32() % (hi - lo + 1))


## True with probability pct/100.
func chance_pct(p: int) -> bool:
	return range_int(0, 99) < p


## Independent child stream derived deterministically from this one's state and `salt`.
func fork(salt: int) -> Rng:
	return Rng.new(StateHash.mix(StateHash.mix(StateHash.OFFSET, state), salt))


## Copy of this generator (same state).
func duplicate_rng() -> Rng:
	var r := Rng.new(1)
	r.state = state
	return r
