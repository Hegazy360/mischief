## ClipMap3D — which of a character's clips come from the animation library and which stay ours.
##
## REDESIGN_3D R2, revised after the open-source evaluation (docs/review/oss_cast/index.md). The
## cast now stands on KayKit's CC0 rig, and its Character Animations pack ships 161 clips on that
## same skeleton. So the everyday motion — walking, idling, reaching, sitting, reacting — is
## library animation that nobody on this project has to author or maintain.
##
## What stays ours is the comedy the library has no equivalent for: the freezes, the snicker, the
## sneeze. Those are still the 2D clips in `game/data/anim/**`, replayed on the 3D skeleton by
## `PoseRetarget3D` — which is why that retarget was worth keeping when the custom rig was dropped.
##
## Data: `game/data/anim/clipmap3d.json`. A clip id in neither list still plays, as a 2D overlay,
## with one warning — a missing mapping must never silence a character.
class_name ClipMap3D
extends RefCounted

const PATH := "res://data/anim/clipmap3d.json"

static var _cache: Dictionary = {}

var library_dir := "res://art3d/cast/anim/"
## rig -> {our clip name: library clip name}
var _lib := {}
## rig -> [clip names kept as 2D overlays]
var _overlay := {}


## Parsed map, cached. Returns an empty map (everything falls back to 2D) when the file is absent.
static func load_map() -> ClipMap3D:
	if _cache.has(PATH):
		return _cache[PATH]
	var m := ClipMap3D.new()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var d: Dictionary = parsed
			m.library_dir = String(d.get("library", m.library_dir))
			for rig in d.get("rigs", {}):
				m._lib[rig] = (d["rigs"] as Dictionary)[rig]
			for rig in d.get("overlay", {}):
				if rig.begins_with("_"):
					continue
				m._overlay[rig] = PackedStringArray((d["overlay"] as Dictionary)[rig])
		else:
			push_error("ClipMap3D: %s is not valid JSON" % PATH)
	_cache[PATH] = m
	return m


static func invalidate() -> void:
	_cache.clear()


## The library clip for `clip` on `rig`, or "" when it is not a library clip.
func library_clip(rig: String, clip: String) -> String:
	var short := clip.get_file() if clip.contains("/") else clip
	if not _lib.has(rig):
		return ""
	return String((_lib[rig] as Dictionary).get(short, ""))


## True when `clip` is deliberately kept as one of our own 2D clips.
func is_overlay(rig: String, clip: String) -> bool:
	var short := clip.get_file() if clip.contains("/") else clip
	if not _overlay.has(rig):
		return false
	return (_overlay[rig] as PackedStringArray).has(short)


## Every library .glb to load for a rig (they are shared, so this is the whole folder).
func library_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(library_dir)
	if d == null:
		push_warning("ClipMap3D: no animation library at %s" % library_dir)
		return out
	for f in d.get_files():
		# Godot renames imported .glb to .glb.import in an export; strip the suffix either way.
		if f.ends_with(".import"):
			f = f.substr(0, f.length() - 7)
		if f.ends_with(".glb") and not out.has(library_dir + f):
			out.append(library_dir + f)
	return out


func rigs() -> PackedStringArray:
	return PackedStringArray(_lib.keys())


func mapped_count(rig: String) -> int:
	return (_lib.get(rig, {}) as Dictionary).size()
