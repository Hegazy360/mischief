## NightWarmer — works through a `NightWarm.list()` under the curtain, one step per frame, each
## step capped by BUDGET_MS of work (s2-night §4.2): residue / combo looks on the rigs
## (`RigPlayer.warm_looks`, soft), the fonts at their play sizes (a primer that draws every glyph set
## once, hidden under the curtain), one hidden PiP frame (`PipView.warm()`, soft), the Night's audio
## (`Audio.warm(ids)`), the FX pool. `done` turns true when every step ran; `elapsed_ms` is the wall
## time from `start()` to done (the budget is ≤ 2.0 s).
## **3D view** (`view3d`, REDESIGN §6.3 "every material is rendered once under the curtain"): `materials` — every
## material the Night registered with MaterialWarm3D (`WorldView3D.warm_materials`: one quad per (shader, kind, pass
## chain) + `RigPlayer3D.warm()`: every tint tier / stone / look / attachment state) **and** every other material in
## the Night's tree, hidden ones included (tags, eye cards, plinth, looks), one quad each in front of the camera, plus
## the instanced variant of every particle material (a one-instance MultiMesh) — drawn for WARM_FRAMES frames, then
## freed; `clips` (every 3D clip into ClipLib3D's cache), `overlays` (every pictogram / icon raster), the Bellows
## window (one render), fonts, audio, the lazy UI textures. `materials_drawn` / `instanced_drawn` count the quads.
class_name NightWarmer
extends Node

signal finished(ms: int)

const BUDGET_MS := 8
## Frames the 3D warm quads stay drawn before they are freed.
const WARM_FRAMES := 2

var list: Dictionary = {}
var done: bool = false
var elapsed_ms: int = 0
## Step names in the order they ran (tests, the report).
var ran: PackedStringArray = PackedStringArray()
var world_view: Node = null
var pip: Node = null
## Where the font primer draws (a CanvasLayer under the curtain).
var primer_parent: Node = null
## 3D: the view is WorldView3D; its camera, the world overlays and their context.
var view3d: bool = false
var cam: Camera3D = null
var overlays: Object = null
var octx: Object = null
## 3D: quads drawn (MaterialWarm3D entries + the tree's other materials) and instanced variants.
var materials_drawn: int = 0
var instanced_drawn: int = 0
var clips_warmed: int = 0
## Scenes the view builds lazily in PLAY (CharacterView3D's freeze plinth at the first freeze): their materials join
## the warm rig, so their shaders compile under the curtain.
const LAZY_SCENES: PackedStringArray = ["res://art3d/chars/hush/plinth.glb"]
## Every shader key the warm-up drew (the registry, the scene rig, the lazy scenes): ShaderWatch.arm adds them to its
## warmed set — the rig itself is freed before the rise.
var warmed_keys: Dictionary = {}

var _steps: Array = []
var _t0: int = 0
var _primer: Node2D = null
var _tex_i: int = 0
var _tex_items: Array = []
var _blocking: bool = false
## Lazy textures rasterised so far (tests, the report).
var textures_warmed: int = 0


## Begin warming `p_list` for `wv` (WorldView) and `p_pip` (PipView).
func start(p_list: Dictionary, wv: Node, p_pip: Node, p_primer_parent: Node) -> void:
	list = p_list
	world_view = wv
	pip = p_pip
	primer_parent = p_primer_parent
	done = false
	ran = PackedStringArray()
	_t0 = Time.get_ticks_msec()
	_tex_i = 0
	_tex_items = []
	_steps = [["looks_bellows", _warm_looks.bind("bellows")], ["looks_hush", _warm_looks.bind("hush")],
		["fonts", _warm_fonts], ["pip", _warm_pip], ["audio", _warm_audio], ["textures", _warm_textures],
		["ui_icons", _warm_ui_icons], ["fonts_done", _free_primer]]
	if view3d:
		_steps = [["materials", _warm_materials_3d], ["clips", _warm_clips_3d], ["overlays", _warm_overlays_3d],
			["fonts", _warm_fonts], ["pip", _warm_pip], ["audio", _warm_audio], ["textures", _warm_textures],
			["ui_icons", _warm_ui_icons], ["fonts_done", _free_primer], ["materials_done", _free_warm_3d]]
	set_process(true)


func _process(_d: float) -> void:
	if _free_pending and Engine.get_process_frames() - _rig_frames >= WARM_FRAMES:
		_free_pending = false
		_free_rigs()
	if done:
		if not _free_pending:
			set_process(false)
		return
	var t := Time.get_ticks_msec()
	while not _steps.is_empty() and Time.get_ticks_msec() - t < BUDGET_MS:
		var s: Array = _steps[0]
		var r: Variant = (s[1] as Callable).call()
		if r is bool and not bool(r):
			break   # a resumable step (textures) spent this frame's budget; it continues next frame
		_steps.pop_front()
		ran.append(String(s[0]))
		if String(s[0]) == "fonts":
			break   # the primer draws this frame; free it next frame
	if _steps.is_empty():
		done = true
		elapsed_ms = Time.get_ticks_msec() - _t0
		DeviceLog.note("warm_ms", elapsed_ms)
		finished.emit(elapsed_ms)


## Run every step now (tests, a seek that needs a warm world at once, a rise forced by the launch cap
## before the warm-up finished: the hitch then lands on the rise frame, under the curtain, never on a
## gag). Look pages are built to completion (≤ 1.5 s guard).
func finish_now() -> void:
	_blocking = true
	while not _steps.is_empty():
		var s: Array = _steps[0]
		var r: Variant = (s[1] as Callable).call()
		if r is bool and not bool(r):
			continue   # resumable: call again until done
		_steps.pop_front()
		ran.append(String(s[0]))
	# looks that started warming in the background: build the rest now
	if not view3d:
		_warm_looks("bellows")
		_warm_looks("hush")
	_blocking = false
	if not done:
		done = true
		elapsed_ms = Time.get_ticks_msec() - _t0
		DeviceLog.note("warm_ms", elapsed_ms)
		finished.emit(elapsed_ms)


# --- 3D ----------------------------------------------------------------------------------------------------

var _rig3d: Node3D = null
var _rig_frames: int = -1
var _free_pending: bool = false


## Build both warm rigs (MaterialWarm3D's + the tree's other materials) in front of the camera; true when built
## (they are drawn for WARM_FRAMES frames and freed by `materials_done`).
func _warm_materials_3d() -> bool:
	if world_view == null or cam == null:
		return true
	if _rig_frames < 0:
		_props_on()
		var reg: Variant = world_view.call("warm_materials", cam) if world_view.has_method("warm_materials") else null
		materials_drawn = MaterialWarm3D.count()
		_rig3d = build_scene_rig(get_parent() if get_parent() != null else world_view, cam, world_view)
		_rig_frames = Engine.get_process_frames()
		var _unused: Variant = reg
	return true


## The rest of the warm (fonts, audio, textures) runs while the rigs are drawn; they go after WARM_FRAMES frames.
func _free_warm_3d() -> bool:
	if _rig_frames >= 0 and Engine.get_process_frames() - _rig_frames < WARM_FRAMES:
		if _blocking:
			# finish_now (a forced rise / a CLI start): the quads still get their frames, then go
			_free_pending = true
			set_process(true)
			return true
		return false
	_free_rigs()
	return true


## Every live rig prop hangs its red beret tag for the warm frames (the tag is built on its first show: its material
## must be drawn under the curtain, not at the first rig — measured: a StandardMaterial3D first registered at tick 211).
var _tagged: Array = []


func _props_on() -> void:
	_tagged.clear()
	var lv: Variant = world_view.get("live")
	if not (lv is Dictionary) or not world_view.has_method("prop"):
		return
	for id in lv:
		if String(lv[id]) != "rig":
			continue
		var p: Variant = world_view.call("prop", String(id))
		if not (p is Object) or not (p as Object).has_method("show_tag"):
			continue
		if (p as Object).has_method("tag_shown") and bool((p as Object).call("tag_shown")):
			continue
		(p as Object).call("show_tag", true, false)
		_tagged.append(p)


func _props_off() -> void:
	for p in _tagged:
		if p is Object and is_instance_valid(p):
			(p as Object).call("show_tag", false, false)
	_tagged.clear()


func _free_rigs() -> void:
	_props_off()
	MaterialWarm3D.free_warm_rig()
	if _rig3d != null and is_instance_valid(_rig3d):
		_rig3d.queue_free()
	_rig3d = null


func _warm_clips_3d() -> void:
	if world_view != null and world_view.has_method("warm_clips"):
		clips_warmed = int(world_view.call("warm_clips"))


func _warm_overlays_3d() -> void:
	if overlays != null and octx != null and overlays.has_method("warm"):
		overlays.call("warm", octx)


## A warm rig for every material under `root` that MaterialWarm3D does not already draw (hidden instances too), and
## a one-instance MultiMesh for every particle material (their instanced shader variant). Returns the rig (a child of
## `parent`, placed 1.6 m in front of `camera`); counts in `materials_drawn` / `instanced_drawn`.
func build_scene_rig(parent: Node, camera: Camera3D, root: Node) -> Node3D:
	var reg := {}
	var plain := {}
	var inst := {}
	for e in MaterialWarm3D.entries():
		var d: Dictionary = e
		var m: Material = d["material"]
		# the particle materials also draw instanced (CPUParticles3D → MultiMesh): warm that variant too
		if StringName(d["kind"]) == &"fx":
			var ki := ShaderWatch.shader_key(m, true)
			if ki != "" and not inst.has(ki):
				inst[ki] = m
		var guard := 0
		while m != null and guard < 6:
			reg[ShaderWatch.shader_key(m, false)] = true
			m = m.next_pass
			guard += 1
	_collect(root, reg, plain, inst)
	for path in LAZY_SCENES:
		if ResourceLoader.exists(path):
			var ps: Variant = load(path)
			if ps is PackedScene:
				var lazy := (ps as PackedScene).instantiate()
				if lazy != null:
					_collect(lazy, reg, plain, inst)
					lazy.free()   # its materials live on in the rig's quads
	for k0 in reg:
		warmed_keys[k0] = true
	for k1 in plain:
		warmed_keys[k1] = true
	for k3 in inst:
		warmed_keys[k3] = true
	var rig := Node3D.new()
	rig.name = "NightWarmRig"
	parent.add_child(rig)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var fwd := -camera.global_basis.z
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var origin := camera.global_position + fwd * 1.6
	var i := 0
	for k in plain:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = plain[k]
		mi.layers = View3DConst.MASK_MAIN
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(mi)
		mi.global_position = origin + right * (-0.4 + 0.05 * float(i % 16)) + up * (0.1 + 0.05 * float(i / 16))
		i += 1
	materials_drawn += plain.size()
	var j := 0
	for k2 in inst:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D.IDENTITY)
		mm.set_instance_color(0, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = inst[k2]
		mmi.layers = View3DConst.MASK_MAIN
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(mmi)
		mmi.global_position = origin + right * (-0.4 + 0.05 * float(j % 16)) + up * (-0.3 - 0.05 * float(j / 16))
		j += 1
	instanced_drawn = inst.size()
	return rig


func _collect(n: Node, reg: Dictionary, plain: Dictionary, inst: Dictionary) -> void:
	if n.name == "MaterialWarm3D" or n.name == "NightWarmRig":
		return
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		var is_inst := g is CPUParticles3D or g is MultiMeshInstance3D
		if g.material_override != null:
			_add_mat(g.material_override, is_inst, reg, plain, inst)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var mi := g as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m != null:
					_add_mat(m, false, reg, plain, inst)
	for c in n.get_children():
		_collect(c, reg, plain, inst)


func _add_mat(m: Material, instanced: bool, reg: Dictionary, plain: Dictionary, inst: Dictionary) -> void:
	var k := ShaderWatch.shader_key(m, false)
	if k == "":
		return
	if instanced:
		var ki := ShaderWatch.shader_key(m, true)
		if not inst.has(ki):
			inst[ki] = m
	elif not reg.has(k) and not plain.has(k):
		plain[k] = m


func _warm_looks(actor: String) -> void:
	if world_view == null or not world_view.has_method("character"):
		return
	var cv: Variant = world_view.call("character", actor)
	if not (cv is Node):
		return
	var rig: Variant = (cv as Node).get("rig")
	var looks: Variant = (list.get("looks", {}) as Dictionary).get(actor, PackedStringArray())
	if rig is Node and (rig as Node).has_method("warm_looks") and looks is PackedStringArray and not (looks as PackedStringArray).is_empty():
		var ok := bool((rig as Node).call("warm_looks", looks))
		var t0 := Time.get_ticks_msec()
		while _blocking and not ok and Time.get_ticks_msec() - t0 < 1500:
			ok = bool((rig as Node).call("warm_looks", looks, 50.0))


func _warm_fonts() -> void:
	if primer_parent == null:
		return
	_primer = _FontPrimer.new()
	_primer.texts = PackedStringArray(list.get("captions", PackedStringArray()))
	_primer.sizes = list.get("fonts", NightWarm.FONT_SIZES)
	primer_parent.add_child(_primer)


func _free_primer() -> void:
	if _primer != null and is_instance_valid(_primer):
		_primer.queue_free()
	_primer = null


func _warm_pip() -> void:
	if pip != null and pip.has_method("warm"):
		pip.call("warm")


## Rasterise the lazy view textures: all of them start on worker threads at once (HiResTex.warm)
## and finish within the frame budget (s2-fix G #9 — one blocking SVG per frame made this step
## ~1 s); then ViewKit's cache is filled from the finished rasters. False until done.
func _warm_textures() -> bool:
	var paths: Variant = list.get("textures", PackedStringArray())
	if not (paths is PackedStringArray):
		return true
	var arr: PackedStringArray = paths
	if _tex_items.is_empty() and not arr.is_empty():
		for p in arr:
			_tex_items.append({"path": p, "scale": ViewKit.art_scale_of(p)})
	if HiResTex.warm(_tex_items, BUDGET_MS) > 0:
		return false
	var t := Time.get_ticks_msec()
	while _tex_i < arr.size():
		ViewKit.tex(arr[_tex_i])
		_tex_i += 1
		textures_warmed += 1
		if Time.get_ticks_msec() - t >= BUDGET_MS and not _blocking:
			return _tex_i >= arr.size()
	return true


## The HUD's own rasters the Night will ask for (PiP awareness glyphs, badges).
func _warm_ui_icons() -> void:
	for g in ["specs_off", "specs_on", "blinded", "asleep", "stars"]:
		UiIcons.glyph(g)
	for b in ["gold", "hide", "in_use", "needs"]:
		UiIcons.badge(b)


func _warm_audio() -> void:
	var a := ViewKit.autoload("Audio")
	var ids: Variant = list.get("audio", PackedStringArray())
	if a != null and a.has_method("warm") and ids is PackedStringArray and not (ids as PackedStringArray).is_empty():
		a.call("warm", ids)


## Draws every glyph set once (off to the side, under the curtain) so the font caches are filled
## before the first caption.
class _FontPrimer:
	extends Node2D
	var texts := PackedStringArray()
	var sizes: Array = []

	func _ready() -> void:
		position = Vector2(-4000, -4000)
		modulate = Color(1, 1, 1, 0.004)
		queue_redraw()

	func _draw() -> void:
		var y := 0.0
		for s in sizes:
			var d: Dictionary = s
			var f: Font = ViewKit.display_font() if String(d.get("font", "display")) == "display" else ViewKit.ui_font()
			if f == null:
				f = ThemeDB.fallback_font
			var sz := int(d.get("size", 48))
			for t in texts:
				draw_string(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
				draw_string_outline(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6)
			y += float(sz) * 1.2
