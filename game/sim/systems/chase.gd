## Chase — chase, wheeze, search hand-off, catch radius, door slam (TECH §3.7.1, GDD §4.4, §4.6).
##
## Run 240 ticks → wheeze 90 (harmless) → run 120 → Search once Hush has been out of sight ≥ 90 ticks;
## hard cap 600 ticks. He runs at 600 px/s toward Hush while he sees her, else toward where he last saw
## her. Catch: same room, |dx| ≤ 80 px, Hush not hidden (or hidden in the spot he watched her enter →
## pull-out). Door slam: Hush passes a doorway with him chasing within 500 px → he bonks it (stun 60),
## once per chase. STEP pranks with `chase: true` on his way fire (Chase Trip). If he saw her dash onto the
## stairs or through a door a moment ago (≤ CHASE_FOLLOW_TICKS), he follows her through it.
class_name Chase
extends RefCounted

var t: int = 0
var out_of_sight: int = 0
var slammed: bool = false
var stun_until: int = 0
var last_room: int = -1
var last_x: int = 0
var repath_t: int = 0
var target_room: int = -1


## Spotted → chase.
func start(w: SimWorld) -> void:
	var b := w.bellows
	var hu := w.hush
	b.state = SimBellows.CHASE
	b.path = null
	t = 0
	out_of_sight = 0
	slammed = false
	stun_until = 0
	# he runs to where he last saw her (Senses), never to where she really is
	last_room = w.senses.last_seen_room if w.senses.last_seen_room >= 0 else hu.room
	last_x = w.senses.last_seen_x if w.senses.last_seen_room >= 0 else hu.x_sub
	if hu.is_hidden() and hu.watched_spot >= 0 and hu.hidden_spot == hu.watched_spot:
		last_room = hu.room
		last_x = w.db.house.hotspots[hu.hidden_spot].use_sub
	repath_t = 0
	target_room = -1
	out_of_sight = maxi(0, w.tick - w.senses.last_seen_tick)
	w.senses.reset_meter(w)
	w.emit(SimEvents.CHASE_START)


## One chase tick (Bellows update).
func update(w: SimWorld) -> void:
	var b := w.bellows
	var hu := w.hush
	t += 1
	if t == SimConst.CHASE_RUN1:
		w.emit(SimEvents.WHEEZE)
	if w.senses.visible:
		last_room = hu.room
		last_x = hu.x_sub
		out_of_sight = 0
	else:
		out_of_sight += 1
		# he saw her dash onto the stairs / through a door a moment ago: he follows her through
		if hu.in_transit() and hu.path != null and hu.path.cursor < hu.path.size() \
				and w.tick - w.senses.last_seen_tick <= SimConst.CHASE_FOLLOW_TICKS:
			last_room = hu.room
			last_x = hu.path.xs[hu.path.cursor]
	var phases := SimConst.CHASE_RUN1 + SimConst.CHASE_WHEEZE + SimConst.CHASE_RUN2
	if t >= SimConst.CHASE_CAP or (t >= phases and out_of_sight >= SimConst.CHASE_LOST):
		w.emit(SimEvents.CHASE_END, {"why": "lost"})
		b.start_search(w)
		return
	if t > SimConst.CHASE_RUN1 and t <= SimConst.CHASE_RUN1 + SimConst.CHASE_WHEEZE:
		return
	if w.tick < stun_until:
		return
	_move(w)
	if b.state != SimBellows.CHASE:
		return
	_catch_check(w)


func _move(w: SimWorld) -> void:
	var b := w.bellows
	var troom := last_room
	var tx := last_x
	var mid_link := b.path != null and not b.path.is_done() and b.path.current_kind() != NavPath.WALK
	if troom == b.room and not mid_link:
		b.path = null
		var dx := tx - b.x_sub
		if dx == 0:
			return
		var ox := b.x_sub
		var nx := tx if absi(dx) <= SimConst.B_CHASE else b.x_sub + SimConst.B_CHASE * Fx.signi(dx)
		b.facing = Fx.signi(dx)
		if w.pranks.check_step(w, b.room, ox, b.room, nx, 0, true):
			return
		b.x_sub = nx
		return
	repath_t -= 1
	if b.path == null or b.path.is_done() or ((troom != target_room or repath_t <= 0) and not mid_link):
		var p := w.db.nav.path(b.room, b.x_sub, troom, tx, SimConst.MOVER_B_CHASE)
		if not p.ok:
			return
		b.path_serial += 1
		p.serial = b.path_serial
		p.facing = b.facing
		b.path = p
		target_room = troom
		repath_t = SimConst.CHASE_REPATH
	b.path.speed = SimConst.B_CHASE
	var oroom := b.room
	var ox2 := b.x_sub
	var flags := b.path.advance()
	b.apply_path(w, flags, oroom, ox2, true)


func _catch_check(w: SimWorld) -> void:
	var b := w.bellows
	var hu := w.hush
	if hu.state == SimHush.CAUGHT or hu.state == SimHush.BOWING or hu.in_transit() or b.room != hu.room:
		return
	if b.path != null and not b.path.is_done() and b.path.current_kind() != NavPath.WALK:
		return
	if absi(hu.x_sub - b.x_sub) > SimConst.CATCH_PX * SimConst.SUB:
		return
	var cause := "grab"
	if hu.is_hidden() or hu.state == SimHush.DIVING:
		if hu.state == SimHush.DIVING or hu.watched_spot < 0 or hu.hidden_spot != hu.watched_spot:
			return
		cause = "pull_out"
	if w.ctx.cant_fail:
		w.senses.figgis_hook(w)
		w.emit(SimEvents.CHASE_END, {"why": "figgis"})
		b.start_search(w)
		return
	w.emit(SimEvents.CHASE_END, {"why": "caught"})
	b.start_caught(w, cause)


## Hush crossed a portal (doorway, door or stairs) this tick.
func on_hush_portal(w: SimWorld, _link: int) -> void:
	var b := w.bellows
	if b.state != SimBellows.CHASE or slammed:
		return
	var d := w.db.nav.floor_distance(b.room, b.x_sub, w.hush.room, w.hush.x_sub)
	if d < 0 or d > SimConst.DOOR_SLAM_PX * SimConst.SUB:
		return
	slammed = true
	stun_until = w.tick + SimConst.DOOR_SLAM_STUN
	w.emit(SimEvents.DOOR_SLAM)


## Deep copy.
func copy() -> Chase:
	var o := Chase.new()
	o.t = t
	o.out_of_sight = out_of_sight
	o.slammed = slammed
	o.stun_until = stun_until
	o.last_room = last_room
	o.last_x = last_x
	o.repath_t = repath_t
	o.target_room = target_room
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in [t, out_of_sight, int(slammed), stun_until, last_room, last_x, repath_t, target_room]:
		h = StateHash.mix(h, v)
	return h
