## Senses — Bellows' sight: the specs rule, the "?" meter, near miss, spotted, face-to-face windows
## (TECH §3.7.3, GDD §4.3, §4.7).
##
## Sight covers his current room in the direction he faces (a head turn overrides the facing for 1 s),
## to the wall; within 250 px of an open doorway he faces he also sees 300 px into the next room. Never
## behind him, never across the stairs, never into a hiding spot he didn't watch Hush enter.
##
##   | state                                            | moving       | frozen |
##   | specs off                                        | 600          | 250    |
##   | specs on (reading, Curious, Search, On Guard, Livid, chase) | whole room | 600 |
##   | absorbed (bath)                                  | 250          | 0      |
##   | blinded / Exhausted                              | 150          | 150    |
##   | asleep, reacting (+60), Meltdown, eyes-shut      | 0            | 0      |
##
## The "?" meter: +1 per tick while he sees her, −2 while not; full (`rules.spot_fill_s`, ×1.5 relaxed)
## → `spotted` (or Figgis's hook when the episode can't be failed). Back to 0 after peaking ≥ 50 % →
## `near_miss` (+2 Applause, max 3 scored) and he goes Curious to where he saw her. When the meter is back to
## 0 a watched hiding spot is forgotten (hidden = safe again).
## Face-to-face (an in-use hiding spot he opens, or the Mirror after round 3): a 48-tick window; POP OUT
## (hiding) or releasing FREEZE (mirror) escapes (a near miss), otherwise a catch.
class_name Senses
extends RefCounted

const F2F_HIDING := 0
const F2F_MIRROR := 1

## He sees Hush this tick.
var visible: bool = false
var peak: int = 0
var spotted_tick: int = -1
## True when the last catch was preceded by a full "?" or a face-to-face window (invariant counters).
var window_ok: bool = false
## First bump: the meter is held at 0 until this tick.
var suppress_until: int = 0
var last_seen_room: int = -1
var last_seen_x: int = 0
var last_seen_tick: int = -1000000
var f2f_until: int = -1
var f2f_spot: int = -1
var f2f_kind: int = F2F_HIDING
var f2f_escaped: bool = false


## Step 6 of the tick.
func update(w: SimWorld) -> void:
	var b := w.bellows
	if f2f_active():
		_update_f2f(w)
		visible = false
		return
	if not w.ctx.senses:
		# `rules.senses: false` (the Gate-0 scene): he never starts a "?" and never catches
		visible = false
		b.spot_meter = 0
		peak = 0
		return
	visible = can_see(w)
	if visible:
		last_seen_room = w.hush.room
		last_seen_x = w.hush.x_sub
		last_seen_tick = w.tick
		if w.hush.state == SimHush.HIDDEN and w.hush.hidden_spot >= 0:
			last_seen_x = w.db.house.hotspots[w.hush.hidden_spot].use_sub
	var st := b.state
	if st == SimBellows.SPOTTED or st == SimBellows.CHASE or st == SimBellows.CAUGHT_HOLD or w.hush.state == SimHush.CAUGHT:
		b.spot_meter = 0
		peak = 0
		return
	if w.tick < suppress_until:
		b.spot_meter = 0
		peak = 0
		return
	var fill := w.ctx.spot_fill
	b.spot_fill = fill
	if visible:
		if b.spot_meter == 0:
			w.emit(SimEvents.SPOT_START, {"by": "bellows"})
		b.spot_meter += 1
		if b.spot_meter > peak:
			peak = b.spot_meter
		if b.spot_meter >= fill:
			_spotted(w)
	elif b.spot_meter > 0:
		b.spot_meter = maxi(0, b.spot_meter - SimConst.SPOT_DRAIN)
		if b.spot_meter == 0:
			var near := peak * 100 >= fill * SimConst.NEAR_MISS_MIN_PCT
			peak = 0
			# the "?" is gone: he has forgotten the spot he saw her dive into
			w.hush.watched_spot = -1
			if near:
				w.emit(SimEvents.NEAR_MISS, {"by": "bellows"})
				w.scoring.near_miss(w)
				if (b.state == SimBellows.ROUTINE or b.state == SimBellows.DETOUR or b.state == SimBellows.CURIOUS) \
						and last_seen_room >= 0 and w.hush.state != SimHush.HIDDEN:
					b.queue_curious(w, last_seen_room, last_seen_x, Routine.WHY_NEAR_MISS, SimConst.CURIOUS_LOOK_TICKS)


## Can Bellows see Hush right now? (Pure query; no state change.)
func can_see(w: SimWorld) -> bool:
	var b := w.bellows
	var hu := w.hush
	if hu.state == SimHush.CAUGHT or hu.state == SimHush.BOWING or hu.in_transit():
		return false
	if b.room < 0 or hu.room < 0:
		return false
	if b.path != null and not b.path.is_done():
		var k := b.path.current_kind()
		if k == NavPath.STAIRS or k == NavPath.DOOR:
			return false
	var hx := hu.x_sub
	var moving := hu.is_moving(w.tick)
	if hu.state == SimHush.HIDDEN:
		if hu.watched_spot < 0 or hu.hidden_spot != hu.watched_spot:
			return false
		hx = w.db.house.hotspots[hu.hidden_spot].use_sub
		moving = true
	if w.bits.mirror_hides(w):
		return false
	_compute_ranges(w)
	var rng: int = _rng_moving if moving else _rng_frozen
	if rng == 0:
		return false
	var face := b.facing
	if w.tick < b.head_turn_until:
		face = b.head_turn_dir
	var dx := hx - b.x_sub
	if hu.room == b.room:
		if dx * face < 0:
			return false
		return rng < 0 or absi(dx) <= rng * SimConst.SUB
	var li := w.db.nav.doorway_ahead(b.room, b.x_sub, face, SimConst.LOOK_THROUGH_NEAR * SimConst.SUB)
	if li < 0:
		return false
	var l := w.db.house.links[li]
	if l.other(b.room) != hu.room:
		return false
	var past := (hx - l.x_sub) * face
	if past < 0 or past > SimConst.LOOK_THROUGH_DEPTH * SimConst.SUB:
		return false
	return rng < 0 or absi(dx) <= rng * SimConst.SUB


## [moving range px (−1 = whole room), frozen range px] for his current state.
func sight_ranges(w: SimWorld) -> Array:
	_compute_ranges(w)
	return [_rng_moving, _rng_frozen]


## Allocation-free sight ranges: Vector2i(moving px (−1 = to the wall), frozen px); 0/0 when blind (asleep,
## reacting + 60, Meltdown, eyes-shut, `rules.senses: false`).
func sight_ranges_into(w: SimWorld) -> Vector2i:
	if not w.ctx.senses:
		return Vector2i.ZERO
	_compute_ranges(w)
	return Vector2i(_rng_moving, _rng_frozen)


var _rng_moving: int = 0
var _rng_frozen: int = 0


func _set_ranges(m: int, f: int) -> void:
	_rng_moving = m
	_rng_frozen = f


func _compute_ranges(w: SimWorld) -> void:
	var b := w.bellows
	var st := b.state
	if st == SimBellows.REACTING or st == SimBellows.MELTDOWN or st == SimBellows.CAUGHT_HOLD:
		_set_ranges(0, 0)
		return
	if w.tick < b.blind_after_until or b.asleep:
		_set_ranges(0, 0)
		return
	var a: ActivityDef = null
	if st == SimBellows.ROUTINE and b.task_kind == SimBellows.T_ACTIVITY and b.phase == SimBellows.PH_PERFORM and b.task_act >= 0:
		a = w.db.activity_list[b.task_act]
	if a != null and a.awareness == ActivityDef.AWARE_BLIND:
		_set_ranges(0, 0)
	elif b.blinded or st == SimBellows.EXHAUSTED:
		_set_ranges(SimConst.SIGHT_BLIND_MOVING, SimConst.SIGHT_BLIND_FROZEN)
	elif a != null and a.awareness == ActivityDef.AWARE_ABSORBED:
		_set_ranges(SimConst.SIGHT_ABSORBED_MOVING, SimConst.SIGHT_ABSORBED_FROZEN)
	elif b.specs_on:
		_set_ranges(SimConst.SIGHT_ON_MOVING, SimConst.SIGHT_ON_FROZEN)
	else:
		_set_ranges(SimConst.SIGHT_OFF_MOVING, SimConst.SIGHT_OFF_FROZEN)


func _spotted(w: SimWorld) -> void:
	var b := w.bellows
	window_ok = true
	spotted_tick = w.tick
	w.emit(SimEvents.SPOTTED, {"by": "bellows"})
	if w.ctx.cant_fail:
		figgis_hook(w)
		return
	b.on_spotted(w)


## The show must go on: Figgis yanks Hush into the nearest hiding spot (Prologue can't-fail).
func figgis_hook(w: SimWorld) -> void:
	var hu := w.hush
	var house := w.db.house
	var best := -1
	var best_d := 1 << 40
	for h in house.hotspots:
		if h.kind != HotspotDef.HIDING or not w.ctx.hush_allowed(h.room_idx):
			continue
		if h.idx == f2f_spot and f2f_active():
			continue
		var d := absi(h.use_sub - hu.x_sub)
		if h.room_idx != hu.room:
			d += 1 << 30
		if d < best_d:
			best_d = d
			best = h.idx
	reset_meter(w)
	f2f_until = -1
	if best < 0:
		return
	hu.figgis_into(w, best)
	w.emit(SimEvents.FIGGIS_HOOK)
	w.emit(SimEvents.HIDE, {"spot": house.hotspots[best].id, "watched": false})


## Zero the meter (no near miss).
func reset_meter(w: SimWorld) -> void:
	w.bellows.spot_meter = 0
	peak = 0


## Open a face-to-face window at a hiding spot or the mirror (never with `rules.senses: false`).
func start_f2f(w: SimWorld, spot: int, kind: int) -> void:
	if f2f_active() or not w.ctx.senses:
		return
	f2f_until = w.tick + w.ctx.f2f_ticks
	f2f_spot = spot
	f2f_kind = kind
	f2f_escaped = false
	reset_meter(w)
	w.emit(SimEvents.FACE_TO_FACE, {"spot": w.db.house.hotspots[spot].id if spot >= 0 else ""})


## True while a face-to-face window runs.
func f2f_active() -> bool:
	return f2f_until >= 0


func _update_f2f(w: SimWorld) -> void:
	var hu := w.hush
	var escaped := f2f_escaped
	if f2f_kind == F2F_MIRROR:
		escaped = escaped or hu.state != SimHush.FROZEN
	else:
		escaped = escaped or hu.hidden_spot != f2f_spot
	if escaped and hu.state != SimHush.CAUGHT:
		f2f_until = -1
		f2f_escaped = false
		w.emit(SimEvents.NEAR_MISS, {"by": "bellows"})
		w.scoring.near_miss(w)
		return
	if w.tick >= f2f_until:
		window_ok = true
		spotted_tick = f2f_until - w.ctx.f2f_ticks
		f2f_until = -1
		if w.ctx.cant_fail:
			figgis_hook(w)
			return
		w.bellows.start_caught(w, "face_to_face")


## Deep copy.
func copy() -> Senses:
	var o := Senses.new()
	o.visible = visible
	o.peak = peak
	o.spotted_tick = spotted_tick
	o.window_ok = window_ok
	o.suppress_until = suppress_until
	o.last_seen_room = last_seen_room
	o.last_seen_x = last_seen_x
	o.last_seen_tick = last_seen_tick
	o.f2f_until = f2f_until
	o.f2f_spot = f2f_spot
	o.f2f_kind = f2f_kind
	o.f2f_escaped = f2f_escaped
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in [int(visible), peak, spotted_tick, int(window_ok), suppress_until, last_seen_room, last_seen_x, last_seen_tick,
			f2f_until, f2f_spot, f2f_kind, int(f2f_escaped)]:
		h = StateHash.mix(h, v)
	return h
