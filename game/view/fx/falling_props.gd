## FxFallingProps — T3 falling props and Meltdown quake drops (GDD §4.5, §5.8): a picture
## frame, his hat, a sausage, a pan… drops from the ceiling onto his head (bonk, bounce off,
## spin to rest on the floor). Pooled (6), view time, one texture per prop.
class_name FxFallingProps
extends Node2D

const POOL := 6
const G := 2600.0
const REST_S := 1.4

## Emitted on each head hit (sfx / shake / stars).
signal bonked(world_pos: Vector2)


class Drop:
	var active: bool = false
	var tex: Texture2D = null
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var rot: float = 0.0
	var spin: float = 0.0
	var head_y: float = 0.0
	var floor_y: float = 0.0
	var hit: bool = false
	var rest: float = 0.0


var _drops: Array[Drop] = []
var _next := 0


func _init() -> void:
	name = "FallingProps"
	z_index = 20
	for i in POOL:
		_drops.append(Drop.new())


## Drop `prop_name` from `from_y` at x, bonking a head at `head_y` (INF = no head, lands on
## the floor at `floor_y`).
func drop(prop_name: String, x: float, from_y: float, head_y: float, floor_y: float) -> void:
	var d := _drops[_next]
	_next = (_next + 1) % POOL
	d.active = true
	d.tex = FxArt.prop(prop_name)
	d.pos = Vector2(x, from_y)
	d.vel = Vector2(0, 200)
	d.rot = 0.0
	d.spin = 0.0
	d.head_y = head_y
	d.floor_y = floor_y
	d.hit = head_y == INF
	d.rest = 0.0
	queue_redraw()


func active_count() -> int:
	var n := 0
	for d in _drops:
		if d.active:
			n += 1
	return n


func clear() -> void:
	for d in _drops:
		d.active = false
	queue_redraw()


func tick(dt: float) -> void:
	var any := false
	for d in _drops:
		if not d.active:
			continue
		any = true
		if d.rest > 0.0:
			d.rest += dt
			if d.rest > REST_S:
				d.active = false
			continue
		d.vel.y += G * dt
		d.pos += d.vel * dt
		d.rot += d.spin * dt
		if not d.hit and d.pos.y >= d.head_y:
			d.hit = true
			d.pos.y = d.head_y
			d.vel = Vector2(signf(sin(d.pos.x)) * 260.0 + 60.0, -760.0)
			d.spin = 9.0
			bonked.emit(d.pos)
		elif d.hit and d.pos.y >= d.floor_y - 20.0:
			d.pos.y = d.floor_y - 20.0
			if absf(d.vel.y) > 300.0:
				d.vel = Vector2(d.vel.x * 0.5, -d.vel.y * 0.3)
				d.spin *= 0.4
			else:
				d.vel = Vector2.ZERO
				d.spin = 0.0
				d.rot = snappedf(d.rot, PI)
				d.rest = 0.001
	if any:
		queue_redraw()


func _draw() -> void:
	for d in _drops:
		if not d.active or d.tex == null:
			continue
		var a := 1.0
		if d.rest > 0.0:
			a = clampf((REST_S - d.rest) / 0.4, 0.0, 1.0)
		var sz := d.tex.get_size()
		draw_set_transform(d.pos, d.rot, Vector2.ONE)
		draw_texture(d.tex, -sz * 0.5, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
