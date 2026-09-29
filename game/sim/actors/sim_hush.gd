## SimHush — the player character (TECH §3.7.2, GDD §3).
##
## Readable by the view (never written from outside the sim): room, floor, x_sub, facing, state,
## hidden_spot, watched_spot (hotspot idx, -1 none), frozen, freeze_pose_seed, carrying (≤ 4 item ids,
## oldest first), carry_uses, rig_prank (prank idx, -1), rig_step, pin ({room, x_sub} or {}), queued,
## last_input_tick, arm_moving_until, at_hotspot (hotspot idx she stands at, -1), run.
## `is_moving()` = not FROZEN and not HIDDEN (idle counts as moving); a squeak's arm counts as moving.
class_name SimHush
extends RefCounted

const IDLE := 0
const WALK := 1
const RUN := 2
const STAIRS := 3
const DOOR := 4
const RUMMAGE := 5
const PICK_WINDOW := 6
const RIGGING := 7
const DIVING := 8
const HIDDEN := 9
const POPPING := 10
const FROZEN := 11
const SQUEAKING := 12
const CAUGHT := 13
const BOWING := 14
const STATE_NAMES: Array[String] = ["IDLE", "WALK", "RUN", "STAIRS", "DOOR", "RUMMAGE", "PICK_WINDOW",
	"RIGGING", "DIVING", "HIDDEN", "POPPING", "FROZEN", "SQUEAKING", "CAUGHT", "BOWING"]

var room: int = -1
var floor: int = 0
var x_sub: int = 0
var facing: int = 1
var state: int = IDLE
var hidden_spot: int = -1
var watched_spot: int = -1
var frozen: bool = false
var freeze_pose_seed: int = 0
var carrying: PackedStringArray = PackedStringArray()
var carry_uses: PackedInt32Array = PackedInt32Array()
var rig_prank: int = -1
var rig_step: int = 0
var queued: Dictionary = {}
var last_input_tick: int = 0
var arm_moving_until: int = 0
var at_hotspot: int = -1
var run: bool = false
var visited_mask: int = 0

## The destination pin ({room: idx, x_sub} or {}), set while hidden or frozen.
var pin: Dictionary:
	get:
		if pin_room < 0 and pin_hs < 0:
			return {}
		if pin_hs >= 0:
			return {"hotspot": pin_hs}
		return {"room": pin_room, "x_sub": pin_x}

var pin_room: int = -1
var pin_x: int = 0
var pin_hs: int = -1
var path: NavPath = null
var path_serial: int = 0
var target_hs: int = -1
var timer: int = 0
var rig_held: bool = false
var freeze_held: bool = false
var frozen_by_rig: bool = false
var wheezing: bool = false
var wheeze_t: int = 0
var noise_t: int = 0
var pick_container: int = -1
## Link idx Hush crossed this tick (-1 none), for the door slam.
var portal_crossed: int = -1
var go_from_inside: bool = true
## Climbing in through the entry (episode `hush.enter`): busy and out of sight while true.
var entering: bool = false


func setup(w: SimWorld) -> void:
	var ep := w.episode
	room = w.room_idx(ep.hush_room)
	if room < 0:
		room = 0
	x_sub = ep.hush_x_sub
	floor = w.db.house.rooms[room].floor if room < w.db.house.rooms.size() else 0
	facing = 1
	state = IDLE
	visited_mask = 1 << room
	entering = w.ctx.hush_enter_ticks > 0


## True unless FROZEN or HIDDEN (idle counts as moving); a squeak or wheeze arm counts as moving.
func is_moving(tick: int) -> bool:
	if tick < arm_moving_until:
		return true
	return state != FROZEN and state != HIDDEN


## True while in a hiding spot.
func is_hidden() -> bool:
	return state == HIDDEN


## True while a busy action runs (a go/move is queued instead of applied).
func is_busy() -> bool:
	return entering or state == RUMMAGE or state == DIVING or state == POPPING or state == SQUEAKING \
		or state == RIGGING or state == CAUGHT or state == BOWING or state == STAIRS or state == DOOR


## True while walking/running/on the stairs or through a door.
func is_travelling() -> bool:
	return state == WALK or state == RUN or state == STAIRS or state == DOOR


## True while crossing the stairs or a door (not in either room for the senses).
func in_transit() -> bool:
	return entering or state == STAIRS or state == DOOR


# --- commands -------------------------------------------------------------------------------------

## Apply one command (step 1 of the tick).
func apply_cmd(w: SimWorld, c: Dictionary) -> void:
	var name := str(c.get("c", ""))
	last_input_tick = w.tick
	if entering and name != SimCmd.GO and name != SimCmd.MOVE and name != SimCmd.HINT_USED:
		_reject(w, name, "entering")
		return
	match name:
		SimCmd.GO:
			_cmd_go(w, c)
		SimCmd.MOVE:
			_cmd_move(w, c)
		SimCmd.PICK:
			_cmd_pick(w, c)
		SimCmd.RIG:
			_cmd_rig(w, bool(c.get("on", false)))
		SimCmd.FREEZE:
			_cmd_freeze(w, bool(c.get("on", false)))
		SimCmd.SQUEAK:
			_cmd_squeak(w, false)
		SimCmd.WHEEZE:
			if bool(c.get("on", false)):
				_cmd_squeak(w, true)
			else:
				wheezing = false
		SimCmd.PIN:
			_cmd_pin(w, c)
		SimCmd.POP_OUT:
			_cmd_pop_out(w, bool(c.get("run", false)))
		SimCmd.BOW:
			_cmd_bow(w)
		SimCmd.HINT_USED:
			w.goals.hint_used(w, str(c.get("line", "")), int(c.get("step", 0)))
		_:
			_reject(w, name, "unknown_command")


func _reject(w: SimWorld, c: String, why: String) -> void:
	w.emit(SimEvents.CMD_REJECTED, {"c": c, "why": why})


func _cmd_go(w: SimWorld, c: Dictionary) -> void:
	var hid := str(c.get("hotspot", ""))
	var hi: int = w.db.house.hotspot_index.get(hid, -1)
	if hi < 0:
		_reject(w, SimCmd.GO, "unknown_hotspot")
		return
	var h := w.db.house.hotspots[hi]
	if not h.tappable:
		_reject(w, SimCmd.GO, "not_tappable")
		return
	if not w.ctx.hush_allowed(h.room_idx):
		_reject(w, SimCmd.GO, "locked")
		return
	var want_run := bool(c.get("run", false))
	if state == HIDDEN or state == FROZEN or state == DIVING:
		_set_pin_hotspot(w, hi)
		return
	if is_busy():
		queued = c.duplicate()
		return
	if path != null and target_hs == hi and is_travelling():
		if want_run and not run:
			run = true
			if state == WALK:
				state = RUN
			w.emit(SimEvents.HUSH_GO, {"target": hid, "run": true})
		return
	var tgt := _hotspot_target(w, h)
	if at_hotspot == hi and path == null and tgt[0] == room and tgt[1] == x_sub:
		_arrive_at(w, hi)
		return
	if not _start_path(w, int(tgt[0]), int(tgt[1]), want_run):
		_reject(w, SimCmd.GO, "unreachable")
		return
	target_hs = hi
	go_from_inside = w.db.house.rooms[room].id != "porch"
	w.emit(SimEvents.HUSH_GO, {"target": hid, "run": want_run})


func _cmd_move(w: SimWorld, c: Dictionary) -> void:
	var rid := str(c.get("room", ""))
	var r := w.room_idx(rid)
	if r < 0:
		_reject(w, SimCmd.MOVE, "unknown_room")
		return
	if not w.ctx.hush_allowed(r):
		_reject(w, SimCmd.MOVE, "locked")
		return
	var rd := w.db.house.rooms[r]
	var tx := clampi(Fx.px(float(c.get("x", 0))), rd.x0_sub, rd.x1_sub)
	var want_run := bool(c.get("run", false))
	if state == HIDDEN or state == FROZEN or state == DIVING:
		_set_pin(w, r, tx)
		return
	if is_busy():
		queued = c.duplicate()
		return
	if path != null and target_hs < 0 and is_travelling() and path.final_room() == r and path.final_x() == tx:
		if want_run and not run:
			run = true
			if state == WALK:
				state = RUN
		return
	if not _start_path(w, r, tx, want_run):
		_reject(w, SimCmd.MOVE, "unreachable")
		return
	target_hs = -1
	w.emit(SimEvents.HUSH_GO, {"target": rid, "run": want_run})


## [room, x_sub] Hush walks to for a hotspot.
func _hotspot_target(w: SimWorld, h: HotspotDef) -> Array:
	var house := w.db.house
	if h.kind == HotspotDef.STAIRS and h.link_idx >= 0:
		var l := house.links[h.link_idx]
		var other := l.other(h.room_idx)
		if other >= 0 and house.rooms[room].floor == house.rooms[h.room_idx].floor and w.ctx.hush_allowed(other):
			return [other, l.x_in(other)]
	if h.kind == HotspotDef.DOOR and h.link_idx >= 0:
		var l := house.links[h.link_idx]
		var other := l.other(h.room_idx)
		if other >= 0 and room == h.room_idx and w.ctx.hush_allowed(other):
			var o := house.rooms[other]
			var dir := 1 if (o.x0_sub + o.x1_sub) > 2 * l.x_sub else -1
			return [other, clampi(l.x_sub + dir * SimConst.DOOR_STEP_PX * SimConst.SUB, o.x0_sub, o.x1_sub)]
	return [h.room_idx, h.use_sub]


func _start_path(w: SimWorld, r: int, tx: int, want_run: bool) -> bool:
	var mover := SimConst.MOVER_HUSH_RUN if want_run else SimConst.MOVER_HUSH_WALK
	var p := w.db.nav.path(room, x_sub, r, tx, mover, w.ctx.hush_mask)
	if not p.ok:
		return false
	path_serial += 1
	p.serial = path_serial
	p.facing = facing
	path = p
	run = want_run
	at_hotspot = -1
	pick_container = -1
	if state == PICK_WINDOW or state == IDLE or state == SQUEAKING:
		pass
	state = RUN if want_run else WALK
	_sync_leg_state()
	return true


func _sync_leg_state() -> void:
	if path == null:
		return
	match path.current_kind():
		NavPath.STAIRS:
			state = STAIRS
		NavPath.DOOR:
			state = DOOR
		_:
			state = RUN if run else WALK


func _cmd_pick(w: SimWorld, c: Dictionary) -> void:
	var item := str(c.get("item", ""))
	var cont := at_hotspot if state == IDLE or state == PICK_WINDOW else -1
	if cont < 0 or w.db.house.hotspots[cont].kind != HotspotDef.CONTAINER:
		_reject(w, SimCmd.PICK, "not_at_container")
		return
	if not w.pranks.container_stock(w, cont).has(item):
		_reject(w, SimCmd.PICK, "not_in_stock")
		return
	_take(w, item)
	state = IDLE
	pick_container = -1


func _take(w: SimWorld, item: String) -> void:
	if carrying.size() >= SimConst.TRAY_CAP:
		var oldest := carrying[0]
		carrying.remove_at(0)
		carry_uses.remove_at(0)
		w.pranks.item_home(w, oldest)
	var it: ItemDef = w.db.items[item]
	carrying.append(item)
	carry_uses.append(it.count)
	w.pranks.item_carried(w, item)
	w.emit(SimEvents.PICK, {"item": item})


## Uses left of a carried item (0 when not carried).
func uses_of(item: String) -> int:
	var i := carrying.find(item)
	return carry_uses[i] if i >= 0 else 0


## Consume one use of a carried item; returns true when it is used up (removed from the tray).
func consume(item: String) -> bool:
	var i := carrying.find(item)
	if i < 0:
		return false
	carry_uses[i] -= 1
	if carry_uses[i] <= 0:
		carrying.remove_at(i)
		carry_uses.remove_at(i)
		return true
	return false


func _cmd_rig(w: SimWorld, on: bool) -> void:
	if not on:
		rig_held = false
		if state == RIGGING:
			w.emit(SimEvents.RIG_PAUSE, {"prank": w.db.prank_list[rig_prank].id})
			state = IDLE
			_run_queued(w)
		elif state == FROZEN and frozen_by_rig:
			frozen_by_rig = false
			if not freeze_held:
				_unfreeze(w)
		return
	if state == CAUGHT or state == BOWING:
		_reject(w, SimCmd.RIG, "busy")
		return
	if state == RIGGING:
		return
	if not (state == IDLE or state == PICK_WINDOW) or at_hotspot < 0 \
			or w.db.house.hotspots[at_hotspot].kind != HotspotDef.RIG_POINT:
		_reject(w, SimCmd.RIG, "not_at_rig_point")
		return
	var pi := w.pranks.rig_target(w, at_hotspot)
	if pi < 0:
		_reject(w, SimCmd.RIG, "nothing_to_rig")
		return
	var p := w.db.prank_list[pi]
	var si: int = w.pranks.step[pi]
	var st := p.steps[si]
	if st.needs != "" and uses_of(st.needs) <= 0:
		_reject(w, SimCmd.RIG, "needs_item")
		return
	if not st.conditions.is_empty() and not Conditions.prank_conditions(w, st.conditions, pi):
		_reject(w, SimCmd.RIG, "step_condition")
		return
	rig_held = true
	rig_prank = pi
	rig_step = si
	state = RIGGING
	pick_container = -1
	w.pranks.begin_rig(w, pi)
	w.emit(SimEvents.RIG_START, {"prank": p.id, "step": si})


func _cmd_freeze(w: SimWorld, on: bool) -> void:
	if not on:
		freeze_held = false
		if state == FROZEN and not (frozen_by_rig and rig_held):
			frozen_by_rig = false
			_unfreeze(w)
		return
	if state == HIDDEN or state == DIVING or state == POPPING:
		_reject(w, SimCmd.FREEZE, "hidden")
		return
	if state == CAUGHT or state == BOWING:
		_reject(w, SimCmd.FREEZE, "busy")
		return
	freeze_held = true
	if state == RIGGING:
		w.emit(SimEvents.RIG_PAUSE, {"prank": w.db.prank_list[rig_prank].id})
		rig_held = false
	_try_freeze(w)


func _try_freeze(w: SimWorld) -> void:
	if not freeze_held or state == FROZEN:
		return
	if state == IDLE or state == WALK or state == RUN or state == PICK_WINDOW or state == SQUEAKING or state == RIGGING:
		_enter_frozen(w)


func _enter_frozen(w: SimWorld) -> void:
	if path != null:
		path = null
		target_hs = -1
	pick_container = -1
	state = FROZEN
	frozen = true
	freeze_pose_seed = int(w.rng.next_u32() % 8)
	w.emit(SimEvents.FREEZE, {"on": true})


func _unfreeze(w: SimWorld) -> void:
	state = IDLE
	frozen = false
	w.emit(SimEvents.FREEZE, {"on": false})
	if pin_hs >= 0 or pin_room >= 0:
		_go_pin(w, false)
	else:
		_run_queued(w)


func _cmd_squeak(w: SimWorld, is_wheeze: bool) -> void:
	var cname := SimCmd.WHEEZE if is_wheeze else SimCmd.SQUEAK
	if state == HIDDEN or state == DIVING or state == POPPING:
		_reject(w, cname, "hidden")
		return
	if state == CAUGHT or state == BOWING:
		_reject(w, cname, "busy")
		return
	var heard := w.bits.hears(w, room, x_sub)
	w.emit(SimEvents.SQUEAK, {"room": w.room_id(room), "x": Fx.to_px(x_sub), "heard": heard})
	arm_moving_until = maxi(arm_moving_until, w.tick + SimConst.SQUEAK_ARM_TICKS)
	if is_wheeze:
		wheezing = true
		wheeze_t = 0
	if state == IDLE:
		state = SQUEAKING
		timer = SimConst.SQUEAK_ARM_TICKS
	w.bits.on_squeak(w, room, x_sub, heard)


func _cmd_pin(w: SimWorld, c: Dictionary) -> void:
	if not (state == HIDDEN or state == FROZEN or state == DIVING):
		_reject(w, SimCmd.PIN, "not_hidden_or_frozen")
		return
	if c.has("hotspot"):
		var hi: int = w.db.house.hotspot_index.get(str(c["hotspot"]), -1)
		if hi < 0 or not w.ctx.hush_allowed(w.db.house.hotspots[hi].room_idx):
			_reject(w, SimCmd.PIN, "unknown_hotspot")
			return
		_set_pin_hotspot(w, hi)
		return
	var r := w.room_idx(str(c.get("room", "")))
	if r < 0 or not w.ctx.hush_allowed(r):
		_reject(w, SimCmd.PIN, "unknown_room")
		return
	var rd := w.db.house.rooms[r]
	_set_pin(w, r, clampi(Fx.px(float(c.get("x", 0))), rd.x0_sub, rd.x1_sub))


func _set_pin(w: SimWorld, r: int, tx: int) -> void:
	pin_room = r
	pin_x = tx
	pin_hs = -1
	w.emit(SimEvents.PIN, {"room": w.room_id(r), "x": Fx.to_px(tx)})


func _set_pin_hotspot(w: SimWorld, hi: int) -> void:
	var h := w.db.house.hotspots[hi]
	pin_hs = hi
	pin_room = -1
	w.emit(SimEvents.PIN, {"room": h.room, "x": Fx.to_px(h.use_sub)})


func _go_pin(w: SimWorld, want_run: bool) -> void:
	var hs := pin_hs
	var pr := pin_room
	var px := pin_x
	pin_hs = -1
	pin_room = -1
	if hs >= 0:
		_cmd_go(w, {"c": SimCmd.GO, "hotspot": w.db.house.hotspots[hs].id, "run": want_run})
	elif pr >= 0:
		_cmd_move(w, {"c": SimCmd.MOVE, "room": w.room_id(pr), "x": Fx.to_px(px), "run": want_run})


func _cmd_pop_out(w: SimWorld, want_run: bool) -> void:
	if state != HIDDEN:
		_reject(w, SimCmd.POP_OUT, "not_hidden")
		return
	var spot := hidden_spot
	if w.senses.f2f_active() and w.senses.f2f_kind == Senses.F2F_HIDING and w.senses.f2f_spot == spot:
		w.senses.f2f_escaped = true
		want_run = true
	w.emit(SimEvents.POP_OUT, {"spot": w.db.house.hotspots[spot].id})
	hidden_spot = -1
	watched_spot = -1
	at_hotspot = spot
	state = POPPING
	timer = SimConst.POP_TICKS
	run = want_run


func _cmd_bow(w: SimWorld) -> void:
	if state == CAUGHT or state == BOWING:
		_reject(w, SimCmd.BOW, "busy")
		return
	if not w.goals.star1:
		_reject(w, SimCmd.BOW, "no_star")
		return
	state = BOWING
	path = null
	w.end_night("bow")


func _run_queued(w: SimWorld) -> void:
	if queued.is_empty() or is_busy():
		return
	var c := queued
	queued = {}
	apply_cmd(w, c)


# --- per tick -------------------------------------------------------------------------------------

## Step 3 of the tick.
func update(w: SimWorld) -> void:
	portal_crossed = -1
	if entering:
		if w.tick < w.ctx.hush_enter_ticks:
			return
		entering = false
	match state:
		RUMMAGE:
			timer -= 1
			if timer <= 0:
				_rummage_done(w)
		PICK_WINDOW:
			timer -= 1
			if timer <= 0:
				state = IDLE
				pick_container = -1
		DIVING:
			timer -= 1
			if timer <= 0:
				_dive_done(w)
		POPPING:
			timer -= 1
			if timer <= 0:
				state = IDLE
				if pin_hs >= 0 or pin_room >= 0:
					_go_pin(w, run)
		SQUEAKING:
			timer -= 1
			if timer <= 0:
				state = IDLE
		RIGGING:
			_update_rig(w)
		WALK, RUN, STAIRS, DOOR:
			_update_move(w)
	if wheezing:
		wheeze_t += 1
		arm_moving_until = maxi(arm_moving_until, w.tick + 1)
		if wheeze_t >= SimConst.WHEEZE_MAX_TICKS:
			wheezing = false
	_try_freeze(w)
	w.pranks.update_restock(w)
	if state == RUN:
		noise_t += 1
		if noise_t % SimConst.RUN_NOISE_EVERY == 1:
			w.emit(SimEvents.NOISE, {"kind": "run", "room": w.room_id(room), "x": Fx.to_px(x_sub), "r": SimConst.NOISE_PX})
			w.bits.on_noise(w, room, x_sub)
	else:
		noise_t = 0
	if not queued.is_empty() and not is_busy() and state != FROZEN and state != CAUGHT:
		_run_queued(w)


func _update_move(w: SimWorld) -> void:
	if path == null:
		state = IDLE
		return
	path.speed = SimConst.HUSH_RUN if run else SimConst.HUSH_TIPTOE
	var flags := path.advance()
	x_sub = path.x
	facing = path.facing
	if flags & NavPath.F_ROOM:
		room = path.room
		floor = w.db.house.rooms[room].floor
		visited_mask |= 1 << room
		w.emit(SimEvents.HUSH_ROOM, {"room": w.room_id(room)})
	if flags & NavPath.F_PORTAL and path.cursor < path.size():
		portal_crossed = path.aux[path.cursor]
		w.chase.on_hush_portal(w, portal_crossed)
	if flags & NavPath.F_DONE:
		path = null
		state = IDLE
		var hs := target_hs
		target_hs = -1
		if hs >= 0:
			_arrive_at(w, hs)
		else:
			_run_queued(w)
	else:
		_sync_leg_state()


func _arrive_at(w: SimWorld, hi: int) -> void:
	var h := w.db.house.hotspots[hi]
	var tgt := _hotspot_target(w, h)
	# stairs / doors: she arrived on the far side, not at the hotspot itself
	if (h.kind == HotspotDef.STAIRS or h.kind == HotspotDef.DOOR) and (int(tgt[0]) != h.room_idx or room != h.room_idx):
		at_hotspot = -1
		w.emit(SimEvents.HUSH_ARRIVE, {"hotspot": h.id})
		return
	at_hotspot = hi
	w.emit(SimEvents.HUSH_ARRIVE, {"hotspot": h.id})
	match h.kind:
		HotspotDef.CONTAINER:
			state = RUMMAGE
			timer = SimConst.RUMMAGE_TICKS
			w.emit(SimEvents.RUMMAGE, {"container": h.id})
		HotspotDef.HIDING:
			state = DIVING
			timer = SimConst.DIVE_TICKS
		HotspotDef.RIG_POINT:
			if h.facing != 0:
				facing = h.facing
			elif h.station_idx >= 0:
				var sx := w.db.house.stations[h.station_idx].x_sub
				if sx != x_sub:
					facing = 1 if sx > x_sub else -1
		HotspotDef.EXIT:
			if w.goals.star1 and go_from_inside:
				_cmd_bow(w)


func _rummage_done(w: SimWorld) -> void:
	state = IDLE
	var stock := w.pranks.container_stock(w, at_hotspot)
	if stock.size() == 1:
		_take(w, stock[0])
	elif stock.size() >= 2:
		state = PICK_WINDOW
		timer = SimConst.PICK_WINDOW_TICKS
		pick_container = at_hotspot
		w.emit(SimEvents.PICK_WINDOW, {"container": w.db.house.hotspots[at_hotspot].id, "items": ",".join(stock)})


func _dive_done(w: SimWorld) -> void:
	state = HIDDEN
	hidden_spot = at_hotspot
	watched_spot = at_hotspot if w.senses.visible else -1
	w.emit(SimEvents.HIDE, {"spot": w.db.house.hotspots[hidden_spot].id, "watched": watched_spot >= 0})
	w.bellows.on_hush_hidden(w, hidden_spot)


func _update_rig(w: SimWorld) -> void:
	var p := w.db.prank_list[rig_prank]
	if w.senses.visible:
		w.emit(SimEvents.RIG_PAUSE, {"prank": p.id})
		frozen_by_rig = true
		_enter_frozen(w)
		return
	var st := p.steps[rig_step]
	var prog := w.pranks.add_progress(w, rig_prank)
	if st.prep == "B" and prog % SimConst.B_RIG_NOISE_EVERY == 1:
		w.emit(SimEvents.NOISE, {"kind": "rig", "room": w.room_id(room), "x": Fx.to_px(x_sub), "r": SimConst.NOISE_PX})
		w.bits.on_noise(w, room, x_sub)
	if prog >= st.prep_ticks:
		if st.needs != "":
			if consume(st.needs):
				w.pranks.item_used(w, st.needs)
		w.pranks.complete_step(w, rig_prank)
		rig_held = false
		state = IDLE
		_run_queued(w)


## Called when Bellows catches her (TECH §3.7.1).
func on_caught(w: SimWorld) -> void:
	for item in carrying:
		w.pranks.item_home(w, item)
	carrying = PackedStringArray()
	carry_uses = PackedInt32Array()
	state = CAUGHT
	frozen = false
	path = null
	target_hs = -1
	at_hotspot = -1
	hidden_spot = -1
	watched_spot = -1
	rig_held = false
	freeze_held = false
	frozen_by_rig = false
	wheezing = false
	pin_room = -1
	pin_hs = -1
	pick_container = -1


## Caught hold +204: she lands on the doorstep.
func place_doorstep(w: SimWorld) -> void:
	room = w.ctx.doorstep_room
	x_sub = w.ctx.doorstep_x
	floor = w.db.house.rooms[room].floor
	facing = 1
	visited_mask |= 1 << room


## Caught hold +240: control returns.
func release(w: SimWorld) -> void:
	state = IDLE
	_run_queued(w)


## Figgis's hook (Prologue can't-fail): yank her into a hiding spot.
func figgis_into(w: SimWorld, spot: int) -> void:
	var h := w.db.house.hotspots[spot]
	path = null
	target_hs = -1
	rig_held = false
	frozen_by_rig = false
	freeze_held = false
	frozen = false
	var moved_room := room != h.room_idx
	room = h.room_idx
	floor = w.db.house.rooms[room].floor
	x_sub = h.use_sub
	at_hotspot = spot
	hidden_spot = spot
	watched_spot = -1
	state = HIDDEN
	visited_mask |= 1 << room
	if moved_room:
		w.emit(SimEvents.HUSH_ROOM, {"room": w.room_id(room)})


# --- clone / hash ---------------------------------------------------------------------------------

## Deep copy.
func copy() -> SimHush:
	var o := SimHush.new()
	o.room = room
	o.floor = floor
	o.x_sub = x_sub
	o.facing = facing
	o.state = state
	o.hidden_spot = hidden_spot
	o.watched_spot = watched_spot
	o.frozen = frozen
	o.freeze_pose_seed = freeze_pose_seed
	o.carrying = carrying.duplicate()
	o.carry_uses = carry_uses.duplicate()
	o.rig_prank = rig_prank
	o.rig_step = rig_step
	o.queued = queued.duplicate(true)
	o.last_input_tick = last_input_tick
	o.arm_moving_until = arm_moving_until
	o.at_hotspot = at_hotspot
	o.run = run
	o.visited_mask = visited_mask
	o.pin_room = pin_room
	o.pin_x = pin_x
	o.pin_hs = pin_hs
	o.path = path.duplicate_path() if path != null else null
	o.path_serial = path_serial
	o.target_hs = target_hs
	o.timer = timer
	o.rig_held = rig_held
	o.freeze_held = freeze_held
	o.frozen_by_rig = frozen_by_rig
	o.wheezing = wheezing
	o.wheeze_t = wheeze_t
	o.noise_t = noise_t
	o.pick_container = pick_container
	o.portal_crossed = portal_crossed
	o.go_from_inside = go_from_inside
	o.entering = entering
	return o


## Mix into a state hash.
func hash_into(h: int) -> int:
	for v in [room, floor, x_sub, facing, state, hidden_spot, watched_spot, int(frozen), freeze_pose_seed,
			rig_prank, rig_step, last_input_tick, arm_moving_until, at_hotspot, int(run), visited_mask,
			pin_room, pin_x, pin_hs, path_serial, target_hs, timer, int(rig_held), int(freeze_held),
			int(frozen_by_rig), int(wheezing), wheeze_t, noise_t, pick_container, int(go_from_inside), int(entering)]:
		h = StateHash.mix(h, v)
	for s in carrying:
		h = StateHash.mix_str(h, s)
	h = StateHash.mix_arr(h, carry_uses)
	h = StateHash.mix_str(h, str(queued.get("c", "")))
	h = StateHash.mix_str(h, str(queued.get("hotspot", queued.get("room", ""))))
	h = StateHash.mix(h, int(queued.get("x", 0)))
	h = StateHash.mix_bool(h, bool(queued.get("run", false)))
	if path != null:
		h = path.hash_into(h)
	return h
