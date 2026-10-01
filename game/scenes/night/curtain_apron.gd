## CurtainApron — what happens in front of the fallen curtain during the curtain call (GDD §6.2):
## Hush on the apron bowing under a rain of roses, the Prologue's title card slamming down (0.3 s drop,
## a squash on landing, the bulbs chasing round its frame), and during the Gag Reel Bellows wandering
## on along the lower stage band in his residue → double take → slow burn → the curtain valance
## drops on his head (bonk).
## The actors are CurtainBows3D's 3D rigs (`bows`, composited under this control: `hush/act_bow`,
## `bellows/cc_wander_on`, `st_double_take`, `beat_slow_burn`, `st_bonk`); the roses, the title and the valance stay
## 2D, on top. Roses are a fixed pool drawn in one `_draw()` (no allocation per frame). (The 2D CharacterView actors
## were removed with the 2D view, r3d-integrate.)
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

## The 3D bows (CurtainBows3D under this control); set before `_ready`.
var bows: CurtainBows3D = null
## 0..1 progress of Bellows' band routine (CurtainCall drives it during the reel).
var bellows_t: float = 0.0
var hush_on: bool = false
var title_on: bool = false

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
var _bonk_t: float = -1.0
var _frame: float = 0.0


func _init() -> void:
	name = "CurtainApron"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rp.resize(ROSES)
	_rv.resize(ROSES)
	_rr.resize(ROSES)
	_rs.resize(ROSES)


func _ready() -> void:
	_rose_tex = UiIcons.get_icon(&"rose")
	if ResourceLoader.exists(VALANCE_ART):
		_valance_tex = load(VALANCE_ART) as Texture2D


func _vs() -> Vector2:
	return size if size.x > 0.0 else Vector2(1920, 1080)


## Hush steps out on the apron and bows for `sec` (false = she leaves).
func show_hush(on: bool, sec: float) -> void:
	hush_on = on
	_hush_t = 0.0
	_hush_len = maxf(0.2, sec)
	if bows != null and not on:
		bows.hide_hush()


## Roses rain from the flies onto the apron.
func rain_roses() -> void:
	var vs := _vs()
	var seed_v := 7
	for i in ROSES:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var fx := float(seed_v % 1000) / 1000.0
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var fy := float(seed_v % 1000) / 1000.0
		_rp[i] = Vector2(vs.x * (0.2 + 0.6 * fx), -80.0 - 700.0 * fy)
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


## Bellows wanders on (the reel); `residues` = the looks he ended the Night in.
func start_bellows(residues: Variant) -> void:
	_bellows_on = true
	bellows_t = 0.0
	_bonk_t = -1.0
	if bows != null and residues is PackedStringArray:
		bows.set_residues(residues)


## The valance drops on his head.
func bonk() -> void:
	if not _bellows_on or _bonk_t >= 0.0:
		return
	_bonk_t = 0.0
	var au := ViewKit.autoload("Audio")
	if au != null and au.has_method("play_sfx"):
		au.call("play_sfx", "bonk")
	UiKit.haptic(&"stomp")


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
		bows.pose_hush(lerpf(0.36, 0.5, clampf(k3 / 0.3, 0.0, 1.0)), "hush/loco_walk" if walking else "hush/act_bow", 1,
			20.0 if walking else 85.0)
	if _bellows_on and bows != null:
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
	if _bonk_t >= 0.0:
		_bonk_t += dt
	queue_redraw()



## 3D: the band routine on CurtainBows3D (wander on → double take → slow burn → the bonk).
func _advance_bellows_3d() -> void:
	var t := bellows_t
	if t < 0.45:
		var e := 1.0 - pow(1.0 - t / 0.45, 2.0)
		bows.pose_bellows(lerpf(1.08, 0.56, e), "bellows/cc_wander_on", -1, 20.0)
		return
	if t < 0.55:
		bows.pose_bellows(0.56, "bellows/st_double_take", 1 if fmod(_t * 6.0, 2.0) < 1.0 else -1, 35.0)
	elif _bonk_t < 0.0:
		bows.pose_bellows(0.56, "bellows/beat_slow_burn", 1, 60.0)
		bows.set_bellows_tier(int(clampf((t - 0.55) / 0.3, 0.0, 1.0) * 3.0))
	else:
		bows.pose_bellows(0.56, "bellows/st_bonk", 1, 60.0)


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
	if _bonk_t >= 0.0 and bows != null:
		_draw_valance(vs)


func _draw_title(vs: Vector2) -> void:
	var k := clampf(_title_t / TITLE_DROP_S, 0.0, 1.0)
	var tsize := TITLE_SIZE
	if _title_tex != null:
		var ts := _title_tex.get_size()
		tsize = Vector2(TITLE_SIZE.x, TITLE_SIZE.x * ts.y / maxf(1.0, ts.x))
	# the card lands with its centre at 40 % of the height (its crest clear of the top edge)
	var land_y := vs.y * 0.40 - tsize.y * 0.5
	var y := lerpf(-tsize.y - 40.0, land_y, k * k)
	var sq := Vector2.ONE
	var since := _title_t - TITLE_DROP_S
	if since >= 0.0 and since < 0.25:
		var s := sin(since / 0.25 * PI)
		sq = Vector2(1.0 + 0.12 * s, 1.0 - 0.16 * s)
	# squash about the card's bottom edge (it lands on it)
	draw_set_transform(Vector2(vs.x * 0.5, y + tsize.y), 0.0, sq)
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
			var star := PackedVector2Array()
			star.resize(10)
			UiKit.star_points(star, r.get_center(), 120.0, 52.0)
			draw_colored_polygon(star, UiKit.GOLD_LIGHT)
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


func _draw_valance(vs: Vector2) -> void:
	var head: Vector2 = bows.head_screen("bellows")
	var head_y := head.y
	var k := clampf(_bonk_t / 0.12, 0.0, 1.0)
	var bottom := lerpf(-10.0, head_y + 30.0, k * k)
	var w := 520.0
	var r := Rect2(head.x - w * 0.5, bottom - 170.0, w, 170.0)
	draw_rect(Rect2(r.position.x + 40.0, -10.0, 16.0, r.position.y + 10.0), UiKit.GOLD_SHADE)
	draw_rect(Rect2(r.end.x - 56.0, -10.0, 16.0, r.position.y + 10.0), UiKit.GOLD_SHADE)
	if _valance_tex != null:
		draw_texture_rect(_valance_tex, r, false)
	else:
		draw_rect(r, UiKit.CURTAIN)
		draw_rect(Rect2(r.position.x, r.end.y - 30.0, r.size.x, 30.0), UiKit.GOLD)
