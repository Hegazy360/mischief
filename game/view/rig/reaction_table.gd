## ReactionTable — read-only lookups into `reactions.json` files (TECH §4.5) for the rig
## player and the animation lint: which archetype entry uses a clip (frames, marks, hold,
## `t3_prop_f`), the `suppressed` beat, and the T3 last-beat pool.
##
## Search order for a clip of rig R: `data/anim/R/reactions.json` (per-rig tables, e.g. the
## `_mannequin` demo table owned by `rig`), then `data/reactions.json` (content-owned). Files
## that do not exist yet are skipped (soft hook). Cached; `invalidate()` for hot reload.
class_name ReactionTable
extends RefCounted

static var _files: Dictionary = {}   ## path → Dictionary (parsed; {} when missing / broken)


## Tables to search for rig `rig_id`, in priority order.
static func tables_for(rig_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in ["%s/anim/%s/reactions.json" % [RigDef.data_root, rig_id], "%s/reactions.json" % RigDef.data_root]:
		var t := _table(p)
		if not t.is_empty():
			out.append(t)
	return out


## The archetype entry whose `clip` is `clip_id` ({} when none), plus "archetype": key.
static func entry_for_clip(clip_id: String) -> Dictionary:
	var rig_id := clip_id.get_slice("/", 0)
	for t in tables_for(rig_id):
		var arch: Variant = t.get("archetypes", {})
		if not (arch is Dictionary):
			continue
		for k in arch:
			var e: Variant = arch[k]
			if e is Dictionary and String((e as Dictionary).get("clip", "")) == clip_id:
				var out: Dictionary = (e as Dictionary).duplicate()
				out["archetype"] = String(k)
				return out
	return {}


## The `suppressed` entry ({clip, frames}) for rig `rig_id` ({} when none): the first table
## whose `archetypes.suppressed.clip` belongs to that rig.
static func suppressed_for(rig_id: String) -> Dictionary:
	for t in tables_for(rig_id):
		var arch: Variant = t.get("archetypes", {})
		if arch is Dictionary and (arch as Dictionary).get("suppressed", null) is Dictionary:
			var e: Dictionary = (arch as Dictionary)["suppressed"]
			if String(e.get("clip", "")).begins_with(rig_id + "/"):
				return e
	return {}


## The T3 last-beat clip pool of rig `rig_id` (ids of that rig only).
static func last_beats_for(rig_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for t in tables_for(rig_id):
		var lb: Variant = t.get("t3_last_beats", [])
		if lb is Array:
			for c in lb:
				if String(c).begins_with(rig_id + "/") and not out.has(String(c)):
					out.append(String(c))
	return out


## Forget cached files.
static func invalidate() -> void:
	_files.clear()


static func _table(p: String) -> Dictionary:
	if _files.has(p):
		return _files[p]
	var out: Dictionary = {}
	if FileAccess.file_exists(p):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(p)) == OK and j.data is Dictionary:
			out = j.data
	_files[p] = out
	return out
