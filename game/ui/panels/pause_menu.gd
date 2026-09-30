## PauseMenu — the "Interval" (GDD §2.2, §3.1; REDESIGN_3D §2.3): Resume · Retry · Take a Bow (only
## once the first Curtain Call ★ is earned) · Hint (Figgis ladder steps 2–3) · Map (the Overview of
## tonight's set) · Settings · Playbill, under a header with the Applause total, the tomatoes and the
## Curtain Calls so far. Resume spans the card; the rest sit in two columns (96 px-tall visuals on
## 120 px hit boxes, 24 px apart both ways), so seven buttons fit a 1080 px screen. Android back =
## Resume. `closed(action)` with action ∈ "resume", "retry", "bow", "hint", "map", "settings",
## "playbill" (NightScene maps hint → the ladder, map → the `map_open` intent; `Hud.open_pause_menu`
## re-emits them as `hint_tap` / `map_open`).
class_name PauseMenu
extends UiPanel

const COL_W := 520.0
const BTN_W := COL_W * 2.0 + 24.0
const BTN_VIS_H := 96.0
const BTN_HIT_H := 120.0
const GAP := 24.0
const TITLE_H := 120.0
const HEADER_H := 72.0
const PAD := 60.0

var can_bow: bool = false
## Header numbers: {applause: int, tomatoes_left: int, tomatoes_max: int, curtain_calls: int}
## (a missing key hides its part).
var header: Dictionary = {}
var buttons: Dictionary = {}

var _title: String = ""
var _header_text: String = ""
var _tex_tomato: Texture2D = null
var _tex_star: Texture2D = null


## `p_can_bow`: show Take a Bow (★ earned); `p_header`: the header numbers (see `header`).
func setup(p_can_bow: bool, p_header: Dictionary = {}) -> void:
	can_bow = p_can_bow
	header = p_header
	_header_text = _make_header()
	if is_inside_tree():
		_rebuild()


func _build() -> void:
	back_action = "resume"
	_title = UiStrings.t("pause.title")
	_tex_tomato = UiIcons.get_icon(&"tomato")
	_tex_star = UiIcons.get_icon(&"star")
	_header_text = _make_header()
	_rebuild()


## The actions shown, in reading order (Resume first, full width).
func actions() -> PackedStringArray:
	var a := PackedStringArray(["resume", "retry"])
	if can_bow:
		a.append("bow")
	a.append_array(["hint", "map", "settings", "playbill"])
	return a


func _make_header() -> String:
	if header.has("applause"):
		return UiStrings.t("pause.applause", {"n": int(header["applause"])})
	return ""


func _rebuild() -> void:
	for b in buttons.values():
		(b as Node).queue_free()
	buttons.clear()
	var icons := {"resume": &"play", "retry": &"retry", "bow": &"rose", "hint": &"figgis_chip", "map": &"overview",
		"settings": &"gear", "playbill": &"script"}
	for act in actions():
		var primary := act == "resume"
		var fill := UiKit.GOLD if primary else (UiKit.CHERRY if act == "bow" else UiKit.CREAM)
		var shade := UiKit.GOLD_SHADE if primary else (UiKit.CHERRY_SHADE if act == "bow" else UiKit.CREAM_SHADE)
		var w := BTN_W if primary else COL_W
		var b := UiButton.make(UiStrings.t("pause." + act), Vector2(w, BTN_HIT_H), fill, shade,
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


func _body_top() -> float:
	return TITLE_H + (HEADER_H if not header.is_empty() else 0.0)


func _layout(rect: Rect2) -> void:
	var acts := actions()
	var rows := 1 + int(ceil(float(acts.size() - 1) / 2.0))
	var h := _body_top() + float(rows) * BTN_HIT_H + float(maxi(0, rows - 1)) * GAP + 48.0
	card.size = Vector2(BTN_W + PAD * 2.0, h)
	card.position = rect.get_center() - card.size * 0.5
	var y := _body_top()
	var col := 0
	for act in acts:
		var b: UiButton = buttons.get(act)
		if b == null:
			continue
		if act == "resume":
			b.position = Vector2(PAD, y)
			y += BTN_HIT_H + GAP
			continue
		b.position = Vector2(PAD + float(col) * (COL_W + 24.0), y)
		col += 1
		if col == 2:
			col = 0
			y += BTN_HIT_H + GAP


func _draw_card(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	UiKit.draw_chunky_rect(ci, r, 40.0, UiKit.CURTAIN, UiKit.CURTAIN_SHADE, UiKit.BUTTON_OUTLINE, 16.0)
	ci.draw_rect(Rect2(40, TITLE_H - 22.0, r.size.x - 80.0, 6.0), UiKit.GOLD)
	UiKit.draw_text_centered(ci, UiKit.display_font(), Vector2(r.size.x * 0.5, TITLE_H * 0.5 - 4.0), _title,
		UiKit.SIZE_TITLE, UiKit.CREAM, 16)
	if header.is_empty():
		return
	# header: Applause total · tomatoes · Curtain Calls (icons first)
	var f := UiKit.display_font()
	var cy := TITLE_H + HEADER_H * 0.5 - 8.0
	var x := PAD
	if _header_text != "":
		UiKit.draw_text(ci, f, Vector2(x, cy + 18.0), _header_text, UiKit.SIZE_PLAY, UiKit.GOLD_LIGHT, 10)
		x += f.get_string_size(_header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_PLAY).x + 48.0
	var tmax := int(header.get("tomatoes_max", -1))
	if tmax > 0:
		var left := int(header.get("tomatoes_left", tmax))
		for i in tmax:
			UiKit.draw_icon(ci, _tex_tomato, Rect2(x, cy - 22.0, 44, 44), Color(1, 1, 1, 1.0 if i < left else 0.3))
			x += 50.0
		x += 30.0
	if header.has("curtain_calls"):
		var n := int(header["curtain_calls"])
		for i in 3:
			UiKit.draw_icon(ci, _tex_star, Rect2(x, cy - 22.0, 44, 44), Color(1, 1, 1, 1.0 if i < n else 0.3))
			x += 50.0
