## FiggisChip — Old Figgis, the prompter, in his top-left chip beside Pause (GDD §3.8, §6.4):
## 144 hit / 128 visual at (S+192, T+24). States:
##   idle   the bust in his prompt box (f_idle);
##   pulse  ladder step 1 (40 s without progress): the chip bobs and a "psst!" bubble pops out
##          (f_psst);
##   card   ladder step 2 (after a tap): he holds up his card (f_point_card, the cue icons drawn
##          inside the card prop's `icon_rect`) and a readable cue card of 2–3 icons with arrows
##          opens below the chip for CARD_SEC (`show_card(icons)`);
##   ghost  ladder step 3 armed: a pale ghost glow (the next tap = "show me").
## One-shot moods on top (`react("shh" | "proud", seconds)`), e.g. f_shh while Hush hides, f_proud
## when a hinted line lands. Tap → `figgis_tap()`. The card and bubble are never targets.
##
## Figgis himself — the fallback chain (art-hush request, s2-ui §4.2.3):
##   Level.CLIPS  a RigPlayer on rig `figgis` playing `figgis/f_idle`, `f_psst`, `f_point_card`,
##                `f_shh`, `f_proud` (data/anim/figgis/, s2-anim-hush) — a mood without its clip uses
##                its pose;
##   Level.POSES  the same RigPlayer holding the rig's poses (f_rest, f_psst, f_point, f_shh,
##                f_proud) with their face presets (blinks and breathing still run);
##   Level.SVG    no rig data: art-hush's single `figgis_chip.svg` bust, else the UI fallback face.
class_name FiggisChip
extends TouchWidget

signal figgis_tap()

const HIT := 144.0
const VISUAL := 128.0
const CARD_SEC := 4.0
const CARD_ICON := 88.0
const ART_HUSH_PATH := "res://art/chars/figgis/figgis_chip.svg"
const RIG_ID := "figgis"
const CARD_PROP := "card"
const CARD_SOCKET := "body:card"
const REACT_SEC := 1.6
const PSST_TAIL: PackedVector2Array = [Vector2(HIT + 10.0, 52.0), Vector2(HIT - 10.0, 66.0), Vector2(HIT + 14.0, 64.0)]
const PSST_TAIL_FLIP: PackedVector2Array = [Vector2(-10.0, 52.0), Vector2(10.0, 66.0), Vector2(-14.0, 64.0)]
const MOOD_CLIPS := {"idle": "figgis/f_idle", "psst": "figgis/f_psst", "point": "figgis/f_point_card",
	"shh": "figgis/f_shh", "proud": "figgis/f_proud"}
const MOOD_POSES := {"idle": "f_rest", "psst": "f_psst", "point": "f_point", "shh": "f_shh", "proud": "f_proud"}

enum State { IDLE, PULSE, CARD, GHOST }
enum Level { SVG, POSES, CLIPS }

var state: int = State.IDLE
## The chip sits in the top-RIGHT corner (left-handed): the "psst" bubble and the cue card open
## toward the screen centre (leftward). Set by the Hud.
var flip: bool = false
var pulse_on: bool = false
var ghost_on: bool = false
## Which Figgis is drawn (Level); decided in _ready.
var level: int = Level.SVG
## The mood on screen ("idle", "psst", "point", "shh", "proud").
var mood: String = ""
## How the current mood is shown: "clip:<id>", "pose:<name>" or "svg" (tests / debug).
var mood_source: String = ""
## The Figgis RigPlayer (null at Level.SVG).
var rig: RigPlayer = null
## Test hook: set before _ready to force a rig id ("" = no rig → Level.SVG).
var rig_id: String = RIG_ID

var _card_keys := PackedStringArray()
var _card_icons: Array[Texture2D] = []
var _card_until_ms: int = -100000
var _card_from_ms: int = -100000
var _react_mood: String = ""
var _react_until_ms: int = -100000
var _tex_face: Texture2D = null
var _tex_arrow: Texture2D = null
var _psst: String = "psst!"
var _ink: _CardInk = null
var _icon_rect := Rect2(16, 13, 48, 32)
var _card_pivot := Vector2(40, 50)


func _init() -> void:
	super()
	size = Vector2(HIT, HIT)
	custom_minimum_size = size


func _ready() -> void:
	_tex_arrow = UiIcons.get_icon(&"arrow")
	_psst = UiStrings.t("ftue.psst") if UiStrings.has("ftue.psst") else UiStrings.t("hud.psst")
	_setup_rig()
	if level == Level.SVG:
		_tex_face = UiIcons.texture(ART_HUSH_PATH)
		if _tex_face == null:
			_tex_face = UiIcons.get_icon(&"figgis_chip")
	_refresh_state()


func _setup_rig() -> void:
	level = Level.SVG
	if rig_id == "" or RigDef.for_id(rig_id) == null:
		return
	rig = RigPlayer.new()
	rig.name = "FiggisRig"
	rig.manual = true
	rig.self_hitstop = false
	rig.setup(rig_id)
	if rig.rig == null or rig.poses == null:
		rig.free()
		rig = null
		return
	rig.position = Vector2(HIT * 0.5, HIT * 0.5 + VISUAL * 0.5)
	add_child(rig)
	var pi := rig.rig.props.size()
	for i in pi:
		var pr: RigDef.RigProp = rig.rig.props[i]
		if pr.id == CARD_PROP:
			_card_pivot = pr.pivot
	var ir := _card_icon_rect_from_rig()
	if ir.size != Vector2.ZERO:
		_icon_rect = ir
	_ink = _CardInk.new()
	_ink.chip = self
	add_child(_ink)
	level = Level.CLIPS if ClipLib.get_clip(String(MOOD_CLIPS["idle"])) != null else Level.POSES


## rig.json `props.card.icon_rect` (card canvas px), read from the file (RigDef keeps only what
## the player needs).
func _card_icon_rect_from_rig() -> Rect2:
	var p := "%s/rigs/%s/rig.json" % [RigDef.data_root, rig_id]
	if not FileAccess.file_exists(p):
		return Rect2()
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
		return Rect2()
	var props: Variant = (j.data as Dictionary).get("props", {})
	if not (props is Dictionary) or not ((props as Dictionary).get(CARD_PROP) is Dictionary):
		return Rect2()
	var r: Variant = ((props as Dictionary)[CARD_PROP] as Dictionary).get("icon_rect")
	if r is Array and (r as Array).size() >= 4:
		return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return Rect2()


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
## joined by arrows, for `seconds`. Figgis holds up his card with the same icons.
func show_card(icons: PackedStringArray, seconds: float = CARD_SEC) -> void:
	_card_icons.clear()
	_card_keys = icons.duplicate()
	for k in icons:
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


## A one-shot mood ("shh", "proud", "psst", "point", "idle") for `seconds`, then back to the
## state's mood.
func react(p_mood: String, seconds: float = REACT_SEC) -> void:
	if not MOOD_POSES.has(p_mood):
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
	set_process(state != State.IDLE or rig != null or _react_mood != "")
	queue_redraw()


func _set_mood(m: String) -> void:
	if m == mood and mood_source != "":
		return
	mood = m
	if rig == null:
		mood_source = "svg"
		return
	var clip := String(MOOD_CLIPS.get(m, ""))
	if level == Level.CLIPS and clip != "" and ClipLib.get_clip(clip) != null:
		rig.play(clip, {"blend_in": 4})
		mood_source = "clip:" + clip
		return
	var pose := String(MOOD_POSES.get(m, "f_rest"))
	if not rig.poses.has_pose(pose):
		pose = "f_rest"
	if rig.poses.has_pose(pose):
		rig.set_static_pose(rig.poses.pose(pose))
		var fp := rig.poses.face_of(pose)
		if fp != "":
			rig.set_face(fp)
		mood_source = "pose:" + pose
	else:
		mood_source = "svg"


## True when the card prop is up in his hands (point / proud).
func card_prop_up() -> bool:
	return rig != null and (mood == "point" or mood == "proud")


func _touch_up(_pos: Vector2, inside: bool) -> void:
	if inside:
		UiKit.haptic(&"ui")
		figgis_tap.emit()


func _process(delta: float) -> void:
	if state == State.CARD and not card_visible():
		_refresh_state()
	elif _react_mood != "" and UiKit.now_ms() >= _react_until_ms:
		_refresh_state()
	if rig != null:
		var now := UiKit.now_ms()
		var k := UiKit.PRESS_SCALE if is_pressed else 1.0
		var bob := 0.0
		if state == State.PULSE and not UiKit.reduce_motion():
			var t := float(now) * 0.001
			k *= 1.0 + 0.06 * maxf(0.0, sin(t * TAU * 1.2))
			bob = -4.0 * maxf(0.0, sin(t * TAU * 1.2))
		rig.scale = Vector2(k, k)
		rig.position = Vector2(HIT * 0.5, HIT * 0.5 + VISUAL * 0.5 * k + bob)
		rig.modulate = Color(1, 1, 1, 0.78) if state == State.GHOST else Color.WHITE
		rig.advance(delta)
		if _ink != null:
			_ink.visible = card_prop_up() and not _card_icons.is_empty()
			if _ink.visible:
				_ink.queue_redraw()
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
	if state == State.GHOST:
		var g := 0.5 + 0.5 * sin(t * TAU * 0.8)
		draw_circle(Vector2.ZERO, r + 10.0 + 4.0 * g, Color(0.85, 0.92, 1.0, 0.35 + 0.25 * g))
	if rig != null:
		# the prompt box is the rig's own art: just a drop shadow under it
		UiKit.draw_chunky_rect(self, Rect2(-r + 2.0, -r + 8.0, VISUAL - 4.0, VISUAL - 2.0), 22.0,
			Color(UiKit.NAVY, 0.4), Color(UiKit.NAVY, 0.4), 0.0, 0.0)
	else:
		draw_circle(Vector2(0, 5), r, Color(UiKit.NAVY, 0.35))
		UiKit.draw_disc(self, Vector2.ZERO, r, Color("#5A4A7A") if not is_pressed else Color("#4A3C66"), Color("#3A3050"))
		var fm := Color(1, 1, 1, 0.75) if state == State.GHOST else Color.WHITE
		UiKit.draw_icon(self, _tex_face, Rect2(-r + 8.0, -r + 6.0, VISUAL - 16.0, VISUAL - 12.0), fm)
	draw_set_transform(Vector2.ZERO)
	if state == State.PULSE or (state != State.CARD and mood == "psst"):
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


## Draws the cue icons on the card prop in Figgis's hands (above the rig).
func _draw_card_ink(ci: Node2D) -> void:
	if rig == null or _card_icons.is_empty():
		return
	var xf := get_global_transform().affine_inverse() * rig.socket_global_transform(CARD_SOCKET)
	ci.draw_set_transform_matrix(xf)
	var r := Rect2(_icon_rect.position - _card_pivot, _icon_rect.size)
	# first and last icon (item → target) side by side inside the card's blank
	var a: Texture2D = _card_icons[0]
	var b: Texture2D = _card_icons[_card_icons.size() - 1] if _card_icons.size() > 1 else null
	if b == null:
		UiKit.draw_icon(ci, a, r)
	else:
		var hw := r.size.x * 0.5
		UiKit.draw_icon(ci, a, Rect2(r.position, Vector2(hw, r.size.y)))
		UiKit.draw_icon(ci, b, Rect2(r.position + Vector2(hw, 0), Vector2(hw, r.size.y)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The card-prop overlay (drawn after the rig so the icons sit on the card).
class _CardInk:
	extends Node2D

	var chip: FiggisChip = null

	func _draw() -> void:
		if chip != null:
			chip._draw_card_ink(self)
