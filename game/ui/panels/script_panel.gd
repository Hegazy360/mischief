## ScriptPanel — "Tonight's Script" (GDD §3.8, §6.2), opened from the Applause-o-Meter (the game
## pauses while it is up). A 1000 × 680 playbill card:
##   * a curtain-red header with the title;
##   * one 84 px row per line (44 px text, auto-shrunk to fit, never below 36): a 72 px status
##     stamp (tick = done, Hush's beret = rigged, open ring = to do, wax seal = the Big Number),
##     the punchline text ("???" while undiscovered), a candle when solved after a step-3 hint,
##     and a red ribbon on required lines. The sealed Big Number reads "Sealed until …";
##   * his loop as an activity-icon strip along the bottom, rigged stations stamped with the
##     beret, the current one ringed.
## `setup(lines, loop, done, total)` — lines / loop exactly as HudModel.script_lines / script_loop.
## Tap anywhere (or Back) closes with "close".
class_name ScriptPanel
extends UiPanel

const W := 1000.0
const H := 680.0
const HEADER_H := 76.0
const ROW_H := 84.0
const STRIP_H := 84.0
const STAMP := 72.0
const PAD := 28.0

var lines: Array = []
var loop: Array = []
var done_count: int = 0
var total_count: int = 0

var _tex := {}
var _title: String = ""
var _unknown: String = "???"
var _sealed: String = ""
var _big: String = ""
var _routine: String = ""
var _loop_tex: Array[Texture2D] = []


## Fill the panel (call before adding it to the tree, or any time after).
func setup(p_lines: Array, p_loop: Array, p_done: int = -1, p_total: int = -1) -> void:
	lines = p_lines
	loop = p_loop
	done_count = p_done
	total_count = p_total
	if done_count < 0 or total_count < 0:
		done_count = 0
		total_count = 0
		for l in lines:
			if not bool((l as Dictionary).get("big_number", false)):
				total_count += 1
				if bool((l as Dictionary).get("done", false)):
					done_count += 1
	_loop_tex.clear()
	for a in loop:
		var d: Dictionary = a
		var ic := String(d.get("icon", ""))
		_loop_tex.append(UiIcons.activity(ic if ic != "" else String(d.get("activity", ""))))
	if is_inside_tree():
		_relayout()


func _build() -> void:
	back_action = "close"
	for k in ["stamp_tick", "stamp_beret", "wax_seal", "ribbon", "candle"]:
		_tex[k] = UiIcons.get_icon(StringName(k))
	_title = UiStrings.t("script.title")
	_unknown = UiStrings.t("script.undiscovered")
	_sealed = UiStrings.t("script.sealed")
	_big = UiStrings.t("script.big_number")
	_routine = UiStrings.t("script.routine")


func _layout(rect: Rect2) -> void:
	card.size = Vector2(W, H)
	card.position = rect.get_center() - card.size * 0.5


func _scrim_tap(_pos: Vector2) -> void:
	if age_ms() > 150:
		close("close")


## Row height for `n` lines (84 px, compressed only when 7 lines would overflow the card).
static func row_height(n: int) -> float:
	var avail := H - HEADER_H - STRIP_H - 16.0
	return minf(ROW_H, avail / float(maxi(1, n)))


func _draw_card(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	UiKit.draw_chunky_rect(ci, r.grow(4.0), 40.0, Color(UiKit.NAVY, 0.4), Color(UiKit.NAVY, 0.4), 0.0, 0.0)
	UiKit.draw_chunky_rect(ci, r, 36.0, UiKit.PAPER, UiKit.PAPER_SHADE, UiKit.BUTTON_OUTLINE, 14.0)
	# header band
	var hr := Rect2(6, 6, W - 12, HEADER_H)
	UiKit.draw_chunky_rect(ci, hr, 30.0, UiKit.CURTAIN, UiKit.CURTAIN_SHADE, 0.0, 8.0)
	ci.draw_rect(Rect2(6, HEADER_H - 20, W - 12, 26), UiKit.CURTAIN)
	ci.draw_rect(Rect2(6, HEADER_H + 2, W - 12, 6), UiKit.GOLD)
	var f := UiKit.display_font()
	UiKit.draw_text_centered(ci, f, Vector2(W * 0.5, HEADER_H * 0.5 + 6.0), _title, 56, UiKit.CREAM, 12)
	var cnt := "%d/%d" % [done_count, total_count]
	UiKit.draw_text(ci, f, Vector2(W - PAD - 110.0, HEADER_H * 0.5 + 24.0), cnt, UiKit.SIZE_HUD_NUM_S, UiKit.GOLD_LIGHT, 10)
	# rows
	var rh := row_height(lines.size())
	var y := HEADER_H + 8.0
	for i in lines.size():
		_draw_row(ci, lines[i], Rect2(PAD, y, W - PAD * 2.0, rh), i)
		y += rh
	# his loop
	_draw_loop(ci, Rect2(PAD, H - STRIP_H - 8.0, W - PAD * 2.0, STRIP_H))


func _draw_row(ci: Control, line: Dictionary, r: Rect2, i: int) -> void:
	if i % 2 == 1:
		UiKit.draw_chunky_rect(ci, r.grow_individual(0, -3, 0, -3), 18.0, Color(UiKit.PAPER_SHADE, 0.45),
			Color(UiKit.PAPER_SHADE, 0.45), 0.0, 0.0)
	var done := bool(line.get("done", false))
	var rigged := bool(line.get("rigged", false))
	var req := bool(line.get("req", false))
	var big := bool(line.get("big_number", false))
	var sealed := bool(line.get("sealed", false))
	var discovered := bool(line.get("discovered", true))
	var candle := bool(line.get("candle", false))
	var st := minf(STAMP, r.size.y - 8.0)
	var sr := Rect2(r.position.x + 4.0, r.position.y + (r.size.y - st) * 0.5, st, st)
	if big:
		UiKit.draw_icon(ci, _tex["wax_seal"], sr)
		if done:
			UiKit.draw_icon(ci, _tex["stamp_tick"], sr.grow(-10.0))
	elif done:
		UiKit.draw_icon(ci, _tex["stamp_tick"], sr)
	elif rigged:
		UiKit.draw_icon(ci, _tex["stamp_beret"], sr)
	else:
		ci.draw_arc(sr.get_center(), st * 0.36, 0.0, TAU, 32, Color(UiKit.NAVY, 0.45), 6.0, true)
	# right-edge marks
	var right := r.end.x
	if req:
		UiKit.draw_icon(ci, _tex["ribbon"], Rect2(right - 44.0, r.position.y - 2.0, 44.0, minf(72.0, r.size.y)))
		right -= 56.0
	if candle:
		UiKit.draw_icon(ci, _tex["candle"], Rect2(right - 48.0, r.position.y + (r.size.y - 52.0) * 0.5, 48.0, 52.0))
		right -= 58.0
	# the text
	var tx := sr.end.x + 20.0
	var avail := right - tx - 8.0
	var text := String(line.get("text", ""))
	var col := UiKit.NAVY
	var fnt := UiKit.ui_font()
	if big and sealed:
		text = _big
		col = UiKit.CURTAIN
		fnt = UiKit.display_font()
	elif big:
		col = UiKit.CURTAIN
		fnt = UiKit.display_font()
	elif not discovered or text == "":
		text = _unknown
		col = Color(UiKit.NAVY, 0.4)
		fnt = UiKit.display_font()
	elif done:
		col = Color(UiKit.NAVY, 0.62)
	var fs := fit_size(fnt, text, avail, UiKit.text_size(UiKit.SIZE_PLAY))
	var base_y := r.position.y + r.size.y * 0.5 + fs * 0.36
	if big and sealed:
		fs = mini(fs, 40)
		base_y = r.position.y + r.size.y * 0.5 - 2.0
	ci.draw_string(fnt, Vector2(tx, base_y), clip_text(fnt, text, avail, fs), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if big and sealed:
		var s2 := fit_size(UiKit.ui_font(), _sealed, avail, UiKit.SIZE_MIN)
		ci.draw_string(UiKit.ui_font(), Vector2(tx, base_y + 36.0), clip_text(UiKit.ui_font(), _sealed, avail, s2),
			HORIZONTAL_ALIGNMENT_LEFT, -1, s2, Color(UiKit.NAVY, 0.55))
	if done and not big:
		var w := minf(avail, fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		ci.draw_line(Vector2(tx - 4.0, base_y - fs * 0.3), Vector2(tx + w + 4.0, base_y - fs * 0.3),
			Color(UiKit.GREEN_SHADE, 0.7), 5.0, true)


func _draw_loop(ci: Control, r: Rect2) -> void:
	ci.draw_line(Vector2(r.position.x, r.position.y - 4.0), Vector2(r.end.x, r.position.y - 4.0), Color(UiKit.NAVY, 0.25), 3.0)
	var f := UiKit.display_font()
	ci.draw_string(f, Vector2(r.position.x, r.position.y + 54.0), _routine, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN,
		UiKit.CURTAIN)
	var n := loop.size()
	if n == 0:
		return
	var label_w := f.get_string_size(_routine, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_MIN).x + 24.0
	var icon := 64.0
	var arrow := 30.0
	var span := r.size.x - label_w
	var step := minf(icon + arrow + 14.0, span / float(n))
	var x := r.position.x + label_w
	var cy := r.position.y + r.size.y * 0.5 + 2.0
	for i in n:
		var d: Dictionary = loop[i]
		var ir := Rect2(x, cy - icon * 0.5, icon, icon)
		if bool(d.get("current", false)):
			ci.draw_circle(ir.get_center(), icon * 0.5 + 6.0, Color(UiKit.GOLD, 0.45))
			ci.draw_arc(ir.get_center(), icon * 0.5 + 6.0, 0.0, TAU, 32, UiKit.GOLD_SHADE, 4.0, true)
		UiKit.draw_icon(ci, _loop_tex[i] if i < _loop_tex.size() else null, ir)
		if bool(d.get("rigged", false)):
			UiKit.draw_icon(ci, _tex["stamp_beret"], Rect2(ir.end.x - 40.0, ir.position.y - 8.0, 44.0, 44.0))
		if i < n - 1:
			var ax := ir.end.x + (step - icon) * 0.5
			ci.draw_line(Vector2(ax - 9.0, cy), Vector2(ax + 7.0, cy), Color(UiKit.NAVY, 0.5), 5.0, true)
			ci.draw_line(Vector2(ax + 1.0, cy - 8.0), Vector2(ax + 9.0, cy), Color(UiKit.NAVY, 0.5), 5.0, true)
			ci.draw_line(Vector2(ax + 1.0, cy + 8.0), Vector2(ax + 9.0, cy), Color(UiKit.NAVY, 0.5), 5.0, true)
		x += step
	# the loop wraps: a small return arrow at the end
	ci.draw_arc(Vector2(x - step + icon + 22.0, cy), 14.0, -PI * 0.9, PI * 0.9, 16, Color(UiKit.NAVY, 0.4), 5.0, true)


## Largest font size ≤ `want` (≥ SIZE_MIN) at which `text` fits `width`.
static func fit_size(f: Font, text: String, width: float, want: int) -> int:
	var s := want
	while s > UiKit.SIZE_MIN and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 2
	return maxi(s, UiKit.SIZE_MIN)


## `text` cut with "…" to fit `width` at size `fs`.
static func clip_text(f: Font, text: String, width: float, fs: int) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"
