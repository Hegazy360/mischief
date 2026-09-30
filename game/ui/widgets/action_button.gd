## ActionButton — the right-thumb context button (GDD §3.2, TECH §6.3).
##
## 240 px hit circle, 190 px visual, one verb as a 96 px icon:
##   RIG      item icon → target icon; HOLD: a 14 px ring fills (the model's ring_frac) from
##            12 o'clock, yellow → green, pulsing at 3 Hz over the last 20 %; completion pops
##            1.0 → 1.18 → 1.0 over 180 ms (+ rig_done haptic). Arrival pops 1.08×.
##   RIG_DIM  the missing item's silhouette in a grey thought-cloud; TAP = intent.
##   FREEZE   the statue (persistent default); HOLD.
##   POP_OUT  rim green / amber / red by danger; TAP.
##   GO       ▶ + pin (a pin is set while hidden); TAP; rim as POP_OUT.
## Rules:
##   * the verb is LATCHED at touch-down: nothing during the press changes what it does;
##   * a new verb is shown only after the current one was visible ≥ HYSTERESIS_MS, never while
##     pressed (or toggled on), with a FADE_MS cross-fade;
##   * sliding > SLIDE_CANCEL_PX off the button cancels (`action_up(verb, true)`);
##   * tap-to-rig (setting): RIG / FREEZE become toggles — a touch-down starts
##     (`action_down`), the next touch-down stops (`action_up(verb, false)`); a RIG toggle ends
##     by itself when the ring completes.
## Signals: action_down(verb), action_up(verb, cancelled), action_double_tap(verb) (a second
## tap of a TAP verb within DOUBLE_TAP_MS: pop out and run), ring_half(), ring_complete().
##
## R3D (REDESIGN_3D §2.4) — two visual states, switched with the same hysteresis and cross-fade:
##   QUIET  FREEZE while nothing threatens Hush: a navy 62 % disc, a white 84 px statue, no ring —
##          still pressable (FREEZE is persistent) but it does not shout;
##   LIVE   any verb that is the right move now: full colour, a 1.08× pop, 96 px icon, 14 px ring —
##          RIG (gold), RIG_DIM, POP OUT / GO ▶ (danger rim), and FREEZE when it matters: a stone-white
##          face with an amber rim (`set_freeze_danger(1)`: he is in her room, she is exposed), the rim
##          pulsing red-amber at 3 Hz while a "?" fills on her (`set_freeze_danger(2)`).
## `set_live(on)` (Hud: `Hud.is_live(model)`); RIG / RIG_DIM / POP_OUT / GO are always shown LIVE.
class_name ActionButton
extends TouchWidget

signal action_down(verb: int)
signal action_up(verb: int, cancelled: bool)
signal action_double_tap(verb: int)
signal ring_half()
signal ring_complete()
## A new verb became visible (tests / debug).
signal verb_shown(verb: int)

const HIT := 240.0
const VISUAL := 190.0
const ICON := 96.0
const RING_W := 14.0
const RING_R := 107.0
const HYSTERESIS_MS := 250
const FADE_MS := 120
const SLIDE_CANCEL_PX := 80.0
const POP_MS := 180
const COMPLETE_POP := 1.18
const ARRIVAL_POP := 1.08
const PULSE_HZ := 3.0
const PULSE_FROM := 0.8
const DOUBLE_TAP_MS := 280
const TAG_MS := 1600
const QUIET_ICON := 84.0
const QUIET_FILL := Color(0.106, 0.137, 0.251, 0.62)
const STONE := Color("#E4DFEC")
const STONE_SHADE := Color("#B3AAC4")

const V := HudModel.Verb
const RIM_COLORS: Array[Color] = [UiKit.GREEN, UiKit.AMBER, UiKit.RED]
const GO_TRI: PackedVector2Array = [Vector2(30, 6), Vector2(58, 26), Vector2(30, 46)]
const GO_TRI_LINE: PackedVector2Array = [Vector2(30, 6), Vector2(58, 26), Vector2(30, 46), Vector2(30, 6)]
const ARROW_PTS: PackedVector2Array = [Vector2(-6, -6), Vector2(10, 6), Vector2(-6, 16)]

## Tap-to-rig accessibility setting (holds become toggles).
var tap_to_rig: bool = false
## The verb currently on the button face.
var shown_verb: int = V.FREEZE
## The verb the press in progress (or the active toggle) acts as; −1 when idle.
var latched_verb: int = -1
## Ring progress 0..1 (RIG).
var ring_frac: float = 0.0
## POP_OUT / GO danger rim (HudModel.Rim).
var rim: int = HudModel.Rim.GREEN
## The face shown is LIVE (else QUIET — only ever FREEZE).
var shown_live: bool = false
## FREEZE danger (HudModel.FreezeDanger): the amber rim / the 3 Hz red-amber pulse.
var freeze_danger: int = 0

var _target_live: bool = false
var _prev_live: bool = false
var _tex_quiet: Texture2D = null

var _target_verb: int = V.FREEZE
var _shown_since_ms: int = -100000
var _prev_verb: int = -1
var _fade_from_ms: int = -100000
var _toggled: bool = false
var _cancelled: bool = false
var _last_tap_ms: int = -100000
var _last_tap_verb: int = -1
var _pop_ms: int = -100000
var _pop_peak: float = 1.0
var _tag_ms: int = -100000
var _item_path: String = ""
var _target_path: String = ""
var _item_tex: Texture2D = null
var _target_tex: Texture2D = null
var _tex_freeze: Texture2D = null
var _tex_pop: Texture2D = null
var _tex_pin: Texture2D = null
var _tex_hand: Texture2D = null
var _tex_cloud: Texture2D = null
var _tags: PackedStringArray = PackedStringArray()
var _tag_tap: String = ""
var _go_text: String = "GO"


func _init() -> void:
	super()
	hit_circle = true
	size = Vector2(HIT, HIT)
	custom_minimum_size = size


func _ready() -> void:
	_tex_freeze = UiIcons.get_icon(&"verb_freeze")
	_tex_quiet = UiIcons.get_icon(&"verb_freeze_quiet")
	_tex_pop = UiIcons.get_icon(&"verb_pop_out")
	_tex_pin = UiIcons.get_icon(&"pin")
	_tex_hand = UiIcons.get_icon(&"hand_rig")
	_tex_cloud = UiIcons.get_icon(&"badge_needs")
	_tags = PackedStringArray([UiStrings.t("hud.verb_rig"), UiStrings.t("hud.verb_rig_dim"),
		UiStrings.t("hud.verb_freeze"), UiStrings.t("hud.verb_pop_out"), UiStrings.t("hud.verb_go")])
	_tag_tap = UiStrings.t("hud.verb_rig_tap")
	_go_text = UiStrings.t("hud.verb_go")
	set_process(false)


# --- model input --------------------------------------------------------------------------

## Request verb `v` (HudModel.Verb). Shown at once, or when the hysteresis / press allows.
func set_verb(v: int) -> void:
	_target_verb = v
	_update_verb()


## QUIET / LIVE (REDESIGN §2.4); verbs other than FREEZE are always drawn LIVE.
func set_live(on: bool) -> void:
	_target_live = on
	_update_verb()


## Verb and QUIET / LIVE in one step (one hysteresis window for both — the Hud's call).
func set_face(v: int, live: bool) -> void:
	_target_verb = v
	_target_live = live
	_update_verb()


## FREEZE danger 0 none / 1 exposed (amber rim) / 2 a "?" filling (red-amber pulse).
func set_freeze_danger(d: int) -> void:
	if d == freeze_danger:
		return
	freeze_danger = d
	if d == 2:
		set_process(true)
	queue_redraw()


## True when verb `v` with the live flag `on` draws the LIVE face.
static func face_live(v: int, on: bool) -> bool:
	return v != V.FREEZE or on


## The verb waiting to be shown (== shown_verb when none is pending).
func pending_verb() -> int:
	return _target_verb


## RIG icons: carried item (id or path, "" = free prank) and target (id or path, "" = none).
func set_icons(item: String, target: String) -> void:
	if item == _item_path and target == _target_path:
		return
	_item_path = item
	_target_path = target
	_item_tex = UiIcons.item(item) if item != "" else null
	_target_tex = null
	if target != "":
		_target_tex = UiIcons.texture(target) if target.begins_with("res://") else UiIcons.activity(target)
	queue_redraw()


## Ring progress 0..1; fires ring_half / ring_complete on the crossing (RIG only).
func set_ring(frac: float) -> void:
	var f := clampf(frac, 0.0, 1.0)
	if is_equal_approx(f, ring_frac):
		return
	var old := ring_frac
	ring_frac = f
	var rigging := shown_verb == V.RIG or latched_verb == V.RIG
	if rigging and old < 0.5 and f >= 0.5 and f < 1.0:
		UiKit.haptic(&"ring_half")
		ring_half.emit()
	if rigging and old < 1.0 and f >= 1.0:
		UiKit.haptic(&"rig_done")
		_pop(COMPLETE_POP)
		ring_complete.emit()
		if _toggled and latched_verb == V.RIG:
			_toggled = false
			latched_verb = -1
			action_up.emit(V.RIG, false)
			_update_verb()
	if f >= PULSE_FROM and f < 1.0:
		set_process(true)
	queue_redraw()


## Danger rim for POP_OUT / GO (HudModel.Rim).
func set_rim(r: int) -> void:
	if r == rim:
		return
	rim = r
	queue_redraw()


## Switch tap-to-rig on/off (an active toggle is released first).
func set_tap_to_rig(on: bool) -> void:
	if on == tap_to_rig:
		return
	if _toggled:
		_toggled = false
		action_up.emit(latched_verb, true)
		latched_verb = -1
	tap_to_rig = on
	_update_verb()


## True while a tap-to-rig toggle is on.
func is_toggled() -> bool:
	return _toggled


## Re-evaluate a pending verb change (called from _process; public for tests).
func tick() -> void:
	_update_verb()


static func is_hold_verb(v: int) -> bool:
	return v == V.RIG or v == V.FREEZE


# --- touch --------------------------------------------------------------------------------

func _touch_down(_pos: Vector2) -> bool:
	_cancelled = false
	UiKit.haptic(&"tap")
	if tap_to_rig and _toggled:
		# the second tap of a toggle: stop
		var v := latched_verb
		_toggled = false
		latched_verb = -1
		_cancelled = true   # the lift of this touch does nothing
		action_up.emit(v, false)
		return true
	latched_verb = shown_verb
	if tap_to_rig and is_hold_verb(latched_verb):
		_toggled = true
		_cancelled = true
	action_down.emit(latched_verb)
	return true


func _touch_move(pos: Vector2) -> void:
	if _cancelled or latched_verb < 0:
		return
	if pos.distance_to(size * 0.5) > HIT * 0.5 + SLIDE_CANCEL_PX:
		_cancelled = true
		var v := latched_verb
		latched_verb = -1
		action_up.emit(v, true)
		queue_redraw()


func _touch_up(_pos: Vector2, _inside: bool) -> void:
	if _cancelled:
		_cancelled = false
		if not _toggled:
			latched_verb = -1
		_update_verb()
		return
	var v := latched_verb
	latched_verb = -1
	if v >= 0:
		action_up.emit(v, false)
		if not is_hold_verb(v):
			var now := UiKit.now_ms()
			if v == _last_tap_verb and now - _last_tap_ms <= DOUBLE_TAP_MS:
				_last_tap_ms = -100000
				action_double_tap.emit(v)
			else:
				_last_tap_ms = now
				_last_tap_verb = v
	_update_verb()


func _touch_cancel() -> void:
	if _cancelled or latched_verb < 0:
		_cancelled = false
		return
	if _toggled:
		return
	var v := latched_verb
	latched_verb = -1
	action_up.emit(v, true)
	_update_verb()


# --- verb switching -------------------------------------------------------------------------

func _update_verb() -> void:
	var tl := face_live(_target_verb, _target_live)
	if _target_verb == shown_verb and tl == shown_live:
		return
	if is_pressed or _toggled:
		return
	var now := UiKit.now_ms()
	if now - _shown_since_ms < HYSTERESIS_MS:
		set_process(true)
		return
	var verb_changed := _target_verb != shown_verb
	var went_live := tl and not shown_live
	_prev_verb = shown_verb
	_prev_live = shown_live
	shown_verb = _target_verb
	shown_live = tl
	_shown_since_ms = now
	_fade_from_ms = now
	if tl and (verb_changed or went_live):
		_tag_ms = now
	if went_live or (tl and verb_changed and shown_verb == V.RIG):
		_pop(ARRIVAL_POP)
	set_process(true)
	if verb_changed:
		verb_shown.emit(shown_verb)
	queue_redraw()


func _pop(peak: float) -> void:
	_pop_peak = peak
	_pop_ms = UiKit.now_ms()
	set_process(true)


func _process(_delta: float) -> void:
	_update_verb()
	var now := UiKit.now_ms()
	var busy := _target_verb != shown_verb
	busy = busy or now - _fade_from_ms < FADE_MS or now - _pop_ms < POP_MS or now - _tag_ms < TAG_MS
	busy = busy or (ring_frac >= PULSE_FROM and ring_frac < 1.0 and shown_verb == V.RIG)
	busy = busy or ((shown_verb == V.POP_OUT or shown_verb == V.GO) and rim == HudModel.Rim.RED)
	busy = busy or (shown_verb == V.FREEZE and shown_live and freeze_danger == 2)
	queue_redraw()
	if not busy:
		set_process(false)


# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var now := UiKit.now_ms()
	var c := size * 0.5
	var k := pop_scale(now)
	if is_pressed or _toggled:
		k *= UiKit.PRESS_SCALE
	draw_set_transform(c, 0.0, Vector2(k, k))
	# each face = one triangle array (shadow, disc, rim) + its icons (s2-fix G #8)
	var ft := float(now - _fade_from_ms) / float(FADE_MS)
	if ft >= 0.0 and ft < 1.0 and _prev_verb >= 0:
		_draw_face(_prev_verb, 1.0 - ft, true, _prev_live)
		_draw_face(shown_verb, ft, false, shown_live)
	else:
		_draw_face(shown_verb, 1.0, true, shown_live)
	draw_set_transform(c, 0.0, Vector2.ONE)
	if shown_verb == V.RIG:
		_draw_ring(now)
	if shown_live:
		_draw_tag(now)
	draw_set_transform(Vector2.ZERO)


func _draw_face(v: int, a: float, with_shadow: bool = false, live: bool = true) -> void:
	var r := VISUAL * 0.5
	var down := is_pressed or _toggled
	if v == V.FREEZE and not live:
		_draw_quiet(r, a, with_shadow, down)
		return
	var fill: Color
	var shade: Color
	match v:
		V.RIG:
			fill = UiKit.GOLD
			shade = UiKit.GOLD_SHADE
		V.RIG_DIM:
			fill = Color("#A7A3B8")
			shade = Color("#7C7894")
		V.FREEZE:
			# LIVE FREEZE: the stone-white face (she turns to marble)
			fill = STONE if not down else Color("#D6E6F5")
			shade = STONE_SHADE if not down else Color("#A3B8D0")
		V.POP_OUT:
			fill = UiKit.CREAM
			shade = UiKit.CREAM_SHADE
		_:
			fill = UiKit.CHERRY
			shade = UiKit.CHERRY_SHADE
	if down:
		fill = UiKit.pressed(fill)
		shade = UiKit.pressed(shade)
	var m := Color(1, 1, 1, a)
	UiShapes.begin()
	if with_shadow:
		UiShapes.circle(Vector2(0, 8), VISUAL * 0.5, Color(UiKit.NAVY, 0.35))
	UiShapes.circle(Vector2.ZERO, r, Color(UiKit.NAVY, a))
	UiShapes.circle(Vector2.ZERO, r - UiKit.BUTTON_OUTLINE, Color(shade, a))
	UiShapes.circle(Vector2(0, -r * 0.08), (r - UiKit.BUTTON_OUTLINE) * 0.9, Color(fill, a))
	if v == V.POP_OUT or not (v == V.RIG or v == V.RIG_DIM or v == V.FREEZE):
		_draw_rim(r, a)
	elif v == V.FREEZE and freeze_danger > 0:
		_draw_freeze_rim(r, a)
	UiShapes.flush(self)
	match v:
		V.RIG:
			var main: Texture2D = _item_tex if _item_tex != null else _tex_hand
			if _target_tex != null:
				UiKit.draw_icon(self, main, Rect2(-62, -64, ICON, ICON), m)
				UiShapes.begin()
				UiShapes.circle(Vector2(38, 34), 38, Color(UiKit.NAVY, a))
				UiShapes.circle(Vector2(38, 34), 33, Color(UiKit.CREAM, a))
				UiShapes.flush(self)
				UiKit.draw_icon(self, _target_tex, Rect2(12, 8, 52, 52), m)
				_draw_arrow(a)
			else:
				UiKit.draw_icon(self, main, Rect2(-ICON * 0.5, -ICON * 0.5 - 4, ICON, ICON), m)
		V.RIG_DIM:
			UiKit.draw_icon(self, _tex_cloud, Rect2(-58, -62, 116, 116), m)
			if _item_tex != null:
				UiKit.draw_icon(self, _item_tex, Rect2(-34, -44, 64, 64), Color(0.16, 0.14, 0.26, 0.6 * a))
		V.FREEZE:
			UiKit.draw_icon(self, _tex_freeze, Rect2(-ICON * 0.5 - 2, -ICON * 0.5 - 8, ICON + 4, ICON + 4), m)
		V.POP_OUT:
			UiKit.draw_icon(self, _tex_pop, Rect2(-ICON * 0.5, -ICON * 0.5 - 4, ICON, ICON), m)
		_:
			UiKit.draw_icon(self, _tex_pin, Rect2(-26, -76, 52, 52), m)
			var f := UiKit.display_font()
			UiKit.draw_text_centered(self, f, Vector2(-22, 26), _go_text, 56, Color(UiKit.CREAM, a), 10,
				Color(UiKit.NAVY, a))
			UiShapes.begin()
			UiShapes.poly(GO_TRI, Color(UiKit.CREAM, a))
			for i in GO_TRI_LINE.size() - 1:
				UiShapes.line(GO_TRI_LINE[i], GO_TRI_LINE[i + 1], Color(UiKit.NAVY, a), 5.0)
			UiShapes.flush(self)


## QUIET: a navy 62 % disc with the white statue — pressable, but it does not shout.
func _draw_quiet(r: float, a: float, with_shadow: bool, down: bool) -> void:
	UiShapes.begin()
	if with_shadow:
		UiShapes.circle(Vector2(0, 4), r, Color(0, 0, 0, 0.18 * a))
	UiShapes.circle(Vector2.ZERO, r, Color(QUIET_FILL, QUIET_FILL.a * a * (1.3 if down else 1.0)))
	UiShapes.flush(self)
	var e := QUIET_ICON
	UiKit.draw_icon(self, _tex_quiet if _tex_quiet != null else _tex_freeze, Rect2(-e * 0.5, -e * 0.5 - 4.0, e, e),
		Color(1, 1, 1, a))


## FREEZE LIVE's rim: amber (exposed), pulsing red ↔ amber at 3 Hz while a "?" fills.
func _draw_freeze_rim(r: float, a: float) -> void:
	var col := UiKit.AMBER
	var w := 14.0
	if freeze_danger >= 2:
		if UiKit.reduce_flash():
			col = UiKit.RED
		else:
			var ph := 0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * PULSE_HZ)
			col = UiKit.AMBER.lerp(UiKit.RED, ph)
			w += 4.0 * ph
	UiShapes.arc(Vector2.ZERO, r - UiKit.BUTTON_OUTLINE - w * 0.5 + 1.0, 0.0, TAU, w, Color(col, a), 64)


func _draw_rim(r: float, a: float) -> void:
	var col: Color = RIM_COLORS[clampi(rim, 0, 2)]
	var w := 14.0
	if rim == HudModel.Rim.RED and not UiKit.reduce_flash():
		w += 4.0 * (0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * 2.0))
	UiShapes.arc(Vector2.ZERO, r - UiKit.BUTTON_OUTLINE - w * 0.5 + 1.0, 0.0, TAU, w, Color(col, a), 64)


func _draw_arrow(a: float) -> void:
	UiShapes.begin()
	for w in [9.0, 4.0]:
		var col := Color(UiKit.NAVY if w > 5.0 else UiKit.CREAM, a)
		for i in ARROW_PTS.size() - 1:
			UiShapes.line(ARROW_PTS[i], ARROW_PTS[i + 1], col, w)
			UiShapes.circle(ARROW_PTS[i + 1], w * 0.5, col)
	UiShapes.flush(self)


func _draw_ring(now: int) -> void:
	UiShapes.begin()
	UiShapes.arc(Vector2.ZERO, RING_R, 0.0, TAU, RING_W + 8.0, Color(UiKit.NAVY, 0.55), 72)
	if ring_frac > 0.0:
		var col := ring_color(ring_frac)
		var s := ring_pulse(ring_frac, now)
		UiKit.draw_ring(self, Vector2.ZERO, RING_R, ring_frac, RING_W + 5.0 * s, col.lightened(0.25 * s))
	UiShapes.flush(self)


## The RIG ring's colour at `frac`: yellow → green (GDD §3.2).
static func ring_color(frac: float) -> Color:
	return UiKit.YELLOW.lerp(UiKit.GREEN, clampf(frac, 0.0, 1.0))


## The ring's pulse 0..1 at `now_ms`: a PULSE_HZ (3 Hz) throb over the last 20 % only.
static func ring_pulse(frac: float, now_ms: int) -> float:
	if frac < PULSE_FROM or frac >= 1.0:
		return 0.0
	return 0.5 + 0.5 * sin(float(now_ms) * 0.001 * TAU * PULSE_HZ)


## The face's scale pop at `now_ms` (1.0 = none): 1.08× on arriving at a rig point, 1.0 → 1.18 →
## 1.0 over POP_MS when the ring completes (tests).
func pop_scale(now_ms: int) -> float:
	var pt := float(now_ms - _pop_ms) / float(POP_MS)
	if pt < 0.0 or pt >= 1.0 or UiKit.reduce_motion():
		return 1.0
	return 1.0 + (_pop_peak - 1.0) * sin(pt * PI)


func _draw_tag(now: int) -> void:
	var t := now - _tag_ms
	if t < 0 or t >= TAG_MS:
		return
	var a := clampf(float(TAG_MS - t) / 300.0, 0.0, 1.0) * clampf(float(t) / 90.0, 0.0, 1.0)
	var label := _tag_tap if (tap_to_rig and is_hold_verb(shown_verb)) else _tags[clampi(shown_verb, 0, _tags.size() - 1)]
	var f := UiKit.display_font()
	var fs := UiKit.SIZE_MIN
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var rect := Rect2(-w * 0.5, -HIT * 0.5 - 62.0, w, 56.0)
	UiKit.draw_chunky_rect(self, rect, 28.0, Color(UiKit.NAVY, a * 0.92), Color(UiKit.NAVY, a * 0.92), 0.0, 0.0)
	UiKit.draw_text_centered(self, f, rect.get_center(), label, fs, Color(UiKit.CREAM, a), 0)
