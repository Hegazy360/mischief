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
## Card icon keys → icon ids (res://art/ui/<id>.svg) or res:// paths (GDD §6.4 cue cards, the
## loading cards). Covers every key barks.json uses: the loading-card `icon` and `new_rule` keys,
## the Figgis cue-card keys (a cue key maps to its lead icon, for one-icon use) and every icon
## key inside figgis_cards / line_cards that is not an item id (items resolve through `item()`).
## `test_card_aliases.gd` fails on any barks.json key that would fall back to a "?" box.
const CARD_ALIASES := {
	# HUD verbs and widgets
	"tray": "tray", "items": "tray", "freeze": "verb_freeze", "statue": "verb_freeze",
	"freeze_specs": "verb_freeze", "squeak": "clarence", "clarence": "clarence", "chicken": "clarence",
	"clarence_hold": "clarence_hold", "hide": "badge_hide", "hiding": "badge_hide",
	"specs": "glyph_specs_on", "specs_on": "glyph_specs_on", "specs_off": "glyph_specs_off",
	"script": "script", "bow": "rose", "rig": "hand_rig", "hold": "hand_rig", "arrow": "arrow",
	"bellows": "bellows_face", "pin": "pin", "go": "pin", "tomato": "tomato", "star": "star",
	"ff": "clock_fast", "ff_button": "ff", "clock_fast": "clock_fast", "overview": "overview",
	"candle": "candle", "figgis": "figgis_chip",
	# loading-card rules (Nights 3–Gala)
	"fixup": ACTIVITY_DIR + "fixup_mirror.svg", "residue_fixup": ACTIVITY_DIR + "fixup_mirror.svg",
	"meltdown": "bellows_livid", "beryl": ACTIVITY_DIR + "herd_beryl.svg",
	"herd": ACTIVITY_DIR + "feed_beryl.svg", "herding": ACTIVITY_DIR + "feed_beryl.svg",
	"panto": "behind_you", "delphine": ACTIVITY_DIR + "host_tea.svg",
	"chase_trip": ACTIVITY_DIR + "hunt.svg", "chase_trips": ACTIVITY_DIR + "hunt.svg",
	"nerves": ACTIVITY_DIR + "warmup.svg", "spotlight": ACTIVITY_DIR + "rehearse.svg",
	"basics": "clarence",
	# Figgis cue-card keys (barks.json figgis_cards) → their lead icon
	"figgis_psst": "clarence", "ghost_squeak": "clarence", "ghost_honey": "hand_rig",
	"ghost_hold": "hand_rig", "ghost_hide": "badge_hide", "ghost_ff": "clock_fast",
	"sparkle_lever": "hand_rig", "title_card": "star", "card_tray": "tray", "card_script": "script", "card_bow": "rose",
	"card_freeze": "verb_freeze", "card_specs": "glyph_specs_on",
	"card_fixup": ACTIVITY_DIR + "fixup_mirror.svg",
}
## Built-in cue-card icon sets (used when barks.json has no `figgis_cards.<key>` entry):
## `ff` = the ⏩ lesson (GDD §3.3, s2-content `ghost_ff`): Clarence held → a clock spinning fast.
const CARD_SETS := {
	"ff": ["clarence_hold", "arrow", "clock_fast"],
	"ghost_ff": ["clarence_hold", "arrow", "clock_fast"],
}
const BARKS_PATH := "res://data/barks.json"

static var _cache: Dictionary = {}
static var _barks: Dictionary = {}
static var _barks_loaded: bool = false
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


## A card icon by key (tray, freeze, squeak, hide, specs, …), a UI icon id, an item id, or a
## res:// path. Unknown keys fall back to the neutral item box.
static func card(key: String) -> Texture2D:
	var p := card_path(key)
	var t := texture(p) if p != "" else null
	return t if t != null else item(key)


## The res:// path a card key resolves to ("" = nothing real: `card()` would show the "?" box).
## Resolution: a res:// path as is → CARD_ALIASES → a UI icon id → an item id.
static func card_path(key: String) -> String:
	if key == "":
		return ""
	var id := key
	if CARD_ALIASES.has(key):
		id = String(CARD_ALIASES[key])
	if id.begins_with("res://"):
		return id if _art_exists(id) else ""
	var ui := DIR + id + ".svg"
	if _art_exists(ui):
		return ui
	var it := ITEM_DIR + id + ".svg"
	if _art_exists(it):
		return it
	var ac := ACTIVITY_DIR + id + ".svg"
	if _art_exists(ac):
		return ac
	return ""


## The icon keys of a cue card: barks.json `figgis_cards.<key>.icons`, else `line_cards.<key>.icons`
## (a Script line id like "n01_throat_tea:kettle"), else CARD_SETS, else just [key].
static func card_set(key: String) -> PackedStringArray:
	var b := barks()
	for section in ["figgis_cards", "line_cards"]:
		var sec: Variant = b.get(section)
		if sec is Dictionary and (sec as Dictionary).get(key) is Dictionary:
			var ic: Variant = ((sec as Dictionary)[key] as Dictionary).get("icons")
			if ic is Array and not (ic as Array).is_empty():
				return PackedStringArray(ic)
	if CARD_SETS.has(key):
		return PackedStringArray(CARD_SETS[key])
	return PackedStringArray([key])


## barks.json as a Dictionary (read once; {} when missing).
static func barks() -> Dictionary:
	if not _barks_loaded:
		_barks_loaded = true
		_barks = {}
		if FileAccess.file_exists(BARKS_PATH):
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(BARKS_PATH)) == OK and j.data is Dictionary:
				_barks = j.data
	return _barks


## Texture-memory accounting (TexStats, soft: the UI kit never depends on the view).
static func _track(t: Texture2D, img: Image, path: String) -> void:
	if not ResourceLoader.exists("res://view/tex/tex_stats.gd"):
		return
	var ts: Script = load("res://view/tex/tex_stats.gd")
	if ts != null and ts.has_method("track_image"):
		ts.call("track_image", t, img, "ui", "res://ui/" + path.get_file() if not path.begins_with("res://art/") else path)


static func _art_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


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
				_track(t, img, path)
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
	_barks.clear()
	_barks_loaded = false


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
