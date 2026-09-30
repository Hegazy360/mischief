## RoomShell3D — one built room's architecture (REDESIGN_3D §3.2 layer 1, §3.5, §5.1): the back wall as one flat
## colour field, one wainscot band (≈ 9 L* darker, 0.9 m) and one picture rail (2.2 m), plain two-tone floor boards,
## and the room's built-ins (kitchen counters + sink unit, fireplace + mantel, the stairs, the front door flat) from
## `house3d.json rooms.<id>`. Low contrast, no outline, no glow. When the room's `arch` .glb exists it replaces the
## greybox (the built-in boxes stay the collision data either way). One SetMats group = the room's lighting group.
class_name RoomShell3D
extends Node3D

const WALL_T := 0.1
const BOARD_ROWS := 6

var room_id: String = ""
var x0: float = 0.0
var x1: float = 0.0
var def: Dictionary = {}
var mats: SetMats = null
## Built-in id → OBB dictionary (SetGeo) for the collision test.
var solids: Dictionary = {}
var _from_glb: bool = false


## Builds the shell of `p_room` spanning x0…x1 (metres) from its house3d.json room block. `built` = hotspot id →
## true for tonight's built hotspots: a built-in with `"with": <hotspot>` (a prop's own shelf) is built only then.
func setup(p_room: String, p_x0: float, p_x1: float, p_def: Dictionary, stage: Dictionary, built: Dictionary = {}) -> void:
	room_id = p_room
	name = "Room_" + p_room
	x0 = p_x0
	x1 = p_x1
	def = p_def.duplicate(true)
	var bis0: Dictionary = def.get("built_ins", {})
	for bid in bis0.keys():
		var w := SetGeo.s((bis0[bid] as Dictionary).get("with", ""))
		if w != "" and not built.has(w):
			bis0.erase(bid)
	var pal: Texture2D = null
	var pal_path := SetGeo.s(def.get("palette", ""))
	if pal_path != "" and ResourceLoader.exists(pal_path):
		pal = load(pal_path) as Texture2D
	mats = SetMats.new(p_room, null)
	mats.room_color = SetGeo.color(def.get("wall", null))
	var arch := SetGeo.s(def.get("arch", ""))
	if arch != "" and ResourceLoader.exists(arch):
		_from_glb = _build_glb(arch, pal)
	if not _from_glb:
		_build_greybox(stage)
	for bid in (def.get("built_ins", {}) as Dictionary).keys():
		var bd: Dictionary = def["built_ins"][bid]
		var b: Array = bd.get("box", [0, 0, 0, 0, 0, 0])
		if bd.has("leaf"):
			# a door flat: solid behind and in front of the doorway; the leaf opens (the lane passes through)
			var lf: Array = bd["leaf"]
			solids[bid + "_back"] = SetGeo.obb_from_box([b[0], b[1], b[2], b[3], b[4], lf[2]])
			solids[bid + "_front"] = SetGeo.obb_from_box([b[0], b[1], lf[5], b[3], b[4], b[5]])
		else:
			solids[bid] = SetGeo.obb_from_box(b)


## True when the room came from its .glb (not the greybox).
func from_glb() -> bool:
	return _from_glb


func _build_glb(path: String, pal: Texture2D) -> bool:
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return false
	inst.name = "Arch"
	add_child(inst)
	var any := false
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var tex := pal
		if tex == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var sm := mi.mesh.surface_get_material(0)
			if sm is BaseMaterial3D:
				tex = (sm as BaseMaterial3D).albedo_texture
		mi.material_override = mats.tex_mat(tex, &"set")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		any = true
	return any


func _build_greybox(stage: Dictionary) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var back_z := -2.4
	var room_h := 3.2
	var wall := SetGeo.color(def.get("wall", null))
	var wains := SetGeo.color(def.get("wainscot", null), wall.darkened(0.12))
	var rail := SetGeo.color(def.get("rail", null), wains)
	var floors: Array = def.get("floor", ["#8A6C54", "#83644D"])
	var outdoor := bool(def.get("outdoor", false))
	# back wall (a flat field; the porch's is the sky flat)
	SetPrims._box(self, Vector3(w, room_h, WALL_T), Vector3(cx, room_h * 0.5, back_z - WALL_T * 0.5), mats.get_mat(wall, &"set"), 0.0, "back_wall")
	var wh := float(def.get("wainscot_h_m", 0.9))
	if wh > 0.0:
		SetPrims._box(self, Vector3(w, wh, 0.03), Vector3(cx, wh * 0.5, back_z + 0.015), mats.get_mat(wains, &"set"), 0.0, "wainscot")
	var rh := float(def.get("rail_h_m", 2.2))
	if rh > 0.0:
		SetPrims._box(self, Vector3(w, 0.05, 0.04), Vector3(cx, rh, back_z + 0.02), mats.get_mat(rail, &"set"), 0.0, "rail")
	# floor: plain boards in two tones, running along x (the stage floor), from the back wall to the lip
	var lip_z := float(stage.get("lip_z", 0.25))
	var depth := lip_z - back_z
	for i in BOARD_ROWS:
		var zb := back_z + depth * float(i) / BOARD_ROWS
		var col := SetGeo.color(floors[i % floors.size()])
		SetPrims._box(self, Vector3(w, 0.04, depth / BOARD_ROWS), Vector3(cx, -0.02, zb + depth / BOARD_ROWS * 0.5), mats.get_mat(col, &"set"), 0.0, "floor_%d" % i)
	if outdoor:
		SetPrims._box(self, Vector3(w, 0.9, 0.04), Vector3(cx, 0.45, back_z + 0.05), mats.get_mat(wains, &"set"), 0.0, "sky_low")
	# built-ins
	var bis: Dictionary = def.get("built_ins", {})
	for bid in bis.keys():
		_build_builtin(String(bid), bis[bid])


func _build_builtin(bid: String, bd: Dictionary) -> void:
	var b: Array = bd.get("box", [0, 0, 0, 0, 0, 0])
	var lo := Vector3(float(b[0]), float(b[1]), float(b[2]))
	var hi := Vector3(float(b[3]), float(b[4]), float(b[5]))
	var col := SetGeo.color(bd.get("color", null))
	var m := mats.get_mat(col, &"set")
	if bd.has("basin"):
		# a counter with a sunk basin: the counter as four blocks around the hollow + the basin's floor
		var bs: Array = bd["basin"]
		var blo := Vector3(float(bs[0]), float(bs[1]), float(bs[2]))
		var bhi := Vector3(float(bs[3]), float(bs[4]), float(bs[5]))
		_block(lo, Vector3(hi.x, blo.y, hi.z), m, bid + "_base")
		_block(Vector3(lo.x, blo.y, lo.z), Vector3(blo.x, hi.y, hi.z), m, bid + "_l")
		_block(Vector3(bhi.x, blo.y, lo.z), Vector3(hi.x, hi.y, hi.z), m, bid + "_r")
		_block(Vector3(blo.x, blo.y, lo.z), Vector3(bhi.x, hi.y, blo.z), m, bid + "_back")
		_block(Vector3(blo.x, blo.y, bhi.z), Vector3(bhi.x, hi.y, hi.z), m, bid + "_front")
		_block(Vector3(blo.x, blo.y, blo.z), Vector3(bhi.x, blo.y + 0.02, bhi.z), mats.get_mat(Color("#D9DEE2"), &"set"), bid + "_basin")
		return
	if bd.has("firebox"):
		var fb: Array = bd["firebox"]
		var flo := Vector3(float(fb[0]), float(fb[1]), float(fb[2]))
		var fhi := Vector3(float(fb[3]), float(fb[4]), float(fb[5]))
		_block(lo, Vector3(flo.x, hi.y, hi.z), m, bid + "_l")
		_block(Vector3(fhi.x, lo.y, lo.z), hi, m, bid + "_r")
		_block(Vector3(flo.x, fhi.y, lo.z), Vector3(fhi.x, hi.y, hi.z), m, bid + "_top")
		_block(Vector3(flo.x, lo.y, lo.z), Vector3(fhi.x, fhi.y, flo.z), mats.get_mat(Color("#2A2230"), &"set"), bid + "_back")
		return
	if bd.has("steps"):
		var n := int(bd["steps"])
		for i in n:
			var zf := hi.z - (hi.z - lo.z) * float(i) / n
			_block(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y + (hi.y - lo.y) * float(i + 1) / n, zf), m, "%s_%d" % [bid, i])
		# the dark into which the stairs rise
		_block(Vector3(lo.x, 0.0, -2.42), Vector3(hi.x, 2.2, -2.39), mats.get_mat(Color("#1A1522"), &"set"), bid + "_dark")
		return
	if bd.has("leaf"):
		var lf: Array = bd["leaf"]
		var llo := Vector3(float(lf[0]), float(lf[1]), float(lf[2]))
		var lhi := Vector3(float(lf[3]), float(lf[4]), float(lf[5]))
		_block(lo, Vector3(hi.x, hi.y, llo.z), m, bid + "_back")
		_block(Vector3(lo.x, lo.y, lhi.z), hi, m, bid + "_front")
		_block(Vector3(lo.x, lhi.y, llo.z), Vector3(hi.x, hi.y, lhi.z), m, bid + "_lintel")
		var leaf := _block(llo, lhi, mats.get_mat(SetGeo.color(bd.get("leaf_color", null)), &"set"), bid + "_leaf")
		leaf.set_meta("door_leaf", true)
		return
	_block(lo, hi, m, bid)


func _block(lo: Vector3, hi: Vector3, m: Material, nm: String) -> MeshInstance3D:
	return SetPrims._box(self, (hi - lo).abs(), (lo + hi) * 0.5, m, 0.0, nm)


## Room light for the whole shell (House3D tweens it).
func set_light(level: float, desat: float) -> void:
	mats.set_light(level, desat)
