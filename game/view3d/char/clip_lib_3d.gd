## ClipLib3D — the 3D clip library (ruling R2): sidecar JSON + a baked Godot `Animation` per clip.
## Clip id → files: `hush/loco_walk` → `res://data/anim/hush3d/loco_walk.json` (the sidecar) whose `anim` names the
## `Animation` resource (`res://art3d/anim/hush/loco_walk.res`). Everything is lazy and cached; the Animation's
## `loop_mode` is set from the sidecar on load (never from a `_Loop` name). Static, headless-safe.
##
## `register(def, anim)` adds an in-memory clip (tests, AnimViewer3D `--anim-glb`); `reload_if_changed(id)` re-reads a
## sidecar whose mtime changed (hot reload); `invalidate()` drops the caches.
class_name ClipLib3D
extends RefCounted

## Sidecar data roots searched in order (tests append a fixture root).
static var search_roots: PackedStringArray = ["res://data"]
## Files in an `<rig>3d/` folder that are not clips.
const NOT_CLIPS: PackedStringArray = ["map.json", "rig_actions.json", "reactions.json", "manifest.json"]

static var _clips: Dictionary = {}       ## id -> ClipDef3D
static var _anims: Dictionary = {}       ## id -> Animation
static var _mtime: Dictionary = {}       ## id -> int (sidecar mtime at load)
static var _registered: Dictionary = {}  ## id -> true (in-memory clips)
static var _missing: Dictionary = {}     ## id -> true (looked up, absent: cheap repeat misses)


## The sidecar path of `clip_id` under the first root that has it (else under the first root).
static func path_of(clip_id: String) -> String:
	var rel := _rel(clip_id)
	for r in search_roots:
		var p := "%s/%s" % [r, rel]
		if FileAccess.file_exists(p):
			return p
	return "%s/%s" % [search_roots[0] if not search_roots.is_empty() else "res://data", rel]


## True when the clip has a sidecar (or was registered).
static func exists(clip_id: String) -> bool:
	if _registered.has(clip_id) or _clips.has(clip_id):
		return true
	if not clip_id.contains("/"):
		return false
	return FileAccess.file_exists(path_of(clip_id))


## The parsed clip (cached); null when it does not exist.
static func get_clip(clip_id: String) -> ClipDef3D:
	if _clips.has(clip_id):
		return _clips[clip_id]
	if _missing.has(clip_id) or not clip_id.contains("/"):
		return null
	var p := path_of(clip_id)
	if not FileAccess.file_exists(p):
		_missing[clip_id] = true
		return null
	var j := JSON.new()
	var def: ClipDef3D
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
		def = ClipDef3D.new()
		def.id = clip_id
		def.rig_id = clip_id.get_slice("/", 0)
		def.path = p
		def.errors.append("%s: invalid JSON (line %d: %s)" % [p, j.get_error_line(), j.get_error_message()])
	else:
		def = ClipDef3D.from_dict(clip_id, j.data as Dictionary, p)
	_clips[clip_id] = def
	_mtime[clip_id] = FileAccess.get_modified_time(p)
	_mtime[clip_id + "#anim"] = _anim_mtime(def)
	return def


## The clip's baked Animation (lazy; loop mode from the sidecar); null when missing.
static func animation(clip_id: String) -> Animation:
	if _anims.has(clip_id):
		return _anims[clip_id]
	var def := get_clip(clip_id)
	if def == null or def.anim_path == "":
		return null
	if not ResourceLoader.exists(def.anim_path):
		def.errors.append("%s: anim: '%s' does not exist" % [def.path, def.anim_path])
		_anims[clip_id] = null
		return null
	var a := ResourceLoader.load(def.anim_path, "Animation") as Animation
	if a == null:
		def.errors.append("%s: anim: '%s' is not an Animation" % [def.path, def.anim_path])
	else:
		_conform(def, a)
	_anims[clip_id] = a
	return a


## Clip length in frames (−1 when missing).
static func length(clip_id: String) -> int:
	var def := get_clip(clip_id)
	return def.length if def != null else -1


## Every clip id of `rig` (a directory scan of `<root>/anim/<rig>3d/*.json`, plus registered clips), sorted.
static func clips_of(rig: String) -> PackedStringArray:
	var seen: Dictionary = {}
	for r in search_roots:
		var dir := "%s/anim/%s3d" % [r, rig]
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json") and not NOT_CLIPS.has(f) and not f.ends_with("_map.json"):
				seen["%s/%s" % [rig, f.get_basename()]] = true
	for id in _registered:
		if String(id).begins_with(rig + "/"):
			seen[id] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## Adds an in-memory clip (tests, raw glb actions). `anim` may be null for a sidecar-only clip.
static func register(def: ClipDef3D, anim: Animation) -> void:
	_clips[def.id] = def
	_registered[def.id] = true
	_missing.erase(def.id)
	if anim != null:
		_conform(def, anim)
		_anims[def.id] = anim


## Loads an action from a raw glb (look-dev files, UAL libraries) with GLTFDocument (same UAL skeleton and an
## armature named `Armature`) and registers it as `<rig>/glb_<name>` (no sidecar: length from the action, loop from
## its loop mode or a `_Loop` name). Returns the clip id ("" on failure). Dev tools only (AnimViewer3D, sheets).
static func load_glb_action(rig: String, path: String, anim_name: String) -> String:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		push_error("ClipLib3D: cannot read %s" % path)
		return ""
	var scene := doc.generate_scene(st)
	if scene == null:
		return ""
	var ap: AnimationPlayer = null
	for n in scene.find_children("*", "AnimationPlayer", true, false):
		ap = n as AnimationPlayer
	if ap == null:
		scene.free()
		push_error("ClipLib3D: no animations in %s" % path)
		return ""
	var names := ap.get_animation_list()
	var pick := ""
	for n2 in names:
		var s2 := String(n2)
		if anim_name == "" or s2 == anim_name or s2 == anim_name.trim_suffix("_Loop") or s2.get_file() == anim_name:
			pick = s2
			break
	if pick == "":
		push_error("ClipLib3D: no action '%s' in %s (have: %s)" % [anim_name, path, ", ".join(names)])
		scene.free()
		return ""
	var a := (ap.get_animation(pick) as Animation).duplicate() as Animation
	scene.free()
	var nm := "glb_" + pick.get_file().to_snake_case().replace(".", "_")
	var id := "%s/%s" % [rig, nm]
	var looped := a.loop_mode != Animation.LOOP_NONE or pick.ends_with("_Loop") or anim_name.ends_with("_Loop")
	var def := ClipDef3D.from_dict(id, {"version": 2, "format": "anim3d", "clip": id, "rig": rig, "anim": path,
		"length": maxi(1, roundi(a.length * 60.0)), "loop": looped, "source": {"kind": "glb", "file": path, "action": pick}}, "")
	register(def, a)
	return id


## Re-reads the sidecar (and its Animation) when the file changed on disk. True when reloaded.
static func reload_if_changed(clip_id: String) -> bool:
	if _registered.has(clip_id) or not _clips.has(clip_id):
		return false
	var def: ClipDef3D = _clips[clip_id]
	if def.path == "" or not FileAccess.file_exists(def.path):
		return false
	var mt := FileAccess.get_modified_time(def.path)
	var amt := _anim_mtime(def)
	if mt == int(_mtime.get(clip_id, 0)) and amt == int(_mtime.get(clip_id + "#anim", 0)):
		return false
	_clips.erase(clip_id)
	var had_anim := _anims.has(clip_id)
	_anims.erase(clip_id)
	def = get_clip(clip_id)
	if had_anim and def.anim_path != "" and ResourceLoader.exists(def.anim_path):
		var a := ResourceLoader.load(def.anim_path, "Animation", ResourceLoader.CACHE_MODE_REPLACE) as Animation
		if a != null:
			_conform(_clips[clip_id], a)
			_anims[clip_id] = a
	return true


## Drop every cache (or one clip's).
static func invalidate(clip_id := "") -> void:
	if clip_id == "":
		_clips.clear()
		_anims.clear()
		_mtime.clear()
		_registered.clear()
		_missing.clear()
		return
	_clips.erase(clip_id)
	_anims.erase(clip_id)
	_mtime.erase(clip_id)
	_registered.erase(clip_id)
	_missing.erase(clip_id)


## Every validation problem of `clip_id` (sidecar + Animation: length and loop vs the sidecar).
static func problems(clip_id: String) -> PackedStringArray:
	var def := get_clip(clip_id)
	if def == null:
		return PackedStringArray(["%s: no sidecar at %s" % [clip_id, path_of(clip_id)]])
	var out := def.errors.duplicate()
	var a := animation(clip_id)
	if a != null:
		var frames := roundi(a.length * 60.0)
		if absi(frames - def.length) > 1:
			out.append("%s: anim length %d f differs from the sidecar's %d f" % [def.path, frames, def.length])
	return out


static func _anim_mtime(def: ClipDef3D) -> int:
	if def.anim_path == "" or not FileAccess.file_exists(def.anim_path):
		return 0
	return FileAccess.get_modified_time(def.anim_path)


static func _conform(def: ClipDef3D, a: Animation) -> void:
	a.loop_mode = Animation.LOOP_LINEAR if def.loop else Animation.LOOP_NONE


static func _rel(clip_id: String) -> String:
	return "anim/%s3d/%s.json" % [clip_id.get_slice("/", 0), clip_id.get_slice("/", 1)]
