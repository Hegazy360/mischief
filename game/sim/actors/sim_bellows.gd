## SimBellows — the neighbour: state machine, routine tasks, walking, detours (TECH §3.7.1, GDD §4).
##
## States: ROUTINE, DETOUR, CURIOUS, SPOTTED, CHASE, SEARCH, REACTING, MELTDOWN, EXHAUSTED, CAUGHT_HOLD
## (priority Chase > Reacting/Meltdown > Spotted > Curious > Detour > Routine) plus `on_guard_until` and
## `asleep`. A task (loop activity, fix-up, curious, search) is WALK_TO → PERFORM(t) → DONE.
##
## Readable by the view: room, floor, x_sub, facing, state, activity_id, activity_t, activity_len,
## detour ({kind, station} or {}), specs_on, blinded_until, blinded, temper_q, tier, residues (sorted kinds),
## spot_meter, spot_fill, ear_pips, reacting ({prank, archetype, variant, tier, suppressed, t, len, travel}
## or {}), bump_count, look_back_until, asleep, on_guard_until, link, tomatoes, meltdowns, glyph.
class_name SimBellows
extends RefCounted

const ROUTINE := 0
const DETOUR := 1
const CURIOUS := 2
const SPOTTED := 3
const CHASE := 4
const SEARCH := 5
const REACTING := 6
const MELTDOWN := 7
const EXHAUSTED := 8
const CAUGHT_HOLD := 9
const STATE_NAMES: Array[String] = ["ROUTINE", "DETOUR", "CURIOUS", "SPOTTED", "CHASE", "SEARCH", "REACTING",
	"MELTDOWN", "EXHAUSTED", "CAUGHT_HOLD"]

## Task kinds.
const T_NONE := 0
const T_ACTIVITY := 1
const T_FIXUP := 2
const T_CURIOUS := 3
const T_SEARCH := 4
## The scripted exit walk (episode `exit`): walks off and stays there.
const T_EXIT := 5
## Task phases.
const PH_WALK := 0
const PH_PERFORM := 1
## What a reaction / chase interrupted.
const INT_NONE := 0
const INT_DONE := 1
const INT_WALK := 2
const INT_RESUME := 3
const INT_CHASE := 4
## Bump phases.
const BUMP_NONE := 0
const BUMP_PAT := 1
const BUMP_WALK_ON := 2
const BUMP_TURN := 3
const BUMP_LOOK := 4

## Awareness glyph ids.
const GLYPH_SPECS_OFF := "specs_off"
const GLYPH_SPECS_ON := "specs_on"
const GLYPH_BLINDED := "blinded"
const GLYPH_ASLEEP := "asleep"
const GLYPH_STARS := "stars"

var room: int = -1
var floor: int = 0
var x_sub: int = 0
var facing: int = 1
var state: int = ROUTINE
var activity_id: String = ""
var activity_t: int = 0
## −1 = not known yet (a player-led gate).
var activity_len: int = -1
var specs_on: bool = false
var blinded_until: int = 0
var blinded: bool = false
var temper_q: int = 0
var tier: int = 0
var residues: PackedStringArray = PackedStringArray()
var spot_meter: int = 0
var spot_fill: int = 60
var ear_pips: int = 0
var bump_count: int = 0
var look_back_until: int = 0
var asleep: bool = false
var on_guard_until: int = 0
var link: int = 0
var tomatoes: int = 0
var meltdowns: int = 0
var catches: int = 0
var glyph: String = GLYPH_SPECS_OFF
var blind_after_until: int = 0

## Current detour ({kind, station} or {}).
var detour: Dictionary:
	get:
		if task_kind == T_NONE or task_kind == T_ACTIVITY:
			return {}
		return {"kind": activity_id, "station": _station_id(task_station)}

## Current reaction ({} when not reacting).
var reacting: Dictionary:
	get:
		if state != REACTING or rx_prank < 0:
			return {}
		return {"prank": rx_prank_id, "archetype": rx_archetype, "variant": rx_variant, "tier": rx_tier,
			"suppressed": rx_suppressed, "t": rx_t, "len": rx_len,
			"travel": {"from_f": rx_from_f, "to_f": rx_to_f, "room": rx_room1_id, "x_sub": rx_x1} if rx_has_travel else {}}

# task
var task_kind: int = T_NONE
var task_loop: int = -1
var task_act: int = -1
var task_station: int = -1
var task_room: int = -1
var task_x: int = 0
var task_facing: int = 1
var task_residue: int = -1
var task_why: String = ""
var phase: int = PH_WALK
var hook_cursor: int = 0
var gate_met_t: int = -1
var path: NavPath = null
var path_serial: int = 0
# entry warning
var warn_serial: int = -1
var warn_leg: int = -1
var warn_room: int = -1
var warn_tick: int = -1000000
# timers
var bit_until: int = 0
var head_turn_until: int = 0
var head_turn_dir: int = 1
var stun_until: int = 0
var spotted_t: int = 0
var melt_t: int = 0
var exhaust_t: int = 0
var caught_t: int = 0
var caught_cause: String = ""
var bump_phase: int = BUMP_NONE
var bump_t: int = 0
var look_t: int = 0
# interruption / resume
var int_kind: int = INT_NONE
var resume_loop: int = -1
var resume_t: int = 0
var resume_cursor: int = 0
var resume_len: int = -1
var resume_gate: int = -1
var exhaust_after: bool = false
# reaction (logic in Reactions)
var rx_prank: int = -1
var rx_prank_id: String = ""
var rx_archetype: String = ""
var rx_variant: String = ""
var rx_key: String = ""
var rx_tier: int = 1
var rx_suppressed: bool = false
var rx_t: int = 0
var rx_len: int = 0
var rx_entry: int = 0
var rx_accent: int = 0
var rx_knock_f: int = -1
var rx_accented: bool = false
var rx_trig: String = ""
var rx_link: int = 1
var rx_knock_from: int = -1
var rx_has_travel: bool = false
var rx_from_f: int = 0
var rx_to_f: int = 0
var rx_x0: int = 0
var rx_x1: int = 0
var rx_room0: int = -1
var rx_room1: int = -1
var rx_room1_id: String = ""
var rx_ease: int = 0
var rx_end_place: bool = false
# bookkeeping
var last_next_id: String = ""
var last_specs: bool = false
var last_step_px: int = 0
var visit_bits: int = 0
## The scripted exit is due / under way.
var exit_due: bool = false


func setup(w: SimWorld) -> void:
	var ep := w.episode
	for st in w.db.house.stations:
		_db_station_ids.append(st.id)
	room = w.room_idx(ep.bellows_room)
	if room < 0:
		room = 0
	x_sub = ep.bellows_x_sub
	floor = w.db.house.rooms[room].floor
	spot_fill = w.ctx.spot_fill
	if w.ctx.nerves:
		w.temper.set_at_least(w, w.ctx.nerves_q)
	_start_next(w)
	last_next_id = _next_id(w)
	glyph = _compute_glyph(w)


func _station_id(s: int) -> String:
	if s < 0 or s >= _db_station_ids.size():
		return ""
	return _db_station_ids[s]


var _db_station_ids: PackedStringArray = PackedStringArray()


func _insert_pause(at: int, t: int, aux: int) -> void:
	path.insert_pause(at, t, aux)
	if warn_serial == path.serial and at <= warn_leg:
		warn_leg += 1


# --- per tick -------------------------------------------------------------------------------------

## Step 5 of the tick.
func update(w: SimWorld) -> void:
	last_step_px = 0
	match state:
		CAUGHT_HOLD:
			_update_caught(w)
		REACTING:
			w.reactions.update(w)
		MELTDOWN:
			_update_meltdown(w)
		EXHAUSTED:
			exhaust_t -= 1
			if exhaust_t <= 0:
				_start_next(w)
		SPOTTED:
			spotted_t -= 1
			if spotted_t <= 0:
				w.chase.start(w)
		CHASE:
			w.chase.update(w)
		_:
			_update_task(w)
	_update_derived(w)


func _update_task(w: SimWorld) -> void:
	if w.senses.f2f_active():
		return
	if w.bits.mirror_active:
		w.bits.update_mirror(w)
		return
	if phase == PH_WALK:
		_walk(w)
	else:
		_perform(w)


func _walk(w: SimWorld) -> void:
	if path == null:
		_arrive(w)
		return
	if bump_phase != BUMP_NONE and not _update_bump(w):
		return
	path.speed = SimConst.b_walk_speed(tier)
	_entry_warning(w)
	if bump_phase == BUMP_NONE and _check_bump(w):
		return
	var ox := x_sub
	var oroom := room
	var flags := path.advance()
	if apply_path(w, flags, oroom, ox, false):
		return
	if flags & NavPath.F_DONE:
		_arrive(w)


## Apply a path advance; returns true when a STEP prank fired (the walk is over).
func apply_path(w: SimWorld, flags: int, oroom: int, ox: int, chasing: bool) -> bool:
	var nroom := path.room
	var nx := path.x
	if w.pranks.check_step(w, oroom, ox, nroom, nx, flags, chasing):
		return true
	x_sub = nx
	var pa := path.current_pause_aux()
	if pa == NavPath.AUX_LOOK_BACK:
		facing = -path.facing
	else:
		facing = path.facing
	last_step_px = Fx.div(absi(nx - ox), SimConst.SUB) if nroom == oroom else 0
	if nroom != room:
		room = nroom
		floor = w.db.house.rooms[room].floor
		w.emit(SimEvents.B_ROOM, {"room": w.room_id(room), "chase": state == CHASE})
	if flags & NavPath.F_PORTAL and not (flags & NavPath.F_STAIRS) and not chasing and state != REACTING \
			and tier >= SimConst.TIER_STEAMING_ID and path.cursor < path.size():
		# after the crossing leg, so finishing the pause doesn't re-cross the portal
		_insert_pause(path.cursor + 1, SimConst.LOOK_BACK_TICKS, NavPath.AUX_LOOK_BACK)
		look_back_until = w.tick + SimConst.LOOK_BACK_TICKS
		facing = -path.facing
		w.emit(SimEvents.LOOK_BACK)
	return false


func _entry_warning(w: SimWorld) -> void:
	var hr := w.hush.room
	if hr < 0 or hr == room or path == null:
		return
	# Checked before this tick's advance: a path eta of e ticks enters on tick now + e − 1 (the e-th
	# advance); e == 0 means only zero-length legs remain before the portal (entry during this advance).
	var e := path.eta_to_room(hr)
	if e < 0:
		return
	var eta := e - 1 if e >= 1 else 0
	if eta > SimConst.ENTRY_WARN:
		return
	var leg := path.entry_leg(hr)
	if leg < 0 or (warn_serial == path.serial and warn_leg == leg and warn_room == hr):
		return
	# TECH §3.7.1: `eta` is the lead time without the pause; the doorway pause makes up 90 − eta
	w.emit(SimEvents.ENTRY_WARNING, {"room": w.room_id(hr), "eta": eta})
	var pause := SimConst.ENTRY_WARN - eta
	if e == 0:
		pause += 1
	if pause > 0:
		_insert_pause(leg, pause, NavPath.AUX_DOORWAY_PAUSE)
		leg += 1
		w.emit(SimEvents.DOORWAY_PAUSE, {"ticks": pause})
	warn_serial = path.serial
	warn_leg = leg
	warn_room = hr
	warn_tick = w.tick


## True when his last warning for room `r` came ≥ ENTRY_WARN ticks ago (invariant counters).
func warned_ok(w: SimWorld, r: int) -> bool:
	return warn_room == r and w.tick - warn_tick >= SimConst.ENTRY_WARN


# --- bump rule (GDD §4.3) -------------------------------------------------------------------------

func _check_bump(w: SimWorld) -> bool:
	var hu := w.hush
	if hu.state != SimHush.FROZEN or hu.room != room or path.current_kind() != NavPath.WALK:
		return false
	var dir := Fx.signi(path.xs[path.cursor] - x_sub)
	if dir == 0:
		return false
	var dx := hu.x_sub - x_sub
	if dx * dir < 0:
		return false
	if absi(dx) > SimConst.BUMP_PX * SimConst.SUB + path.speed:
		return false
	if absi(path.xs[path.cursor] - x_sub) < absi(dx):
		return false
	bump_count += 1
	var first := bump_count == 1
	w.emit(SimEvents.BUMP, {"first": first})
	facing = dir
	if first:
		bump_phase = BUMP_PAT
		bump_t = SimConst.BUMP_PAT_TICKS
		w.senses.suppress_until = w.tick + SimConst.BUMP_PAT_TICKS + SimConst.BUMP_WALK_ON_TICKS + SimConst.BUMP_TURN_TICKS
		w.senses.reset_meter(w)
	else:
		bump_phase = BUMP_LOOK
		look_t = 0
	return true


## Returns true when walking may continue this tick.
func _update_bump(w: SimWorld) -> bool:
	match bump_phase:
		BUMP_PAT:
			bump_t -= 1
			if bump_t <= 0:
				bump_phase = BUMP_WALK_ON
				bump_t = SimConst.BUMP_WALK_ON_TICKS
			return false
		BUMP_WALK_ON:
			bump_t -= 1
			if bump_t <= 0:
				bump_phase = BUMP_TURN
				bump_t = SimConst.BUMP_TURN_TICKS
				var dx := w.hush.x_sub - x_sub
				if dx != 0:
					facing = Fx.signi(dx)
				return false
			return true
		BUMP_TURN:
			bump_t -= 1
			var dx2 := w.hush.x_sub - x_sub
			if dx2 != 0 and w.hush.room == room:
				facing = Fx.signi(dx2)
			if bump_t <= 0:
				bump_phase = BUMP_LOOK
				look_t = 0
			return false
		BUMP_LOOK:
			look_t += 1
			if w.hush.room == room and w.hush.state == SimHush.FROZEN:
				var dx3 := w.hush.x_sub - x_sub
				if dx3 != 0:
					facing = Fx.signi(dx3)
			if (spot_meter == 0 and look_t >= SimConst.HEAD_TURN_TICKS) or look_t >= SimConst.BUMP_LOOK_MAX:
				bump_phase = BUMP_NONE
				return true
			return false
	return true


# --- tasks ----------------------------------------------------------------------------------------

func _arrive(w: SimWorld) -> void:
	path = null
	phase = PH_PERFORM
	facing = task_facing
	bump_phase = BUMP_NONE
	if int_kind == INT_RESUME and task_kind == T_ACTIVITY and task_loop == resume_loop:
		activity_t = resume_t
		hook_cursor = resume_cursor
		activity_len = resume_len
		gate_met_t = resume_gate
		int_kind = INT_NONE
		return
	int_kind = INT_NONE
	activity_t = 0
	hook_cursor = 0
	gate_met_t = -1
	visit_bits = 0
	w.emit(SimEvents.B_ACTIVITY, {"id": activity_id})
	if task_kind == T_EXIT and w.ctx.end_when == null:
		w.end_night(w.ctx.end_reason)
		return
	if task_kind == T_ACTIVITY and task_act >= 0:
		var a := w.db.activity_list[task_act]
		if a.in_use_idx >= 0 and w.hush.state == SimHush.HIDDEN and w.hush.hidden_spot == a.in_use_idx:
			w.senses.start_f2f(w, a.in_use_idx, Senses.F2F_HIDING)
		_update_gate(w)


func _perform(w: SimWorld) -> void:
	activity_t += 1
	var a: ActivityDef = w.db.activity_list[task_act] if task_act >= 0 else null
	if a != null and a.path.size() == 2 and task_kind == T_ACTIVITY:
		var tx := a.path[1]
		var dx := tx - x_sub
		if dx != 0:
			var sp := SimConst.b_walk_speed(tier)
			var ox := x_sub
			var nx := tx if absi(dx) <= sp else x_sub + sp * Fx.signi(dx)
			facing = Fx.signi(dx)
			if w.pranks.check_step(w, room, ox, room, nx, 0, false):
				return
			x_sub = nx
			last_step_px = Fx.div(absi(nx - ox), SimConst.SUB)
	# Search, Curious ("looks both ways") and the scripted hunt turn around every 1.5 s
	if task_kind == T_SEARCH or task_kind == T_CURIOUS \
			or (a != null and a.awareness == ActivityDef.AWARE_SEARCHING and task_kind == T_ACTIVITY):
		if activity_t % SimConst.SEARCH_TURN_EVERY == 0:
			facing = -facing
	if task_kind == T_ACTIVITY and a != null:
		while hook_cursor < a.hook_count() and a.hooks[hook_cursor * 2] <= activity_t:
			var mark := a.hooks[hook_cursor * 2]
			var pi := a.hooks[hook_cursor * 2 + 1]
			hook_cursor += 1
			if mark == activity_t:
				w.pranks.on_hook(w, pi, "use")
		if state == REACTING or state == MELTDOWN or w.bits.mirror_active:
			return
		_update_gate(w)
	elif task_kind == T_FIXUP and activity_t == _fixup_mark(w):
		w.pranks.fixup_hooks(w, task_station, _fixup_kind(w))
		if state == REACTING or w.bits.mirror_active:
			return
	# a squeak bit plays over the activity clock; he doesn't leave before it is over
	if activity_len >= 0 and activity_t >= activity_len and w.tick >= bit_until:
		_complete_task(w)


func _fixup_mark(w: SimWorld) -> int:
	if task_act >= 0 and w.db.activity_list[task_act].mark_ticks >= 0:
		return w.db.activity_list[task_act].mark_ticks
	return SimConst.FIXUP_MARK_TICKS


func _fixup_kind(w: SimWorld) -> String:
	if task_residue < 0:
		return ""
	return w.db.residue_list[task_residue].fixup


func _update_gate(w: SimWorld) -> void:
	if task_kind != T_ACTIVITY or task_loop < 0:
		return
	var le: EpisodeDef.LoopEntry = w.episode.loop[task_loop]
	if not le.has_gate or (le.first_loop_only and w.routine.loop_count > 0):
		return
	if gate_met_t < 0 and _gate_true(w, le.until):
		gate_met_t = activity_t
	var end := -1
	if gate_met_t >= 0:
		end = gate_met_t + le.plus_ticks
	if le.max_ticks >= 0:
		end = mini(end, le.max_ticks) if end >= 0 else le.max_ticks
	activity_len = end


func _gate_true(w: SimWorld, until: Variant) -> bool:
	if until == null:
		return false
	if typeof(until) == TYPE_STRING:
		var s := str(until)
		if s == "first_squeak":
			return w.bits.first_squeak_tick >= 0
		if s == "first_rig":
			return w.pranks.first_rig_tick >= 0
		if s.begins_with("rigged:"):
			var st := w.prank_state(s.trim_prefix("rigged:"))
			return st >= Pranks.RIGGED
		return false
	return Conditions.eval(w, until)


func _complete_task(w: SimWorld) -> void:
	match task_kind:
		T_ACTIVITY:
			_complete_loop_activity(w)
		T_FIXUP:
			w.emit(SimEvents.B_ACTIVITY_END, {"id": activity_id})
			if task_residue >= 0:
				w.residue.clear(w, w.db.residue_list[task_residue].id)
		T_SEARCH:
			w.emit(SimEvents.B_ACTIVITY_END, {"id": activity_id})
			on_guard_until = w.tick + SimConst.ON_GUARD_TICKS
			w.emit(SimEvents.ON_GUARD)
		_:
			w.emit(SimEvents.B_ACTIVITY_END, {"id": activity_id})
	task_kind = T_NONE
	_start_next(w)


func _complete_loop_activity(w: SimWorld) -> void:
	w.emit(SimEvents.B_ACTIVITY_END, {"id": activity_id})
	var r := w.routine
	if w.ctx.exit_after != "" and activity_id == w.ctx.exit_after:
		exit_due = true
	r.loop_index += 1
	if r.loop_index >= w.episode.loop.size():
		if not w.ctx.loop_repeat:
			exit_due = true
		r.loop_index = 0
		r.loop_count += 1
		if w.ctx.nerves:
			w.temper.set_at_least(w, w.ctx.nerves_q)
	task_kind = T_NONE


## Start the next task: the first queued detour, else the loop activity at the loop index.
func _start_next(w: SimWorld) -> void:
	bit_until = 0
	bump_phase = BUMP_NONE
	var r := w.routine
	while r.dq_size() > 0:
		var d := r.pop_front()
		var kind := d[0]
		if kind == Routine.D_FIXUP:
			var ri := d[2]
			if ri < 0 or not w.residue.has(w.db.residue_list[ri].id):
				continue
			var st := w.db.house.stations[d[1]]
			state = DETOUR
			var did := w.db.residue_list[ri].detour_id()
			var dai := w.db.activity_idx(did)
			var flen := SimConst.FIXUP_TICKS
			if dai >= 0 and w.db.activity_list[dai].dur_ticks > 0:
				flen = w.db.activity_list[dai].dur_ticks
			_begin_task(w, T_FIXUP, dai, -1, d[1], st.room_idx, st.stand_sub, st.facing, flen, did)
			task_residue = ri
			task_why = w.db.residue_list[ri].id
			return
		if kind == Routine.D_CURIOUS:
			state = CURIOUS
			var look := d[4] if d[4] > 0 else SimConst.CURIOUS_LOOK_TICKS
			_begin_task(w, T_CURIOUS, w.db.activity_idx("curious"), -1, -1, d[1], d[2], facing, look, "curious")
			task_why = Routine.WHY_NAMES[clampi(d[3], 0, Routine.WHY_NAMES.size() - 1)]
			return
	if exit_due:
		state = ROUTINE
		if w.ctx.exit_room >= 0:
			_begin_task(w, T_EXIT, w.db.activity_idx("exit"), -1, -1, w.ctx.exit_room, w.ctx.exit_x, facing, -1, "exit")
		else:
			_begin_task(w, T_EXIT, -1, -1, -1, room, x_sub, facing, -1, "exit")
		return
	var n := w.episode.loop.size()
	if n == 0:
		state = ROUTINE
		task_kind = T_NONE
		return
	var li := r.loop_index % n
	var le: EpisodeDef.LoopEntry = w.episode.loop[li]
	if le.act_idx < 0:
		state = ROUTINE
		task_kind = T_NONE
		return
	var a := w.db.activity_list[le.act_idx]
	var sti := a.station_idx
	var troom := room
	var tx := x_sub
	var tf := facing
	if sti >= 0:
		var st := w.db.house.stations[sti]
		troom = st.room_idx
		tx = st.stand_sub
		tf = a.facing if a.facing != 0 else st.facing
	if a.path.size() == 2:
		tx = a.path[0]
	var gated := le.has_gate and not (le.first_loop_only and r.loop_count > 0)
	state = ROUTINE
	_begin_task(w, T_ACTIVITY, a.idx, li, sti, troom, tx, tf, -1 if gated else a.dur_ticks, a.id)


func _begin_task(w: SimWorld, kind: int, act: int, loop_i: int, station: int, troom: int, tx: int, tf: int,
		length: int, id: String) -> void:
	task_kind = kind
	task_act = act
	task_loop = loop_i
	task_station = station
	task_room = troom
	task_x = tx
	task_facing = tf
	task_residue = -1
	task_why = ""
	activity_id = id
	activity_len = length
	activity_t = 0
	phase = PH_WALK
	hook_cursor = 0
	gate_met_t = -1
	_path_to(w, troom, tx, SimConst.MOVER_B_WALK)
	_refresh_next(w)


func _path_to(w: SimWorld, troom: int, tx: int, mover: int) -> void:
	var p := w.db.nav.path(room, x_sub, troom, tx, mover)
	if not p.ok:
		p = w.db.nav.path(room, x_sub, room, x_sub, mover)
	path_serial += 1
	p.serial = path_serial
	p.facing = facing
	path = p


## Leave the current task because a reaction, chase or curious detour takes over.
func interrupt(w: SimWorld, resume: bool) -> void:
	int_kind = INT_NONE
	w.bits.cancel_mirror()
	match task_kind:
		T_ACTIVITY:
			if phase == PH_PERFORM:
				if resume:
					int_kind = INT_RESUME
					resume_loop = task_loop
					resume_t = activity_t
					resume_cursor = hook_cursor
					resume_len = activity_len
					resume_gate = gate_met_t
				else:
					_complete_loop_activity(w)
					int_kind = INT_DONE
			else:
				int_kind = INT_WALK
		T_FIXUP:
			if task_residue >= 0:
				w.routine.push_front(Routine.D_FIXUP, task_station, task_residue, 0, 0)
			int_kind = INT_WALK
		_:
			int_kind = INT_WALK
	if state == CHASE:
		int_kind = INT_CHASE
	task_kind = T_NONE
	path = null
	bump_phase = BUMP_NONE
	bit_until = 0


## After a reaction (or chase trip) ends with nothing else queued.
func after_reaction(w: SimWorld) -> void:
	if int_kind == INT_CHASE:
		int_kind = INT_NONE
		on_guard_until = w.tick + SimConst.ON_GUARD_TICKS
		w.emit(SimEvents.ON_GUARD)
	if int_kind == INT_RESUME and resume_loop >= 0:
		var le: EpisodeDef.LoopEntry = w.episode.loop[resume_loop]
		var a := w.db.activity_list[le.act_idx]
		var st := w.db.house.stations[a.station_idx]
		state = ROUTINE
		task_kind = T_ACTIVITY
		task_act = a.idx
		task_loop = resume_loop
		task_station = a.station_idx
		task_room = st.room_idx
		task_x = st.stand_sub if a.path.size() != 2 else x_sub
		task_facing = a.facing if a.facing != 0 else st.facing
		activity_id = a.id
		phase = PH_WALK
		if room == task_room and x_sub == task_x:
			_arrive(w)
		else:
			_path_to(w, task_room, task_x, SimConst.MOVER_B_WALK)
		_refresh_next(w)
		return
	int_kind = INT_NONE
	_start_next(w)


## Queue a fix-up detour (Residue) and show it in the bubble the same tick.
func queue_fixup(w: SimWorld, residue_i: int, station: int) -> void:
	w.routine.push_back(Routine.D_FIXUP, station, residue_i, 0, 0)
	var r := w.db.residue_list[residue_i]
	w.emit(SimEvents.B_DETOUR, {"kind": r.detour_id(), "station": w.db.house.stations[station].id, "why": r.id})
	_refresh_next(w, true)


## A lure, noise or near miss: go Curious toward (room, x) now (queued if he can't break off).
func queue_curious(w: SimWorld, troom: int, tx: int, why: int, look: int) -> void:
	if state == CURIOUS and task_kind == T_CURIOUS:
		task_room = troom
		task_x = tx
		activity_len = look
		if phase == PH_PERFORM:
			phase = PH_WALK
			activity_t = 0
		_path_to(w, troom, tx, SimConst.MOVER_B_WALK)
		return
	w.emit(SimEvents.B_DETOUR, {"kind": "curious", "station": "", "why": Routine.WHY_NAMES[why]})
	if state == ROUTINE or state == DETOUR or state == SEARCH:
		interrupt(w, false)
		w.routine.push_front(Routine.D_CURIOUS, troom, tx, why, look)
		_start_next(w)
	else:
		w.routine.push_front(Routine.D_CURIOUS, troom, tx, why, look)
	_refresh_next(w, true)


## Spotted: the "!" double take, then the chase.
func on_spotted(w: SimWorld) -> void:
	interrupt(w, false)
	state = SPOTTED
	spotted_t = SimConst.SPOTTED_TICKS
	if w.hush.x_sub != x_sub and w.hush.room == room:
		facing = Fx.signi(w.hush.x_sub - x_sub)


## Hush just dived into a hiding spot.
func on_hush_hidden(w: SimWorld, spot: int) -> void:
	if (state == ROUTINE) and task_kind == T_ACTIVITY and phase == PH_PERFORM and task_act >= 0:
		var a := w.db.activity_list[task_act]
		if a.in_use_idx == spot:
			w.senses.start_f2f(w, spot, Senses.F2F_HIDING)


## Start a Search at his position (after a lost chase).
func start_search(w: SimWorld) -> void:
	state = SEARCH
	_begin_task(w, T_SEARCH, w.db.activity_idx("search"), -1, -1, room, x_sub, facing, SimConst.SEARCH_TICKS, "search")
	path = null
	phase = PH_PERFORM
	w.emit(SimEvents.SEARCH)
	w.emit(SimEvents.B_ACTIVITY, {"id": "search"})


# --- caught ---------------------------------------------------------------------------------------

## Caught (grab, pull-out or a lost face-to-face).
func start_caught(w: SimWorld, cause: String) -> void:
	if state == CAUGHT_HOLD:
		return
	if state != CHASE and state != SPOTTED:
		interrupt(w, false)
	path = null
	state = CAUGHT_HOLD
	caught_t = 0
	caught_cause = cause
	catches += 1
	w.emit(SimEvents.CAUGHT, {"cause": cause, "spotted_tick": w.senses.spotted_tick, "by": "bellows"})
	w.emit(SimEvents.BUSTED_CAM)
	w.hush.on_caught(w)
	w.scoring.add(w, -SimConst.CATCH_PENALTY, "catch", "caught")
	w.temper.end_running_gag(w)
	on_guard_until = w.tick + SimConst.ON_GUARD_TICKS
	w.senses.reset_meter(w)


func _update_caught(w: SimWorld) -> void:
	caught_t += 1
	if caught_t == SimConst.CAUGHT_BUSTED:
		w.emit(SimEvents.LECTURE, {"variant": (catches - 1) % SimConst.LECTURE_VARIANTS})
	if caught_t == SimConst.CAUGHT_DOORSTEP_AT:
		w.hush.place_doorstep(w)
		w.emit(SimEvents.DOORSTEP)
		tomatoes += 1
		w.emit(SimEvents.TOMATO, {"n": tomatoes})
	if caught_t >= SimConst.CAUGHT_HOLD:
		w.hush.release(w)
		if w.ctx.tomatoes_max >= 0 and tomatoes >= w.ctx.tomatoes_max:
			w.emit(SimEvents.HOOK)
			w.end_night("hook")
			return
		_start_next(w)


# --- meltdown -------------------------------------------------------------------------------------

## Temper ≥ 100 at a reaction end (GDD §4.5).
func start_meltdown(w: SimWorld) -> void:
	if int_kind == INT_RESUME:
		# a tantrum ends the activity he would have resumed
		_complete_loop_activity(w)
	int_kind = INT_NONE
	state = MELTDOWN
	melt_t = 0
	meltdowns += 1
	w.emit(SimEvents.MELTDOWN_START)
	w.temper.add_link(w)
	w.scoring.meltdown(w)
	w.goals.dirty = true
	for pi in w.ctx.quake_pranks:
		var p := w.db.prank_list[pi]
		if w.pranks.state[pi] == Pranks.RIGGED and w.room_idx(p.trig_room) == room \
				and Conditions.prank_conditions(w, p.conditions, pi):
			w.pranks.queue_pending(w, pi, "quake")


func _update_meltdown(w: SimWorld) -> void:
	melt_t += 1
	for i in SimConst.MELTDOWN_STOMPS.size():
		if melt_t == SimConst.MELTDOWN_STOMPS[i]:
			w.emit(SimEvents.MELTDOWN_STOMP, {"n": i + 1})
	if melt_t >= SimConst.MELTDOWN_TICKS:
		w.temper.set_temper(w, SimConst.MELTDOWN_RESET * SimConst.TEMPER_Q)
		if w.pranks.fire_pending(w, true):
			return
		start_exhausted(w)


## Exhausted (8 s, sight 150 px).
func start_exhausted(w: SimWorld) -> void:
	state = EXHAUSTED
	exhaust_t = SimConst.EXHAUSTED_TICKS
	exhaust_after = false
	w.emit(SimEvents.EXHAUSTED)


# --- derived / bubble -----------------------------------------------------------------------------

func _update_derived(w: SimWorld) -> void:
	var a: ActivityDef = w.db.activity_list[task_act] if task_act >= 0 and task_kind == T_ACTIVITY else null
	var performing := phase == PH_PERFORM and (state == ROUTINE) and a != null
	asleep = performing and a.awareness == ActivityDef.AWARE_ASLEEP
	var s := false
	if not asleep:
		if performing and (a.specs or a.awareness == ActivityDef.AWARE_SEARCHING):
			s = true
		elif state == CURIOUS or state == SEARCH or state == CHASE:
			s = true
		elif w.tick < on_guard_until or tier >= SimConst.TIER_LIVID_ID:
			s = true
	specs_on = s
	if specs_on != last_specs:
		last_specs = specs_on
		w.emit(SimEvents.SPECS, {"on": specs_on})
	if w.residue.blinded():
		# a blinding residue keeps `blinded_until` just ahead so readers of either field agree
		blinded_until = maxi(blinded_until, w.tick + 1)
	blinded = w.tick < blinded_until
	w.bits.update_pips(w)
	var g := _compute_glyph(w)
	if g != glyph:
		glyph = g
		w.emit(SimEvents.GLYPH, {"id": g})
	_refresh_next(w)


func _compute_glyph(w: SimWorld) -> String:
	if state == REACTING or state == MELTDOWN or state == CAUGHT_HOLD:
		return GLYPH_STARS
	if asleep:
		return GLYPH_ASLEEP
	if blinded or state == EXHAUSTED:
		return GLYPH_BLINDED
	if specs_on:
		return GLYPH_SPECS_ON
	return GLYPH_SPECS_OFF


func _refresh_next(w: SimWorld, force: bool = false) -> void:
	var nid := _next_id(w)
	if nid != last_next_id or force:
		last_next_id = nid
		w.emit(SimEvents.B_NEXT, {"id": nid, "detour": w.routine.dq_size() > 0})


func _next_id(w: SimWorld) -> String:
	var r := w.routine
	if task_kind == T_EXIT:
		return "exit"
	if phase == PH_WALK and (task_kind == T_FIXUP or task_kind == T_CURIOUS) and state != REACTING:
		return activity_id
	if r.dq_size() > 0:
		var d := r.peek(0)
		if d[0] == Routine.D_FIXUP and d[2] >= 0:
			return w.db.residue_list[d[2]].detour_id()
		if d[0] == Routine.D_CURIOUS:
			return "curious"
	var n := w.episode.loop.size()
	if n == 0:
		return ""
	var li := r.loop_index % n
	if task_kind == T_ACTIVITY and task_loop == li and phase == PH_PERFORM:
		li = (li + 1) % n
	return w.episode.loop[li].activity


## {next, icon, ring_ticks, glyph, ear_pips, detour}
func bubble(w: SimWorld) -> Dictionary:
	var nid := _next_id(w)
	var icon := ""
	var a: ActivityDef = w.db.activities.get(nid, null)
	if a != null:
		icon = a.icon
	var ring := -1
	if phase == PH_PERFORM and activity_len >= 0 and (state == ROUTINE or state == DETOUR or state == CURIOUS or state == SEARCH):
		var rem := activity_len - activity_t
		if rem >= 0 and rem <= SimConst.RING_TICKS:
			ring = rem
	return {"next": nid, "icon": icon, "ring_ticks": ring, "glyph": glyph, "ear_pips": ear_pips,
		"detour": a != null and a.is_detour}


## [room, x_sub, ...] every 10 ticks for `ticks` ticks along his current walk.
func path_preview(_w: SimWorld, ticks: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var samples := maxi(1, Fx.div(ticks, 10))
	if path == null or not (state == ROUTINE or state == DETOUR or state == CURIOUS or state == CHASE):
		for i in samples:
			out.append(room)
			out.append(x_sub)
		return out
	var p := path.duplicate_path()
	for i in samples:
		for k in 10:
			if p.is_done():
				break
			p.advance()
		out.append(p.room)
		out.append(p.x)
	return out


# --- clone / hash ---------------------------------------------------------------------------------

## Deep copy.
func copy() -> SimBellows:
	var o := SimBellows.new()
	for prop in _PROPS:
		o.set(prop, get(prop))
	o.residues = residues.duplicate()
	o.path = path.duplicate_path() if path != null else null
	o._db_station_ids = _db_station_ids
	return o


const _PROPS: Array[String] = ["room", "floor", "x_sub", "facing", "state", "activity_id", "activity_t",
	"activity_len", "specs_on", "blinded_until", "blinded", "temper_q", "tier", "spot_meter", "spot_fill",
	"ear_pips", "bump_count", "look_back_until", "asleep", "on_guard_until", "link", "tomatoes", "meltdowns",
	"catches", "glyph", "blind_after_until", "task_kind", "task_loop", "task_act", "task_station", "task_room",
	"task_x", "task_facing", "task_residue", "task_why", "phase", "hook_cursor", "gate_met_t", "path_serial",
	"warn_serial", "warn_leg", "warn_room", "warn_tick", "bit_until", "head_turn_until", "head_turn_dir",
	"stun_until", "spotted_t", "melt_t", "exhaust_t", "caught_t", "caught_cause", "bump_phase", "bump_t",
	"look_t", "int_kind", "exit_due", "resume_loop", "resume_t", "resume_cursor", "resume_len", "resume_gate",
	"exhaust_after", "rx_prank", "rx_prank_id", "rx_archetype", "rx_variant", "rx_key", "rx_tier",
	"rx_suppressed", "rx_t", "rx_len", "rx_entry", "rx_accent", "rx_knock_f", "rx_accented", "rx_trig",
	"rx_link", "rx_knock_from", "rx_has_travel", "rx_from_f", "rx_to_f", "rx_x0", "rx_x1", "rx_room0",
	"rx_room1", "rx_room1_id", "rx_ease", "rx_end_place", "last_next_id", "last_specs", "last_step_px",
	"visit_bits"]


## Mix into a state hash.
func hash_into(h: int) -> int:
	for prop in _PROPS:
		var v: Variant = get(prop)
		match typeof(v):
			TYPE_INT:
				h = StateHash.mix(h, v)
			TYPE_BOOL:
				h = StateHash.mix_bool(h, v)
			TYPE_STRING:
				h = StateHash.mix_str(h, v)
	for s in residues:
		h = StateHash.mix_str(h, s)
	if path != null:
		h = path.hash_into(h)
	return h
