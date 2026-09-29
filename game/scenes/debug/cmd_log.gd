## CmdLog — the device's command log (TECH §6.7, s2-night §4.5): every command the player's thumbs
## pushed, as `user://last_session.json` in the `sim_run.gd --cmds` format
## (`{"episode", "cmds": [[tick, cmd], …], "ticks", "build"}`), so a phone session replays headless:
## `tools/scripts/sandbox.sh x -s res://tools/sim_run.gd -- --episode=<id> --cmds=/abs/last_session.json`.
## Written at the end of a Night, on pause / backgrounding, and on quit (debug builds and the
## `mnd_devlog` profile APK only — the same gate as DeviceLog).
class_name CmdLog
extends RefCounted

const PATH := "user://last_session.json"

static var path: String = PATH


## Write `cmds` ([[tick, cmd], …], SimDriver.cmd_log) for `episode`. Returns OK or an error.
static func write(episode: String, cmds: Array, last_tick: int = -1) -> int:
	if not DeviceLog.active():
		return ERR_UNAVAILABLE
	var rows: Array = []
	for c in cmds:
		if c is Array and (c as Array).size() >= 2:
			rows.append([int(c[0]), c[1]])
	var t := last_tick
	if t < 0 and not rows.is_empty():
		t = int(rows[rows.size() - 1][0])
	var doc := {"episode": episode, "cmds": rows, "ticks": maxi(t, 0) + 600,
		"build": "debug" if OS.is_debug_build() else "profile"}
	return OK if SafeFile.write_text(path, JSON.stringify(doc)) else ERR_CANT_CREATE


## Read a log back ({} when missing / invalid).
static func read(p: String = "") -> Dictionary:
	var fp := p if p != "" else path
	if not FileAccess.file_exists(fp):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(fp)) != OK or not (j.data is Dictionary):
		return {}
	return j.data
