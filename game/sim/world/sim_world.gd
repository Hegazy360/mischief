## SimWorld — one deterministic Night (TECH §3.4). Pure logic: RefCounted only, integers only.
##
## Tick order (`step()`, TECH §3.6):
##   1. tick += 1; commands applied in array order (validation, the single queue).
##   2. Director: gates, cues, safety net, the Prologue's can't-fail and end.
##   3. SimHush.update: busy timers, rig ring, movement (doors, stairs), dive / pop out, freeze, squeak arm,
##      queued command, carried items + restock, noise emission.
##   4. Stage-3 actors (null-safe seams: beryl, delphine).
##   5. SimBellows.update: state machine, routine + detours, walking (entry warning, doorway pause,
##      look-back, bump), hooks → Pranks.fire, reactions, Meltdown, chase / search, caught hold.
##   6. Senses.update: sight, the "?" meter, near miss, spotted, face-to-face windows.
##   7. Temper.update: hold, decay (paused during fix-ups, reactions, Meltdown), tiers, Running Gag end.
##   8. ScriptGoals.update: lines, Big Number unseal, all lines, stars (applause changes are applied by
##      Scoring as they happen during the tick).
##   9. Invariant counters (config.invariants), hash log (config.record_hash_every).
##
## Determinism: no Time, no randf, no floats in state, every iteration over sorted id arrays; the only
## randomness is `rng` (seeded from the episode). Snapshot fields for the view: see SimHush / SimBellows.
## Events: every name in SimEvents, `{"e": name, "t": tick, ...}`, stamped at emission.
class_name SimWorld
extends RefCounted

## Ticks since curtain up.
var tick: int = 0
var ended: bool = false
## "bow" | "hook" | "prologue_done"
var end_reason: String = ""
var hush: SimHush = null
var bellows: SimBellows = null
## Stage-3 actors: null unless the episode has them.
var beryl: SimBeryl = null
var delphine: SimDelphine = null
var episode: EpisodeDef = null
var db: ContentDB = null
## [[tick, hash], ...] when config.record_hash_every > 0.
var hash_log: Array = []
## Fairness counters when config.invariants (tests/solver only).
var invariant_counters: Dictionary = {}

var ctx: SimCtx = null
var config: Dictionary = {}
var rng: Rng = null

# systems (TECH §3.7)
var routine: Routine = null
var senses: Senses = null
var temper: Temper = null
var pranks: Pranks = null
var reactions: Reactions = null
var residue: Residue = null
var scoring: Scoring = null
var goals: ScriptGoals = null
var bits: Bits = null
var chase: Chase = null
var director: Director = null

var _events: Array = []
## Event index for the `event_seen` / `event_ago_ge_s` conditions: "name" and "name|key=value" → first tick.
var seen: Dictionary = {}
## Occurrence counts for the same keys (`count_ge`).
var seen_n: Dictionary = {}
## Events emitted so far this Night (lets the Director skip re-evaluating event-only cues; not hashed —
## it only gates a cache whose results are identical either way).
var emit_serial: int = 0
var _record_every: int = 0
var _invariants: bool = false
var _last_hush_room_for_inv: int = -1


## Create a Night. config: {relaxed: bool, seed: int, record_hash_every: int (0 = off), invariants: bool}.
## Returns null when the episode id is unknown.
static func create(p_db: ContentDB, episode_id: String, p_config: Dictionary = {}) -> SimWorld:
	if p_db == null or not p_db.episodes.has(episode_id):
		push_warning("SimWorld.create: unknown episode '%s'" % episode_id)
		return null
	var w := SimWorld.new()
	w.db = p_db
	w.episode = p_db.episodes[episode_id]
	w.config = p_config.duplicate()
	w.ctx = SimCtx.build(p_db, w.episode, w.config)
	w._record_every = int(w.config.get("record_hash_every", 0))
	w._invariants = bool(w.config.get("invariants", false))
	w._init_state()
	return w


func _init_state() -> void:
	tick = 0
	ended = false
	end_reason = ""
	hash_log = []
	invariant_counters = {}
	_events = []
	seen = {}
	seen_n = {}
	emit_serial = 0
	rng = Rng.new(ctx.seed)
	routine = Routine.new()
	senses = Senses.new()
	temper = Temper.new()
	pranks = Pranks.new()
	reactions = Reactions.new()
	residue = Residue.new()
	scoring = Scoring.new()
	goals = ScriptGoals.new()
	bits = Bits.new()
	chase = Chase.new()
	director = Director.new()
	hush = SimHush.new()
	bellows = SimBellows.new()
	beryl = null
	delphine = null
	pranks.setup(self)
	goals.setup(self)
	director.setup(self)
	hush.setup(self)
	bellows.setup(self)
	if _invariants:
		for k in ["catch_without_window", "entry_without_warning", "caught_unwatched_hidden", "reaction_overlap",
				"spot_while_blind", "fast_nonchase", "negative_applause"]:
			invariant_counters[k] = 0


## Retry in place: identical to a fresh create().
func reset() -> void:
	_init_state()


## Advance ONE tick. `cmds` = Array[Dictionary] (SimCmd).
func step(cmds: Array = []) -> void:
	if ended:
		return
	tick += 1
	for c in cmds:
		if typeof(c) == TYPE_DICTIONARY:
			hush.apply_cmd(self, c)
		else:
			emit(SimEvents.CMD_REJECTED, {"c": "", "why": "not_a_dictionary"})
	if ended:
		_post_tick()
		return
	director.update(self)
	hush.update(self)
	if beryl != null:
		beryl.update(self)
	if delphine != null:
		delphine.update(self)
	bellows.update(self)
	senses.update(self)
	temper.update(self)
	goals.update(self)
	_post_tick()


func _post_tick() -> void:
	if _invariants:
		_update_invariants()
	if _record_every > 0 and tick % _record_every == 0:
		hash_log.append([tick, state_hash()])


## Events since the last drain, each {"e": name, "t": tick, ...}.
func drain_events() -> Array:
	var out := _events
	_events = []
	return out


## Events emitted but not yet drained (read-only peek).
func pending_events() -> Array:
	return _events


## Emit an event (sim-internal). Payload values must be int / String / bool.
func emit(name: String, payload: Dictionary = {}) -> void:
	var ev := {"e": name, "t": tick}
	emit_serial += 1
	if not seen.has(name):
		seen[name] = tick
	seen_n[name] = int(seen_n.get(name, 0)) + 1
	for k in payload:
		var v: Variant = payload[k]
		ev[k] = v
		var key := "%s|%s=%s" % [name, k, str(v)]
		if not seen.has(key):
			seen[key] = tick
		seen_n[key] = int(seen_n.get(key, 0)) + 1
	_events.append(ev)


## End the Night (sim-internal).
func end_night(reason: String) -> void:
	if ended:
		return
	ended = true
	end_reason = reason
	goals.on_curtain(self)
	emit(SimEvents.NIGHT_END, {"reason": reason})


# --- accessors (TECH §3.4) ---------------------------------------------------------------------

## PrankState of a prank (Pranks.LOCKED … LANDED); LOCKED for unknown ids.
func prank_state(id: String) -> int:
	var i := db.prank_idx(id)
	return pranks.state[i] if i >= 0 else Pranks.LOCKED


## Per-mille progress of the prank's current rig step (1000 once rigged).
func rig_progress_pm(id: String) -> int:
	var i := db.prank_idx(id)
	return pranks.progress_pm(self, i) if i >= 0 else 0


## [{id, done, req, big_number, sealed, candle}] in Script order.
func line_states() -> Array:
	return goals.line_states(self)


## Applause in tenths.
func applause_tenths() -> int:
	return scoring.applause


## Curtain Calls [★, ★★, ★★★] as they stand now (all false in the Prologue).
func stars() -> Array:
	return goals.stars(self)


## Running Gag link count.
func link() -> int:
	return bellows.link


## Running Gag fuse: remaining hold + (temper − 20) / 2 seconds, in ticks (0 when not live).
func fuse_ticks() -> int:
	return temper.fuse_ticks(self)


## Tomatoes taken so far.
func tomatoes() -> int:
	return bellows.tomatoes


## Tomato limit (−1 = unlimited).
func tomatoes_max() -> int:
	return ctx.tomatoes_max


## {kind, enabled, stock:[items], occupant, in_use_next, spent, rigged, needs_item, seen}
func hotspot_state(id: String) -> Dictionary:
	return pranks.hotspot_state(self, id)


## {next: activity|detour id, icon, ring_ticks, glyph, ear_pips}
func bubble() -> Dictionary:
	return bellows.bubble(self)


## Bellows' walking line for the next `ticks` ticks: [room, x_sub, ...] sampled every 10 ticks.
func bellows_path_preview(ticks: int) -> PackedInt32Array:
	return bellows.path_preview(self, ticks)


## True when Hush has visited the hotspot's room (Script "???" reveal, item silhouettes).
func hush_can_see(hotspot_id: String) -> bool:
	var h := db.house.hotspot(hotspot_id)
	return h != null and h.room_idx >= 0 and (hush.visited_mask & (1 << h.room_idx)) != 0


## Room id of a room idx ("" if none).
func room_id(r: int) -> String:
	return db.house.rooms[r].id if r >= 0 and r < db.house.rooms.size() else ""


## Room idx of a room id (-1 if none).
func room_idx(id: String) -> int:
	return int(db.house.room_index.get(id, -1))


# --- determinism ----------------------------------------------------------------------------------

## FNV-1a over every mutable field in a fixed order.
func state_hash() -> int:
	var h := StateHash.OFFSET
	h = StateHash.mix(h, tick)
	h = StateHash.mix_bool(h, ended)
	h = StateHash.mix_str(h, end_reason)
	h = StateHash.mix(h, rng.state)
	h = hush.hash_into(h)
	h = bellows.hash_into(h)
	h = routine.hash_into(h)
	h = senses.hash_into(h)
	h = temper.hash_into(h)
	h = pranks.hash_into(h)
	h = reactions.hash_into(h)
	h = residue.hash_into(h)
	h = scoring.hash_into(h)
	h = goals.hash_into(h)
	h = bits.hash_into(h)
	h = chase.hash_into(h)
	h = director.hash_into(h)
	return h


## Deep copy of the mutable state (shares ContentDB and the episode context).
func clone() -> SimWorld:
	var w := SimWorld.new()
	w.db = db
	w.episode = episode
	w.config = config
	w.ctx = ctx
	w._record_every = _record_every
	w._invariants = _invariants
	w.tick = tick
	w.ended = ended
	w.end_reason = end_reason
	w.hash_log = hash_log.duplicate(true)
	w.invariant_counters = invariant_counters.duplicate()
	w._events = _events.duplicate(true)
	w.seen = seen.duplicate()
	w.seen_n = seen_n.duplicate()
	w.emit_serial = emit_serial
	w.rng = rng.duplicate_rng()
	w.hush = hush.copy()
	w.bellows = bellows.copy()
	w.routine = routine.copy()
	w.senses = senses.copy()
	w.temper = temper.copy()
	w.pranks = pranks.copy()
	w.reactions = reactions.copy()
	w.residue = residue.copy()
	w.scoring = scoring.copy()
	w.goals = goals.copy()
	w.bits = bits.copy()
	w.chase = chase.copy()
	w.director = director.copy()
	w._last_hush_room_for_inv = _last_hush_room_for_inv
	return w


# --- invariant counters --------------------------------------------------------------------------

func _update_invariants() -> void:
	for ev in _events:
		if int(ev["t"]) != tick:
			continue
		match str(ev["e"]):
			SimEvents.CAUGHT:
				if not senses.window_ok:
					invariant_counters["catch_without_window"] += 1
				if hush.hidden_spot >= 0 and hush.watched_spot < 0 and str(ev.get("cause", "")) != "face_to_face":
					invariant_counters["caught_unwatched_hidden"] += 1
			SimEvents.B_ROOM:
				if not bool(ev.get("chase", false)) and bellows.state != SimBellows.REACTING \
						and room_idx(str(ev["room"])) == hush.room and not bellows.warned_ok(self, hush.room):
					invariant_counters["entry_without_warning"] += 1
			SimEvents.REACTION_START:
				if reactions.active_count > 1:
					invariant_counters["reaction_overlap"] += 1
			SimEvents.SPOT_START:
				if bellows.state == SimBellows.REACTING or tick < bellows.blind_after_until:
					invariant_counters["spot_while_blind"] += 1
	if bellows.state != SimBellows.CHASE and bellows.last_step_px > Fx.mul_pct(SimConst.B_WALK, 115):
		invariant_counters["fast_nonchase"] += 1
	if scoring.applause < 0:
		invariant_counters["negative_applause"] += 1
