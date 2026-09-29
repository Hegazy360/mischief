## Temper — hold, decay, tiers, the Running Gag (TECH §3.7.6, GDD §4.5).
##
## `bellows.temper_q` is points × 60: gains land at a reaction's accent, hold 360 ticks from the latest
## gain, then fall 2 q per tick (2 points/s). Hold and decay pause while he is REACTING, in a MELTDOWN or on
## a fix-up detour. The Running Gag is live while temper ≥ 20: each prank landing while live is link + 1
## (the prank that starts it is link 1); a Meltdown is a link; falling below 20 ends it.
class_name Temper
extends RefCounted

var hold_left: int = 0
var last_tier: int = 0


## Step 7 of the tick.
func update(w: SimWorld) -> void:
	var b := w.bellows
	if not _paused(b):
		if hold_left > 0:
			hold_left -= 1
		elif b.temper_q > 0:
			b.temper_q = maxi(0, b.temper_q - SimConst.DECAY_Q_PER_TICK)
	_sync_tier(w)
	if b.link > 0 and b.temper_q < SimConst.TIER_IRKED * SimConst.TEMPER_Q:
		end_running_gag(w)


func _paused(b: SimBellows) -> bool:
	return b.state == SimBellows.REACTING or b.state == SimBellows.MELTDOWN \
		or (b.state == SimBellows.DETOUR and b.task_kind == SimBellows.T_FIXUP)


func _sync_tier(w: SimWorld) -> void:
	var b := w.bellows
	b.tier = SimConst.tier_of(b.temper_q)
	if b.tier != last_tier:
		last_tier = b.tier
		w.emit(SimEvents.TEMPER_TIER, {"tier": SimConst.TIER_NAMES[b.tier]})


## Add temper (q units) and restart the hold.
func gain(w: SimWorld, q: int) -> void:
	w.bellows.temper_q += q
	hold_left = SimConst.HOLD_TICKS
	_sync_tier(w)


## Set temper exactly (Meltdown reset) and restart the hold.
func set_temper(w: SimWorld, q: int) -> void:
	w.bellows.temper_q = maxi(0, q)
	hold_left = SimConst.HOLD_TICKS
	_sync_tier(w)


## Raise temper to at least `q` (opening-night nerves); a raise restarts the hold.
func set_at_least(w: SimWorld, q: int) -> void:
	if w.bellows.temper_q < q:
		w.bellows.temper_q = q
		hold_left = SimConst.HOLD_TICKS
		_sync_tier(w)


## Link the next landing prank will be: link + 1 while live (temper ≥ 20), else 1.
func next_link(w: SimWorld) -> int:
	var b := w.bellows
	return b.link + 1 if b.temper_q >= SimConst.TIER_IRKED * SimConst.TEMPER_Q else 1


## A landing prank (at its accent) becomes link `n`.
func set_link(w: SimWorld, n: int) -> void:
	var b := w.bellows
	b.link = n
	w.goals.note_link(n)
	w.emit(SimEvents.RUNNING_GAG, {"link": n, "mult": SimConst.mult_for_link(n)})


## A Meltdown counts as a link.
func add_link(w: SimWorld) -> void:
	set_link(w, w.bellows.link + 1)


## The Running Gag ends (temper < 20 or a catch).
func end_running_gag(w: SimWorld) -> void:
	if w.bellows.link > 0:
		w.bellows.link = 0
		w.emit(SimEvents.RUNNING_GAG_END)


## Fuse: remaining hold + (temper − 20) / 2 s, in ticks; 0 when the Running Gag is not live.
func fuse_ticks(w: SimWorld) -> int:
	var b := w.bellows
	var over := b.temper_q - SimConst.TIER_IRKED * SimConst.TEMPER_Q
	if b.link <= 0 or over < 0:
		return 0
	return hold_left + Fx.div(over, SimConst.DECAY_Q_PER_TICK)


## Deep copy.
func copy() -> Temper:
	var o := Temper.new()
	o.hold_left = hold_left
	o.last_tier = last_tier
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	h = StateHash.mix(h, hold_left)
	return StateHash.mix(h, last_tier)
