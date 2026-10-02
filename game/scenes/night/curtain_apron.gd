## CurtainApron — what happens in front of the fallen curtain during the curtain call (GDD §6.2):
## Hush on the apron bowing under a rain of roses, the Prologue's title card slamming down (0.3 s drop,
## a squash on landing, the bulbs chasing round its frame), and during the Gag Reel Bellows' bit: he wanders on in
## his residue, double-takes at the audience, slow-burns, and the stage pelmet drops on his head (bonk).
## The actors are CurtainBows3D's 3D rigs (`bows`, composited under this control: `hush/act_bow`,
## `bellows/cc_wander_on`, `st_double_take`, `beat_slow_burn`, `st_bonk`); the roses and the title stay 2D, on top.
## Roses are a fixed pool drawn in one `_draw()` (no allocation per frame).
##
## **Staging (r3d QA2 Q2-G7 — the bonk was small beside the buttons, the menu covered it):**
##   * Hush bows at HUSH_MARK_X (left of centre) and the title card lands at TITLE_X (right of centre), so the card
##     never covers her during its hold;
##   * Bellows' bit runs centre-left (BIT_MARK_X), on CurtainBows3D.BIT_Z (≈ 46 % of the height, his face reads),
##     clear of the Gag Reel inset (right) and the buttons (bottom corners), his head under the results' text;
##   * the pelmet is drawn on `top` — a control CurtainCall keeps ABOVE the ResultsScreen — so the results' navy wash
##     never mutes it: it lurches into view at the top (6 f), WOBBLES on its ropes for BIT_WOBBLE_S (the set-up: one
##     rope slips, dust sifts — he is still fuming at the audience, he never looks up), the ropes snap and it DROPS in
##     BIT_DROP_F frames onto his head — CONTACT (r3d polish): its solid fabric edge lands ON the top of his bouffant
##     (CurtainBows3D.wig_top_screen: the wig's crown from the `bouffant` bone / a variant's bounds, squashed — never a
##     fixed height), the wig squashes flat under it and springs back (`wig_squash_at`), he is squashed into his knees,
##     the pelmet squashes and rocks on the wig, whack lines + a small dust puff burst out of the old fabric,
##     then his dazed face holds to the camera (`st_bonk`, its gaze window; body cheat 70°) with stars circling for
##     ≥ BIT_HOLD_S before the reel step may end — no cut, nothing else moves on the stage; then the topper: the
##     stars go and he gathers his dignity, the pelmet still on his head like a crown (BIT_TOPPER_CLIP: he
##     straightens and tugs his cravat), then glares at the audience under it (BIT_END_CLIP) while the call waits.
## `bit_plan(dur)` is the pure schedule (seconds into the reel step) the tests check.
class_name CurtainApron
extends Control

const ROSES := 28
const TITLE_ART := "res://art/house/stage/title_card.svg"
const BULBS_A := "res://art/house/stage/title_card_bulbs_a.svg"
const BULBS_B := "res://art/house/stage/title_card_bulbs_b.svg"
const VALANCE_ART := "res://art/house/stage/curtain_valance.svg"
const TITLE_SIZE := Vector2(1120, 460)
const TITLE_DROP_S := 0.3
const BULBS := 22
## Hush's walk-in (screen x fractions) and the title card's centre: she bows left of centre, the card lands right of
## it (the card was centred over her for its 1.2 s hold — r3d QA2 known edge).
const HUSH_FROM_X := 0.12
const HUSH_MARK_X := 0.30
const TITLE_X := 0.60
## Bellows' bit (Q2-G7): from the left wing to his mark, centre-left (x 0.28 = 336 px at 1200 wide).
const BIT_WING_X := -0.10
const BIT_MARK_X := 0.28
const BIT_TAKE_S := 0.35
const BIT_WOBBLE_S := 0.6
const BIT_DROP_F := 4
const BIT_HOLD_S := 1.0
## The topper after his dazed hold: he gathers his dignity with the pelmet still on his head like a crown — the
## cravat tug, the look round, the "ahem" to the audience, the cravat pings (`beat_dignity_fail`, face to camera).
const BIT_TOPPER_S := 1.25
const BIT_TOPPER_CLIP := "bellows/beat_dignity_fail"
## ...for its straighten-and-tug (30 f: its look-round spreads his arms like a T, which read wrong at strip size), then
## he glares at the audience, the pelmet still on (`beat_slow_burn`, looping: the end picture while the call waits).
const BIT_TOPPER_LEN_S := 0.5
const BIT_END_CLIP := "bellows/beat_slow_burn"
## The pelmet (logical px at the 1080 base): size, the bottom edge while it hangs at the top, its lurch into view
## (frames). The valance art (curtain_valance.svg) is solid fabric down to PELMET_FABRIC_K of its height; below hang
## the scalloped fringe and the tassels (to ≈ 0.86) and the last 13 % is empty — so the CONTACT line is the fabric's
## edge, not the rect's bottom (QA3: resting the rect's bottom 30 px under the head top left the fabric 28 px above
## the wig, "hovering"). Once it lands the fabric edge sits PELMET_PRESS px into the (squashed) top of his wig.
const PELMET_SIZE := Vector2(500, 150)
const PELMET_HANG_Y := 150.0
const PELMET_FABRIC_K := 0.62
const PELMET_PRESS := 14.0
const PELMET_LURCH_F := 6
const ORBIT_STARS := 4
## His wig under the pelmet: flattened on contact, springs back, then rests a little squashed while it is on.
const WIG_HIT := 0.6
const WIG_REST := 0.88
## The dust shaken out of the pelmet on contact: puffs, how long they live (frames).
const DUST_PUFFS := 10
const DUST_F := 30.0
## Per puff of a clump: its angle (deg above the horizontal, outwards), how far it billows, its final radius.
const DUST_ANG := [-14.0, -38.0, -62.0, -24.0, -50.0]
const DUST_DIST := [74.0, 88.0, 58.0, 112.0, 96.0]
const DUST_R := [22.0, 28.0, 18.0, 15.0, 24.0]

## The 3D bows (CurtainBows3D under this control); set before `_ready`.
var bows: CurtainBows3D = null
## The pelmet's control, drawn above the ResultsScreen (CurtainCall adds it to the layer and keeps it on top).
var top: Control = null
## 0..1 progress of the reel step (CurtainCall drives it; kept for callers — the bit runs on `bit_t`).
var bellows_t: float = 0.0
var hush_on: bool = false
var title_on: bool = false
## Seconds since Bellows' bit started (the reel step) and its schedule (`bit_plan`).
var bit_t: float = 0.0
var bit: Dictionary = {}

var _rose_tex: Texture2D = null
var _title_tex: Texture2D = null
var _bulbs: Array[Texture2D] = []
var _valance_tex: Texture2D = null
var _rp := PackedVector2Array()      # rose positions
var _rv := PackedVector2Array()      # velocities
var _rr := PackedFloat32Array()      # rotation
var _rs := PackedFloat32Array()      # spin
var _roses_live: bool = false
var _t: float = 0.0
var _hush_t: float = 0.0
var _hush_len: float = 1.6
var _title_t: float = 0.0
var _bellows_on: bool = false
## Seconds since the pelmet hit his head (−1 before).
var _bonk_t: float = -1.0
var _frame: float = 0.0
var _star := PackedVector2Array()


func _init() -> void:
	name = "CurtainApron"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rp.resize(ROSES)
	_rv.resize(ROSES)
	_rr.resize(ROSES)
	_rs.resize(ROSES)
	_star.resize(10)
	top = _Top.new()
	(top as _Top).apron = self


## The pelmet's control is made here; when nobody parented it (tests, an apron that never staged) it goes with us.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and top != null and is_instance_valid(top) and top.get_parent() == null:
		top.free()


func _ready() -> void:
	_rose_tex = UiIcons.get_icon(&"rose")
	if ResourceLoader.exists(VALANCE_ART):
		_valance_tex = load(VALANCE_ART) as Texture2D


func _vs() -> Vector2:
	return size if size.x > 0.0 else Vector2(1920, 1080)


## Bellows' bit, seconds into a reel step of `dur` s (pure): `walk` (he reaches his mark), `take` (the double take
## ends), `wobble` (the pelmet lurches into view and wobbles), `drop` (the ropes snap), `hit` (it lands on his head:
## the accent, BIT_DROP_F frames after `drop`) and `end` (his face hold is done: ≥ BIT_HOLD_S after the hit). The
## walk-on and the slow burn stretch to fill the step; the set-up, the drop and the hold do not.
static func bit_plan(dur: float) -> Dictionary:
	var drop_s := float(BIT_DROP_F) / 60.0
	var avail := maxf(0.0, dur - BIT_HOLD_S - BIT_WOBBLE_S - drop_s)
	var walk := clampf(avail * 0.48, 0.9, 2.2)
	var burn := clampf(avail - walk - BIT_TAKE_S, 0.5, 2.0)
	var wob := walk + BIT_TAKE_S + burn
	var hit := wob + BIT_WOBBLE_S + drop_s
	return {"walk": walk, "take": walk + BIT_TAKE_S, "wobble": wob, "drop": wob + BIT_WOBBLE_S, "hit": hit,
		"end": hit + BIT_HOLD_S}


## Hush steps out on the apron and bows for `sec` (false = she leaves).
func show_hush(on: bool, sec: float) -> void:
	hush_on = on
	_hush_t = 0.0
	_hush_len = maxf(0.2, sec)
	if bows != null and not on:
		bows.hide_hush()


## Roses rain from the flies onto the apron, round where Hush bows.
func rain_roses() -> void:
	var vs := _vs()
	var seed_v := 7
	for i in ROSES:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var fx := float(seed_v % 1000) / 1000.0
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var fy := float(seed_v % 1000) / 1000.0
		_rp[i] = Vector2(vs.x * (HUSH_MARK_X - 0.22 + 0.5 * fx), -80.0 - 700.0 * fy)
		_rv[i] = Vector2((fx - 0.5) * 120.0, 520.0 + 380.0 * fy)
		_rr[i] = fx * TAU
		_rs[i] = (fy - 0.5) * 8.0
	_roses_live = true


## The Prologue title card slams down.
func slam_title() -> void:
	_load_title()
	title_on = true
	_title_t = 0.0


func show_title(on: bool) -> void:
	if on:
		_load_title()
	title_on = on


## The title card and its bulb layers, loaded the first time the card shows: only the Prologue's call
## slams it (NightWarm rasterises them under that Night's curtain, so this is a cache hit there), and
## every other curtain call no longer holds 3 × 4.5 MB of art it never draws (s2-fix G #7).
func _load_title() -> void:
	if _title_tex != null or not ResourceLoader.exists(TITLE_ART):
		return
	_title_tex = ViewKit.tex(TITLE_ART)
	if _title_tex == null:
		_title_tex = load(TITLE_ART) as Texture2D
	_bulbs.clear()
	for b in [BULBS_A, BULBS_B]:
		if ResourceLoader.exists(b):
			var t := ViewKit.tex(b)
			if t != null:
				_bulbs.append(t)


## Bellows' bit starts (the reel step, `dur` s long); `residues` = the looks he ended the Night in.
func start_bellows(residues: Variant, dur: float = 5.0) -> void:
	_bellows_on = true
	bellows_t = 0.0
	bit_t = 0.0
	bit = bit_plan(dur)
	_bonk_t = -1.0
	if bows != null:
		bows.set_wig_squash(1.0)
	if bows != null and residues is PackedStringArray:
		bows.set_residues(residues)


## The pelmet drops on his head now (a tap / the end of the reel step before the bit got there): no wobble, the
## ropes snap at once and it lands BIT_DROP_F frames later.
func bonk() -> void:
	if not _bellows_on or _bonk_t >= 0.0 or bit.is_empty():
		return
	if bit_t < float(bit["drop"]):
		var drop_s := float(BIT_DROP_F) / 60.0
		bit["wobble"] = bit_t
		bit["drop"] = bit_t
		bit["hit"] = bit_t + drop_s
		bit["end"] = bit_t + drop_s + BIT_HOLD_S


## True once his face hold after the bonk is done (or no bit runs): the reel step may end.
func bit_done() -> bool:
	return not _bellows_on or (_bonk_t >= BIT_HOLD_S)


## True from the hit on (the pelmet is on his head).
func bonked() -> bool:
	return _bonk_t >= 0.0


## Clip id when its 3D sidecar exists, else "" (the current clip carries on).
static func clip_or_empty(id: String) -> String:
	return id if ClipMap.clip_exists3d(id) else ""


## Per frame (CurtainCall._process).
func advance(dt: float) -> void:
	_t += dt
	_frame += dt * 60.0
	var vs := _vs()
	if hush_on and bows != null:
		_hush_t += dt
		var k3 := clampf(_hush_t / _hush_len, 0.0, 1.0)
		var walking := k3 < 0.3
		bows.pose_hush(lerpf(HUSH_FROM_X, HUSH_MARK_X, clampf(k3 / 0.3, 0.0, 1.0)), "hush/loco_walk" if walking else "hush/act_bow",
			1, 20.0 if walking else 85.0)
	if _bellows_on:
		var was := bit_t
		bit_t += dt
		if not bit.is_empty() and was < float(bit["wobble"]) and bit_t >= float(bit["wobble"]) and _bonk_t < 0.0:
			_sfx("bow_creak")
		if _bonk_t < 0.0 and not bit.is_empty() and bit_t >= float(bit["hit"]):
			_on_hit()
		elif _bonk_t >= 0.0:
			_bonk_t += dt
		if bows != null:
			_advance_bellows_3d()
	if _roses_live:
		var any := false
		var floor_y := vs.y - 30.0
		for i in ROSES:
			var p := _rp[i]
			if p.y < floor_y:
				var v := _rv[i]
				p += v * dt
				_rr[i] += _rs[i] * dt
				_rp[i] = p
				any = true
		_roses_live = any
	if title_on:
		_title_t += dt
	queue_redraw()
	if top != null:
		top.queue_redraw()


## The accent: the pelmet lands on his head.
func _on_hit() -> void:
	_bonk_t = 0.0
	_sfx("bonk")
	UiKit.haptic(&"stomp")


func _sfx(id: String) -> void:
	var au := ViewKit.autoload("Audio")
	if au != null and au.has_method("play_sfx"):
		au.call("play_sfx", id)


## His squash from the hit (1 = none): driven into his knees on contact, one overshoot, settled by 18 f.
static func squash_at(bonk_f: float) -> float:
	if bonk_f < 0.0:
		return 1.0
	if bonk_f < 4.0:
		return 0.82
	if bonk_f < 10.0:
		return lerpf(0.82, 1.05, (bonk_f - 4.0) / 6.0)
	if bonk_f < 18.0:
		return lerpf(1.05, 1.0, (bonk_f - 10.0) / 8.0)
	return 1.0


## His wig's squash from the hit (1 = none): flattened under the pelmet on contact, springs back up (lifting it),
## then settles a little squashed under its weight (WIG_REST) while the pelmet stays on.
static func wig_squash_at(bonk_f: float) -> float:
	if bonk_f < 0.0:
		return 1.0
	if bonk_f < 3.0:
		return WIG_HIT
	if bonk_f < 9.0:
		var k := (bonk_f - 3.0) / 6.0
		return lerpf(WIG_HIT, 0.97, 1.0 - (1.0 - k) * (1.0 - k))
	if bonk_f < 16.0:
		return lerpf(0.97, WIG_REST, (bonk_f - 9.0) / 7.0)
	return WIG_REST


## The pelmet's rock on his round wig after it lands (rad about its contact line; decays by 40 f).
static func rock_at(bonk_f: float) -> float:
	if bonk_f < 0.0 or bonk_f >= 40.0:
		return 0.0
	return 0.06 * sin(bonk_f / 60.0 * TAU * 2.4) * (1.0 - bonk_f / 40.0)


## 3D: the bit on CurtainBows3D (wander on → double take → slow burn under the wobbling pelmet → the bonk + hold).
func _advance_bellows_3d() -> void:
	if bit.is_empty():
		return
	var t := bit_t
	if _bonk_t >= BIT_TOPPER_S + BIT_TOPPER_LEN_S:
		bows.pose_bellows(BIT_MARK_X, BIT_END_CLIP, 1, 60.0, true, 10)
		bows.set_wig_squash(WIG_REST)
		return
	if _bonk_t >= BIT_TOPPER_S:
		bows.pose_bellows(BIT_MARK_X, BIT_TOPPER_CLIP, 1, 60.0, false, 8)
		bows.set_bellows_squash(1.0)
		bows.set_wig_squash(WIG_REST)
		return
	if _bonk_t >= 0.0:
		bows.pose_bellows(BIT_MARK_X, "bellows/st_bonk", 1, 70.0, false, 0)
		bows.set_bellows_squash(squash_at(_bonk_t * 60.0))
		bows.set_wig_squash(wig_squash_at(_bonk_t * 60.0))
		return
	bows.set_wig_squash(1.0)
	var walk := float(bit["walk"])
	if t < walk:
		var e := 1.0 - pow(1.0 - clampf(t / walk, 0.0, 1.0), 2.0)
		bows.pose_bellows(lerpf(BIT_WING_X, BIT_MARK_X, e), "bellows/cc_wander_on", 1, 20.0)
		return
	if t < float(bit["take"]):
		bows.pose_bellows(BIT_MARK_X, "bellows/st_double_take", 1, 35.0, false)
		return
	bows.pose_bellows(BIT_MARK_X, "bellows/beat_slow_burn", 1, 60.0)
	var take := float(bit["take"])
	bows.set_bellows_tier(int(clampf((t - take) / maxf(0.1, float(bit["wobble"]) - take), 0.0, 1.0) * 3.0))


func _draw() -> void:
	var vs := _vs()
	# footlight glow along the apron edge while anyone is on
	if hush_on or _bellows_on:
		draw_rect(Rect2(0, vs.y - 26.0, vs.x, 26.0), Color(UiKit.GOLD_LIGHT, 0.18))
	if _roses_live and _rose_tex != null:
		for i in ROSES:
			var p := _rp[i]
			draw_set_transform(p, _rr[i], Vector2.ONE)
			draw_texture_rect(_rose_tex, Rect2(-36, -36, 72, 72), false)
		draw_set_transform(Vector2.ZERO)
	if title_on:
		_draw_title(vs)


func _draw_title(vs: Vector2) -> void:
	var k := clampf(_title_t / TITLE_DROP_S, 0.0, 1.0)
	var tsize := TITLE_SIZE
	if _title_tex != null:
		var ts := _title_tex.get_size()
		tsize = Vector2(TITLE_SIZE.x, TITLE_SIZE.x * ts.y / maxf(1.0, ts.x))
	# the card lands with its centre at 40 % of the height (its crest clear of the top edge), right of Hush
	var land_y := vs.y * 0.40 - tsize.y * 0.5
	var y := lerpf(-tsize.y - 40.0, land_y, k * k)
	var sq := Vector2.ONE
	var since := _title_t - TITLE_DROP_S
	if since >= 0.0 and since < 0.25:
		var s := sin(since / 0.25 * PI)
		sq = Vector2(1.0 + 0.12 * s, 1.0 - 0.16 * s)
	var cx := clampf(vs.x * TITLE_X, tsize.x * 0.5 + 24.0, vs.x - tsize.x * 0.5 - 24.0)
	# squash about the card's bottom edge (it lands on it)
	draw_set_transform(Vector2(cx, y + tsize.y), 0.0, sq)
	var r := Rect2(-tsize.x * 0.5, -tsize.y, tsize.x, tsize.y)
	if _title_tex != null:
		draw_texture_rect(_title_tex, r, false)
		if _bulbs.size() == 2:
			# the art's two bulb layers alternate: the chase
			draw_texture_rect(_bulbs[int(_title_t * 7.0) % 2], r, false)
			draw_set_transform(Vector2.ZERO)
			return
	else:
		UiKit.draw_chunky_rect(self, r, 40.0, UiKit.PLUM, UiKit.NAVY, 10.0, 14.0)
		draw_rect(r.grow(-26.0), Color(UiKit.GOLD, 0.9), false, 8.0)
		if UiStrings.has("curtain.title"):
			UiKit.draw_text_centered(self, UiKit.display_font(), r.get_center(), UiStrings.t("curtain.title"),
				UiKit.SIZE_BIG_TITLE, UiKit.GOLD_LIGHT, 18)
		else:
			UiKit.star_points(_star, r.get_center(), 120.0, 52.0)
			draw_colored_polygon(_star, UiKit.GOLD_LIGHT)
	# the bulbs chase round the frame
	var chase := int(_title_t * 14.0)
	for i in BULBS:
		var u := float(i) / float(BULBS)
		var p := _perimeter(r.grow(-8.0), u)
		var lit := (i + chase) % 3 == 0
		draw_circle(p, 13.0, UiKit.GOLD_LIGHT if lit else Color(UiKit.GOLD_SHADE, 0.8))
	draw_set_transform(Vector2.ZERO)


static func _perimeter(r: Rect2, u: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := fposmod(u, 1.0) * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.end - Vector2(d, 0)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


## The pelmet's state now (pure on `bit_t` / `_bonk_t`): {on, bottom (its rect's bottom edge y), line (its solid
## fabric's edge y: the contact line), rot (rad), ropes (true while it hangs), x}. `head` = the top of his wig on
## screen (CurtainBows3D.wig_top_screen, squashed): from the hit on the fabric's edge sits PELMET_PRESS px into it.
func pelmet_state(head: Vector2) -> Dictionary:
	var below := PELMET_SIZE.y * (1.0 - PELMET_FABRIC_K)
	var out := {"on": false, "bottom": -PELMET_SIZE.y - 20.0, "line": -PELMET_SIZE.y - 20.0 - below, "rot": 0.0,
		"ropes": false, "x": head.x}
	if not _bellows_on or bit.is_empty():
		return out
	var rest := head.y + PELMET_PRESS + below
	var wob := float(bit["wobble"])
	var drop := float(bit["drop"])
	var hit := float(bit["hit"])
	if _bonk_t >= 0.0:
		out["on"] = true
		out["bottom"] = rest
		out["line"] = rest - below
		out["rot"] = rock_at(_bonk_t * 60.0)
		return out
	if bit_t < wob:
		return out
	out["on"] = true
	if bit_t < drop:
		# the lurch into view, then the wobble on its ropes (growing; one rope slips at 60 %)
		var w := bit_t - wob
		var lurch := clampf(w * 60.0 / float(PELMET_LURCH_F), 0.0, 1.0)
		var dip := 0.0 if w < BIT_WOBBLE_S * 0.6 else 18.0
		out["bottom"] = lerpf(-20.0, PELMET_HANG_Y, lurch * lurch) + dip
		var grow := 0.5 + w / BIT_WOBBLE_S
		out["rot"] = 0.07 * sin(w * TAU * 4.5) * grow + (0.05 if dip > 0.0 else 0.0)
		out["ropes"] = true
		out["line"] = float(out["bottom"]) - below
		return out
	# the drop: ease-in from where it hung to his head in BIT_DROP_F frames
	var k := clampf((bit_t - drop) / maxf(0.001, hit - drop), 0.0, 1.0)
	out["bottom"] = lerpf(PELMET_HANG_Y, rest, k * k)
	out["line"] = float(out["bottom"]) - below
	return out


## The pelmet, the snapped ropes, the impact star and the dizzy stars (on `top`, above the ResultsScreen).
func _draw_top(ci: Control) -> void:
	if not _bellows_on or bows == null:
		return
	var head: Vector2 = bows.wig_top_screen()
	var st := pelmet_state(head)
	if not bool(st["on"]):
		return
	var bottom := float(st["bottom"])
	var line := float(st["line"])
	var rot := float(st["rot"])
	var w := PELMET_SIZE.x
	var h := PELMET_SIZE.y
	var sq := Vector2.ONE
	if _bonk_t >= 0.0:
		var bf := _bonk_t * 60.0
		var s := clampf(1.0 - bf / 12.0, 0.0, 1.0)
		sq = Vector2(1.0 + 0.10 * s, 1.0 - 0.22 * s)
	var pivot := Vector2(float(st["x"]), bottom - h)
	if bool(st["ropes"]):
		# two gold ropes from the flies to its top corners (they swing with it)
		for side: float in [-1.0, 1.0]:
			var corner := pivot + Vector2(side * (w * 0.5 - 48.0), 0.0).rotated(rot)
			ci.draw_line(Vector2(corner.x, -12.0), corner, UiKit.GOLD_SHADE, 9.0)
			ci.draw_line(Vector2(corner.x, -12.0), corner, UiKit.GOLD_LIGHT, 3.0)
		# dust sifts from the slipping rope
		var w0 := bit_t - float(bit["wobble"])
		for i in 4:
			var ph := fposmod(w0 * 1.6 + float(i) * 0.27, 1.0)
			var dp := pivot + Vector2(-w * 0.5 + 40.0 + float(i) * 14.0, ph * 160.0)
			ci.draw_rect(Rect2(dp, Vector2(7, 7)), Color(UiKit.CREAM, 0.85 * (1.0 - ph)))
	elif _bonk_t < 0.4:
		# the snapped rope ends, flicking up at the flies
		for side: float in [-1.0, 1.0]:
			var x := pivot.x + side * (w * 0.5 - 48.0)
			ci.draw_line(Vector2(x, -12.0), Vector2(x + side * 14.0, 52.0), UiKit.GOLD_SHADE, 9.0)
	# about its contact line (the fabric's edge): it squashes down onto the wig and rocks on it without lifting off
	ci.draw_set_transform(Vector2(float(st["x"]), line), rot, sq)
	var r := Rect2(-w * 0.5, -h * PELMET_FABRIC_K, w, h)
	if _valance_tex != null:
		ci.draw_texture_rect(_valance_tex, r, false)
	else:
		ci.draw_rect(Rect2(r.position, Vector2(w, h * PELMET_FABRIC_K)), UiKit.CURTAIN)
		ci.draw_rect(Rect2(r.position.x, -30.0, r.size.x, 30.0), UiKit.GOLD)
	ci.draw_set_transform(Vector2.ZERO)
	if _bonk_t >= 0.0:
		_draw_hit(ci, Vector2(float(st["x"]), line), w)


## The dust shaken out of the pelmet at the hit (pure on the frames since it, `bf`): puff `i` of DUST_PUFFS →
## Vector4(x, y — its centre, relative to the contact point —, radius, alpha 0..1; a value, no allocation per frame).
## Two clumps where the fabric meets the sides of his wig (even puffs left, odd right), each puff billowing out and up
## at its own angle, gone by DUST_F.
static func dust_puff(i: int, bf: float, w: float) -> Vector4:
	if bf < 0.0 or bf >= DUST_F:
		return Vector4.ZERO
	var side := -1.0 if i % 2 == 0 else 1.0
	var j := (i >> 1) % DUST_ANG.size()
	var u := bf / DUST_F
	var e := 1.0 - pow(1.0 - u, 3.0)
	var ang := deg_to_rad(float(DUST_ANG[j]))
	var dir := Vector2(cos(ang) * side, sin(ang))
	var start := Vector2(side * (w * 0.14 + 7.0 * float(j)), 6.0 - 4.0 * float(j % 2))
	var p := start + dir * float(DUST_DIST[j]) * e + Vector2(0.0, -10.0 * u)
	var r1 := float(DUST_R[j])
	return Vector4(p.x, p.y, lerpf(r1 * 0.45, r1, e), 0.9 * pow(1.0 - u, 1.3))


## The contact (at = the middle of the fabric's edge on his wig): whack lines out of both sides of the wig (6 f), the
## dust puffing out of the old pelmet, then four stars circling round his wig under the fringe. Nothing covers the
## wig on the contact frame — its squash is the read.
func _draw_hit(ci: Control, at: Vector2, w: float) -> void:
	var bf := _bonk_t * 60.0
	if bf < 6.0:
		var a2 := clampf(1.4 - bf / 6.0, 0.0, 1.0)
		for side: float in [-1.0, 1.0]:
			for j in 3:
				var ang := deg_to_rad(-38.0 + 30.0 * float(j))
				var dir := Vector2(cos(ang) * side, sin(ang))
				var p0 := at + Vector2(side * 96.0, 10.0) + dir * (14.0 + bf * 5.0)
				var p1 := p0 + dir * 44.0
				ci.draw_line(p0, p1, Color(ViewKit.INK, a2), 11.0)
				ci.draw_line(p0, p1, Color(1.0, 0.97, 0.82, a2), 5.0)
	if bf < DUST_F:
		for i in DUST_PUFFS:
			var d := dust_puff(i, bf, w)
			var al := d.w
			if al <= 0.0:
				continue
			var c0 := at + Vector2(d.x, d.y)
			var rr := d.z
			ci.draw_circle(c0 + Vector2(0.0, rr * 0.2), rr * 1.1, Color(0.40, 0.29, 0.27, al * 0.4))
			ci.draw_circle(c0, rr, Color(0.91, 0.87, 0.79, al))
	if bf >= 3.0 and _bonk_t < BIT_TOPPER_S:
		var c := at + Vector2(0.0, 12.0)
		for i in ORBIT_STARS:
			var a := _t * TAU * 0.9 + float(i) * TAU / float(ORBIT_STARS)
			var depth := 0.5 + 0.5 * sin(a)
			var p := c + Vector2(cos(a) * 150.0, sin(a) * 30.0)
			var ro := lerpf(16.0, 26.0, depth)
			UiKit.star_points(_star, p, ro + 5.0, (ro + 5.0) * 0.45, a)
			ci.draw_colored_polygon(_star, ViewKit.INK)
			UiKit.star_points(_star, p, ro, ro * 0.45, a)
			ci.draw_colored_polygon(_star, UiKit.GOLD_LIGHT)


## The pelmet's control: above the ResultsScreen (CurtainCall raises it), full rect, never takes input.
class _Top:
	extends Control
	var apron: CurtainApron = null

	func _init() -> void:
		name = "CurtainPelmet"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if apron != null:
			apron._draw_top(self)
