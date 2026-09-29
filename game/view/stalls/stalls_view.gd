## StallsView — the visible laugh track (GDD §1.2, §4.10, §6.5; TECH §5.10): 24 silhouetted
## heads along the bottom-centre band (x from S+800 to W−S−312), drawn from ONE atlas in
## `_draw()` (one batched draw call). Resting they peek up 40 px at alpha 0.6; they react per
## laugh tier — T0 two heads nudge, T1 bob, T2 bounce, T3 rise +60 px, T4 everyone stands and
## one head tumbles out of its seat — and do the specials: shush (lean), gasp (jolt),
## "BEHIND YOU!" (rise + point), boo, aww, the PIPE-DOWN! chant, relief. Alpha 1.0 during
## reaction holds. No input handling at all (put it on a CanvasLayer at layer 9, under the
## HUD). Atlas: `res://data/rigs/stalls/stalls.json` (owner `art-hush`) when present, else
## built-in rounded silhouettes (bowlers, beehives, a shiny bald head, a toddler on a
## shoulder…).
class_name StallsView
extends Node2D

const STALLS_JSON := "res://data/rigs/stalls/stalls.json"
const HEADS := 24
const REST_PX := 40.0
const REST_ALPHA := 0.6
const FILL := Color("#2A1E3A")
const SPRING_K := 160.0
const SPRING_C := 13.0
const BAND_LEFT := 800.0
const BAND_RIGHT := 312.0
const BALLOON_S := 1.6
## Durations (s) of each reaction.
const DUR := {0: 0.8, 1: 1.2, 2: 2.0, 3: 3.0, 4: 4.5}

var reduce_motion: bool = false
## Test hook: a fixed canvas size.
var view_size_override: Vector2 = Vector2.ZERO
## Symmetric side inset S (logical px); refreshed from SafeArea when available.
var side_inset: float = 0.0

var _atlas: Texture2D = null
## Per head: atlas regions for rest / laugh / lean, drawn size (1×).
var _rest: Array[Rect2] = []
var _laugh: Array[Rect2] = []
var _lean: Array[Rect2] = []
var _size: Array[Vector2] = []
var _x := PackedFloat32Array()
var _row := PackedInt32Array()
var _y := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _mode := "rest"
var _tier := -1
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
	_build_atlas()
	_layout_heads()


## Canvas size (logical px).
func view_size() -> Vector2:
	if view_size_override != Vector2.ZERO:
		return view_size_override
	return get_viewport_rect().size if is_inside_tree() else Vector2(2400, 1080)


# --- public reactions ----------------------------------------------------------------------

## A laugh of tier 0–4 (GDD §6.5).
func react(tier: int) -> void:
	tier = clampi(tier, 0, 4)
	_tier = tier
	_mode = "laugh"
	_t = 0.0
	_dur = float(DUR[tier])
	_laughs += 1
	if tier == 0:
		_nudge_a = (_laughs * 7) % (HEADS - 1)
	if tier == 4 and _tumble < 0:
		_tumble = (_laughs * 5 + 3) % 12
		_tumble_t = 0.0


## Specials: shush, gasp, behind_you, boo, aww, chant, relief, ooh.
func special(kind: String) -> void:
	match kind:
		"relief":
			react(1)
			return
		"t0", "t1", "t2", "t3", "t4":
			react(int(kind.substr(1)))
			return
	_mode = kind
	_tier = -1
	_t = 0.0
	_dur = 1.6 if kind != "chant" else 3.0
	match kind:
		"behind_you":
			_balloon = "BEHIND YOU!"
		"boo":
			_balloon = "BOO!"
		"aww":
			_balloon = "Awww…"
		"chant":
			_balloon = "PIPE-DOWN!"
		"shush", "shh":
			_mode = "shush"
			_balloon = "SHHH!"
		"gasp":
			_dur = 0.7
			_balloon = ""
		"ooh":
			_dur = 0.8
			_balloon = "Ooooh!"
		_:
			_balloon = ""
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


# --- atlas ---------------------------------------------------------------------------------

func _build_atlas() -> void:
	_rest.clear()
	_laugh.clear()
	_lean.clear()
	_size.clear()
	if _atlas_from_json():
		return
	_atlas_fallback()


## art-hush's atlas: heads[i].frames.{rest, laugh, lean} = texture paths (or [x, y, w, h] on a
## "sheet"). Packs every frame into one runtime texture.
func _atlas_from_json() -> bool:
	var v: Variant = ViewKit.json(STALLS_JSON)
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	var heads: Array = d.get("heads", [])
	if heads.is_empty():
		return false
	var sheet_path := ViewKit.s(d.get("sheet", ""))
	if sheet_path != "":
		var st := ViewKit.tex(sheet_path)
		if st == null:
			return false
		_atlas = st
		for i in HEADS:
			var h: Dictionary = heads[i % heads.size()]
			var fr: Dictionary = h.get("frames", {})
			var r := _rect_of(fr.get("rest", null))
			_rest.append(r)
			_laugh.append(_rect_of(fr.get("laugh", fr.get("rest", null))))
			_lean.append(_rect_of(fr.get("lean", fr.get("rest", null))))
			_size.append(Vector2(float(h.get("w", r.size.x)), float(h.get("h", r.size.y))))
		return true
	# Paths per frame: blit into one image.
	var imgs: Array[Image] = []
	var keys: Array = []
	for i in mini(HEADS, heads.size()):
		var h2: Dictionary = heads[i]
		var fr2: Dictionary = h2.get("frames", {})
		for k in ["rest", "laugh", "lean"]:
			var p: Variant = fr2.get(k, fr2.get("rest", null))
			var img := _image_of(ViewKit.s(p) if p is String else "")
			if img == null:
				return false
			imgs.append(img)
			keys.append([i, k, Vector2(float(h2.get("w", img.get_width())), float(h2.get("h", img.get_height())))])
	var rects := _pack(imgs)
	if rects.is_empty():
		return false
	var n := heads.size()
	for i in HEADS:
		var src := i % mini(n, HEADS)
		_rest.append(rects[src * 3])
		_laugh.append(rects[src * 3 + 1])
		_lean.append(rects[src * 3 + 2])
		_size.append(keys[src * 3][2])
	return true


func _rect_of(v: Variant) -> Rect2:
	if v is Array and (v as Array).size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2(0, 0, 64, 64)


func _image_of(path: String) -> Image:
	if path == "":
		return null
	var t := ViewKit.tex(path)
	if t == null:
		return null
	var img := t.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# Keep layout in 1× px: scale down hi-res rasters to the texture's reported size.
	var sz := t.get_size()
	if img.get_width() != int(sz.x) and sz.x > 0.0:
		img.resize(int(sz.x), int(sz.y), Image.INTERPOLATE_BILINEAR)
	return img


## Shelf-pack images into one atlas texture; returns their rects (empty on failure).
func _pack(imgs: Array[Image]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := 1024
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
		_size.append(cell)


## One silhouette (flat #FFFFFF, tinted at draw time) in a 120 × 130 cell; the head sits on
## shoulders at the bottom.
static func _head_svg(i: int, cx: float, top: float) -> String:
	var b := top + 130.0
	var s := "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' fill='#FFFFFF'/>" % [cx - 58, b, cx - 50, b - 34, cx + 50, b - 34, cx + 58, b]
	var hr := 22.0 + float((i * 7) % 5) * 2.0
	var hy := b - 40.0 - hr
	s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx, hy, hr]
	match i % 8:
		0:  # bowler
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='6' fill='#FFFFFF'/>" % [cx, hy - hr * 0.55, hr * 1.35]
			s += "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' fill='#FFFFFF'/>" % [cx - hr * 0.85, hy - hr * 0.5, cx - hr * 0.8, hy - hr * 1.9, cx + hr * 0.8, hy - hr * 1.9, cx + hr * 0.85, hy - hr * 0.5]
		1:  # beehive
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='%.1f' fill='#FFFFFF'/>" % [cx, hy - hr * 1.3, hr * 0.85, hr * 1.25]
		2:  # shiny bald head (highlight drawn by the lighter inner disc at runtime? keep a notch)
			s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx, hy - 3, hr + 3]
		3:  # top hat
			s += "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' fill='#FFFFFF'/>" % [cx - hr * 0.7, hy - hr * 2.4, hr * 1.4, hr * 1.9]
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='5' fill='#FFFFFF'/>" % [cx, hy - hr * 0.55, hr * 1.3]
		4:  # feathered hat
			s += "<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='%.1f' fill='#FFFFFF'/>" % [cx, hy - hr * 0.7, hr * 1.2, hr * 0.5]
			s += "<path d='M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' fill='none' stroke='#FFFFFF' stroke-width='7' stroke-linecap='round'/>" % [cx + hr * 0.4, hy - hr, cx + hr * 1.2, hy - hr * 2.2, cx + hr * 1.8, hy - hr * 2.0, cx + hr * 2.0, hy - hr * 2.6]
		5:  # curlers
			for k in 4:
				s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx - hr * 0.75 + float(k) * hr * 0.5, hy - hr * 0.9, hr * 0.3]
		6:  # toddler on a shoulder
			s += "<circle cx='%.1f' cy='%.1f' r='%.1f' fill='#FFFFFF'/>" % [cx + hr * 0.5, hy - hr * 1.9, hr * 0.62]
			s += "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' rx='6' fill='#FFFFFF'/>" % [cx + hr * 0.05, hy - hr * 1.4, hr * 0.9, hr * 0.9]
		7:  # flat cap + bun
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
	var want_alpha := REST_ALPHA if _mode == "rest" else 1.0
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


## Upward rise (px, positive = up) this head wants right now.
func _target_rise(i: int) -> float:
	var ph := _phase[i]
	var u := clampf(_t / maxf(0.01, _dur), 0.0, 1.0)
	var env := sin(u * PI) if u < 1.0 else 0.0
	var m := 0.6 if reduce_motion else 1.0
	match _mode:
		"laugh":
			match _tier:
				0:
					return 6.0 * env if i == _nudge_a or i == _nudge_a + 1 else 0.0
				1:
					return absf(sin(_t * TAU * 3.0 + ph)) * 9.0 * env * m
				2:
					return (8.0 + absf(sin(_t * TAU * 4.0 + ph)) * 16.0) * env * m
				3:
					return (60.0 * minf(1.0, _t * 4.0) + absf(sin(_t * TAU * 4.0 + ph)) * 14.0) * (1.0 if u < 0.8 else env * 2.0) * m
				4:
					if i == _tumble:
						return -140.0 * minf(1.0, _tumble_t * 1.2) + 60.0 * maxf(0.0, 1.0 - _tumble_t * 3.0)
					return (82.0 + (float(i % 3) * 8.0) + absf(sin(_t * TAU * 3.2 + ph)) * 22.0) * (1.0 if u < 0.85 else env * 3.0) * m
		"gasp":
			return 16.0 * (1.0 if _t < 0.45 else env)
		"behind_you":
			return 42.0 * env if i % 3 == 0 else 8.0 * env
		"chant":
			return absf(sin(_t * TAU * 2.0)) * 18.0 * env
		"ooh":
			return 10.0 * env
		"aww":
			return -8.0 * env
		"boo":
			return 6.0 * env
	if i == _tumble and _tumble_t < 5.0:
		return -140.0 * minf(1.0, _tumble_t * 1.2)
	return 0.0


func _target_rot(i: int) -> float:
	var u := clampf(_t / maxf(0.01, _dur), 0.0, 1.0)
	var env := sin(u * PI) if u < 1.0 else 0.0
	if i == _tumble:
		return _tumble_t * 9.0
	match _mode:
		"laugh":
			if _tier == 0 and (i == _nudge_a or i == _nudge_a + 1):
				return (0.25 if i == _nudge_a else -0.25) * env
			if _tier >= 2:
				return -0.18 * env * sin(_t * 6.0 + _phase[i])
		"shush":
			var cx := view_size().x * 0.5
			return (0.2 if _x[i] < cx else -0.2) * env
		"boo":
			return -0.15 * env
		"aww":
			return 0.1 * env * (1.0 if i % 2 == 0 else -1.0)
	return 0.0


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
			var sz := _size[i]
			var sc := 0.62 if pass_row == 1 else 0.8
			var src := _rest[i]
			if _mode == "laugh" and _tier >= 2:
				src = _laugh[i]
			elif _mode == "shush" or (_mode == "laugh" and _tier == 0):
				src = _lean[i]
			var rise := REST_PX + (-_y[i])
			var col := Color(FILL.lightened(0.12 if pass_row == 1 else 0.0), _alpha * (0.8 if pass_row == 1 else 1.0))
			var feet := Vector2(_x[i], bottom - rise + sz.y * sc)
			draw_set_transform(feet, _rot[i], Vector2(sc, sc))
			draw_texture_rect_region(_atlas, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), src, col)
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
