## ResultsScreen — the curtain call skeleton (GDD §6.2, TECH §5.9). Layout at the 1080-high base:
##   * "CURTAIN CALL" title + the Night's name;
##   * three 160 px Curtain Call stamps (Opening Night ★, Full Script ★★, Standing Ovation ★★★)
##     that stamp in one after another (star_slam haptic);
##   * the Applause count-up (96 px) and the ONE why-missed line at 44 px;
##   * the Gag Reel slot (704 × 396, `gag_reel_rect()` global rect, `set_gag_reel_texture(tex)`)
##     with "+NEW!" chips for never-seen reactions under it;
##   * buttons: **Next Night ▶** (the default: 240 px tall, bottom right under the right thumb),
##     Retry and Playbill (bottom left).
## Bellows' slow-burn and the dropping curtain are the view's (it renders them into the reel /
## over this screen). `setup({applause, stars, why, new, has_next, night_title})`.
## `closed(action)` with action ∈ "next", "retry", "playbill". Back = playbill.
class_name ResultsScreen
extends UiPanel

const STAMP := 160.0
## Stamp column pitch (room for the 36 px names under the stamps).
const STAMP_PITCH := 330.0
const REEL := Vector2(704, 396)
const NEXT_SIZE := Vector2(560, 240)
const SMALL_SIZE := Vector2(340, 144)
const STAMP_DELAY_MS := 450
const COUNT_MS := 1400

var applause: int = 0
var stars: Array = [false, false, false]
var why: String = ""
var new_items: PackedStringArray = PackedStringArray()
var has_next: bool = true
var night_title: String = ""
var reel_texture: Texture2D = null

var next_button: UiButton
var retry_button: UiButton
var playbill_button: UiButton

var _title: String = ""
var _star_names: PackedStringArray = PackedStringArray()
var _applause_label: String = ""
var _new_label: String = ""
var _reel_label: String = ""
var _tex_star: Texture2D
var _tex_empty: Texture2D
var _stamped: int = 0
var _left := Rect2()
var _reel := Rect2()


func setup(d: Dictionary) -> void:
	applause = int(d.get("applause", 0))
	var st: Array = d.get("stars", [false, false, false])
	stars = [st.size() > 0 and bool(st[0]), st.size() > 1 and bool(st[1]), st.size() > 2 and bool(st[2])]
	why = String(d.get("why", ""))
	new_items = PackedStringArray(d.get("new", []))
	has_next = bool(d.get("has_next", true))
	night_title = String(d.get("night_title", ""))
	if next_button != null:
		next_button.disabled = not has_next
	if is_inside_tree():
		_relayout()


## Where the Gag Reel is shown (global canvas px) — the view renders into it.
func gag_reel_rect() -> Rect2:
	return Rect2(card.global_position + _reel.position, _reel.size)


## The Gag Reel's SubViewport texture.
func set_gag_reel_texture(tex: Texture2D) -> void:
	reel_texture = tex
	card.queue_redraw()


## Applause shown by the count-up right now.
func shown_applause() -> int:
	var t := clampf(float(age_ms() - 300) / float(COUNT_MS), 0.0, 1.0)
	return int(round(float(applause) * (1.0 - pow(1.0 - t, 3.0))))


func _build() -> void:
	back_action = "playbill"
	scrim = Color(0, 0, 0, 0)
	_title = UiStrings.t("results.title")
	_star_names = PackedStringArray([UiStrings.t("results.star_1"), UiStrings.t("results.star_2"),
		UiStrings.t("results.star_3")])
	_applause_label = UiStrings.t("results.applause")
	_new_label = UiStrings.t("results.new")
	_reel_label = UiStrings.t("results.gag_reel")
	_tex_star = UiIcons.get_icon(&"star")
	_tex_empty = UiIcons.get_icon(&"star_empty")
	next_button = UiButton.make(UiStrings.t("results.next"), NEXT_SIZE, UiKit.GOLD, UiKit.GOLD_SHADE,
		UiIcons.get_icon(&"play"))
	next_button.name = "NextNight"
	next_button.icon_after = true
	next_button.font_size = 64
	next_button.icon_px = 84.0
	next_button.radius = 44.0
	next_button.disabled = not has_next
	next_button.pressed.connect(close.bind("next"))
	retry_button = UiButton.make(UiStrings.t("results.retry"), SMALL_SIZE, UiKit.CREAM, UiKit.CREAM_SHADE,
		UiIcons.get_icon(&"retry"))
	retry_button.name = "Retry"
	retry_button.hit_pad = Vector2(0, 12)
	retry_button.pressed.connect(close.bind("retry"))
	playbill_button = UiButton.make(UiStrings.t("results.playbill"), SMALL_SIZE, UiKit.CREAM, UiKit.CREAM_SHADE,
		UiIcons.get_icon(&"script"))
	playbill_button.name = "Playbill"
	playbill_button.hit_pad = Vector2(0, 12)
	playbill_button.pressed.connect(close.bind("playbill"))
	for b in [next_button, retry_button, playbill_button]:
		card.add_child(b)


func _layout(rect: Rect2) -> void:
	card.position = Vector2.ZERO
	card.size = size
	var s := rect
	next_button.position = Vector2(s.end.x - 48.0 - NEXT_SIZE.x, s.end.y - 40.0 - NEXT_SIZE.y)
	retry_button.position = Vector2(s.position.x + 48.0, s.end.y - 40.0 - SMALL_SIZE.y - 48.0)
	playbill_button.position = Vector2(s.position.x + 48.0 + SMALL_SIZE.x + 24.0, retry_button.position.y)
	var top := s.position.y + 176.0
	_reel = Rect2(s.end.x - 64.0 - REEL.x, top, REEL.x, REEL.y)
	_left = Rect2(s.position.x + 64.0, top, _reel.position.x - s.position.x - 128.0, 520.0)


func _tick() -> void:
	var due := clampi((age_ms() - 500) / STAMP_DELAY_MS + 1, 0, 3)
	while _stamped < due:
		if bool(stars[_stamped]):
			UiKit.haptic(&"rig_done")
		_stamped += 1
	if age_ms() < 500 + 3 * STAMP_DELAY_MS + COUNT_MS + 400 or not new_items.is_empty():
		card.queue_redraw()


func _draw_panel() -> void:
	# stage: curtain-red wings, a warm spotlight, footlight glow
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.CURTAIN_SHADE)
	var fold := size.x / 16.0
	for i in 16:
		draw_rect(Rect2(float(i) * fold + fold * 0.6, 0, fold * 0.4, size.y), Color(UiKit.CURTAIN, 0.55))
	var spot := Vector2(_left.get_center().x if _left.size.x > 0.0 else size.x * 0.36, size.y * 0.5)
	for i in 6:
		draw_circle(spot, size.y * (0.62 - 0.08 * float(i)), Color(1.0, 0.86, 0.6, 0.035))
	draw_rect(Rect2(0, size.y - 28.0, size.x, 28.0), UiKit.GOLD_SHADE)
	draw_rect(Rect2(0, size.y - 34.0, size.x, 6.0), UiKit.GOLD_LIGHT)


func _draw_card(ci: Control) -> void:
	var s := safe_rect()
	var df := UiKit.display_font()
	UiKit.draw_text_centered(ci, df, Vector2(size.x * 0.5, s.position.y + 70.0), _title, UiKit.SIZE_BIG_TITLE,
		UiKit.GOLD_LIGHT, 18)
	if night_title != "":
		UiKit.draw_text_centered(ci, UiKit.ui_font(), Vector2(size.x * 0.5, s.position.y + 138.0), night_title,
			UiKit.SIZE_PLAY, UiKit.CREAM, 10)
	# stamps
	var now := age_ms()
	var pitch := minf(STAMP_PITCH, _left.size.x / 3.0)
	var sx := _left.get_center().x - pitch
	for i in 3:
		var c := Vector2(sx + float(i) * pitch, _left.position.y + STAMP * 0.5 + 10.0)
		var t := float(now - 500 - i * STAMP_DELAY_MS) / 220.0
		ci.draw_circle(c, STAMP * 0.5 + 6.0, Color(UiKit.NAVY, 0.5))
		if t < 0.0:
			UiKit.draw_icon(ci, _tex_empty, Rect2(c - Vector2(STAMP, STAMP) * 0.42, Vector2(STAMP, STAMP) * 0.84), Color(1, 1, 1, 0.5))
		else:
			var k := 1.0 if UiKit.reduce_motion() else lerpf(1.8, 1.0, clampf(t, 0.0, 1.0))
			var earned := bool(stars[i])
			var e := STAMP * 0.84 * k
			UiKit.draw_icon(ci, _tex_star if earned else _tex_empty, Rect2(c - Vector2(e, e) * 0.5, Vector2(e, e)),
				Color(1, 1, 1, clampf(t * 2.0, 0.0, 1.0)))
		var nm := _star_names[i]
		var fs := ScriptPanel.fit_size(UiKit.ui_font(), nm, pitch - 12.0, UiKit.SIZE_MIN)
		UiKit.draw_text_centered(ci, UiKit.ui_font(), c + Vector2(0, STAMP * 0.5 + 34.0), nm, fs,
			UiKit.CREAM if bool(stars[i]) else Color(UiKit.CREAM, 0.55), 10)
	# applause count-up
	var ay := _left.position.y + STAMP + 150.0
	UiKit.draw_text_centered(ci, df, Vector2(_left.get_center().x, ay), _applause_label, UiKit.SIZE_PLAY, UiKit.GOLD_LIGHT, 10)
	UiKit.draw_text_centered(ci, df, Vector2(_left.get_center().x, ay + 84.0), str(shown_applause()),
		UiKit.SIZE_BIG_TITLE, UiKit.CREAM, 18)
	# why-missed line
	if why != "":
		var lines := LoadingCard.wrap_lines(UiKit.ui_font(), why, _left.size.x, UiKit.text_size(UiKit.SIZE_PLAY))
		var ly := ay + 170.0
		for l in lines:
			UiKit.draw_text_centered(ci, UiKit.ui_font(), Vector2(_left.get_center().x, ly), l,
				UiKit.text_size(UiKit.SIZE_PLAY), UiKit.CREAM, 10)
			ly += 56.0
	# gag reel slot
	UiKit.draw_chunky_rect(ci, _reel.grow(14.0), 24.0, UiKit.GOLD, UiKit.GOLD_SHADE, UiKit.BUTTON_OUTLINE, 8.0)
	if reel_texture != null:
		ci.draw_texture_rect(reel_texture, _reel, false)
	else:
		ci.draw_rect(_reel, UiKit.PLUM)
		UiKit.draw_text_centered(ci, df, _reel.get_center(), _reel_label, UiKit.SIZE_BANNER, Color(UiKit.CREAM, 0.5), 0)
	# +NEW! chips
	var cx := _reel.position.x
	var cy := _reel.end.y + 34.0
	for n in new_items:
		var txt := "%s %s" % [_new_label, n]
		var w := UiKit.display_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN).x + 36.0
		if cx + w > _reel.end.x:
			cx = _reel.position.x
			cy += 70.0
		var pulse := 1.0 + 0.04 * sin(float(now) * 0.006)
		var rr := Rect2(cx, cy, w * pulse, 58.0)
		UiKit.draw_chunky_rect(ci, rr, 29.0, UiKit.CHERRY, UiKit.CHERRY_SHADE, 5.0, 6.0)
		UiKit.draw_text_centered(ci, df, rr.get_center() + Vector2(0, -2), txt, UiKit.SIZE_MIN, UiKit.CREAM, 0)
		cx += w + 16.0
