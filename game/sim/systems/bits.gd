## Bits — the squeak (ear pips, squeak bits, head turns, lures, lure fatigue), noises heard, and the
## Mirror, Mirror stand-in rounds (TECH §3.7.7, GDD §5.6, §5.7 #15). The panto is Stage 3.
##
## Hearing a squeak: his room or a room joined to it by a doorway; never while reacting (+1 s), in a
## Meltdown, a chase or the caught hold; asleep he only plays the nap's bit. Each heard squeak is an ear
## pip (8 s window, ≤ 3). If his current activity has a squeak bit used < 3 times this visit it plays
## (over the activity clock — he doesn't leave before it ends; +5 temper, Applause +2 / +1 / 0 per bit
## per Night); otherwise he
## turns his head toward the squeak for 1 s. The third pip within 8 s is a lure (Curious at the squeak's
## spot, specs on, 3 s look) unless two lures already happened in the last 60 s (lure_fatigue: a shout).
## Noises (running, big rigs) within 500 px on his floor make him Curious too.
##
## Mirror, Mirror: when the prank's hook finds Hush FROZEN in the frame, rounds of 72 / 72 / 60 ticks run
## (his task pauses; Hush in the frame is invisible — as she is whenever she stands FROZEN in the frame of the
## rigged prank). Releasing FREEZE in round n fires the prank at tier n (`wink`); still frozen after round 3
## → a face-to-face "?" window. Anything that calls him away cancels the rounds.
class_name Bits
extends RefCounted

var pips: PackedInt32Array = PackedInt32Array()
var lures: PackedInt32Array = PackedInt32Array()
var first_squeak_tick: int = -1
var mirror_active: bool = false
var mirror_prank: int = -1
var mirror_round: int = 0
var mirror_t: int = 0


## Would Bellows hear a squeak from (room, x) now?
func hears(w: SimWorld, room: int, _x: int) -> bool:
	var b := w.bellows
	if b.state == SimBellows.REACTING or b.state == SimBellows.MELTDOWN or b.state == SimBellows.CAUGHT_HOLD \
			or b.state == SimBellows.CHASE or b.state == SimBellows.SPOTTED:
		return false
	if w.tick < b.blind_after_until:
		return false
	if b.path != null and (b.path.current_kind() == NavPath.STAIRS or b.path.current_kind() == NavPath.DOOR):
		return false
	return w.db.nav.doorway_joined(b.room, room)


## A squeak (or a wheeze start) happened at (room, x).
func on_squeak(w: SimWorld, room: int, x: int, heard: bool) -> void:
	if first_squeak_tick < 0:
		first_squeak_tick = w.tick
	if not heard:
		return
	var b := w.bellows
	var a := _current_activity(w)
	if b.asleep:
		if a != null and a.squeak_bit != "" and b.visit_bits < SimConst.BIT_MAX_PER_VISIT:
			_play_bit(w, a)
		return
	_trim_pips(w)
	pips.append(w.tick)
	while pips.size() > SimConst.EAR_PIPS_MAX:
		pips.remove_at(0)
	b.ear_pips = pips.size()
	w.emit(SimEvents.EAR_PIP, {"n": b.ear_pips})
	if a != null and a.squeak_bit != "" and b.visit_bits < SimConst.BIT_MAX_PER_VISIT:
		_play_bit(w, a)
	else:
		b.head_turn_until = w.tick + SimConst.HEAD_TURN_TICKS
		var d := Fx.signi(x - b.x_sub) if room == b.room else -b.facing
		b.head_turn_dir = d if d != 0 else b.facing
		w.emit(SimEvents.HEAD_TURN)
	if pips.size() >= SimConst.EAR_PIPS_MAX:
		pips = PackedInt32Array()
		b.ear_pips = 0
		_trim_lures(w)
		if lures.size() >= SimConst.LURE_FATIGUE_COUNT:
			w.emit(SimEvents.LURE_FATIGUE)
		else:
			lures.append(w.tick)
			w.emit(SimEvents.LURE, {"room": w.room_id(room), "x": Fx.to_px(x)})
			b.queue_curious(w, room, x, Routine.WHY_LURE, SimConst.LURE_LOOK_TICKS)


func _current_activity(w: SimWorld) -> ActivityDef:
	var b := w.bellows
	if b.state == SimBellows.ROUTINE and b.task_kind == SimBellows.T_ACTIVITY and b.phase == SimBellows.PH_PERFORM \
			and b.task_act >= 0:
		return w.db.activity_list[b.task_act]
	return null


func _play_bit(w: SimWorld, a: ActivityDef) -> void:
	var b := w.bellows
	var bit := a.squeak_bit
	var info: Dictionary = w.db.squeak_bits.get(bit, {})
	var length: int = int(info.get("len", SimConst.BIT_DEFAULT_TICKS))
	b.bit_until = w.tick + length
	b.visit_bits += 1
	var n: int = w.scoring.bit_plays.get(bit, 0)
	var score: int = SimConst.BIT_SCORES[n] if n < SimConst.BIT_SCORES.size() else 0
	w.emit(SimEvents.SQUEAK_BIT, {"bit": bit, "score": score})
	w.scoring.squeak_bit(w, bit)
	w.temper.gain(w, SimConst.GAIN_BIT * SimConst.TEMPER_Q)


func _trim_pips(w: SimWorld) -> void:
	while pips.size() > 0 and w.tick - pips[0] >= SimConst.EAR_PIP_WINDOW:
		pips.remove_at(0)


func _trim_lures(w: SimWorld) -> void:
	while lures.size() > 0 and w.tick - lures[0] >= SimConst.LURE_FATIGUE_WINDOW:
		lures.remove_at(0)


## Fade old ear pips (per tick).
func update_pips(w: SimWorld) -> void:
	if pips.is_empty():
		return
	var n := pips.size()
	_trim_pips(w)
	if pips.size() != n:
		w.bellows.ear_pips = pips.size()
		w.emit(SimEvents.EAR_PIP, {"n": pips.size()})


## False while lure fatigue is on (the HUD greys the Clarence ring).
func lure_ready(w: SimWorld) -> bool:
	var n := 0
	for t in lures:
		if w.tick - t < SimConst.LURE_FATIGUE_WINDOW:
			n += 1
	return n < SimConst.LURE_FATIGUE_COUNT


## A noise (run, big rig) at (room, x): he investigates if within 500 px on his floor.
func on_noise(w: SimWorld, room: int, x: int) -> void:
	var b := w.bellows
	if b.state != SimBellows.ROUTINE and b.state != SimBellows.DETOUR and b.state != SimBellows.CURIOUS:
		return
	if b.asleep or w.tick < b.blind_after_until:
		return
	if b.path != null and (b.path.current_kind() == NavPath.STAIRS or b.path.current_kind() == NavPath.DOOR):
		return
	var d := w.db.nav.floor_distance(b.room, b.x_sub, room, x)
	if d < 0 or d > SimConst.NOISE_PX * SimConst.SUB:
		return
	b.queue_curious(w, room, x, Routine.WHY_NOISE, SimConst.CURIOUS_LOOK_TICKS)


# --- Mirror, Mirror -------------------------------------------------------------------------------

## Begin the stand-in rounds for prank `p`.
func start_mirror(w: SimWorld, p: int) -> void:
	mirror_active = true
	mirror_prank = p
	mirror_round = 1
	mirror_t = 0
	w.emit(SimEvents.MIRROR_ROUND, {"round": 1})


## One tick of the rounds (his task is paused while they run).
func update_mirror(w: SimWorld) -> void:
	if not mirror_active:
		return
	if not Conditions.hush_in_frame_frozen(w, mirror_prank):
		var r := mirror_round
		mirror_active = false
		w.emit(SimEvents.WINK, {"round": r})
		w.pranks.fire(w, mirror_prank, "use", 0, r)
		return
	mirror_t += 1
	var pd := w.db.prank_list[mirror_prank]
	var rounds: Array = Array(pd.stand_rounds) if pd.stand_rounds.size() > 0 else SimConst.MIRROR_ROUNDS
	if mirror_t >= int(rounds[mirror_round - 1]):
		mirror_round += 1
		mirror_t = 0
		if mirror_round > rounds.size():
			mirror_active = false
			w.senses.start_f2f(w, w.db.prank_list[mirror_prank].rig_idx, Senses.F2F_MIRROR)
			return
		w.emit(SimEvents.MIRROR_ROUND, {"round": mirror_round})


## True while Hush is his "reflection": in the frame during the rounds, or FROZEN in the frame of a
## RIGGED stand-in prank (the glass is out; a frozen Hush there reads as his reflection).
func mirror_hides(w: SimWorld) -> bool:
	if mirror_active:
		return Conditions.hush_in_frame(w, mirror_prank)
	if w.hush.state != SimHush.FROZEN:
		return false
	for p in w.ctx.stand_in_pranks:
		if w.pranks.state[p] == Pranks.RIGGED and Conditions.hush_in_frame(w, p):
			return true
	return false


## Stop the rounds (he was called away).
func cancel_mirror() -> void:
	mirror_active = false


## Deep copy.
func copy() -> Bits:
	var o := Bits.new()
	o.pips = pips.duplicate()
	o.lures = lures.duplicate()
	o.first_squeak_tick = first_squeak_tick
	o.mirror_active = mirror_active
	o.mirror_prank = mirror_prank
	o.mirror_round = mirror_round
	o.mirror_t = mirror_t
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix_arr(h, pips)
	h = StateHash.mix_arr(h, lures)
	h = StateHash.mix(h, first_squeak_tick)
	h = StateHash.mix_bool(h, mirror_active)
	h = StateHash.mix(h, mirror_prank)
	h = StateHash.mix(h, mirror_round)
	return StateHash.mix(h, mirror_t)
