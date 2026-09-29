## Director — the episode `director` block: cues, the safety net, can't-fail, the scripted end
## (TECH §3.7.7, GDD §2.3). Gates live on the loop entries (EpisodeDef merges `director.gates`).
##
## `cues`: [{id, when}] → `director_cue {id}` the first tick `when` holds (the view shows Figgis cards and
## ghost fingers). `safety_net`: {hide_before_entry_s, slowmo, pulse} → `safety_net {on}` while he is due
## in Hush's room within that time and she isn't hidden (the view slows time; the sim never does).
## `cant_fail` is read by Senses/Chase (Figgis's hook). `end_when`: a condition that ends the Night with
## "prologue_done" (or `director.end {when, reason}`). `safety_net.room` limits it to one room, `once` to one use.
class_name Director
extends RefCounted

var cue_fired: PackedByteArray = PackedByteArray()
var safety_on: bool = false
var safety_used: bool = false
## `SimWorld.emit_serial` at each cue's / the end condition's last evaluation: an event-only condition is
## re-evaluated only after a new event (a cache — results are identical either way; not hashed).
var _cue_serial: PackedInt32Array = PackedInt32Array()
var _end_serial: int = -1


func setup(w: SimWorld) -> void:
	cue_fired.resize(w.ctx.cues.size())
	_cue_serial.resize(cue_fired.size())
	for i in cue_fired.size():
		cue_fired[i] = 0
		_cue_serial[i] = -1
	_end_serial = -1
	safety_on = false


## Step 2 of the tick.
func update(w: SimWorld) -> void:
	var cues := w.ctx.cues
	for i in cues.size():
		if cue_fired[i] == 1:
			continue
		if w.ctx.cue_event_only[i] == 1:
			if _cue_serial[i] == w.emit_serial:
				continue
			_cue_serial[i] = w.emit_serial
		var c: Variant = cues[i]
		if typeof(c) != TYPE_DICTIONARY or not Conditions.seen_all(w, w.ctx.cue_req[i]):
			continue
		if Conditions.eval(w, (c as Dictionary).get("when", {})):
			cue_fired[i] = 1
			w.emit(SimEvents.DIRECTOR_CUE, {"id": str((c as Dictionary).get("id", ""))})
	if not w.ctx.safety_net.is_empty() and not (safety_used and ContentUtil.b(w.ctx.safety_net, "once")):
		var on := _danger(w)
		if on != safety_on:
			safety_on = on
			if not on:
				safety_used = true
			w.emit(SimEvents.SAFETY_NET, {"on": on})
	if w.ctx.end_when != null and _end_due(w) and Conditions.seen_all(w, w.ctx.end_req) \
			and Conditions.eval(w, w.ctx.end_when):
		w.end_night(w.ctx.end_reason)


func _end_due(w: SimWorld) -> bool:
	if not w.ctx.end_event_only:
		return true
	if _end_serial == w.emit_serial:
		return false
	_end_serial = w.emit_serial
	return true


func _danger(w: SimWorld) -> bool:
	var b := w.bellows
	var hu := w.hush
	if hu.is_hidden() or hu.state == SimHush.DIVING or hu.room < 0 or b.room == hu.room:
		return false
	if b.path == null or not (b.state == SimBellows.ROUTINE or b.state == SimBellows.DETOUR or b.state == SimBellows.CURIOUS):
		return false
	var only := ContentUtil.s(w.ctx.safety_net, "room")
	if only != "" and w.room_id(hu.room) != only:
		return false
	var eta := b.path.eta_to_room(hu.room)
	var lim := Fx.ticks(ContentUtil.f(w.ctx.safety_net, "hide_before_entry_s", 1.5))
	return eta >= 0 and eta <= lim


## Deep copy.
func copy() -> Director:
	var o := Director.new()
	o.cue_fired = cue_fired.duplicate()
	o.safety_on = safety_on
	o.safety_used = safety_used
	o._cue_serial = _cue_serial.duplicate()
	o._end_serial = _end_serial
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in cue_fired:
		h = StateHash.mix(h, v)
	h = StateHash.mix_bool(h, safety_used)
	return StateHash.mix_bool(h, safety_on)
