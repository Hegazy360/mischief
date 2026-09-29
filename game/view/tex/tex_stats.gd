## TexStats — counts every texture page the game builds at runtime (s2-rig §4.3), so the e2e
## can prove 0 pages are built during PLAY (pre-gate row 15): AtlasBuilder (one per atlas
## page: rigs, rooms, look pages), RigPlayer's lazy look pages, HiResTex rasters and
## `s2-view`'s lazy FX textures all call `note_build(kind)`. Static; no Nodes.
##   TexStats.reset()                  # at curtain rise
##   … play …
##   assert TexStats.pages_built() == 0
## Kinds used: "atlas" (an AtlasBuilder page), "look" (a lazy residue look page: also
## counted as "atlas"), "hires" (a HiResTex raster), "fx" (view).
class_name TexStats
extends RefCounted

static var _total: int = 0
static var _by_kind: Dictionary = {}
static var _last: Array = []   ## the last 16 {kind, label, frame}


## Pages / textures built since the last reset().
static func pages_built() -> int:
	return _total


## Count one texture page of `kind` ("atlas", "look", "hires", "fx", …); `label` names it
## (the atlas key or path) for the device log.
static func note_build(kind: String, label: String = "") -> void:
	_total += 1
	_by_kind[kind] = int(_by_kind.get(kind, 0)) + 1
	_last.append({"kind": kind, "label": label, "frame": Engine.get_process_frames()})
	if _last.size() > 16:
		_last.pop_front()


## Builds of one kind since the last reset().
static func built(kind: String) -> int:
	return int(_by_kind.get(kind, 0))


## {kind: count} since the last reset() (a copy).
static func by_kind() -> Dictionary:
	return _by_kind.duplicate()


## The most recent builds (≤ 16): [{kind, label, frame}] — what the device log prints when
## a page was built during PLAY.
static func recent() -> Array:
	return _last.duplicate(true)


## Start counting from zero (curtain rise; tests).
static func reset() -> void:
	_total = 0
	_by_kind.clear()
	_last.clear()
