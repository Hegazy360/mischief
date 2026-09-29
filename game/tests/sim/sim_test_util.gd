## SimTestUtil — shared helpers for the sim tests (fixture loading, stepping, event queries).
class_name SimTestUtil
extends RefCounted

const FIXTURES := "res://tests/sim/fixtures"

static var _raw_cache: Dictionary = {}
static var _db_cache: ContentDB = null


## Raw fixture dictionaries (deep copy each call): {house, items, pranks, activities, reactions, residues,
## episodes: {id: dict}}.
static func raw() -> Dictionary:
	if _raw_cache.is_empty():
		var r := FIXTURES
		_raw_cache["house"] = _json(r + "/house/house.json")
		for k in ["items", "pranks", "activities", "reactions", "residues"]:
			_raw_cache[k] = _json("%s/%s.json" % [r, k])
		var eps := {}
		for id in ["fx_prologue", "fx_act1", "fx_meltdown"]:
			eps[id] = _json("%s/episodes/%s.json" % [r, id])
		_raw_cache["episodes"] = eps
	return _raw_cache.duplicate(true)


static func _json(path: String) -> Variant:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("fixture parse error %s" % path)
		return {}
	return j.data


## The fixture ContentDB (cached; do not mutate).
static func db() -> ContentDB:
	if _db_cache == null:
		_db_cache = ContentDB.load_dir(FIXTURES)
	return _db_cache


## A ContentDB from modified raw dictionaries.
static func db_from(files: Dictionary) -> ContentDB:
	return ContentDB.load_dicts(files)


## A world on the fixture db.
static func world(episode: String = "fx_act1", config: Dictionary = {}) -> SimWorld:
	return SimWorld.create(db(), episode, config)


## A world with an episode patched by `patch` (a Callable taking the episode Dictionary).
static func world_patched(episode: String, patch: Callable, config: Dictionary = {}, files_patch: Callable = Callable()) -> SimWorld:
	var files := raw()
	patch.call(files["episodes"][episode])
	if files_patch.is_valid():
		files_patch.call(files)
	var d := ContentDB.load_dicts(files)
	if not d.errors.is_empty():
		push_warning("patched fixtures have errors: %s" % str(d.errors))
	return SimWorld.create(d, episode, config)


## A single-activity loop episode patch: Bellows loops `acts` (ids) with an optional start.
static func loop_patch(acts: Array, b_room: String = "", b_x: int = -1, h_room: String = "", h_x: int = -1) -> Callable:
	return func(ep: Dictionary) -> void:
		var loop: Array = []
		for a in acts:
			loop.append(a if typeof(a) == TYPE_DICTIONARY else {"a": a})
		ep["bellows"]["loop"] = loop
		if b_room != "":
			ep["bellows"]["start"] = {"room": b_room, "x": b_x}
		if h_room != "":
			ep["hush"]["start"] = {"room": h_room, "x": h_x}
			if not (ep["rooms"] as Array).has(h_room):
				(ep["rooms"] as Array).append(h_room)


## A world where Bellows stays upstairs on the landing (radiator loop): Hush can act unseen downstairs.
static func quiet_world(episode: String = "fx_act1", config: Dictionary = {}, files_patch: Callable = Callable()) -> SimWorld:
	return world_patched(episode, loop_patch(["radiator"], "landing", 1420), config, files_patch)


## Step n ticks with no commands; returns every event.
static func run(w: SimWorld, n: int) -> Array:
	var out: Array = []
	for i in n:
		if w.ended:
			break
		w.step([])
		out.append_array(w.drain_events())
	return out


## Step once with commands; returns that tick's events.
static func step(w: SimWorld, cmds: Array = []) -> Array:
	w.step(cmds)
	return w.drain_events()


## Step until an event named `name` (matching fields) appears or `max_ticks` pass. Returns the event or {}.
## Every event seen is appended to `log` when given.
static func run_until(w: SimWorld, name: String, match_d: Dictionary = {}, max_ticks: int = 6000, log: Array = []) -> Dictionary:
	for i in max_ticks:
		if w.ended:
			return {}
		w.step([])
		var evs := w.drain_events()
		log.append_array(evs)
		for ev in evs:
			if str(ev["e"]) == name and _matches(ev, match_d):
				return ev
	return {}


## Step until `pred.call(w)` is true (max ticks). Returns true if it became true.
static func run_until_pred(w: SimWorld, pred: Callable, max_ticks: int = 6000, log: Array = []) -> bool:
	for i in max_ticks:
		if pred.call(w):
			return true
		if w.ended:
			return false
		w.step([])
		log.append_array(w.drain_events())
	return pred.call(w)


static func _matches(ev: Dictionary, m: Dictionary) -> bool:
	for k in m:
		if not ev.has(k) or str(ev[k]) != str(m[k]):
			return false
	return true


## Events named `name` in a log (optionally matching fields).
static func find(log: Array, name: String, match_d: Dictionary = {}) -> Array:
	var out: Array = []
	for ev in log:
		if str(ev["e"]) == name and _matches(ev, match_d):
			out.append(ev)
	return out


## First event named `name` or {}.
static func first(log: Array, name: String, match_d: Dictionary = {}) -> Dictionary:
	for ev in log:
		if str(ev["e"]) == name and _matches(ev, match_d):
			return ev
	return {}


## Put Hush somewhere instantly (test setup only).
static func place_hush(w: SimWorld, room: String, x_px: int) -> void:
	var h := w.hush
	h.room = w.room_idx(room)
	h.floor = w.db.house.rooms[h.room].floor
	h.x_sub = x_px * SimConst.SUB
	h.path = null
	h.state = SimHush.IDLE
	h.at_hotspot = -1
	h.visited_mask |= 1 << h.room


## Put Hush at a hotspot's use point, standing there (test setup only).
static func place_hush_at(w: SimWorld, hotspot: String) -> void:
	var hs := w.db.house.hotspot(hotspot)
	place_hush(w, hs.room, Fx.to_px(hs.use_sub))
	w.hush.at_hotspot = hs.idx


## Rig a prank instantly (test setup only): every step done → RIGGED.
static func force_rig(w: SimWorld, prank: String) -> void:
	var p := w.db.prank_idx(prank)
	w.pranks.state[p] = Pranks.RIGGED
	w.pranks.step[p] = w.db.prank_list[p].steps.size()
	if w.pranks.first_rig_tick < 0:
		w.pranks.first_rig_tick = w.tick


## Set Bellows' temper (points) instantly (test setup only).
static func set_temper(w: SimWorld, points: int) -> void:
	w.bellows.temper_q = points * SimConst.TEMPER_Q
	w.temper.hold_left = SimConst.HOLD_TICKS
	w.bellows.tier = SimConst.tier_of(w.bellows.temper_q)
	w.temper.last_tier = w.bellows.tier


## Walk Hush to a hotspot (go) and step until she arrives (hush_arrive) or max ticks.
static func walk_to(w: SimWorld, hotspot: String, max_ticks: int = 1200, log: Array = []) -> bool:
	w.step([SimCmd.go(hotspot)])
	log.append_array(w.drain_events())
	var ev := run_until(w, SimEvents.HUSH_ARRIVE, {"hotspot": hotspot}, max_ticks, log)
	return not ev.is_empty()


## Hold RIG until the current step completes (or max ticks). Returns true on rig_step_done.
static func rig_hold(w: SimWorld, max_ticks: int = 400, log: Array = []) -> bool:
	w.step([SimCmd.rig(true)])
	var evs := w.drain_events()
	log.append_array(evs)
	if not first(evs, SimEvents.RIG_STEP_DONE).is_empty():
		return true
	var ev := run_until(w, SimEvents.RIG_STEP_DONE, {}, max_ticks, log)
	w.step([SimCmd.rig(false)])
	log.append_array(w.drain_events())
	return not ev.is_empty()


## A scripted Hush for fx_act1 (deterministic): rigs ACHOO-RIA!, IN A PICKLE and TAP DANCE in the kitchen,
## hides in the pantry, later fetches the squeaker for KETTLE DRUM, squeaks a bit, and wanders
## (seeded) for the rest of the Night. Returns [[tick, cmd], ...] (commands as applied).
static func bot_act1(ticks: int) -> Array:
	var w := world("fx_act1")
	var out: Array = []
	var rng := Rng.new(1234)
	var phase := 0
	var wait := 0
	var spots := ["kitchen_pantry_curtain", "kitchen_table", "kitchen_honey", "kitchen_pickle_jar", "kitchen_sink_tap",
		"parlour_piano_back", "hall_coat_cupboard", "hall_confiscated_box"]
	for t in range(1, ticks + 1):
		var cmds: Array = []
		var h := w.hush
		var b := w.bellows
		if wait > 0:
			wait -= 1
		else:
			match phase:
				0:
					cmds.append(SimCmd.go("kitchen_honey"))
					phase = 1
				1:
					if h.at_hotspot == w.db.house.hotspot_index["kitchen_honey"] and h.state == SimHush.IDLE:
						cmds.append(SimCmd.rig(true))
						phase = 2
				2:
					if w.prank_state("achoo_ria") == Pranks.RIGGED:
						cmds.append(SimCmd.rig(false))
						cmds.append(SimCmd.go("kitchen_pickle_jar"))
						phase = 3
				3:
					if h.at_hotspot == w.db.house.hotspot_index["kitchen_pickle_jar"] and h.state == SimHush.IDLE:
						cmds.append(SimCmd.rig(true))
						cmds.append(SimCmd.go("kitchen_sink_tap"))
						phase = 4
				4:
					if w.prank_state("in_a_pickle") == Pranks.RIGGED and h.at_hotspot == w.db.house.hotspot_index["kitchen_sink_tap"] \
							and h.state == SimHush.IDLE:
						cmds.append(SimCmd.rig(false))
						cmds.append(SimCmd.rig(true))
						cmds.append(SimCmd.go("kitchen_pantry_curtain"))
						phase = 5
				5:
					if h.state == SimHush.HIDDEN:
						phase = 6
				6:
					# once he's back at the gramophone (parlour, facing left), pop out and squeak from the kitchen
					if b.activity_id == "warmup" and b.phase == SimBellows.PH_PERFORM and h.is_hidden():
						cmds.append(SimCmd.pop_out(false))
						wait = 20
						phase = 7
				7:
					cmds.append(SimCmd.squeak())
					wait = 40
					phase = 8 if rng.chance_pct(40) else 7
				_:
					if h.is_hidden() and t % 300 == 0:
						cmds.append(SimCmd.pop_out(rng.chance_pct(50)))
					elif t % 120 == 0 and not h.is_busy() and not h.is_hidden():
						cmds.append(SimCmd.go(spots[rng.range_int(0, spots.size() - 1)], rng.chance_pct(20)))
					elif t % 173 == 0 and not h.is_hidden():
						cmds.append(SimCmd.squeak())
					elif t % 211 == 0 and not h.is_hidden():
						cmds.append(SimCmd.freeze(true))
					elif t % 211 == 50:
						cmds.append(SimCmd.freeze(false))
					elif t % 97 == 0 and h.at_hotspot >= 0 and w.db.house.hotspots[h.at_hotspot].kind == HotspotDef.RIG_POINT:
						cmds.append(SimCmd.rig(true))
					elif t % 97 == 40:
						cmds.append(SimCmd.rig(false))
		for c in cmds:
			out.append([t, c])
		w.step(cmds)
		w.drain_events()
		if w.ended:
			break
	return out


## Replay [[tick, cmd], ...] for `ticks` ticks; returns the per-tick hashes (when `hashes`) and the world.
static func replay(episode: String, cmds: Array, ticks: int, hashes: PackedInt64Array = PackedInt64Array(), config: Dictionary = {}) -> SimWorld:
	var w := world(episode, config)
	var by := {}
	for e in cmds:
		var t := int(e[0])
		if not by.has(t):
			by[t] = []
		(by[t] as Array).append(e[1])
	for t in range(1, ticks + 1):
		w.step(by.get(t, []))
		w.drain_events()
		hashes.append(w.state_hash())
		if w.ended:
			break
	return w
