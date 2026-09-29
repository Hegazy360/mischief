## ComingSoonScreen — the generated stand-in for a route whose scene does not exist yet (the
## Playbill until Stage 4, the Night until Stage 2): the red curtain, a playbill card with a title
## and the route's name, and a big Back button. Navigation never crashes.
class_name ComingSoonScreen
extends Control

var route_key: String = ""
var back_button: UiButton

var _card: Control


func _init(p_key: String = "") -> void:
	route_key = p_key
	name = "ComingSoon_%s" % (p_key if p_key != "" else "unknown")
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Router calls setup(params) before the node enters the tree.
func setup(_params: Dictionary) -> void:
	pass


## Back → the previous route (or boot).
func handle_back() -> bool:
	_on_back()
	return true


func _ready() -> void:
	var curtain := CurtainTransition.new()
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	curtain.visible = true
	curtain.call("_set_drop", 1.0)
	curtain.call("_load_art")
	_card = _Card.new()
	_card.screen = self
	add_child(_card)
	back_button = UiButton.make(UiStrings.t("router.back"), Vector2(480, 144), UiKit.GOLD, UiKit.GOLD_SHADE)
	back_button.name = "BackButton"
	back_button.font_size = 56
	back_button.pressed.connect(_on_back)
	add_child(back_button)
	resized.connect(_place)
	_place()


func _place() -> void:
	_card.size = Vector2(minf(1280.0, size.x - 96.0), 360.0)
	_card.position = Vector2((size.x - _card.size.x) * 0.5, size.y * 0.5 - 260.0)
	back_button.position = Vector2((size.x - back_button.size.x) * 0.5, _card.position.y + _card.size.y + 48.0)
	_card.queue_redraw()


func _on_back() -> void:
	UiKit.haptic(&"ui")
	var r := get_node_or_null(^"/root/Router")
	if r != null and r.has_method("back"):
		if not bool(r.call("back")):
			r.call("goto", "boot", {}, "curtain")


## Human name of a route key for the card ("playbill" → "Playbill").
func route_title() -> String:
	var k := "router." + route_key
	return UiStrings.t(k) if UiStrings.has(k) else route_key.capitalize()


class _Card:
	extends Control

	var screen: ComingSoonScreen

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_chunky_rect(self, r, 44.0, UiKit.PAPER, UiKit.PAPER_SHADE, UiKit.BUTTON_OUTLINE, 16.0)
		UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(r.size.x * 0.5, 110.0),
			UiStrings.t("router.coming_soon"), UiKit.SIZE_BIG_TITLE, UiKit.CURTAIN, 0)
		var body := UiStrings.t("router.coming_soon_body", {"route": screen.route_title() if screen != null else ""})
		var lines := LoadingCard.wrap_lines(UiKit.ui_font(), body, r.size.x - 120.0, UiKit.SIZE_PLAY)
		var y := 210.0
		for l in lines:
			UiKit.draw_text_centered(self, UiKit.ui_font(), Vector2(r.size.x * 0.5, y), l, UiKit.SIZE_PLAY, UiKit.NAVY, 0)
			y += 56.0
