## FadeTransition — the plain Router transition: a navy fade over everything.
## Interface shared by every Router transition:
##   func cover(kind: String) -> void    # awaitable; the screen is hidden when it returns
##   func reveal(kind: String) -> void   # awaitable; the screen is visible when it returns
## Blocks touches while visible. Tweens run in real time and while the tree is paused.
class_name FadeTransition
extends ColorRect

const COVER_SEC := 0.18
const REVEAL_SEC := 0.24

var _tween: Tween


func _init() -> void:
	name = "FadeTransition"
	color = Color("#1B2340")
	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Fade to opaque (instant for kind "none").
func cover(kind: String = "fade") -> void:
	visible = true
	if kind == "none" or not is_inside_tree():
		modulate.a = 1.0
		return
	await _fade_to(1.0, COVER_SEC)


## Fade back to transparent and hide (instant for kind "none").
func reveal(kind: String = "fade") -> void:
	if kind == "none" or not is_inside_tree():
		modulate.a = 0.0
		visible = false
		return
	await _fade_to(0.0, REVEAL_SEC)
	visible = false


func _fade_to(a: float, sec: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", a, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
