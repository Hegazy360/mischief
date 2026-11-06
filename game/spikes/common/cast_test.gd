## CastTest — a bench for RagCast: both characters stand on a floor, walk, and get clobbered every
## few seconds so the flop, the settle and the scramble-up can be reviewed as a capture.
extends Node2D

const FLOOR_Y := 760.0

var _bellows: RagCast = null
var _hush: RagCast = null
var _t := 0.0
var _next := 1.5
var _dir := 1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#F3E3CE"))
	var cam := Camera2D.new()
	cam.position = Vector2(1100, 520)
	cam.zoom = Vector2(1.9, 1.9)
	add_child(cam)
	cam.make_current()
	_bellows = RagCast.new()
	add_child(_bellows)
	_bellows.setup("bellows")
	_bellows.floor_y = FLOOR_Y
	_bellows.position = Vector2(760, FLOOR_Y - _bellows.stand_h)
	_hush = RagCast.new()
	add_child(_hush)
	_hush.setup("hush")
	_hush.floor_y = FLOOR_Y
	_hush.position = Vector2(1500, FLOOR_Y - _hush.stand_h)


func _draw() -> void:
	draw_rect(Rect2(0, FLOOR_Y, 2400, 400), Color("#C8A882"))
	draw_line(Vector2(0, FLOOR_Y), Vector2(2400, FLOOR_Y), Color("#1B2340"), 5.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _bellows.is_down():
		_bellows.walk_to(_bellows.position.x + _dir * 300.0, 240.0)
	if not _hush.is_down():
		_hush.walk_to(_hush.position.x - _dir * 300.0, 400.0)
	if _t >= _next:
		_next = _t + 4.0
		_dir = -_dir
		_bellows.hit(Vector2(520 * _dir, -520), "trip")
		_hush.hit(Vector2(-430 * _dir, -470), "bonk")
