## SimReplay — replay a command log (`sim_run.gd --cmds`, `solve.sh --dump-cmds`, `fuzz.sh --dump-cmds`) on a
## fresh world. The file format:
##   {"episode": id, "ticks": last tick, "hash": final state hash, "cmds": [[tick, cmd], …], …}
## or a bare [[tick, cmd], …] list; a command at tick t is applied by the step that produces tick t.
## NightScene's e2e driver and ViewSandbox `--sim --cmds` read the same files.
class_name SimReplay
extends RefCounted


## Parse a command file: {cmds: Array, episode: String ("" unknown), ticks: int (-1 unknown), hash: int (-1
## unknown), meta: Dictionary (the whole object)} or {} when unreadable.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return from_data(j.data)


## The same from parsed JSON.
static func from_data(d: Variant) -> Dictionary:
	if typeof(d) == TYPE_ARRAY:
		return {"cmds": d, "episode": "", "ticks": -1, "hash": -1, "meta": {}}
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var o: Dictionary = d
	return {"cmds": o.get("cmds", []), "episode": str(o.get("episode", "")), "ticks": int(o.get("ticks", -1)),
		"hash": int(o.get("hash", -1)), "meta": o}


## tick → [cmd, …] (file order kept within a tick).
static func by_tick(cmds: Array) -> Dictionary:
	var out := {}
	for e in cmds:
		if typeof(e) == TYPE_ARRAY and (e as Array).size() >= 2:
			var t := int(e[0])
			if not out.has(t):
				out[t] = []
			(out[t] as Array).append(e[1])
	return out


## Step `w` from its current tick to `ticks` (or its end) applying `cmds`; `on_tick` (optional) is called
## with (w, events) after every step. Returns `w`.
static func run(w: SimWorld, cmds: Array, ticks: int, on_tick: Callable = Callable()) -> SimWorld:
	var by := by_tick(cmds)
	while w.tick < ticks and not w.ended:
		w.step(by.get(w.tick + 1, []))
		var evs := w.drain_events()
		if on_tick.is_valid():
			on_tick.call(w, evs)
	return w
