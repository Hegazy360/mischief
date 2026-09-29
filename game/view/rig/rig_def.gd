## RigDef — a parsed `data/rigs/<id>/rig.json` (TECH §4.7): the flat-cutout rig every clip
## of that character is sampled against. Pure data (RefCounted, no Nodes), headless-safe.
##
## * Parts are stored in PARENT-FIRST order (`names`, `parent`, `offset`, `pivot`, `z_base`,
##   limits, texture variants, sizes). The root part's `offset` is its joint position
##   relative to the FEET origin (0, 0) — the character's world position.
## * Face slots become VIRTUAL PARTS named `face_<slot>` (children of the face anchor, drawn
##   centred on the anchor + the slot's offset), so poses can scale / move them (a wild take's
##   eyes 1.8×) and a face preset is just their `tex` / `vis` channels.
## * A POSE is a PackedFloat32Array of `pose_size` floats: ROOT_CH root channels
##   `[x, y, rot, sx, sy]` then STRIDE channels per part `[rot, x, y, sx, sy, z, tex, vis,
##   alpha]` (rot in degrees, clockwise-positive; x/y in px added to the part's offset; tex =
##   variant index into `tex_names[part]`). `rest` is the rig's rest pose.
## * `errors` / `warnings` collect every problem found while loading (RigLint reports them);
##   a rig with errors still loads as far as it can.
## `RigDef.for_id(id)` caches rigs by id (`invalidate(id)` for hot reload).
class_name RigDef
extends RefCounted

const ROOT_CH := 5
const STRIDE := 9
const R_X := 0
const R_Y := 1
const R_ROT := 2
const R_SX := 3
const R_SY := 4
const C_ROT := 0
const C_X := 1
const C_Y := 2
const C_SX := 3
const C_SY := 4
const C_Z := 5
const C_TEX := 6
const C_VIS := 7
const C_ALPHA := 8
const CHANNELS: PackedStringArray = ["rot", "x", "y", "sx", "sy", "z", "tex", "vis", "alpha"]
const ROOT_CHANNELS: PackedStringArray = ["x", "y", "rot", "sx", "sy"]
const FACE_PREFIX := "face_"
const NO_LIMIT := 1.0e9
## Spring channels.
const SPRING_ROT := 0
const SPRING_SY := 1

## Root of the data tree (tests may point it at fixtures).
static var data_root: String = "res://data"
static var _cache: Dictionary = {}

## One rubber-hose limb: a round-capped stroke (fill + ink outline) through its joints.
class RigLimb extends RefCounted:
	var id: String = ""
	var joints: PackedInt32Array = PackedInt32Array()
	var width: float = 24.0
	var fill: Color = Color.WHITE
	var outline: float = 6.0
	var ink: Color = Color("#1B2340")
	var cap: String = "round"


## One socketed prop (`props` in rig.json).
class RigProp extends RefCounted:
	var id: String = ""
	var pivot: Vector2 = Vector2.ZERO
	var socket: String = ""          ## "part:socket"
	var socket_i: int = -1           ## index into RigDef.socket_names
	var states: PackedStringArray = PackedStringArray()
	var state_files: PackedStringArray = PackedStringArray()
	var state_sizes: PackedVector2Array = PackedVector2Array()
	var default_state: int = 0
	var z_offset: int = 1
	## Starts hidden (rig.json `"hidden": true`); a `prop` event `show` / `attach` reveals it.
	var hidden: bool = false
	## Absolute z while on its default socket (rig.json `"z"`; -1 = socket part z + z_offset).
	var z_abs: int = -1
	## "part:socket" → absolute z (rig.json `z_by_socket`, e.g. Clarence behind the glove).
	var z_by_socket: Dictionary = {}
	## state → "part:socket" the prop moves to in that state (`state_sockets`: specs chain ↔ nose).
	var state_sockets: Dictionary = {}
	## state → z offset over the socket part (`state_z_offset`).
	var state_z_offset: Dictionary = {}


## Residue look (`residues` in rig.json): texture overrides + overlays sharing part pivots.
class RigResidue extends RefCounted:
	var kind: String = ""
	var tex_part: PackedInt32Array = PackedInt32Array()
	var tex_var: PackedInt32Array = PackedInt32Array()
	var overlay_part: PackedInt32Array = PackedInt32Array()
	var overlay_file: PackedStringArray = PackedStringArray()
	var overlay_size: PackedVector2Array = PackedVector2Array()
	## Face slots shown while active (`face_overlays`: slot names; their first real variant).
	var face_slots: PackedInt32Array = PackedInt32Array()
	## prop id → "part:socket" attached (and shown) while active (`props`).
	var props: Dictionary = {}
	## limb index → Color (`limb_fill`: long johns).
	var limb_fill: Dictionary = {}
	## Combos (`combos` map): residue kinds that must all be on, and kinds hidden while it shows.
	var combo_of: PackedStringArray = PackedStringArray()
	var combo_replaces: PackedStringArray = PackedStringArray()


var id: String = ""
var path: String = ""
var raw: Dictionary = {}
var height_px: float = 300.0
var root_part: String = ""
var root_index: int = 0
var art_dir: String = ""
var pose_size: int = ROOT_CH

var names: PackedStringArray = PackedStringArray()
var parent: PackedInt32Array = PackedInt32Array()
var offset: PackedVector2Array = PackedVector2Array()
var pivot: PackedVector2Array = PackedVector2Array()
var z_base: PackedInt32Array = PackedInt32Array()
var rot_min: PackedFloat32Array = PackedFloat32Array()
var rot_max: PackedFloat32Array = PackedFloat32Array()
## Parts that have rot limits (RigSampler.clamp_limits walks only these).
var limited: PackedInt32Array = PackedInt32Array()
## Texture variants per part (index 0 = default). Empty for invisible bones.
var tex_names: Array[PackedStringArray] = []
var tex_files: Array[PackedStringArray] = []
var tex_sizes: Array[PackedVector2Array] = []
## Limb index of `draw: "limb:<id>"` bones (-1 otherwise).
var limb_of: PackedInt32Array = PackedInt32Array()
## Face slot index of virtual face parts (-1 otherwise).
var face_slot_of: PackedInt32Array = PackedInt32Array()
var no_mirror: PackedByteArray = PackedByteArray()
## Mirror partner part index (-1 when unpaired).
var mirror_idx: PackedInt32Array = PackedInt32Array()
var mirror_pairs: Array[PackedStringArray] = []

var socket_names: PackedStringArray = PackedStringArray()   ## "part:socket"
var socket_part: PackedInt32Array = PackedInt32Array()
var socket_xf: PackedVector3Array = PackedVector3Array()    ## (x, y, angle°) in part canvas px

var spring_part: PackedInt32Array = PackedInt32Array()
var spring_channel: PackedInt32Array = PackedInt32Array()
var spring_k: PackedFloat32Array = PackedFloat32Array()
var spring_c: PackedFloat32Array = PackedFloat32Array()
var spring_clamp: PackedFloat32Array = PackedFloat32Array()

var limbs: Array[RigLimb] = []
var face_anchor: int = -1
var face_offset: Vector2 = Vector2.ZERO
var face_slots: PackedStringArray = PackedStringArray()
var face_slot_part: PackedInt32Array = PackedInt32Array()
var pupils_part: int = -1
var pupil_range: Vector2 = Vector2(3, 3)
var eyes_part: int = -1
## Eyes variants that hide the pupils (`face.slots.pupils.hide_with` / `eyes.no_pupils`).
var pupils_hide: PackedInt32Array = PackedInt32Array()
## Eyes variant index → lids variant index (`face.slots.eyes.lids`); `lids_part` = face_lids.
var eyes_lids: Dictionary = {}
var lids_part: int = -1

var residues: Dictionary = {}          ## kind → RigResidue
var tint_parts: PackedInt32Array = PackedInt32Array()
var tint_tiers: PackedColorArray = PackedColorArray()
var props: Array[RigProp] = []
var prop_index: Dictionary = {}        ## id → index
var feet: PackedInt32Array = PackedInt32Array()
## Per foot (same order as `feet`): the 2-bone chain [upper, lower] above it (-1 when the
## foot is not the end of a 2-bone chain) — used by the plant lock (RigSampler).
var foot_upper: PackedInt32Array = PackedInt32Array()
var foot_lower: PackedInt32Array = PackedInt32Array()
var breath_part: int = -1
var breath_amp: float = 0.015
var breath_period: float = 3.2
var look_part: int = -1
var look_max_deg: float = 20.0
var masks: Dictionary = {}             ## name → PackedStringArray
## Locomotion parts (1 = in): the root part, every foot and every ancestor of a foot. An
## overlay clip never writes them (RigPlayer), so a micro-gag over a walk keeps the walk's
## planted feet and root exactly (s2-rig §4.1.1).
var locomotion: PackedByteArray = PackedByteArray()
var skins: Dictionary = {}             ## skin → {"dir": String}
var rest: PackedFloat32Array = PackedFloat32Array()

var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()

var _index: Dictionary = {}


## Cached rig by id (`<data_root>/rigs/<id>/rig.json`); null if the file does not exist.
static func for_id(rig_id: String) -> RigDef:
	var hit: RigDef = _cache.get(rig_id, null)
	if hit != null:
		return hit
	var p := "%s/rigs/%s/rig.json" % [data_root, rig_id]
	if not FileAccess.file_exists(p):
		return null
	var r := RigDef.load(p)
	_cache[rig_id] = r
	return r


## Forget a cached rig ("" = all).
static func invalidate(rig_id: String = "") -> void:
	if rig_id == "":
		_cache.clear()
	else:
		_cache.erase(rig_id)


## Parse a rig.json file. Always returns a RigDef; problems go to `errors`.
static func load(file_path: String) -> RigDef:
	var r := RigDef.new()
	r.path = file_path
	var data: Variant = _read_json(file_path, r.errors)
	if data is Dictionary:
		r._parse(data)
	elif r.errors.is_empty():
		r.errors.append("%s: not a JSON object" % file_path)
	return r


## Parse from an already-parsed dictionary (tests).
static func from_dict(d: Dictionary, file_path: String = "") -> RigDef:
	var r := RigDef.new()
	r.path = file_path
	r._parse(d)
	return r


static func _read_json(file_path: String, errs: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(file_path):
		errs.append("%s: missing" % file_path)
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(file_path)) != OK:
		errs.append("%s:%d: %s" % [file_path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


## Part index by name (-1 when unknown).
func idx(part: String) -> int:
	return int(_index.get(part, -1))


func part_count() -> int:
	return names.size()


## Pose array offset of part `i` channel `c`.
static func ch(i: int, c: int) -> int:
	return ROOT_CH + i * STRIDE + c


## Variant index of texture `variant` on part `i` (-1 when unknown).
func tex_index(i: int, variant: String) -> int:
	if i < 0 or i >= tex_names.size():
		return -1
	return tex_names[i].find(variant)


## True when part `i` draws a texture (not a limb bone / invisible bone).
func is_textured(i: int) -> bool:
	return i >= 0 and i < tex_files.size() and not tex_files[i].is_empty() and limb_of[i] < 0


## Socket index for "part:socket" (-1 when unknown).
func socket_index(name: String) -> int:
	return socket_names.find(name)


## Every texture path the rig can draw (parts, variants, face slots, overlays, props), for
## the atlas. `skin` resolves each path through `skin_path`.
func all_texture_paths(skin: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var add := func(p: String) -> void:
		if p == "":
			return
		var q := skin_path(p, skin)
		if not seen.has(q):
			seen[q] = true
			out.append(q)
	for i in names.size():
		if limb_of[i] >= 0:
			continue
		for f in tex_files[i]:
			add.call(f)
	for k in residues:
		var res: RigResidue = residues[k]
		for f in res.overlay_file:
			add.call(f)
	for pr in props:
		for f in pr.state_files:
			add.call(f)
	return out


## Textures only a residue look draws (s2-rig §4.3, lazy look pages): its overlays, the part
## variants its `tex` swaps in (never a part's rest variant), the variants of its face
## overlay slots, and its props' state textures — minus anything the base set already has.
## Deterministic per (kind, skin), so two players share the look's cached atlas.
func look_texture_paths(kind: String, skin: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var res: RigResidue = residues.get(kind, null)
	if res == null:
		return out
	var base := _base_set(skin)
	var add := func(p: String) -> void:
		if p == "":
			return
		var q := skin_path(p, skin)
		if not base.has(q) and not out.has(q):
			out.append(q)
	for f in res.overlay_file:
		add.call(f)
	for k in res.tex_part.size():
		var files: PackedStringArray = tex_files[res.tex_part[k]]
		if res.tex_var[k] < files.size():
			add.call(files[res.tex_var[k]])
	for si in res.face_slots:
		for f2 in tex_files[face_slot_part[si]]:
			add.call(f2)
	for pid in res.props:
		var pi := int(prop_index.get(String(pid), -1))
		if pi >= 0:
			for f3 in (props[pi] as RigProp).state_files:
				add.call(f3)
	return out


## Every texture the rig draws without any residue look (all_texture_paths minus the files
## only residue looks use), core first: the atlas RigPlayer.setup() builds.
func base_texture_paths(skin: String = "") -> PackedStringArray:
	var only := _look_only(skin)
	var out := PackedStringArray()
	for q in core_texture_paths(skin):
		if not only.has(q) and not out.has(q):
			out.append(q)
	for q2 in all_texture_paths(skin):
		if not only.has(q2) and not out.has(q2):
			out.append(q2)
	return out


## The files of `paths` that are in the base set (core-first order kept) — the count
## AtlasBuilder packs first.
func base_core_count(skin: String = "") -> int:
	var only := _look_only(skin)
	var n := 0
	var seen := {}
	for q in core_texture_paths(skin):
		if not only.has(q) and not seen.has(q):
			seen[q] = true
			n += 1
	return n


var _base_cache: Dictionary = {}   ## skin → {path: true}
var _only_cache: Dictionary = {}   ## skin → {path: true}


func _base_set(skin: String) -> Dictionary:
	if not _base_cache.has(skin):
		var d := {}
		for q in base_texture_paths(skin):
			d[q] = true
		_base_cache[skin] = d
	return _base_cache[skin]


## Files referenced ONLY by residue looks: overlays, residue-swapped part variants (never a
## part's rest variant), the variants of face-overlay slots hidden by default (singe,
## hiccup), and props that start hidden and that residues attach (costumes).
func _look_only(skin: String) -> Dictionary:
	if _only_cache.has(skin):
		return _only_cache[skin]
	var cand := {}
	var res_props := {}
	var res_slots := {}
	for k in residues:
		var res: RigResidue = residues[k]
		for f in res.overlay_file:
			cand[skin_path(f, skin)] = true
		for t in res.tex_part.size():
			var p := res.tex_part[t]
			var v := res.tex_var[t]
			if v != int(rest[ch(p, C_TEX)]) and v < tex_files[p].size():
				cand[skin_path(tex_files[p][v], skin)] = true
		for si in res.face_slots:
			res_slots[si] = true
		for pid in res.props:
			res_props[String(pid)] = true
	for si2 in res_slots:
		var part := face_slot_part[si2]
		if rest[ch(part, C_VIS)] < 0.5:
			for f2 in tex_files[part]:
				cand[skin_path(f2, skin)] = true
	for pid2 in res_props:
		var pi := int(prop_index.get(pid2, -1))
		if pi >= 0 and (props[pi] as RigProp).hidden:
			for f3 in (props[pi] as RigProp).state_files:
				cand[skin_path(f3, skin)] = true
	# Never a part's rest variant (the everyday look).
	for i in names.size():
		if limb_of[i] >= 0 or tex_files[i].is_empty() or rest[ch(i, C_VIS)] < 0.5:
			continue
		cand.erase(skin_path(tex_files[i][clampi(int(rest[ch(i, C_TEX)]), 0, tex_files[i].size() - 1)], skin))
	# Never a variant any pose shows (the sneeze's puffed sideburns are also COMBO:poodle's):
	# clips key poses, so those must not build a page mid-gag.
	var lib: PoseLib = PoseLib.for_rig(id) if id != "" and _cache.get(id, null) == self else null
	if lib != null:
		for pn in lib.poses:
			var pose: PackedFloat32Array = lib.poses[pn]
			for i2 in names.size():
				var nt := tex_files[i2].size()
				if limb_of[i2] >= 0 or nt < 2:
					continue
				var v2 := int(pose[ch(i2, C_TEX)])
				if v2 >= 0 and v2 < nt:
					cand.erase(skin_path(tex_files[i2][v2], skin))
	_only_cache[skin] = cand
	return cand


## The textures of the everyday look (every part's and face slot's rest variant, props'
## default states) — AtlasBuilder packs these first so they share page 0.
func core_texture_paths(skin: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for i in names.size():
		if limb_of[i] >= 0 or tex_files[i].is_empty():
			continue
		var v := clampi(int(rest[ch(i, C_TEX)]), 0, tex_files[i].size() - 1)
		var q := skin_path(tex_files[i][v], skin)
		if not out.has(q):
			out.append(q)
	for pr in props:
		if pr.state_files.is_empty():
			continue
		var q2 := skin_path(pr.state_files[pr.default_state], skin)
		if not out.has(q2):
			out.append(q2)
	return out


## The skin variant of a texture path: `<dir>/<skin>/<file>` when that file exists (or the
## rig's `skins.<skin>.dir`), else the path itself (TECH §4.7: skins share names/pivots).
func skin_path(p: String, skin: String) -> String:
	if skin == "" or p == "":
		return p
	var dir := p.get_base_dir() + "/" + skin
	var sk: Variant = skins.get(skin, null)
	if sk is Dictionary:
		var fm: Variant = (sk as Dictionary).get("files", {})
		if fm is Dictionary and (fm as Dictionary).has(p):
			var mapped := resolve(String(fm[p]))
			if FileAccess.file_exists(mapped):
				return mapped
		if (sk as Dictionary).has("dir"):
			dir = String((sk as Dictionary)["dir"]).trim_suffix("/")
	var cand := dir + "/" + p.get_file()
	return cand if FileAccess.file_exists(cand) else p


## Limb fill colours a skin overrides (`skins.<skin>.limbs.<limb>.fill`): limb index → Color.
func skin_limb_fills(skin: String) -> Dictionary:
	var out := {}
	var sk: Variant = skins.get(skin, null)
	if not (sk is Dictionary):
		return out
	var lv: Variant = (sk as Dictionary).get("limbs", {})
	if lv is Dictionary:
		for lid in lv:
			var li := _limb_index(String(lid))
			var e: Variant = lv[lid]
			if li >= 0 and e is Dictionary and (e as Dictionary).has("fill"):
				out[li] = Color.from_string(String(e["fill"]), limbs[li].fill)
	return out


## Resolve a file name from rig.json: absolute `res://` paths stay, relative ones are taken
## from `art_dir`.
func resolve(file: String) -> String:
	if file == "" or file.begins_with("res://") or file.begins_with("user://") or file.begins_with("/"):
		return file
	return art_dir.path_join(file)


## A fresh copy of the rest pose.
func new_pose() -> PackedFloat32Array:
	return rest.duplicate()


## Descendants of part `i` (including `i`), parent-first.
func subtree(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if i < 0:
		return out
	var inside := PackedByteArray()
	inside.resize(names.size())
	inside[i] = 1
	out.append(i)
	for j in range(i + 1, names.size()):
		var p := parent[j]
		if p >= 0 and inside[p] == 1:
			inside[j] = 1
			out.append(j)
	return out


## True when rig.json `masks` defines `mask_name`.
func has_mask(mask_name: String) -> bool:
	return masks.has(mask_name)


## Per-part mask (1 = in) from a list of part names; `name*` adds the whole subtree, a
## String names an entry of rig.json `masks`. Unknown names go to `errs`.
func mask_from(spec: Variant, errs: PackedStringArray = PackedStringArray()) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(names.size())
	var items: Array = []
	if spec is String:
		if masks.has(spec):
			items = Array(masks[spec])
		else:
			errs.append("unknown mask '%s'" % spec)
	elif spec is Array:
		items = spec
	for it in items:
		var s := String(it)
		var deep := s.ends_with("*")
		var n := s.trim_suffix("*")
		var i := idx(n)
		if i < 0:
			errs.append("mask part '%s' not in rig %s" % [n, id])
			continue
		if deep:
			for j in subtree(i):
				m[j] = 1
		else:
			m[i] = 1
	return m


# --- parsing ---------------------------------------------------------------------------------

func _parse(d: Dictionary) -> void:
	raw = d
	id = String(d.get("rig", d.get("id", path.get_base_dir().get_file())))
	height_px = float(d.get("height_px", 300))
	var parts_v: Variant = d.get("parts", {})
	if not (parts_v is Dictionary) or (parts_v as Dictionary).is_empty():
		errors.append("%s: no parts" % _where())
		return
	var parts: Dictionary = parts_v
	art_dir = String(d.get("art_dir", ""))
	if art_dir == "":
		for pn in parts:
			var f := String((parts[pn] as Dictionary).get("file", "")) if parts[pn] is Dictionary else ""
			if f.begins_with("res://"):
				art_dir = f.get_base_dir()
				break
	if art_dir == "":
		art_dir = "res://art/chars/%s" % id
	art_dir = art_dir.trim_suffix("/")
	var sk: Variant = d.get("skins", {})
	if sk is Dictionary:
		skins = sk
	# Parent-first order: the root, then repeatedly every part whose parent is placed.
	root_part = String(d.get("root_part", ""))
	if root_part == "":
		for pn in parts:
			var pd: Variant = parts[pn]
			if pd is Dictionary and (pd as Dictionary).get("parent", null) == null:
				root_part = String(pn)
				break
	if not parts.has(root_part):
		errors.append("%s: root_part '%s' is not a part" % [_where(), root_part])
		return
	var ordered: Array[String] = [root_part]
	var placed := {root_part: true}
	var pending: Array[String] = []
	for pn in parts:
		if String(pn) != root_part:
			pending.append(String(pn))
	var progress := true
	while not pending.is_empty() and progress:
		progress = false
		var still: Array[String] = []
		for pn in pending:
			var pd2: Variant = parts[pn]
			var par := String((pd2 as Dictionary).get("parent", "")) if pd2 is Dictionary else ""
			if par == "":
				errors.append("%s: part '%s' has no parent (only the root may)" % [_where(), pn])
				continue
			if placed.has(par):
				ordered.append(pn)
				placed[pn] = true
				progress = true
			else:
				still.append(pn)
		pending = still
	for pn in pending:
		var par2 := String((parts[pn] as Dictionary).get("parent", ""))
		if parts.has(par2):
			errors.append("%s: part '%s' is in a parent cycle" % [_where(), pn])
		else:
			errors.append("%s: part '%s' has unknown parent '%s'" % [_where(), pn, par2])
	for pn in ordered:
		_add_part(pn, parts[pn] if parts[pn] is Dictionary else {})
	for i in names.size():
		var pd3: Dictionary = parts[names[i]]
		var par3 := String(pd3.get("parent", ""))
		parent[i] = idx(par3) if par3 != "" else -1
	root_index = 0
	_parse_limbs(d)
	_parse_face(d)
	_parse_springs(parts)
	_parse_tint(d)
	_parse_props(d)
	_parse_residues(d)
	_parse_mirror(d)
	_parse_misc(d)
	_build_rest()


func _where() -> String:
	return path if path != "" else "rig '%s'" % id


func _v2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


func _add_part(pn: String, pd: Dictionary) -> void:
	var i := names.size()
	_index[pn] = i
	names.append(pn)
	parent.append(-1)
	var off := _v2(pd.get("offset", null), Vector2.INF)
	if off == Vector2.INF:
		if i == 0:
			warnings.append("%s: root part '%s' has no offset (joint above the feet); using [0, %d]" % [_where(), pn, -int(height_px * 0.5)])
			off = Vector2(0, -height_px * 0.5)
		else:
			off = Vector2.ZERO
	offset.append(off)
	pivot.append(_v2(pd.get("pivot", null)))
	z_base.append(int(pd.get("z", 0)))
	var lim: Variant = pd.get("limits", {})
	var lo := -NO_LIMIT
	var hi := NO_LIMIT
	if lim is Dictionary and (lim as Dictionary).get("rot", null) is Array:
		var rr: Array = (lim as Dictionary)["rot"]
		if rr.size() >= 2:
			lo = float(rr[0])
			hi = float(rr[1])
			if lo > hi:
				errors.append("%s: part '%s' limits.rot min > max" % [_where(), pn])
	rot_min.append(lo)
	rot_max.append(hi)
	var draw := String(pd.get("draw", ""))
	limb_of.append(-2 if draw.begins_with("limb:") else -1)   # resolved in _parse_limbs
	if pd.has("visible") and not bool(pd["visible"]):
		_hidden_parts[i] = true
	face_slot_of.append(-1)
	no_mirror.append(0)
	mirror_idx.append(-1)
	var vn := PackedStringArray()
	var vf := PackedStringArray()
	var file := String(pd.get("file", ""))
	if file != "":
		vn.append("default")
		vf.append(resolve(file))
	var tex: Variant = pd.get("tex", {})
	if tex is Dictionary:
		for tn in tex:
			vn.append(String(tn))
			vf.append(resolve(String(tex[tn])))
	if draw.begins_with("limb:") and not vf.is_empty():
		warnings.append("%s: limb bone '%s' has textures (limb bones are invisible)" % [_where(), pn])
	tex_names.append(vn)
	tex_files.append(vf)
	var sizes := PackedVector2Array()
	for f in vf:
		var s := AtlasBuilder.svg_size(f)
		if s == Vector2.ZERO:
			errors.append("%s: part '%s' texture %s is missing or not a readable SVG" % [_where(), pn, f])
		sizes.append(s)
	tex_sizes.append(sizes)
	var so: Variant = pd.get("sockets", {})
	if so is Dictionary:
		for sn in so:
			var sv: Variant = so[sn]
			if sv is Array and (sv as Array).size() >= 2:
				socket_names.append("%s:%s" % [pn, sn])
				socket_part.append(i)
				socket_xf.append(Vector3(float(sv[0]), float(sv[1]), float(sv[2]) if (sv as Array).size() >= 3 else 0.0))
			else:
				errors.append("%s: part '%s' socket '%s' must be [x, y, angle]" % [_where(), pn, sn])
	pose_size = ROOT_CH + names.size() * STRIDE


func _parse_limbs(d: Dictionary) -> void:
	var lv: Variant = d.get("limbs", {})
	var ld: Dictionary = lv if lv is Dictionary else {}
	var by_id := {}
	for lid in ld:
		var e: Variant = ld[lid]
		if not (e is Dictionary):
			errors.append("%s: limb '%s' is not an object" % [_where(), lid])
			continue
		var l := RigLimb.new()
		l.id = String(lid)
		for jn in (e as Dictionary).get("joints", []):
			var j := idx(String(jn))
			if j < 0:
				errors.append("%s: limb '%s' joint '%s' is not a part" % [_where(), lid, jn])
			else:
				l.joints.append(j)
		if l.joints.size() < 2:
			errors.append("%s: limb '%s' needs ≥ 2 joints" % [_where(), lid])
		for k in range(1, l.joints.size()):
			if parent[l.joints[k]] != l.joints[k - 1]:
				warnings.append("%s: limb '%s' joint '%s' is not a child of '%s'" % [_where(), lid, names[l.joints[k]], names[l.joints[k - 1]]])
		l.width = float((e as Dictionary).get("width", 24))
		l.outline = float((e as Dictionary).get("outline", 6))
		l.fill = Color.from_string(String((e as Dictionary).get("fill", "#FFFFFF")), Color.WHITE)
		l.ink = Color.from_string(String((e as Dictionary).get("ink", "#1B2340")), Color("#1B2340"))
		l.cap = String((e as Dictionary).get("cap", "round"))
		by_id[l.id] = limbs.size()
		limbs.append(l)
	var parts: Dictionary = d.get("parts", {})
	for i in names.size():
		if limb_of[i] == -2:
			var draw := String((parts[names[i]] as Dictionary).get("draw", ""))
			var lid2 := draw.trim_prefix("limb:")
			if by_id.has(lid2):
				limb_of[i] = int(by_id[lid2])
			else:
				errors.append("%s: part '%s' draws unknown limb '%s'" % [_where(), names[i], lid2])
				limb_of[i] = -1


func _parse_face(d: Dictionary) -> void:
	var fv: Variant = d.get("face", null)
	if not (fv is Dictionary):
		return
	var f: Dictionary = fv
	face_anchor = idx(String(f.get("anchor", "head")))
	if face_anchor < 0:
		errors.append("%s: face anchor '%s' is not a part" % [_where(), f.get("anchor", "head")])
		return
	face_offset = _v2(f.get("offset", [0, 0]))
	var sv: Variant = f.get("slots", {})
	if not (sv is Dictionary):
		errors.append("%s: face.slots must be an object" % _where())
		return
	for sn in sv:
		var s: Variant = sv[sn]
		if not (s is Dictionary):
			errors.append("%s: face slot '%s' must be an object" % [_where(), sn])
			continue
		var sd: Dictionary = s
		var pname := FACE_PREFIX + String(sn)
		if _index.has(pname):
			errors.append("%s: face slot '%s' clashes with part '%s'" % [_where(), sn, pname])
			continue
		var vn := PackedStringArray()
		var vf := PackedStringArray()
		var vars: Variant = sd.get("variants", {})
		if vars is Dictionary:
			for v in vars:
				vn.append(String(v))
				vf.append(resolve(String(vars[v])))
		if sd.has("file"):
			vn.append("default")
			vf.append(resolve(String(sd["file"])))
		var i := names.size()
		var pd := {"parent": names[face_anchor], "z": int(sd.get("z", 8))}
		_add_part(pname, pd)
		# _add_part appended an empty variant list; replace it with the slot variants.
		tex_names[i] = vn
		tex_files[i] = vf
		var sizes := PackedVector2Array()
		for fp in vf:
			var sz := AtlasBuilder.svg_size(fp)
			if sz == Vector2.ZERO:
				errors.append("%s: face slot '%s' texture %s is missing or not a readable SVG" % [_where(), sn, fp])
			sizes.append(sz)
		tex_sizes[i] = sizes
		parent[i] = face_anchor
		offset[i] = face_offset + _v2(sd.get("offset", [0, 0]))
		var piv := _v2(sd.get("pivot", null), Vector2.INF)
		if piv == Vector2.INF:
			piv = sizes[0] * 0.5 if not sizes.is_empty() else Vector2.ZERO
		pivot[i] = piv
		var slot_i := face_slots.size()
		face_slots.append(String(sn))
		face_slot_part.append(i)
		face_slot_of[i] = slot_i
		if String(sn) == "pupils":
			pupils_part = i
			pupil_range = _v2(sd.get("range", [3, 3]), Vector2(3, 3))
		elif String(sn) == "eyes":
			eyes_part = i
		if vn.is_empty():
			warnings.append("%s: face slot '%s' has no variants" % [_where(), sn])
		var dflt := String(sd.get("default", ""))
		if dflt != "" and dflt != "none" and vn.find(dflt) < 0:
			errors.append("%s: face slot '%s' default '%s' is not a variant" % [_where(), sn, dflt])
		_slot_default[i] = dflt
	lids_part = idx(FACE_PREFIX + "lids")
	if eyes_part >= 0:
		var hide: Array = []
		var pd2: Variant = (sv as Dictionary).get("pupils", {})
		if pd2 is Dictionary:
			hide.append_array((pd2 as Dictionary).get("hide_with", []))
		var ed: Variant = (sv as Dictionary).get("eyes", {})
		if ed is Dictionary:
			hide.append_array((ed as Dictionary).get("no_pupils", []))
			var lm: Variant = (ed as Dictionary).get("lids", {})
			if lm is Dictionary and lids_part >= 0:
				for ev in lm:
					var ei := tex_index(eyes_part, String(ev))
					var li := tex_index(lids_part, String(lm[ev]))
					if ei < 0 or li < 0:
						errors.append("%s: face eyes.lids %s → %s does not resolve" % [_where(), ev, lm[ev]])
					else:
						eyes_lids[ei] = li
		for hv in hide:
			var hi := tex_index(eyes_part, String(hv))
			if hi >= 0 and not pupils_hide.has(hi):
				pupils_hide.append(hi)


var _slot_default: Dictionary = {}
var _hidden_parts: Dictionary = {}


func _parse_springs(parts: Dictionary) -> void:
	for i in names.size():
		if not parts.has(names[i]):
			continue
		var sp: Variant = (parts[names[i]] as Dictionary).get("spring", null)
		if not (sp is Dictionary):
			continue
		var s: Dictionary = sp
		var chn := String(s.get("channel", "rot"))
		if chn != "rot" and chn != "sy":
			errors.append("%s: part '%s' spring channel '%s' must be rot or sy" % [_where(), names[i], chn])
			continue
		spring_part.append(i)
		spring_channel.append(SPRING_ROT if chn == "rot" else SPRING_SY)
		spring_k.append(float(s.get("k", 220)))
		spring_c.append(float(s.get("c", 10)))
		spring_clamp.append(float(s.get("clamp", 30.0 if chn == "rot" else 0.08)))
		if float(s.get("k", 220)) <= 0.0 or float(s.get("c", 10)) < 0.0:
			errors.append("%s: part '%s' spring needs k > 0 and c ≥ 0" % [_where(), names[i]])


func _parse_residues(d: Dictionary) -> void:
	var rv: Variant = d.get("residues", {})
	if rv is Dictionary:
		for kind in rv:
			var e: Variant = rv[kind]
			if not (e is Dictionary):
				continue
			residues[String(kind)] = _residue_from(String(kind), e)
			# Sub-looks: `blind` (while the residue blinds him) and `variants` (COSTUME:<id>),
			# unless the file already lists them flattened.
			var bl: Variant = (e as Dictionary).get("blind", null)
			if bl is Dictionary and not rv.has("%s:blind" % kind):
				residues["%s:blind" % kind] = _residue_from("%s:blind" % kind, bl)
			var vv: Variant = (e as Dictionary).get("variants", null)
			if vv is Dictionary:
				for vn in vv:
					var key := "%s:%s" % [kind, vn]
					if not rv.has(key) and vv[vn] is Dictionary:
						residues[key] = _residue_from(key, vv[vn])
	# Combos: {id: {of: [..], replaces: [..], tex, overlays, face_overlays, props}} → COMBO:<id>.
	var cv: Variant = d.get("combos", {})
	if cv is Dictionary:
		for cid in cv:
			var ce: Variant = cv[cid]
			if not (ce is Dictionary):
				continue
			var key2 := "COMBO:%s" % cid
			var res: RigResidue = residues[key2] if residues.has(key2) else _residue_from(key2, ce)
			res.combo_of = PackedStringArray((ce as Dictionary).get("of", []))
			res.combo_replaces = PackedStringArray((ce as Dictionary).get("replaces", (ce as Dictionary).get("of", [])))
			for k in res.combo_of:
				if not residues.has(k) and not (rv is Dictionary and (rv as Dictionary).has(k)):
					warnings.append("%s: combo %s needs residue %s, which the rig does not define" % [_where(), cid, k])
			residues[key2] = res


func _residue_from(kind: String, e: Dictionary) -> RigResidue:
	var res := RigResidue.new()
	res.kind = kind
	var tv: Variant = e.get("tex", {})
	if tv is Dictionary:
		for pn in tv:
			var i := idx(String(pn))
			var vi := tex_index(i, String(tv[pn]))
			if i < 0 or vi < 0:
				errors.append("%s: residue %s tex %s:%s does not resolve" % [_where(), kind, pn, tv[pn]])
				continue
			res.tex_part.append(i)
			res.tex_var.append(vi)
	var ov: Variant = e.get("overlays", {})
	if ov is Dictionary:
		for pn2 in ov:
			var j := idx(String(pn2))
			if j < 0:
				errors.append("%s: residue %s overlay part '%s' unknown" % [_where(), kind, pn2])
				continue
			var fp := resolve(String(ov[pn2]))
			var sz := AtlasBuilder.svg_size(fp)
			if sz == Vector2.ZERO:
				errors.append("%s: residue %s overlay %s is missing" % [_where(), kind, fp])
			res.overlay_part.append(j)
			res.overlay_file.append(fp)
			res.overlay_size.append(sz)
	for fs in e.get("face_overlays", []):
		var si := face_slots.find(String(fs))
		if si < 0:
			errors.append("%s: residue %s face overlay '%s' is not a face slot" % [_where(), kind, fs])
		else:
			res.face_slots.append(si)
	var pv: Variant = e.get("props", {})
	if pv is Dictionary:
		for pid in pv:
			if not prop_index.has(String(pid)):
				errors.append("%s: residue %s prop '%s' is not a prop" % [_where(), kind, pid])
			elif socket_index(String(pv[pid])) < 0:
				errors.append("%s: residue %s prop %s socket '%s' does not exist" % [_where(), kind, pid, pv[pid]])
			else:
				res.props[String(pid)] = String(pv[pid])
	var lf: Variant = e.get("limb_fill", {})
	if lf is Dictionary:
		for lid in lf:
			var li := _limb_index(String(lid))
			if li < 0:
				errors.append("%s: residue %s limb_fill limb '%s' unknown" % [_where(), kind, lid])
			else:
				res.limb_fill[li] = Color.from_string(String(lf[lid]), Color.WHITE)
	return res


func _limb_index(lid: String) -> int:
	for i in limbs.size():
		if limbs[i].id == lid:
			return i
	return -1


func _parse_tint(d: Dictionary) -> void:
	var tv: Variant = d.get("tint", null)
	if not (tv is Dictionary):
		return
	for pn in (tv as Dictionary).get("parts", []):
		var i := idx(String(pn))
		if i < 0:
			errors.append("%s: tint part '%s' unknown" % [_where(), pn])
		else:
			tint_parts.append(i)
	for c in (tv as Dictionary).get("tiers", []):
		tint_tiers.append(Color.from_string(String(c), Color.WHITE))


func _parse_props(d: Dictionary) -> void:
	var pv: Variant = d.get("props", {})
	if not (pv is Dictionary):
		return
	for pid in pv:
		var e: Variant = pv[pid]
		if not (e is Dictionary):
			continue
		var pd: Dictionary = e
		var pr := RigProp.new()
		pr.id = String(pid)
		pr.pivot = _v2(pd.get("pivot", [0, 0]))
		pr.socket = String(pd.get("socket", ""))
		pr.socket_i = socket_index(pr.socket)
		if pr.socket != "" and pr.socket_i < 0:
			errors.append("%s: prop '%s' socket '%s' does not exist" % [_where(), pid, pr.socket])
		pr.z_offset = int(pd.get("z_offset", 1))
		pr.hidden = bool(pd.get("hidden", false))
		pr.z_abs = int(pd.get("z", -1))
		var zbs: Variant = pd.get("z_by_socket", {})
		if zbs is Dictionary:
			for sk in zbs:
				if socket_index(String(sk)) < 0:
					errors.append("%s: prop '%s' z_by_socket socket '%s' does not exist" % [_where(), pid, sk])
				pr.z_by_socket[String(sk)] = int(zbs[sk])
		var sss: Variant = pd.get("state_sockets", {})
		if sss is Dictionary:
			for st2 in sss:
				if socket_index(String(sss[st2])) < 0:
					errors.append("%s: prop '%s' state_sockets %s → '%s' does not exist" % [_where(), pid, st2, sss[st2]])
				pr.state_sockets[String(st2)] = String(sss[st2])
		var szo: Variant = pd.get("state_z_offset", {})
		if szo is Dictionary:
			for st3 in szo:
				pr.state_z_offset[String(st3)] = int(szo[st3])
		var file := resolve(String(pd.get("file", "")))
		var tex: Dictionary = pd.get("tex", {}) if pd.get("tex", {}) is Dictionary else {}
		var states: Array = pd.get("states", [])
		if states.is_empty():
			states = ["default"]
		for st in states:
			var sname := String(st)
			var sf := ""
			if tex.has(sname):
				sf = resolve(String(tex[sname]))
			else:
				var cand := file.get_basename() + "_" + sname + ".svg"
				sf = cand if FileAccess.file_exists(cand) else file
			pr.states.append(sname)
			pr.state_files.append(sf)
			var sz := AtlasBuilder.svg_size(sf)
			if sz == Vector2.ZERO:
				errors.append("%s: prop '%s' state '%s' texture %s is missing" % [_where(), pid, sname, sf])
			pr.state_sizes.append(sz)
		var ds := String(pd.get("default", pd.get("default_state", pr.states[0])))
		pr.default_state = maxi(0, pr.states.find(ds))
		prop_index[pr.id] = props.size()
		props.append(pr)


func _parse_mirror(d: Dictionary) -> void:
	var mp: Variant = d.get("mirror_pairs", [["_l", "_r"]])
	if mp is Array:
		for pair in mp:
			if pair is Array and (pair as Array).size() == 2:
				mirror_pairs.append(PackedStringArray([String(pair[0]), String(pair[1])]))
	for i in names.size():
		var n := names[i]
		for pair2 in mirror_pairs:
			for side in 2:
				var a := pair2[side]
				var b := pair2[1 - side]
				if n.ends_with(a):
					var partner := n.substr(0, n.length() - a.length()) + b
					var j := idx(partner)
					if j >= 0:
						mirror_idx[i] = j
					else:
						errors.append("%s: mirror pair of '%s' ('%s') does not exist" % [_where(), n, partner])
	for pn in d.get("no_mirror", []):
		var k := idx(String(pn))
		if k < 0:
			errors.append("%s: no_mirror part '%s' unknown" % [_where(), pn])
		else:
			no_mirror[k] = 1


func _parse_misc(d: Dictionary) -> void:
	var fv: Variant = d.get("feet", null)
	if fv is Array:
		for pn in fv:
			var i := idx(String(pn))
			if i < 0:
				errors.append("%s: feet part '%s' unknown" % [_where(), pn])
			else:
				feet.append(i)
	else:
		for i2 in names.size():
			if names[i2].begins_with("foot") or names[i2].contains("_foot"):
				feet.append(i2)
	for ft in feet:
		var lo := parent[ft]
		var up := parent[lo] if lo >= 0 else -1
		var ok := lo >= 0 and up >= 0 and parent[up] >= 0 and offset[lo].length() > 1.0 and offset[ft].length() > 1.0
		foot_upper.append(up if ok else -1)
		foot_lower.append(lo if ok else -1)
	var bv: Variant = d.get("breath", {})
	var bd: Dictionary = bv if bv is Dictionary else {}
	breath_part = idx(String(bd.get("part", "torso")))
	if breath_part < 0:
		breath_part = root_index
	breath_amp = float(bd.get("amp", 0.015))
	breath_period = maxf(0.2, float(bd.get("period_s", 3.2)))
	var lv: Variant = d.get("look", {})
	var ld: Dictionary = lv if lv is Dictionary else {}
	look_part = idx(String(ld.get("part", "head")))
	look_max_deg = float(ld.get("max_deg", 20.0))
	var mv: Variant = d.get("masks", {})
	if mv is Dictionary:
		for mn in mv:
			masks[String(mn)] = PackedStringArray(mv[mn] if mv[mn] is Array else [])
	locomotion.resize(names.size())
	locomotion.fill(0)
	if not names.is_empty():
		locomotion[root_index] = 1
	for ft2 in feet:
		var a := ft2
		while a >= 0:
			locomotion[a] = 1
			a = parent[a]


func _build_rest() -> void:
	limited = PackedInt32Array()
	for li in names.size():
		if rot_min[li] > -NO_LIMIT or rot_max[li] < NO_LIMIT:
			limited.append(li)
	rest = PackedFloat32Array()
	rest.resize(pose_size)
	rest[R_SX] = 1.0
	rest[R_SY] = 1.0
	for i in names.size():
		var b := ROOT_CH + i * STRIDE
		rest[b + C_SX] = 1.0
		rest[b + C_SY] = 1.0
		rest[b + C_Z] = float(z_base[i])
		rest[b + C_VIS] = 1.0
		rest[b + C_ALPHA] = 1.0
		if _hidden_parts.has(i):
			rest[b + C_VIS] = 0.0
		var dflt := String(_slot_default.get(i, ""))
		if dflt == "none":
			rest[b + C_VIS] = 0.0
		elif dflt != "":
			rest[b + C_TEX] = float(maxi(0, tex_names[i].find(dflt)))
