## CharStandIn3D — the counted stand-in when a character's rig fails to set up (a missing / broken descriptor or
## scene): a capsule body and a sphere head in the character's two main colours at the right height, on the CHAR
## visual layer, so the Night still plays. The view counts it as a "puppet" (`fallback_counts().puppets`).
## The colours come from the descriptor's `skins.stand_in` ([body, head]) when present, else per rig.
class_name CharStandIn3D
extends Node3D

const COLOURS := {
	"hush": [Color("#23284A"), Color("#F3EDE2")],
	"bellows": [Color("#6B3A6E"), Color("#E9B79A")],
}
const CHAR_LAYER_BITS := 2

var rig_id: String = ""
var height_m: float = 1.6


## Builds the capsule for `rig` at `height` metres (feet at the origin).
func build(rig: String, height: float, colours: Array = []) -> void:
	rig_id = rig
	height_m = maxf(0.4, height)
	name = "StandIn_%s" % rig
	var cols: Array = colours if colours.size() >= 2 else COLOURS.get(rig, [Color("#7A7A8C"), Color("#E0DCD2")])
	var head_r := height_m * 0.14
	var body_h := height_m - head_r * 2.0
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = height_m * 0.16
	cap.height = body_h
	body.mesh = cap
	body.position = Vector3(0, body_h * 0.5, 0)
	body.material_override = _mat(cols[0])
	body.layers = CHAR_LAYER_BITS
	add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sph := SphereMesh.new()
	sph.radius = head_r
	sph.height = head_r * 2.0
	head.mesh = sph
	head.position = Vector3(0, body_h + head_r * 0.9, 0)
	head.material_override = _mat(cols[1])
	head.layers = CHAR_LAYER_BITS
	add_child(head)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m
