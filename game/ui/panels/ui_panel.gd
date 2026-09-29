## UiPanel — base of every full-screen panel (Script, Pause, Settings, Loading, Results):
## a navy scrim that swallows touches (so nothing reaches the world), a pop-in, safe-area
## insets, Android back = `handle_back()` (closes with `back_action`), and `closed(action)`.
## Subclasses build their content in `_build()` (children go into `card`, which pops in) and lay
## it out in `_layout(rect)` where `rect` is the safe area; `_draw_card(ci)` paints the card
## background on `card`. Taps on the bare scrim call `_scrim_tap()` (default: nothing).
class_name UiPanel
extends Control

signal closed(action: String)

## Action reported when Back / a scrim tap closes the panel.
var back_action: String = "close"
## Scrim colour (alpha 0 = none).
var scrim: Color = UiKit.SCRIM
var insets: Vector4 = Vector4.ZERO

## The popping content container (children + `_draw_card`).
var card: Control

var _open_ms: int = 0
var _closing: bool = false
var _scrim_touch: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = UiKit.theme()
	size = Vector2(1920, 1080)
	card = _Card.new()
	card.name = "Card"
	card.panel = self
	add_child(card)


func _ready() -> void:
	_open_ms = UiKit.now_ms()
	_build()
	_relayout()
	resized.connect(_relayout)
	set_process(true)


## Safe-area insets (Hud passes them in).
func set_insets(v: Vector4) -> void:
	insets = SafeArea.symmetric(v)
	if is_inside_tree():
		_relayout()


## Android back / Escape: close with `back_action`. Returns true (consumed).
func handle_back() -> bool:
	close(back_action)
	return true


## Close with `action` (once).
func close(action: String) -> void:
	if _closing:
		return
	_closing = true
	closed.emit(action)


## Milliseconds since the panel opened.
func age_ms() -> int:
	return UiKit.now_ms() - _open_ms


## The safe rect (logical px).
func safe_rect() -> Rect2:
	return Rect2(insets.x, insets.y, size.x - insets.x - insets.z, size.y - insets.y - insets.w)


func _relayout() -> void:
	_layout(safe_rect())
	queue_redraw()
	card.queue_redraw()


func _process(_delta: float) -> void:
	if age_ms() < 400:
		queue_redraw()
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * pop_k()
	_tick()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.pressed:
			_scrim_touch = st.index
		elif st.index == _scrim_touch:
			_scrim_touch = -1
			_scrim_tap(st.position)
	elif event is InputEventScreenDrag or event is InputEventMouse:
		accept_event()


func _draw() -> void:
	if scrim.a > 0.0:
		var a := clampf(float(age_ms()) / 180.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(scrim, scrim.a * a))
	_draw_panel()


## Pop-in scale for content (0.9 → 1.0 over 220 ms, ease-out-back); 1.0 with reduce motion.
func pop_k() -> float:
	if UiKit.reduce_motion():
		return 1.0
	var t := clampf(float(age_ms()) / 220.0, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var e := 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
	return 0.9 + 0.1 * e


# --- overridables -------------------------------------------------------------------------

func _build() -> void:
	pass


func _layout(_rect: Rect2) -> void:
	pass


func _draw_panel() -> void:
	pass


## Paint the card background / static content on `ci` (the card), in card-local px.
func _draw_card(_ci: Control) -> void:
	pass


func _tick() -> void:
	pass


func _scrim_tap(_pos: Vector2) -> void:
	pass


## The popping card: forwards its _draw to the panel.
class _Card:
	extends Control

	var panel: UiPanel = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		if panel != null:
			panel._draw_card(self)
