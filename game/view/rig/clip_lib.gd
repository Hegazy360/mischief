## ClipLib — loads, resolves and caches clips (TECH §5.3).
##
##   var clip := ClipLib.get_clip("_mannequin/rx_take")   # res://data/anim/_mannequin/rx_take.json
##
## NOTE — TECH §5.3 names this `ClipLib.get(id)`, but `get` cannot be a static method name
## in GDScript (it overrides Object.get: parse error), so it is **`ClipLib.get_clip(id)`**.
##
## Clip ids are `<rig>/<name>`. Files in `anim/<rig>/` that are not clips (`reactions.json`,
## `map.json`, `tiers.json`) are skipped by `list()`, and `rigs_with_clips()` lists only
## folders that belong to a rig (`rigs/<id>/rig.json`), so `anim/cold/` (cold-open scripts)
## and `anim/clip_rules.json` never reach the clip tools. `reload_changed()` re-reads files
## whose mtime changed (the AnimViewer's hot reload) and returns the ids it dropped.
## `register(clip)` puts a clip built elsewhere (a test fixture) under its id.
class_name ClipLib
extends RefCounted

const NOT_CLIPS: PackedStringArray = ["reactions.json", "map.json", "tiers.json"]

static var _cache: Dictionary = {}    ## id → ClipDef
static var _mtime: Dictionary = {}    ## id → int


## The clip `clip_id` ("rig/name"), cached; null when its file does not exist.
static func get_clip(clip_id: String) -> ClipDef:
	var hit: ClipDef = _cache.get(clip_id, null)
	if hit != null:
		return hit
	var p := path_of(clip_id)
	if not FileAccess.file_exists(p):
		return null
	var c := load_file(p, clip_id)
	_cache[clip_id] = c
	_mtime[clip_id] = FileAccess.get_modified_time(p)
	return c


## `res://data/anim/<rig>/<name>.json` for "rig/name".
static func path_of(clip_id: String) -> String:
	return "%s/anim/%s.json" % [RigDef.data_root, clip_id]


## Every clip id of a rig, sorted.
static func list(rig_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := "%s/anim/%s" % [RigDef.data_root, rig_id]
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json") and not NOT_CLIPS.has(f):
			out.append("%s/%s" % [rig_id, f.get_basename()])
	out.sort()
	return out


## Every rig id that has an `anim/<rig>/` folder and a `rigs/<rig>/rig.json`, sorted.
static func rigs_with_clips() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("%s/anim" % RigDef.data_root)
	if d == null:
		return out
	for n in d.get_directories():
		if FileAccess.file_exists("%s/rigs/%s/rig.json" % [RigDef.data_root, n]):
			out.append(n)
	out.sort()
	return out


## Put `clip` in the cache under its id (fixtures, tools); get_clip() then returns it until
## invalidate(). Returns the clip.
static func register(clip: ClipDef) -> ClipDef:
	if clip == null or clip.id == "":
		return clip
	_cache[clip.id] = clip
	var p := path_of(clip.id)
	_mtime[clip.id] = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
	return clip


## Load a clip file from anywhere (`res://tests/rig/fixtures/…`) and register it under
## `clip_id` (default: the file's `clip` field). Null when the file is missing.
static func register_file(file_path: String, clip_id: String = "") -> ClipDef:
	if not FileAccess.file_exists(file_path):
		return null
	return register(load_file(file_path, clip_id))


## Drop cached clips ("" = all).
static func invalidate(clip_id: String = "") -> void:
	if clip_id == "":
		_cache.clear()
		_mtime.clear()
	else:
		_cache.erase(clip_id)
		_mtime.erase(clip_id)


## Drop every cached clip whose file changed on disk; returns their ids.
static func reload_changed() -> PackedStringArray:
	var out := PackedStringArray()
	for cid in _cache.keys():
		var p := path_of(String(cid))
		var mt := FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
		if mt != int(_mtime.get(cid, -2)):
			out.append(String(cid))
	for cid2 in out:
		invalidate(cid2)
	return out


## Parse a clip file (tests load purpose-built bad clips from fixtures this way). The rig
## comes from the file's `rig` field unless `rig_def` / `pose_lib` are given.
static func load_file(file_path: String, clip_id: String = "", rig_def: RigDef = null, pose_lib: PoseLib = null) -> ClipDef:
	var errs := PackedStringArray()
	var data: Variant = RigDef._read_json(file_path, errs)
	var d: Dictionary = data if data is Dictionary else {}
	var c := from_dict(d, clip_id, rig_def, pose_lib, file_path)
	for e in errs:
		c.errors.append(e)
	return c


## Build a clip from a parsed dictionary.
static func from_dict(d: Dictionary, clip_id: String = "", rig_def: RigDef = null, pose_lib: PoseLib = null, file_path: String = "") -> ClipDef:
	var c := ClipDef.new()
	c.raw = d
	c.path = file_path
	c.id = clip_id if clip_id != "" else String(d.get("clip", ""))
	if c.id == "" and file_path != "":
		c.id = "%s/%s" % [String(d.get("rig", "")), file_path.get_file().get_basename()]
	c.rig_id = String(d.get("rig", c.id.get_slice("/", 0)))
	c.rig = rig_def if rig_def != null else RigDef.for_id(c.rig_id)
	var where := file_path if file_path != "" else c.id
	if c.rig == null:
		c.errors.append("%s: rig '%s' not found" % [where, c.rig_id])
		return c
	c.poses = pose_lib if pose_lib != null else PoseLib.for_rig(c.rig_id)
	if c.poses == null:
		c.poses = PoseLib.from_dicts(c.rig, {}, {})
	if d.has("clip") and clip_id != "" and String(d["clip"]) != clip_id:
		c.warnings.append("%s: \"clip\" is '%s' but the file is '%s'" % [where, d["clip"], clip_id])
	c.loop = bool(d.get("loop", false))
	var layer_name := String(d.get("layer", "base"))
	c.layer = ClipDef.LAYERS.find(layer_name)
	if c.layer < 0:
		c.errors.append("%s: unknown layer '%s'" % [where, layer_name])
		c.layer = ClipDef.LAYER_BASE
	# Mask: a rig.json `masks` name or a list of parts. A name the rig does not define (yet)
	# is not an error: the overlay falls back to the parts the clip keys (lint A23 warns); an
	# overlay without any mask is lint A23's error.
	var mv: Variant = d.get("mask", null)
	c.mask_spec = mv
	c.touch_legs = bool(d.get("touch_legs", false))
	if mv is String and String(mv) != "":
		if c.rig.has_mask(String(mv)):
			c.mask = c.rig.mask_from(mv, c.errors)
			c.mask_src = ClipDef.MASK_RIG
		else:
			c.mask_src = ClipDef.MASK_KEYS
	elif mv is Array:
		c.mask = c.rig.mask_from(mv, c.errors)
		c.mask_src = ClipDef.MASK_PARTS
	elif mv != null and not (mv is String):
		c.errors.append("%s: mask must be a rig mask name or a list of parts" % where)
	elif c.layer == ClipDef.LAYER_OVERLAY:
		c.mask_src = ClipDef.MASK_KEYS
	c.has_blend_in = d.has("blend_in")
	c.has_blend_out = d.has("blend_out")
	c.blend_in = int(d.get("blend_in", ClipDef.DEFAULT_BLEND))
	c.blend_out = int(d.get("blend_out", ClipDef.DEFAULT_BLEND))
	c.stride_px = float(d.get("stride_px", 0.0))
	c.skippable = bool(d.get("skippable", false))
	var tv: Variant = d.get("tags", [])
	if tv is Array:
		c.tags = PackedStringArray(tv)
	var sn := c.short_name()
	c.is_take = c.tags.has("take") or sn.begins_with("rx_") or sn.begins_with("sig_")
	var var_v: Variant = d.get("variation", {})
	if var_v is Dictionary:
		c.time_jitter = float((var_v as Dictionary).get("time_jitter", 0.0))
		c.rot_jitter = float((var_v as Dictionary).get("rot_jitter", 0.0))
	var sm: Variant = d.get("smear", {})
	c.smear_auto = sm is Dictionary and bool((sm as Dictionary).get("auto", false))
	_parse_keys(c, d, where)
	c.plant = bool(d.get("plant", false))
	if c.plant:
		_plant_keys(c)
	c.length = int(d.get("length", c.key_f[c.key_f.size() - 1] if not c.key_f.is_empty() else 1))
	if c.length < 1:
		c.errors.append("%s: length must be ≥ 1" % where)
		c.length = 1
	_parse_beats(c, d, where)
	_parse_events(c, d, where)
	return c


static func _parse_keys(c: ClipDef, d: Dictionary, where: String) -> void:
	var kv: Variant = d.get("keys", [])
	if not (kv is Array) or (kv as Array).is_empty():
		c.errors.append("%s: no keys" % where)
		return
	var prev: PackedFloat32Array = c.rig.rest
	var prev_face := ""
	for k in (kv as Array).size():
		var e: Variant = kv[k]
		if not (e is Dictionary):
			c.errors.append("%s: key %d is not an object" % [where, k])
			continue
		var kd: Dictionary = e
		var f := int(kd.get("f", -1))
		var pn := String(kd.get("pose", ""))
		var kwhere := "%s: key f=%d" % [where, f]
		if f < 0:
			c.errors.append("%s: key %d has no frame" % [where, k])
		if pn != "" and not c.poses.has_pose(pn):
			c.errors.append("%s: unknown pose '%s'" % [kwhere, pn])
		var pose := (c.poses.pose(pn) if pn != "" else prev).duplicate()
		var en := String(kd.get("ease", "linear"))
		var eid := RigEase.id(en)
		if eid < 0:
			c.errors.append("%s: unknown ease '%s'" % [kwhere, en])
			eid = RigEase.LINEAR
		var face := ""
		var explicit := kd.has("face")
		if explicit:
			face = String(kd["face"])
			if face != "" and not c.poses.has_preset(face):
				c.errors.append("%s: unknown face preset '%s'" % [kwhere, face])
			c.poses.apply_preset(pose, face)
		elif pn != "" and c.poses.face_of(pn) != "":
			face = c.poses.face_of(pn)
		else:
			# Carry the previous key's face (face parts' tex / vis only).
			face = prev_face
			for s in c.rig.face_slot_part:
				var b := RigDef.ROOT_CH + s * RigDef.STRIDE
				pose[b + RigDef.C_TEX] = prev[b + RigDef.C_TEX]
				pose[b + RigDef.C_VIS] = prev[b + RigDef.C_VIS]
		var sv: Variant = kd.get("set", {})
		var set_d: Dictionary = sv if sv is Dictionary else {}
		for pn2 in set_d:
			if String(pn2) == "root":
				if set_d[pn2] is Dictionary:
					c.poses.apply_root(pose, set_d[pn2], kwhere, c.errors)
				continue
			var i := c.rig.idx(String(pn2))
			if i < 0:
				c.errors.append("%s: set part '%s' is not in rig %s" % [kwhere, pn2, c.rig.id])
				continue
			if set_d[pn2] is Dictionary:
				c.poses.apply_channels(pose, i, set_d[pn2], kwhere, c.errors)
		if not c.key_f.is_empty() and f <= c.key_f[c.key_f.size() - 1]:
			c.errors.append("%s: frames must increase (previous key f=%d)" % [kwhere, c.key_f[c.key_f.size() - 1]])
		c.key_f.append(f)
		c.key_pose.append(pose)
		c.key_pose_name.append(pn)
		c.key_ease.append(eid)
		c.key_face.append(face)
		c.key_face_explicit.append(1 if explicit else 0)
		c.key_set.append(set_d)
		prev = pose
		prev_face = face


## Per key × foot: planted (lowest sole point within 1.5 px of the floor), the ankle's
## world position and the foot's world rotation.
static func _plant_keys(c: ClipDef) -> void:
	var nf := c.rig.feet.size()
	var xf: Array[Transform2D] = []
	for k in c.key_pose.size():
		RigSampler.solve(c.rig, c.key_pose[k], xf)
		for j in nf:
			var ft := c.rig.feet[j]
			var s := RigBounds.part_size(c.rig, c.key_pose[k], ft)
			var y := s.y - RigBounds.MARGIN
			var piv := c.rig.pivot[ft]
			var low := -INF
			for fx in [0.15, 0.5, 0.85]:
				low = maxf(low, (xf[ft] * (Vector2(s.x * fx, y) - piv)).y)
			var on := low >= -1.5 and low <= 3.0 and c.rig.foot_upper[j] >= 0
			c.plant_on.append(1 if on else 0)
			c.plant_pos.append(xf[ft].origin)
			c.plant_rot.append(xf[ft].get_rotation())


static func _parse_beats(c: ClipDef, d: Dictionary, where: String) -> void:
	var bv: Variant = d.get("beats", {})
	if not (bv is Dictionary):
		return
	for bn in bv:
		var b: Variant = bv[bn]
		if b is Array and (b as Array).size() == 2:
			var v := Vector2i(int(b[0]), int(b[1]))
			if v.x > v.y or v.x < 0 or v.y > c.length:
				c.errors.append("%s: beat '%s' %s is outside [0, %d] or reversed" % [where, bn, v, c.length])
			c.beats[String(bn)] = v
		else:
			c.errors.append("%s: beat '%s' must be [start, end]" % [where, bn])


static func _parse_events(c: ClipDef, d: Dictionary, where: String) -> void:
	var ev: Variant = d.get("events", [])
	if not (ev is Array):
		c.errors.append("%s: events must be an array" % where)
		return
	var tmp: Array = []
	var n := 0
	for e in ev:
		if not (e is Dictionary):
			c.errors.append("%s: event %d is not an object" % [where, n])
			n += 1
			continue
		var ed: Dictionary = (e as Dictionary).duplicate()
		var t := String(ed.get("type", ""))
		if not ClipDef.EVENT_TYPES.has(t):
			c.errors.append("%s: event f=%s unknown type '%s'" % [where, ed.get("f", "?"), t])
		var f := int(ed.get("f", -1))
		if f < 0 or f > c.length:
			c.errors.append("%s: event '%s' frame %d is outside [0, %d]" % [where, t, f, c.length])
		ed["f"] = f
		ed["clip"] = c.id
		tmp.append([f, n, ed])
		n += 1
	tmp.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for row in tmp:
		c.events.append(row[2])
		c.ev_f.append(int(row[0]))
		var ed2: Dictionary = row[2]
		if String(ed2.get("type", "")) == "mark":
			c.marks[String(ed2.get("name", ""))] = int(ed2["f"])
	if not c.marks.has("accent") and c.beats.has("accent"):
		c.marks["accent"] = (c.beats["accent"] as Vector2i).x
	if not c.marks.has("release"):
		if c.beats.has("settle"):
			c.marks["release"] = (c.beats["settle"] as Vector2i).y
		elif c.is_reaction():
			c.marks["release"] = c.length
