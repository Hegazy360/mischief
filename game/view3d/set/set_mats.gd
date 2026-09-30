## SetMats — a small material cache for one room set or one live prop: `set_toon` (architecture, furniture, dressing)
## and `prop_toon` (live props) ShaderMaterials keyed by colour, the prop ink (`outline_prop`) and halo (`halo`)
## shells, all registered with MaterialWarm3D (soft). When a shader file is missing the material falls back to an
## unshaded StandardMaterial3D, so a greybox still renders. `stage_light` / `desat` / glow are pushed to every
## material of the cache at once (a room is one lighting group; a prop is one glow group).
class_name SetMats
extends RefCounted

const SH_SET := "res://art3d/shaders/set_toon.gdshader"
const SH_PROP := "res://art3d/shaders/prop_toon.gdshader"
const SH_INK := "res://art3d/shaders/outline_prop.gdshader"
const SH_HALO := "res://art3d/shaders/halo.gdshader"
const WARM := "res://view3d/stage/material_warm_3d.gd"
const INK := Color("#1B2340")

static var _shaders: Dictionary = {}
static var _warm: Script = null
static var _warm_checked := false

var group: String = ""
var palette: Texture2D = null
var _cache: Dictionary = {}
var _all: Array[Material] = []
var _ink: Array[Material] = []
var _halo: Array[Material] = []
var stage_light: float = 1.0
var desat: float = 0.0
var room_color: Color = Color(0.78, 0.71, 0.52)


func _init(p_group: String = "", p_palette: Texture2D = null) -> void:
	group = p_group
	palette = p_palette


## A shader by path (cached; null when the file is missing).
static func shader(path: String) -> Shader:
	if _shaders.has(path):
		return _shaders[path]
	var sh: Shader = null
	if ResourceLoader.exists(path):
		sh = load(path) as Shader
	_shaders[path] = sh
	return sh


## Registers a material with MaterialWarm3D when that module exists (r3d-view3d).
static func warm(mat: Material, kind: StringName) -> void:
	if not _warm_checked:
		_warm_checked = true
		if ResourceLoader.exists(WARM):
			_warm = load(WARM) as Script
	if _warm != null and mat != null:
		_warm.call("register", mat, kind)


## A body material: kind &"set" (set_toon) or &"prop" (prop_toon).
func get_mat(col: Color, kind: StringName) -> Material:
	var key := "%s|%s" % [kind, col.to_html(true)]
	if _cache.has(key):
		return _cache[key]
	var sh := shader(SH_PROP if kind == &"prop" else SH_SET)
	var m: Material
	if sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("albedo_color", col)
		if palette != null:
			sm.set_shader_parameter("palette", palette)
		sm.set_shader_parameter("stage_light", stage_light)
		sm.set_shader_parameter("desat", desat)
		m = sm
	else:
		var st := StandardMaterial3D.new()
		st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		st.albedo_color = col
		m = st
	_cache[key] = m
	_all.append(m)
	warm(m, kind)
	return m


## A textured body material (a set .glb on the room palette): `set_toon` / `prop_toon` with `palette` = tex.
func tex_mat(tex: Texture2D, kind: StringName) -> Material:
	var key := "%s|tex|%d" % [kind, tex.get_instance_id() if tex != null else 0]
	if _cache.has(key):
		return _cache[key]
	var sh := shader(SH_PROP if kind == &"prop" else SH_SET)
	var m: Material
	if sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		if tex != null:
			sm.set_shader_parameter("palette", tex)
		sm.set_shader_parameter("stage_light", stage_light)
		sm.set_shader_parameter("desat", desat)
		m = sm
	else:
		var st := StandardMaterial3D.new()
		st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		st.albedo_texture = tex
		st.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m = st
	_cache[key] = m
	_all.append(m)
	warm(m, kind)
	return m


## The 2.5 px ink shell of a live prop (own instance, layer PROP_INK). `color_normal` = the mesh carries smoothed
## outline normals in COLOR.rgb.
func ink_mat(color_normal: bool = false) -> Material:
	var key := "ink|%s" % color_normal
	if _cache.has(key):
		return _cache[key]
	var sh := shader(SH_INK)
	if sh == null:
		return null
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("ink", INK)
	sm.set_shader_parameter("outline_px", 2.5)
	sm.set_shader_parameter("use_color_normal", color_normal)
	sm.set_shader_parameter("room_color", room_color)
	sm.set_shader_parameter("stage_light", stage_light)
	_cache[key] = sm
	_ink.append(sm)
	warm(sm, &"ink")
	return sm


## The 8 px verb halo shell (own instance, layer PROP_INK).
func halo_mat(verb_color: Color, color_normal: bool = false) -> Material:
	var key := "halo|%s" % color_normal
	if _cache.has(key):
		return _cache[key]
	var sh := shader(SH_HALO)
	if sh == null:
		return null
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("glow_color", verb_color)
	sm.set_shader_parameter("glow_amp", 0.0)
	sm.set_shader_parameter("use_color_normal", color_normal)
	_cache[key] = sm
	_halo.append(sm)
	warm(sm, &"halo")
	return sm


## Every body material of this group.
func materials() -> Array[Material]:
	return _all


## Pushes the room light to every material (bodies, ink `stage_light` + `room_lerp`).
func set_light(level: float, p_desat: float) -> void:
	stage_light = level
	desat = p_desat
	for m in _all:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("stage_light", level)
			(m as ShaderMaterial).set_shader_parameter("desat", p_desat)
	for m in _ink:
		(m as ShaderMaterial).set_shader_parameter("stage_light", level)
		(m as ShaderMaterial).set_shader_parameter("room_lerp", 0.5 if level < 0.95 else 0.0)


## Pushes the verb glow to every prop body material and the halo shell.
func set_glow(col: Color, amp: float, phase: float = 0.0) -> void:
	for m in _all:
		if m is ShaderMaterial and (m as ShaderMaterial).shader == shader(SH_PROP):
			var sm := m as ShaderMaterial
			sm.set_shader_parameter("glow_color", col)
			sm.set_shader_parameter("glow_amp", amp)
			sm.set_shader_parameter("glow_phase", phase)
	for m in _halo:
		var hm := m as ShaderMaterial
		hm.set_shader_parameter("glow_color", col)
		hm.set_shader_parameter("glow_amp", amp)
		hm.set_shader_parameter("glow_phase", phase)


## Pushes the `spent` look (desaturated, a touch darker) to every prop body material.
func set_spent(on: bool) -> void:
	for m in _all:
		if m is ShaderMaterial and (m as ShaderMaterial).shader == shader(SH_PROP):
			(m as ShaderMaterial).set_shader_parameter("spent", 1.0 if on else 0.0)
