## LoadingCard — the rule card on the curtain before each Night (GDD §2.2): the red curtain
## backdrop (art-house curtain.svg, procedural velvet fallback), a playbill card with the Night's
## title, ONE 160 px icon and the ≤ 25-word rule at 52 px. "tap to start" appears after
## TAP_AFTER_SEC; a tap after that, or AUTO_SEC, closes with "start". Taps before 1 s are ignored
## (a stray tap never skips the rule). Back = start.
## `setup({title, subtitle, text, icon})` — icon: a UiIcons.card key (tray, freeze, squeak, hide,
## specs, …), an item id or a res:// path.
class_name LoadingCard
extends UiPanel

const TAP_AFTER_SEC := 1.0
const AUTO_SEC := 4.0
const ICON := 160.0
const CARD_W := 1320.0
const TEXT_SIZE := 52

var title: String = ""
var subtitle: String = ""
var text: String = ""
var icon_key: String = ""
## Test hook: disable the automatic close.
var auto_close: bool = true

var _icon: Texture2D = null
var _curtain: CurtainTransition = null
var _tap: String = ""
var _lines: PackedStringArray = PackedStringArray()


func setup(d: Dictionary) -> void:
	title = String(d.get("title", ""))
	subtitle = String(d.get("subtitle", ""))
	text = String(d.get("text", ""))
	icon_key = String(d.get("icon", ""))
	if is_inside_tree():
		_prepare()
		_relayout()


func _build() -> void:
	back_action = "start"
	scrim = Color(0, 0, 0, 0)
	_curtain = CurtainTransition.new()
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	move_child(_curtain, 0)
	_curtain.visible = true
	_curtain.call("_set_drop", 1.0)
	_curtain.call("_load_art")
	_tap = UiStrings.t("loading.tap_to_start")
	_prepare()


func _prepare() -> void:
	_icon = UiIcons.card(icon_key) if icon_key != "" else null
	_lines = wrap_lines(UiKit.ui_font(), text, CARD_W - 120.0, UiKit.text_size(TEXT_SIZE))


## Word count of the rule (the content lint caps it at 25).
func word_count() -> int:
	return text.split(" ", false).size()


func _layout(rect: Rect2) -> void:
	var lh := float(UiKit.text_size(TEXT_SIZE)) * 1.22
	var h := 70.0 + 110.0 + ICON + 30.0 + float(maxi(1, _lines.size())) * lh + 60.0
	card.size = Vector2(minf(CARD_W, rect.size.x - 64.0), minf(h, rect.size.y - 90.0))
	card.position = Vector2(rect.get_center().x - card.size.x * 0.5, rect.position.y + (rect.size.y - card.size.y - 70.0) * 0.5)


func _tick() -> void:
	if auto_close and float(age_ms()) >= AUTO_SEC * 1000.0:
		close("start")
	if float(age_ms()) >= TAP_AFTER_SEC * 1000.0:
		card.queue_redraw()


func _scrim_tap(_pos: Vector2) -> void:
	if float(age_ms()) >= TAP_AFTER_SEC * 1000.0:
		close("start")


func _draw_card(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	UiKit.draw_chunky_rect(ci, Rect2(r.position + Vector2(0, 10), r.size), 44.0, Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), 0.0, 0.0)
	UiKit.draw_chunky_rect(ci, r, 44.0, UiKit.PAPER, UiKit.PAPER_SHADE, UiKit.BUTTON_OUTLINE, 16.0)
	ci.draw_rect(Rect2(30, 22, r.size.x - 60, 5), UiKit.GOLD)
	var y := 104.0
	var df := UiKit.display_font()
	if title != "":
		UiKit.draw_text_centered(ci, df, Vector2(r.size.x * 0.5, 72.0), title, UiKit.SIZE_TITLE, UiKit.CURTAIN, 0)
	if subtitle != "":
		UiKit.draw_text_centered(ci, df, Vector2(r.size.x * 0.5, 136.0), subtitle, UiKit.SIZE_BANNER, UiKit.NAVY, 0)
	y = 180.0
	if _icon != null:
		ci.draw_circle(Vector2(r.size.x * 0.5, y + ICON * 0.5), ICON * 0.5 + 18.0, Color(UiKit.GOLD, 0.35))
		UiKit.draw_icon(ci, _icon, Rect2(r.size.x * 0.5 - ICON * 0.5, y, ICON, ICON))
		y += ICON + 30.0
	var fs := UiKit.text_size(TEXT_SIZE)
	var lh := float(fs) * 1.22
	var f := UiKit.ui_font()
	for l in _lines:
		var w := f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, Vector2((r.size.x - w) * 0.5, y + fs * 0.9), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.NAVY)
		y += lh
	if float(age_ms()) >= TAP_AFTER_SEC * 1000.0:
		var a := 0.55 + 0.45 * sin(float(age_ms()) * 0.001 * TAU * 0.9)
		var p := Vector2(r.size.x * 0.5, r.size.y + 56.0)
		UiKit.draw_text_centered(ci, UiKit.display_font(), p, _tap, UiKit.SIZE_PLAY, Color(UiKit.CREAM, a), 12,
			Color(UiKit.NAVY, a))


## Greedy word wrap of `text` into lines no wider than `width` at size `fs`.
static func wrap_lines(f: Font, txt: String, width: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in txt.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out
