## ViewSnapshot — the plain-data seam between the sim and every view class (TECH §5.4).
##
## `ViewSnapshot.from_sim(world)` (or `fill(world, prev)` on a pooled instance) reads ONLY the
## public `SimWorld` accessors of TECH §3.4 and the actor fields of §3.7.1–§3.7.2, and turns
## them into floats / strings / bools the view can use directly: positions in px, state
## names, facing, glyph, bubble, "?" meter %, residues, the reacting clip + frame, hotspot
## states, applause, link and fuse. `FakeWorld` exposes the same accessors, so the whole
## view runs on a scripted timeline today and on the real `SimWorld` tomorrow, unchanged.
##
## The sim interns ids to ints in sorted-id order (TECH §2); fields that arrive as ints are
## mapped back to ids through `IdTables` (built once per ContentDB). Enum states are mapped
## to names through the actor script's constant map (an enum containing IDLE / ROUTINE), or
## the TECH order as a fallback.
class_name ViewSnapshot
extends RefCounted

const SUB := 60.0
const FLOOR_PITCH := 700.0
## TECH §3.7.2 order (fallback when the sim's enum cannot be read).
const HUSH_STATES: PackedStringArray = ["IDLE", "WALK", "RUN", "STAIRS", "DOOR", "RUMMAGE", "PICK_WINDOW",
	"RIGGING", "DIVING", "HIDDEN", "POPPING", "FROZEN", "SQUEAKING", "CAUGHT", "BOWING"]
## TECH §3.7.1 order.
const BELLOWS_STATES: PackedStringArray = ["ROUTINE", "DETOUR", "CURIOUS", "SPOTTED", "CHASE", "SEARCH",
	"REACTING", "MELTDOWN", "EXHAUSTED", "CAUGHT_HOLD"]
## GDD §4.4 temper tier names by index (0 calm … 3 livid, 4 meltdown).
const TIERS: PackedStringArray = ["calm", "irked", "steaming", "livid", "meltdown"]


## One character's plain state.
class Actor:
	var present: bool = false
	var room: String = ""
	var floor: int = 0
	## World px (x) and the floor line of its floor (y, TECH §2: ground 0, upper −700).
	var x: float = 0.0
	var y: float = 0.0
	var facing: int = 1
	var state: String = ""
	## Position changed since the previous tick (walk cycle), and at run speed.
	var moving: bool = false
	var running: bool = false
	var speed_px_s: float = 0.0
	# Hush (§3.7.2)
	var hidden_spot: String = ""
	var watched_spot: String = ""
	var frozen: bool = false
	var freeze_pose_seed: int = 0
	var carrying: PackedStringArray = PackedStringArray()
	var rig_prank: String = ""
	var rig_step: int = 0
	var rig_pm: int = 0
	# Bellows (§3.7.1)
	var activity: String = ""
	var activity_t: int = 0
	var activity_len: int = 0
	var detour_kind: String = ""
	var detour_station: String = ""
	var specs_on: bool = false
	var blinded: bool = false
	var temper_q: int = 0
	var tier: int = 0
	var residues: PackedStringArray = PackedStringArray()
	var spot_meter: int = 0
	var spot_fill: int = 1
	var spot_pct: float = 0.0
	var ear_pips: int = 0
	var reacting: bool = false
	var react_prank: String = ""
	var react_archetype: String = ""
	var react_variant: String = ""
	var react_tier: int = 1
	var react_suppressed: bool = false
	var react_t: int = 0
	var react_len: int = 0
	var react_clip: String = ""
	var look_back: bool = false
	var on_guard: bool = false
	## The reaction's knock-on entry frame (> 0: entered at B's accent − 2), the sim's last
	## beat clip (played after the settle; its frames are inside `react_len`) and the length
	## without it.
	var react_entry: int = 0
	var react_last_beat: String = ""
	var react_base_len: int = 0
	# One-shot (s2-sim `bellows_oneshot()` / `hush_oneshot()` {id, t, len, variant}; brief §4.1.9)
	## Id ("" none): `bit:<bit>`, `head_turn`, `doorway_pause`, `bump`, `caught:lecture`, …
	var oneshot: String = ""
	## Ticks since the one-shot began, its length (−1 variable) and variant.
	var oneshot_t: int = 0
	var oneshot_len: int = 0
	var oneshot_var: int = 0
	# The current leg (s2-sim `bellows_leg()` / `hush_leg()`; derived from DOOR / STAIRS states
	# when absent): kind "walk" | "door" | "stairs" | "", its ends (rooms, world x, floor-line y),
	# progress 0–1000 and whether it climbs.
	var leg_kind: String = ""
	var leg_from_room: String = ""
	var leg_to_room: String = ""
	var leg_from_x: float = 0.0
	var leg_to_x: float = 0.0
	var leg_from_y: float = 0.0
	var leg_to_y: float = 0.0
	var leg_pm: int = 0
	var leg_up: bool = false
	# Bellows' sight from the sim (`sight_ranges()`, s2-sim §4.4; the stare strip): known, moving
	# px (to the wall when `sight_wall`), frozen px.
	var sight_known: bool = false
	var sight_moving: float = 0.0
	var sight_frozen: float = 0.0
	var sight_wall: bool = false

	## Temper in points (temper_q / 60).
	func temper_points() -> float:
		return float(temper_q) / 60.0

	func copy_from(o: Actor) -> void:
		present = o.present
		room = o.room
		floor = o.floor
		x = o.x
		y = o.y
		facing = o.facing
		state = o.state
		moving = o.moving
		running = o.running
		speed_px_s = o.speed_px_s
		hidden_spot = o.hidden_spot
		watched_spot = o.watched_spot
		frozen = o.frozen
		freeze_pose_seed = o.freeze_pose_seed
		carrying = o.carrying.duplicate()
		rig_prank = o.rig_prank
		rig_step = o.rig_step
		rig_pm = o.rig_pm
		activity = o.activity
		activity_t = o.activity_t
		activity_len = o.activity_len
		detour_kind = o.detour_kind
		detour_station = o.detour_station
		specs_on = o.specs_on
		blinded = o.blinded
		temper_q = o.temper_q
		tier = o.tier
		residues = o.residues.duplicate()
		spot_meter = o.spot_meter
		spot_fill = o.spot_fill
		spot_pct = o.spot_pct
		ear_pips = o.ear_pips
		reacting = o.reacting
		react_prank = o.react_prank
		react_archetype = o.react_archetype
		react_variant = o.react_variant
		react_tier = o.react_tier
		react_suppressed = o.react_suppressed
		react_t = o.react_t
		react_len = o.react_len
		react_clip = o.react_clip
		look_back = o.look_back
		on_guard = o.on_guard
		react_entry = o.react_entry
		react_last_beat = o.react_last_beat
		react_base_len = o.react_base_len
		oneshot = o.oneshot
		oneshot_t = o.oneshot_t
		oneshot_len = o.oneshot_len
		oneshot_var = o.oneshot_var
		leg_kind = o.leg_kind
		leg_from_room = o.leg_from_room
		leg_to_room = o.leg_to_room
		leg_from_x = o.leg_from_x
		leg_to_x = o.leg_to_x
		leg_from_y = o.leg_from_y
		leg_to_y = o.leg_to_y
		leg_pm = o.leg_pm
		leg_up = o.leg_up
		sight_known = o.sight_known
		sight_moving = o.sight_moving
		sight_frozen = o.sight_frozen
		sight_wall = o.sight_wall


## Sorted id tables for int → id mapping (TECH §2 interning order).
class IdTables:
	var rooms: PackedStringArray = PackedStringArray()
	var hotspots: PackedStringArray = PackedStringArray()
	var activities: PackedStringArray = PackedStringArray()
	var pranks: PackedStringArray = PackedStringArray()
	var items: PackedStringArray = PackedStringArray()
	var residues: PackedStringArray = PackedStringArray()
	var stations: PackedStringArray = PackedStringArray()


var tick: int = 0
var ended: bool = false
var hush: Actor = Actor.new()
var bellows: Actor = Actor.new()
## Thought bubble (TECH §3.4 `bubble()`): next activity / detour id, its icon path, the
## countdown ring (ticks, −1 = none), awareness glyph, ear pips, whether `next` is a detour,
## and the progress bar ("", "sleep", "bath") with its fraction.
var bubble_next: String = ""
var bubble_icon: String = ""
var bubble_ring_ticks: int = -1
var bubble_glyph: String = "specs_off"
var bubble_ear_pips: int = 0
var bubble_detour: bool = false
var bubble_bar: String = ""
var bubble_bar_pct: float = 0.0
## His current activity's awareness (activities.json): normal, absorbed, asleep, blind.
var awareness: String = "normal"
var applause_tenths: int = 0
var link: int = 0
var fuse_ticks: int = 0
var tomatoes: int = 0
var tomatoes_max: int = -1
## id → hotspot_state() Dictionary (shared between the driver's two snapshots).
var hotspots: Dictionary = {}
## Bellows' predicted walk for the next 1.5 s (bellows_path_preview samples).
var path_rooms: PackedStringArray = PackedStringArray()
var path_x: PackedFloat32Array = PackedFloat32Array()

static var _state_maps: Dictionary = {}
static var _id_tables: Dictionary = {}
static var _act_cache: Dictionary = {}
static var _house: HouseLayout = null


## A fresh snapshot of `world` (SimWorld or FakeWorld). Allocates; the driver uses fill().
static func from_sim(world: Object) -> ViewSnapshot:
	var s := ViewSnapshot.new()
	s.fill(world, null)
	s.refresh_hotspots(world, ViewSnapshot.hotspot_ids_of(world))
	s.refresh_path(world)
	return s


## Refill this snapshot from `world` in place. `prev` (the previous tick's snapshot, may be
## null) gives the motion flags. Hotspot states and the path preview are refreshed separately
## (refresh_hotspots / refresh_path) because the driver does them at 10 Hz.
func fill(world: Object, prev: ViewSnapshot) -> void:
	var ids := ViewSnapshot.id_tables(world)
	tick = int(_g(world, "tick", 0))
	ended = bool(_g(world, "ended", false))
	_fill_actor(hush, _g(world, "hush", null), ids, prev.hush if prev != null else null, HUSH_STATES, "IDLE")
	_fill_actor(bellows, _g(world, "bellows", null), ids, prev.bellows if prev != null else null, BELLOWS_STATES, "ROUTINE")
	var hb: Object = _g(world, "hush", null)
	if hb != null:
		hush.hidden_spot = ViewKit.id_of(_g(hb, "hidden_spot", ""), ids.hotspots)
		hush.watched_spot = ViewKit.id_of(_g(hb, "watched_spot", ""), ids.hotspots)
		hush.frozen = bool(_g(hb, "frozen", hush.state == "FROZEN"))
		hush.freeze_pose_seed = int(_g(hb, "freeze_pose_seed", 0))
		hush.carrying = _ids_array(_g(hb, "carrying", []), ids.items, hush.carrying)
		hush.rig_prank = ViewKit.id_of(_g(hb, "rig_prank", ""), ids.pranks)
		hush.rig_step = int(_g(hb, "rig_step", 0))
		hush.rig_pm = 0
		if hush.rig_prank != "" and world.has_method("rig_progress_pm"):
			hush.rig_pm = int(world.call("rig_progress_pm", hush.rig_prank))
	var bb: Object = _g(world, "bellows", null)
	if bb != null:
		_fill_bellows(bb, ids, world)
	_fill_oneshot(hush, world, "hush_oneshot", hb, bb)
	_fill_oneshot(bellows, world, "bellows_oneshot", bb, bb)
	_fill_leg(hush, world, "hush_leg", ids, prev.hush if prev != null else null)
	_fill_leg(bellows, world, "bellows_leg", ids, prev.bellows if prev != null else null)
	_fill_sight(world)
	_fill_bubble(world, ids)
	applause_tenths = _call_int(world, "applause_tenths", 0)
	link = _call_int(world, "link", 0)
	fuse_ticks = _call_int(world, "fuse_ticks", 0)
	tomatoes = _call_int(world, "tomatoes", 0)
	tomatoes_max = _call_int(world, "tomatoes_max", -1)


func _fill_actor(a: Actor, src: Object, ids: IdTables, prev: Actor, fallback_states: PackedStringArray, def_state: String) -> void:
	if src == null:
		a.present = false
		return
	a.present = true
	a.room = ViewKit.id_of(_g(src, "room", ""), ids.rooms)
	a.floor = int(_g(src, "floor", 0))
	a.x = float(_g(src, "x_sub", 0)) / SUB
	a.y = -FLOOR_PITCH * float(a.floor)
	var f := int(_g(src, "facing", 1))
	a.facing = -1 if f < 0 else 1
	a.state = ViewSnapshot.state_name(src, _g(src, "state", 0), fallback_states, def_state)
	if prev != null and prev.present:
		var dx := absf(a.x - prev.x)
		a.moving = dx > 0.01 and prev.room == a.room
		a.speed_px_s = dx * 60.0 if a.moving else 0.0
	else:
		a.moving = a.state == "WALK" or a.state == "RUN"
		a.speed_px_s = 0.0
	a.running = a.state == "RUN" or a.state == "CHASE" or (a.moving and a.speed_px_s > 520.0)


func _fill_bellows(bb: Object, ids: IdTables, world: Object) -> void:
	var b := bellows
	b.activity = ViewKit.id_of(_g(bb, "activity_id", ""), ids.activities)
	b.activity_t = int(_g(bb, "activity_t", 0))
	b.activity_len = int(_g(bb, "activity_len", 0))
	var det: Variant = _g(bb, "detour", null)
	b.detour_kind = ""
	b.detour_station = ""
	if det is Dictionary:
		b.detour_kind = ViewKit.s((det as Dictionary).get("kind", ""))
		b.detour_station = ViewKit.id_of((det as Dictionary).get("station", ""), ids.stations)
	elif det is Object:
		b.detour_kind = ViewKit.s(_g(det, "kind", ""))
		b.detour_station = ViewKit.id_of(_g(det, "station", ""), ids.stations)
	b.specs_on = bool(_g(bb, "specs_on", false))
	var bl: Variant = _g(bb, "blinded", null)
	b.blinded = bool(bl) if bl != null else int(_g(bb, "blinded_until", 0)) > tick
	b.temper_q = int(_g(bb, "temper_q", 0))
	b.tier = int(_g(bb, "tier", 0))
	b.residues = _ids_array(_g(bb, "residues", []), ids.residues, b.residues)
	b.spot_meter = int(_g(bb, "spot_meter", 0))
	b.spot_fill = maxi(1, int(_g(bb, "spot_fill", 60)))
	b.spot_pct = clampf(float(b.spot_meter) / float(b.spot_fill), 0.0, 1.0)
	b.ear_pips = int(_g(bb, "ear_pips", 0))
	b.look_back = int(_g(bb, "look_back_until", 0)) > tick
	b.on_guard = int(_g(bb, "on_guard_until", 0)) > tick
	var r: Variant = _g(bb, "reacting", null)
	var rd: Dictionary = {}
	if r is Dictionary:
		rd = r
	elif r is Object:
		for k in ["prank", "archetype", "variant", "tier", "suppressed", "t", "len", "last_beat", "entry"]:
			rd[k] = _g(r, k, null)
	b.reacting = not rd.is_empty() and rd.get("prank", null) != null and ViewKit.s(rd.get("prank", "")) != "" \
			and (b.state == "REACTING" or b.state == "")
	if b.reacting:
		b.react_prank = ViewKit.id_of(rd.get("prank", ""), ids.pranks)
		b.react_archetype = ViewKit.s(rd.get("archetype", ""))
		b.react_variant = ViewKit.s(rd.get("variant", "a"))
		b.react_tier = maxi(1, int(rd.get("tier", 1)))
		b.react_suppressed = bool(rd.get("suppressed", false))
		b.react_t = int(rd.get("t", 0))
		b.react_len = int(rd.get("len", 0))
		b.react_clip = ViewSnapshot.reaction_clip(_g(world, "db", null), b.react_archetype, b.react_variant)
		b.react_entry = int(rd.get("entry", 0))
		b.react_last_beat = ViewKit.s(rd.get("last_beat", ""))
		b.react_base_len = b.react_len - ViewSnapshot.beat_frames(b.react_last_beat) if b.react_last_beat != "" else b.react_len
	else:
		b.react_prank = ""
		b.react_t = 0
		b.react_len = 0
		b.react_clip = ""
		b.react_entry = 0
		b.react_last_beat = ""
		b.react_base_len = 0


## One-shot of an actor from `bellows_oneshot()` / `hush_oneshot()` (s2-sim §4.4b), else a
## derivation from the sim's own bookkeeping fields for the rows that matter most before the
## accessor lands (the caught phases, the door-slam stun, the head turn, look-back, squeak bit).
func _fill_oneshot(a: Actor, world: Object, method: String, src: Object, b_src: Object) -> void:
	a.oneshot = ""
	a.oneshot_t = 0
	a.oneshot_len = 0
	a.oneshot_var = 0
	if not a.present:
		return
	if world.has_method(method):
		var v: Variant = world.call(method)
		if v is Dictionary:
			var d: Dictionary = v
			a.oneshot = ViewKit.s(d.get("id", ""))
			a.oneshot_t = int(d.get("t", 0))
			a.oneshot_len = int(d.get("len", 0))
			a.oneshot_var = int(d.get("variant", 0))
		return
	# Derived (soft) — the caught phases from Bellows' caught_t (TECH §3.7.1: busted cam 60 →
	# Lecture 132 → wipe 12 → doorstep 36).
	var caught := bellows.state == "CAUGHT_HOLD"
	if caught and b_src != null:
		var ct := int(_g(b_src, "caught_t", 0))
		var hush_side := a == hush
		if ct < 60:
			ViewSnapshot._set_os(a, "caught:busted" if hush_side else "caught:grab", ct, 60, 0)
		elif ct < 192:
			ViewSnapshot._set_os(a, "caught:lecture", ct - 60, 132, int(_g(b_src, "caught_variant", 0)))
		elif ct < 204:
			ViewSnapshot._set_os(a, "caught:wipe", ct - 192, 12, 0)
		else:
			ViewSnapshot._set_os(a, "caught:doorstep", ct - 204, 36, 0)
		return
	if a != bellows or src == null:
		return
	var stun := int(_g(src, "stun_until", 0))
	if stun > tick:
		ViewSnapshot._set_os(a, "stun", 60 - (stun - tick), 60, 0)
		return
	var bit := ViewKit.s(_g(src, "bit_id", ""))
	if bit != "" and int(_g(src, "bit_until", 0)) > tick:
		var t0 := int(_g(src, "bit_t0", tick))
		ViewSnapshot._set_os(a, "bit:" + bit, tick - t0, int(_g(src, "bit_until", 0)) - t0, 0)
		return
	var ht := int(_g(src, "head_turn_until", 0))
	if ht > tick:
		ViewSnapshot._set_os(a, "head_turn", 60 - (ht - tick), 60, 0)
		return
	var lb := int(_g(src, "look_back_until", 0))
	if lb > tick and a.state != "REACTING":
		ViewSnapshot._set_os(a, "look_back", 60 - (lb - tick), 60, 0)


static func _set_os(a: Actor, id: String, t: int, n: int, variant: int) -> void:
	a.oneshot = id
	a.oneshot_t = maxi(0, t)
	a.oneshot_len = n
	a.oneshot_var = variant


## The actor's current leg from `bellows_leg()` / `hush_leg()` (s2-sim §4.5.2), else derived
## from Hush's DOOR / STAIRS states (room / x are already the arrival end's during a leg).
func _fill_leg(a: Actor, world: Object, method: String, ids: IdTables, prev: Actor) -> void:
	a.leg_kind = ""
	a.leg_pm = 0
	a.leg_up = false
	if not a.present:
		return
	if world.has_method(method):
		var v: Variant = world.call(method)
		if v is Dictionary:
			var d: Dictionary = v
			a.leg_kind = ViewKit.s(d.get("kind", ""))
			if a.leg_kind == "":
				return
			a.leg_from_room = ViewKit.id_of(d.get("from_room", a.room), ids.rooms)
			a.leg_to_room = ViewKit.id_of(d.get("to_room", a.room), ids.rooms)
			a.leg_from_x = ViewSnapshot._px_of(d.get("from_x", a.x))
			a.leg_to_x = ViewSnapshot._px_of(d.get("to_x", a.x))
			a.leg_pm = clampi(int(d.get("progress_pm", 0)), 0, 1000)
			a.leg_from_y = -FLOOR_PITCH * float(ViewSnapshot._floor_of(d.get("from_floor", null), a.leg_from_room, a))
			a.leg_to_y = -FLOOR_PITCH * float(ViewSnapshot._floor_of(d.get("to_floor", null), a.leg_to_room, a))
			a.leg_up = a.leg_to_y < a.leg_from_y
		return
	if a.state == "DOOR":
		a.leg_kind = "door"
	elif a.state == "STAIRS":
		a.leg_kind = "stairs"
		if prev != null and prev.present and prev.leg_kind == "stairs":
			a.leg_from_room = prev.leg_from_room
			a.leg_from_y = prev.leg_from_y
			a.leg_up = prev.leg_up
		elif prev != null and prev.present:
			a.leg_from_room = prev.room
			a.leg_from_y = prev.y
			a.leg_up = a.y < prev.y
		a.leg_to_room = a.room
		a.leg_to_y = a.y


## The leg accessors give x in px (ints or floats).
static func _px_of(v: Variant) -> float:
	return float(v)


static func _floor_of(v: Variant, room: String, a: Actor) -> int:
	if v != null:
		return int(v)
	if _house == null:
		_house = HouseLayout.load_default()
	var r := _house.room(room)
	return r.floor if r != null else a.floor


## Bellows' sight ranges from `sight_ranges()` (soft; the stare strip keeps its GDD table otherwise).
func _fill_sight(world: Object) -> void:
	var b := bellows
	b.sight_known = false
	if not b.present or not world.has_method("sight_ranges"):
		return
	var v: Variant = world.call("sight_ranges")
	if not (v is Dictionary):
		return
	var d: Dictionary = v
	b.sight_known = true
	b.sight_wall = bool(d.get("to_wall", false))
	b.sight_moving = float(d.get("moving_px", 0))
	b.sight_frozen = float(d.get("frozen_px", 0))
	if bool(d.get("blind", false)):
		b.sight_moving = 0.0
		b.sight_frozen = 0.0


## Frames of a clip in reactions.json `clip_timings` (0 when unknown): last-beat lengths.
static func beat_frames(clip: String) -> int:
	if clip == "":
		return 0
	var rx: Variant = ViewKit.json("res://data/reactions.json")
	if not (rx is Dictionary):
		return 0
	var ct: Variant = (rx as Dictionary).get("clip_timings", {})
	if ct is Dictionary and (ct as Dictionary).get(clip, null) is Dictionary:
		return int(((ct as Dictionary)[clip] as Dictionary).get("frames", 0))
	return 0


func _fill_bubble(world: Object, ids: IdTables) -> void:
	if not world.has_method("bubble"):
		return
	var d: Variant = world.call("bubble")
	if not (d is Dictionary):
		return
	var bd: Dictionary = d
	var nxt: Variant = bd.get("next", "")
	bubble_next = ViewKit.id_of(nxt, ids.activities)
	bubble_icon = ViewKit.s(bd.get("icon", ""))
	bubble_ring_ticks = int(bd.get("ring_ticks", -1))
	bubble_glyph = ViewSnapshot.normalise_glyph(bd.get("glyph", ""), bellows)
	bubble_ear_pips = int(bd.get("ear_pips", bellows.ear_pips))
	bubble_detour = bool(bd.get("detour", bubble_next.begins_with("fixup_") or bubble_next in ["curious", "herd_beryl", "search"]))
	var info := ViewSnapshot.activity_info(world, bellows.activity)
	bubble_bar = ViewKit.s(info.get("bar", "")) if info.get("bar", null) != null else ""
	awareness = ViewKit.s(info.get("awareness", "normal")) if info.get("awareness", null) != null else "normal"
	if bellows.moving:
		awareness = "normal"
	bubble_bar_pct = 0.0
	if bubble_bar != "" and bellows.activity_len > 0:
		bubble_bar_pct = clampf(float(bellows.activity_t) / float(bellows.activity_len), 0.0, 1.0)
	if bubble_icon == "":
		bubble_icon = ViewSnapshot.icon_for(bubble_next)


## True for a bubble `next` that is a detour (fix-ups, the "?" look, search, herding) — or
## "exit" (he leaves: the exit icon; not a detour but never an activity of the routine).
static func is_detour(next_id: String) -> bool:
	return next_id.begins_with("fixup_") or next_id in ["curious", "herd_beryl", "search", "hunt"]


## Refresh hotspot states for `ids_list` (TECH §3.4 hotspot_state).
func refresh_hotspots(world: Object, ids_list: PackedStringArray) -> void:
	if not world.has_method("hotspot_state"):
		return
	for id in ids_list:
		var v: Variant = world.call("hotspot_state", id)
		if v is Dictionary:
			hotspots[id] = v


## Refresh Bellows' 1.5 s path preview (TECH §3.4 bellows_path_preview: [room, x_sub, ...]).
func refresh_path(world: Object) -> void:
	path_rooms.clear()
	path_x.clear()
	if not world.has_method("bellows_path_preview"):
		return
	var v: Variant = world.call("bellows_path_preview", 90)
	if not (v is PackedInt32Array or v is Array):
		return
	var ids := ViewSnapshot.id_tables(world)
	var arr: Array = Array(v)
	var i := 0
	while i + 1 < arr.size():
		path_rooms.append(ViewKit.id_of(arr[i], ids.rooms))
		path_x.append(float(arr[i + 1]) / SUB)
		i += 2


## Copy every field of `o` (Busted Cam, tests). Hotspots are shared by reference.
func copy_from(o: ViewSnapshot) -> void:
	tick = o.tick
	ended = o.ended
	hush.copy_from(o.hush)
	bellows.copy_from(o.bellows)
	bubble_next = o.bubble_next
	bubble_icon = o.bubble_icon
	bubble_ring_ticks = o.bubble_ring_ticks
	bubble_glyph = o.bubble_glyph
	bubble_ear_pips = o.bubble_ear_pips
	bubble_detour = o.bubble_detour
	bubble_bar = o.bubble_bar
	bubble_bar_pct = o.bubble_bar_pct
	awareness = o.awareness
	applause_tenths = o.applause_tenths
	link = o.link
	fuse_ticks = o.fuse_ticks
	tomatoes = o.tomatoes
	tomatoes_max = o.tomatoes_max
	hotspots = o.hotspots
	path_rooms = o.path_rooms.duplicate()
	path_x = o.path_x.duplicate()


## Temper tier name of this snapshot's Bellows.
func tier_name() -> String:
	return TIERS[clampi(bellows.tier, 0, TIERS.size() - 1)]


# --- static helpers ------------------------------------------------------------------------

## Hotspot ids of a world: from its ContentDB house (soft), else the FakeWorld's list.
static func hotspot_ids_of(world: Object) -> PackedStringArray:
	if world.has_method("hotspot_ids"):
		return PackedStringArray(world.call("hotspot_ids"))
	var ids := ViewSnapshot.id_tables(world).hotspots
	if ids.is_empty():
		for hs in HouseLayout.load_default().hotspots:
			ids.append(hs.id)
	return ids


## The name of an actor state (int enum or string).
static func state_name(actor: Object, v: Variant, fallback: PackedStringArray, def_state: String) -> String:
	if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
		return ViewKit.s(v).to_upper()
	if typeof(v) != TYPE_INT:
		return def_state
	var names := _state_names_for(actor, fallback, def_state)
	var i := int(v)
	return names[i] if i >= 0 and i < names.size() else def_state


static func _state_names_for(actor: Object, fallback: PackedStringArray, marker: String) -> PackedStringArray:
	var sc: Script = actor.get_script() as Script
	if sc == null:
		return fallback
	var key := "%s|%s" % [sc.resource_path, marker]
	if _state_maps.has(key):
		return _state_maps[key]
	var out := fallback
	var cmap := sc.get_script_constant_map()
	for cname in cmap:
		var c: Variant = cmap[cname]
		if c is Dictionary and (c as Dictionary).has(marker):
			var d: Dictionary = c
			var n := 0
			for k in d:
				n = maxi(n, int(d[k]) + 1)
			var names := PackedStringArray()
			names.resize(n)
			for k in d:
				names[int(d[k])] = ViewKit.s(k)
			out = names
			break
	_state_maps[key] = out
	return out


## Sorted id tables for a world's ContentDB (cached per db instance; defaults when absent).
static func id_tables(world: Object) -> IdTables:
	var db: Variant = _g(world, "db", null)
	var key := 0
	if db is Object:
		key = (db as Object).get_instance_id()
	if _id_tables.has(key):
		return _id_tables[key]
	var t := IdTables.new()
	if db is Object:
		var dbo: Object = db
		var house: Variant = _g(dbo, "house", null)
		if house != null:
			t.rooms = _collect_ids(_g(house, "rooms", null))
			t.hotspots = _collect_ids(_g(house, "hotspots", null))
			t.stations = _collect_ids(_g(house, "stations", null))
		t.activities = _collect_ids(_g(dbo, "activities", null))
		t.pranks = _collect_ids(_g(dbo, "pranks", null))
		t.items = _collect_ids(_g(dbo, "items", null))
		t.residues = _collect_ids(_g(dbo, "residues", null))
	if t.rooms.is_empty():
		t.rooms = HouseLayout.default_room_ids()
		t.rooms.sort()
	_id_tables[key] = t
	return t


static func _collect_ids(c: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if c is Dictionary:
		for k in c:
			out.append(ViewKit.s(k))
	elif c is Array:
		for e in c:
			if e is Dictionary:
				out.append(ViewKit.s((e as Dictionary).get("id", "")))
			elif e is Object:
				out.append(ViewKit.s(_g(e, "id", "")))
	out.sort()
	return out


static func _ids_array(v: Variant, table: PackedStringArray, reuse: PackedStringArray) -> PackedStringArray:
	reuse.clear()
	if v is Array or v is PackedStringArray or v is PackedInt32Array:
		for e in v:
			reuse.append(ViewKit.id_of(e, table))
	return reuse


## Activity def fields (bar, awareness, icon, specs, station) from world.db (soft) or the
## FakeWorld's `activity_info()`.
static func activity_info(world: Object, id: String) -> Dictionary:
	if id == "":
		return {}
	if world.has_method("activity_info"):
		var v: Variant = world.call("activity_info", id)
		return v if v is Dictionary else {}
	var db: Variant = _g(world, "db", null)
	if not (db is Object):
		return {}
	var ck := "%d|%s" % [(db as Object).get_instance_id(), id]
	if _act_cache.has(ck):
		return _act_cache[ck]
	var acts: Variant = _g(db, "activities", null)
	var def: Variant = null
	if acts is Dictionary:
		def = (acts as Dictionary).get(id, null)
	if def == null:
		return {}
	var out := {}
	for k in ["bar", "awareness", "icon", "specs", "station", "clip"]:
		out[k] = _g(def, k, null) if def is Object else (def as Dictionary).get(k, null)
	# The sim's ActivityDef stores awareness as an enum int plus `awareness_name`.
	var an: Variant = _g(def, "awareness_name", null)
	if an != null:
		out["awareness"] = an
	if ViewKit.s(out.get("bar", "")) == "":
		out["bar"] = null
	_act_cache[ck] = out
	return out


## Clip id of a reaction (reactions.json archetype key `<archetype>_<variant>`), else the
## TECH §14 convention `bellows/rx_<archetype>_<variant>`.
static func reaction_clip(db: Variant, archetype: String, variant: String) -> String:
	if archetype == "":
		return ""
	var key := archetype if variant == "" else "%s_%s" % [archetype, variant]
	if archetype.begins_with("sig_"):
		key = archetype
	if db is Object:
		var rx: Variant = _g(db, "reactions", null)
		var arch: Variant = null
		var tbl: Variant = null
		if rx is Dictionary:
			tbl = (rx as Dictionary).get("archetypes", rx)
		elif rx is Object:
			tbl = _g(rx, "archetypes", null)
		if tbl is Dictionary:
			arch = (tbl as Dictionary).get(key, null)
		if arch != null:
			var c: Variant = _g(arch, "clip", null) if arch is Object else (arch as Dictionary).get("clip", null)
			if c != null and ViewKit.s(c) != "":
				return ViewKit.s(c)
	return "bellows/%s" % key if key.begins_with("sig_") else "bellows/rx_%s" % key


## Canonical awareness glyph id: specs_off, specs_on, blinded, asleep, stars.
static func normalise_glyph(v: Variant, b: Actor) -> String:
	var g := ViewKit.s(v).to_lower() if v != null else ""
	match g:
		"specs_on", "on", "specs":
			return "specs_on"
		"blinded", "blind", "butter", "hair":
			return "blinded"
		"zz", "zzz", "asleep", "sleep":
			return "asleep"
		"stars", "reacting", "dizzy", "meltdown":
			return "stars"
		"specs_off", "specs_dangling", "dangling", "off":
			return "specs_off"
	if b.reacting or b.state == "REACTING" or b.state == "MELTDOWN":
		return "stars"
	if b.blinded or b.state == "EXHAUSTED":
		return "blinded"
	return "specs_on" if b.specs_on else "specs_off"


## Activity / detour icon path (art-house, TECH §1: art/icons/activities/<id>.svg).
static func icon_for(activity_id: String) -> String:
	if activity_id == "":
		return ""
	return "res://art/icons/activities/%s.svg" % activity_id


static func _g(o: Variant, key: String, def: Variant) -> Variant:
	if o == null or not (o is Object):
		if o is Dictionary:
			return (o as Dictionary).get(key, def)
		return def
	var v: Variant = (o as Object).get(key)
	return def if v == null else v


static func _call_int(o: Object, m: String, def: int) -> int:
	if o.has_method(m):
		var v: Variant = o.call(m)
		if v != null:
			return int(v)
	return def
