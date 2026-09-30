## ShaderSmoke — the rendered shader smoke test of R3D ruling R8 (brief r3d-view3d §4.1). Run it from a FRESH process
## under xvfb with the opengl3 driver (the Compatibility renderer), never headless (a headless run compiles nothing):
##   tools/scripts/shot.sh res://tests/view3d/ShaderSmoke.tscn <out.png> 40 <sandbox> -- --smoke-out=/abs/result.json
## It loads every `.gdshader` in res://art3d/shaders/ into a material on a sphere (the halo and the inks as passes over
## a stencil-writing prop in front of a wall), renders, and FAILS on:
##  * any shader compile error (a Logger catches ERROR_TYPE_SHADER and every error mentioning a shader);
##  * the readability floor: the darkest lit pixel of a set_toon and of a char_toon sphere (albedo 0.5 grey, stage 1.0)
##    below 0.66 × the albedo's luminance (minus a 1.5 % quantisation allowance);
##  * the halo: no verb-coloured halo pixels on the wall around the wall-mounted prop (stencil + depth pull).
## Prints `[shader_smoke] PASS|FAIL …` and writes {pass, shaders, errors, floor_set, floor_char, halo_px} as JSON.
extends Node3D

const SHADER_DIR := "res://art3d/shaders/"
const EVAL_FRAME := 14
const ALBEDO_GREY := 0.5
const FLOOR_K := 0.66
const FLOOR_ALLOW := 0.015
const HALO_COLOR := Color(1.0, 0.784, 0.220)


## Collects shader compile errors (and every other error) raised while the smoke scene renders.
class SmokeLogger extends Logger:
	var mutex := Mutex.new()
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var text := code if rationale == "" else "%s: %s" % [code, rationale]
		var is_shader := error_type == Logger.ERROR_TYPE_SHADER or text.to_lower().contains("shader") \
				or file.to_lower().contains("shader")
		if is_shader:
			mutex.lock()
			errors.append("%s (%s:%d %s)" % [text, file.get_file(), line, function])
			mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error and message.to_lower().contains("shader"):
			mutex.lock()
			errors.append(message.strip_edges())
			mutex.unlock()


var _logger := SmokeLogger.new()
var _frame := 0
var _out_json := ""
var _shot := ""
var _shot_frames := 40
var _cam: Camera3D
var _shaders: PackedStringArray = []
var _probe_set: MeshInstance3D
var _probe_char: MeshInstance3D
var _prop_box: MeshInstance3D
var _done := false


func _ready() -> void:
	OS.add_logger(_logger)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke-out="):
			_out_json = a.substr(12)
		elif a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
	_build()


func _exit_tree() -> void:
	OS.remove_logger(_logger)


func _build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1D1728")
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.fov = 30.0
	_cam.position = Vector3(0.0, 1.2, 7.5)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	add_child(_cam)
	_cam.make_current()
	for f in DirAccess.get_files_at(SHADER_DIR):
		if f.ends_with(".gdshader"):
			_shaders.append(f)
	_shaders.sort()
	# 1. the two floor probes (big spheres, left): set_toon and char_toon on 0.5 grey
	_probe_set = _sphere(Vector3(-2.2, 1.6, 0.0), 0.62, _mat("set_toon.gdshader", {"albedo_color": Color(ALBEDO_GREY, ALBEDO_GREY, ALBEDO_GREY)}))
	_probe_char = _sphere(Vector3(-2.2, 0.35, 0.0), 0.55, _mat("char_toon.gdshader", {"albedo_color": Color(ALBEDO_GREY, ALBEDO_GREY, ALBEDO_GREY), "vc_masks": false, "rim": 0.0}))
	# 2. the wall-mounted prop + ink + halo (right): a wall quad just behind a small box
	var wall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 1.6)
	wall.mesh = q
	wall.position = Vector3(1.9, 1.1, -0.30)
	wall.material_override = _mat("set_toon.gdshader", {"albedo_color": Color("#C7B684")})
	add_child(wall)
	_prop_box = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.25
	bm.height = 0.5
	_prop_box.mesh = bm
	_prop_box.position = Vector3(1.9, 1.1, -0.14)
	_prop_box.material_override = _mat("prop_toon.gdshader", {"albedo_color": Color("#D8452F"), "glow_amp": 1.0})
	add_child(_prop_box)
	for pass_name in ["outline_prop.gdshader", "halo.gdshader"]:
		if not ResourceLoader.exists(SHADER_DIR + pass_name):
			continue
		var shell := MeshInstance3D.new()
		shell.mesh = bm
		shell.position = _prop_box.position
		var params := {"glow_amp": 2.0, "use_color_normal": false} if pass_name == "halo.gdshader" else {}
		shell.material_override = _mat(pass_name, params)
		add_child(shell)
	# 3. every shader on its own small sphere (compile coverage), bottom row; passes ride on a set_toon sphere
	var x := -0.9
	for f in _shaders:
		if f in ["halo.gdshader", "outline_prop.gdshader"]:
			continue
		var params := {}
		if f == "decal.gdshader":
			var quad := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.5, 0.5)
			quad.mesh = qm
			quad.position = Vector3(x, 0.25, 0.3)
			quad.material_override = _mat(f, {"shape": 2, "color": Color(1, 1, 1, 0.9)})
			add_child(quad)
		elif f == "outline.gdshader":
			var base := _mat("set_toon.gdshader", {})
			base.next_pass = _mat(f, {"outline_px": 6.0})
			_sphere(Vector3(x, 0.25, 0.3), 0.2, base)
		else:
			_sphere(Vector3(x, 0.25, 0.3), 0.2, _mat(f, params))
		x += 0.55


func _mat(file: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh: Shader = load(SHADER_DIR + file)
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _sphere(pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 48
	s.rings = 24
	mi.mesh = s
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == EVAL_FRAME and not _done:
		_done = true
		_evaluate()
	if _shot != "" and get_node_or_null("/root/DevShot") == null and _frame == _shot_frames:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()


func _evaluate() -> void:
	var img := get_viewport().get_texture().get_image()
	var floor_set := _min_luma(img, _probe_set, 0.62)
	var floor_char := _min_luma(img, _probe_char, 0.55)
	var halo := _halo_pixels(img)
	var want := FLOOR_K * ALBEDO_GREY - FLOOR_ALLOW
	var errs := _logger.errors.duplicate()
	var ok := errs.is_empty() and floor_set >= want and floor_char >= want and halo > 0 and _shaders.size() >= 8
	var result := {"pass": ok, "shaders": Array(_shaders), "errors": Array(errs), "floor_set": floor_set,
			"floor_char": floor_char, "floor_want": want, "halo_px": halo, "frame": _frame}
	print("[shader_smoke] %s shaders=%d errors=%d floor_set=%.3f floor_char=%.3f (want >= %.3f) halo_px=%d" % [
			"PASS" if ok else "FAIL", _shaders.size(), errs.size(), floor_set, floor_char, want, halo])
	for e in errs:
		print("[shader_smoke] error: ", e)
	if _out_json != "":
		var f := FileAccess.open(_out_json, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(result, "  "))


## The minimum luminance over the sphere's projected disc (inset 12 % from the silhouette so edge AA and the
## background never count).
func _min_luma(img: Image, mi: MeshInstance3D, r: float) -> float:
	var c := _cam.unproject_position(mi.global_position)
	var edge := _cam.unproject_position(mi.global_position + _cam.global_basis.x * r)
	var rp := (edge - c).length() * 0.88
	var sx := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var lo := 9.0
	var steps := 40
	for iy in steps + 1:
		for ix in steps + 1:
			var p := Vector2(-1.0 + 2.0 * ix / steps, -1.0 + 2.0 * iy / steps)
			if p.length() > 1.0:
				continue
			var q := (c + p * rp) * sx
			var px := img.get_pixel(clampi(int(q.x), 0, img.get_width() - 1), clampi(int(q.y), 0, img.get_height() - 1))
			lo = minf(lo, 0.299 * px.r + 0.587 * px.g + 0.114 * px.b)
	return lo


## Counts halo-coloured pixels in a band just outside the prop box's projected rect (on the wall).
func _halo_pixels(img: Image) -> int:
	var aabb := _prop_box.get_aabb()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p := _cam.unproject_position(_prop_box.global_transform * aabb.get_endpoint(i))
		lo = lo.min(p)
		hi = hi.max(p)
	var sx := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var n := 0
	var band := 12.0
	var y := lo.y - band
	while y <= hi.y + band:
		var x := lo.x - band
		while x <= hi.x + band:
			var inside := x > lo.x + 2 and x < hi.x - 2 and y > lo.y + 2 and y < hi.y - 2
			if not inside:
				var px := img.get_pixel(clampi(int(x * sx), 0, img.get_width() - 1), clampi(int(y * sx), 0, img.get_height() - 1))
				if px.r > 0.8 and px.g > 0.55 and px.b < 0.45 and px.r - px.b > 0.4:
					n += 1
			x += 1.0
		y += 1.0
	return n
