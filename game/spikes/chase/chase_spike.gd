## SPIKE C — The Chase (docs/review/pivot/index.md §3.C).
##
## The question it asks: **if the waiting is replaced by a pursuer, is it still funny — or just tense?**
##
## He has seen you. He is coming, slowly, through the whole house, and he never stops. You run ahead and
## arm traps in his path as you pass them: the rug slips him off his feet, the marbles send him skating,
## the bucket drops over his eyes, the door swings into his face. Every trap he hits is a ragdoll tumble,
## a laugh and a few metres of lead. Every one you fumble, he gets closer.
##
## There is no fast-forward button in this spike, because there is nothing to wait for. No script, no
## prank list, no reaction clips: the falls are the same procedural ragdoll Spike A uses.
extends Node2D

const ROOMS: PackedStringArray = ["hall", "parlour", "kitchen"]
const H_SPEED := 520.0
const B_SPEED := 300.0
## He has to be this close to arm a trap's trigger, and this close to Hush to catch her.
const TRAP_FIRE_PX := 70.0
const CATCH_PX := 86.0
## Hush can ask for a trap from this far, but she has to go and crouch over it to set it — that
## second and a bit, with him coming, is the whole decision in this spike.
const ARM_PX := 460.0
const ARM_REACH := 64.0
const ARM_TIME := 0.42
## Extra seconds he loses AFTER picking himself up. The tumble itself already costs him about 1.5 s,
## and a chase that stops for four seconds stops being a chase.
const STALL := {"rug": 0.35, "marbles": 0.5, "bucket": 0.8, "door": 0.45}
## How long the bucket leaves him groping.
const BLIND_S := 4.5

## The traps: kind, x, the art that shows it, and how high the art sits.
const TRAPS := [
	{"kind": "rug", "x": 780.0, "art": "hall_runner", "h": 38.0},
	{"kind": "door", "x": 1480.0, "art": "parlour_door", "h": 320.0},
	{"kind": "marbles", "x": 1900.0, "art": "", "h": 0.0},
	{"kind": "bucket", "x": 2320.0, "art": "", "h": 0.0},
	{"kind": "rug", "x": 2660.0, "art": "hall_runner", "h": 38.0},
	{"kind": "door", "x": 2810.0, "art": "parlour_door", "h": 320.0},
	{"kind": "marbles", "x": 3180.0, "art": "", "h": 0.0},
	{"kind": "bucket", "x": 3560.0, "art": "", "h": 0.0},
]

## One trap on the floor.
class Trap extends RefCounted:
	var kind: String = ""
	var x: float = 0.0
	var armed: bool = false
	var spent: bool = false
	var node: Node2D = null

var stage: SpikeStage = null
var hush: RagCast = null
var bellows: RagCast = null
var hud: SpikeHud = null
var cam: Camera2D = null

var _traps: Array[Trap] = []
var _hush_target: float = 0.0
var _stall: float = 0.0
var _landed: int = 0
var _caught: int = 0
var _blind: float = 0.0
var _demo: bool = false
var _demo_t: float = 0.0
var _best_lead: float = 0.0
var _arm_target: Trap = null
var _arm_t: float = 0.0
var _survived: float = 0.0
## `emulate_touch_from_mouse`: one click arrives as a mouse button AND a touch in the same frame.
var _tap_frame: int = -1


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1B2340"))
	stage = SpikeStage.new()
	add_child(stage)
	stage.build(ROOMS)
	for t: Dictionary in TRAPS:
		_add_trap(t)
	hush = RagCast.new()
	add_child(hush)
	hush.setup("hush")
	hush.position = Vector2(1400.0, -hush.stand_h)
	hush.z_index = 22
	_hush_target = hush.position.x
	bellows = RagCast.new()
	add_child(bellows)
	bellows.setup("bellows")
	bellows.position = Vector2(620.0, -bellows.stand_h)
	bellows.z_index = 20
	cam = Camera2D.new()
	cam.zoom = Vector2(1.3, 1.3)
	cam.position_smoothing_enabled = false
	cam.position = Vector2(hush.position.x, -300.0)
	add_child(cam)
	cam.make_current()
	_demo = OS.get_cmdline_user_args().has("--demo")
	hud = SpikeHud.new()
	add_child(hud)
	hud.hint.position.y = 62.0
	hud.hint.text = "TAP ahead to run   ·   TAP a gold trap: she runs over and SETS it (that costs you time)   ·   the house has two ends"


func _add_trap(d: Dictionary) -> void:
	var t := Trap.new()
	t.kind = str(d["kind"])
	t.x = float(d["x"])
	var n := Node2D.new()
	n.position = Vector2(t.x, 0)
	n.z_index = 10
	n.draw.connect(_draw_trap.bind(n, t))
	add_child(n)
	t.node = n
	_traps.append(t)


## Traps are drawn, not arted: a spike should not wait on an artist. Colour says the state —
## grey = out of reach, gold = tap me, red = armed and waiting for him.
func _draw_trap(n: Node2D, t: Trap) -> void:
	if t.spent:
		n.draw_circle(Vector2(0, -8), 10.0, Color(0.45, 0.45, 0.45, 0.5))
		return
	var reach: bool = absf(hush.position.x - t.x) < ARM_PX
	var col := Color("#E23B4E") if t.armed else (Color("#FFC93C") if reach else Color(1, 1, 1, 0.3))
	match t.kind:
		"rug":
			n.draw_rect(Rect2(-95, -20, 190, 20), col)
			n.draw_rect(Rect2(-95, -20, 190, 20), Color("#1B2340"), false, 4.0)
		"marbles":
			for i in 7:
				n.draw_circle(Vector2(-78 + i * 26, -11), 11.0, col)
		"bucket":
			n.draw_rect(Rect2(-40, -470, 80, 64), col)
			n.draw_rect(Rect2(-40, -470, 80, 64), Color("#1B2340"), false, 4.0)
			n.draw_line(Vector2(0, -406), Vector2(0, -330), Color(1, 1, 1, 0.25), 3.0)
		"door":
			n.draw_rect(Rect2(-18, -430, 36, 430), col)
			n.draw_rect(Rect2(-18, -430, 36, 430), Color("#1B2340"), false, 4.0)
	if t.armed:
		n.draw_circle(Vector2(0, -500), 13.0, Color("#E23B4E"))


# --- input ---------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
			return
		at = m.position
	else:
		return
	if int(Engine.get_process_frames()) == _tap_frame:
		return
	_tap_frame = int(Engine.get_process_frames())
	_tap(get_viewport().get_canvas_transform().affine_inverse() * at)


## A tap arms the nearest trap in reach, or sends her running.
func _tap(w: Vector2) -> void:
	var best: Trap = null
	var bd := 220.0
	for t in _traps:
		if t.armed or t.spent or absf(hush.position.x - t.x) > ARM_PX:
			continue
		var d: float = absf(t.x - w.x)
		if d < bd:
			bd = d
			best = t
	if best != null:
		_arm_target = best
		_arm_t = 0.0
		_hush_target = best.x
		return
	_arm_target = null
	_hush_target = clampf(w.x, stage.x0 + 60.0, stage.x1 - 60.0)


# --- per frame -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _demo:
		_run_demo(delta)
	_survived += delta
	if not hush.is_down():
		hush.walk_to(_hush_target, H_SPEED)
		_drive_arming(delta)
	_drive_bellows(delta)
	_check_traps()
	_check_catch()
	for t in _traps:
		t.node.queue_redraw()
	var lead: float = hush.position.x - bellows.position.x
	_best_lead = maxf(_best_lead, lead)
	cam.position.x = lerpf(cam.position.x, _cam_want(), 1.0 - pow(0.002, delta))
	cam.position.y = -300.0
	var setting := "   ·   SETTING…" if _arm_target != null and _arm_t > 0.0 else ""
	var state := "DOWN" if bellows.is_down() else ("BLIND" if _blind > 0.0 else "COMING")
	hud.status.text = "LEAD %4d px     TRAPS %d     CAUGHT %d     %ds     he is %s%s" % [
		int(lead), _landed, _caught, int(_survived), state, setting]


## Setting a trap: she has to stand over it and crouch, and she cannot run while she does.
func _drive_arming(delta: float) -> void:
	if _arm_target == null:
		return
	if _arm_target.spent or _arm_target.armed:
		_arm_target = null
		return
	if absf(hush.position.x - _arm_target.x) > ARM_REACH:
		_arm_t = 0.0
		return
	_arm_t += delta
	hush.pose = "carry"
	hush.speed = 0.0
	_hush_target = hush.position.x
	if _arm_t >= ARM_TIME:
		_arm_target.armed = true
		_arm_target.node.queue_redraw()
		_arm_target = null
		_arm_t = 0.0


## Frame the pair while he is close (you must see him coming), and fall back to following Hush once
## the lead is too wide to hold both — otherwise she runs off her own screen.
func _cam_want() -> float:
	var half := get_viewport_rect().size.x * 0.5 / cam.zoom.x
	var lead := hush.position.x - bellows.position.x
	var mid := (hush.position.x + bellows.position.x) * 0.5
	var t: float = clampf((absf(lead) - half * 0.8) / (half * 0.6), 0.0, 1.0)
	var follow := hush.position.x - signf(lead) * half * 0.35
	return clampf(lerpf(mid, follow, t), stage.x0 + half, stage.x1 - half)


## He never stops coming. A trap stalls him; a bucket leaves him groping blind and slow.
func _drive_bellows(delta: float) -> void:
	if bellows.is_down():
		return
	if _stall > 0.0:
		_stall -= delta
		bellows.pose = "blind" if _blind > 0.0 else "idle"
		bellows.speed = 0.0
		return
	_blind = maxf(0.0, _blind - delta)
	var sp := B_SPEED * (0.45 if _blind > 0.0 else 1.0)
	bellows.walk_to(hush.position.x, sp)
	if _blind > 0.0:
		bellows.pose = "blind"


## An armed trap fires when he walks over it.
func _check_traps() -> void:
	if bellows.is_down() or _stall > 0.0:
		return
	for t in _traps:
		if not t.armed or t.spent:
			continue
		if absf(bellows.position.x - t.x) > TRAP_FIRE_PX:
			continue
		t.spent = true
		t.armed = false
		_landed += 1
		_stall = float(STALL[t.kind])
		var away := signf(bellows.position.x - hush.position.x)
		if away == 0.0:
			away = -1.0
		match t.kind:
			"rug":
				bellows.hit(Vector2(-away * 420.0, -260.0), "trip")
			"marbles":
				bellows.hit(Vector2(-away * 700.0, -120.0), "slide")
			"door":
				bellows.hit(Vector2(away * 520.0, -300.0), "bonk")
			"bucket":
				_blind = BLIND_S
				bellows.hit(Vector2(0.0, 120.0), "bonk")
		t.node.queue_redraw()


## He touches her: a gag, then she is put back at the start of the house and the traps reset.
func _check_catch() -> void:
	if bellows.is_down() or hush.is_down() or _stall > 0.0:
		return
	if absf(bellows.position.x - hush.position.x) > CATCH_PX:
		return
	_caught += 1
	_arm_target = null
	# he grabs her, she wriggles free and is dumped a few paces off; he stands there fuming
	var away := signf(hush.position.x - bellows.position.x)
	if away == 0.0:
		away = 1.0
	hush.hit(Vector2(away * 520.0, -540.0), "bonk")
	bellows.position.x -= away * 300.0
	_stall = 1.1
	for t in _traps:
		t.spent = false
		t.armed = false


## A scripted run so the chase can be captured without a finger: run right, arm each trap in reach.
func _run_demo(delta: float) -> void:
	_demo_t += delta
	if _arm_target != null:
		return
	# head for the far end, stopping to set every trap on the way
	for t in _traps:
		if t.armed or t.spent:
			continue
		var d: float = t.x - hush.position.x
		if d > -20.0 and d < ARM_PX:
			_arm_target = t
			_arm_t = 0.0
			_hush_target = t.x
			return
	_hush_target = stage.x1 - 120.0
