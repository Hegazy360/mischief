## StateHash — FNV-1a (32-bit) over canonical integer state (port of the Booby helper; TECH §3.1, §3.9).
class_name StateHash
extends RefCounted

const OFFSET := 0x811C9DC5
const PRIME := 0x01000193
const MASK := 0xFFFFFFFF


## Mix a 64-bit int (both 32-bit halves, little-endian bytes) into hash `h`.
static func mix(h: int, v: int) -> int:
	var lo := v & MASK
	var hi := (v >> 32) & MASK
	h = ((h ^ (lo & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((lo >> 8) & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((lo >> 16) & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((lo >> 24) & 0xFF)) * PRIME) & MASK
	h = ((h ^ (hi & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((hi >> 8) & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((hi >> 16) & 0xFF)) * PRIME) & MASK
	h = ((h ^ ((hi >> 24) & 0xFF)) * PRIME) & MASK
	return h


## Mix a bool.
static func mix_bool(h: int, b: bool) -> int:
	return mix(h, 1 if b else 0)


## Mix a string (UTF-8 bytes, then its length).
static func mix_str(h: int, s: String) -> int:
	for byte in s.to_utf8_buffer():
		h = ((h ^ byte) * PRIME) & MASK
	return mix(h, s.length())


## Mix every element of a PackedInt32Array (then its size).
static func mix_arr(h: int, a: PackedInt32Array) -> int:
	for v in a:
		h = mix(h, v)
	return mix(h, a.size())


## Hash of a list of ints.
static func of_ints(values: Array) -> int:
	var h := OFFSET
	for v in values:
		h = mix(h, int(v))
	return h
