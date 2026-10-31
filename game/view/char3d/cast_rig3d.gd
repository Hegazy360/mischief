## CastRig3D — the 3D rig descriptor for one character (REDESIGN_3D §5.6, §5.7).
##
## Loads `res://art3d/cast/<rig>.rig3d.json` (written by tools/art3d/cast/build_cast.py) and
## `res://art3d/cast/face_<rig>.json` (the face atlas map), and resolves both into the lookup
## tables the runtime needs every frame. Pure data: no nodes, no scene tree, so it is cheap to
## build in a test and shared between every Character3D of the same rig.
##
## The important field is `fk_map`: the 2D clip channel -> the 3D bones that replay it. The cast's
## 236 authored poses and 34 lint-checked clips in `game/data/{rigs,anim}/**` are plain humanoid
## FK (one Z rotation per joint), so a skeleton shaped to match replays all of them unchanged —
## that is the whole reason this rig exists rather than a library skeleton (see
## tools/art3d/cast/mnd_rig.py for the argument).
class_name CastRig3D
extends RefCounted

const DIR := "res://art3d/cast/"

var rig_id := ""
var height_m := 1.6
## The .glb's own height in its authoring units. Library characters (KayKit) are not modelled in
## metres, so the runtime scales each one by height_m / model_height_u to put it on stage at the
## size REDESIGN_3D §5.6 asks for. 0 = already metric, no scaling.
var model_height_u := 0.0
## Sagittal rotation axis in Godot space: a 2D clip angle is a rotation about this.
var fk_axis := Vector3(0, 0, 1)
## 2D channel name -> [bone names]. A channel listed against several bones is split by `splits`.
var fk_map := {}
## channel -> {bone: weight}; weights sum to 1 (a 2D "torso" hinge spread over spine + chest).
var splits := {}
## [{bone, parent, stiffness, damping, max_deg}]
var jiggle: Array[Dictionary] = []
## chain name -> {upper, lower, tip, bend}
var ik := {}
var feet: PackedStringArray = []
var toes: PackedStringArray = []
var sockets: PackedStringArray = []
var mesh_path := ""
var tris := 0
var bone_count := 0

## Face atlas: layer -> {band: Vector2, cell_uv: Vector2, origin: Vector2, per_row: int, cells: [name]}
var face_layers := {}
## preset name -> {layer: cell name}
var face_presets := {}
var face_atlas_path := ""

var _errors: PackedStringArray = []


## Load `<rig>.rig3d.json` + its face atlas. Returns null and pushes an error when either is
## missing or malformed — the caller falls back to a greybox puppet rather than crashing a Night.
static func load_rig(rig: String) -> CastRig3D:
	var r := CastRig3D.new()
	r.rig_id = rig
	var desc_path := DIR + rig + ".rig3d.json"
	var d := _read_json(desc_path)
	if d.is_empty():
		push_error("CastRig3D: cannot read %s" % desc_path)
		return null
	r.height_m = float(d.get("height_m", 1.6))
	r.model_height_u = float(d.get("model_height_u", 0.0))
	var ax: Array = d.get("fk_axis", [0, 0, 1])
	r.fk_axis = Vector3(ax[0], ax[1], ax[2]).normalized()
	r.tris = int(d.get("tris", 0))
	r.bone_count = int(d.get("bones", 0))
	r.mesh_path = DIR + rig + ".glb"

	for ch in d.get("fk_map", {}):
		var bones: Array = (d["fk_map"] as Dictionary)[ch]
		r.fk_map[ch] = PackedStringArray(bones)
	for ch in d.get("splits", {}):
		r.splits[ch] = (d["splits"] as Dictionary)[ch]
	for j in d.get("jiggle", []):
		r.jiggle.append({
			"bone": String(j.get("bone", "")),
			"parent": String(j.get("parent", "")),
			"stiffness": float(j.get("stiffness", 140.0)),
			"damping": float(j.get("damping", 0.6)),
			"max_deg": float(j.get("max_deg", 15.0)),
		})
	for name in d.get("ik", {}):
		var c: Dictionary = (d["ik"] as Dictionary)[name]
		var b: Array = c.get("bend", [1, 0, 0])
		r.ik[name] = {
			"upper": String(c.get("upper", "")),
			"lower": String(c.get("lower", "")),
			"tip": String(c.get("tip", "")),
			"bend": Vector3(b[0], b[1], b[2]).normalized(),
		}
	r.feet = PackedStringArray(d.get("feet", []))
	r.toes = PackedStringArray(d.get("toes", []))
	r.sockets = PackedStringArray(d.get("sockets", []))

	r._load_face(String((d.get("face", {}) as Dictionary).get("atlas", "face_%s.png" % rig)))
	return r


func _load_face(atlas_png: String) -> void:
	face_atlas_path = DIR + atlas_png
	var jpath := DIR + "face_%s.json" % rig_id
	var d := _read_json(jpath)
	if d.is_empty():
		_errors.append("no face atlas map at %s" % jpath)
		return
	var size := float(d.get("atlas", 1024))
	for name in d.get("layers", {}):
		var L: Dictionary = (d["layers"] as Dictionary)[name]
		var band: Array = L.get("band", [0.0, 1.0])
		var origin: Array = L.get("origin_px", [0, 0])
		var cell: Array = L.get("cell_px", [1, 1])
		face_layers[name] = {
			"band": Vector2(band[0], band[1]),
			"origin": Vector2(origin[0] / size, origin[1] / size),
			"cell_uv": Vector2(cell[0] / size, cell[1] / size),
			"per_row": int(L.get("per_row", 3)),
			"cells": PackedStringArray(L.get("cells", [])),
		}
	for p in d.get("presets", {}):
		face_presets[p] = (d["presets"] as Dictionary)[p]


## The atlas rect (origin.x, origin.y, size.x, size.y) of `cell` in `layer`, as the shader wants it.
## Returns a zero-width rect for an unknown layer or cell, which the shader reads as "draw nothing".
func face_cell(layer: String, cell: String) -> Vector4:
	if not face_layers.has(layer):
		return Vector4.ZERO
	var L: Dictionary = face_layers[layer]
	var cells: PackedStringArray = L["cells"]
	var idx := cells.find(cell)
	if idx < 0:
		return Vector4.ZERO
	var per_row: int = maxi(1, L["per_row"])
	var o: Vector2 = L["origin"]
	var c: Vector2 = L["cell_uv"]
	var col := idx % per_row
	var row := idx / per_row
	return Vector4(o.x + col * c.x, o.y + row * c.y, c.x, c.y)


## The band (v0, v1) of `layer` inside the face square.
func face_band(layer: String) -> Vector2:
	if not face_layers.has(layer):
		return Vector2(0, 1)
	return (face_layers[layer] as Dictionary)["band"]


## Bones a 2D channel drives, with the weight each takes of the channel's angle.
func channel_bones(channel: String) -> Dictionary:
	if not fk_map.has(channel):
		return {}
	var bones: PackedStringArray = fk_map[channel]
	var out := {}
	if splits.has(channel):
		var s: Dictionary = splits[channel]
		for b in bones:
			out[b] = float(s.get(b, 1.0 / maxi(1, bones.size())))
	else:
		for b in bones:
			out[b] = 1.0 / float(maxi(1, bones.size()))
	return out


## Uniform scale that puts this character on stage at its design height.
func stage_scale() -> float:
	if model_height_u <= 0.01:
		return 1.0
	return height_m / model_height_u


func errors() -> PackedStringArray:
	return _errors


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
