## FiggisChip — Old Figgis, the prompter mouse (GDD §3.8, §6.4; REDESIGN_3D §2.2): a CONTEXTUAL
## 128 px bust (144 hit) at (S+24, T+192) that the Hud shows only on a nudge (40 s without
## progress), a card cue, or "Hint" from the pause panel, and hides again after 4 s. States:
##   idle   his bust in the prompt box (figgis_chip.svg);
##   pulse  ladder step 1: he bobs and a "psst!" bubble pops out (figgis_psst.svg);
##   card   ladder step 2: he holds up his card (figgis_point.svg) and a 320 × 200 cue card of 2–3
##          icons joined by arrows opens to his right for CARD_SEC (`show_card(icons)`);
##   ghost  ladder step 3 armed: a pale glow (the next tap = "show me").
## One-shot moods on top (`react("shh" | "proud", seconds)`). Tap → `figgis_tap()`. The card and the
## bubble are never targets.
##
## R3D (index R7): the chip always runs at its SVG level — a flat matte-vinyl bust in look A's
## palette, one SVG per mood (`res://art/chars/figgis/figgis_<mood>.svg`, `figgis_chip.svg` = idle),
## swapped with a 0.15 s bob / tilt so he still feels alive. It has NO dependency on the 2D rig
## runtime (the idle rig animation of Stage 2 is gone — a stated downgrade; the 3D-style sprite is
## R3). `level` stays for callers of the old API and is always Level.SVG.
class_name FiggisChip
extends TouchWidget

signal figgis_tap()

const HIT := 144.0
const VISUAL := 128.0
const CARD_SEC := 4.0
const CARD_W := 320.0
const CARD_H := 200.0
const CARD_ICON := 88.0
const ART_DIR := "res://art/chars/figgis/"
const ART_IDLE := ART_DIR + "figgis_chip.svg"
## Kept for callers of the Stage-2 API (the idle bust's path).
const ART_HUSH_PATH := ART_IDLE
const REACT_SEC := 1.6
const SWAP_S := 0.15
const PSST_TAIL: PackedVector2Array = [Vector2(HIT + 10.0, 52.0), Vector2(HIT - 10.0, 66.0), Vector2(HIT + 14.0, 64.0)]
const PSST_TAIL_FLIP: PackedVector2Array = [Vector2(-10.0, 52.0), Vector2(10.0, 66.0), Vector2(-14.0, 64.0)]
const MOODS: PackedStringArray = ["idle", "psst", "point", "shh", "proud"]

enum State { IDLE, PULSE, CARD, GHOST }
## Stage-2 fallback levels; R3D always uses SVG.
enum Level { SVG, POSES, CLIPS }

var state: int = State.IDLE
## The chip sits in the top-RIGHT corner (left-handed): the bubble and the card open leftward.
var flip: bool = false
var pulse_on: bool = false
var ghost_on: bool = false
## Always Level.SVG (R7).
var level: int = Level.SVG
## The mood on screen ("idle", "psst", "point", "shh", "proud").
var mood: String = ""
## "svg:<mood>" — which art is drawn (tests / debug).
var mood_source: String = ""

var _card_icons: Array[Texture2D] = []
var _card_until_ms: int = -100000
var _card_from_ms: int = -100000
var _react_mood: String = ""
var _react_until_ms: int = -100000
var _tex: Dictionary = {}
var _tex_face: Texture2D = null
var _tex_arrow: Texture2D = null
var _psst: String = "psst!"
var _swap_ms: int = -100000


func _init() -> void:
	super()
	size = Vector2(HIT, HIT)
	custom_minimum_size = size


func _ready() -> void:
	_tex_arrow = UiIcons.get_icon(&"arrow")
	_psst = UiStrings.t("ftue.psst") if UiStrings.has("ftue.psst") else UiStrings.t("hud.psst")
	for m in MOODS:
		_tex[m] = UiIcons.texture(art_path(m))
	if _tex.get("idle") == null:
		_tex["idle"] = UiIcons.get_icon(&"figgis_chip")
	_refresh_state()


## The SVG of a mood (pure; tests).
static func art_path(p_mood: String) -> String:
	return ART_IDLE if p_mood == "idle" else ART_DIR + "figgis_" + p_mood + ".svg"


## Stage-2 API: the level for a rig (always SVG in R3D; kept so old callers compile).
static func level_for(_has_rig: bool, _has_idle_clip: bool) -> int:
	return Level.SVG


## Ladder step 1 on / off.
func set_pulse(on: bool) -> void:
	if on == pulse_on:
		return
	pulse_on = on
	_refresh_state()


## Ladder step 3 armed on / off.
func set_ghost(on: bool) -> void:
	if on == ghost_on:
		return
	ghost_on = on
	_refresh_state()


## Ladder step 2: a cue card of 2–3 icons (keys for UiIcons.card / item ids / paths), joined by
## arrows, for `seconds`; Figgis holds up his card.
func show_card(icons: PackedStringArray, seconds: float = CARD_SEC) -> void:
	_card_icons.clear()
	for k in icons:
		# barks.json cards spell the arrow out ("item", "arrow", "target"); the card draws its own
		if k == "" or k == "arrow":
			continue
		var t := UiIcons.card(k)
		if t != null:
			_card_icons.append(t)
	var now := UiKit.now_ms()
	_card_from_ms = now
	_card_until_ms = now + int(seconds * 1000.0)
	UiKit.sfx("card")
	_refresh_state()


## Hide the card now.
func hide_card() -> void:
	_card_until_ms = -100000
	_refresh_state()


## True while the cue card is up.
func card_visible() -> bool:
	return UiKit.now_ms() < _card_until_ms and not _card_icons.is_empty()


## The cue card's icons (tests).
func card_icon_count() -> int:
	return _card_icons.size() if card_visible() else 0


## When the card closes (UiKit.now_ms() clock; the Hud's auto-hide).
func card_until_ms() -> int:
	return _card_until_ms


## A one-shot mood ("shh", "proud", "psst", "point", "idle") for `seconds`, then back.
func react(p_mood: String, seconds: float = REACT_SEC) -> void:
	if not MOODS.has(p_mood):
		return
	_react_mood = p_mood
	_react_until_ms = UiKit.now_ms() + int(seconds * 1000.0)
	_refresh_state()


## The mood a state shows.
static func mood_for_state(s: int) -> String:
	match s:
		State.PULSE:
			return "psst"
		State.CARD:
			return "point"
	return "idle"


## The card's rect in local px (to the right of the bust; left when flipped).
func card_rect() -> Rect2:
	var x := HIT + 12.0 if not flip else -12.0 - CARD_W
	return Rect2(x, 0.0, CARD_W, CARD_H)


func _refresh_state() -> void:
	if card_visible():
		state = State.CARD
	elif ghost_on:
		state = State.GHOST
	elif pulse_on:
		state = State.PULSE
	else:
		state = State.IDLE
	var m := mood_for_state(state)
	if _react_mood != "" and UiKit.now_ms() < _react_until_ms and state != State.CARD:
		m = _react_mood
	elif UiKit.now_ms() >= _react_until_ms:
		_react_mood = ""
	_set_mood(m)
	set_process(state != State.IDLE or _react_mood != "" or UiKit.now_ms() - _swap_ms < int(SWAP_S * 1000.0))
	queue_redraw()


func _set_mood(m: String) -> void:
	if m == mood and mood_source != "":
		return
	if mood != "":
		_swap_ms = UiKit.now_ms()
	mood = m
	_tex_face = _tex.get(m, null)
	if _tex_face == null:
		_tex_face = _tex.get("idle", null)
	mood_source = "svg:" + m


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		figgis_tap.emit()


func _process(_delta: float) -> void:
	if state == State.CARD and not card_visible():
		_refresh_state()
	elif _react_mood != "" and UiKit.now_ms() >= _react_until_ms:
		_refresh_state()
	queue_redraw()
	if state == State.IDLE and _react_mood == "" and UiKit.now_ms() - _swap_ms >= int(SWAP_S * 1000.0):
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var t := float(now) * 0.001
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var bob := 0.0
	var tilt := 0.0
	if not UiKit.reduce_motion():
		if state == State.PULSE:
			k *= 1.0 + 0.06 * maxf(0.0, sin(t * TAU * 1.2))
			bob = -4.0 * maxf(0.0, sin(t * TAU * 1.2))
		var st := float(now - _swap_ms) / (SWAP_S * 1000.0)
		if st >= 0.0 and st < 1.0:
			# the mood swap: a little hop and a tilt that settles (he still feels alive)
			bob -= 8.0 * sin(st * PI)
			tilt = 0.12 * sin(st * PI) * (-1.0 if flip else 1.0)
	var r := VISUAL * 0.5
	draw_set_transform(c + Vector2(0, bob), tilt, Vector2(k, k))
	if state == State.GHOST:
		var g := 0.5 + 0.5 * sin(t * TAU * 0.8)
		UiShapes.begin()
		UiShapes.circle(Vector2.ZERO, r + 10.0 + 4.0 * g, Color(0.85, 0.92, 1.0, 0.35 + 0.25 * g))
		UiShapes.flush(self)
	var fm := Color(1, 1, 1, 0.75) if state == State.GHOST else Color.WHITE
	UiKit.draw_icon(self, _tex_face, Rect2(-r, -r, VISUAL, VISUAL), fm)
	draw_set_transform(Vector2.ZERO)
	if state == State.PULSE or (state != State.CARD and mood == "psst"):
		_draw_psst(t)
	elif state == State.CARD:
		_draw_card(now)


func _draw_psst(t: float) -> void:
	var f := UiKit.display_font()
	var fs := UiKit.SIZE_PLAY
	var w := f.get_string_size(_psst, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var a := clampf(0.6 + 0.4 * sin(t * TAU * 1.2), 0.0, 1.0)
	var rect := Rect2(HIT + 4.0, 18.0, w, 64.0) if not flip else Rect2(-4.0 - w, 18.0, w, 64.0)
	UiShapes.begin()
	UiKit.draw_chunky_rect(self, rect, 28.0, UiKit.CREAM, UiKit.CREAM_SHADE, 5.0, 6.0)
	UiShapes.poly(PSST_TAIL_FLIP if flip else PSST_TAIL, UiKit.CREAM)
	UiShapes.flush(self)
	UiKit.draw_text_centered(self, f, rect.get_center() + Vector2(0, -2), _psst, fs, Color(UiKit.NAVY, a), 0)


func _draw_card(now: int) -> void:
	var n := _card_icons.size()
	if n == 0:
		return
	var ap := clampf(float(now - _card_from_ms) / 160.0, 0.0, 1.0)
	var out := clampf(float(_card_until_ms - now) / 200.0, 0.0, 1.0)
	var k := (0.7 + 0.3 * ap) * out
	var cr := card_rect()
	var pivot := Vector2(cr.position.x if not flip else cr.end.x, cr.position.y + cr.size.y * 0.5)
	draw_set_transform(pivot, 0.0, Vector2(k, k))
	var rect := Rect2(cr.position - pivot, cr.size)
	UiKit.draw_chunky_rect(self, rect, 26.0, UiKit.PAPER, UiKit.PAPER_SHADE, 6.0, 12.0)
	# icons joined by arrows, fitted to the card
	var arrow_w := 44.0
	var icon := minf(CARD_ICON, (CARD_W - 40.0 - float(n - 1) * (arrow_w + 8.0)) / float(n))
	var total := float(n) * icon + float(n - 1) * (arrow_w + 8.0)
	var x := rect.position.x + (CARD_W - total) * 0.5
	var y := rect.position.y + (CARD_H - 12.0 - icon) * 0.5
	for i in n:
		UiKit.draw_icon(self, _card_icons[i], Rect2(x, y, icon, icon))
		x += icon
		if i < n - 1:
			UiKit.draw_icon(self, _tex_arrow, Rect2(x + 4.0, y + icon * 0.5 - arrow_w * 0.5, arrow_w, arrow_w))
			x += arrow_w + 8.0
	draw_set_transform(Vector2.ZERO)
