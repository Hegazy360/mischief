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
## * `--curtain-call=<reason>`  end the Night right after the start/seek with that `night_end` reason
##                      (bow, g0_done, prologue_done …): shots of the curtain call.
## * `--open=pause|script|tbc` open the pause menu / the Script panel / the "To be continued…" card (shots).
## * `--view=2d|3d`     the view (ruling R1; default boot_config.json `view`).
## * `--msaa=off|0|2|4` 3D MSAA for this run (timing runs on the CPU box: `off`, index R11; default Settings `msaa_3d`).
## * `--no-captions`    hide the pun captions and stamps (caption-free reviewer packets, `r3d-qa`).
## * `--hud=off`        the world only: no HUD, world overlays, bubble or Stalls (set / value shots).
## * `--window=sim|lean` the Bellows-window mode for this run (ruling R15; default Settings `bellows_window`).
## Pure: `parse(args)` returns a Dictionary; `read_cmds(path)` loads a command log.
class_name NightArgs
extends RefCounted

const DEFAULT_EPISODE := "p00_curtain_up"


## Parse user args (OS.get_cmdline_user_args()). Keys: episode (""), cmds_path (""), seek_tick (−1),
## paused (false), relaxed (false), no_curtain (false), given (true when any NightScene flag appeared).
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {"episode": "", "cmds_path": "", "seek_tick": -1, "paused": false, "relaxed": false,
		"no_curtain": false, "curtain_call": "", "open": "", "given": false, "view": "", "msaa": "", "no_captions": false,
		"hud": true, "window": ""}
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
		elif a.begins_with("--curtain-call="):
			out["curtain_call"] = a.substr(15)
			out["given"] = true
		elif a.begins_with("--open="):
			out["open"] = a.substr(7)
			out["given"] = true
		elif a.begins_with("--view="):
			var v := a.substr(7).to_lower()
			out["view"] = v if v == "2d" or v == "3d" else ""
		elif a.begins_with("--msaa="):
			out["msaa"] = msaa_value(a.substr(7))
		elif a == "--no-captions":
			out["no_captions"] = true
		elif a == "--hud=off":
			out["hud"] = false
		elif a.begins_with("--window="):
			var w := a.substr(9)
			out["window"] = w if w == "sim" or w == "lean" else ""
	return out


## `--msaa=` value → "off" | "2" | "4" ("" = invalid / not given).
static func msaa_value(v: String) -> String:
	match v.to_lower():
		"off", "0", "false", "none":
			return "off"
		"2", "2x", "on", "true":
			return "2"
		"4", "4x":
			return "4"
	return ""


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
