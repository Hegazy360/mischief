## Pranks — prank states, rig steps, items + restock, triggers, fizzles, pending punchlines (TECH §3.7.4).
##
## PrankState: LOCKED → AVAILABLE → IN_PROGRESS → RIGGED → FIRED → LANDED. Available = in this Night
## (Script lines, Double Acts, `nights`) and not sealed (Big Number-only pranks unseal at ★).
## Steps persist their progress (ticks into the current step; per-mille via `progress_pm`).
## Triggers: USE hooks at marks (SimBellows), fix-up hooks at fix-up tick 60, STEP pranks walked over
## (`chase: true` also mid-chase = a Chase Trip), QUAKE pranks queued by a Meltdown in their room,
## knock-ons (Reactions), third-party (Stage 3, inactive). Conditions false → `fizzle` if defined (stays
## RIGGED). One punchline at a time: a trigger while he is reacting waits in `pending`.
class_name Pranks
extends RefCounted

const LOCKED := 0
const AVAILABLE := 1
const IN_PROGRESS := 2
const RIGGED := 3
const FIRED := 4
const LANDED := 5
const STATE_NAMES: Array[String] = ["LOCKED", "AVAILABLE", "IN_PROGRESS", "RIGGED", "FIRED", "LANDED"]

const ITEM_HOME := 0
const ITEM_CARRIED := 1
const ITEM_RESTOCKING := 2

var state: PackedInt32Array = PackedInt32Array()
var step: PackedInt32Array = PackedInt32Array()
var prog: PackedInt32Array = PackedInt32Array()
var item_state: PackedInt32Array = PackedInt32Array()
var restock_at: PackedInt32Array = PackedInt32Array()
var restocking: int = 0
var pending: PackedInt32Array = PackedInt32Array()
var pending_trig: PackedStringArray = PackedStringArray()
var first_rig_tick: int = -1
var landed: int = 0
var chase_trips: int = 0
## Per prank idx: 1 once it fired as a Chase Trip.
var trip_flag: PackedByteArray = PackedByteArray()
## Per double act idx: 1 once A knocked on into B and B landed.
var da_done: PackedByteArray = PackedByteArray()
## Per prank idx: 1 once its gag scored (a re-armed prank scores once per Night).
var scored: PackedByteArray = PackedByteArray()


## Initial states for the Night.
func setup(w: SimWorld) -> void:
	var np := w.db.prank_list.size()
	state.resize(np)
	step.resize(np)
	prog.resize(np)
	trip_flag.resize(np)
	scored.resize(np)
	for i in np:
		step[i] = 0
		prog[i] = 0
		trip_flag[i] = 0
		scored[i] = 0
		if w.ctx.prank_in_ep[i] == 1 and w.ctx.prank_bn_only[i] == 0 and not w.db.prank_list[i].steps.is_empty():
			state[i] = AVAILABLE
		else:
			state[i] = LOCKED
	var ni := w.db.item_list.size()
	item_state.resize(ni)
	restock_at.resize(ni)
	for i in ni:
		item_state[i] = ITEM_HOME
		restock_at[i] = 0
	da_done.resize(w.db.double_act_list.size())
	for i in da_done.size():
		da_done[i] = 0


## The Big Number unsealed: its pranks become available.
func unseal_bn(w: SimWorld) -> void:
	for i in state.size():
		if w.ctx.prank_bn_only[i] == 1 and state[i] == LOCKED and not w.db.prank_list[i].steps.is_empty():
			state[i] = AVAILABLE
	if w.ctx.bn_line >= 0:
		for pid in w.episode.script_lines[w.ctx.bn_line].rearm_on_unseal:
			var pi := w.db.prank_idx(pid)
			if pi >= 0 and state[pi] == LANDED:
				state[pi] = AVAILABLE
				step[pi] = 0
				prog[pi] = 0


# --- rigging --------------------------------------------------------------------------------------

## The prank Hush can rig at rig point `hs` right now (its current step is there), -1 if none.
func rig_target(w: SimWorld, hs: int) -> int:
	if hs < 0 or hs >= w.db.pranks_at_hs.size():
		return -1
	for pi in w.db.pranks_at_hs[hs]:
		var s := state[pi]
		if s != AVAILABLE and s != IN_PROGRESS:
			continue
		var p := w.db.prank_list[pi]
		var si := step[pi]
		if si < p.steps.size() and p.steps[si].at_idx == hs:
			return pi
	return -1


## Mark a prank in progress (Hush started its ring).
func begin_rig(_w: SimWorld, p: int) -> void:
	if state[p] == AVAILABLE:
		state[p] = IN_PROGRESS


## One tick of ring progress; returns the ticks done on the current step.
func add_progress(_w: SimWorld, p: int) -> int:
	prog[p] += 1
	return prog[p]


## Per-mille of the current step (1000 once rigged).
func progress_pm(w: SimWorld, p: int) -> int:
	var s := state[p]
	if s >= RIGGED:
		return 1000
	var pd := w.db.prank_list[p]
	var si := step[p]
	if si >= pd.steps.size():
		return 1000
	return mini(1000, Fx.div(prog[p] * 1000, maxi(1, pd.steps[si].prep_ticks)))


## The current step completed.
func complete_step(w: SimWorld, p: int) -> void:
	var pd := w.db.prank_list[p]
	w.emit(SimEvents.RIG_STEP_DONE, {"prank": pd.id, "step": step[p]})
	step[p] += 1
	prog[p] = 0
	if step[p] >= pd.steps.size():
		state[p] = RIGGED
		if first_rig_tick < 0:
			first_rig_tick = w.tick
		w.emit(SimEvents.RIGGED, {"prank": pd.id})
	w.goals.dirty = true


# --- items ----------------------------------------------------------------------------------------

## Items of this Night in stock at a container (sorted ids).
func container_stock(w: SimWorld, cont: int) -> PackedStringArray:
	var out := PackedStringArray()
	if cont < 0:
		return out
	for it in w.db.item_list:
		if it.source_idx == cont and w.ctx.item_in_ep[it.idx] == 1 and item_state[it.idx] == ITEM_HOME:
			out.append(it.id)
	return out


## Hush picked the item up.
func item_carried(w: SimWorld, item: String) -> void:
	var i := w.db.item_idx(item)
	if i >= 0:
		if item_state[i] == ITEM_RESTOCKING:
			restocking -= 1
		item_state[i] = ITEM_CARRIED


## The item flies home (tray overflow, caught): back in stock at once.
func item_home(w: SimWorld, item: String) -> void:
	var i := w.db.item_idx(item)
	if i < 0:
		return
	if item_state[i] == ITEM_RESTOCKING:
		restocking -= 1
	item_state[i] = ITEM_HOME
	w.emit(SimEvents.ITEM_HOME, {"item": item})


## The item was used up on a rig: it restocks RESTOCK_TICKS later.
func item_used(w: SimWorld, item: String) -> void:
	var i := w.db.item_idx(item)
	if i < 0:
		return
	if item_state[i] != ITEM_RESTOCKING:
		restocking += 1
	item_state[i] = ITEM_RESTOCKING
	restock_at[i] = w.tick + SimConst.RESTOCK_TICKS


## Per tick (Hush update, "carried items").
func update_restock(w: SimWorld) -> void:
	if restocking <= 0:
		return
	for it in w.db.item_list:
		var i := it.idx
		if item_state[i] == ITEM_RESTOCKING and restock_at[i] <= w.tick:
			item_state[i] = ITEM_HOME
			restocking -= 1
			w.emit(SimEvents.RESTOCK, {"item": it.id, "container": it.source})


# --- triggers -------------------------------------------------------------------------------------

## A USE hook (or fix-up hook) reached its mark. Returns true when the prank fired (or a stand-in began).
func on_hook(w: SimWorld, p: int, trig: String) -> bool:
	if state[p] != RIGGED:
		return false
	var b := w.bellows
	if b.state == SimBellows.REACTING or b.state == SimBellows.MELTDOWN or w.bits.mirror_active:
		queue_pending(w, p, trig)
		return false
	var pd := w.db.prank_list[p]
	if not Conditions.prank_conditions(w, pd.conditions, p):
		if pd.has_fizzle():
			_fizzle(w, pd)
		return false
	if Conditions.is_stand_in(pd):
		w.bits.start_mirror(w, p)
		return true
	fire(w, p, trig)
	return true


## Fix-up hooks at a station for a fix-up kind (fix-up tick 60).
func fixup_hooks(w: SimWorld, station: int, kind: String) -> void:
	if station < 0 or kind == "":
		return
	for p in w.db.fixup_hooks[station]:
		var pd := w.db.prank_list[p]
		if pd.trig_fixup_kinds.has(kind):
			on_hook(w, p, "fixup")


## STEP pranks walked over between (oroom, ox) and (nroom, nx). Returns true when one fired.
func check_step(w: SimWorld, oroom: int, ox: int, nroom: int, nx: int, flags: int, chasing: bool) -> bool:
	if w.ctx.step_pranks.is_empty():
		return false
	var house := w.db.house
	for p in w.ctx.step_pranks:
		if state[p] != RIGGED:
			continue
		var pd := w.db.prank_list[p]
		if chasing and not pd.trig_chase:
			continue
		if pd.trig_at_idx < 0:
			continue
		var h := house.hotspots[pd.trig_at_idx]
		var hit := false
		match pd.trig_dir:
			PrankDef.DIR_UP, PrankDef.DIR_DOWN:
				if (flags & NavPath.F_STAIRS) and oroom == h.room_idx and nroom >= 0:
					var f0 := house.rooms[oroom].floor
					var f1 := house.rooms[nroom].floor
					hit = f1 > f0 if pd.trig_dir == PrankDef.DIR_UP else f1 < f0
			_:
				if oroom == h.room_idx and ox != nx:
					var hx := h.use_sub
					hit = (ox < hx and nx >= hx) or (ox > hx and nx <= hx)
					if hit and pd.trig_dir == PrankDef.DIR_LEFT:
						hit = nx < ox
					elif hit and pd.trig_dir == PrankDef.DIR_RIGHT:
						hit = nx > ox
		if not hit:
			continue
		if not Conditions.prank_conditions(w, pd.conditions, p):
			if pd.has_fizzle():
				_fizzle(w, pd)
			continue
		var b := w.bellows
		b.room = h.room_idx
		b.floor = house.rooms[b.room].floor
		b.x_sub = h.use_sub if pd.trig_dir == PrankDef.DIR_UP or pd.trig_dir == PrankDef.DIR_DOWN else nx
		b.path = null
		if chasing:
			chase_trips += 1
			trip_flag[p] = 1
			w.emit(SimEvents.CHASE_END, {"why": "trip"})
			w.goals.dirty = true
		fire(w, p, "step")
		return true
	return false


## Fire a prank (FIRED → its reaction). `entry` < 0 = the knock-on entry (accent − 2);
## `tier_override` > 0 forces the reaction tier (Mirror, Mirror rounds).
func fire(w: SimWorld, p: int, trig: String, entry: int = 0, tier_override: int = 0, knock_from: int = -1) -> void:
	var pd := w.db.prank_list[p]
	var b := w.bellows
	state[p] = FIRED
	var lk := w.temper.next_link(w)
	var tier := tier_override if tier_override > 0 else SimConst.react_tier_of(b.temper_q)
	if b.state != SimBellows.REACTING:
		b.interrupt(w, pd.trig_resume and trig == "use")
	w.emit(SimEvents.PRANK_FIRE, {"prank": pd.id, "trigger": trig, "link": lk, "tier": tier, "witnessed": false})
	w.reactions.start(w, p, trig, entry, tier, lk, knock_from)


## A rigged prank's trigger came round with its conditions false: `fizzle` (it stays RIGGED) and his "huh?"
## one-shot (SimOneshots.FIZZLE).
func _fizzle(w: SimWorld, pd: PrankDef) -> void:
	w.bellows.fizzle_t0 = w.tick
	w.emit(SimEvents.FIZZLE, {"prank": pd.id})


## Queue a trigger that must wait for the current punchline.
func queue_pending(_w: SimWorld, p: int, trig: String) -> void:
	for i in pending.size():
		if pending[i] == p:
			return
	pending.append(p)
	pending_trig.append(trig)


## Fire the first pending trigger that is still valid. Returns true if one fired.
func fire_pending(w: SimWorld, exhaust_after: bool) -> bool:
	while pending.size() > 0:
		var p := pending[0]
		var trig := pending_trig[0]
		pending.remove_at(0)
		pending_trig.remove_at(0)
		if state[p] != RIGGED:
			continue
		var pd := w.db.prank_list[p]
		if trig != "quake" and not Conditions.prank_conditions(w, pd.conditions, p):
			if pd.has_fizzle():
				_fizzle(w, pd)
			continue
		if Conditions.is_stand_in(pd):
			continue
		fire(w, p, trig)
		w.bellows.exhaust_after = exhaust_after
		return true
	return false


# --- view helpers ---------------------------------------------------------------------------------

## TECH §3.4 hotspot_state.
func hotspot_state(w: SimWorld, id: String) -> Dictionary:
	var h := w.db.house.hotspot(id)
	if h == null:
		return {}
	var enabled := w.ctx.hush_allowed(h.room_idx) and w.ctx.is_live(h.idx)
	var d := {"kind": h.kind_name, "enabled": enabled, "stock": [], "occupant": w.hush.hidden_spot == h.idx,
		"in_use_next": false, "spent": false, "rigged": false, "needs_item": "", "seen": w.hush_can_see(id)}
	match h.kind:
		HotspotDef.CONTAINER:
			d["stock"] = Array(container_stock(w, h.idx))
		HotspotDef.HIDING:
			d["in_use_next"] = _in_use_next(w, h.idx)
		HotspotDef.RIG_POINT:
			var any := false
			var all_landed := true
			for p in w.db.prank_list:
				if w.ctx.prank_in_ep[p.idx] == 0:
					continue
				var here := p.rig_idx == h.idx
				for st in p.steps:
					if st.at_idx == h.idx:
						here = true
				if not here:
					continue
				any = true
				if state[p.idx] == RIGGED:
					d["rigged"] = true
				if state[p.idx] != LANDED:
					all_landed = false
			d["spent"] = any and all_landed
			var t := rig_target(w, h.idx)
			if t >= 0:
				d["needs_item"] = w.db.prank_list[t].steps[step[t]].needs
			d["enabled"] = enabled and (t >= 0 or bool(d["rigged"]))
	return d


func _in_use_next(w: SimWorld, spot: int) -> bool:
	var b := w.bellows
	if b.task_kind == SimBellows.T_ACTIVITY and b.task_act >= 0 and w.db.activity_list[b.task_act].in_use_idx == spot:
		return true
	var nid := b._next_id(w)
	var a: ActivityDef = w.db.activities.get(nid, null)
	return a != null and a.in_use_idx == spot


# --- clone / hash ---------------------------------------------------------------------------------

## Deep copy.
func copy() -> Pranks:
	var o := Pranks.new()
	o.state = state.duplicate()
	o.step = step.duplicate()
	o.prog = prog.duplicate()
	o.item_state = item_state.duplicate()
	o.restock_at = restock_at.duplicate()
	o.restocking = restocking
	o.pending = pending.duplicate()
	o.pending_trig = pending_trig.duplicate()
	o.first_rig_tick = first_rig_tick
	o.landed = landed
	o.chase_trips = chase_trips
	o.trip_flag = trip_flag.duplicate()
	o.da_done = da_done.duplicate()
	o.scored = scored.duplicate()
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix_arr(h, state)
	h = StateHash.mix_arr(h, step)
	h = StateHash.mix_arr(h, prog)
	h = StateHash.mix_arr(h, item_state)
	h = StateHash.mix_arr(h, restock_at)
	h = StateHash.mix_arr(h, pending)
	for s in pending_trig:
		h = StateHash.mix_str(h, s)
	h = StateHash.mix(h, first_rig_tick)
	h = StateHash.mix(h, landed)
	h = StateHash.mix(h, chase_trips)
	for v in trip_flag:
		h = StateHash.mix(h, v)
	for v in da_done:
		h = StateHash.mix(h, v)
	for v in scored:
		h = StateHash.mix(h, v)
	return h
