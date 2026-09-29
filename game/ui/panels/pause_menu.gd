## PauseMenu — the "Interval" (GDD §2.2, §3.1, TECH §5.9): Resume, Retry, Take a Bow (only once
## the first Curtain Call ★ is earned), Settings, Playbill. 96 px-tall button visuals on 120 px hit
## boxes with 24 px between hit boxes. Android back = Resume. `closed(action)` with action ∈
## "resume", "retry", "bow", "settings", "playbill".
class_name PauseMenu
extends UiPanel

const BTN_W := 680.0
const BTN_VIS_H := 96.0
const BTN_HIT_H := 120.0
const GAP := 24.0
const TITLE_H := 120.0

var can_bow: bool = false
var buttons: Dictionary = {}

var _title: String = ""


## `p_can_bow`: show Take a Bow (★ earned).
func setup(p_can_bow: bool) -> void:
	can_bow = p_can_bow
	if is_inside_tree():
		_rebuild()


func _build() -> void:
	back_action = "resume"
	_title = UiStrings.t("pause.title")
	_rebuild()


## The actions shown, top to bottom.
func actions() -> PackedStringArray:
	var a := PackedStringArray(["resume", "retry"])
	if can_bow:
		a.append("bow")
	a.append_array(["settings", "playbill"])
	return a


func _rebuild() -> void:
	for b in buttons.values():
		(b as Node).queue_free()
	buttons.clear()
	var icons := {"resume": &"play", "retry": &"retry", "bow": &"rose", "settings": &"gear", "playbill": &"script"}
	for act in actions():
		var primary := act == "resume"
		var fill := UiKit.GOLD if primary else (UiKit.CHERRY if act == "bow" else UiKit.CREAM)
		var shade := UiKit.GOLD_SHADE if primary else (UiKit.CHERRY_SHADE if act == "bow" else UiKit.CREAM_SHADE)
		var b := UiButton.make(UiStrings.t("pause." + act), Vector2(BTN_W, BTN_HIT_H), fill, shade,
			UiIcons.get_icon(icons[act]))
		b.name = "Btn_" + act
		b.hit_pad = Vector2(0, (BTN_HIT_H - BTN_VIS_H) * 0.5)
		b.font_size = 52
		b.icon_px = 64.0
		b.text_color = UiKit.CREAM if act == "bow" else UiKit.NAVY
		b.pressed.connect(close.bind(act))
		card.add_child(b)
		buttons[act] = b
	_relayout()


func _layout(rect: Rect2) -> void:
	var n := buttons.size()
	var h := TITLE_H + float(n) * BTN_HIT_H + float(maxi(0, n - 1)) * GAP + 48.0
	card.size = Vector2(BTN_W + 120.0, h)
	card.position = rect.get_center() - card.size * 0.5
	var y := TITLE_H
	for act in actions():
		var b: UiButton = buttons.get(act)
		if b == null:
			continue
		b.position = Vector2(60.0, y)
		y += BTN_HIT_H + GAP


func _draw_card(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	UiKit.draw_chunky_rect(ci, r, 40.0, UiKit.CURTAIN, UiKit.CURTAIN_SHADE, UiKit.BUTTON_OUTLINE, 16.0)
	ci.draw_rect(Rect2(40, TITLE_H - 22.0, r.size.x - 80.0, 6.0), UiKit.GOLD)
	UiKit.draw_text_centered(ci, UiKit.display_font(), Vector2(r.size.x * 0.5, TITLE_H * 0.5 - 4.0), _title,
		UiKit.SIZE_TITLE, UiKit.CREAM, 16)
