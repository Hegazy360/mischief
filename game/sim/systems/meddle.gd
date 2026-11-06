## Meddle — "the house is a toybox" (GDD §5.6): a rig point that carries no prank tonight can still be
## fiddled with. Hush holds the action button for a Q prep (0.8 s) and the prop sits ASKEW (the view tilts it).
## The next time Bellows walks toward it in its room (within `NOTICE_PX`, ROUTINE / DETOUR walks only, not
## blinded) he stops for `NOTICE_TICKS` — a path pause, `AUX_NOTICE` — tuts or straightens it, and the prop is
## right again: `notice {hotspot, variant, len, vis, score}`. The first notice per prop pays +1 Applause (a
## bit), every notice adds a little temper. Nothing here changes his route, his senses or the loop order, so
## every fairness rule holds; a Night turns it off with `rules.meddle: false`.
class_name Meddle
extends RefCounted

## Per hotspot idx: 1 while the prop sits askew.
var askew: PackedByteArray = PackedByteArray()
## Per hotspot idx: 1 once its first notice paid Applause this Night.
var scored: PackedByteArray = PackedByteArray()
## Askew props right now (fast path: nothing to scan when 0).
var askew_n: int = 0
## Notices this Night (the view flavour rotates on it).
var count: int = 0
## Meddles this Night.
var meddled: int = 0


func setup(w: SimWorld) -> void:
	var n := w.db.house.hotspots.size()
	askew.resize(n)
	scored.resize(n)
	for i in n:
		askew[i] = 0
		scored[i] = 0
	askew_n = 0
	count = 0
	meddled = 0


## True when a prank of this Night has its rig point or a rig step at hotspot `hs` (whatever its state):
## tonight's props belong to the Script, not to meddling.
func has_prank_tonight(w: SimWorld, hs: int) -> bool:
	for p in w.db.prank_list:
		if w.ctx.prank_in_ep[p.idx] == 0:
			continue
		if p.rig_idx == hs:
			return true
		for st in p.steps:
			if st.at_idx == hs:
				return true
	return false


## True when Hush may start meddling with hotspot `hs` now.
func can_meddle(w: SimWorld, hs: int) -> bool:
	if not w.ctx.meddle or hs < 0 or hs >= askew.size() or askew[hs] == 1:
		return false
	var h := w.db.house.hotspots[hs]
	if h.kind != HotspotDef.RIG_POINT or not w.ctx.hush_allowed(h.room_idx):
		return false
	return not has_prank_tonight(w, hs)


## True while hotspot `hs` sits askew.
func is_askew(hs: int) -> bool:
	return hs >= 0 and hs < askew.size() and askew[hs] == 1


## Hush's hold completed: the prop sits askew.
func set_askew(w: SimWorld, hs: int) -> void:
	if askew[hs] == 1:
		return
	askew[hs] = 1
	askew_n += 1
	meddled += 1
	w.emit(SimEvents.MEDDLED, {"hotspot": w.db.house.hotspots[hs].id})


## The askew prop Bellows notices this tick (−1 none): in his room, within NOTICE_PX, ahead of him on a WALK leg
## of a ROUTINE / DETOUR walk, not blinded. Pure.
func find_notice(w: SimWorld) -> int:
	if askew_n <= 0:
		return -1
	var b := w.bellows
	if (b.state != SimBellows.ROUTINE and b.state != SimBellows.DETOUR) or b.blinded or b.path == null \
			or b.path.is_done() or b.path.current_kind() != NavPath.WALK or b.bump_phase != SimBellows.BUMP_NONE:
		return -1
	var dir := Fx.signi(b.path.xs[b.path.cursor] - b.x_sub)
	if dir == 0:
		return -1
	var reach := SimConst.NOTICE_PX * SimConst.SUB
	var best := -1
	var best_d := reach + 1
	for i in askew.size():
		if askew[i] == 0:
			continue
		var h := w.db.house.hotspots[i]
		if h.room_idx != b.room:
			continue
		var dx := h.use_sub - b.x_sub
		if dx * dir < 0 or absi(dx) > reach:
			continue
		if absi(dx) < best_d:
			best_d = absi(dx)
			best = i
	return best


## He noticed hotspot `hs`: stop, put it right, a titter if it is the first time. Call during his walk tick,
## before the path advance (the inserted pause then takes this tick).
func notice(w: SimWorld, hs: int) -> void:
	var b := w.bellows
	var h := w.db.house.hotspots[hs]
	askew[hs] = 0
	askew_n = maxi(0, askew_n - 1)
	var variant := count % SimConst.NOTICE_VARIANTS
	count += 1
	var score := 0
	if scored[hs] == 0:
		scored[hs] = 1
		score = SimConst.NOTICE_SCORE
	var d := Fx.signi(h.use_sub - b.x_sub)
	b.start_notice(w, hs, variant, d if d != 0 else b.facing)
	w.emit(SimEvents.NOTICE, {"hotspot": h.id, "variant": variant, "len": SimConst.NOTICE_TICKS,
		"vis": SimVisibility.beat_vis(w, true), "score": score})
	if score > 0:
		w.scoring.add(w, score, "bit", "notice")
	w.temper.gain(w, SimConst.GAIN_NOTICE * SimConst.TEMPER_Q)


## Deep copy.
func copy() -> Meddle:
	var o := Meddle.new()
	o.askew = askew.duplicate()
	o.scored = scored.duplicate()
	o.askew_n = askew_n
	o.count = count
	o.meddled = meddled
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in askew:
		h = StateHash.mix(h, v)
	for v in scored:
		h = StateHash.mix(h, v)
	h = StateHash.mix(h, askew_n)
	h = StateHash.mix(h, count)
	return StateHash.mix(h, meddled)
