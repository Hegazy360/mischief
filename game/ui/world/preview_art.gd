## PreviewArt — the preview pictograms (REDESIGN_3D §4.3 BEFORE column; previews.json ids) as
## textures, rasterised ONCE (UiIcons' HiResTex path) and cached by prank, so nothing is built
## during PLAY (`WorldOverlays.warm` asks for every prank of the Night under the curtain).
##
## One composite SVG per slice prank: `res://art/ui/previews/<prank>.svg`, drawn in one visual
## language (cream cloud-ready, navy #1B2340 ink, look A's palette), readable at 78 px. Each file
## names the previews.json pictogram ids it draws in its `<desc>` ("ids: nose star_burst") — a test
## checks they match previews.json. A prank without its own file falls back to
## `previews/<first id>.svg`, then to the generic `previews/_unknown.svg`.
class_name PreviewArt
extends RefCounted

const DIR := "res://art/ui/previews/"
const UNKNOWN := "_unknown"
## Raster scale: the SVGs are authored on a 128 px canvas; ×2 keeps the 124 px thought crisp.
const SCALE := 2.0

static var _by_prank: Dictionary = {}


## The pictogram texture for `prank` (ids: its previews.json pictogram; may be empty).
static func texture(prank: String, ids: PackedStringArray = PackedStringArray()) -> Texture2D:
	if _by_prank.has(prank):
		return _by_prank[prank]
	var t := UiIcons.texture(path_for(prank, ids), SCALE)
	_by_prank[prank] = t
	return t


## The file a prank's pictogram comes from (pure; tests).
static func path_for(prank: String, ids: PackedStringArray = PackedStringArray()) -> String:
	var p := DIR + prank + ".svg"
	if prank != "" and FileAccess.file_exists(p):
		return p
	if not ids.is_empty():
		var q := DIR + ids[0] + ".svg"
		if FileAccess.file_exists(q):
			return q
	return DIR + UNKNOWN + ".svg"


## The ids a composite SVG declares in its `<desc>ids: …</desc>` (empty when none; tests).
static func declared_ids(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	var src := FileAccess.get_file_as_string(path)
	var a := src.find("<desc>ids:")
	if a < 0:
		return PackedStringArray()
	var b := src.find("</desc>", a)
	if b < 0:
		return PackedStringArray()
	return PackedStringArray(src.substr(a + 10, b - a - 10).strip_edges().split(" ", false))


## Drop the cache (tests).
static func clear_cache() -> void:
	_by_prank.clear()
