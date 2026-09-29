## ResultsScreen — the curtain call (GDD §6.2, TECH §5.9, s2-ui §4.2.5), shown by NightScene over
## the fallen curtain. Layout at the 1080-high base (safe area S):
##   * "CURTAIN CALL" (88 px) + the Night's name (44 px), top centre;
##   * left block: the brass Applause dial (a needle that swings up with the count-up) and the
##     Applause number (96 px); three 128 px Curtain Call stamps (Opening Night ★, Full Script ★★,
##     Standing Ovation ★★★) that thunk in one after another; the ONE why-missed line (44 px);
##   * right: the Gag Reel slot (704 × 396, `gag_reel_rect()` global rect,
##     `set_gag_reel_texture(tex)`) with the "+NEW!" chips under it;
##   * buttons in the bottom corners: **Next Night ▶** (the default: 240 px tall under the right
##     thumb, gently glowing), Retry and Playbill bottom-left.
##   * The lower stage band between the corners is left CLEAR: NightScene stages Bellows' slow
##     burn and the curtain bonk there, behind this screen (no backdrop is drawn unless
##     `stage: true`, for standalone use).
## Variants (`setup({variant})`): "night" (above), "prologue" (no stamps; the primary button is
## "Night 1 ▶", plus Retry) and "gate0" (no stamps; **Again ▶** the default, plus Stage door).
## **Every button is live from the first frame** (no pop-in on this panel). A tap anywhere else
## skips the current step — the count-up jumps to its end and every stamp lands at once — and
## emits `skip_requested(step)` (step DONE = the sequence had finished: NightScene skips the Gag
## Reel). `sequence_finished` fires once when the count, stamps and why line have all landed.
## `closed(action)` with action ∈ "next", "retry", "playbill" (night / prologue) and "again",
## "stage_door" (gate0). Back = playbill (night), next (prologue), stage_door (gate0).
class_name ResultsScreen
extends UiPanel

signal skip_requested(step: int)
signal sequence_finished()

enum Step { COUNT, STAMPS, WHY, DONE }

const VARIANTS: PackedStringArray = ["night", "prologue", "gate0"]
const STAMP := 128.0
const STAMP_PITCH := 300.0
const REEL := Vector2(704, 396)
const NEXT_SIZE := Vector2(520, 240)
const SMALL_SIZE := Vector2(340, 144)
const DIAL := 150.0
## Timeline (ms from open, first viewing; a repeat viewing runs at REPEAT_PACE).
const COUNT_FROM_MS := 150
const COUNT_MS := 1100
const STAMP_MS := 300
const STAMP_LAND_MS := 140
const WHY_FADE_MS := 200
const REPEAT_PACE := 0.8
const TICK_EVERY := 10

var variant: String = "night"
var applause: int = 0
var stars: Array = [false, false, false]
var why: String = ""
var new_items: PackedStringArray = PackedStringArray()
var has_next: bool = true
var night_title: String = ""
var repeat: bool = false
## Paint a curtain backdrop (standalone use); false over the real stage.
var stage: bool = false
var reel_texture: Texture2D = null

## The default button (Next Night ▶ / Night 1 ▶ / Again ▶).
var next_button: UiButton
var retry_button: UiButton
var playbill_button: UiButton
var stage_door_button: UiButton

var _title: String = ""
var _star_names: PackedStringArray = PackedStringArray()
var _applause_label: String = ""
var _new_label: String = ""
var _reel_label: String = ""
var _tex_star: Texture2D
var _tex_empty: Texture2D
var _left := Rect2()
var _reel := Rect2()
var _why_lines := PackedStringArray()
var _skip_at_ms: int = -1
var _stamped: int = 0
var _finished_emitted: bool = false
var _last_tick: int = 0
var _new_sting: bool = false
var _count_text: String = "0"
var _count_shown: int = -1


func setup(d: Dictionary) -> void:
	variant = String(d.get("variant", "night"))
	if not VARIANTS.has(variant):
		variant = "night"
	applause = int(d.get("applause", 0))
	var st: Array = d.get("stars", [false, false, false])
	stars = [st.size() > 0 and bool(st[0]), st.size() > 1 and bool(st[1]), st.size() > 2 and bool(st[2])]
	why = String(d.get("why", ""))
	new_items = PackedStringArray(d.get("new", []))
	has_next = bool(d.get("has_next", true))
	night_title = String(d.get("night_title", ""))
	repeat = bool(d.get("repeat", false))
	stage = bool(d.get("stage", false))
	if is_inside_tree():
		_rebuild_buttons()
		_relayout()


## The one why-missed line (NightScene picks it by its fixed order).
func set_why(text: String) -> void:
	why = text
	_wrap_why()
	card.queue_redraw()


## Where the Gag Reel is shown (global canvas px) — the view renders into it.
func gag_reel_rect() -> Rect2:
	return Rect2(card.global_position + _reel.position, _reel.size)


## The Gag Reel's SubViewport texture.
func set_gag_reel_texture(tex: Texture2D) -> void:
	reel_texture = tex
	card.queue_redraw()


## Does this variant stamp the Curtain Calls?
func has_stamps() -> bool:
	return variant == "night"


## Milliseconds into the sequence (a skip jumps to its end).
func seq_ms() -> float:
	var pace := REPEAT_PACE if repeat else 1.0
	var t := float(age_ms()) / pace
	return maxf(t, total_ms()) if _skip_at_ms >= 0 else t


## Length of the whole sequence (ms, at pace 1).
func total_ms() -> float:
	var t := float(COUNT_FROM_MS + COUNT_MS)
	if has_stamps():
		t += 3.0 * STAMP_MS
	return t + WHY_FADE_MS + 100.0


## The step the sequence is in.
func step() -> int:
	var t := seq_ms()
	if t < float(COUNT_FROM_MS + COUNT_MS):
		return Step.COUNT
	var st_end := float(COUNT_FROM_MS + COUNT_MS) + (3.0 * STAMP_MS if has_stamps() else 0.0)
	if t < st_end:
		return Step.STAMPS
	if t < total_ms():
		return Step.WHY
	return Step.DONE


func is_finished() -> bool:
	return step() == Step.DONE


## Jump to the end of the sequence (count done, every stamp landed). Emits skip_requested.
func skip() -> void:
	var s := step()
	if _skip_at_ms < 0 and s != Step.DONE:
		_skip_at_ms = age_ms()
	skip_requested.emit(s)
	_tick()
	card.queue_redraw()


## Applause shown by the count-up right now.
func shown_applause() -> int:
	var t := clampf((seq_ms() - float(COUNT_FROM_MS)) / float(COUNT_MS), 0.0, 1.0)
	return int(round(float(applause) * (1.0 - pow(1.0 - t, 3.0))))


## Stamps landed so far (0..3; 0 for variants without stamps).
func stamps_landed() -> int:
	if not has_stamps():
		return 0
	var t := seq_ms() - float(COUNT_FROM_MS + COUNT_MS)
	return clampi(int(floor(t / float(STAMP_MS))) + 1, 0, 3) if t >= 0.0 else 0


## The visible buttons (tests: every one is live from the first frame).
func buttons() -> Array[UiButton]:
	var out: Array[UiButton] = []
	for b in [next_button, retry_button, playbill_button, stage_door_button]:
		if b != null and b.visible:
			out.append(b)
	return out


## No pop-in: the buttons must be where they are from the first frame.
func pop_k() -> float:
	return 1.0


func _build() -> void:
	scrim = Color(0, 0, 0, 0)
	_title = UiStrings.t("results.title")
	_star_names = PackedStringArray([UiStrings.t("results.star_1"), UiStrings.t("results.star_2"),
		UiStrings.t("results.star_3")])
	_applause_label = _s("curtain.applause", "results.applause")
	_new_label = _s("curtain.new", "results.new")
	_reel_label = UiStrings.t("results.gag_reel")
	_tex_star = UiIcons.get_icon(&"star")
	_tex_empty = UiIcons.get_icon(&"star_empty")
	next_button = _make_button("NextNight", "", NEXT_SIZE, UiKit.GOLD, UiKit.GOLD_SHADE, &"play", "next")
	next_button.icon_after = true
	next_button.font_size = 64
	next_button.icon_px = 84.0
	next_button.radius = 44.0
	retry_button = _make_button("Retry", _s("curtain.retry", "results.retry"), SMALL_SIZE, UiKit.CREAM,
		UiKit.CREAM_SHADE, &"retry", "retry")
	playbill_button = _make_button("Playbill", _s("curtain.playbill", "results.playbill"), SMALL_SIZE, UiKit.CREAM,
		UiKit.CREAM_SHADE, &"script", "playbill")
	stage_door_button = _make_button("StageDoor", _s("curtain.stage_door", "curtain.stage_door"), SMALL_SIZE,
		UiKit.CREAM, UiKit.CREAM_SHADE, &"lock", "stage_door")
	_rebuild_buttons()


func _make_button(nm: String, text: String, sz: Vector2, fill: Color, shade: Color, icon: StringName,
		action: String) -> UiButton:
	var b := UiButton.make(text, sz, fill, shade, UiIcons.get_icon(icon))
	b.name = nm
	if sz.y < NEXT_SIZE.y:
		b.hit_pad = Vector2(0, 12)
	b.pressed.connect(_on_button.bind(b, action))
	card.add_child(b)
	return b


func _on_button(b: UiButton, action: String) -> void:
	if b == next_button:
		close("again" if variant == "gate0" else "next")
	else:
		close(action)


func _rebuild_buttons() -> void:
	if next_button == null:
		return
	match variant:
		"gate0":
			next_button.text = _s("curtain.again", "curtain.again")
			back_action = "stage_door"
		"prologue":
			next_button.text = _s("curtain.night1", "results.next")
			back_action = "next"
		_:
			next_button.text = _s("curtain.next_night", "results.next")
			back_action = "playbill"
	# "▶" is the play icon after the label (the fonts have no U+25B6 glyph)
	next_button.icon = UiIcons.get_icon(&"play")
	next_button.disabled = variant == "night" and not has_next
	retry_button.visible = variant != "gate0"
	playbill_button.visible = variant == "night"
	stage_door_button.visible = variant == "gate0"
	for b in [next_button, retry_button, playbill_button, stage_door_button]:
		(b as UiButton).queue_redraw()


func _s(key: String, fallback_key: String) -> String:
	return UiStrings.t(key) if UiStrings.has(key) else UiStrings.t(fallback_key)


func _layout(rect: Rect2) -> void:
	card.position = Vector2.ZERO
	card.size = size
	var s := rect
	next_button.position = Vector2(s.end.x - 48.0 - NEXT_SIZE.x, s.end.y - 40.0 - NEXT_SIZE.y)
	var small_y := s.end.y - 40.0 - SMALL_SIZE.y
	retry_button.position = Vector2(s.position.x + 48.0, small_y)
	playbill_button.position = Vector2(s.position.x + 48.0 + SMALL_SIZE.x + 24.0, small_y)
	stage_door_button.position = retry_button.position
	var top := s.position.y + 170.0
	_reel = Rect2(s.end.x - 48.0 - REEL.x, top, REEL.x, REEL.y)
	_left = Rect2(s.position.x + 48.0, top, _reel.position.x - s.position.x - 96.0, 460.0)
	_wrap_why()


func _wrap_why() -> void:
	_why_lines = PackedStringArray()
	if why != "" and _left.size.x > 0.0:
		_why_lines = LoadingCard.wrap_lines(UiKit.ui_font(), why, _left.size.x, UiKit.text_size(UiKit.SIZE_PLAY))


func _scrim_tap(_pos: Vector2) -> void:
	skip()


func _tick() -> void:
	# count-up ticks (a soft ui_tick every TICK_EVERY applause while it runs)
	var sa := shown_applause()
	if sa != _count_shown:
		_count_shown = sa
		_count_text = str(sa)
		if sa / TICK_EVERY != _last_tick / TICK_EVERY and _skip_at_ms < 0:
			UiKit.sfx("ui_tick")
		_last_tick = sa
	var due := stamps_landed()
	var landed_now := 0
	while _stamped < due:
		if bool(stars[_stamped]):
			landed_now += 1
		_stamped += 1
	if landed_now > 0:
		UiKit.sfx("stamp")
		UiKit.haptic(&"rig_done")
	if not _new_sting and not new_items.is_empty() and step() >= Step.WHY:
		_new_sting = true
		UiKit.sfx("sting_new")
	if not _finished_emitted and step() == Step.DONE:
		_finished_emitted = true
		sequence_finished.emit()
	# the count, stamps, chips and the default button's glow animate: redraw each frame
	card.queue_redraw()


func _draw_panel() -> void:
	if stage:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.CURTAIN_SHADE)
		var fold := size.x / 16.0
		for i in 16:
			draw_rect(Rect2(float(i) * fold + fold * 0.6, 0, fold * 0.4, size.y), Color(UiKit.CURTAIN, 0.55))
		draw_rect(Rect2(0, size.y - 28.0, size.x, 28.0), UiKit.GOLD_SHADE)
		draw_rect(Rect2(0, size.y - 34.0, size.x, 6.0), UiKit.GOLD_LIGHT)
	# a soft navy wash behind the upper block only, so the text reads over the curtain and the
	# lower stage band stays clear for Bellows
	var wash_h := _left.end.y + 40.0
	var steps := 8
	for i in steps:
		var y0 := wash_h * float(i) / float(steps)
		var a := 0.5 * (1.0 - float(i) / float(steps))
		draw_rect(Rect2(0, y0, size.x, wash_h / float(steps) + 1.0), Color(UiKit.NAVY, a))


func _draw_card(ci: Control) -> void:
	var s := safe_rect()
	var df := UiKit.display_font()
	var t := seq_ms()
	UiKit.draw_text_centered(ci, df, Vector2(size.x * 0.5, s.position.y + 64.0), _title, UiKit.SIZE_TITLE,
		UiKit.GOLD_LIGHT, 18)
	if night_title != "":
		UiKit.draw_text_centered(ci, UiKit.ui_font(), Vector2(size.x * 0.5, s.position.y + 128.0), night_title,
			UiKit.SIZE_PLAY, UiKit.CREAM, 10)
	var lc := _left.get_center().x
	# the Applause dial + count-up
	var row_y := _left.position.y + DIAL * 0.5
	var dial_c := Vector2(lc - 150.0, row_y)
	_draw_dial(ci, dial_c, float(shown_applause()))
	UiKit.draw_text(ci, df, Vector2(dial_c.x + DIAL * 0.5 + 28.0, row_y - 22.0), _applause_label, UiKit.SIZE_PLAY,
		UiKit.GOLD_LIGHT, 10)
	var enc := shown_applause() >= 100
	UiKit.draw_text(ci, df, Vector2(dial_c.x + DIAL * 0.5 + 24.0, row_y + 66.0), _count_text, UiKit.SIZE_BIG_TITLE,
		UiKit.GOLD_LIGHT if enc else UiKit.CREAM, 18)
	var y := _left.position.y + DIAL + 24.0
	# stamps
	if has_stamps():
		var pitch := minf(STAMP_PITCH, _left.size.x / 3.0)
		var sx := lc - pitch
		var st0 := float(COUNT_FROM_MS + COUNT_MS)
		for i in 3:
			var c := Vector2(sx + float(i) * pitch, y + STAMP * 0.5)
			var lt := (t - st0 - float(i * STAMP_MS)) / float(STAMP_LAND_MS)
			if _skip_at_ms >= 0:
				lt = 1.0
			ci.draw_circle(c, STAMP * 0.5 + 6.0, Color(UiKit.NAVY, 0.55))
			var earned := bool(stars[i])
			if lt < 0.0:
				UiKit.draw_icon(ci, _tex_empty, Rect2(c - Vector2(STAMP, STAMP) * 0.4, Vector2(STAMP, STAMP) * 0.8),
					Color(1, 1, 1, 0.35))
			else:
				var k := 1.0 if UiKit.reduce_motion() else lerpf(1.9, 1.0, clampf(lt, 0.0, 1.0))
				var e := STAMP * 0.86 * k
				UiKit.draw_icon(ci, _tex_star if earned else _tex_empty, Rect2(c - Vector2(e, e) * 0.5, Vector2(e, e)),
					Color(1, 1, 1, clampf(lt * 2.0, 0.0, 1.0) if earned else 0.6))
			var nm := _star_names[i]
			var fs := ScriptPanel.fit_size(UiKit.ui_font(), nm, pitch - 16.0, UiKit.SIZE_MIN)
			UiKit.draw_text_centered(ci, UiKit.ui_font(), c + Vector2(0, STAMP * 0.5 + 30.0), nm, fs,
				UiKit.CREAM if earned and lt >= 0.0 else Color(UiKit.CREAM, 0.5), 10)
		y += STAMP + 64.0
	# the why-missed line
	if not _why_lines.is_empty():
		var why_t := t - (total_ms() - float(WHY_FADE_MS) - 100.0)
		var a := clampf(why_t / float(WHY_FADE_MS), 0.0, 1.0)
		var fs2 := UiKit.text_size(UiKit.SIZE_PLAY)
		var ly := y + 12.0
		for l in _why_lines:
			UiKit.draw_text_centered(ci, UiKit.ui_font(), Vector2(lc, ly), l, fs2, Color(UiKit.CREAM, a), 10,
				Color(UiKit.NAVY, a))
			ly += float(fs2) * 1.25
	# the Gag Reel slot
	UiKit.draw_chunky_rect(ci, _reel.grow(14.0), 24.0, UiKit.GOLD, UiKit.GOLD_SHADE, UiKit.BUTTON_OUTLINE, 8.0)
	if reel_texture != null:
		ci.draw_texture_rect(reel_texture, _reel, false)
	else:
		ci.draw_rect(_reel, UiKit.PLUM)
		UiKit.draw_text_centered(ci, df, _reel.get_center(), _reel_label, UiKit.SIZE_BANNER, Color(UiKit.CREAM, 0.5), 0)
	# +NEW! chips (pop in with the why line)
	if step() >= Step.WHY or _skip_at_ms >= 0:
		var cx := _reel.position.x
		var cy := _reel.end.y + 30.0
		var now := UiKit.now_ms()
		for n in new_items:
			var txt := "%s %s" % [_new_label, n]
			var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN).x + 36.0
			if cx + w > _reel.end.x:
				cx = _reel.position.x
				cy += 70.0
			var pulse := 1.0 if UiKit.reduce_motion() else 1.0 + 0.04 * sin(float(now) * 0.006)
			var rr := Rect2(cx, cy, w * pulse, 58.0)
			UiKit.draw_chunky_rect(ci, rr, 29.0, UiKit.CHERRY, UiKit.CHERRY_SHADE, 5.0, 6.0)
			UiKit.draw_text_centered(ci, df, rr.get_center() + Vector2(0, -2), txt, UiKit.SIZE_MIN, UiKit.CREAM, 0)
			cx += w + 16.0
	# the default button's glow (it is where the right thumb already is)
	if not next_button.disabled and not UiKit.reduce_flash():
		var g := 0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * 0.9)
		var br := Rect2(next_button.position, next_button.size).grow(10.0 + 6.0 * g)
		UiKit.draw_chunky_rect(ci, br, 54.0, Color(UiKit.GOLD_LIGHT, 0.25 + 0.2 * g),
			Color(UiKit.GOLD_LIGHT, 0.25 + 0.2 * g), 0.0, 0.0)


## The brass Applause dial (0–100 over 240°, the ENCORE zone to 150), needle at `v`.
func _draw_dial(ci: Control, c: Vector2, v: float) -> void:
	var r := DIAL * 0.5
	ci.draw_circle(c + Vector2(0, 6), r + 8.0, Color(UiKit.NAVY, 0.4))
	UiKit.draw_disc(ci, c, r + 8.0, UiKit.BRASS, UiKit.BRASS_SHADE)
	ci.draw_circle(c, r - 4.0, UiKit.NAVY)
	ci.draw_circle(c, r - 9.0, UiKit.CREAM)
	var ra := r - 24.0
	var a0 := -PI * 0.5 - deg_to_rad(ApplauseMeter.SWEEP_DEG)
	var a1 := -PI * 0.5 + deg_to_rad(ApplauseMeter.SWEEP_DEG)
	ci.draw_arc(c, ra, a0, a0 + (a1 - a0) * 0.34, 16, UiKit.CHERRY, 14.0, true)
	ci.draw_arc(c, ra, a0 + (a1 - a0) * 0.34, a0 + (a1 - a0) * 0.67, 16, UiKit.YELLOW, 14.0, true)
	ci.draw_arc(c, ra, a0 + (a1 - a0) * 0.67, a1, 16, UiKit.GREEN, 14.0, true)
	ci.draw_arc(c, ra, a1, a1 + deg_to_rad(ApplauseMeter.ENCORE_DEG), 8, UiKit.GOLD_LIGHT, 14.0, true)
	var vv := clampf(v, 0.0, 150.0)
	var ang := -deg_to_rad(ApplauseMeter.SWEEP_DEG) + deg_to_rad(ApplauseMeter.SWEEP_DEG * 2.0) * minf(vv, 100.0) / 100.0
	if vv > 100.0:
		ang += deg_to_rad(ApplauseMeter.ENCORE_DEG) * (vv - 100.0) / 50.0
	var nd := Vector2(sin(ang), -cos(ang))
	ci.draw_line(c - nd * 10.0, c + nd * (r - 16.0), UiKit.NAVY, 9.0, true)
	ci.draw_line(c + nd * (r - 38.0), c + nd * (r - 16.0), UiKit.CHERRY, 6.0, true)
	ci.draw_circle(c, 13.0, UiKit.NAVY)
	ci.draw_circle(c, 7.0, UiKit.BRASS_LIGHT)
