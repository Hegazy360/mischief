## TomatoRow — the 3 × 44 px tomatoes on the Applause-o-Meter (GDD §3.8, §4.6): whole tomatoes
## are catches left before the Hook; used ones splat (a 0.35 s squash-in). Hidden when the Night
## has unlimited tomatoes (max < 0: Prologue, Nights 1–3, Relaxed). Not a touch target.
class_name TomatoRow
extends Control

const SIZE_PX := 44.0
const GAP := 4.0
const SPLAT_MS := 350

var left_count: int = -1
var max_count: int = -1

var _tex_whole: Texture2D = null
var _tex_splat: Texture2D = null
var _splat_ms: PackedInt64Array = PackedInt64Array([-100000, -100000, -100000, -100000, -100000])


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2(3 * SIZE_PX + 2 * GAP, SIZE_PX)


func _ready() -> void:
	_tex_whole = UiIcons.get_icon(&"tomato")
	_tex_splat = UiIcons.get_icon(&"tomato_splat")
	set_process(false)


## Width needed for `n` tomatoes.
static func width_for(n: int) -> float:
	return 0.0 if n <= 0 else float(n) * SIZE_PX + float(n - 1) * GAP


## Update counts; a tomato that just got used splats.
func set_counts(p_left: int, p_max: int) -> void:
	if p_left == left_count and p_max == max_count:
		return
	var now := UiKit.now_ms()
	if p_max == max_count and p_max > 0 and p_left < left_count:
		for i in range(maxi(0, p_left), mini(left_count, _splat_ms.size())):
			_splat_ms[i] = now
		set_process(true)
	left_count = p_left
	max_count = p_max
	visible = max_count > 0
	size = Vector2(width_for(maxi(max_count, 0)), SIZE_PX)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()
	var now := UiKit.now_ms()
	for t in _splat_ms:
		if now - t < SPLAT_MS:
			return
	set_process(false)


func _draw() -> void:
	if max_count <= 0:
		return
	var now := UiKit.now_ms()
	# tomatoes left sit on the left; used (splatted) ones on the right
	for i in max_count:
		var x := float(i) * (SIZE_PX + GAP)
		var used := i >= left_count
		var r := Rect2(x, 0, SIZE_PX, SIZE_PX)
		if not used:
			UiKit.draw_icon(self, _tex_whole, r)
			continue
		var k := 1.0
		var t := float(now - _splat_ms[mini(i, _splat_ms.size() - 1)]) / float(SPLAT_MS)
		if t >= 0.0 and t < 1.0 and not UiKit.reduce_motion():
			k = 1.6 - 0.6 * t
		var c := r.get_center()
		var s := Vector2(SIZE_PX, SIZE_PX) * k
		UiKit.draw_icon(self, _tex_splat, Rect2(c - s * 0.5, s), Color(1, 1, 1, 0.95))
