## E2eRoute — the solver route → command log dumper the e2e driver replays (s2-night §3: the in-process
## fallback for `solve.sh --dump-cmds`, used when no `--e2e-cmds=` file is given, e.g. under
## capture.sh). Plays `<episode>/<route>` from `data/solutions/<episode>.json` headless with the
## solver's Executor on a fresh SimWorld and returns its commands in the `sim_run.gd --cmds` format.
class_name E2eRoute
extends RefCounted

const MAX_S := 900


## {ok, cmds: [[tick, cmd], …], ticks, hash, end_reason, error} for one route.
static func dump(episode: String, route: String, data_root: String = "res://data") -> Dictionary:
	var sol_path := "%s/solutions/%s.json" % [data_root, episode]
	if not FileAccess.file_exists(sol_path):
		return {"ok": false, "cmds": [], "error": "no solution file %s" % sol_path}
	var sol := SolutionDef.load_file(sol_path)
	if sol == null or not sol.has_method("resolve"):
		return {"ok": false, "cmds": [], "error": "cannot load %s" % sol_path}
	var names: Variant = sol.get("routes")
	if names is Dictionary and not (names as Dictionary).has(route):
		return {"ok": false, "cmds": [], "error": "no route '%s' in %s" % [route, sol_path]}
	var data := SolverData.load_dir(data_root)
	var db: Object = SolverHooks.load_db(data_root)
	var r: Dictionary = sol.resolve(route)
	var make := SolverHooks.factory_for("sim", db, data, episode, {})
	var world: Object = make.call()
	if world == null:
		return {"ok": false, "cmds": [], "error": "SimWorld.create(%s) failed" % episode}
	var ex := Executor.new(world, r, r["persona"], Callable(), data, {"episode": episode})
	var rep: Dictionary = ex.run(MAX_S * 60)
	return {"ok": bool(rep.get("ok", false)), "cmds": ex.log.cmds.duplicate(true), "ticks": int(world.get("tick")),
		"hash": int(ex.log.final_hash), "end_reason": String(world.get("end_reason")), "error": "",
		"fail": rep.get("fail", [])}


## Read a `--dump-cmds` / `sim_run --cmds` file → [[tick, cmd], …] ([] when missing).
static func read_file(path: String) -> Array:
	return NightArgs.read_cmds(path)
