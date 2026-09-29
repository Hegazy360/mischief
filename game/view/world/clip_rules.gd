## ClipRules — the one-shot / staging clip table as data (`data/anim/clip_rules.json`, owner
## s2-view; brief §4.1.9–§4.1.10, ruling L14). Pure, cached.
##
## Each row names a map key (`oneshot:bump`, `bit:*`, `mg:*`, `cue:laugh_picture`,
## `flavour:snicker`, …), who triggers it, the rig, its default clip(s), the layer (base |
## overlay | fx | none), the length source and how it ends. ClipMap asks it which layer a key
## plays on and what the row falls back to; SliceClips turns the rows into the slice clip
## manifest.
class_name ClipRules
extends RefCounted

const PATH := "res://data/anim/clip_rules.json"

static var _rows: Array = []
static var _by_key: Dictionary = {}
static var _loaded_from: String = ""
## rig → {key → row}.
static var _by_rig: Dictionary = {}
static var _wild_hits: Dictionary = {}
const _EMPTY := {}
## Test hook: rows used instead of the file (null = the file).
static var override_rows: Variant = null


## Every row (parsed once).
static func rows() -> Array:
	_ensure()
	return _rows


## The row for `key` on `rig` ({} when none). `bit:<id>` / `mg:<id>` match their `*` rows.
static func row(key: String, rig: String) -> Dictionary:
	_ensure()
	var per: Variant = _by_rig.get(rig, null)
	if not (per is Dictionary):
		return _EMPTY
	var hit: Variant = (per as Dictionary).get(key, null)
	if hit is Dictionary:
		return hit
	# `bit:<id>` / `mg:<id>` → their `*` row; remembered per key (no string building per frame).
	var miss: Variant = _wild_hits.get(rig, {}).get(key, null) if _wild_hits.has(rig) else null
	if miss is Dictionary:
		return miss
	var out: Dictionary = _EMPTY
	var w := ClipRules.wildcard_of(key)
	if w != "" and (per as Dictionary).get(w, null) is Dictionary:
		out = (per as Dictionary)[w]
	if not _wild_hits.has(rig):
		_wild_hits[rig] = {}
	(_wild_hits[rig] as Dictionary)[key] = out
	return out


## "base" | "overlay" | "fx" | "none" for a key ("base" when the table has no row).
static func layer_of(key: String, rig: String) -> String:
	var r := row(key, rig)
	return ViewKit.s(r.get("layer", "base")) if not r.is_empty() else "base"


## The row's mask for overlay keys ("" when none).
static func mask_of(key: String, rig: String) -> String:
	return ViewKit.s(row(key, rig).get("mask", ""))


## The `*` form of an expandable key: "bit:bit_tea" → "bit:*", "mg:hum" → "mg:*"; else "".
static func wildcard_of(key: String) -> String:
	if key.begins_with("bit:") and key != "bit:*":
		return "bit:*"
	if key.begins_with("mg:") and key != "mg:*":
		return "mg:*"
	return ""


## Forget the cache (tests / hot reload).
static func invalidate() -> void:
	_rows = []
	_by_key = {}
	_by_rig = {}
	_wild_hits = {}
	_loaded_from = ""


static func _ensure() -> void:
	var src := "override" if override_rows != null else PATH
	if _loaded_from == src and (not _rows.is_empty() or src == "override"):
		return
	_rows = []
	_by_key = {}
	_by_rig = {}
	_wild_hits = {}
	_loaded_from = src
	var list: Variant = override_rows
	if list == null:
		var d: Variant = ViewKit.json(PATH)
		list = (d as Dictionary).get("rows", []) if d is Dictionary else []
	if not (list is Array):
		return
	for r in list:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		_rows.append(rd)
		var k := "%s|%s" % [ViewKit.s(rd.get("rig", "")), ViewKit.s(rd.get("key", ""))]
		if not _by_key.has(k):
			_by_key[k] = rd
			var rg := ViewKit.s(rd.get("rig", ""))
			if not _by_rig.has(rg):
				_by_rig[rg] = {}
			(_by_rig[rg] as Dictionary)[ViewKit.s(rd.get("key", ""))] = rd
