## Save — the player's progress (`user://save.json`, TECH §7).
##
## Schema (version 1):
##   {"version": 1, "prologue_done": bool,
##    "nights": {"<episode>": {"played": int, "stars": [bool, bool, bool], "best_applause": int,
##               "lines": [line ids], "candles": [line ids], "encores": [ids]}},
##    "seen": {"<key>": true}, "stats": {"catches": int, "pranks": int, "play_s": int}}
## Writes are atomic (`.tmp` + rename, previous good copy kept as `.bak` — SafeFile) and
## debounced by SAVE_DELAY_SEC; `flush()` writes now. Loading never crashes:
##   * an older / versionless file is migrated (`migrate`), every field sanitised;
##   * a file from a newer build is copied to `<path>.v<N>` and the game starts fresh;
##   * a corrupt file is copied to `<path>.corrupt`, then the `.bak` copy is tried, else fresh.
## Registered by the orchestrator as the `Save` autoload; tests instantiate the script and set
## `path` first.
extends Node

## Emitted after a record changed (id = episode id, "" for seen/stats/prologue).
signal changed(id: String)

const PATH := "user://save.json"
const VERSION := 1
const SAVE_DELAY_SEC := 0.5

## Override before _ready / load_save (tests).
var path: String = PATH
## Completed writes (tests).
var save_count: int = 0
## What the last load did: "fresh", "loaded", "migrated", "backup", "corrupt", "future".
var last_load: String = "fresh"

var _data: Dictionary = {}
var _pending := false
var _timer: float = 0.0


func _init() -> void:
	_data = fresh()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()


func _process(delta: float) -> void:
	if not _pending:
		return
	_timer -= delta
	if _timer <= 0.0:
		flush()


# --- public API (TECH §7) ------------------------------------------------------------------

## The record for episode `id` (a copy; a zeroed record when never played).
func night(id: String) -> Dictionary:
	var n: Variant = (_data["nights"] as Dictionary).get(id)
	if n is Dictionary:
		return (n as Dictionary).duplicate(true)
	return empty_night()


## Merge one finished Night into the save. `result` keys (all optional): `stars` [b,b,b],
## `applause` int, `lines` [ids done], `candles` [ids solved after a step-3 hint],
## `encores` [ids], `catches` int, `pranks` int, `play_s` int. Stars and lines only ever grow;
## best_applause is the max; a line's candle clears once it has been done without a hint.
## Returns the merged record.
func record_result(id: String, result: Dictionary) -> Dictionary:
	var n := night(id)
	n["played"] = int(n["played"]) + 1
	var old_stars: Array = n["stars"]
	var new_stars: Array = result.get("stars", [])
	for i in 3:
		old_stars[i] = bool(old_stars[i]) or (i < new_stars.size() and bool(new_stars[i]))
	n["best_applause"] = maxi(int(n["best_applause"]), int(result.get("applause", 0)))
	var lines: Array = n["lines"]
	var candles: Array = n["candles"]
	var res_lines: Array = result.get("lines", [])
	var res_candles: Array = result.get("candles", [])
	var clean_before: Array = []
	for l in lines:
		if not candles.has(l):
			clean_before.append(l)
	for l in res_lines:
		if not lines.has(String(l)):
			lines.append(String(l))
	for c in res_candles:
		if not candles.has(String(c)) and not clean_before.has(String(c)):
			candles.append(String(c))
	for l in res_lines:
		if not res_candles.has(l) and candles.has(String(l)):
			candles.erase(String(l))
	var enc: Array = n["encores"]
	for e in result.get("encores", []):
		if not enc.has(String(e)):
			enc.append(String(e))
	(_data["nights"] as Dictionary)[id] = n
	var st: Dictionary = _data["stats"]
	for k in ["catches", "pranks", "play_s"]:
		st[k] = int(st[k]) + maxi(0, int(result.get(k, 0)))
	_touch(id)
	return n.duplicate(true)


## Marks a "seen" key (reaction variant, bit, combo …). True if it was new (→ "+NEW!").
func mark_seen(key: String) -> bool:
	var seen: Dictionary = _data["seen"]
	if seen.has(key):
		return false
	seen[key] = true
	_touch("")
	return true


## Has `key` been seen?
func is_seen(key: String) -> bool:
	return (_data["seen"] as Dictionary).has(key)


## The Prologue has been played through.
func set_prologue_done() -> void:
	if bool(_data["prologue_done"]):
		return
	_data["prologue_done"] = true
	_touch("")


## Write now if anything changed since the last write.
func flush() -> void:
	if not _pending:
		return
	_pending = false
	if SafeFile.write_text(path, JSON.stringify(_data, "  ", true)):
		save_count += 1
	else:
		push_warning("Save: could not write %s" % path)


# --- extras ----------------------------------------------------------------------------------

## True once the Prologue was completed.
func prologue_done() -> bool:
	return bool(_data["prologue_done"])


## Lifetime stats (copy): catches, pranks, play_s.
func stats() -> Dictionary:
	return (_data["stats"] as Dictionary).duplicate()


## The whole save (copy; debugging / Playbill).
func data() -> Dictionary:
	return _data.duplicate(true)


## True while a debounced write is waiting.
func is_pending() -> bool:
	return _pending


## Wipe progress (tests / a future "reset progress" setting); written like any change.
func reset() -> void:
	_data = fresh()
	_touch("")


## (Re)load from `path` with migration and corruption handling (see header).
func load_save() -> void:
	_pending = false
	if not FileAccess.file_exists(path):
		var from_bak := _try_backup()
		last_load = "backup" if from_bak else "fresh"
		if not from_bak:
			_data = fresh()
		return
	var parsed: Variant = parse_json(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		DirAccess.copy_absolute(path, path + ".corrupt")
		push_warning("Save: %s is corrupt; kept a copy at %s.corrupt" % [path, path])
		if _try_backup():
			last_load = "backup"
		else:
			_data = fresh()
			last_load = "corrupt"
		_pending = true   # rewrite a clean file
		flush()
		return
	var d: Dictionary = parsed
	var ver := _num(d.get("version", 0))
	if ver > VERSION:
		DirAccess.copy_absolute(path, "%s.v%d" % [path, ver])
		push_warning("Save: %s has version %d (> %d); kept a copy and started fresh" % [path, ver, VERSION])
		_data = fresh()
		last_load = "future"
		_pending = true
		flush()
		return
	_data = migrate(d)
	last_load = "migrated" if ver < VERSION else "loaded"
	if ver < VERSION:
		_pending = true
		flush()


# --- pure helpers ----------------------------------------------------------------------------

## Parsed JSON, or null when `text` is not valid JSON (never logs an engine error).
static func parse_json(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## A new, empty save.
static func fresh() -> Dictionary:
	return {"version": VERSION, "prologue_done": false, "nights": {}, "seen": {},
		"stats": {"catches": 0, "pranks": 0, "play_s": 0}}


## An empty Night record.
static func empty_night() -> Dictionary:
	return {"played": 0, "stars": [false, false, false], "best_applause": 0, "lines": [], "candles": [],
		"encores": []}


## Migrate any older / partial save dictionary to VERSION and sanitise every field.
## v0 (pre-release dev files, no "version"): `stars` may be an int count and `best` the best
## applause; unknown keys are dropped.
static func migrate(d: Dictionary) -> Dictionary:
	var out := fresh()
	out["prologue_done"] = _truthy(d.get("prologue_done", false))
	var nights: Variant = d.get("nights", {})
	if nights is Dictionary:
		for id in nights:
			var src: Variant = (nights as Dictionary)[id]
			if src is Dictionary:
				(out["nights"] as Dictionary)[String(id)] = _sanitize_night(src)
	var seen: Variant = d.get("seen", {})
	if seen is Dictionary:
		for k in seen:
			if _truthy((seen as Dictionary)[k]):
				(out["seen"] as Dictionary)[String(k)] = true
	elif seen is Array:
		for k in seen:
			(out["seen"] as Dictionary)[String(k)] = true
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k in ["catches", "pranks", "play_s"]:
			(out["stats"] as Dictionary)[k] = maxi(0, _num((st as Dictionary).get(k, 0)))
	return out


## bool of a JSON value (non-bool / non-number values are false).
static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
	return false


static func _num(v: Variant) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0


static func _sanitize_night(src: Dictionary) -> Dictionary:
	var n := empty_night()
	n["played"] = maxi(0, _num(src.get("played", 0)))
	var stars: Variant = src.get("stars", [])
	if stars is Array:
		for i in mini(3, (stars as Array).size()):
			(n["stars"] as Array)[i] = _truthy((stars as Array)[i])
	elif typeof(stars) in [TYPE_INT, TYPE_FLOAT]:
		for i in clampi(int(stars), 0, 3):
			(n["stars"] as Array)[i] = true
	n["best_applause"] = maxi(0, _num(src.get("best_applause", src.get("best", 0))))
	for k in ["lines", "candles", "encores"]:
		var a: Variant = src.get(k, [])
		if a is Array:
			for v in a:
				if not (n[k] as Array).has(String(v)):
					(n[k] as Array).append(String(v))
	return n


func _try_backup() -> bool:
	var bak := path + ".bak"
	if not FileAccess.file_exists(bak):
		return false
	var parsed: Variant = parse_json(FileAccess.get_file_as_string(bak))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) > VERSION:
		return false
	_data = migrate(parsed)
	return true


func _touch(id: String) -> void:
	changed.emit(id)
	if not is_inside_tree():
		_pending = true
		flush()
		return
	_pending = true
	_timer = SAVE_DELAY_SEC


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_PREDELETE:
		flush()
