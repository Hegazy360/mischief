## NightCurtain — the red stage curtain NightScene (and Boot) own: down on the first frame (the
## imported 1× `art/house/stage/curtain.svg`, no HiResTex wait; procedural velvet when missing), a
## 0.8 s rise (the sim clock starts on its first frame, input goes live when it is half up) and a
## 0.8 s fall (the curtain call). Same geometry as the Router's CurtainTransition (the texture tiled
## across the width at full height), so a hand-over between the two never shows.
## Animation runs on real time (`_process`), never on the sim clock; it swallows touches while more
## than half down.
class_name NightCurtain
extends Control

signal half_up()
signal risen()
signal fallen()

const ART := "res://art/house/stage/curtain.svg"
const RISE_S := 0.8
const FALL_S := 0.8
const FOLDS := 14

## 0 = raised (off-screen), 1 = down.
var drop: float = 1.0
var _tex: Texture2D = null
var _anim: int = 0            # 0 none, 1 rising, -1 falling
var _t: float = 0.0
var _dur: float = RISE_S
var _half_sent: bool = false
var _from: float = 1.0


func _init() -> void:
	name = "NightCurtain"
	# after NightScene (priority 10): a rise started this frame advances this frame (tick 0 = first rise frame)
	process_priority = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(ART):
		_tex = load(ART) as Texture2D


## Snap down (no animation).
func set_down() -> void:
	_anim = 0
	drop = 1.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## Snap up and hide.
func set_up() -> void:
	_anim = 0
	drop = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Start the rise (`half_up` at 50 %, `risen` at the end).
func rise(sec: float = RISE_S) -> void:
	visible = true
	_anim = 1
	_t = 0.0
	_dur = maxf(0.01, sec)
	_from = drop
	_half_sent = false


## Start the fall (`fallen` at the end).
func fall(sec: float = FALL_S) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_anim = -1
	_t = 0.0
	_dur = maxf(0.01, sec)
	_from = drop


## Seconds into the current rise / fall.
func elapsed() -> float:
	return _t


func is_animating() -> bool:
	return _anim != 0


func is_down() -> bool:
	return _anim == 0 and drop >= 1.0


func _process(delta: float) -> void:
	if _anim == 0:
		return
	advance(delta)


## Advance the animation by `delta` real seconds (public for tests).
func advance(delta: float) -> void:
	if _anim == 0:
		return
	_t += delta
	var u := clampf(_t / _dur, 0.0, 1.0)
	if _anim > 0:
		var e := u * u * (3.0 - 2.0 * u)
		drop = _from * (1.0 - e)
		if not _half_sent and u >= 0.5:
			_half_sent = true
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			half_up.emit()
		if u >= 1.0:
			_anim = 0
			drop = 0.0
			visible = false
			risen.emit()
	else:
		# Ease-in fall with a small bounce at the hem.
		var e := u * u
		drop = lerpf(_from, 1.0, e)
		if u >= 1.0:
			_anim = 0
			drop = 1.0
			fallen.emit()
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0 or drop <= 0.0:
		return
	var y := -s.y * (1.0 - drop)
	if _tex != null:
		var ts := _tex.get_size()
		var tw := ts.x * (s.y / maxf(1.0, ts.y))
		var x := 0.0
		while x < s.x:
			draw_texture_rect(_tex, Rect2(x, y, tw, s.y), false)
			x += tw
		return
	var fold_w := s.x / float(FOLDS)
	draw_rect(Rect2(0, y, s.x, s.y), UiKit.CURTAIN)
	for i in FOLDS:
		var x0 := float(i) * fold_w
		draw_rect(Rect2(x0 + fold_w * 0.62, y, fold_w * 0.38, s.y), UiKit.CURTAIN_SHADE)
		draw_rect(Rect2(x0 + fold_w * 0.18, y, fold_w * 0.16, s.y), Color("#D02A44"))
	var hem := y + s.y
	draw_rect(Rect2(0, hem - 34, s.x, 34), UiKit.GOLD)
	draw_rect(Rect2(0, hem - 34, s.x, 8), UiKit.GOLD_SHADE)
