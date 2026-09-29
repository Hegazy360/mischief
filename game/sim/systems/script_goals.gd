## ScriptGoals — Script lines, the Big Number, all lines, stars, candles (TECH §3.7.7, GDD §6.2).
##
## Line kinds: prank (landed), double_act (A knocked on into B and B landed), combo (formed), meltdown
## {count}, chase_trip (a STEP prank fired mid-chase; `prank` optional), chain {link} (Running Gag link
## reached). Stage-3 kinds (panto, witness, herd, prank_witnessed, combo_witnessed) are never done yet.
## ★ = every required line (not the Big Number); ★★ = every line; ★★★ = Applause ≥ 100 at the curtain.
## The Big Number unseals when ★ is reached; a Big Number achieved while sealed counts at the unseal.
## The Prologue (act 0) awards no stars.
class_name ScriptGoals
extends RefCounted

var done: PackedByteArray = PackedByteArray()
var candle_hint: PackedByteArray = PackedByteArray()
var candle: PackedByteArray = PackedByteArray()
var bn_unsealed: bool = false
var all_done: bool = false
var star1: bool = false
var star2: bool = false
var star3: bool = false
var max_link: int = 0
var dirty: bool = true


func setup(w: SimWorld) -> void:
	var n := w.episode.script_lines.size()
	done.resize(n)
	candle_hint.resize(n)
	candle.resize(n)
	for i in n:
		done[i] = 0
		candle_hint[i] = 0
		candle[i] = 0
	bn_unsealed = w.ctx.bn_line < 0
	dirty = true


## Record the highest Running Gag link reached.
func note_link(n: int) -> void:
	if n > max_link:
		max_link = n
	dirty = true


## A step-3 hint was used on a line (candle if it is solved afterwards).
func hint_used(w: SimWorld, line: String, step: int) -> void:
	var l := w.episode.line(line)
	if l == null:
		w.emit(SimEvents.CMD_REJECTED, {"c": SimCmd.HINT_USED, "why": "unknown_line"})
		return
	if step >= 3 and done[l.idx] == 0:
		candle_hint[l.idx] = 1


## Step 8 of the tick.
func update(w: SimWorld) -> void:
	if not dirty:
		return
	dirty = false
	var lines := w.episode.script_lines
	for l in lines:
		if done[l.idx] == 1 or (l.big_number and not bn_unsealed):
			continue
		if _line_done(w, l):
			done[l.idx] = 1
			if candle_hint[l.idx] == 1:
				candle[l.idx] = 1
			w.emit(SimEvents.LINE_DONE, {"line": l.id})
	var req_done := true
	for l in lines:
		if l.req and not l.big_number and done[l.idx] == 0:
			req_done = false
	if req_done and not bn_unsealed:
		bn_unsealed = true
		w.emit(SimEvents.BIG_NUMBER_UNSEALED)
		w.pranks.unseal_bn(w)
		var bl := lines[w.ctx.bn_line]
		if done[bl.idx] == 0 and _line_done(w, bl):
			done[bl.idx] = 1
			w.emit(SimEvents.LINE_DONE, {"line": bl.id})
	var every := true
	for l in lines:
		if done[l.idx] == 0:
			every = false
	if every and not all_done and lines.size() > 0:
		all_done = true
		w.emit(SimEvents.ALL_LINES_DONE)
	if w.ctx.no_stars:
		return
	if req_done and not star1:
		star1 = true
		w.emit(SimEvents.STAR, {"n": 1})
	if every and lines.size() > 0 and not star2:
		star2 = true
		w.emit(SimEvents.STAR, {"n": 2})
	var s3 := w.scoring.applause >= SimConst.STAR3_TENTHS
	if s3 and not star3:
		w.emit(SimEvents.STAR, {"n": 3})
	star3 = s3


func _line_done(w: SimWorld, l: LineDef) -> bool:
	match l.kind:
		LineDef.K_PRANK:
			return w.prank_state(l.prank) == Pranks.LANDED
		LineDef.K_DOUBLE_ACT:
			var da: DoubleActDef = w.db.double_acts.get(l.double_act, null)
			return da != null and w.pranks.da_done[da.idx] == 1
		LineDef.K_COMBO:
			return w.residue.combo_formed(w, l.combo)
		LineDef.K_MELTDOWN:
			return w.bellows.meltdowns >= l.count
		LineDef.K_CHASE_TRIP:
			if l.prank != "":
				var pi := w.db.prank_idx(l.prank)
				return pi >= 0 and w.pranks.trip_flag[pi] == 1
			return w.pranks.chase_trips >= 1
		LineDef.K_CHAIN:
			return max_link >= l.link
	return false


## Called at the curtain (night_end): final star evaluation.
func on_curtain(w: SimWorld) -> void:
	dirty = true
	update(w)


## [{id, done, req, big_number, sealed, candle}]
func line_states(w: SimWorld) -> Array:
	var out: Array = []
	for l in w.episode.script_lines:
		out.append({"id": l.id, "done": done[l.idx] == 1, "req": l.req, "big_number": l.big_number,
			"sealed": l.big_number and not bn_unsealed, "candle": candle[l.idx] == 1})
	return out


## [★, ★★, ★★★]
func stars(w: SimWorld) -> Array:
	if w.ctx.no_stars:
		return [false, false, false]
	return [star1, star2, w.scoring.applause >= SimConst.STAR3_TENTHS]


## Deep copy.
func copy() -> ScriptGoals:
	var o := ScriptGoals.new()
	o.done = done.duplicate()
	o.candle_hint = candle_hint.duplicate()
	o.candle = candle.duplicate()
	o.bn_unsealed = bn_unsealed
	o.all_done = all_done
	o.star1 = star1
	o.star2 = star2
	o.star3 = star3
	o.max_link = max_link
	o.dirty = dirty
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in done:
		h = StateHash.mix(h, v)
	for v in candle_hint:
		h = StateHash.mix(h, v)
	for v in candle:
		h = StateHash.mix(h, v)
	for b in [bn_unsealed, all_done, star1, star2, star3, dirty]:
		h = StateHash.mix_bool(h, b)
	return StateHash.mix(h, max_link)
