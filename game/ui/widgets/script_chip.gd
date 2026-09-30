## ScriptChip — always-on piece #2 (REDESIGN_3D §2.1): the Script at a glance. A 312 × 144 hit at
## (S+192, T+24) around a navy (62 %) pill 96 px tall at T+48: the playbill icon 40 × 52, one 34 px
## pip per REQUIRED line (gold filled = done, white ring = open), one 14 px dot per optional line and a
## 32 px star for the Big Number (grey while sealed → gold). The pill grows with the Script:
## 112 + 46 per required + 22 per optional + 50 px, ≤ 440 (`HudLayout.script_pill_width`).
## Tap → `script_tap()` (the Hud forwards it as `meter_tap`, which opens the Script panel).
## When a line lands, the Hud's tag flight arrives here and `pop(line_index)` fills the pip with a pop.
class_name ScriptChip
extends TouchWidget

signal script_tap()

const H_HIT := 144.0
const PILL_H := 96.0
const PILL_Y := 24.0
const ICON := Vector2(40, 52)
const PIP := 34.0
const DOT := 14.0
const STAR := 32.0
const POP_MS := 280
const FILL := Color(0.106, 0.137, 0.251, 0.62)

const P := HudModel.Pip

## Pip codes (HudModel.Pip), in Script order.
var pips: PackedInt32Array = PackedInt32Array()

var _tex_icon: Texture2D = null
var _tex_star: Texture2D = null
var _pop_ms: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	super()
	size = Vector2(HudLayout.PILL_MIN_HIT, H_HIT)
	custom_minimum_size = size


func _ready() -> void:
	_tex_icon = UiIcons.get_icon(&"script")
	_tex_star = UiIcons.get_icon(&"star")
	set_process(false)


## Set the pips (no redraw when unchanged). A pip that turned done pops.
func set_pips(p: PackedInt32Array) -> void:
	if p == pips:
		return
	var now := UiKit.now_ms()
	var old := pips
	pips = p.duplicate()
	_pop_ms.resize(pips.size())
	for i in pips.size():
		var was := old[i] if i < old.size() else -1
		if was >= 0 and is_done(was) != is_done(pips[i]) and is_done(pips[i]):
			_pop_ms[i] = now
			set_process(true)
		elif i >= old.size():
			_pop_ms[i] = -100000
	size = Vector2(maxf(HudLayout.PILL_MIN_HIT, pill_width()), H_HIT)
	queue_redraw()


## Pop pip `i` (a tag flight arrived).
func pop(i: int) -> void:
	if i < 0 or i >= _pop_ms.size():
		return
	_pop_ms[i] = UiKit.now_ms()
	set_process(true)
	queue_redraw()


## Required / optional counts of the current pips.
func counts() -> Vector2i:
	var req := 0
	var opt := 0
	for c in pips:
		if c == P.REQ_OPEN or c == P.REQ_DONE:
			req += 1
		elif c == P.OPT_OPEN or c == P.OPT_DONE:
			opt += 1
	return Vector2i(req, opt)


## The pill's width (REDESIGN §2.1 formula).
func pill_width() -> float:
	var c := counts()
	return HudLayout.script_pill_width(c.x, c.y)


static func is_done(code: int) -> bool:
	return code == P.REQ_DONE or code == P.OPT_DONE or code == P.BIG_DONE


## Pips from HudModel.script_lines ({req, done, big_number, sealed}) — the fallback when the
## presenter does not fill `script_pips` (pure; allocates — call only when the lines changed).
static func pips_from_lines(lines: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var big := -1
	for l in lines:
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		if bool(d.get("big_number", false)):
			big = P.BIG_DONE if bool(d.get("done", false)) else (P.BIG_SEALED if bool(d.get("sealed", true)) else P.BIG_OPEN)
			continue
		var done := bool(d.get("done", false))
		if bool(d.get("req", false)):
			out.append(P.REQ_DONE if done else P.REQ_OPEN)
		else:
			out.append(P.OPT_DONE if done else P.OPT_OPEN)
	# required first, then optional, the Big Number last (the chip's reading order)
	var sorted := PackedInt32Array()
	for c in out:
		if c == P.REQ_OPEN or c == P.REQ_DONE:
			sorted.append(c)
	for c in out:
		if c == P.OPT_OPEN or c == P.OPT_DONE:
			sorted.append(c)
	if big >= 0:
		sorted.append(big)
	return sorted


## Pips from a bare "done / total" (all required; the oldest fallback).
static func pips_from_counts(done: int, total: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in maxi(0, total):
		out.append(P.REQ_DONE if i < done else P.REQ_OPEN)
	return out


## The centre of pip `i` in local px (the tag flight's target).
func pip_center(i: int) -> Vector2:
	var x := HudLayout.PILL_BASE
	for j in pips.size():
		var c := pips[j]
		var w := _slot_w(c)
		if j == i:
			return Vector2(x + w * 0.5, PILL_Y + PILL_H * 0.5)
		x += w
	return Vector2(x, PILL_Y + PILL_H * 0.5)


static func _slot_w(c: int) -> float:
	if c == P.REQ_OPEN or c == P.REQ_DONE:
		return HudLayout.PILL_REQ
	if c == P.OPT_OPEN or c == P.OPT_DONE:
		return HudLayout.PILL_OPT
	return HudLayout.PILL_BIG


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		script_tap.emit()


func _process(_delta: float) -> void:
	queue_redraw()
	var now := UiKit.now_ms()
	for t in _pop_ms:
		if now - t < POP_MS:
			return
	set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var w := minf(pill_width(), HudLayout.PILL_MAX)
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var c := Vector2(w * 0.5, PILL_Y + PILL_H * 0.5)
	draw_set_transform(c, 0.0, Vector2(k, k))
	var o := -c
	UiShapes.begin()
	UiShapes.rrect(Rect2(o + Vector2(0, PILL_Y + 4), Vector2(w, PILL_H)), PILL_H * 0.5, Color(0, 0, 0, 0.18))
	UiShapes.rrect(Rect2(o + Vector2(0, PILL_Y), Vector2(w, PILL_H)), PILL_H * 0.5, FILL)
	var x := HudLayout.PILL_BASE
	var cy := o.y + PILL_Y + PILL_H * 0.5
	for i in pips.size():
		var code := pips[i]
		var sw := _slot_w(code)
		var cx := o.x + x + sw * 0.5
		var pk := 1.0
		if i < _pop_ms.size():
			var pt := float(now - _pop_ms[i]) / float(POP_MS)
			if pt >= 0.0 and pt < 1.0 and not UiKit.reduce_motion():
				pk = 1.0 + 0.45 * sin(pt * PI)
		match code:
			P.REQ_DONE:
				UiShapes.circle(Vector2(cx, cy), PIP * 0.5 * pk + 3.0, UiKit.NAVY)
				UiShapes.circle(Vector2(cx, cy), PIP * 0.5 * pk, UiKit.GOLD)
				UiShapes.circle(Vector2(cx - 5, cy - 6), 5.0 * pk, UiKit.GOLD_LIGHT)
			P.REQ_OPEN:
				UiShapes.arc(Vector2(cx, cy), PIP * 0.5 - 3.0, 0.0, TAU, 6.0, UiKit.WHITE, 32)
			P.OPT_DONE:
				UiShapes.circle(Vector2(cx, cy), DOT * 0.5 * pk + 2.0, UiKit.NAVY)
				UiShapes.circle(Vector2(cx, cy), DOT * 0.5 * pk, UiKit.GOLD)
			P.OPT_OPEN:
				UiShapes.arc(Vector2(cx, cy), DOT * 0.5 - 1.5, 0.0, TAU, 3.0, Color(1, 1, 1, 0.85), 16)
		x += sw
	UiShapes.flush(self)
	UiKit.draw_icon(self, _tex_icon, Rect2(o + Vector2(40.0, PILL_Y + (PILL_H - ICON.y) * 0.5), ICON))
	# the Big Number star (grey while sealed, gold once unsealed / done)
	x = HudLayout.PILL_BASE
	for i in pips.size():
		var code := pips[i]
		var sw := _slot_w(code)
		if code == P.BIG_SEALED or code == P.BIG_OPEN or code == P.BIG_DONE:
			var col := Color(0.62, 0.6, 0.7, 0.9) if code == P.BIG_SEALED else Color.WHITE
			UiKit.draw_icon(self, _tex_star, Rect2(o + Vector2(x + (sw - STAR) * 0.5, PILL_Y + (PILL_H - STAR) * 0.5),
				Vector2(STAR, STAR)), col)
		x += sw
	draw_set_transform(Vector2.ZERO)
