## UiStrings — every UI string by key from `res://data/ui/strings.json` (English only in v1).
##
##   UiStrings.t("pause.resume")                  → "Resume"
##   UiStrings.t("hud.mult", {"m": "1.5"})        → "×1.5"
## Unknown keys return the key itself (visible in screenshots, never a crash).
class_name UiStrings
extends RefCounted

const PATH := "res://data/ui/strings.json"

static var _strings: Dictionary = {}
static var _loaded: bool = false


## The string for `key`, with `{name}` placeholders filled from `args`.
static func t(key: String, args: Dictionary = {}) -> String:
	if not _loaded:
		reload()
	var s := String(_strings.get(key, key))
	if not args.is_empty():
		s = s.format(args)
	return s


## True when `key` exists in strings.json.
static func has(key: String) -> bool:
	if not _loaded:
		reload()
	return _strings.has(key)


## All keys (tests).
static func keys() -> Array:
	if not _loaded:
		reload()
	return _strings.keys()


## (Re)load strings.json.
static func reload() -> void:
	_loaded = true
	_strings = {}
	if not FileAccess.file_exists(PATH):
		push_warning("UiStrings: %s missing" % PATH)
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(PATH)) != OK:
		push_warning("UiStrings: %s:%d %s" % [PATH, j.get_error_line(), j.get_error_message()])
		return
	var d: Variant = j.data
	if d is Dictionary and (d as Dictionary).get("strings") is Dictionary:
		_strings = (d as Dictionary)["strings"]
