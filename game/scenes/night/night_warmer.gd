## NightWarmer — works through a `NightWarm.list()` under the curtain, one step per frame, each
## step capped by BUDGET_MS of work (s2-night §4.2): residue / combo looks on the rigs
## (`RigPlayer.warm_looks`, soft), the fonts at their play sizes (a primer that draws every glyph set
## once, hidden under the curtain), one hidden PiP frame (`PipView.warm()`, soft), the Night's audio
## (`Audio.warm(ids)`), the FX pool. `done` turns true when every step ran; `elapsed_ms` is the wall
## time from `start()` to done (the budget is ≤ 2.0 s).
class_name NightWarmer
extends Node

signal finished(ms: int)

const BUDGET_MS := 8

var list: Dictionary = {}
var done: bool = false
var elapsed_ms: int = 0
## Step names in the order they ran (tests, the report).
var ran: PackedStringArray = PackedStringArray()
var world_view: Node = null
var pip: Node = null
## Where the font primer draws (a CanvasLayer under the curtain).
var primer_parent: Node = null

var _steps: Array = []
var _t0: int = 0
var _primer: Node2D = null


## Begin warming `p_list` for `wv` (WorldView) and `p_pip` (PipView).
func start(p_list: Dictionary, wv: Node, p_pip: Node, p_primer_parent: Node) -> void:
	list = p_list
	world_view = wv
	pip = p_pip
	primer_parent = p_primer_parent
	done = false
	ran = PackedStringArray()
	_t0 = Time.get_ticks_msec()
	_steps = [["looks_bellows", _warm_looks.bind("bellows")], ["looks_hush", _warm_looks.bind("hush")],
		["fonts", _warm_fonts], ["pip", _warm_pip], ["audio", _warm_audio], ["fonts_done", _free_primer]]
	set_process(true)


func _process(_d: float) -> void:
	if done:
		set_process(false)
		return
	var t := Time.get_ticks_msec()
	while not _steps.is_empty() and Time.get_ticks_msec() - t < BUDGET_MS:
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
		ran.append(String(s[0]))
		if String(s[0]) == "fonts":
			break   # the primer draws this frame; free it next frame
	if _steps.is_empty():
		done = true
		elapsed_ms = Time.get_ticks_msec() - _t0
		finished.emit(elapsed_ms)


## Run every step now (tests, a seek that needs a warm world at once).
func finish_now() -> void:
	while not _steps.is_empty():
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
		ran.append(String(s[0]))
	if not done:
		done = true
		elapsed_ms = Time.get_ticks_msec() - _t0
		finished.emit(elapsed_ms)


func _warm_looks(actor: String) -> void:
	if world_view == null or not world_view.has_method("character"):
		return
	var cv: Variant = world_view.call("character", actor)
	if not (cv is Node):
		return
	var rig: Variant = (cv as Node).get("rig")
	var looks: Variant = (list.get("looks", {}) as Dictionary).get(actor, PackedStringArray())
	if rig is Node and (rig as Node).has_method("warm_looks") and looks is PackedStringArray and not (looks as PackedStringArray).is_empty():
		(rig as Node).call("warm_looks", looks)


func _warm_fonts() -> void:
	if primer_parent == null:
		return
	_primer = _FontPrimer.new()
	_primer.texts = PackedStringArray(list.get("captions", PackedStringArray()))
	_primer.sizes = list.get("fonts", NightWarm.FONT_SIZES)
	primer_parent.add_child(_primer)


func _free_primer() -> void:
	if _primer != null and is_instance_valid(_primer):
		_primer.queue_free()
	_primer = null


func _warm_pip() -> void:
	if pip != null and pip.has_method("warm"):
		pip.call("warm")


func _warm_audio() -> void:
	var a := ViewKit.autoload("Audio")
	var ids: Variant = list.get("audio", PackedStringArray())
	if a != null and a.has_method("warm") and ids is PackedStringArray and not (ids as PackedStringArray).is_empty():
		a.call("warm", ids)


## Draws every glyph set once (off to the side, under the curtain) so the font caches are filled
## before the first caption.
class _FontPrimer:
	extends Node2D
	var texts := PackedStringArray()
	var sizes: Array = []

	func _ready() -> void:
		position = Vector2(-4000, -4000)
		modulate = Color(1, 1, 1, 0.004)
		queue_redraw()

	func _draw() -> void:
		var y := 0.0
		for s in sizes:
			var d: Dictionary = s
			var f: Font = ViewKit.display_font() if String(d.get("font", "display")) == "display" else ViewKit.ui_font()
			if f == null:
				f = ThemeDB.fallback_font
			var sz := int(d.get("size", 48))
			for t in texts:
				draw_string(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
				draw_string_outline(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6)
			y += float(sz) * 1.2
