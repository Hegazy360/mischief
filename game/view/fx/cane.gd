## FxCane — Figgis's vaudeville hook (GDD §6.4, `figgis_hook`): a gold-tipped cane sweeps in
## from the wing (12 f), hooks Hush's collar, and yanks back out (12 f) as she is pulled into
## the hiding spot (`oneshot:yanked` on her rig). One pooled node, lines only. View time.
class_name FxCane
extends Node2D

const IN_S := 0.2
const HOLD_S := 0.1
const OUT_S := 0.2
const LEN := 560.0
const WOOD := Color("#6B3F22")
const GOLD := Color("#E8B33A")

var _t := 99.0
var _target := Vector2.ZERO
var _dir := 1.0
var _unit := 1.0


func _init() -> void:
	name = "Cane"
	z_index = 34


## Sweep in toward `target` (world) from the right wing (`from_right`) or the left.
func start(target: Vector2, from_right: bool) -> void:
	_target = target
	_dir = 1.0 if from_right else -1.0
	_t = 0.0
	queue_redraw()


func active() -> bool:
	return _t < IN_S + HOLD_S + OUT_S


func stop() -> void:
	_t = 99.0
	queue_redraw()


func tick(dt: float, unit: float) -> void:
	if not active():
		return
	_t += dt
	_unit = unit
	queue_redraw()


## How far in the hook is (0 off-screen … 1 at her collar).
func reach() -> float:
	if _t < IN_S:
		return ViewKit.ease_out_cubic(_t / IN_S)
	if _t < IN_S + HOLD_S:
		return 1.0
	return 1.0 - clampf((_t - IN_S - HOLD_S) / OUT_S, 0.0, 1.0)


func _draw() -> void:
	if not active():
		return
	var u := reach()
	var hook := _target + Vector2(_dir * (1.0 - u) * 900.0, -40.0)
	var handle := hook + Vector2(_dir * LEN, -60.0)
	var w := 14.0
	draw_line(hook, handle, ViewKit.INK, w + 8.0)
	draw_line(hook, handle, WOOD, w)
	# The crook: a half circle opening toward her.
	var r := 34.0
	var c := hook + Vector2(0, r)
	var prev := c + Vector2(0, -r)
	for i in range(1, 13):
		var a := -PI * 0.5 - _dir * PI * float(i) / 12.0
		var p := c + Vector2(cos(a), sin(a)) * r
		draw_line(prev, p, ViewKit.INK, w + 8.0)
		draw_line(prev, p, WOOD, w)
		prev = p
	draw_circle(handle, 16.0, ViewKit.INK)
	draw_circle(handle, 11.0, GOLD)
