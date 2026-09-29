## Scoring — Applause in tenths (TECH §3.7.7, GDD §6.1).
##
## Applause = Σ gags (base × Running Gag multiplier at the accent) + Σ bits + Σ the four named bonuses
## − 5.0 per catch, never below 0. Every change emits `applause {delta, total, kind, label}`; bonuses also
## emit `bonus {kind, amount}`. Caps: MELTDOWN ≤ 2, NEAR MISS ≤ 3 per Night, COMBO once per combo.
class_name Scoring
extends RefCounted

var applause: int = 0
var near_misses_scored: int = 0
var meltdowns_scored: int = 0
## Plays per squeak bit this Night (bit id → count).
var bit_plays: Dictionary = {}


## Add (or subtract) Applause; the total never drops below 0.
func add(w: SimWorld, delta: int, kind: String, label: String) -> void:
	var before := applause
	applause = maxi(0, applause + delta)
	var d := applause - before
	if d == 0 and delta != 0 and kind != "catch":
		return
	w.emit(SimEvents.APPLAUSE, {"delta": d, "total": applause, "kind": kind, "label": label})
	w.goals.dirty = true


## A prank's gag at its accent.
func gag(w: SimWorld, base: int, link: int, label: String) -> void:
	if base <= 0:
		return
	add(w, Fx.div(base * SimConst.mult_for_link(link), 100), "gag", label)


## A squeak bit: +2 / +1 / 0 per bit per Night. Returns the tenths scored.
func squeak_bit(w: SimWorld, bit: String) -> int:
	var n: int = bit_plays.get(bit, 0)
	bit_plays[bit] = n + 1
	var s: int = SimConst.BIT_SCORES[n] if n < SimConst.BIT_SCORES.size() else 0
	if s > 0:
		add(w, s, "bit", bit)
	return s


## A named bonus.
func bonus(w: SimWorld, kind: String, amount: int) -> void:
	w.emit(SimEvents.BONUS, {"kind": kind, "amount": amount})
	add(w, amount, "bonus", kind)


## NEAR MISS! +2 (max 3 per Night).
func near_miss(w: SimWorld) -> void:
	if near_misses_scored < SimConst.BONUS_NEAR_MISS_MAX:
		near_misses_scored += 1
		bonus(w, "near_miss", SimConst.BONUS_NEAR_MISS)


## MELTDOWN! +8 (max 2 per Night).
func meltdown(w: SimWorld) -> void:
	if meltdowns_scored < SimConst.BONUS_MELTDOWN_MAX:
		meltdowns_scored += 1
		bonus(w, "meltdown", SimConst.BONUS_MELTDOWN)


## COMBO! +4 (the caller enforces once per combo).
func combo(w: SimWorld) -> void:
	bonus(w, "combo", SimConst.BONUS_COMBO)


## Deep copy.
func copy() -> Scoring:
	var o := Scoring.new()
	o.applause = applause
	o.near_misses_scored = near_misses_scored
	o.meltdowns_scored = meltdowns_scored
	o.bit_plays = bit_plays.duplicate()
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix(h, applause)
	h = StateHash.mix(h, near_misses_scored)
	h = StateHash.mix(h, meltdowns_scored)
	for k in ContentUtil.sorted_keys(bit_plays):
		h = StateHash.mix_str(h, k)
		h = StateHash.mix(h, int(bit_plays[k]))
	return h
