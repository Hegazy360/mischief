## PROTOTYPE 3 — "THE KEEP": a low-poly 3D toy sandbox on library assets (docs/review/pivot/next_options.md §D).
##
## A Knight (KayKit Adventurers, CC0, used as shipped) goes about his day in a stone hall: sits in his
## chair, works at his bench, waves out of the window, walks his rounds. You are the Rogue. Everything
## loose is a rigid body — crates, barrels, buckets, books, plates — and you can pick up, carry and throw
## any of it. Hit him hard enough and he staggers, goes down, lies there, gets up, looks round; if he sees
## you he chases; if not, he puts back whatever you moved and carries on. Walking into things shoves them.
##
## Not one frame of animation in this prototype is ours (KayKit Character Animations, CC0). The room is
## primitives and a palette. That is the pipeline an agent team can keep up with.
##
## Controls: TAP the floor to run there · TAP a prop to pick it up · TAP the Knight (or a prop) while
## holding to throw AT it · THROW button to lob it ahead · wheel / pinch to zoom.
## Flags: --demo (plays itself for captures) · --clicktest (self-test of the input path).
extends Node3D

const ROGUE := preload("res://proto/toyhouse/rogue_player.gd")
const KNIGHT := preload("res://proto/toyhouse/knight_npc.gd")

const HALL := Vector3(30.0, 7.5, 20.0)
const PAL := {
	"floor": Color("#7D8390"), "floor2": Color("#6E7482"), "wall": Color("#C9B99A"), "trim": Color("#8B5A2B"),
	"wood": Color("#A0622F"), "crate": Color("#C98B45"), "barrel": Color("#7A4A2A"), "hoop": Color("#3E3A36"),
	"bucket": Color("#9AA3B5"), "plate": Color("#F2EEE3"), "red": Color("#D9483B"), "blue": Color("#3E6DB5"),
	"green": Color("#4F9A5B"), "gold": Color("#E8B33A"), "purple": Color("#7B3F8C"), "cloth": Color("#B5433F"),
}

var player: RoguePlayer = null
var knight: KnightNpc = null
var cam: Camera3D = null
var props: Array = []
var hud_status: Label = null
var hud_hint: Label = null
var hud_bonk: Label = null
var throw_btn: Button = null
var _bonk_t := 0.0
var _knockdowns := 0
var _caught := 0
var _zoom := 1.0
var _tap_frame := -1
var _demo := false
var _demo_t := 0.0
var _demo_step := 0
var _trace := false
## The invisible front wall: bodies collide with it, taps must see straight through it.
var _fence: StaticBody3D = null


func _ready() -> void:
	_build_world()
	_build_props()
	_build_actors()
	_build_camera()
	_build_hud()
	var args := OS.get_cmdline_user_args()
	_demo = args.has("--demo")
	_trace = args.has("--trace")
	if args.has("--clicktest"):
		_clicktest.call_deferred()


# --- world ----------------------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


## A static box with a mesh. Centre `at`, full `size`.
func _block(at: Vector3, size: Vector3, col: Color, parent: Node3D = self) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = at
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	b.add_child(mi)
	parent.add_child(b)
	return b


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1B2340")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9DA7C8")
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	# floor: a chequer of two greys so movement reads
	var tile := 2.5
	for ix in int(HALL.x / tile):
		for iz in int(HALL.z / tile):
			var x := -HALL.x * 0.5 + tile * (float(ix) + 0.5)
			var z := -HALL.z * 0.5 + tile * (float(iz) + 0.5)
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(tile, tile)
			mi.mesh = pm
			mi.material_override = _mat(PAL["floor"] if (ix + iz) % 2 == 0 else PAL["floor2"])
			mi.position = Vector3(x, 0.0, z)
			add_child(mi)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(HALL.x + 4.0, 1.0, HALL.z + 4.0)
	fs.shape = fb
	fs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fs)
	add_child(floor_body)
	# walls (the near wall is left open so the camera sees in), with a doorway in the back wall
	var t := 0.6
	_block(Vector3(-HALL.x * 0.5 - t * 0.5, HALL.y * 0.5, 0), Vector3(t, HALL.y, HALL.z + t * 2), PAL["wall"])
	_block(Vector3(HALL.x * 0.5 + t * 0.5, HALL.y * 0.5, 0), Vector3(t, HALL.y, HALL.z + t * 2), PAL["wall"])
	var door_w := 3.4
	var back_z := -HALL.z * 0.5 - t * 0.5
	var seg := (HALL.x - door_w) * 0.5
	_block(Vector3(-door_w * 0.5 - seg * 0.5, HALL.y * 0.5, back_z), Vector3(seg, HALL.y, t), PAL["wall"])
	_block(Vector3(door_w * 0.5 + seg * 0.5, HALL.y * 0.5, back_z), Vector3(seg, HALL.y, t), PAL["wall"])
	_block(Vector3(0, HALL.y - 0.6, back_z), Vector3(door_w, 1.2, t), PAL["wall"])
	# a low front lip so props cannot roll out of frame, plus an INVISIBLE full-height front wall: the
	# camera looks in over it, but nothing — thrown, shoved or walking — can leave the hall
	_block(Vector3(0, 0.25, HALL.z * 0.5 + 0.3), Vector3(HALL.x + 1.2, 0.5, 0.6), PAL["trim"])
	var fence := StaticBody3D.new()
	_fence = fence
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(HALL.x + 2.0, HALL.y * 2.0, 0.6)
	fcs.shape = fbs
	fence.position = Vector3(0, HALL.y, HALL.z * 0.5 + 0.9)
	fence.add_child(fcs)
	add_child(fence)
	# window frames on the right wall (decor)
	for z in [-5.0, 5.0]:
		_block(Vector3(HALL.x * 0.5 - 0.1, 2.8, z), Vector3(0.25, 1.8, 1.8), Color("#8FC3E8"))
	# furniture: long table, two benches, the Knight's chair, a workbench, a bookshelf
	_block(Vector3(0, 1.15, -2.0), Vector3(7.0, 0.3, 1.8), PAL["wood"])
	for sx in [-3.0, 3.0]:
		for sz in [-0.6, 0.6]:
			_block(Vector3(sx, 0.55, -2.0 + sz), Vector3(0.3, 1.1, 0.3), PAL["trim"])
	# the Knight's chair: the back is solid, the seat is visual only so he can actually stand (and sit) on it
	_block(Vector3(-9.0, 1.9, -6.4), Vector3(1.6, 1.8, 0.3), PAL["purple"])
	var seat := MeshInstance3D.new()
	var seat_m := BoxMesh.new()
	seat_m.size = Vector3(1.6, 1.1, 1.5)
	seat.mesh = seat_m
	seat.material_override = _mat(PAL["purple"])
	seat.position = Vector3(-9.0, 0.55, -5.5)
	add_child(seat)
	_block(Vector3(10.5, 1.0, -7.4), Vector3(4.0, 0.25, 1.6), PAL["wood"])        # workbench
	_block(Vector3(10.5, 0.45, -7.4), Vector3(3.6, 0.9, 1.2), PAL["trim"])
	_block(Vector3(-13.3, 1.6, -3.0), Vector3(0.9, 3.2, 4.0), PAL["trim"])       # bookshelf back
	for sh in [0.6, 1.5, 2.4]:
		_block(Vector3(-12.9, sh, -3.0), Vector3(1.1, 0.12, 4.0), PAL["wood"])
	# a rug under the table
	var rug := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(9.0, 4.5)
	rug.mesh = rm
	rug.material_override = _mat(PAL["cloth"])
	rug.position = Vector3(0, 0.02, -2.0)
	add_child(rug)


## A loose prop: rigid body, primitive mesh, a `home` it belongs at and a `size` for the hit test.
func _prop(kind: String, at: Vector3, size: Vector3, col: Color, mass: float, shape: String = "box") -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.position = at
	b.continuous_cd = true
	b.can_sleep = true
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	match shape:
		"cyl":
			var c := CylinderShape3D.new()
			c.radius = size.x * 0.5
			c.height = size.y
			cs.shape = c
			var cm := CylinderMesh.new()
			cm.top_radius = size.x * 0.5
			cm.bottom_radius = size.x * 0.5
			cm.height = size.y
			mi.mesh = cm
		"ball":
			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			cs.shape = s
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.x
			mi.mesh = sm
		_:
			var bx := BoxShape3D.new()
			bx.size = size
			cs.shape = bx
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
	mi.material_override = _mat(col)
	b.add_child(cs)
	b.add_child(mi)
	b.set_meta("home", at)
	b.set_meta("kind", kind)
	b.set_meta("size", maxf(size.x, maxf(size.y, size.z)))
	add_child(b)
	props.append(b)
	return b


func _build_props() -> void:
	# crates by the door, barrels along the wall, buckets by the bench, books on the shelf, plates on the table
	for i in 6:
		var x := -4.0 + float(i % 3) * 1.1
		var y := 0.45 + float(i / 3) * 0.9
		_prop("crate", Vector3(x, y, 7.2), Vector3(0.9, 0.9, 0.9), PAL["crate"], 2.5)
	for i in 4:
		_prop("barrel", Vector3(7.0 + float(i) * 1.3, 0.6, 7.6), Vector3(1.0, 1.2, 1.0), PAL["barrel"], 4.0, "cyl")
	for i in 3:
		_prop("bucket", Vector3(8.5 + float(i) * 0.8, 0.3, -5.6), Vector3(0.55, 0.6, 0.55), PAL["bucket"], 1.2, "cyl")
	var book_cols: Array[Color] = [PAL["red"], PAL["blue"], PAL["green"], PAL["gold"], PAL["purple"]]
	var bi := 0
	for sh in [0.6, 1.5, 2.4]:
		for k in 5:
			_prop("book", Vector3(-12.9, sh + 0.06 + 0.28, -4.6 + float(k) * 0.72), Vector3(0.5, 0.56, 0.36),
				book_cols[bi % book_cols.size()], 0.6)
			bi += 1
	for i in 6:
		_prop("plate", Vector3(-2.5 + float(i) * 1.0, 1.34, -2.0), Vector3(0.55, 0.08, 0.55), PAL["plate"], 0.5, "cyl")
	_prop("ball", Vector3(3.0, 0.4, 4.0), Vector3(0.8, 0.8, 0.8), PAL["gold"], 1.0, "ball")


func _build_actors() -> void:
	player = ROGUE.new()
	add_child(player)
	player.setup("Rogue", 2.15, 0.5)
	player.position = Vector3(1.0, 0.0, 6.0)
	player.face_yaw = PI
	knight = KNIGHT.new()
	add_child(knight)
	knight.setup("Knight", 2.5, 0.55)
	knight.position = Vector3(-9.0, 0.0, -4.0)
	knight.props = props
	knight.player = player
	knight.stations = [
		{"pos": Vector3(-9.0, 0.0, -5.3), "look": Vector3(-9.0, 0.0, 5.0), "clip": "", "dur": 7.0, "sit": true, "label": "sitting in his chair"},
		{"pos": Vector3(10.5, 0.0, -5.8), "look": Vector3(10.5, 0.0, -9.0), "clip": "Working_A", "dur": 6.0, "label": "working at his bench"},
		{"pos": Vector3(13.2, 0.0, 5.0), "look": Vector3(20.0, 0.0, 5.0), "clip": "Waving", "dur": 3.5, "label": "waving out of the window"},
		{"pos": Vector3(0.0, 0.0, 3.5), "look": Vector3(0.0, 0.0, -5.0), "clip": "Idle_B", "dur": 3.0, "label": "admiring his table"},
	]
	knight.knocked_down.connect(_on_knocked)
	knight.caught_player.connect(_on_caught)
	knight.state_changed.connect(func(_l: String) -> void: _refresh_hud())
	knight.begin()


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 46.0
	add_child(cam)
	cam.make_current()
	_place_camera(1.0)


## Three-quarter view that keeps you in the middle third and leans toward the Knight, pulling back a
## little as the two of you get further apart so he is rarely off-screen.
func _place_camera(k: float) -> void:
	var pp := player.global_position
	var kp := knight.global_position if knight != null else pp
	var to_k := kp - pp
	to_k.y = 0.0
	# lean at most 2.5 m toward him: you stay in the middle of the frame, he gets pulled in from the edge
	var focus := pp + to_k.limit_length(2.5) + Vector3(0, 1.3, 0)
	var far: float = clampf(to_k.length() / 16.0, 1.0, 1.25)
	var want := focus + Vector3(0.0, 6.6, 8.6) * _zoom * far
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(focus, Vector3.UP)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_status = _label(layer, 30, Vector2(28, 18), Color("#FFF4E0"))
	hud_hint = _label(layer, 19, Vector2(28, 62), Color("#FFD98A"))
	hud_hint.text = "TAP the floor to run  ·  TAP a crate, barrel, bucket, book or plate to pick it up  ·  TAP the Knight to throw it at him  ·  THROW lobs it ahead"
	hud_bonk = _label(layer, 132, Vector2(0, 0), Color("#FFC93C"))
	hud_bonk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_bonk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_bonk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_bonk.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	hud_bonk.visible = false
	throw_btn = Button.new()
	throw_btn.text = "THROW"
	throw_btn.add_theme_font_size_override("font_size", 34)
	throw_btn.custom_minimum_size = Vector2(260, 92)
	throw_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	throw_btn.position = Vector2(-300, -130)
	throw_btn.visible = false
	throw_btn.pressed.connect(func() -> void: player.throw_at(Vector3.ZERO, false))
	layer.add_child(throw_btn)
	_refresh_hud()


func _label(parent: Node, size: int, at: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0E1328"))
	l.add_theme_constant_override("outline_size", 10)
	parent.add_child(l)
	return l


func _refresh_hud() -> void:
	if hud_status == null:
		return
	hud_status.text = "KNOCKDOWNS %d   ·   CAUGHT %d   ·   the Knight is %s" % [_knockdowns, _caught, knight.label()]


func _on_knocked() -> void:
	_knockdowns += 1
	_bonk_t = 1.2
	hud_bonk.text = ["BONK!", "CLANG!", "OOF!", "WHUMP!"][_knockdowns % 4]
	hud_bonk.visible = true
	_refresh_hud()


func _on_caught() -> void:
	_caught += 1
	player.knocked(knight.global_position)
	_refresh_hud()


# --- input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom = clampf(_zoom / (event as InputEventMagnifyGesture).factor, 0.55, 1.7)
		return
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 0.92, 0.55, 1.7)
			return
		if m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 0.92, 0.55, 1.7)
			return
	var at := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			at = mb.position
	if at == Vector2.INF or int(Engine.get_process_frames()) == _tap_frame:
		return
	_tap_frame = int(Engine.get_process_frames())
	_tap(at)


## A tap: a ray into the hall. Knight → throw at him or go to him; prop → throw at it or pick it up;
## floor → run there (carrying whatever you hold).
func _tap(screen: Vector2) -> void:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = false
	if _fence != null:
		q.exclude = [_fence.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var body: Object = hit.get("collider")
	var point: Vector3 = hit.get("position", Vector3.ZERO)
	if _trace:
		print("[tap] hit %s at %s  (holding=%s, player state=%d)" % [str(body.get_meta("kind", body.get_class()) if body is Node else body),
			str(point.snapped(Vector3(0.1, 0.1, 0.1))), str(player.is_holding()), player.state])
	if body == knight:
		if player.is_holding():
			player.throw_at(knight.global_position + Vector3(0, 1.4, 0))
		else:
			player.go_to(knight.global_position + (player.global_position - knight.global_position).normalized() * 2.2)
		return
	if body is RigidBody3D and props.has(body):
		if player.is_holding():
			player.throw_at((body as RigidBody3D).global_position)
		else:
			player.grab(body as RigidBody3D)
		return
	player.go_to(Vector3(point.x, 0.0, point.z))


func _process(delta: float) -> void:
	_place_camera(1.0 - pow(0.002, delta))
	throw_btn.visible = player.is_holding()
	if _bonk_t > 0.0:
		_bonk_t -= delta
		hud_bonk.modulate.a = clampf(_bonk_t / 0.4, 0.0, 1.0)
		hud_bonk.scale = Vector2.ONE * (1.0 + (1.2 - _bonk_t) * 0.35)
		if _bonk_t <= 0.0:
			hud_bonk.visible = false
	if _demo:
		_run_demo(delta)


# --- demo / self-test -------------------------------------------------------------------------------

## Plays itself: fetch a crate, carry it to within range of the Knight, wait until he has settled at a
## station, throw, then slip away behind the crates so the capture shows him get up and tidy.
func _run_demo(delta: float) -> void:
	_demo_t += delta
	if _trace and Engine.get_physics_frames() % 30 == 0:
		print("[demo] f=%d step=%d pstate=%d pos=%s tgt=%s floor=%s hold=%s | knight=%s kstate=%d" % [
			Engine.get_physics_frames(), _demo_step, player.state, str(player.global_position.snapped(Vector3(0.1,0.1,0.1))),
			str(player.target.snapped(Vector3(0.1,0.1,0.1))), str(player.is_on_floor()), str(player.is_holding()),
			str(knight.global_position.snapped(Vector3(0.1,0.1,0.1))), knight.state])
	match _demo_step:
		0:
			if _demo_t > 0.6:
				var pick := _nearest_loose_crate()
				if pick != null:
					player.grab(pick)
				_demo_step = 1
		1:
			if player.is_holding() and player.state == RoguePlayer.S.IDLE:
				player.go_to(_stand_off(knight.global_position, 6.0))
				_demo_step = 2
				_demo_t = 0.0
		2:
			if not player.is_holding():
				_demo_step = 0
			elif player.state == RoguePlayer.S.IDLE:
				if knight.global_position.distance_to(player.global_position) > 8.0:
					player.go_to(_stand_off(knight.global_position, 6.0))
				elif knight.state == KnightNpc.S.ROUTINE_ACT or _demo_t > 6.0:
					player.throw_at(knight.global_position + Vector3(0, 1.4, 0))
					_demo_step = 3
					_demo_t = 0.0
		3:
			if _demo_t > 0.9:
				player.go_to(Vector3(-6.5, 0.0, 8.2))
				_demo_step = 4
				_demo_t = 0.0
		4:
			if _demo_t > 10.0:
				_demo_step = 0
				_demo_t = 0.0


## A floor point `d` metres from `p`, toward the middle of the hall, kept inside the walls.
func _stand_off(p: Vector3, d: float) -> Vector3:
	var centre := Vector3(0, 0, 1.0)
	var dir := (centre - p)
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	var q := p + dir.normalized() * d
	return Vector3(clampf(q.x, -HALL.x * 0.5 + 1.5, HALL.x * 0.5 - 1.5), 0.0, clampf(q.z, -HALL.z * 0.5 + 1.5, HALL.z * 0.5 - 1.5))


func _nearest_loose_crate() -> RigidBody3D:
	var best: RigidBody3D = null
	var bd := 1.0e9
	for p: RigidBody3D in props:
		if str(p.get_meta("kind", "")) != "crate" or p.freeze:
			continue
		var d := p.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


## Push real clicks through the real input path and assert the game moved.
func _clicktest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var fails := 0
	var p0 := player.global_position
	var floor_target := Vector3(6.0, 0.0, 4.0)
	await _click(cam.unproject_position(floor_target))
	for i in 90:
		await get_tree().process_frame
	var moved := player.global_position.distance_to(p0)
	print("[clicktest] floor tap: moved %.2f m (want > 1)" % moved)
	if moved < 1.0:
		fails += 1
	var crate: RigidBody3D = _nearest_loose_crate()
	await _click(cam.unproject_position(crate.global_position))
	for i in 200:
		await get_tree().process_frame
	print("[clicktest] crate tap: holding=%s (want true)" % str(player.is_holding()))
	if not player.is_holding():
		fails += 1
	await _click(cam.unproject_position(knight.global_position + Vector3(0, 1.4, 0)))
	for i in 30:
		await get_tree().process_frame
	print("[clicktest] knight tap while holding: holding=%s (want false, it was thrown)" % str(player.is_holding()))
	if player.is_holding():
		fails += 1
	print("[clicktest] knight label now: '%s'   knockdowns=%d" % [knight.label(), _knockdowns])
	print("[clicktest] %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
	await get_tree().process_frame
