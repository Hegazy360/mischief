## RigDef3D — a parsed 3D rig descriptor `data/rigs3d/<rig>/rig3d.json` (r3d-index §7.3): the skinned glTF
## on the UAL skeleton, its sockets, bone-driven props, attachments, body slots, looks, jiggle groups, the face
## card atlas and presets, the material, tint tiers, stone and cheat angles. Pure data (RefCounted), headless-safe.
##
## * `RigDef3D.load(rig_id, variant)` reads `rig3d.json` (or `rig3d_<variant>.json`, e.g. Hush's `"head_b"`,
##   ruling R6) from the first `search_roots` entry that has it, caches it per (rig, variant) and VALIDATES it:
##   the scene exists, every referenced bone exists in the scene's skeleton, sockets / props / jiggle /
##   attachments / slots / looks resolve, face cells sit inside the atlas grid and every preset's cells exist.
##   Every problem lands in `errors` (or `warnings`) as `"<file>: <key>: <what>"`; a def with errors still
##   loads as far as it can, `is_valid()` is false and `RigPlayer3D.setup()` refuses it (stand-in).
## * Bone names come from the scene (`bone_names`, `bone_parent`, `bone_rest` — the headless sampler builds its
##   skeleton from them).
## * The `"pip"` skin is not built in R3D (ruling R7): `load(rig, "pip")` loads the base descriptor (logged once).
class_name RigDef3D
extends RefCounted

## Face layers in uniform order: `face_cell_a` = (brows, eyes, pupils, mouth), `face_cell_b` = (extra_a,
## extra_b, lids, spare); `face_rect[i]` follows the first six (lids share the eyes' rect).
const FACE_LAYERS: PackedStringArray = ["brows", "eyes", "pupils", "mouth", "extra_a", "extra_b", "lids", "spare"]
## Descriptor keys the loader knows (anything else is a warning, so a typo does not silently do nothing).
const KNOWN_KEYS: PackedStringArray = ["version", "rig", "scene", "skeleton", "mesh", "height_m", "head_scale", "tris",
	"deform_bones", "bones", "sockets", "props", "attachments", "slots", "anim", "jiggle", "face", "material",
	"vertex_color", "looks", "tint", "stone", "cheat", "blob_shadow_r", "skins", "doc", "notes", "variant", "slot_base",
	"hidden_bones", "extra_meshes", "slot_parts", "fx", "portraits", "build"]
const BONE_ROLES: PackedStringArray = ["root", "pelvis", "spine_top", "neck", "head", "hand_l", "hand_r", "foot_l", "foot_r"]
const DEFAULT_CHEAT := {"idle": 35.0, "walk": 20.0, "perform": 35.0, "face_to_face": 5.0}

## Data roots searched in order (tests append their fixture root).
static var search_roots: PackedStringArray = ["res://data"]
static var _cache: Dictionary = {}
static var _pip_logged: bool = false


## A named socket: a point on a bone (metres, bone space) with an optional rotation (degrees, XYZ Euler).
class Socket extends RefCounted:
	var name: String = ""
	var bone: String = ""
	var pos: Vector3 = Vector3.ZERO
	var rot_deg: Vector3 = Vector3.ZERO

	## The socket's transform in its bone's space.
	func local_xf() -> Transform3D:
		var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
		return Transform3D(b, pos)


## A bone-driven prop (`props.<id>`): its mesh is weighted to `bone`; `states` map a state to a socket name
## or `"hidden"`; the default state's socket is the prop's HOME (no override there: the clip drives the bone).
class Prop extends RefCounted:
	var id: String = ""
	var bone: String = ""
	var states: Dictionary = {}          ## state -> socket name | "hidden"
	var default_state: String = "shown"
	var home_socket: String = ""         ## socket of the default state ("" = the bone's own rest parent)
	var hides: PackedStringArray = PackedStringArray()   ## props hidden while this one shows (specs ↔ specs_dangling)


## An attachment (`attachments.<id>`): a scene instanced once at setup on a bone (BoneAttachment3D), toggled.
class Attachment extends RefCounted:
	var id: String = ""
	var scene: String = ""
	var bone: String = ""
	var socket: String = ""              ## optional: sit on a socket instead of the bone origin
	var pos: Vector3 = Vector3.ZERO
	var rot_deg: Vector3 = Vector3.ZERO
	var visible_default: bool = false
	var soft: bool = false               ## another task's scene: missing = a warning, the attachment is skipped
	## Optional: the palette texture the scene was built on (a set / props glb keeps it; default: derived, see
	## RigPlayer3D._set_piece_palette).
	var palette: String = ""


## A jiggle group (`jiggle[]`): one SpringBoneSimulator3D setting per bone chain.
class JiggleGroup extends RefCounted:
	var bones: PackedStringArray = PackedStringArray()
	var stiffness: float = 3.0
	var drag: float = 0.4
	var gravity: float = 0.3
	var radius: float = 0.05
	var clamp_deg: float = 30.0
	var tip_m: float = 0.08              ## extended end length for a single-bone chain


## A look (`looks.<id>`): ops applied while it is on.
class Look extends RefCounted:
	var id: String = ""
	var show: PackedStringArray = PackedStringArray()
	var hide: PackedStringArray = PackedStringArray()
	var hide_bones: PackedStringArray = PackedStringArray()
	var params: Dictionary = {}          ## material uniform -> value
	var swap: Dictionary = {}            ## slot -> variant
	var face: Dictionary = {}            ## face layer -> cell while on (`face_extra`: FRAZZLED's singe marks)


## One body-slot variant: the attachments it shows, bones it hides, uniforms it sets (a plain `"<attachment>"` or
## `null` in the descriptor is the common case).
class SlotVariant extends RefCounted:
	var name: String = ""
	var show: PackedStringArray = PackedStringArray()
	var hide_bones: PackedStringArray = PackedStringArray()
	var params: Dictionary = {}


var rig_id: String = ""
var variant: String = ""
var path: String = ""
var raw: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()

var scene_path: String = ""
var skeleton_path: String = "Armature/Skeleton3D"
var mesh_path: String = ""
var height_m: float = 1.6
var head_scale: float = 1.0
var tris: int = 0
var deform_bones: int = 0
## role -> bone name (`bones`).
var bones: Dictionary = {}
var sockets: Dictionary = {}            ## name -> Socket
var props: Dictionary = {}              ## id -> Prop
var prop_order: PackedStringArray = PackedStringArray()
var attachments: Dictionary = {}        ## id -> Attachment
var attachment_order: PackedStringArray = PackedStringArray()
var slots: Dictionary = {}              ## slot -> {variant -> SlotVariant}
var slot_default: Dictionary = {}       ## slot -> variant name (the first `null` variant, else the first)
var slot_hide_bones: Dictionary = {}    ## slot -> PackedStringArray: base-mesh bones hidden while a non-default variant shows
## Bones at scale ≈ 0 unless the playing clip animates their scale (`hidden_bones`: FX / prop bones).
var default_hidden_bones: PackedStringArray = PackedStringArray()
var anim_layers: PackedStringArray = PackedStringArray()
var jiggle: Array[JiggleGroup] = []
var looks: Dictionary = {}              ## id -> Look

var face_atlas: String = ""
var face_atlas_px: int = 1024
var face_grid: Vector2i = Vector2i(8, 8)
var face_layers: PackedStringArray = PackedStringArray()
var face_rects: Dictionary = {}         ## layer -> Vector4 (u0, v0, u1, v1) in face-card UV
var face_cells: Dictionary = {}         ## layer -> {cell name -> index}
var pupil_range: Vector2 = Vector2(0.05, 0.03)
var presets_path: String = ""
var presets: Dictionary = {}            ## preset -> {layer -> cell name | "none"}
var gaze: Dictionary = {}               ## preset -> Vector2 (resting pupil offset, −1..1)
var blink_every_s: Vector2 = Vector2(2.0, 6.0)
var blink_frames: int = 6
var blink_cell: String = "closed"
var blink_half_cell: String = "half"
var blinkable: PackedStringArray = PackedStringArray()
var blink_hide_layers: PackedStringArray = PackedStringArray(["pupils", "lids"])
var face_default: String = "neutral"
var mirror_pupil_x: bool = true         ## a preset's gaze x flips with facing (2D art space semantics)
var no_pupils: PackedStringArray = PackedStringArray()   ## eyes cells that hide the pupils (closed, happy …)
var mirror_cells: Dictionary = {}       ## "layer/cell" -> cell (facing −1)

var palette: String = ""
var outline_px: float = View3DConst.OUTLINE_CHAR_PX   ## D7: the character outline width when the descriptor names none
var rim: float = 0.45
var vertex_color: Dictionary = {}
var tint_tiers: Array[Color] = [Color.WHITE]
var tint_livid: Color = Color("#B8324B")
## The skin's reference colour the tier multiply colours apply to (`tint.skin`; char_toon mixes toward the result).
var tint_skin: Color = Color("#E9B79A")
var tint_scale_bones: PackedStringArray = PackedStringArray()
var tint_livid_specs: String = "on"
var tint_bone_scale: PackedFloat32Array = PackedFloat32Array()
var stone_color: Color = Color("#E8E6E1")
var cheat: Dictionary = DEFAULT_CHEAT.duplicate()
var blob_shadow_r: float = 0.34
var skins: Dictionary = {}

## From the scene (validation / the headless sampler).
var bone_names: PackedStringArray = PackedStringArray()
var bone_parent: PackedInt32Array = PackedInt32Array()
var bone_rest: Array[Transform3D] = []


## Loads (cached) and validates `rig3d.json` / `rig3d_<variant>.json` of `rig_id`. Never null: a missing file
## returns a def whose `errors` say so.
static func load(rig_id: String, variant := "") -> RigDef3D:
	var v := variant
	if v == "pip":
		if not _pip_logged:
			_pip_logged = true
			print("[RigDef3D] skin 'pip' is not built in R3D (ruling R7) — %s loads its base descriptor" % rig_id)
		v = ""
	var key := "%s|%s" % [rig_id, v]
	if _cache.has(key):
		return _cache[key]
	var file := "rig3d.json" if v == "" else "rig3d_%s.json" % v
	var p := find_file("rigs3d/%s/%s" % [rig_id, file])
	var def := RigDef3D.new()
	def.rig_id = rig_id
	def.variant = v
	if p == "":
		def.path = "rigs3d/%s/%s" % [rig_id, file]
		def.errors.append("%s: file not found in %s" % [def.path, ", ".join(search_roots)])
	else:
		def.load_path(p)
	_cache[key] = def
	return def


## True when a descriptor for `rig_id` (and `variant`) exists under a search root.
static func exists(rig_id: String, variant := "") -> bool:
	var file := "rig3d.json" if variant == "" or variant == "pip" else "rig3d_%s.json" % variant
	return find_file("rigs3d/%s/%s" % [rig_id, file]) != ""


## The first search root that has `rel` (e.g. "rigs3d/hush/rig3d.json"), as a full path; "" when none.
static func find_file(rel: String) -> String:
	for r in search_roots:
		var p := "%s/%s" % [r, rel]
		if FileAccess.file_exists(p):
			return p
	return ""


## Forget cached descriptors (hot reload, tests).
static func invalidate(rig_id := "") -> void:
	if rig_id == "":
		_cache.clear()
		return
	for k in _cache.keys():
		if String(k).begins_with(rig_id + "|"):
			_cache.erase(k)


## Parses and validates the descriptor at `p` (a res:// or user:// path).
func load_path(p: String) -> void:
	path = p
	var j := JSON.new()
	if not FileAccess.file_exists(p):
		errors.append("%s: file not found" % p)
		return
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
		errors.append("%s: invalid JSON (line %d: %s)" % [p, j.get_error_line(), j.get_error_message()])
		return
	parse(j.data as Dictionary)


## Parses a descriptor dictionary (tests call it directly) and validates it (incl. the scene's bones).
func parse(d: Dictionary) -> void:
	raw = d
	if rig_id == "":
		rig_id = String(d.get("rig", ""))
	elif d.has("rig") and String(d["rig"]) != rig_id:
		_err("rig", "is '%s', expected '%s'" % [d["rig"], rig_id])
	for k in d.keys():
		if not KNOWN_KEYS.has(String(k)):
			_warn(String(k), "unknown key")
	scene_path = String(d.get("scene", ""))
	skeleton_path = String(d.get("skeleton", skeleton_path))
	mesh_path = String(d.get("mesh", ""))
	height_m = float(d.get("height_m", height_m))
	head_scale = float(d.get("head_scale", 1.0))
	tris = int(d.get("tris", 0))
	deform_bones = int(d.get("deform_bones", 0))
	if scene_path == "":
		_err("scene", "missing")
	elif not ResourceLoader.exists(scene_path):
		_err("scene", "'%s' does not exist" % scene_path)
	_parse_bones(d)
	_parse_sockets(d)
	_parse_props(d)
	_parse_attachments(d)
	_parse_slots(d)
	_parse_looks(d)
	_parse_jiggle(d)
	_parse_face(d)
	_parse_misc(d)
	_read_scene_bones()
	_validate_bones()


## True when the descriptor loaded without errors.
func is_valid() -> bool:
	return errors.is_empty()


## The bone a role names (`bones.<role>`), else `fallback`.
func bone(role: String, fallback := "") -> String:
	return String(bones.get(role, fallback))


## Index of `bone_name` in the scene skeleton (−1 when absent).
func bone_index(bone_name: String) -> int:
	return bone_names.find(bone_name)


## Cell index of `cell` in face `layer` (−1 when unknown or "none").
func cell_index(layer: String, cell: String) -> int:
	if cell == "" or cell == "none":
		return -1
	var cells: Dictionary = face_cells.get(layer, {})
	return int(cells.get(cell, -1))


## The mirrored cell name of `cell` in `layer` (facing −1), or `cell` itself.
func mirrored(layer: String, cell: String) -> String:
	var k := "%s/%s" % [layer, cell]
	if mirror_cells.has(k):
		return String(mirror_cells[k])
	if mirror_cells.has(cell):
		var m := String(mirror_cells[cell])
		if (face_cells.get(layer, {}) as Dictionary).has(m):
			return m
	return cell


## The tint colour of temper tier `tier` (0–3; 4 = livid).
func tint_color(tier: int) -> Color:
	if tier >= tint_tiers.size():
		return tint_livid
	return tint_tiers[clampi(tier, 0, tint_tiers.size() - 1)]


## Cheat-out yaw (degrees) for a staging kind: idle | walk | perform | face_to_face.
func cheat_deg(kind: String) -> float:
	return float(cheat.get(kind, DEFAULT_CHEAT.get(kind, 0.0)))


# --- parsing ----------------------------------------------------------------------------------------------------

func _parse_bones(d: Dictionary) -> void:
	var b: Variant = d.get("bones", {})
	if not (b is Dictionary):
		_err("bones", "must be an object")
		return
	for k in (b as Dictionary):
		bones[String(k)] = String((b as Dictionary)[k])
	for role in ["root", "pelvis", "head"]:
		if not bones.has(role):
			_warn("bones.%s" % role, "missing (defaults to the UAL name)")
	if not bones.has("root"):
		bones["root"] = "root"
	if not bones.has("pelvis"):
		bones["pelvis"] = "pelvis"
	if not bones.has("head"):
		bones["head"] = "Head"


func _parse_sockets(d: Dictionary) -> void:
	var s: Variant = d.get("sockets", {})
	if not (s is Dictionary):
		_err("sockets", "must be an object")
		return
	for k in (s as Dictionary):
		var e: Variant = (s as Dictionary)[k]
		if not (e is Dictionary):
			_err("sockets.%s" % k, "must be an object")
			continue
		var so := Socket.new()
		so.name = String(k)
		so.bone = String((e as Dictionary).get("bone", ""))
		so.pos = _vec3((e as Dictionary).get("pos", [0, 0, 0]), "sockets.%s.pos" % k)
		so.rot_deg = _vec3((e as Dictionary).get("rot_deg", [0, 0, 0]), "sockets.%s.rot_deg" % k)
		if so.bone == "":
			_err("sockets.%s.bone" % k, "missing")
		sockets[so.name] = so


func _parse_props(d: Dictionary) -> void:
	var s: Variant = d.get("props", {})
	if not (s is Dictionary):
		_err("props", "must be an object")
		return
	for k in (s as Dictionary):
		var e: Variant = (s as Dictionary)[k]
		if not (e is Dictionary):
			_err("props.%s" % k, "must be an object")
			continue
		var pr := Prop.new()
		pr.id = String(k)
		pr.bone = String((e as Dictionary).get("bone", ""))
		if pr.bone == "":
			_err("props.%s.bone" % k, "missing")
		var st: Variant = (e as Dictionary).get("states", {})
		if st is Dictionary:
			for sk in (st as Dictionary):
				var target := String((st as Dictionary)[sk])
				pr.states[String(sk)] = target
				if target != "hidden" and not sockets.has(target):
					_err("props.%s.states.%s" % [k, sk], "socket '%s' does not exist" % target)
		elif st != null:
			_err("props.%s.states" % k, "must be an object")
		pr.states["hidden"] = "hidden"
		if not pr.states.has("shown"):
			pr.states["shown"] = ""
		pr.default_state = String((e as Dictionary).get("default", "shown"))
		if not pr.states.has(pr.default_state):
			_err("props.%s.default" % k, "state '%s' is not in states" % pr.default_state)
			pr.default_state = "shown"
		var hs := String(pr.states.get(pr.default_state, ""))
		pr.home_socket = "" if hs == "hidden" else hs
		pr.hides = _strs((e as Dictionary).get("hides", []))
		props[pr.id] = pr
		prop_order.append(pr.id)


func _parse_attachments(d: Dictionary) -> void:
	var s: Variant = d.get("attachments", {})
	if not (s is Dictionary):
		_err("attachments", "must be an object")
		return
	for k in (s as Dictionary):
		var e: Variant = (s as Dictionary)[k]
		if not (e is Dictionary):
			_err("attachments.%s" % k, "must be an object")
			continue
		var at := Attachment.new()
		at.id = String(k)
		var ed: Dictionary = e
		at.scene = String(ed.get("scene", ""))
		at.bone = String(ed.get("bone", ""))
		at.socket = String(ed.get("socket", ""))
		at.pos = _vec3(ed.get("pos", [0, 0, 0]), "attachments.%s.pos" % k)
		at.rot_deg = _vec3(ed.get("rot_deg", [0, 0, 0]), "attachments.%s.rot_deg" % k)
		at.visible_default = bool(ed.get("default", false))
		at.soft = bool(ed.get("soft", false))
		at.palette = String(ed.get("palette", ""))
		if at.palette != "" and not ResourceLoader.exists(at.palette) and not FileAccess.file_exists(at.palette):
			_err("attachments.%s.palette" % k, "'%s' does not exist" % at.palette)
		if at.scene == "":
			_err("attachments.%s.scene" % k, "missing")
		elif not ResourceLoader.exists(at.scene):
			if at.soft:
				_warn("attachments.%s.scene" % k, "'%s' does not exist yet (soft: skipped)" % at.scene)
			else:
				_err("attachments.%s.scene" % k, "'%s' does not exist" % at.scene)
		if at.socket != "":
			if not sockets.has(at.socket):
				_err("attachments.%s.socket" % k, "socket '%s' does not exist" % at.socket)
			elif at.bone == "":
				at.bone = (sockets[at.socket] as Socket).bone
		if at.bone == "":
			_err("attachments.%s.bone" % k, "missing")
		attachments[at.id] = at
		attachment_order.append(at.id)
	if attachments.size() > 4:
		_warn("attachments", "%d attachments (budget: ≤ 4 visible at once)" % attachments.size())


func _parse_slots(d: Dictionary) -> void:
	var s: Variant = d.get("slots", {})
	if not (s is Dictionary):
		_err("slots", "must be an object")
		return
	for sk in (s as Dictionary):
		var vars: Variant = (s as Dictionary)[sk]
		if not (vars is Dictionary) or (vars as Dictionary).is_empty():
			_err("slots.%s" % sk, "must be a non-empty object of variants")
			continue
		var out: Dictionary = {}
		var first := ""
		var first_null := ""
		for vk in (vars as Dictionary):
			var sv := SlotVariant.new()
			sv.name = String(vk)
			var spec: Variant = (vars as Dictionary)[vk]
			if spec == null:
				if first_null == "":
					first_null = sv.name
			elif spec is String:
				sv.show.append(String(spec))
			elif spec is Dictionary:
				sv.show = _strs((spec as Dictionary).get("show", []))
				sv.hide_bones = _strs((spec as Dictionary).get("hide_bones", []))
				var pv: Variant = (spec as Dictionary).get("params", {})
				sv.params = (pv as Dictionary) if pv is Dictionary else {}
			else:
				_err("slots.%s.%s" % [sk, vk], "must be null, an attachment id or an object")
			for a in sv.show:
				if not attachments.has(a):
					_err("slots.%s.%s" % [sk, vk], "attachment '%s' does not exist" % a)
			if first == "":
				first = sv.name
			out[sv.name] = sv
		slots[String(sk)] = out
		slot_default[String(sk)] = first_null if first_null != "" else first
	var sp: Variant = d.get("slot_parts", {})
	if sp is Dictionary:
		for sk2 in (sp as Dictionary):
			if not slots.has(String(sk2)):
				_err("slot_parts.%s" % sk2, "slot does not exist")
				continue
			var e2: Variant = (sp as Dictionary)[sk2]
			slot_hide_bones[String(sk2)] = _strs((e2 as Dictionary).get("hide_bones", [])) if e2 is Dictionary else PackedStringArray()
	default_hidden_bones = _strs(d.get("hidden_bones", []))


func _parse_looks(d: Dictionary) -> void:
	var s: Variant = d.get("looks", {})
	if not (s is Dictionary):
		_err("looks", "must be an object")
		return
	for k in (s as Dictionary):
		var e: Variant = (s as Dictionary)[k]
		if not (e is Dictionary):
			_err("looks.%s" % k, "must be an object")
			continue
		var lk := Look.new()
		lk.id = String(k)
		var ed: Dictionary = e
		lk.show = _strs(ed.get("show", []))
		lk.hide = _strs(ed.get("hide", []))
		lk.hide_bones = _strs(ed.get("hide_bones", []))
		var pv: Variant = ed.get("params", {})
		lk.params = (pv as Dictionary) if pv is Dictionary else {}
		var sw: Variant = ed.get("swap", {})
		if sw is Dictionary:
			for slot in (sw as Dictionary):
				var v := String((sw as Dictionary)[slot])
				lk.swap[String(slot)] = v
				if not slots.has(String(slot)):
					_err("looks.%s.swap.%s" % [k, slot], "slot does not exist")
				elif not (slots[String(slot)] as Dictionary).has(v):
					_err("looks.%s.swap.%s" % [k, slot], "variant '%s' does not exist" % v)
		for a in lk.show + lk.hide:
			if not attachments.has(a) and not props.has(a):
				_err("looks.%s" % k, "attachment '%s' does not exist" % a)
		var fe: Variant = ed.get("face_extra", {})
		if fe is Dictionary:
			for ln in (fe as Dictionary):
				lk.face[String(ln)] = String((fe as Dictionary)[ln])
		looks[lk.id] = lk


func _parse_jiggle(d: Dictionary) -> void:
	var s: Variant = d.get("jiggle", [])
	if not (s is Array):
		_err("jiggle", "must be an array")
		return
	var i := 0
	for e in s:
		if not (e is Dictionary):
			_err("jiggle[%d]" % i, "must be an object")
			i += 1
			continue
		var g := JiggleGroup.new()
		var ed: Dictionary = e
		g.bones = _strs(ed.get("bones", []))
		g.stiffness = float(ed.get("stiffness", g.stiffness))
		g.drag = float(ed.get("drag", g.drag))
		g.gravity = float(ed.get("gravity", g.gravity))
		g.radius = float(ed.get("radius", g.radius))
		g.clamp_deg = float(ed.get("clamp_deg", g.clamp_deg))
		g.tip_m = float(ed.get("tip_m", g.tip_m))
		if g.bones.is_empty():
			_err("jiggle[%d].bones" % i, "empty")
		jiggle.append(g)
		i += 1


func _parse_face(d: Dictionary) -> void:
	var fv: Variant = d.get("face", null)
	if fv == null:
		return
	if not (fv is Dictionary):
		_err("face", "must be an object")
		return
	var f: Dictionary = fv
	face_atlas = String(f.get("atlas", ""))
	if face_atlas != "" and not ResourceLoader.exists(face_atlas) and not FileAccess.file_exists(face_atlas):
		_err("face.atlas", "'%s' does not exist" % face_atlas)
	face_atlas_px = int(f.get("atlas_px", 1024))
	var g: Variant = f.get("grid", [8, 8])
	if g is Array and (g as Array).size() == 2:
		face_grid = Vector2i(maxi(1, int(g[0])), maxi(1, int(g[1])))
	else:
		_err("face.grid", "must be [cols, rows]")
	face_layers = _strs(f.get("layers", []))
	for ln in face_layers:
		if not FACE_LAYERS.has(ln):
			_err("face.layers", "unknown layer '%s' (known: %s)" % [ln, ", ".join(FACE_LAYERS)])
	var lr: Variant = f.get("layer_rects", {})
	if lr is Dictionary:
		for ln in (lr as Dictionary):
			var r: Variant = (lr as Dictionary)[ln]
			if r is Array and (r as Array).size() == 4:
				face_rects[String(ln)] = Vector4(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			else:
				_err("face.layer_rects.%s" % ln, "must be [u0, v0, u1, v1]")
	var n := face_grid.x * face_grid.y
	var cv: Variant = f.get("cells", {})
	if cv is Dictionary:
		for ln in (cv as Dictionary):
			var cells: Dictionary = {}
			var src: Variant = (cv as Dictionary)[ln]
			if not (src is Dictionary):
				_err("face.cells.%s" % ln, "must be an object")
				continue
			for cn in (src as Dictionary):
				var ci := int((src as Dictionary)[cn])
				if ci < 0 or ci >= n:
					_err("face.cells.%s.%s" % [ln, cn], "cell %d outside the %dx%d grid" % [ci, face_grid.x, face_grid.y])
				cells[String(cn)] = ci
			face_cells[String(ln)] = cells
			if not face_layers.has(String(ln)):
				face_layers.append(String(ln))
	var pr: Variant = f.get("pupil_range", [0.05, 0.03])
	if pr is Array and (pr as Array).size() == 2:
		pupil_range = Vector2(float(pr[0]), float(pr[1]))
	var bl: Variant = f.get("blink", {})
	if bl is Dictionary:
		var es: Variant = (bl as Dictionary).get("every_s", [2.0, 6.0])
		if es is Array and (es as Array).size() == 2:
			blink_every_s = Vector2(float(es[0]), float(es[1]))
		blink_frames = int((bl as Dictionary).get("frames", 6))
		blink_cell = String((bl as Dictionary).get("cell", "closed"))
		blink_half_cell = String((bl as Dictionary).get("half_cell", "half"))
		blinkable = _strs((bl as Dictionary).get("blinkable", []))
		if (bl as Dictionary).has("hide_layers"):
			blink_hide_layers = _strs((bl as Dictionary)["hide_layers"])
	no_pupils = _strs(f.get("no_pupils", ["closed", "half", "happy", "wink", "squint"]))
	var mc: Variant = f.get("mirror_cells", {})
	if mc is Dictionary:
		for k in (mc as Dictionary):
			var mv: Variant = (mc as Dictionary)[k]
			if mv is Dictionary:
				# Per layer: {"brows": {"one_up": "one_up_m"}}.
				for ck in (mv as Dictionary):
					mirror_cells["%s/%s" % [k, ck]] = String((mv as Dictionary)[ck])
			else:
				mirror_cells[String(k)] = String(mv)
	face_default = String(f.get("default", "neutral"))
	mirror_pupil_x = bool(f.get("mirror_pupil_x", true))
	presets_path = String(f.get("presets", ""))
	var inline: Variant = f.get("preset_table", null)
	if inline is Dictionary:
		_take_presets(inline as Dictionary, "face.preset_table")
	elif presets_path != "":
		if not FileAccess.file_exists(presets_path):
			_err("face.presets", "'%s' does not exist" % presets_path)
		else:
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(presets_path)) != OK or not (j.data is Dictionary):
				_err("face.presets", "'%s' is not valid JSON" % presets_path)
			else:
				var pd: Dictionary = j.data
				_take_presets((pd.get("presets", pd)) as Dictionary if pd.get("presets", pd) is Dictionary else {}, presets_path)
	_validate_presets()


func _take_presets(pd: Dictionary, where: String) -> void:
	for pn in pd:
		var e: Variant = pd[pn]
		if not (e is Dictionary):
			_err("%s.%s" % [where, pn], "must be an object")
			continue
		var cells: Dictionary = {}
		for ln in (e as Dictionary):
			var key := String(ln)
			if key == "gaze":
				var gz: Variant = (e as Dictionary)[ln]
				if gz is Array and (gz as Array).size() == 2:
					gaze[String(pn)] = Vector2(float(gz[0]), float(gz[1]))
				continue
			if key in ["temper", "doc", "tags", "desc"]:
				continue
			if key == "extra":
				key = "extra_a"
			cells[key] = String((e as Dictionary)[ln]) if (e as Dictionary)[ln] != null else "none"
		presets[String(pn)] = cells


func _validate_presets() -> void:
	for pn in presets:
		var cells: Dictionary = presets[pn]
		for ln in cells:
			var cn := String(cells[ln])
			if cn == "none" or cn == "":
				continue
			if not FACE_LAYERS.has(String(ln)):
				# A 2D-style overlay slot ("blush": "on"): fine when an extra layer has a cell of that name.
				if cell_index("extra_a", String(ln)) < 0 and cell_index("extra_b", String(ln)) < 0:
					_warn("face.presets.%s.%s" % [pn, ln], "not a face layer and no extra cell '%s'" % ln)
				continue
			if not face_cells.has(ln):
				_err("face.presets.%s.%s" % [pn, ln], "layer '%s' has no cells" % ln)
			elif not (face_cells[ln] as Dictionary).has(cn):
				_err("face.presets.%s.%s" % [pn, ln], "cell '%s' does not exist" % cn)
	if not face_cells.is_empty() and not presets.has(face_default):
		_warn("face.default", "no '%s' preset" % face_default)
	for lid in looks:
		var lk: Look = looks[lid]
		for ln in lk.face:
			var cn2 := String(lk.face[ln])
			if cn2 != "none" and cn2 != "" and cell_index(String(ln), cn2) < 0:
				_err("looks.%s.face_extra.%s" % [lid, ln], "cell '%s' does not exist" % cn2)
	for cn in blinkable:
		if face_cells.has("eyes") and not (face_cells["eyes"] as Dictionary).has(cn):
			_err("face.blink.blinkable", "eyes cell '%s' does not exist" % cn)
	if face_cells.has("eyes") and not (face_cells["eyes"] as Dictionary).has(blink_cell):
		_err("face.blink.cell", "eyes cell '%s' does not exist" % blink_cell)


func _parse_misc(d: Dictionary) -> void:
	var an: Variant = d.get("anim", {})
	if an is Dictionary:
		anim_layers = _strs((an as Dictionary).get("layers", []))
	var m: Variant = d.get("material", {})
	if m is Dictionary:
		palette = String((m as Dictionary).get("palette", ""))
		outline_px = float((m as Dictionary).get("outline_px", View3DConst.OUTLINE_CHAR_PX))
		rim = float((m as Dictionary).get("rim", 0.45))
		if palette != "" and not ResourceLoader.exists(palette) and not FileAccess.file_exists(palette):
			_err("material.palette", "'%s' does not exist" % palette)
	var vc: Variant = d.get("vertex_color", {})
	vertex_color = (vc as Dictionary) if vc is Dictionary else {}
	var t: Variant = d.get("tint", {})
	if t is Dictionary:
		var tiers: Variant = (t as Dictionary).get("tiers", ["#FFFFFF"])
		tint_tiers.clear()
		for c in (tiers if tiers is Array else []):
			tint_tiers.append(_color(c, "tint.tiers"))
		if tint_tiers.is_empty():
			tint_tiers.append(Color.WHITE)
		tint_livid = _color((t as Dictionary).get("livid", "#B8324B"), "tint.livid")
		tint_skin = _color((t as Dictionary).get("skin", "#E9B79A"), "tint.skin")
		var ss: Variant = (t as Dictionary).get("sideburn_scale", (t as Dictionary).get("bone_scale", []))
		if ss is Array:
			for x in ss:
				tint_bone_scale.append(float(x))
		tint_scale_bones = _strs((t as Dictionary).get("scale_bones", []))
		tint_livid_specs = String((t as Dictionary).get("livid_specs", "on"))
	var st: Variant = d.get("stone", {})
	if st is Dictionary:
		stone_color = _color((st as Dictionary).get("color", "#E8E6E1"), "stone.color")
	var ch: Variant = d.get("cheat", {})
	if ch is Dictionary:
		for k in (ch as Dictionary):
			cheat[String(k)] = float((ch as Dictionary)[k])
	blob_shadow_r = float(d.get("blob_shadow_r", blob_shadow_r))
	var sk: Variant = d.get("skins", {})
	skins = (sk as Dictionary) if sk is Dictionary else {}


## Reads the skeleton's bone names / parents / rests from the scene (instanced once, freed).
func _read_scene_bones() -> void:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var ps := ResourceLoader.load(scene_path) as PackedScene
	if ps == null:
		_err("scene", "'%s' is not a scene" % scene_path)
		return
	var inst := ps.instantiate()
	var sk := inst.get_node_or_null(NodePath(skeleton_path)) as Skeleton3D
	if sk == null:
		sk = _find_skeleton(inst)
		if sk != null:
			_warn("skeleton", "'%s' not found; using '%s'" % [skeleton_path, inst.get_path_to(sk)])
			skeleton_path = String(inst.get_path_to(sk))
	if sk == null:
		_err("skeleton", "no Skeleton3D in '%s'" % scene_path)
	else:
		for i in sk.get_bone_count():
			bone_names.append(sk.get_bone_name(i))
			bone_parent.append(sk.get_bone_parent(i))
			bone_rest.append(sk.get_bone_rest(i))
		if mesh_path != "" and inst.get_node_or_null(NodePath(mesh_path)) == null:
			_err("mesh", "'%s' not found in the scene" % mesh_path)
	inst.free()


func _validate_bones() -> void:
	if bone_names.is_empty():
		return
	for role in bones:
		_need_bone(String(bones[role]), "bones.%s" % role)
	for sn in sockets:
		_need_bone((sockets[sn] as Socket).bone, "sockets.%s.bone" % sn)
	for pid in props:
		_need_bone((props[pid] as Prop).bone, "props.%s.bone" % pid)
	for aid in attachments:
		_need_bone((attachments[aid] as Attachment).bone, "attachments.%s.bone" % aid)
	var gi := 0
	for g in jiggle:
		for b in g.bones:
			_need_bone(b, "jiggle[%d].bones" % gi)
		gi += 1
	for lid in looks:
		for b in (looks[lid] as Look).hide_bones:
			_need_bone(b, "looks.%s.hide_bones" % lid)
	for sl in slots:
		for vn in slots[sl]:
			for b in (slots[sl][vn] as SlotVariant).hide_bones:
				_need_bone(b, "slots.%s.%s.hide_bones" % [sl, vn])
	for b in tint_scale_bones:
		_need_bone(b, "tint.scale_bones")
	for b in default_hidden_bones:
		_need_bone(b, "hidden_bones")
	for sl2 in slot_hide_bones:
		for b in slot_hide_bones[sl2]:
			_need_bone(b, "slot_parts.%s.hide_bones" % sl2)
	for pid2 in props:
		for h in (props[pid2] as Prop).hides:
			if not props.has(h):
				_err("props.%s.hides" % pid2, "prop '%s' does not exist" % h)


func _need_bone(b: String, key: String) -> void:
	if b != "" and not bone_names.has(b):
		_err(key, "bone '%s' does not exist in the skeleton" % b)


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


func _err(key: String, what: String) -> void:
	errors.append("%s: %s: %s" % [path if path != "" else "rig3d(%s)" % rig_id, key, what])


func _warn(key: String, what: String) -> void:
	warnings.append("%s: %s: %s" % [path if path != "" else "rig3d(%s)" % rig_id, key, what])


func _vec3(v: Variant, key: String) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	_err(key, "must be [x, y, z]")
	return Vector3.ZERO


func _color(v: Variant, key: String) -> Color:
	var s := String(v) if v != null else ""
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color(s)
	_err(key, "'%s' is not a #RRGGBB colour" % s)
	return Color.WHITE


static func _strs(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array or v is PackedStringArray:
		for x in v:
			out.append(String(x))
	elif v is String and String(v) != "":
		out.append(String(v))
	return out
