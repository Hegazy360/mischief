## Verbs3D — renders frame-locked RGBA cut-outs of clips on the game's own RigPlayer3D (transparent background, an
## orthographic camera looking down −z like the game camera) for the 64 px verb board (r3d-anim §4.4 W1:
## tools/art3d/review/sil64.py masks … --mode=alpha) and other silhouette checks. One process, many shots:
##   tools/scripts/shot.sh res://tools/anim/Verbs3D.tscn /abs/unused.png <frames> <sandbox> -- \
##     --out=/abs/dir --items="name=hush/loco_walk@13,name2=hush/rig_low@60:facing=-1:cheat=10:prop=clarence.held"
## Per item: `<name>=<clip>@<frame>` plus optional `:facing=±1`, `:cheat=<deg>` (default: the clip's sidecar
## cheat_deg), `:prop=<id>.<state>` and `:plinth=1` (the freeze's stone plinth under her, the same plinth.glb geometry
## CharacterView3D._ensure_plinth shows in game — a statue is judged WITH it, issues.md D12). Writes
## `<out>/<name>.png` (1024 px tall RGBA). `<frames>` ≥ 6 × items + 10.
extends Node3D

const H := 1024
const W := 1024
const SETTLE := 4
const PLINTH_SCENE := "res://art3d/chars/hush/plinth.glb"   ## = CharacterView3D.PLINTH_SCENE

var _items: Array[Dictionary] = []
var _out := ""
var _vp: SubViewport = null
var _cam: Camera3D = null
var _rig: RigPlayer3D = null
var _plinth: Node3D = null
var _i := 0
var _wait := 0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out = String(args.get("out", ""))
	for spec in String(args.get("items", "")).split(",", false):
		var it := _parse(spec)
		if not it.is_empty():
			_items.append(it)
	if _out == "" or _items.is_empty():
		printerr("[verbs3d] --out=/abs/dir --items=name=clip@frame[,...] required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 3.2
	_cam.position = Vector3(0, 1.3, 8.0)
	_vp.add_child(_cam)
	_cam.make_current()
	_rig = RigPlayer3D.new()
	_rig.auto_advance = false
	_vp.add_child(_rig)
	if not _rig.setup("hush"):
		printerr("[verbs3d] rig hush failed")
	_plinth = _make_plinth()
	_vp.add_child(_plinth)
	_pose(_items[0])


## The freeze plinth at the character's origin, unscaled (the game's pop-in ends at scale 1): plinth.glb, else the
## same fallback cylinder as CharacterView3D.
static func _make_plinth() -> Node3D:
	var p: Node3D = null
	if ResourceLoader.exists(PLINTH_SCENE):
		var ps: Variant = load(PLINTH_SCENE)
		if ps is PackedScene:
			p = (ps as PackedScene).instantiate() as Node3D
	if p == null:
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.25
		cy.bottom_radius = 0.27
		cy.height = 0.12
		mi.mesh = cy
		mi.position.y = 0.06
		p = Node3D.new()
		p.add_child(mi)
	p.name = "Plinth"
	p.visible = false
	return p


static func _parse(spec: String) -> Dictionary:
	var parts := spec.split(":")
	var head := parts[0]
	if not head.contains("=") or not head.contains("@"):
		return {}
	var name := head.get_slice("=", 0)
	var cf := head.get_slice("=", 1)
	var it := {"name": name, "clip": cf.get_slice("@", 0), "frame": float(cf.get_slice("@", 1)), "facing": 1}
	for p in parts.slice(1):
		var k := p.get_slice("=", 0)
		var v := p.get_slice("=", 1)
		match k:
			"facing":
				it["facing"] = int(v)
			"cheat":
				it["cheat"] = float(v)
			"prop":
				it["prop"] = v
			"plinth":
				it["plinth"] = v == "1" or v == "true"
	return it


func _pose(it: Dictionary) -> void:
	var rig_id := String(it["clip"]).get_slice("/", 0)
	if rig_id != _rig.rig_id:
		_rig.setup(rig_id)
	_rig.reset(true)                           # props home, looks off: each cut-out starts clean
	# no cross-fade from the previous item's pose (a clip's blend_in would ghost the last cut-out into this one)
	_rig.play(String(it["clip"]), {"blend_in": 0})
	var cheat := float(it.get("cheat", -1.0))
	if cheat < 0.0:
		var c := ClipLib3D.get_clip(String(it["clip"]))
		cheat = float(c.cheat_deg) if c != null and c.cheat_deg >= 0.0 else 20.0
	_rig.set_facing(int(it["facing"]), false)
	_rig.set_cheat(cheat, 0.0)
	var pv := String(it.get("prop", ""))
	if pv.contains("."):
		_rig.set_prop(pv.get_slice(".", 0), pv.get_slice(".", 1))
	if _plinth != null:
		_plinth.visible = bool(it.get("plinth", false))
	_rig.set_external_frame(float(it["frame"]))
	_rig.advance(1.0 / 60.0)
	_wait = SETTLE


func _process(_dt: float) -> void:
	if _i >= _items.size():
		return
	_rig.set_external_frame(float(_items[_i]["frame"]))
	_rig.advance(1.0 / 60.0)
	_wait -= 1
	if _wait > 0:
		return
	var img := _vp.get_texture().get_image()
	var path := _out.path_join("%s.png" % String(_items[_i]["name"]))
	img.save_png(path)
	print("[verbs3d] %s  %s @%d" % [path, _items[_i]["clip"], int(_items[_i]["frame"])])
	_i += 1
	if _i < _items.size():
		_pose(_items[_i])
	else:
		print("[verbs3d] done: %d cut-outs" % _items.size())
