## CompileProbe — a rendered probe (not a test file): does Godot 4.7.2's Compatibility renderer report shader /
## pipeline compilations through `RenderingServer.get_rendering_info(RENDERING_INFO_PIPELINE_COMPILATIONS_*)` or
## the `Performance.PIPELINE_COMPILATIONS_*` monitors? It draws a plain scene, reads the counters, then draws a
## brand-new shader (never compiled before) and reads them again, printing `[compile_probe] {json}` and quitting.
##   tools/scripts/shot.sh res://tests/night/CompileProbe.tscn /tmp/x.png 40 <sandbox>
extends Node3D

const INFO_NAMES: PackedStringArray = ["RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS", "RENDERING_INFO_PIPELINE_COMPILATIONS_MESH",
	"RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE", "RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW",
	"RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION"]
const MON_NAMES: PackedStringArray = ["PIPELINE_COMPILATIONS_CANVAS", "PIPELINE_COMPILATIONS_MESH", "PIPELINE_COMPILATIONS_SURFACE",
	"PIPELINE_COMPILATIONS_DRAW", "PIPELINE_COMPILATIONS_SPECIALIZATION"]

var _frame := 0
var _before: Dictionary = {}
var _t_new := 0
var _ms := PackedFloat32Array()
var _last := 0


func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	add_child(cam)
	cam.make_current()
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	add_child(mi)


static func counters() -> Dictionary:
	var out := {}
	for n in INFO_NAMES:
		if ClassDB.class_has_integer_constant("RenderingServer", n):
			out[n] = RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer", n))
	for n2 in MON_NAMES:
		if ClassDB.class_has_integer_constant("Performance", n2):
			out["mon_" + n2] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance", n2))
	return out


func _process(_d: float) -> void:
	_frame += 1
	var now := Time.get_ticks_usec()
	if _last > 0:
		_ms.append(float(now - _last) / 1000.0)
	_last = now
	if _frame == 20:
		_before = counters()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nuniform vec4 c : source_color = vec4(0.9, 0.2, 0.%d, 1.0);\nvoid fragment() { ALBEDO = c.rgb * (0.5 + 0.5 * sin(UV.x * 31.0 + TIME)); }\n" % (Time.get_ticks_usec() % 9)
		var m := ShaderMaterial.new()
		m.shader = sh
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		mi.material_override = m
		mi.position = Vector3(0.8, 0, 0)
		add_child(mi)
		_t_new = _ms.size()
	if _frame == 30:
		var after := counters()
		var hitch := 0.0
		for i in range(_t_new, _ms.size()):
			hitch = maxf(hitch, _ms[i])
		var base := 0.0
		for i2 in range(5, _t_new):
			base = maxf(base, _ms[i2])
		print("[compile_probe] ", JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(),
			"before": _before, "after": after, "frame_ms_max_before": snappedf(base, 0.1), "frame_ms_max_after_new": snappedf(hitch, 0.1)}))
