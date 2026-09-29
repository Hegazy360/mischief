## BootRouting — where the game goes at launch and after a Night (pure, s2-night §4.2–§4.3).
##
## * `scenes/boot/boot_config.json` `{"start": "auto" | "stage_door" | "<episode id>"}` (the
##   orchestrator sets `stage_door` for the Gate-0 APK, `auto` for the Fun-Gate APK).
## * `auto`: first launch (`Save.prologue_done()` false) → the Prologue; later → the first slice Night
##   without ★ (N01, N02); else the Playbill stub.
## * `stage_door` exists only in debug builds (a release build falls back to `auto`).
## * `next_episode(id)`: the next **final** episode after `id` by (act, index) — never a draft;
##   "" after the last slice Night (the curtain call then shows "To be continued…" → Playbill).
class_name BootRouting
extends RefCounted

const CONFIG := "res://scenes/boot/boot_config.json"
const PROLOGUE := "p00_curtain_up"
const SLICE_NIGHTS: PackedStringArray = ["n01_throat_tea", "n02_something_fishy"]

## Set by the e2e driver (debug) before Boot routes on its third frame: a `start` value that wins over
## boot_config.json and `--start`.
static var override_start: String = ""


## `start` from boot_config.json ("auto" when missing / invalid).
static func read_config(path: String = CONFIG) -> String:
	if not FileAccess.file_exists(path):
		return "auto"
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return "auto"
	var s := String((j.data as Dictionary).get("start", "auto"))
	return s if s != "" else "auto"


## The launch route: {route: "night"|"stage_door"|"playbill", params: {...}}.
## `episodes`: id → {status, act, index}; `prologue_done`; `stars_of`: id → [★, ★★, ★★★] (Save).
static func start_for(start: String, prologue_done: bool, stars_of: Dictionary, episodes: Dictionary,
		debug: bool = true) -> Dictionary:
	if start == "stage_door":
		if debug:
			return {"route": "stage_door", "params": {}}
		start = "auto"
	if start != "auto" and episodes.has(start):
		return {"route": "night", "params": {"episode": start, "from": "boot"}}
	if not prologue_done and episodes.has(PROLOGUE):
		return {"route": "night", "params": {"episode": PROLOGUE, "from": "boot"}}
	for id in SLICE_NIGHTS:
		if not episodes.has(id) or String((episodes[id] as Dictionary).get("status", "")) != "final":
			continue
		var st: Variant = stars_of.get(id, [])
		var starred := st is Array and (st as Array).size() > 0 and bool((st as Array)[0])
		if not starred:
			return {"route": "night", "params": {"episode": id, "from": "boot"}}
	return {"route": "playbill", "params": {}}


## Next final episode after `id` by (act, index); "" when none (or `id` is not a final episode).
static func next_after(id: String, episodes: Dictionary) -> String:
	if not episodes.has(id) or String((episodes[id] as Dictionary).get("status", "")) != "final":
		return ""
	var me: Dictionary = episodes[id]
	var key := int(me.get("act", 0)) * 1000 + int(me.get("index", 0))
	var best := ""
	var best_key := 1 << 30
	for other in episodes:
		var e: Dictionary = episodes[other]
		if String(e.get("status", "")) != "final" or String(other) == id:
			continue
		var k := int(e.get("act", 0)) * 1000 + int(e.get("index", 0))
		if k > key and k < best_key:
			best_key = k
			best = String(other)
	return best


## id → {status, act, index} from the Content autoload's ContentDB ({} without it).
static func episode_table() -> Dictionary:
	var out := {}
	var c := ViewKit.autoload("Content")
	var db: Variant = c.get("db") if c != null else null
	var eps: Variant = (db as Object).get("episodes") if db is Object else null
	if not (eps is Dictionary):
		return out
	for id in eps:
		var e: Variant = eps[id]
		if e is Object:
			out[String(id)] = {"status": String((e as Object).get("status")), "act": int((e as Object).get("act")),
				"index": int((e as Object).get("index"))}
	return out


## `next_after` on the live content.
static func next_episode(id: String) -> String:
	return next_after(id, episode_table())


## Stars per episode from the Save autoload.
static func saved_stars() -> Dictionary:
	var out := {}
	var sv := ViewKit.autoload("Save")
	if sv == null or not sv.has_method("night"):
		return out
	for id in SLICE_NIGHTS:
		var n: Variant = sv.call("night", id)
		if n is Dictionary:
			out[id] = (n as Dictionary).get("stars", [])
	return out
