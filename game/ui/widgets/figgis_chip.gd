## FiggisChip — Old Figgis, the prompter, in his top-left chip beside Pause (GDD §3.8, §6.4):
## 144 hit / 128 visual at (S+192, T+24). States:
##   idle   the hooded bust, still;
##   pulse  ladder step 1 (40 s without progress): the chip bobs and a "psst!" bubble pops out;
##   card   ladder step 2 (after a tap): a cue card of 2–3 icons with arrows for CARD_SEC
##          below the chip (`show_card(icons)`);
##   ghost  ladder step 3 armed: a pale ghost glow (the next tap = "show me").
## Tap → `figgis_tap()`. The card and bubble are drawn by the chip and are never targets.
## Figgis's face comes from art-hush when present (`res://art/chars/figgis/figgis_chip.svg`),
## else from `res://art/ui/figgis_chip.svg`.
class_name FiggisChip
extends TouchWidget

signal figgis_tap()

const HIT := 144.0
const VISUAL := 128.0
const CARD_SEC := 4.0
const CARD_ICON := 88.0
const ART_HUSH_PATH := "res://art/chars/figgis/figgis_chip.svg"
const PSST_TAIL: PackedVector2Array = [Vector2(HIT + 10.0, 52.0), Vector2(HIT - 10.0, 66.0), Vector2(HIT + 14.0, 64.0)]
const PSST_TAIL_FLIP: PackedVector2Array = [Vector2(-10.0, 52.0), Vector2(10.0, 66.0), Vector2(-14.0, 64.0)]

enum State { IDLE, PULSE, CARD, GHOST }

var state: int = State.IDLE
## The chip sits in the top-RIGHT corner (left-handed): the "psst" bubble and the cue card open
## toward the screen centre (leftward). Set by the Hud.
var flip: bool = false
var pulse_on: bool = false
var ghost_on: bool = false

var _card_icons: Array[Texture2D] = []
var _card_until_ms: int = -100000
var _card_from_ms: int = -100000
var _tex_face: Texture2D = null
var _tex_arrow: Texture2D = null
var _psst: String = "psst!"


func _init() -> void:
	super()
	size = Vector2(HIT, HIT)
	custom_minimum_size = size


func _ready() -> void:
	_tex_face = UiIcons.texture(ART_HUSH_PATH)
	if _tex_face == null:
		_tex_face = UiIcons.get_icon(&"figgis_chip")
	_tex_arrow = UiIcons.get_icon(&"arrow")
	_psst = UiStrings.t("hud.psst")
	set_process(false)


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


## Ladder step 2: show a cue card of 2–3 icons (keys for UiIcons.card / item ids / paths),
## joined by arrows, for `seconds`.
func show_card(icons: PackedStringArray, seconds: float = CARD_SEC) -> void:
	_card_icons.clear()
	for k in icons:
		var t := UiIcons.card(k)
		if t != null:
			_card_icons.append(t)
	var now := UiKit.now_ms()
	_card_from_ms = now
	_card_until_ms = now + int(seconds * 1000.0)
	_refresh_state()


## Hide the card now.
func hide_card() -> void:
	_card_until_ms = -100000
	_refresh_state()


## True while the cue card is up.
func card_visible() -> bool:
	return UiKit.now_ms() < _card_until_ms and not _card_icons.is_empty()


func _refresh_state() -> void:
	if card_visible():
		state = State.CARD
	elif ghost_on:
		state = State.GHOST
	elif pulse_on:
		state = State.PULSE
	else:
		state = State.IDLE
	set_process(state != State.IDLE)
	queue_redraw()


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		figgis_tap.emit()


func _process(_delta: float) -> void:
	if state == State.CARD and not card_visible():
		_refresh_state()
	queue_redraw()


func _draw() -> void:
	var now := UiKit.now_ms()
	var t := float(now) * 0.001
	var c := size * 0.5
	var k := UiKit.PRESS_SCALE if is_pressed else 1.0
	var bob := 0.0
	if state == State.PULSE and not UiKit.reduce_motion():
		k *= 1.0 + 0.06 * maxf(0.0, sin(t * TAU * 1.2))
		bob = -4.0 * maxf(0.0, sin(t * TAU * 1.2))
	draw_set_transform(c + Vector2(0, bob), 0.0, Vector2(k, k))
	var r := VISUAL * 0.5
	draw_circle(Vector2(0, 5), r, Color(UiKit.NAVY, 0.35))
	if state == State.GHOST:
		var g := 0.5 + 0.5 * sin(t * TAU * 0.8)
		draw_circle(Vector2.ZERO, r + 10.0 + 4.0 * g, Color(0.85, 0.92, 1.0, 0.35 + 0.25 * g))
	UiKit.draw_disc(self, Vector2.ZERO, r, Color("#5A4A7A") if not is_pressed else Color("#4A3C66"), Color("#3A3050"))
	var fm := Color(1, 1, 1, 0.75) if state == State.GHOST else Color.WHITE
	UiKit.draw_icon(self, _tex_face, Rect2(-r + 8.0, -r + 6.0, VISUAL - 16.0, VISUAL - 12.0), fm)
	draw_set_transform(Vector2.ZERO)
	if state == State.PULSE:
		_draw_psst(t)
	elif state == State.CARD:
		_draw_card(now)


func _draw_psst(t: float) -> void:
	var f := UiKit.display_font()
	var fs := UiKit.SIZE_MIN
	var w := f.get_string_size(_psst, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var a := clampf(0.6 + 0.4 * sin(t * TAU * 1.2), 0.0, 1.0)
	var rect := Rect2(HIT + 4.0, 18.0, w, 60.0) if not flip else Rect2(-4.0 - w, 18.0, w, 60.0)
	UiKit.draw_chunky_rect(self, rect, 26.0, UiKit.CREAM, UiKit.CREAM_SHADE, 5.0, 6.0)
	draw_colored_polygon(PSST_TAIL_FLIP if flip else PSST_TAIL, UiKit.CREAM)
	UiKit.draw_text_centered(self, f, rect.get_center() + Vector2(0, -2), _psst, fs, Color(UiKit.NAVY, a), 0)


func _draw_card(now: int) -> void:
	var n := _card_icons.size()
	if n == 0:
		return
	var ap := clampf(float(now - _card_from_ms) / 160.0, 0.0, 1.0)
	var out := clampf(float(_card_until_ms - now) / 200.0, 0.0, 1.0)
	var k := (0.7 + 0.3 * ap) * out
	var w := float(n) * CARD_ICON + float(n - 1) * 52.0 + 48.0
	var h := CARD_ICON + 44.0
	var origin := Vector2(-16.0, HIT + 16.0) if not flip else Vector2(HIT + 16.0 - w, HIT + 16.0)
	draw_set_transform(origin + Vector2(w * 0.5, 0), 0.0, Vector2(k, k))
	var rect := Rect2(-w * 0.5, 0.0, w, h)
	UiKit.draw_chunky_rect(self, rect, 22.0, UiKit.PAPER, UiKit.PAPER_SHADE, 6.0, 10.0)
	var x := rect.position.x + 24.0
	for i in n:
		UiKit.draw_icon(self, _card_icons[i], Rect2(x, 18.0, CARD_ICON, CARD_ICON))
		x += CARD_ICON
		if i < n - 1:
			UiKit.draw_icon(self, _tex_arrow, Rect2(x + 4.0, 18.0 + CARD_ICON * 0.5 - 22.0, 44.0, 44.0))
			x += 52.0
	draw_set_transform(Vector2.ZERO)
