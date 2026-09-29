## UiIcons — every HUD icon as a crisp texture.
##
## `get_icon(&"verb_freeze")` → `res://art/ui/verb_freeze.svg` re-rasterised from its raw SVG at
## `RASTER_SCALE` × with mipmaps (sharp on 1440p phones, no aliasing when shrunk on small
## windows); when the raw source is not readable (an export without raw SVGs) it falls back to
## the imported texture, then to null. Results are cached.
##
## Soft art from other owners (loaded the same way, with a neutral fallback):
##   * `item(id_or_path)` → `res://art/house/items/<id>.svg` (art-house), else `item_fallback`.
##   * `activity(id_or_path)` → `res://art/icons/activities/<id>.svg` (art-house), else `script`.
## Public ids for other owners (view): `glyph(id)` with ids `specs_off, specs_on, blinded,
## asleep, stars` (aliases accepted, see GLYPH_ALIASES) and `badge(kind)` with kinds
## `gold, hide, in_use, needs` (aliases in BADGE_ALIASES).
class_name UiIcons
extends RefCounted

const DIR := "res://art/ui/"
const ITEM_DIR := "res://art/house/items/"
const ACTIVITY_DIR := "res://art/icons/activities/"
## Raster scale of a 128-px canvas icon (256 px texture; shown at 44–160 px).
const RASTER_SCALE := 2.0

const GLYPH_ALIASES := {
	"specs_off": "specs_off", "dangling": "specs_off", "off": "specs_off", "normal": "specs_off", "": "specs_off",
	"specs_on": "specs_on", "on": "specs_on", "specs": "specs_on", "searching": "specs_on",
	"blinded": "blinded", "blind": "blinded", "butter": "blinded", "flour": "blinded",
	"asleep": "asleep", "zz": "asleep", "sleep": "asleep",
	"stars": "stars", "reacting": "stars", "dizzy": "stars",
}
const BADGE_ALIASES := {
	"gold": "gold", "usable": "gold", "ready": "gold",
	"hide": "hide", "hiding": "hide", "blue": "hide",
	"in_use": "in_use", "red": "in_use", "in_use_next": "in_use",
	"needs": "needs", "grey": "needs", "cloud": "needs", "needs_item": "needs",
}
## Loading-card / cue-card icon keys → icon ids.
const CARD_ALIASES := {
	"tray": "tray", "items": "tray", "freeze": "verb_freeze", "statue": "verb_freeze",
	"squeak": "clarence", "clarence": "clarence", "chicken": "clarence", "hide": "badge_hide",
	"hiding": "badge_hide", "specs": "glyph_specs_on", "specs_on": "glyph_specs_on",
	"specs_off": "glyph_specs_off", "script": "script", "bow": "rose", "rig": "hand_rig",
	"hold": "hand_rig", "arrow": "arrow", "bellows": "bellows_face", "pin": "pin", "go": "pin",
	"tomato": "tomato", "star": "star", "ff": "ff", "overview": "overview", "candle": "candle",
}

static var _cache: Dictionary = {}
## Test hook / counters.
static var stats := {"raster": 0, "imported": 0, "missing": 0}


## A UI icon by id (file name in res://art/ui without ".svg"); null when missing.
static func get_icon(id: StringName) -> Texture2D:
	return texture(DIR + String(id) + ".svg")


## Awareness glyph texture (ids: specs_off, specs_on, blinded, asleep, stars; aliases ok).
static func glyph(id: String) -> Texture2D:
	var g := String(GLYPH_ALIASES.get(id.to_lower(), id.to_lower()))
	return get_icon(StringName("glyph_" + g))


## Hotspot badge texture (kinds: gold, hide, in_use, needs; aliases ok).
static func badge(kind: String) -> Texture2D:
	var k := String(BADGE_ALIASES.get(kind.to_lower(), kind.to_lower()))
	return get_icon(StringName("badge_" + k))


## Item icon by item id or res:// path, falling back to the neutral `item_fallback` box.
static func item(id_or_path: String) -> Texture2D:
	if id_or_path == "":
		return null
	var p := id_or_path if id_or_path.begins_with("res://") else ITEM_DIR + id_or_path + ".svg"
	var t := texture(p)
	return t if t != null else get_icon(&"item_fallback")


## Activity / detour icon by id or path, falling back to the `script` icon.
static func activity(id_or_path: String) -> Texture2D:
	if id_or_path == "":
		return null
	var p := id_or_path if id_or_path.begins_with("res://") else ACTIVITY_DIR + id_or_path + ".svg"
	var t := texture(p)
	return t if t != null else get_icon(&"script")


## A card icon by key (tray, freeze, squeak, hide, specs, …), a UI icon id, or a res:// path.
static func card(key: String) -> Texture2D:
	if key.begins_with("res://"):
		return texture(key)
	var id := String(CARD_ALIASES.get(key, key))
	var t := get_icon(StringName(id))
	if t == null:
		t = item(key)
	return t


## Any SVG/PNG path as a crisp texture (cached). Null when neither raw nor imported exists.
static func texture(path: String, scale: float = RASTER_SCALE) -> Texture2D:
	var key := "%s@%s" % [path, scale]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if path.ends_with(".svg") and FileAccess.file_exists(path):
		var src := FileAccess.get_file_as_string(path)
		if src != "":
			var img := Image.new()
			if img.load_svg_from_string(src, scale) == OK and not img.is_empty():
				img.generate_mipmaps()
				t = ImageTexture.create_from_image(img)
				stats["raster"] += 1
	if t == null and ResourceLoader.exists(path):
		t = load(path) as Texture2D
		if t != null:
			stats["imported"] += 1
	if t == null:
		stats["missing"] += 1
	_cache[key] = t
	_ensure_keeper()
	return t


## Drop the cache (tests; also on quit so no texture outlives the renderer).
static func clear_cache() -> void:
	_cache.clear()


static var _keeper_added: bool = false


static func _ensure_keeper() -> void:
	if _keeper_added:
		return
	var t := Engine.get_main_loop() as SceneTree
	if t == null or t.root == null:
		return
	_keeper_added = true
	var k := _CacheKeeper.new()
	k.name = "UiIconsCache"
	t.root.add_child.call_deferred(k)


## Clears the static texture cache when the tree shuts down.
class _CacheKeeper:
	extends Node

	func _exit_tree() -> void:
		UiIcons.clear_cache()
		UiKit.clear_caches()
		UiIcons._keeper_added = false
