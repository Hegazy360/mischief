## StallsView — the visible laugh track (GDD §1.2, §4.10, §6.5; TECH §5.10): 24 silhouetted
## heads along the bottom-centre band (x from S+800 to W−S−312), drawn from ONE atlas in
## `_draw()` (one batched draw call). Resting they peek up 40 px at `alpha_rest` (0.6); they react
## per laugh tier — T0 two heads nudge, T1 bob, T2 bounce, T3 rise +60 px, T4 everyone stands and
## one head tumbles heels-over-head in its seat (`tumble` frames, 8 f each) — and do the specials:
## `shush` (lean toward `face_dir`), `gasp` (jolt), `behind_you` (rise + the `point` frame + the
## `fx.behind_you` balloon), `boo`, `aww`, `chant`, `relief` (a collective exhale, then a titter).
## `alpha_hold` (1.0) during reaction holds. No input handling at all (a CanvasLayer at layer 9,
## under the HUD).
##
## Data (art-hush / s2-anim-hush): `res://data/rigs/stalls/stalls.json` — heads (frames rest /
## laugh / lean / point, `size` canvas + `pivot` bottom centre, `face_dir`), `layout` (seat order),
## `tumble` frames, `alpha_rest` / `alpha_hold`; `res://data/anim/stalls/tiers.json` (optional) —
## per tier `heads_pct`, `rise_px`, `bob_hz`, `bounce_px`, `frame`, `hold_s`, `delay_ms` (per-head
## pattern), `stand`, `tumble {head, frames, f_per_frame}`, and per special the same keys. The
## built-in constants (DEFAULT_TIERS / DEFAULT_SPECIALS) apply when a file or a key is missing,
## and built-in rounded silhouettes when the art is.
class_name StallsView
extends Node2D

const STALLS_JSON := "res://data/rigs/stalls/stalls.json"
const TIERS_JSON := "res://data/anim/stalls/tiers.json"
const HEADS := 24
const REST_PX := 40.0
const REST_ALPHA := 0.6
const FILL := Color("#2A1E3A")
const SPRING_K := 160.0
const SPRING_C := 13.0
const BAND_LEFT := 800.0
const BAND_RIGHT := 312.0
const BALLOON_S := 1.6
## The silhouettes are drawn at ≤ 0.8× their 1× size (front row 0.8, back row 0.62) in one flat
## fill: the atlas is rasterised at 0.8× (lossless on screen; s2-fix G #7: 17.7 → 11.3 MB). Regions
## are atlas px, destination rects stay in 1× px, so drawing is unchanged.
const ATLAS_SCALE := 0.8
const TUMBLE_F_PER_FRAME := 8
## Motion per laugh tier (the GDD §6.5 table as data; tiers.json overrides key by key).
const DEFAULT_TIERS := {
	"t0": {"heads_pct": 0.09, "rise_px": 6.0, "bob_hz": 0.0, "bounce_px": 0.0, "frame": "lean", "hold_s": 0.8},
	"t1": {"heads_pct": 1.0, "rise_px": 0.0, "bob_hz": 3.0, "bounce_px": 9.0, "frame": "rest", "hold_s": 1.2},
	"t2": {"heads_pct": 1.0, "rise_px": 8.0, "bob_hz": 4.0, "bounce_px": 16.0, "frame": "laugh", "hold_s": 2.0},
	"t3": {"heads_pct": 1.0, "rise_px": 60.0, "bob_hz": 4.0, "bounce_px": 14.0, "frame": "laugh", "hold_s": 3.0},
	"t4": {"heads_pct": 1.0, "rise_px": 82.0, "bob_hz": 3.2, "bounce_px": 22.0, "frame": "laugh", "hold_s": 4.5,
		"stand": true, "tumble": {"head": "", "frames": 4, "f_per_frame": 8}},
}
const DEFAULT_SPECIALS := {
	"shush": {"heads_pct": 1.0, "rise_px": 0.0, "lean": 0.2, "frame": "lean", "hold_s": 1.6},
	"gasp": {"heads_pct": 1.0, "rise_px": 16.0, "frame": "rest", "hold_s": 0.7},
	"behind_you": {"heads_pct": 0.34, "rise_px": 42.0, "frame": "point", "hold_s": 1.6},
	"boo": {"heads_pct": 1.0, "rise_px": 6.0, "lean": -0.15, "frame": "rest", "hold_s": 1.6},
	"aww": {"heads_pct": 1.0, "rise_px": -8.0, "frame": "rest", "hold_s": 1.6},
	"relief": {"heads_pct": 1.0, "rise_px": -6.0, "bob_hz": 3.0, "bounce_px": 8.0, "frame": "rest", "hold_s": 1.4},
	"chant": {"heads_pct": 1.0, "rise_px": 0.0, "bob_hz": 2.0, "bounce_px": 18.0, "frame": "laugh", "hold_s": 3.0},
	"ooh": {"heads_pct": 1.0, "rise_px": 10.0, "frame": "rest", "hold_s": 0.8},
}
## Balloon words per special (s2-ui `fx.*` keys, with today's literal as the fallback).
const BALLOONS := {"behind_you": ["fx.behind_you", "BEHIND YOU!"], "boo": ["fx.boo", "BOO!"], "aww": ["fx.aww", "Awww…"],
	"chant": ["fx.chant", "PIPE-DOWN!"], "shush": ["fx.shush", "SHHH!"], "ooh": ["fx.ooh", "Ooooh!"]}

var reduce_motion: bool = false
## Test hook: a fixed canvas size.
var view_size_override: Vector2 = Vector2.ZERO
## Symmetric side inset S (logical px); refreshed from SafeArea when available.
var side_inset: float = 0.0
var alpha_rest: float = REST_ALPHA
var alpha_hold: float = 1.0

var _atlas: Texture2D = null
## Per seat: atlas regions for rest / laugh / lean / point, drawn canvas size and pivot.
var _rest: Array[Rect2] = []
var _laugh: Array[Rect2] = []
var _lean: Array[Rect2] = []
var _point: Array[Rect2] = []
var _size: Array[Vector2] = []
var _pivot: Array[Vector2] = []
## Silhouette height above the pivot (stalls.json `h`): the part that peeks over the edge.
var _sil_h := PackedFloat32Array()
var _face := PackedFloat32Array()
var _ids := PackedStringArray()
var _tumble_r: Array[Rect2] = []
var _tumble_size := Vector2.ZERO
var _tumble_pivot := Vector2.ZERO
var _tiers: Dictionary = {}
var _specials: Dictionary = {}
var _x := PackedFloat32Array()
var _row := PackedInt32Array()
var _y := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _mode := "rest"
var _tier := -1
var _spec: Dictionary = {}
var _t := 0.0
var _dur := 0.0
var _alpha := REST_ALPHA
var _nudge_a := 0
var _tumble := -1
var _tumble_t := 0.0
var _balloon := ""
var _balloon_t := 0.0
var _font: Font = null
var _layout_w := 0.0
var _laughs := 0


func _init() -> void:
	name = "Stalls"
	process_priority = -10


func _ready() -> void:
	_font = ViewKit.display_font()
	reduce_motion = bool(ViewKit.setting("reduce_motion", false))
	_load_tables()
	_build_atlas()
	_layout_heads()


## Canvas size (logical px).
func view_size() -> Vector2:
	if view_size_override != Vector2.ZERO:
		return view_size_override
	return get_viewport_rect().size if is_inside_tree() else Vector2(2400, 1080)


func _load_tables() -> void:
	_tiers = DEFAULT_TIERS.duplicate(true)
	_specials = DEFAULT_SPECIALS.duplicate(true)
	var v: Variant = ViewKit.json(TIERS_JSON)
	if not (v is Dictionary):
		return
	var t: Variant = (v as Dictionary).get("tiers", {})
	if t is Dictionary:
		for k in t:
			if (t as Dictionary)[k] is Dictionary:
				var base: Dictionary = _tiers.get(ViewKit.s(k), {})
				base.merge((t as Dictionary)[k], true)
				_tiers[ViewKit.s(k)] = base
	var sp: Variant = (v as Dictionary).get("specials", {})
	if sp is Dictionary:
		for k2 in sp:
			if (sp as Dictionary)[k2] is Dictionary:
				var b2: Dictionary = _specials.get(ViewKit.s(k2), {})
				b2.merge((sp as Dictionary)[k2], true)
				_specials[ViewKit.s(k2)] = b2


## The motion row for tier `n` (t0–t4) — tiers.json over the built-in table.
func tier_row(n: int) -> Dictionary:
	return _tiers.get("t%d" % clampi(n, 0, 4), {})


# --- public reactions ----------------------------------------------------------------------

## A laugh of tier 0–4 (GDD §6.5).
func react(tier: int) -> void:
	tier = clampi(tier, 0, 4)
	_tier = tier
	_mode = "laugh"
	_spec = tier_row(tier)
	_t = 0.0
	_dur = float(_spec.get("hold_s", 1.0))
	_laughs += 1
	if tier == 0:
		_nudge_a = (_laughs * 7) % (HEADS - 1)
	if tier == 4 and _tumble < 0:
		_tumble = _tumble_seat()
		_tumble_t = 0.0


func _tumble_seat() -> int:
	var tb: Variant = _spec.get("tumble", {})
	var id := ViewKit.s((tb as Dictionary).get("head", "")) if tb is Dictionary else ""
	if id != "":
		var i := _ids.find(id)
		if i >= 0:
			return i
	return (_laughs * 5 + 3) % 12


## Specials: shush, gasp, behind_you, boo, aww, chant, relief, ooh (t0–t4 = laughs).
func special(kind: String) -> void:
	match kind:
		"t0", "t1", "t2", "t3", "t4":
			react(int(kind.substr(1)))
			return
		"shh":
			kind = "shush"
		"rest":
			_mode = "rest"
			_tier = -1
			_t = 0.0
			_dur = 0.0
			_balloon = ""
			return
	_mode = kind
	_tier = -1
	_spec = _specials.get(kind, {"hold_s": 1.6})
	_t = 0.0
	_dur = float(_spec.get("hold_s", 1.6))
	var bw: Variant = BALLOONS.get(kind, null)
	_balloon = ViewKit.word(ViewKit.s(bw[0]), ViewKit.s(bw[1])) if bw is Array else ""
	_balloon_t = 0.0 if _balloon != "" else 99.0


## Current behaviour ("rest", "laugh", "gasp", …), tier (−1 for specials), alpha (tests).
func mode() -> String:
	return _mode


func tier() -> int:
	return _tier


func strip_alpha() -> float:
	return _alpha


## Visible height (px above the bottom edge) of head `i` right now (tests).
func head_rise(i: int) -> float:
	return REST_PX + _y[clampi(i, 0, HEADS - 1)] * -1.0


func tumbling() -> int:
	return _tumble


## The tumble frame the tumbler shows now (0–3; −1 none): 8 f per frame, then holds the last.
func tumble_frame() -> int:
	if _tumble < 0:
		return -1
	var fpf := TUMBLE_F_PER_FRAME
	var tb: Variant = tier_row(4).get("tumble", {})
	if tb is Dictionary:
		fpf = maxi(1, int((tb as Dictionary).get("f_per_frame", fpf)))
	var n := maxi(1, _tumble_r.size())
	return mini(int(_tumble_t * 60.0 / float(fpf)), n - 1)


## Seat ids in layout order (tests).
func seat_ids() -> PackedStringArray:
	return _ids


## The frame a seat shows now ("rest", "laugh", "lean", "point").
func frame_of(i: int) -> String:
	if _mode == "rest":
		return "rest"
	if not _selected(i):
		return "rest"
	if _mode == "laugh" and _tier == 0:
		return "lean" if (i == _nudge_a or i == _nudge_a + 1) else "rest"
	return ViewKit.s(_spec.get("frame", "rest"))


# --- atlas ---------------------------------------------------------------------------------

func _build_atlas() -> void:
	_rest.clear()
	_laugh.clear()
	_lean.clear()
	_point.clear()
	_size.clear()
	_pivot.clear()
	_face.resize(HEADS)
	_ids.resize(HEADS)
	_sil_h.resize(HEADS)
	if _atlas_from_json():
		return
	_atlas_fallback()


## art-hush's atlas: heads (ordered by `layout`) with frames {rest, laugh, lean, point} as texture
## paths, plus the `tumble` frames; everything is packed into ONE runtime texture.
func _atlas_from_json() -> bool:
	var v: Variant = ViewKit.json(STALLS_JSON)
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	var heads: Array = d.get("heads", [])
	if heads.is_empty():
		return false
	alpha_rest = float(d.get("alpha_rest", REST_ALPHA))
	alpha_hold = float(d.get("alpha_hold", 1.0))
	_alpha = alpha_rest
	var by_id := {}
	for h in heads:
		if h is Dictionary:
			by_id[ViewKit.s((h as Dictionary).get("id", ""))] = h
	var order: Array = []
	for id in d.get("layout", []):
		if by_id.has(ViewKit.s(id)):
			order.append(by_id[ViewKit.s(id)])
	for h2 in heads:
		if not order.has(h2):
			order.append(h2)
	var imgs: Array[Image] = []
	var n := mini(HEADS, order.size())
	for i in n:
		var hd: Dictionary = order[i]
		var fr: Dictionary = hd.get("frames", {})
		for k in ["rest", "laugh", "lean", "point"]:
			var p: Variant = fr.get(k, fr.get("rest", null))
			var img := _image_of(ViewKit.s(p) if p is String else "")
			if img == null:
				return false
			imgs.append(img)
	var tumble: Array = d.get("tumble", []) if d.get("tumble", []) is Array else []
	var nt := 0
	for tf in tumble:
		if tf is Dictionary:
			var ti := _image_of(ViewKit.s((tf as Dictionary).get("file", "")))
			if ti != null:
				imgs.append(ti)
				nt += 1
				_tumble_size = _v2((tf as Dictionary).get("size", [ti.get_width() / ATLAS_SCALE, ti.get_height() / ATLAS_SCALE]))
				_tumble_pivot = _v2((tf as Dictionary).get("pivot", [_tumble_size.x * 0.5, _tumble_size.y]))
	var rects := _pack(imgs)
	if rects.is_empty():
		return false
	for i in HEADS:
		var src := i % n
		var hd2: Dictionary = order[src]
		_rest.append(rects[src * 4])
		_laugh.append(rects[src * 4 + 1])
		_lean.append(rects[src * 4 + 2])
		_point.append(rects[src * 4 + 3])
		var sz := _v2(hd2.get("size", [rects[src * 4].size.x / ATLAS_SCALE, rects[src * 4].size.y / ATLAS_SCALE]))
		_size.append(sz)
		_pivot.append(_v2(hd2.get("pivot", [sz.x * 0.5, sz.y])))
		_face[i] = float(hd2.get("face_dir", 1))
		_ids[i] = ViewKit.s(hd2.get("id", ""))
		_sil_h[i] = float(hd2.get("h", sz.y))
	_tumble_r.clear()
	for k2 in nt:
		_tumble_r.append(rects[n * 4 + k2])
	return true


static func _v2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


func _image_of(path: String) -> Image:
	if path == "":
		return null
	# The atlas is packed in 1× px: rasterise the SVG at 1× straight into an Image (s2-fix G #7 —
	# going through ViewKit.tex left ~100 unused 2× textures alive, 65 MB).
	var hs := ViewKit.soft_script(ViewKit.HIRES_PATH)
	if hs != null and hs.has_method("rasterize") and path.get_extension().to_lower() == "svg":
		var raw: Variant = hs.call("rasterize", path, {}, ATLAS_SCALE)
		if raw is Image and not (raw as Image).is_empty():
			var ri := raw as Image
			if ri.get_format() != Image.FORMAT_RGBA8:
				ri.convert(Image.FORMAT_RGBA8)
			return ri
	if not ResourceLoader.exists(path):
		return null
	var t := load(path) as Texture2D
	if t == null:
		return null
	var img := t.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var sz := t.get_size() * ATLAS_SCALE
	if img.get_width() != int(sz.x) and sz.x > 0.0:
		img.resize(maxi(1, int(sz.x)), maxi(1, int(sz.y)), Image.INTERPOLATE_BILINEAR)
	return img


## Shelf-pack images into one atlas texture; returns their rects (empty on failure).
func _pack(imgs: Array[Image]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := 2048
	var x := 2
	var y := 2
	var row_h := 0
	for img in imgs:
		if x + img.get_width() + 2 > w:
			x = 2
			y += row_h + 2
			row_h = 0
		out.append(Rect2(x, y, img.get_width(), img.get_height()))
		x += img.get_width() + 2
		row_h = maxi(row_h, img.get_height())
	var h := y + row_h + 2
	if h > 2048:
		return []
	var atlas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		atlas.blit_rect(imgs[i], Rect2i(0, 0, imgs[i].get_width(), imgs[i].get_height()), Vector2i(out[i].position))
	_atlas = ImageTexture.create_from_image(atlas)
	var ts := ViewKit.soft_script("res://view/tex/tex_stats.gd")
	if ts != null and ts.has_method("note_build"):
		ts.call("note_build", "stalls")
	if ts != null and ts.has_method("track_image"):
		ts.call("track_image", _atlas, atlas, "stalls", "stalls:atlas")
	return out


## Built-in silhouettes: one SVG sheet (6 × 4 cells of 120 × 130), rasterised once.
func _atlas_fallback() -> void:
	var cell := Vector2(120, 130)
	var body := ""
	for i in HEADS:
		var cx := float(i % 6) * cell.x + cell.x * 0.5
		var cy := float(i / 6) * cell.y
		body += StallsView._head_svg(i, cx, cy)
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'>%s</svg>" % [int(cell.x * 6), int(cell.y * 4), body]
	_atlas = ViewKit.svg_tex("stalls_fallback", svg, 1.0)
	for i in HEADS:
		var r := Rect2(float(i % 6) * cell.x, float(i / 6) * cell.y, cell.x, cell.y)
		_rest.append(r)
		_laugh.append(r)
		_lean.append(r)
		_point.append(r)
		_size.append(cell)
		_pivot.append(Vector2(cell.x * 0.5, cell.y))
		_face[i] = 1.0 if i % 2 == 0 else -1.0
		_ids[i] = "fallback_%d" % i
		_sil_h[i] = cell.y


## One silhouette (flat #FFFFFF, tinted at draw time) in a 120 × 130 cell; the head sits on
## shoulders at the bottom.
static func _head_svg(i: int, cx: float, top: float) -> String:
	var b := top + 130.0
	var s := "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' fill='#FFFFFF'/>" % [cx - 58, b, cx - 50, b - 34, cx + 50, b - 34, cx + 58, b]
	var hr := 22.0 + float((i * 7) % 5) * 2.0
	var hy := b - 40.0 - hr
	s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx, hy, hr]
	match i % 8:
		0:
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='6' fill='#FFFFFF'/>" % [cx, hy - hr * 0.55, hr * 1.35]
			s += "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' fill='#FFFFFF'/>" % [cx - hr * 0.85, hy - hr * 0.5, cx - hr * 0.8, hy - hr * 1.9, cx + hr * 0.8, hy - hr * 1.9, cx + hr * 0.85, hy - hr * 0.5]
		1:
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='%.1f' fill='#FFFFFF'/>" % [cx, hy - hr * 1.3, hr * 0.85, hr * 1.25]
		2:
			s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx, hy - 3, hr + 3]
		3:
			s += "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' fill='#FFFFFF'/>" % [cx - hr * 0.7, hy - hr * 2.4, hr * 1.4, hr * 1.9]
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='5' fill='#FFFFFF'/>" % [cx, hy - hr * 0.55, hr * 1.3]
		4:
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='%.1f' fill='#FFFFFF'/>" % [cx, hy - hr * 0.7, hr * 1.2, hr * 0.5]
			s += "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' fill='none' stroke='#FFFFFF' stroke-width='7' stroke-linecap='round'/>" % [cx + hr * 0.4, hy - hr, cx + hr * 1.2, hy - hr * 2.2, cx + hr * 1.8, hy - hr * 2.0, cx + hr * 2.0, hy - hr * 2.6]
		5:
			for k in 4:
				s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx - hr * 0.75 + float(k) * hr * 0.5, hy - hr * 0.9, hr * 0.3]
		6:
			s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx + hr * 0.5, hy - hr * 1.9, hr * 0.62]
			s += "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' rx='6' fill='#FFFFFF'/>" % [cx + hr * 0.05, hy - hr * 1.4, hr * 0.9, hr * 0.9]
		7:
			s += "<path d='M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' fill='#FFFFFF'/>" % [cx - hr, hy - hr * 0.4, cx + hr * 1.5, hy - hr * 0.55, cx - hr * 0.2, hy - hr * 1.15]
	return s


func _layout_heads() -> void:
	_x.resize(HEADS)
	_row.resize(HEADS)
	_y.resize(HEADS)
	_vy.resize(HEADS)
	_rot.resize(HEADS)
	_phase.resize(HEADS)
	var vs := view_size()
	_refresh_inset()
	var x0 := side_inset + BAND_LEFT
	var x1 := vs.x - side_inset - BAND_RIGHT
	_layout_w = vs.x
	var w := maxf(200.0, x1 - x0)
	var front := HEADS / 2
	for i in HEADS:
		var row := 0 if i < front else 1
		var k := i if row == 0 else i - front
		var n := front
		var fx := (float(k) + 0.5 + (0.5 if row == 1 else 0.0)) / float(n + (1 if row == 1 else 0))
		_x[i] = x0 + w * fx + float((i * 13) % 11 - 5)
		_row[i] = row
		_y[i] = 0.0
		_vy[i] = 0.0
		_rot[i] = 0.0
		_phase[i] = float((i * 37) % 100) / 100.0 * TAU


func _refresh_inset() -> void:
	var sa := ViewKit.soft_script("res://autoload/support/safe_area.gd")
	if sa != null and is_inside_tree():
		var v: Variant = sa.call("insets", get_viewport())
		if v is Vector4:
			side_inset = (v as Vector4).x


# --- animation -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	advance(delta)


## One frame (public for tests; real time — the audience never slows down).
func advance(delta: float) -> void:
	delta = minf(delta, 0.1)
	if absf(view_size().x - _layout_w) > 1.0:
		_layout_heads()
	_t += delta
	if _mode != "rest" and _t >= _dur:
		_mode = "rest"
		_tier = -1
	var want_alpha := alpha_rest if _mode == "rest" else alpha_hold
	_alpha = move_toward(_alpha, want_alpha, delta * (4.0 if want_alpha > _alpha else 1.2))
	_balloon_t += delta
	if _tumble >= 0:
		_tumble_t += delta
		if _tumble_t > 5.0:
			_tumble = -1
	for i in HEADS:
		var target := _target_rise(i)
		var acc := -SPRING_K * (_y[i] + target) - SPRING_C * _vy[i]
		_vy[i] += acc * delta
		_y[i] += _vy[i] * delta
		_rot[i] = lerpf(_rot[i], _target_rot(i), minf(1.0, delta * 10.0))
	queue_redraw()


## True when seat `i` takes part in the current reaction (`heads_pct` of the seats, spread).
func _selected(i: int) -> bool:
	var pct := float(_spec.get("heads_pct", 1.0))
	if pct >= 0.999:
		return true
	return float((i * 7 + _laughs * 5) % HEADS) < pct * float(HEADS)


## This seat's start delay (s) from `delay_ms` (a per-head pattern, repeated).
func _delay(i: int) -> float:
	var dm: Variant = _spec.get("delay_ms", null)
	if dm is Array and not (dm as Array).is_empty():
		return float((dm as Array)[i % (dm as Array).size()]) / 1000.0
	return 0.0


## Upward rise (px, positive = up) this head wants right now.
func _target_rise(i: int) -> float:
	if _mode == "rest":
		return 0.0
	var m := 0.6 if reduce_motion else 1.0
	if i == _tumble and _mode == "laugh":
		return 30.0
	if _mode == "laugh" and _tier == 0:
		var u0 := clampf(_t / maxf(0.01, _dur), 0.0, 1.0)
		return float(_spec.get("rise_px", 6.0)) * sin(u0 * PI) if (i == _nudge_a or i == _nudge_a + 1) else 0.0
	if not _selected(i):
		return 2.0 * sin(clampf(_t / maxf(0.01, _dur), 0.0, 1.0) * PI)
	var t := _t - _delay(i)
	if t < 0.0:
		return 0.0
	var span := maxf(0.01, _dur - _delay(i))
	var u := clampf(t / span, 0.0, 1.0)
	var env := sin(u * PI) if u < 1.0 else 0.0
	var rise := float(_spec.get("rise_px", 0.0))
	var bob := float(_spec.get("bob_hz", 0.0))
	var bounce := float(_spec.get("bounce_px", 0.0))
	var hold_env := env
	if rise >= 40.0:
		# Big rises stand up fast and hold, then sit down in the last fifth.
		hold_env = minf(1.0, t * 4.0) if u < 0.8 else env * 2.0
	if _mode == "gasp":
		hold_env = 1.0 if t < 0.45 else env
	var wobble := absf(sin(t * TAU * bob + _phase[i])) * bounce if bob > 0.0 else 0.0
	return (rise * hold_env + wobble * env) * m + (float(i % 3) * 8.0 * hold_env if bool(_spec.get("stand", false)) else 0.0)


func _target_rot(i: int) -> float:
	var u := clampf(_t / maxf(0.01, _dur), 0.0, 1.0)
	var env := sin(u * PI) if u < 1.0 else 0.0
	if i == _tumble and _tumble_r.is_empty():
		return _tumble_t * 9.0
	if _mode == "rest":
		return 0.0
	var fd := _face[i] if _face.size() > i else 1.0
	match _mode:
		"laugh":
			if _tier == 0 and (i == _nudge_a or i == _nudge_a + 1):
				return (0.25 if i == _nudge_a else -0.25) * env
			if _tier >= 2:
				return -0.18 * fd * env * absf(sin(_t * 6.0 + _phase[i]))
		_:
			var lean := float(_spec.get("lean", 0.0))
			if lean != 0.0:
				return lean * fd * env
	return 0.0


func _region(i: int) -> Rect2:
	match frame_of(i):
		"laugh":
			return _laugh[i]
		"lean":
			return _lean[i]
		"point":
			return _point[i]
	return _rest[i]


func _draw() -> void:
	if _atlas == null:
		return
	var vs := view_size()
	var bottom := vs.y
	for pass_i in 2:
		var pass_row := 1 - pass_i
		for i in HEADS:
			if _row[i] != pass_row:
				continue
			var sc := 0.62 if pass_row == 1 else 0.8
			var rise := REST_PX + (-_y[i])
			var col := Color(FILL.lightened(0.12 if pass_row == 1 else 0.0), _alpha * (0.8 if pass_row == 1 else 1.0))
			var tf := tumble_frame() if i == _tumble else -1
			if tf >= 0 and not _tumble_r.is_empty():
				var feet_t := Vector2(_x[i], bottom - rise + _tumble_size.y * sc * 0.8)
				draw_set_transform(feet_t, 0.0, Vector2(sc * (_face[i] if _face[i] != 0.0 else 1.0), sc))
				draw_texture_rect_region(_atlas, Rect2(-_tumble_pivot, _tumble_size), _tumble_r[tf], col)
				continue
			var sz := _size[i]
			var piv := _pivot[i]
			var feet := Vector2(_x[i], bottom - rise + _sil_h[i] * sc)
			draw_set_transform(feet, _rot[i], Vector2(sc, sc))
			draw_texture_rect_region(_atlas, Rect2(-piv, sz), _region(i), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _balloon != "" and _balloon_t < BALLOON_S and _font != null:
		var fs := 44
		var a := clampf((BALLOON_S - _balloon_t) / 0.3, 0.0, 1.0)
		var w := _font.get_string_size(_balloon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := vs.x * 0.5
		var y := bottom - 150.0 - sin(minf(1.0, _balloon_t * 5.0) * PI * 0.5) * 20.0
		var box := Rect2(cx - w * 0.5 - 24.0, y - fs - 6.0, w + 48.0, fs + 28.0)
		draw_rect(box.grow(5.0), Color(ViewKit.INK, a))
		draw_rect(box, Color("#FFF4E0", a))
		draw_string(_font, Vector2(cx - w * 0.5, y + 8.0), _balloon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ViewKit.INK, a))
