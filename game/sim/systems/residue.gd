## Residue — residue kinds, fix-up routing and combos (TECH §3.7.5, GDD §5.4).
##
## A new kind queues one fix-up detour (shown in the bubble the same tick) to the nearest station of its
## fix-up kind on his floor by path (episode `fixup_overrides` first — by residue kind or fix-up kind; ties
## by station id). Completing the fix-up clears that residue; a prank firing during it interrupts it (the
## residue stays, the fix-up is re-queued). A `blind` residue (FRAZZLED from ACHOO-RIA!) blinds him until
## cleared. Combos fire once per Night when all their residues are present.
class_name Residue
extends RefCounted

## Current kinds, sorted.
var kinds: PackedStringArray = PackedStringArray()
## 1 when kinds[i] blinds him.
var blind: PackedByteArray = PackedByteArray()
## Per combo idx: 1 once formed this Night.
var combo_done: PackedByteArray = PackedByteArray()


## A prank landed: clears first, then its residues.
func on_prank_landed(w: SimWorld, pd: PrankDef) -> void:
	for k in pd.clears:
		clear(w, k)
	for r in pd.residue:
		add(w, str(r["kind"]), bool(r["blind"]))
		var bt := int(r.get("blind_ticks", 0))
		if bt > 0:
			w.bellows.blinded_until = maxi(w.bellows.blinded_until, w.tick + bt)


## True when the kind is on him.
func has(kind: String) -> bool:
	return kinds.has(kind)


## True when some residue blinds him.
func blinded() -> bool:
	for v in blind:
		if v == 1:
			return true
	return false


## Add a residue kind.
func add(w: SimWorld, kind: String, is_blind: bool) -> void:
	var i := kinds.find(kind)
	if i >= 0:
		if is_blind:
			blind[i] = 1
		return
	var at := kinds.bsearch(kind)
	kinds.insert(at, kind)
	blind.insert(at, 1 if is_blind else 0)
	w.bellows.residues = kinds.duplicate()
	w.emit(SimEvents.RESIDUE_ADD, {"kind": kind})
	var ri := w.db.residue_idx(kind)
	if ri >= 0:
		var st := fixup_station(w, kind)
		if st >= 0:
			w.bellows.queue_fixup(w, ri, st)
	_check_combos(w)


## Remove a residue kind (fix-up done, or cleared by a prank).
func clear(w: SimWorld, kind: String) -> void:
	var i := kinds.find(kind)
	if i < 0:
		return
	kinds.remove_at(i)
	blind.remove_at(i)
	w.bellows.residues = kinds.duplicate()
	w.emit(SimEvents.RESIDUE_CLEAR, {"kind": kind})
	var ri := w.db.residue_idx(kind)
	if ri >= 0:
		w.routine.remove_fixups_for(ri)


func _check_combos(w: SimWorld) -> void:
	if combo_done.size() != w.db.combo_list.size():
		combo_done.resize(w.db.combo_list.size())
	for c in w.db.combo_list:
		if combo_done[c.idx] == 1 or c.of.is_empty():
			continue
		# `rules.combos` (ruling L4): a disallowed pair simply keeps both residues — no combo, no score
		if c.idx < w.ctx.combo_ok.size() and w.ctx.combo_ok[c.idx] == 0:
			continue
		var all := true
		for k in c.of:
			if not kinds.has(k):
				all = false
				break
		if all:
			combo_done[c.idx] = 1
			w.emit(SimEvents.COMBO, {"id": c.id})
			w.scoring.combo(w)
			w.goals.dirty = true


## Station idx for a residue's fix-up (-1 if none exists).
func fixup_station(w: SimWorld, kind: String) -> int:
	var rd: ResidueDef = w.db.residues.get(kind, null)
	if rd == null:
		return -1
	var house := w.db.house
	var ov: Variant = w.episode.fixup_overrides.get(kind, w.episode.fixup_overrides.get(rd.fixup, null))
	if ov != null:
		var si: int = house.station_index.get(str(ov), -1)
		if si >= 0:
			return si
	var cands: PackedInt32Array = house.stations_by_kind.get(rd.fixup, PackedInt32Array())
	var b := w.bellows
	var best := -1
	var best_cost := 1 << 40
	# passes: his floor among the Night's rooms + backstage, any floor among them, then (no such station at
	# all — a content error the lint reports) anywhere, so a residue never stays for good
	for pass_i in 4:
		for si in cands:
			var st := house.stations[si]
			if st.room_idx < 0:
				continue
			if pass_i < 2 and not w.ctx.fixup_room_ok(st.room_idx):
				continue
			if (pass_i == 0 or pass_i == 2) and house.rooms[st.room_idx].floor != b.floor:
				continue
			var c := w.db.nav.cost(b.room, b.x_sub, st.room_idx, st.stand_sub, SimConst.MOVER_B_WALK)
			if c >= 0 and c < best_cost:
				best_cost = c
				best = si
		if best >= 0:
			return best
	return best


## True when combo `id` formed this Night.
func combo_formed(w: SimWorld, id: String) -> bool:
	var c: ComboDef = w.db.combos.get(id, null)
	return c != null and c.idx < combo_done.size() and combo_done[c.idx] == 1


## Deep copy.
func copy() -> Residue:
	var o := Residue.new()
	o.kinds = kinds.duplicate()
	o.blind = blind.duplicate()
	o.combo_done = combo_done.duplicate()
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for k in kinds:
		h = StateHash.mix_str(h, k)
	for v in blind:
		h = StateHash.mix(h, v)
	for v in combo_done:
		h = StateHash.mix(h, v)
	return h
