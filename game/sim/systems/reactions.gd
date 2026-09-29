## Reactions — the punchline: variant, tier, length, accent, travel, knock-on, end (TECH §3.7.4).
##
## `start()` picks the variant `hash(seed, prank, loop_count) % n`, the tier (T1 < 45 ≤ T2 < 70 ≤ T3, or the
## Mirror round), `suppressed` (always false until Delphine exists), the length from ReactionDef
## (`frames + hold_len × (tier_scale − 100) / 100`), travel keys and the end position. Bellows is blind
## and deaf for the duration + 60. At the accent: temper gain, Running Gag link, the gag's Applause.
## Knock-on: at `knock_on.frame` (tier-remapped), if B is RIGGED, A is truncated and B starts at its
## `accent − 2` frame. At the end: LANDED, residues (→ fix-ups, combos), line checks, then a Meltdown
## (temper ≥ 100), a pending trigger, Exhausted, or the routine. State lives in SimBellows' rx_* fields.
class_name Reactions
extends RefCounted

## Reactions running (0 or 1 — one punchline at a time).
var active_count: int = 0


## Start a prank's reaction (Pranks.fire calls this).
func start(w: SimWorld, p: int, trig: String, entry: int, tier: int, lk: int, knock_from: int = -1) -> void:
	var b := w.bellows
	var pd := w.db.prank_list[p]
	var variant := ""
	if pd.variants.size() > 0:
		var hv := StateHash.mix(StateHash.mix(StateHash.mix(StateHash.OFFSET, w.ctx.seed), p), w.routine.loop_count)
		variant = pd.variants[hv % pd.variants.size()]
	var def := w.db.reaction_for(pd, variant)
	var t := clampi(tier, 1, 3)
	var ent := entry
	if ent < 0:
		ent = maxi(0, def.accent - 2)
	b.state = SimBellows.REACTING
	b.rx_prank = p
	b.rx_prank_id = pd.id
	b.rx_archetype = pd.archetype
	b.rx_variant = variant
	b.rx_key = def.id
	b.rx_tier = t
	b.rx_suppressed = false
	b.rx_len = def.length(t, false)
	b.rx_entry = ent
	b.rx_t = ent
	b.rx_accent = def.accent
	b.rx_accented = ent > def.accent
	b.rx_trig = trig
	b.rx_link = lk
	b.rx_knock_from = knock_from
	var kf := -1
	if pd.knock_prank != "" and not pd.knock_headbutt:
		kf = pd.knock_frame if pd.knock_frame >= 0 else def.knock_on
		if kf >= 0:
			kf = def.remap(kf, t)
	b.rx_knock_f = kf
	b.rx_room0 = b.room
	b.rx_x0 = b.x_sub
	b.rx_room1 = b.room
	b.rx_x1 = b.x_sub
	var has_end := pd.end_room != ""
	if has_end:
		var r1 := w.room_idx(pd.end_room)
		if r1 >= 0:
			b.rx_room1 = r1
			var x1 := pd.end_x_sub
			if pd.end_landing != "":
				var lx := w.db.house.landing_sub(pd.end_room, pd.end_landing)
				if lx >= 0:
					x1 = lx
			if x1 < 0:
				x1 = b.x_sub if r1 == b.room else w.db.house.rooms[r1].x0_sub
			b.rx_x1 = x1
		else:
			has_end = false
	b.rx_room1_id = w.room_id(b.rx_room1)
	b.rx_has_travel = has_end and def.has_travel
	b.rx_end_place = has_end and not def.has_travel
	b.rx_from_f = def.remap(def.travel_from, t) if def.has_travel else 0
	b.rx_to_f = def.remap(def.travel_to, t) if def.has_travel else 0
	b.rx_ease = def.travel_ease_id
	active_count += 1
	w.emit(SimEvents.REACTION_START, {"prank": pd.id, "archetype": pd.archetype, "variant": variant, "tier": t,
		"suppressed": false, "len": b.rx_len, "entry": ent})
	if has_end and b.rx_room1 != b.room and b.rx_room1 == w.hush.room:
		var when := (b.rx_to_f if b.rx_has_travel else b.rx_len) - ent
		w.emit(SimEvents.ENTRY_WARNING, {"room": w.room_id(b.rx_room1), "eta": maxi(0, when)})
		b.warn_room = b.rx_room1
		b.warn_tick = w.tick


## One tick of the current reaction.
func update(w: SimWorld) -> void:
	var b := w.bellows
	b.rx_t += 1
	if not b.rx_accented and b.rx_t >= b.rx_accent:
		_accent(w)
	if b.rx_knock_f >= 0 and b.rx_t == b.rx_knock_f:
		if _knock_on(w):
			return
	if b.rx_has_travel:
		_travel(w)
	if b.rx_t >= b.rx_len:
		finish(w, -1)


func _accent(w: SimWorld) -> void:
	var b := w.bellows
	b.rx_accented = true
	var pd := w.db.prank_list[b.rx_prank]
	w.emit(SimEvents.REACTION_ACCENT, {"prank": pd.id})
	w.temper.gain(w, SimConst.gain_for_size(maxi(0, pd.size)) * SimConst.TEMPER_Q)
	w.temper.set_link(w, b.rx_link)
	if w.pranks.scored[b.rx_prank] == 0:
		w.pranks.scored[b.rx_prank] = 1
		w.scoring.gag(w, w.ctx.prank_base[b.rx_prank], b.rx_link, pd.caption)


func _knock_on(w: SimWorld) -> bool:
	var b := w.bellows
	var pd := w.db.prank_list[b.rx_prank]
	var bi := w.db.prank_idx(pd.knock_prank)
	if bi < 0 or w.pranks.state[bi] != Pranks.RIGGED:
		return false
	var bd := w.db.prank_list[bi]
	if not Conditions.prank_conditions(w, bd.conditions, bi):
		return false
	w.emit(SimEvents.KNOCK_ON, {"a": pd.id, "b": bd.id})
	if not b.rx_accented:
		_accent(w)
	finish(w, bi)
	return true


func _travel(w: SimWorld) -> void:
	var b := w.bellows
	if b.rx_t < b.rx_from_f:
		return
	if b.rx_room1 == b.rx_room0:
		if b.rx_t >= b.rx_to_f or b.rx_to_f <= b.rx_from_f:
			b.x_sub = b.rx_x1
		else:
			var pm := Fx.div((b.rx_t - b.rx_from_f) * 1000, b.rx_to_f - b.rx_from_f)
			var e := EaseI.eval_pm(b.rx_ease, pm)
			b.x_sub = b.rx_x0 + Fx.div((b.rx_x1 - b.rx_x0) * e, 1000)
		var rd := w.db.house.rooms[b.room]
		b.x_sub = clampi(b.x_sub, rd.x0_sub, rd.x1_sub)
	elif b.rx_t >= b.rx_to_f and b.room != b.rx_room1:
		_place(w, b.rx_room1, b.rx_x1)


func _place(w: SimWorld, r: int, x: int) -> void:
	var b := w.bellows
	b.x_sub = x
	if r != b.room:
		b.room = r
		b.floor = w.db.house.rooms[r].floor
		w.emit(SimEvents.B_ROOM, {"room": w.room_id(r), "chase": false})


## End the reaction (normally, or truncated by a knock-on into prank `knock_b`).
func finish(w: SimWorld, knock_b: int) -> void:
	var b := w.bellows
	var p := b.rx_prank
	var pd := w.db.prank_list[p]
	if b.rx_end_place or (b.rx_has_travel and (b.room != b.rx_room1 or b.x_sub != b.rx_x1) and knock_b < 0):
		_place(w, b.rx_room1, b.rx_x1)
	w.emit(SimEvents.REACTION_END, {"prank": pd.id})
	w.pranks.state[p] = Pranks.LANDED
	w.pranks.landed += 1
	w.residue.on_prank_landed(w, pd)
	if pd.blind_ticks > 0:
		b.blinded_until = maxi(b.blinded_until, w.tick + pd.blind_ticks)
	b.blind_after_until = w.tick + SimConst.REACT_BLIND_AFTER
	if b.rx_knock_from >= 0:
		var a_id := w.db.prank_list[b.rx_knock_from].id
		for da in w.db.double_act_list:
			if da.a == a_id and da.b == pd.id:
				w.pranks.da_done[da.idx] = 1
	w.goals.dirty = true
	active_count = 0
	var ex := b.exhaust_after
	b.exhaust_after = false
	b.rx_prank = -1
	if knock_b >= 0:
		w.pranks.fire(w, knock_b, "knock_on", -1, 0, p)
		b.exhaust_after = ex
		return
	if b.temper_q >= SimConst.TIER_MELTDOWN * SimConst.TEMPER_Q:
		b.start_meltdown(w)
		return
	if w.pranks.fire_pending(w, ex):
		return
	if ex:
		b.start_exhausted(w)
		return
	b.state = SimBellows.ROUTINE
	b.after_reaction(w)


## Deep copy.
func copy() -> Reactions:
	var o := Reactions.new()
	o.active_count = active_count
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	return StateHash.mix(h, active_count)
