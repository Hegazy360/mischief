## NightArgs — the NightScene command-line flags (debug builds; NightScene as the main scene).
##
##   godot … res://scenes/night/NightScene.tscn -- --episode=<id> [--cmds=/abs.json]
##         [--seek-tick=<n>] [--paused] [--relaxed] [--no-curtain]
## * `--episode=<id>`   the episode to play (default `p00_curtain_up`).
## * `--cmds=/abs.json` a command log in `sim_run.gd --cmds` format (`{"cmds": [[tick, cmd], …]}` or a
##                      bare `[[tick, cmd], …]` list) replayed through `SimDriver.push_cmd` at the
##                      logged ticks (the sim is deterministic, so the route plays exactly).
## * `--seek-tick=<n>`  run the sim headless (views muted) to tick n before the first frame, then
##                      `settle_gags()` + `pip.settle()`.
## * `--paused`         hold after the seek (the driver stays paused; nothing moves).
## * `--relaxed`        Relaxed mode.
## * `--no-curtain`     start playing on the first frame (no curtain rise; shots of early ticks).
## Pure: `parse(args)` returns a Dictionary; `read_cmds(path)` loads a command log.
class_name NightArgs
extends RefCounted

const DEFAULT_EPISODE := "p00_curtain_up"


## Parse user args (OS.get_cmdline_user_args()). Keys: episode (""), cmds_path (""), seek_tick (−1),
## paused (false), relaxed (false), no_curtain (false), given (true when any NightScene flag appeared).
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {"episode": "", "cmds_path": "", "seek_tick": -1, "paused": false, "relaxed": false,
		"no_curtain": false, "given": false}
	for a in args:
		if a.begins_with("--episode="):
			out["episode"] = a.substr(10)
			out["given"] = true
		elif a.begins_with("--cmds="):
			out["cmds_path"] = a.substr(7)
			out["given"] = true
		elif a.begins_with("--seek-tick="):
			out["seek_tick"] = maxi(0, int(a.substr(12)))
			out["given"] = true
		elif a == "--paused":
			out["paused"] = true
			out["given"] = true
		elif a == "--relaxed":
			out["relaxed"] = true
		elif a == "--no-curtain":
			out["no_curtain"] = true
	return out


## A command log → Array of [tick, cmd] (sorted by tick, stable). Missing / invalid → [].
static func read_cmds(path: String) -> Array:
	if path == "" or not FileAccess.file_exists(path):
		return []
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("NightArgs: %s:%d %s" % [path, j.get_error_line(), j.get_error_message()])
		return []
	return normalise_cmds(j.data)


## `{"cmds": [...]}` or a bare list → [[tick:int, cmd:Dictionary], …] sorted by tick (stable).
static func normalise_cmds(v: Variant) -> Array:
	var raw: Variant = v
	if v is Dictionary:
		raw = (v as Dictionary).get("cmds", [])
	var out: Array = []
	if not (raw is Array):
		return out
	for e in raw:
		if e is Array and (e as Array).size() >= 2 and (e as Array)[1] is Dictionary:
			out.append([int(e[0]), (e[1] as Dictionary).duplicate(true)])
	# Stable sort by tick (keeps array order within a tick: SimDriver applies them in order).
	var idx: Array = []
	for i in out.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ta := int(out[a][0])
		var tb := int(out[b][0])
		return ta < tb or (ta == tb and a < b))
	var sorted: Array = []
	for i in idx:
		sorted.append(out[i])
	return sorted
