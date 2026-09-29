## SolverLog — what one run leaves behind: every event, every command, and compact per-tick
## samples (spot meter, Bellows' state/room/x/activity, Hush's room/x/hidden spot, reacting and
## input flags, applause). Metrics and Invariants read only this, so a log can be synthesised in a
## test ("a purpose-built bad log") without any world.
##
## Per-tick channels are PackedInt32Arrays indexed by sample number; `ticks[i]` is the world tick of
## sample i. String channels (rooms, states, spots, activities) store codes into `names`
## (code 0 = "").
class_name SolverLog
extends RefCounted

var episode: String = ""
var route: String = ""
var persona: String = ""
var start_tick: int = 0

## Every event, in order ({"e", "t", ...}).
var events: Array = []
## Every command sent: [tick_applied, cmd_dict].
var cmds: Array = []

# Per-tick samples.
var ticks := PackedInt32Array()
var hush_room := PackedInt32Array()
var hush_x := PackedInt32Array()          ## px
var hush_hidden := PackedInt32Array()     ## code of the hiding spot (0 = not hidden)
var hush_watched := PackedInt32Array()    ## 0/1
var hush_frozen := PackedInt32Array()     ## 0/1
var hush_state := PackedInt32Array()      ## code
var b_room := PackedInt32Array()
var b_x_sub := PackedInt32Array()
var b_state := PackedInt32Array()         ## code
var b_activity := PackedInt32Array()      ## code
var b_reacting := PackedInt32Array()      ## 0/1
var spot := PackedInt32Array()            ## "?" meter
var input := PackedInt32Array()           ## 1 = a command this tick or a hold is on
var hold_rig := PackedInt32Array()        ## 1 = rig hold on
var applause := PackedInt32Array()        ## tenths

var names: PackedStringArray = [""]
var _codes: Dictionary = {"": 0}

# Run facts (filled by the executor / runner; Invariants and Metrics read them).
var fill_ticks: int = 60                 ## "?" window of the episode (× 1.5 relaxed)
var relaxed: bool = false
var loop: Array = []                     ## [{a, once}] loop entries
var gated: PackedStringArray = []        ## loop activities with an uncapped player-led gate
var in_use: Dictionary = {}              ## hiding spot -> activity that opens it
var has_beryl: bool = false
var b_walk_sub: int = 240                ## Bellows' base walk speed, sub-px per tick
var launch_offset_s: float = 0.0
var bases_sum: int = -1                  ## Σ prank-line bases (tenths), −1 unknown
var final_hash: int = 0
var replay_hash: Variant = null          ## determinism replay result (int) or null = not run
var softlock_probes: Array = []          ## [{t, ok, why}]
var end_reason: String = ""
## The ⏩ persona model (ruling L2; Metrics): ticks after a drop (or hiding) before the persona re-presses ⏩,
## and whether it needs this Night's `director_cue {id: ghost_ff}` before it uses ⏩ at all (the slow
## first-timer before it has been taught).
var ff_repress_ticks: int = 30
var ff_needs_cue: bool = false
## Ticks Hush is busy climbing in (`hush.enter`), for rule 9's queued-command check.
var enter_ticks: int = 0
## `rules.combos`: null = every combo allowed, else the allowed combo ids (rule 12).
var combos_allowed: Variant = null


## Intern a string to a code.
func code(s: String) -> int:
	if _codes.has(s):
		return _codes[s]
	var c := names.size()
	names.append(s)
	_codes[s] = c
	return c


## Name of a code.
func name_of(c: int) -> String:
	return names[c] if c >= 0 and c < names.size() else ""


## Number of samples.
func size() -> int:
	return ticks.size()


## Append one per-tick sample read through `probe` (`input_flag`: a command or hold this tick).
func sample(probe: SolverProbe, input_flag: bool, rig_hold: bool) -> void:
	ticks.append(probe.tick())
	hush_room.append(code(probe.hush_room()))
	hush_x.append(probe.hush_x())
	var hs := probe.hush_hidden_spot()
	hush_hidden.append(code(hs))
	hush_watched.append(1 if hs != "" and probe.hush_watched() else 0)
	hush_frozen.append(1 if probe.hush_frozen() else 0)
	hush_state.append(code(probe.hush_state()))
	b_room.append(code(probe.bellows_room()))
	b_x_sub.append(probe.bellows_x_sub())
	b_state.append(code(probe.bellows_state()))
	b_activity.append(code(probe.bellows_activity()))
	b_reacting.append(1 if probe.bellows_reacting() else 0)
	spot.append(probe.spot_meter())
	input.append(1 if input_flag else 0)
	hold_rig.append(1 if rig_hold else 0)
	applause.append(probe.applause_tenths())


## Append a synthetic sample (tests). Missing keys default to "" / 0.
func add_sample(t: int, s: Dictionary) -> void:
	ticks.append(t)
	hush_room.append(code(SolverData.sv(s.get("hush_room", ""))))
	hush_x.append(int(s.get("hush_x", 0)))
	hush_hidden.append(code(SolverData.sv(s.get("hidden", ""))))
	hush_watched.append(1 if bool(s.get("watched", false)) else 0)
	hush_frozen.append(1 if bool(s.get("frozen", false)) else 0)
	hush_state.append(code(SolverData.sv(s.get("hush_state", "IDLE"))))
	b_room.append(code(SolverData.sv(s.get("b_room", ""))))
	b_x_sub.append(int(s.get("b_x_sub", 0)))
	b_state.append(code(SolverData.sv(s.get("b_state", "ROUTINE"))))
	b_activity.append(code(SolverData.sv(s.get("b_activity", ""))))
	b_reacting.append(1 if bool(s.get("reacting", false)) else 0)
	spot.append(int(s.get("spot", 0)))
	input.append(1 if bool(s.get("input", false)) else 0)
	hold_rig.append(1 if bool(s.get("hold_rig", false)) else 0)
	applause.append(int(s.get("applause", 0)))


## Write the command log in the `sim_run.gd --cmds` format (SimReplay): {episode, route, persona, ticks (the last
## tick), hash (the final state hash), …`meta`, cmds: [[tick, cmd], …]}, one command per line. Returns OK or an
## error code. Replaying it through sim_run gives the same hash (NightScene's e2e driver, ViewSandbox --cmds).
func write_cmds(path: String, meta: Dictionary = {}) -> int:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var head := {"persona": persona, "ticks": last_tick(), "hash": final_hash}
	head.merge(meta, true)
	var keys := head.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s: %s" % [JSON.stringify(str(k)), JSON.stringify(head[k])])
	var rows := PackedStringArray()
	for c in cmds:
		rows.append("  [%d, %s]" % [int(c[0]), JSON.stringify(c[1])])
	f.store_string("{%s,\n \"cmds\": [\n%s\n]}\n" % [", ".join(parts), ",\n".join(rows)])
	f.close()
	return OK


## Sample index of world tick `t` (−1 if not sampled).
func index_of_tick(t: int) -> int:
	if ticks.is_empty():
		return -1
	var i := t - ticks[0]
	if i >= 0 and i < ticks.size() and ticks[i] == t:
		return i
	var lo := 0
	var hi := ticks.size() - 1
	while lo <= hi:
		var mid := (lo + hi) / 2
		if ticks[mid] == t:
			return mid
		if ticks[mid] < t:
			lo = mid + 1
		else:
			hi = mid - 1
	return -1


## Events named `e` (optionally matching every key of `match_d`).
func events_named(e: String, match_d: Dictionary = {}) -> Array:
	var out: Array = []
	for ev in events:
		if SolverData.sv(ev.get("e", "")) != e:
			continue
		var ok := true
		for k in match_d:
			if str(ev.get(k, null)) != str(match_d[k]):
				ok = false
				break
		if ok:
			out.append(ev)
	return out


## The recorded commands grouped by tick, for replays: {tick: [cmd, ...]}.
func cmds_by_tick() -> Dictionary:
	var out := {}
	for c in cmds:
		var t: int = c[0]
		if not out.has(t):
			out[t] = []
		(out[t] as Array).append(c[1])
	return out


## Last sampled world tick (start_tick if none).
func last_tick() -> int:
	return ticks[ticks.size() - 1] if not ticks.is_empty() else start_tick
