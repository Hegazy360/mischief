## SPIKE A — Physics Toybox (docs/review/pivot/index.md §3.A).
##
## The question it asks: **is the comedy funnier when the player makes it with their hands?**
##
## Everything loose in the parlour and the kitchen is a rigid body. Press on a prop and Hush picks it
## up; drag it and she hauls it about; let go with a flick and it flies. Bellows walks his tea round on
## an active ragdoll — hit him with anything moving fast enough and he goes limp, tumbles, lands flat and
## scrambles back up. Then he notices the mess, carries the prop home and carries on as if nothing had
## happened, which is the joke you can re-enter as often as you like.
##
## Nothing here is authored: no prank list, no script, no reaction clips, no scoring. The only number on
## screen is how many times you have knocked him over.
extends Node2D

const ROOMS: PackedStringArray = ["parlour", "kitchen"]
## Props: art id, home x, drawn height in px (the SVGs are authored big), mass and body radius.
const PROPS := [
	{"art": "vase", "x": 1700.0, "h": 92.0, "r": 26.0, "m": 0.8},
	{"art": "picture_frame", "x": 1900.0, "h": 104.0, "r": 34.0, "m": 1.1},
	{"art": "log_basket", "x": 2180.0, "h": 112.0, "r": 42.0, "m": 2.0},
	{"art": "tea_tray", "x": 2520.0, "h": 80.0, "r": 36.0, "m": 1.0},
	{"art": "kitchen_stool", "x": 2900.0, "h": 150.0, "r": 40.0, "m": 2.4},
	{"art": "kettle", "x": 3060.0, "h": 118.0, "r": 34.0, "m": 1.4},
	{"art": "honey_jar", "x": 3180.0, "h": 112.0, "r": 28.0, "m": 0.9},
	{"art": "pickle_jar", "x": 3300.0, "h": 112.0, "r": 28.0, "m": 1.0},
]
## Where Bellows pootles between (he starts in the kitchen, within reach of the player).
const STATIONS := [3080.0, 1760.0]
const B_SPEED := 230.0
const H_SPEED := 430.0
## A prop must be going at least this fast (px/s) to clobber him.
const HIT_SPEED := 520.0
const HIT_RADIUS := 130.0
## A prop this far from home is "a mess" and he will tidy it.
const MESS_PX := 170.0
const GRAB_PX := 230.0
const HOLD_K := 16.0
const HOLD_MAX := 2600.0

enum B { ROUND, FETCH, CARRY }

var stage: SpikeStage = null
var hush: RagCast = null
var bellows: RagCast = null
var hud: SpikeHud = null
var cam: Camera2D = null

var _props: Array[RigidBody2D] = []
var _home: Array = []
var _held: RigidBody2D = null
var _held_at: Vector2 = Vector2.ZERO
var _hush_target: float = 3400.0
var _b_state: int = B.ROUND
var _b_station: int = 0
var _b_wait: float = 0.0
var _b_prop: RigidBody2D = null
var _knockdowns: int = 0
var _hit_cool: Dictionary = {}
var _was_down: bool = false
## `emulate_touch_from_mouse`: one click arrives as a mouse button AND a touch in the same frame.
var _tap_frame: int = -1
## `--demo` plays a scripted fling so the loop can be captured without a finger on the screen.
var _demo: bool = false
var _demo_t: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1B2340"))
	stage = SpikeStage.new()
	add_child(stage)
	stage.build(ROOMS)
	for p: Dictionary in PROPS:
		_add_prop(p)
	hush = RagCast.new()
	add_child(hush)
	hush.setup("hush")
	hush.position = Vector2(3400.0, -hush.stand_h)
	bellows = RagCast.new()
	add_child(bellows)
	bellows.setup("bellows")
	bellows.position = Vector2(float(STATIONS[0]), -bellows.stand_h)
	bellows.z_index = 20
	hush.z_index = 22
	cam = Camera2D.new()
	cam.zoom = Vector2(1.45, 1.45)
	cam.position_smoothing_enabled = false
	cam.position = Vector2(hush.position.x, -300.0)
	add_child(cam)
	cam.make_current()
	_demo = OS.get_cmdline_user_args().has("--demo")
	hud = SpikeHud.new()
	add_child(hud)
	hud.hint.position.y = 62.0
	hud.hint.text = "DRAG a prop to haul and fling it   ·   TAP the floor to send Hush there   ·   knock him flat"


func _add_prop(d: Dictionary) -> void:
	var path := "res://art/house/props/%s.svg" % str(d["art"])
	if not ResourceLoader.exists(path):
		push_warning("toybox: missing %s" % path)
		return
	var body := RigidBody2D.new()
	body.collision_layer = SpikeStage.L_WORLD
	body.collision_mask = SpikeStage.L_WORLD
	body.mass = float(d["m"])
	body.gravity_scale = 1.9
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var r := float(d["r"])
	body.position = Vector2(float(d["x"]), -r)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = r
	cs.shape = circ
	body.add_child(cs)
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# the house SVGs are authored much larger than they are drawn: scale to the wanted height
	var sc := float(d["h"]) / maxf(1.0, tex.get_size().y)
	s.scale = Vector2(sc, sc)
	# the art stands on the floor: lift it so its base sits at the body's bottom
	s.position = Vector2(0, r - float(d["h"]) * 0.5)
	body.add_child(s)
	body.z_index = 30
	add_child(body)
	_props.append(body)
	_home.append(Vector2(float(d["x"]), -r))


# --- input ---------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		pressed = t.pressed
		released = not t.pressed
		at = t.position
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = m.pressed
		released = not m.pressed
		at = m.position
	elif event is InputEventScreenDrag:
		_held_at = _world((event as InputEventScreenDrag).position)
		if _held == null:
			_hush_target = _held_at.x
		return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_held_at = _world(mm.position)
			if _held == null:
				_hush_target = _held_at.x
		return
	else:
		return
	if int(Engine.get_process_frames()) == _tap_frame:
		return
	_tap_frame = int(Engine.get_process_frames())
	var w := _world(at)
	if pressed:
		_held_at = w
		_held = _prop_near(w)
		if _held != null:
			_held.gravity_scale = 0.0
		else:
			_hush_target = w.x
	elif released and _held != null:
		_held.gravity_scale = 1.9
		_held = null


func _world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen


## The prop under the finger, if Hush can reach it.
func _prop_near(w: Vector2) -> RigidBody2D:
	var best: RigidBody2D = null
	var bd := 150.0
	for p in _props:
		var d := p.global_position.distance_to(w)
		if d < bd and absf(p.global_position.x - hush.position.x) < GRAB_PX:
			bd = d
			best = p
	return best


# --- per frame -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _demo:
		_run_demo(delta)
	_drive_held(delta)
	_drive_hush(delta)
	_drive_bellows(delta)
	_check_hits()
	_follow_camera(delta)
	if bellows.is_down() and not _was_down:
		_knockdowns += 1
	_was_down = bellows.is_down()
	hud.status.text = "KNOCKED DOWN  %d        %s" % [_knockdowns,
		"he is tidying up" if _b_state != B.ROUND else "he is on his rounds"]


## A scripted version of the one thing this spike is about: pick a prop up, swing it, let go at him.
## Then it keeps its hands off, so the capture shows the flop, the scramble up and the tidying.
func _run_demo(delta: float) -> void:
	_demo_t += delta
	var kettle: RigidBody2D = _props[5] if _props.size() > 5 else null
	if kettle == null:
		return
	if _demo_t < 0.8:
		_hush_target = kettle.global_position.x + 70.0
	elif _demo_t < 1.1:
		if _held == null:
			_held = kettle
			_held.gravity_scale = 0.0
		_held_at = kettle.global_position
	elif _demo_t < 2.0:
		# wind up: lift it over her head and lean away from him
		_held_at = bellows.position + Vector2(460.0, -430.0)
	elif _demo_t < 2.25:
		if _held != null:
			# and let go, straight at him
			var dir := (bellows.position + Vector2(0, -40.0) - _held.global_position).normalized()
			_held.gravity_scale = 1.9
			_held.linear_velocity = dir * 1750.0
			_held = null
	else:
		# keep her near him afterwards, so the capture follows the flop and the tidying up
		_hush_target = bellows.position.x + 300.0


## A held prop chases the finger on a spring, so letting go throws it at whatever speed you were moving.
func _drive_held(_delta: float) -> void:
	if _held == null:
		return
	var to := _held_at - _held.global_position
	_held.linear_velocity = (to * HOLD_K).limit_length(HOLD_MAX)
	_held.angular_velocity *= 0.9


func _drive_hush(_delta: float) -> void:
	if hush.is_down():
		return
	var tx := _held.global_position.x if _held != null else _hush_target
	if _held != null:
		# stand beside whatever she is hauling, not on top of it
		tx -= signf(_held.global_position.x - hush.position.x) * 90.0
	var done := hush.walk_to(tx, H_SPEED)
	hush.pose = "carry" if (_held != null and done) else hush.pose


## His round, and the tidying loop that makes the world feel alive: anything you move, he puts back.
func _drive_bellows(delta: float) -> void:
	if bellows.is_down():
		if _b_prop != null and _b_state == B.CARRY:
			_b_prop.freeze = false
			_b_prop = null
			_b_state = B.ROUND
		return
	match _b_state:
		B.ROUND:
			# he notices a mess the moment it is made, not only when he next reaches a station
			var mess := _worst_mess()
			if mess >= 0:
				_b_prop = _props[mess]
				_b_state = B.FETCH
				_b_wait = 0.0
				return
			if _b_wait > 0.0:
				_b_wait -= delta
				bellows.pose = "idle"
				bellows.speed = 0.0
				return
			if bellows.walk_to(float(STATIONS[_b_station]), B_SPEED):
				_b_wait = 1.1
				_b_station = (_b_station + 1) % STATIONS.size()
		B.FETCH:
			if _b_prop == null:
				_b_state = B.ROUND
				return
			if bellows.walk_to(_b_prop.global_position.x, B_SPEED):
				_b_prop.freeze = true
				_b_state = B.CARRY
		B.CARRY:
			if _b_prop == null:
				_b_state = B.ROUND
				return
			var i := _props.find(_b_prop)
			var home: Vector2 = _home[i]
			_b_prop.global_position = bellows.position + Vector2(0, -110)
			bellows.pose = "carry"
			if bellows.walk_to(home.x, B_SPEED):
				_b_prop.freeze = false
				_b_prop.global_position = home
				_b_prop.linear_velocity = Vector2.ZERO
				_b_prop.angular_velocity = 0.0
				_b_prop.rotation = 0.0
				_b_prop = null
				_b_state = B.ROUND
				_b_wait = 0.5


## The prop furthest from home, or -1 when the room is tidy.
func _worst_mess() -> int:
	var worst := -1
	var wd := MESS_PX
	for i in _props.size():
		if _props[i] == _held:
			continue
		var d: float = _props[i].global_position.distance_to(_home[i])
		if d > wd:
			wd = d
			worst = i
	return worst


## Anything fast enough that reaches him knocks him flat.
func _check_hits() -> void:
	if bellows.is_down():
		return
	var torso := bellows.position
	for p in _props:
		var id := p.get_instance_id()
		var cool: float = _hit_cool.get(id, 0.0)
		if cool > Time.get_ticks_msec():
			continue
		var v := p.linear_velocity
		if v.length() < HIT_SPEED:
			continue
		if p.global_position.distance_to(torso) > HIT_RADIUS:
			continue
		_hit_cool[id] = Time.get_ticks_msec() + 900
		bellows.hit(v * 0.42 * minf(p.mass, 2.0), "bonk")
		p.linear_velocity = v * -0.3


func _follow_camera(delta: float) -> void:
	var half := get_viewport_rect().size.x * 0.5 / cam.zoom.x
	var want: float = clampf(hush.position.x, stage.x0 + half, stage.x1 - half)
	cam.position.x = lerpf(cam.position.x, want, 1.0 - pow(0.004, delta))
	cam.position.y = -300.0
