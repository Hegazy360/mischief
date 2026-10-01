## Cast — the stage door's live cast sheet (Gate 0 G3; s2-night §4.1; R3D brief r3d-night §4.3).
## Hush and Bellows as the game's own RigPlayer3D on the lane at
## the base framing (REDESIGN §5.2: FOV 30°, 7.5 m in front of the lane, y 1.9 aimed at 1.35), on a plain lit stage.
## "Next" cycles both through idle → snicker → freeze (Hush turns to marble on her stone plinth) → take (Bellows'
## CHOO frame of the sneeze, held); "Turn" rotates both by 45° (a turntable); "Back" returns to the stage door. A
## clip that has not landed yet shows the rig's idle (the label says which clip is missing).
## (The Stage-2 2D sheet was removed with the 2D view, r3d-integrate.)
class_name CastPage
extends Control

const BEATS: PackedStringArray = ["idle", "snicker", "freeze", "take"]
## rig → [clip, frame (−1 = play it looped)] per beat (3D). The take holds Bellows on the CHOO (the sneeze's accent).
const CLIPS3D := {
	"hush": [["hush/loco_idle", -1], ["hush/act_snicker", -1], ["hush/freeze_1", 40], ["hush/loco_idle", -1]],
	"bellows": [["bellows/loco_idle", -1], ["bellows/st_smirk", -1], ["bellows/st_suspicious", -1],
		["bellows/rx_sneeze_blast_a", 94]],
}
const RIGS3D: PackedStringArray = ["hush", "bellows"]
## 3D: lane x (m) of each actor and the camera (REDESIGN §5.2 base framing).
const LANE_X := {"hush": -1.25, "bellows": 1.35}
const CAM_POS := Vector3(0.0, 1.9, 6.5)
const CAM_AIM := Vector3(0.0, 1.35, -1.0)
const PLINTH := "res://art3d/chars/hush/plinth.glb"

var beat: int = 0
var skin: String = ""
var players: Dictionary = {}          ## rig → RigPlayer3D
var buttons: Dictionary = {}
## Always true (the 2D page was removed; kept for callers).
var view3d: bool = true
## 3D: the turntable yaw (degrees) and the clips of this beat that have not landed.
var yaw: float = 0.0
var missing: PackedStringArray = PackedStringArray()
var _labels: Dictionary = {}
var _pivots: Dictionary = {}
var _plinth: Node3D = null
var _cam: Camera3D = null


func _init() -> void:
	name = "Cast"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()


func _ready() -> void:
	skin = String(ViewKit.setting("hush_skin", ""))
	_build3d()
	resized.connect(_layout)
	_layout()
	set_beat(0)
	# shots: `--beat=0..3` and `--turn=<deg>`
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--beat="):
			set_beat(clampi(int(a.substr(7)), 0, BEATS.size() - 1))
		elif a.begins_with("--turn="):
			turn(float(a.substr(7)))



func _build3d() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = View3DConst.BG
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	add_child(StageLighting3D.new())
	_cam = Camera3D.new()
	_cam.name = "CastCamera"
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.fov = View3DConst.CAM_FOV_DEG
	_cam.near = View3DConst.CAM_NEAR
	_cam.far = View3DConst.CAM_FAR
	add_child(_cam)
	_cam.look_at_from_position(CAM_POS, CAM_AIM, Vector3.UP)
	_cam.current = true
	_add_stage_mesh(Vector3(0.0, -0.01, -1.2), Vector3(14.0, 0.02, 2.8), Color("#8E6E52"))
	_add_stage_mesh(Vector3(0.0, 1.6, -2.45), Vector3(14.0, 3.2, 0.1), Color("#C7B684"))
	_add_stage_mesh(Vector3(0.0, 0.45, -2.38), Vector3(14.0, 0.9, 0.06), Color("#AE9C70"))
	for id in RIGS3D:
		var pivot := Node3D.new()
		pivot.name = "Pivot_" + id
		pivot.position = Vector3(float(LANE_X[id]), 0.0, View3DConst.LANE_Z)
		add_child(pivot)
		_pivots[id] = pivot
		var rp := RigPlayer3D.new()
		rp.name = "Rig3D_" + id
		pivot.add_child(rp)
		rp.setup(id, String(ViewKit.setting("hush_head", "")) if id == "hush" else "")
		rp.set_facing(1 if id == "hush" else -1, false)
		rp.set_cheat(View3DConst.CHEAT_IDLE, 0.0)
		players[id] = rp
		_add_label(id)
	if ResourceLoader.exists(PLINTH):
		var ps: Variant = load(PLINTH)
		if ps is PackedScene:
			_plinth = (ps as PackedScene).instantiate() as Node3D
			if _plinth != null:
				CastPage.stone(_plinth)
				(_pivots["hush"] as Node3D).add_child(_plinth)
				_plinth.visible = false
	_add_buttons([["next", "stage_door.cast_next", UiKit.GOLD, UiKit.GOLD_SHADE], ["turn", "stage_door.cast_turn",
		UiKit.CREAM, UiKit.CREAM_SHADE], ["back", "stage_door.back", UiKit.CREAM, UiKit.CREAM_SHADE]])


## The plinth glb carries a bare `hush_prop` StandardMaterial3D (no palette texture), which renders black in the
## toon world (no lights): every mesh gets the set shader in stone, like CharacterView3D's stand-in plinth.
static func stone(root: Node) -> void:
	if root is MeshInstance3D:
		var m := ShaderMaterial.new()
		m.shader = load(View3DConst.SH_SET)
		m.set_shader_parameter("albedo_color", View3DConst.STONE)
		(root as MeshInstance3D).material_override = m
	for c in root.get_children():
		CastPage.stone(c)


func _add_stage_mesh(pos: Vector3, size_m: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size_m
	mi.mesh = bm
	var sm := ShaderMaterial.new()
	sm.shader = load(View3DConst.SH_SET)
	sm.set_shader_parameter("albedo_color", col)
	sm.set_shader_parameter("stage_light", 1.0)
	mi.material_override = sm
	mi.position = pos
	add_child(mi)


func _add_label(id: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", UiKit.ui_font())
	l.add_theme_font_size_override("font_size", UiKit.SIZE_MIN)
	l.add_theme_color_override("font_color", UiKit.CREAM)
	l.add_theme_color_override("font_outline_color", UiKit.NAVY)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	_labels[id] = l


func _add_buttons(specs: Array) -> void:
	for spec in specs:
		var b := UiButton.make(StageDoor.label(String(spec[1])), Vector2(360, 144), spec[2], spec[3])
		b.name = "Btn_" + String(spec[0])
		b.pressed.connect(press.bind(String(spec[0])))
		add_child(b)
		buttons[String(spec[0])] = b


func _layout() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	var floor_y := vs.y * 0.74
	for id in RIGS3D:
		var l: Label = _labels[id]
		var p := Vector2(vs.x * (0.35 if id == "hush" else 0.65), floor_y)
		if _cam != null and _cam.is_inside_tree():
			p = _cam.unproject_position(Vector3(float(LANE_X[id]), 0.0, View3DConst.LANE_Z))
		l.position = Vector2(p.x - 300.0, minf(p.y + 24.0, vs.y - 90.0))
		l.size = Vector2(600, 60)
	var by := 40.0
	var bx := vs.x - 48.0
	for id in ["next", "turn", "back"]:
		if not buttons.has(id):
			continue
		var b: UiButton = buttons[id]
		bx -= b.size.x
		b.position = Vector2(bx, by)
		bx -= 24.0


## next | turn | back
func press(id: String) -> void:
	match id:
		"next":
			set_beat((beat + 1) % BEATS.size())
		"turn":
			turn(45.0)
		"back":
			get_tree().change_scene_to_file(StageDoor.SCENE)


## 3D: rotate both actors by `deg` on their turntables.
func turn(deg: float) -> void:
	yaw = fposmod(yaw + deg, 360.0)
	for id in _pivots:
		(_pivots[id] as Node3D).rotation_degrees.y = yaw


## Show beat `i` on every actor.
func set_beat(i: int) -> void:
	beat = i
	_set_beat3d(i)


func _set_beat3d(i: int) -> void:
	missing.clear()
	for id in RIGS3D:
		var spec: Array = (CLIPS3D[id] as Array)[i]
		var clip := String(spec[0])
		var fr := int(spec[1])
		var rp: RigPlayer3D = players[id]
		var ok := ClipMap.clip_exists3d(clip)
		var play := clip if ok else "%s/loco_idle" % id
		if not ok:
			missing.append(clip)
		if ClipMap.clip_exists3d(play):
			rp.release_external()
			rp.play(play, {"loop": fr < 0 or not ok, "blend_in": 6, "start_frame": maxf(0.0, float(fr))})
			if fr >= 0 and ok:
				rp.set_external_frame(float(fr))
		var frozen := id == "hush" and BEATS[i] == "freeze"
		rp.set_stone(frozen, 0.1)
		if id == "hush" and _plinth != null:
			_plinth.visible = frozen
		var nm := "Hush" if id == "hush" else "Bellows"
		(_labels[id] as Label).text = "%s · %s%s" % [nm, BEATS[i], "" if ok else " (%s not in yet)" % clip.get_file()]


func handle_back() -> bool:
	press("back")
	return true


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(260.0, 110.0), UiStrings.t("stage_door.cast"),
		UiKit.SIZE_TITLE, UiKit.GOLD_LIGHT, 16)
