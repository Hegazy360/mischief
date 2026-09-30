## GagReel3D — the curtain call's Gag Reel over the 3D view (brief r3d-night §4.3; GDD §6.2): the Night's best
## moments re-staged from what was drawn. NightScene's `GagReel.Log` keeps one MomentRecorder3D window per reaction
## (`Log.keep_3d`: [start − 12 f, end], knock-ons merged into their trigger's window); the reel poses both characters
## by clip + frame (`WorldView3D.show_moment_frame`), puts every prop in that moment's state (idle / armed / spent /
## occupied) and the decor pieces (the launched stool) as they were, lights the rooms the actors were in, and films it
## in a 704 × 396 SubViewport that shares the World3D — a camera framed like the live punch-in (Bellows' chest, the
## prank's size zoom, eased in to the accent) — with the pun caption drawn in the slot after the accent.
## No empty box: `prime()` renders the first moment's first frame before the reel step starts (the ResultsScreen
## shows the texture at once). `skip()` (a tap) ends the current moment; `budget_s` caps the whole reel. Sounds are
## not replayed (the call's crowd and music carry on) — a stated difference from the 2D reel.
## While it plays the world view is paused (`set_process(false)`, the characters in `replay`); `stop()` / the end
## hands them back.
class_name GagReel3D
extends Node

signal moment_started(index: int, moment: Dictionary)
signal finished()

const SIZE := Vector2i(704, 396)
const BASE_DIST := 7.5
const PRE_ZOOM := 1.15
const CAPTION_PX := 44

var night: Node = null
var world_view: Node = null
var viewport: SubViewport = null
var reel_cam: Camera3D = null
var caption: Label = null
var moments: Array = []
var budget_s: float = 8.0
var index: int = -1
var playing: bool = false
var primed: bool = false
## Ticks actually played per moment (tests / the report) and the frames shown.
var played: Array = []
var frames_shown: int = 0

var _rec: Object = null
var _moment: Object = null
var _t_ticks: float = 0.0
var _elapsed: float = 0.0
var _zoom: float = 1.4
var _accent: int = -1
var _focus := Vector3.ZERO
var _snap := true
var _info: Object = null


func _init() -> void:
	name = "GagReel3D"
	viewport = SubViewport.new()
	viewport.name = "ReelViewport3D"
	viewport.size = SIZE
	viewport.own_world_3d = false
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	reel_cam = Camera3D.new()
	reel_cam.name = "ReelCamera3D"
	reel_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	reel_cam.fov = 30.0
	reel_cam.near = 0.3
	reel_cam.far = 40.0
	reel_cam.cull_mask = View3DConst.MASK_MAIN & ~View3DConst.MASK_PROP_INK
	viewport.add_child(reel_cam)
	caption = Label.new()
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 18)
	caption.size = Vector2(SIZE.x, 70)
	caption.add_theme_font_override("font", UiKit.display_font())
	caption.add_theme_font_size_override("font_size", CAPTION_PX)
	caption.add_theme_color_override("font_color", UiKit.GOLD_LIGHT)
	caption.add_theme_color_override("font_outline_color", UiKit.NAVY)
	caption.add_theme_constant_override("outline_size", 10)
	caption.visible = false
	viewport.add_child(caption)


func _ready() -> void:
	reel_cam.current = true


## The reel's texture (ResultsScreen.set_gag_reel_texture).
func get_texture() -> Texture2D:
	return viewport.get_texture()


## Pose the first moment's first frame and render it once (call as soon as the curtain call starts).
func prime(p_night: Node, p_moments: Array) -> void:
	night = p_night
	moments = p_moments
	world_view = night.get("world_view") if night != null else null
	_rec = world_view.get("recorder") if world_view != null else null
	_info = world_view.get("info") if world_view != null else null
	if moments.is_empty() or _rec == null:
		return
	var m: Object = _rec.call("moment", int((moments[0] as Dictionary).get("rec", -1)))
	if m == null or int(m.call("count")) <= 0:
		return
	_hold_world(true)
	_begin(0, m)
	_show(0.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	primed = true


## Play `p_moments` (from `Log.best`) on `p_night` within `p_budget_s`. `_cmds` is unused (2D replays the sim).
func start(p_night: Node, p_moments: Array, p_budget_s: float, _cmds: Array = []) -> void:
	if not primed:
		prime(p_night, p_moments)
	budget_s = p_budget_s
	index = -1
	played.clear()
	_elapsed = 0.0
	if not primed:
		_finish()
		return
	playing = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_next()


## A tap: end the current moment now.
func skip() -> void:
	if playing:
		_next()


## End the whole reel now.
func stop() -> void:
	if playing or primed:
		_finish()


func _share() -> float:
	return budget_s / float(maxi(1, moments.size()))


func _next() -> void:
	index += 1
	while index < moments.size() and _elapsed < budget_s:
		var m: Object = _rec.call("moment", int((moments[index] as Dictionary).get("rec", -1)))
		if m != null and int(m.call("count")) > 0:
			_begin(index, m)
			var w := GagReel.window(moments[index], _share())
			played.append(Vector2i(w.x, w.y))
			moment_started.emit(index, moments[index])
			return
		index += 1
	_finish()


func _begin(i: int, m: Object) -> void:
	_moment = m
	var md: Dictionary = moments[i]
	var w := GagReel.window(md, _share())
	_t_ticks = float(maxi(w.x, int(m.get("from_tick"))))
	_accent = int(md.get("accent", -1))
	var size := "M"
	if _info != null and _info.has_method("prank"):
		size = String((_info.call("prank", String(md.get("prank", ""))) as Dictionary).get("size", "M"))
	_zoom = float(ContentInfo.SIZE_ZOOM.get(size, 1.3)) * 1.1
	caption.text = ""
	if _info != null and _info.has_method("prank"):
		caption.text = String((_info.call("prank", String(md.get("prank", ""))) as Dictionary).get("caption", ""))
	caption.visible = false
	_snap = true


func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	_t_ticks += delta * 60.0
	var md: Dictionary = moments[index] if index >= 0 and index < moments.size() else {}
	var w := GagReel.window(md, _share())
	if _t_ticks >= float(mini(w.y, int(_moment.get("to_tick")))) or _elapsed >= budget_s:
		_next()
		return
	_show(delta)


## Pose the frame at the current tick and aim the reel camera.
func _show(delta: float) -> void:
	var f: Object = _moment.call("frame_at_tick", int(_t_ticks))
	if f == null:
		return
	world_view.call("show_moment_frame", f)
	_apply_props(f)
	var lighting: Variant = world_view.get("lighting")
	if lighting is Object:
		(lighting as Object).call("set_rooms_of", String(f.get("hush").get("room")), String(f.get("bellows").get("room")))
		(lighting as Object).call("advance", maxf(delta, 0.4))
	frames_shown += 1
	var b: Object = f.get("bellows")
	var target: Vector3 = b.get("pos") + Vector3(0.0, 1.05, 0.0)
	var after := _accent >= 0 and int(_t_ticks) >= _accent
	var z := _zoom if after else PRE_ZOOM
	caption.visible = after and caption.text != ""
	var k := 1.0 if _snap else clampf(delta * 6.0, 0.0, 1.0)
	_snap = false
	_focus = _focus.lerp(target, k)
	var d := maxf(4.5, BASE_DIST / maxf(0.5, z)) * 0.72
	var eye := _focus + Vector3(0.0, 0.35, d)
	reel_cam.global_transform = Transform3D(Basis.looking_at(_focus - eye, Vector3.UP), eye) if reel_cam.is_inside_tree() \
		else Transform3D(Basis.looking_at(_focus - eye, Vector3.UP), eye)


## The props of the frame: idle / armed / spent / occupied, and the decor pieces' visibility.
func _apply_props(f: Object) -> void:
	var ids: PackedStringArray = _rec.get("hotspot_ids")
	var codes: PackedByteArray = f.get("props")
	for i in mini(ids.size(), codes.size()):
		var p: Variant = world_view.call("prop", ids[i])
		if not (p is Object):
			continue
		var po: Object = p
		var code := int(codes[i])
		var st := &"spent" if code == 2 else (&"armed" if code == 1 else &"idle")
		if po.get_meta("mnd_state", &"") != st and po.has_method("set_state"):
			po.set_meta("mnd_state", st)
			po.call("set_state", st)
			if po.has_method("show_tag"):
				po.call("show_tag", st == &"armed", false)
		var occ := code == 3
		if po.has_method("set_occupied") and bool(po.get_meta("mnd_occ", false)) != occ:
			po.set_meta("mnd_occ", occ)
			po.call("set_occupied", occ)
	var set3d: Variant = world_view.get("set3d")
	var decor_ids: PackedStringArray = _rec.get("decor_ids")
	var dcodes: PackedByteArray = f.get("decor")
	if set3d is Object and (set3d as Object).has_method("set_decor_visible"):
		for j in mini(decor_ids.size(), dcodes.size()):
			(set3d as Object).call("set_decor_visible", decor_ids[j], dcodes[j] == 1)


## Pause the world view and hand the characters to the reel (or give them back).
func _hold_world(on: bool) -> void:
	if world_view == null:
		return
	world_view.set_process(not on)
	for id in ["hush", "bellows"]:
		var cv: Variant = world_view.call("character", id)
		if cv is Object:
			(cv as Object).set("replay", on)


func _finish() -> void:
	var was := playing or primed
	playing = false
	primed = false
	caption.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if was:
		_hold_world(false)
	finished.emit()
