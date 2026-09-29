## IpLint — banned-term scan (TECH §10.5): our game is original IP and must never echo Neighbours
## from Hell (names, characters, framing or its signature gags).
##
##   var hits := IpLint.scan_text(text, "pranks.json")     # ["pranks.json:12: 'woody' in «…»"]
##   var all := IpLint.scan_project("res://", "/abs/docs/GDD.md")
##
## Case-insensitive and word-boundary aware: a term matches only between non-alphanumeric
## characters, and spaces inside a term also match `_` / `-` (ids like `on_air` are caught), so
## "woodblock", "goldenrod", "Volga" or "season 10" never match. Scanned: `game/data/**/*.json`
## (including `data/ui/strings.json`), every `.tscn` / `.tres` text under the game (tests excluded),
## and the Script / caption / loading-card strings of `docs/GDD.md`.
class_name IpLint
extends RefCounted

const BANNED: PackedStringArray = ["neighbours from hell", "neighbors from hell", "woody", "rottweiler", "olga",
	"golden neighbour", "viewer rating", "audience rating", "street share", "golden remote", "trap camera",
	"season 1", "episode rating", "on air", "channel 11",
	"binoculars", "laxative", "mousetrap", "fart cushion", "drawing pin", "marbles", "banana peel", "cactus"]
const SKIP_DIRS: PackedStringArray = [".godot", "tests", ".import"]

static var _regexes: Array = []


static func _patterns() -> Array:
	if _regexes.is_empty():
		for term in BANNED:
			var body := ""
			for w in term.split(" ", false):
				if body != "":
					body += "[\\s_\\-]+"
				body += _escape(w)
			var re := RegEx.new()
			re.compile("(?i)(?<![a-z0-9])" + body + "(?![a-z0-9])")
			_regexes.append([term, re])
	return _regexes


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ".^$*+?()[]{}|\\".contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out


## Hits of every banned term in `text` ("<source>:<line>: '<term>' in «<snippet>»").
static func scan_text(text: String, source: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lines := text.split("\n")
	for pr in _patterns():
		var re: RegEx = pr[1]
		for i in lines.size():
			for m in re.search_all(lines[i]):
				var a := maxi(0, m.get_start() - 24)
				var snippet := lines[i].substr(a, m.get_end() - a + 24).strip_edges()
				out.append("%s:%d: banned term '%s' in «%s»" % [source, i + 1, pr[0], snippet])
	return out


## Files to scan under a game root: data JSON + scene/resource text (tests and caches excluded).
static func game_files(game_root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var root := game_root if game_root.ends_with("://") else game_root.trim_suffix("/")
	_walk(root, out, true)
	out.sort()
	return out


static func _walk(dir: String, out: PackedStringArray, top: bool) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for sub in da.get_directories():
		if SKIP_DIRS.has(sub) or sub.begins_with("."):
			continue
		_walk(dir.path_join(sub), out, false)
	var in_data := dir.contains("/data")
	for f in da.get_files():
		if f.ends_with(".tscn") or f.ends_with(".tres") or (in_data and f.ends_with(".json")):
			out.append(dir.path_join(f))


## The GDD strings the IP lint owns: §5.5/§5.7 captions, §7.2 Script lines and loading cards.
## Returns [[label, text], ...].
static func gdd_strings(gdd: String) -> Array:
	var out: Array = []
	var lines := gdd.split("\n")
	var sec := ""
	var cap_re := RegEx.new()
	cap_re.compile("\\*\\*#\\d+ `([a-z_]+)` ([^*]+)\\*\\*")
	var quote_re := RegEx.new()
	quote_re.compile("\"([^\"]+)\"")
	var bold_re := RegEx.new()
	bold_re.compile("\\*\\*([^*]+)\\*\\*")
	for i in lines.size():
		var l := lines[i]
		if l.begins_with("### "):
			sec = l.substr(4, 4).strip_edges()
		if sec.begins_with("5.7"):
			for m in cap_re.search_all(l):
				out.append(["GDD.md:%d caption %s" % [i + 1, m.get_string(1)], m.get_string(2)])
		elif sec.begins_with("5.5") and l.begins_with("|"):
			for m in bold_re.search_all(l):
				out.append(["GDD.md:%d double act" % (i + 1), m.get_string(1)])
		elif sec.begins_with("7.2") and (l.contains("Script:") or l.contains("Card:")):
			for m in quote_re.search_all(l):
				out.append(["GDD.md:%d %s" % [i + 1, "script" if l.contains("Script:") else "card"], m.get_string(1)])
			for m in bold_re.search_all(l):
				out.append(["GDD.md:%d %s" % [i + 1, "script caption"], m.get_string(1)])
	return out


## Scan the project: game files under `game_root` + the GDD strings (if `gdd_path` exists).
## Returns {hits: PackedStringArray, files: int, strings: int, gdd: bool}.
static func scan_project(game_root: String, gdd_path: String = "") -> Dictionary:
	var hits := PackedStringArray()
	var files := game_files(game_root)
	for f in files:
		var rel := f.trim_prefix(game_root).trim_prefix("/")
		hits.append_array(scan_text(FileAccess.get_file_as_string(f), rel))
	var n := 0
	var gdd_ok := gdd_path != "" and FileAccess.file_exists(gdd_path)
	if gdd_ok:
		for pr in gdd_strings(FileAccess.get_file_as_string(gdd_path)):
			n += 1
			for h in scan_text(String(pr[1]), String(pr[0])):
				hits.append(h)
	return {"hits": hits, "files": files.size(), "strings": n, "gdd": gdd_ok}
