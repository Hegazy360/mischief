## CurtainTransition — the stage-farce Router transition: the red curtain drops (cover) and rises
## (reveal). Uses `res://art/house/stage/curtain.svg` (art-house; 1920×1080, tiled horizontally
## for wide phones) through a soft load; without it, draws procedural velvet folds with a gold
## fringe. Same interface as FadeTransition (`cover(kind)`, `reveal(kind)`, awaitable).
## Timings: drop 0.55 s (ease-in + a small bounce), rise 0.8 s (GDD §2.3). Reduce motion: fade.
class_name CurtainTransition
extends Control

const CURTAIN_ART := "res://art/house/stage/curtain.svg"
const DROP_SEC := 0.55
const RISE_SEC := 0.8
const FOLDS := 14

var _tex: Texture2D = null
var _tried_art := false
var _drop: float = 0.0          # 0 = fully raised (off-screen), 1 = down
var _tween: Tween


func _init() -> void:
	name = "CurtainTransition"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


## True when the art-house curtain texture was found.
func has_art() -> bool:
	_load_art()
	return _tex != null


## Drop the curtain (instant for kind "none").
func cover(kind: String = "curtain") -> void:
	_load_art()
	visible = true
	if kind == "none" or not is_inside_tree():
		_set_drop(1.0)
		return
	if UiKit.reduce_motion():
		modulate.a = 0.0
		_set_drop(1.0)
		await _tween_prop("modulate:a", 1.0, 0.2)
		return
	modulate.a = 1.0
	_kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_drop, _drop, 1.04, DROP_SEC * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_drop, 1.04, 1.0, DROP_SEC * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished


## Raise the curtain and hide (instant for kind "none").
func reveal(kind: String = "curtain") -> void:
	if kind == "none" or not is_inside_tree():
		_set_drop(0.0)
		visible = false
		return
	if UiKit.reduce_motion():
		await _tween_prop("modulate:a", 0.0, 0.25)
		visible = false
		modulate.a = 1.0
		_set_drop(0.0)
		return
	_kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_drop, _drop, 0.0, RISE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	visible = false


## Current drop amount (0 raised … 1 down), for tests.
func drop_amount() -> float:
	return _drop


func _set_drop(v: float) -> void:
	_drop = v
	queue_redraw()


func _tween_prop(prop: String, v: float, sec: float) -> void:
	_kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, prop, v, sec)
	await _tween.finished


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _load_art() -> void:
	if _tried_art:
		return
	_tried_art = true
	_tex = UiIcons.texture(CURTAIN_ART, 1.0)


func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var y := -s.y * (1.0 - _drop)
	if _tex != null:
		var ts := _tex.get_size()
		var tw := ts.x * (s.y / maxf(1.0, ts.y))
		var x := 0.0
		while x < s.x:
			draw_texture_rect(_tex, Rect2(x, y, tw, s.y), false)
			x += tw
		return
	# Procedural velvet: alternating lit / shaded folds, a gold fringe along the hem.
	var fold_w := s.x / float(FOLDS)
	draw_rect(Rect2(0, y, s.x, s.y), UiKit.CURTAIN)
	for i in FOLDS:
		var x0 := float(i) * fold_w
		draw_rect(Rect2(x0 + fold_w * 0.62, y, fold_w * 0.38, s.y), UiKit.CURTAIN_SHADE)
		draw_rect(Rect2(x0 + fold_w * 0.18, y, fold_w * 0.16, s.y), Color("#D02A44"))
	var hem := y + s.y
	draw_rect(Rect2(0, hem - 34, s.x, 34), UiKit.GOLD)
	draw_rect(Rect2(0, hem - 34, s.x, 8), UiKit.GOLD_SHADE)
	var tassel := 0.0
	while tassel < s.x:
		draw_circle(Vector2(tassel + 12, hem - 4), 9, UiKit.GOLD_SHADE)
		tassel += 36.0
