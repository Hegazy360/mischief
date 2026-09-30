## ShaderWatch — "no shader compiled during play" (REDESIGN §6.3, risk X2; brief r3d-night §4.2).
##
## Method (measured, `tests/night/CompileProbe.tscn`): Godot 4.7.2's Compatibility renderer reports **0** for every
## `RenderingServer.get_rendering_info(RENDERING_INFO_PIPELINE_COMPILATIONS_*)` counter and every
## `Performance.PIPELINE_COMPILATIONS_*` monitor even while a never-seen shader compiles (a 480 ms frame on llvmpipe),
## so the counters cannot see GLES3 compiles. The watch therefore counts what would compile:
## * **first use** — at the rise (`arm(root)`) it records the warmed set: every MaterialWarm3D key and the shader of
##   every material in the Night's tree (the warm-up drew them all); after that, every MaterialWarm3D key first
##   registered, and every shader (+ the instanced variant for particles) first seen on a visible instance in a
##   `scan()` (every SCAN_EVERY PLAY frames), is a `shader_first_use` — `shader_compiles_play` must stay 0;
## * **hitches** — every PLAY frame longer than max(HITCH_MS, HITCH_K × the running median frame) (the device's 50 ms
##   budget; on the CPU box the median itself is ≈ 85 ms);
## * the pipeline counters anyway (`pipeline_delta`), in case a later renderer reports them.
## Both go to the device log (`DeviceLog.shader_first_use`, `DeviceLog.hitch`) and the e2e report (`perf3d`).
class_name ShaderWatch
extends RefCounted

const HITCH_MS := 50.0
const HITCH_K := 2.5
const SCAN_EVERY := 60
const RING := 61
const INFO_NAMES: PackedStringArray = ["RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS",
	"RENDERING_INFO_PIPELINE_COMPILATIONS_MESH", "RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE",
	"RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW", "RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION"]

var armed: bool = false
## "first_use" (GLES3) — or "pipeline_info" if the renderer ever reports compilations.
var method: String = "first_use"
## [{key, kind, tick, source: "registry"|"scene"}] — every shader first used after the rise.
var first_use: Array = []
## [{tick, frame_ms, median_ms}]
var hitches: Array = []
var hitch_max_ms: float = 0.0
## Pipeline compilations the renderer reported after the rise (0 on GLES3).
var pipeline_delta: int = 0
## Warmed shader keys at the rise (+ every key seen since).
var known: Dictionary = {}
var root: Node = null

var _reg_count: int = 0
var _pipe0: int = 0
var _frame: int = 0
var _ring := PackedFloat32Array()
var _ring_i: int = 0
var _ring_n: int = 0
var _sort := PackedFloat32Array()


## Record the warmed set (call on the curtain-rise frame, after the warm-up). `warmed` = NightWarmer.warmed_keys (what
## its rig drew, freed since: e.g. the lazily built plinth's material).
func arm(p_root: Node, warmed: Dictionary = {}) -> void:
	root = p_root
	armed = true
	known.clear()
	known.merge(warmed)
	for e in MaterialWarm3D.entries():
		var d: Dictionary = e
		known["reg:" + MaterialWarm3D.key_of(d["material"], d["kind"])] = true
		_note_material(d["material"], false)
		if StringName(d["kind"]) == &"fx":
			_note_material(d["material"], true)
	_reg_count = MaterialWarm3D.count()
	if root != null:
		_walk(root, false, false)
	_pipe0 = pipeline_total()
	_ring.resize(RING)
	_sort.resize(0)
	_ring_i = 0
	_ring_n = 0
	_frame = 0


## Forget everything (a new Night).
func reset() -> void:
	armed = false
	first_use.clear()
	hitches.clear()
	hitch_max_ms = 0.0
	pipeline_delta = 0
	known.clear()


## The number of shaders compiled during PLAY (first uses + reported pipeline compilations).
func compiles_play() -> int:
	return first_use.size() + pipeline_delta


## Per PLAY frame: new registry keys, the periodic scene scan, hitches, the pipeline counters.
func frame(dt: float, tick: int) -> void:
	if not armed:
		return
	_frame += 1
	var ms := dt * 1000.0
	if _ring_n >= 10:
		var med := median_ms()
		var lim := maxf(HITCH_MS, HITCH_K * med)
		if ms > lim:
			hitch_max_ms = maxf(hitch_max_ms, ms)
			if hitches.size() < 200:
				hitches.append({"tick": tick, "frame_ms": snappedf(ms, 0.1), "median_ms": snappedf(med, 0.1)})
			DeviceLog.hitch(ms, med, tick)
	_ring[_ring_i] = ms
	_ring_i = (_ring_i + 1) % RING
	_ring_n = mini(_ring_n + 1, RING)
	if MaterialWarm3D.count() != _reg_count:
		_reg_count = MaterialWarm3D.count()
		for e in MaterialWarm3D.entries():
			var d: Dictionary = e
			var k: String = "reg:" + MaterialWarm3D.key_of(d["material"], d["kind"])
			if not known.has(k):
				known[k] = true
				_first(k, String(d["kind"]), tick, "registry")
				_note_material(d["material"], false)
	if root != null and _frame % SCAN_EVERY == 0:
		scan(tick)
	var pt := pipeline_total()
	if pt > _pipe0:
		pipeline_delta += pt - _pipe0
		_pipe0 = pt
		method = "pipeline_info"


## Walk the tree now: a visible instance whose shader was never seen is a first use.
func scan(tick: int) -> void:
	if root == null or not is_instance_valid(root):
		return
	_scan_tick = tick
	_walk(root, true, true)


## The median of the last frames (ms).
func median_ms() -> float:
	if _ring_n <= 0:
		return 0.0
	_sort.resize(_ring_n)
	for i in _ring_n:
		_sort[i] = _ring[i]
	_sort.sort()
	return _sort[_ring_n / 2]


## Every pipeline compilation the renderer reports (0 on GLES3).
static func pipeline_total() -> int:
	var n := 0
	for name in INFO_NAMES:
		if ClassDB.class_has_integer_constant("RenderingServer", name):
			n += RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer", name))
	return n


## The watch's report (e2e `perf3d`, the device log).
func summary() -> Dictionary:
	return {"method": method, "shader_compiles_play": compiles_play(), "first_use": first_use.slice(0, 20),
		"hitches": hitches.size(), "hitch_max_ms": snappedf(hitch_max_ms, 0.1), "pipeline_delta": pipeline_delta,
		"known": known.size()}


# --- internals ---------------------------------------------------------------------------------------------------

var _scan_tick: int = 0


func _first(key: String, kind: String, tick: int, source: String) -> void:
	first_use.append({"key": key, "kind": kind, "tick": tick, "source": source})
	DeviceLog.shader_first_use(key, kind, tick)


## The compile unit of a material: its shader (ShaderMaterial), or for a BaseMaterial3D its feature signature
## (`base_key`: Godot builds one shader per feature set and shares it between every material with that set), + "inst:"
## for the instanced variant (particles / MultiMesh).
static func shader_key(m: Material, instanced: bool) -> String:
	var base := ""
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		if sh == null:
			return ""
		base = sh.resource_path if sh.resource_path != "" else "shader:%d" % sh.get_rid().get_id()
	elif m is BaseMaterial3D:
		base = ShaderWatch.base_key(m as BaseMaterial3D)
	else:
		base = "%s:%d" % [m.get_class(), m.get_rid().get_id()]
	return ("inst:" if instanced else "sh:") + base


## The properties a BaseMaterial3D's generated shader depends on (the engine's material key: modes, flags, which
## feature textures are set). Parameters (colours, amounts) are uniforms and do not make a new shader.
const BASE_KEY_PROPS: PackedStringArray = ["transparency", "shading_mode", "blend_mode", "cull_mode", "depth_draw_mode",
	"no_depth_test", "diffuse_mode", "specular_mode", "billboard_mode", "billboard_keep_scale", "texture_filter",
	"texture_repeat", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "normal_enabled", "emission_enabled",
	"rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "ao_enabled", "heightmap_enabled",
	"subsurf_scatter_enabled", "backlight_enabled", "refraction_enabled", "detail_enabled", "use_point_size",
	"fixed_size", "grow", "alpha_antialiasing_mode", "distance_fade_mode", "proximity_fade_enabled",
	"disable_receive_shadows", "shadow_to_opacity", "disable_ambient_light", "disable_fog", "uv1_triplanar",
	"uv2_triplanar", "use_particle_trails", "albedo_texture_force_srgb"]
const BASE_KEY_TEXTURES: PackedStringArray = ["albedo_texture", "metallic_texture", "roughness_texture",
	"emission_texture", "normal_texture", "orm_texture"]


static func base_key(m: BaseMaterial3D) -> String:
	var parts := PackedStringArray([m.get_class()])
	for p in BASE_KEY_PROPS:
		var v: Variant = m.get(p)
		parts.append("" if v == null else str(v))
	for t in BASE_KEY_TEXTURES:
		parts.append("1" if m.get(t) != null else "0")
	return "|".join(parts)


func _note_material(m: Material, instanced: bool) -> void:
	var guard := 0
	while m != null and guard < 6:
		var k := shader_key(m, instanced)
		if k != "":
			known[k] = true
		m = m.next_pass
		guard += 1


func _check_material(m: Material, instanced: bool, report: bool, where: Node = null) -> void:
	var guard := 0
	while m != null and guard < 6:
		var k := shader_key(m, instanced)
		if k != "" and not known.has(k):
			known[k] = true
			if report:
				_first(k, "scene", _scan_tick, "scene")
				# where it was seen (the node, the material's file or name) — who to ask to warm it
				var rec: Dictionary = first_use[first_use.size() - 1]
				rec["node"] = String(root.get_path_to(where)) if where != null and root != null and root.is_ancestor_of(where) else ""
				rec["material"] = m.resource_path if m.resource_path != "" else m.resource_name
		m = m.next_pass
		guard += 1


func _walk(n: Node, only_visible: bool, report: bool) -> void:
	if n is Node3D and only_visible and not (n as Node3D).visible:
		return
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		var inst := g is CPUParticles3D or g is MultiMeshInstance3D or g is GPUParticles3D
		if inst and only_visible and g is CPUParticles3D and not (g as CPUParticles3D).emitting:
			pass
		else:
			if g.material_override != null:
				_check_material(g.material_override, inst, report, g)
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				var mi := g as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					var m := mi.get_active_material(i)
					if m != null:
						_check_material(m, false, report, g)
			elif g is CPUParticles3D and (g as CPUParticles3D).mesh != null:
				var pm := (g as CPUParticles3D).mesh
				for i2 in pm.get_surface_count():
					var m2 := pm.surface_get_material(i2)
					if m2 != null:
						_check_material(m2, true, report, g)
	for c in n.get_children():
		_walk(c, only_visible, report)
