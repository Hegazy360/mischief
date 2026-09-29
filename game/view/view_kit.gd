## ViewKit — small shared helpers for every view class (soft hooks, settings, textures,
## fonts, frame-rate-independent damping). Static only; no state beyond caches.
##
## Soft hooks (TECH §13): modules built in parallel (sim, rig, ui, audio) are reached through
## `soft_script(path)` / `autoload(name)` + `has_method`, never through their class names, so
## the view parses and runs whether or not they exist yet.
class_name ViewKit
extends RefCounted

const HIRES_PATH := "res://view/tex/hi_res_tex.gd"
const UI_STRINGS := "res://ui/theme/ui_strings.gd"
const FONT_DIRS: PackedStringArray = ["res://ui/theme/fonts", "res://ui/fonts"]
const DISPLAY_FONT_NAMES: PackedStringArray = ["LilitaOne-Regular.ttf", "LilitaOne.ttf", "lilita_one.ttf"]
const UI_FONT_NAMES: PackedStringArray = ["Nunito-ExtraBold.ttf", "NunitoExtraBold.ttf", "nunito_extrabold.ttf"]
## Ink navy used for every outline over the world (GDD §3.10).
const INK := Color("#1B2340")
const CREAM := Color("#FFF4E0")

static var _tex_cache: Dictionary = {}
static var _script_cache: Dictionary = {}
static var _json_cache: Dictionary = {}
static var _words: Dictionary = {}
static var _display_font: Font = null
static var _ui_font: Font = null


## The script at `path` when it exists and compiles, else null (cached).
static func soft_script(path: String) -> Script:
	if _script_cache.has(path):
		return _script_cache[path]
	var s: Script = null
	if ResourceLoader.exists(path):
		s = load(path) as Script
		if s != null and not s.can_instantiate():
			s = null
	_script_cache[path] = s
	return s


## Autoload node by name (null outside a SceneTree or when not registered).
static func autoload(n: String) -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(n)
	return null


## Settings value with a default when the Settings autoload (owner `ui`) is absent.
static func setting(key: String, def: Variant) -> Variant:
	var s := autoload("Settings")
	if s != null and s.has_method("get_value"):
		var v: Variant = s.call("get_value", key, def)
		return def if v == null else v
	return def


## Parsed JSON file (cached), or null when missing / invalid.
static func json(path: String) -> Variant:
	if _json_cache.has(path):
		return _json_cache[path]
	var out: Variant = null
	if FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK:
			out = j.data
		else:
			push_warning("ViewKit.json: %s:%d %s" % [path, j.get_error_line(), j.get_error_message()])
	_json_cache[path] = out
	return out


## Forget cached JSON (tests / hot reload).
static func clear_json_cache() -> void:
	_json_cache.clear()


## Player-facing words (s2-ui `fx.*` keys, UiStrings): the string for `key` when the key
## exists, else `fallback` (brief §4.2.17: today's literal until the key lands). Cached.
static func word(key: String, fallback: String) -> String:
	if _words.has(key):
		return _words[key]
	var out := fallback
	var us := soft_script(UI_STRINGS)
	if us != null and us.has_method("has") and bool(us.call("has", key)):
		out = ViewKit.s(us.call("t", key), fallback)
	_words[key] = out
	return out


## Art scale of everything in a room that is not in tonight's episode (the unlit set, dimmed to
## ≈ 30 %) and of the far background flats: 1× (s2-fix G #7 — texture memory; on a 1080p-tall
## phone 1× is one texel per pixel at the play zoom).
const LOCKED_SCALE := 1.0
## "No art at all" (a room no camera can frame tonight; WorldView.room_art_scales).
const NO_ART := -3.0
## Art that is always drawn at or below its 1× size gains nothing at 2× (s2-fix G #7): the
## Prologue's title card (1500 px art drawn 1120 px wide in the 2400-px logical view) and its bulb
## layers — 72 MB at 2×, 18 MB at 1×. tex() serves these paths at the given scale.
## The same for soft art that gains nothing above 1× or ½×: the red Busted-Cam vignette (a blur,
## drawn full screen), the additive footlight and door glows.
const PATH_SCALES := {"res://art/house/stage/title_card*.svg": 1.0, "res://art/fx/vignette_*.svg": 0.5,
	"res://art/house/stage/footlight_glow.svg": 1.0, "res://art/house/stage/front_door_glow.svg": 1.0}


## The art scale tex() serves `path` at: its PATH_SCALES entry, else −1 (ART_SCALE).
static func art_scale_of(path: String) -> float:
	for g in PATH_SCALES:
		if path.match(String(g)):
			return float(PATH_SCALES[g])
	return -1.0


## Texture for an art path at an explicit art `scale` (≤ 0: ART_SCALE, i.e. tex()). Cached per
## (path, scale).
static func tex_at(path: String, scale: float) -> Texture2D:
	if scale <= 0.0:
		return tex(path)
	if path == "":
		return null
	var k := "%s@%s" % [path, snappedf(scale, 0.001)]
	if _tex_cache.has(k):
		return _tex_cache[k]
	var t: Texture2D = null
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var hs := soft_script(HIRES_PATH)
		if hs != null and hs.has_method("get_texture"):
			var v: Variant = hs.call("get_texture", path, {}, scale)
			if v is Texture2D:
				t = v
		if t == null and ResourceLoader.exists(path):
			t = load(path) as Texture2D
	_tex_cache[k] = t
	return t


## Drop the texture cache and let HiResTex free every raster no node holds any more (NightScene
## calls it before it builds, so the previous Night's art does not stay in memory). Returns how
## many HiResTex entries were freed.
static func release_textures() -> int:
	for k in _tex_cache.keys():
		if not String(k).begins_with("svg:"):
			_tex_cache.erase(k)
	var hs := soft_script(HIRES_PATH)
	if hs != null and hs.has_method("trim"):
		return int(hs.call("trim"))
	return 0


## Texture for an art path: HiResTex (owner `rig`, soft) at ART_SCALE with a 1× size
## override when it exists, else the imported texture; null when missing. Cached.
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	for g in PATH_SCALES:
		if path.match(String(g)):
			var ts := tex_at(path, float(PATH_SCALES[g]))
			_tex_cache[path] = ts
			return ts
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var hs := soft_script(HIRES_PATH)
		if hs != null and hs.has_method("get_texture"):
			var v: Variant = hs.call("get_texture", path)
			if v is Texture2D:
				t = v
		if t == null:
			t = load(path) as Texture2D
	_tex_cache[path] = t
	return t


## Texture rasterised from SVG source text at `scale` (for built-in fallbacks). The size is
## overridden to the 1× size so layout stays in 1× px. Cached by `key`.
static func svg_tex(key: String, svg: String, scale: float = 2.0) -> Texture2D:
	var k := "svg:" + key
	if _tex_cache.has(k):
		return _tex_cache[k]
	var img := Image.new()
	var t: Texture2D = null
	var ts := soft_script("res://view/tex/tex_stats.gd")
	if ts != null and ts.has_method("note_build"):
		ts.call("note_build", "fx")
	if img.load_svg_from_string(svg, scale) == OK:
		var it := ImageTexture.create_from_image(img)
		it.set_size_override(Vector2i(int(round(img.get_width() / scale)), int(round(img.get_height() / scale))))
		t = it
		if ts != null and ts.has_method("track_image"):
			ts.call("track_image", it, img, "fx", "fx:" + key)
	else:
		var f := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		f.fill(Color.WHITE)
		t = ImageTexture.create_from_image(f)
	_tex_cache[k] = t
	return t


## Lilita One (display font, owner `ui`) or the engine fallback font.
static func display_font() -> Font:
	if _display_font == null:
		_display_font = _find_font(DISPLAY_FONT_NAMES, "lilita")
	return _display_font


## Nunito ExtraBold (UI font, owner `ui`) or the engine fallback font.
static func ui_font() -> Font:
	if _ui_font == null:
		_ui_font = _find_font(UI_FONT_NAMES, "nunito")
	return _ui_font


static func _find_font(names: PackedStringArray, needle: String) -> Font:
	for d in FONT_DIRS:
		for n in names:
			var p := "%s/%s" % [d, n]
			if ResourceLoader.exists(p):
				var f := load(p) as Font
				if f != null:
					return f
		var da := DirAccess.open(d)
		if da == null:
			continue
		for fname in da.get_files():
			var clean := fname.trim_suffix(".import").trim_suffix(".remap")
			var low := clean.to_lower()
			if low.contains(needle) and (low.ends_with(".ttf") or low.ends_with(".otf")):
				var p2 := "%s/%s" % [d, clean]
				if ResourceLoader.exists(p2):
					var f2 := load(p2) as Font
					if f2 != null:
						return f2
	return ThemeDB.fallback_font


## Exponential smoothing factor for time constant `tau` over `dt` (frame-rate independent).
static func damp(dt: float, tau: float) -> float:
	if tau <= 0.0:
		return 1.0
	return 1.0 - exp(-maxf(0.0, dt) / tau)


## First-order-hold exponential follow: exact for a target moving linearly between
## `target_old` and `target_new` over `dt`, so 30 and 60 fps give the same path (TECH §5.5).
## Jumps larger than `max_jump` are treated as a step (zero-order hold).
static func follow_exp(x: float, target_old: float, target_new: float, dt: float, tau: float, max_jump: float = 600.0) -> float:
	if dt <= 0.0:
		return x
	if tau <= 0.0:
		return target_new
	var a := exp(-dt / tau)
	var dtarget := target_new - target_old
	if absf(dtarget) > max_jump:
		return target_new + (x - target_new) * a
	var vtau := dtarget / dt * tau
	return target_new - vtau + (x - target_old + vtau) * a


## Smoothstep ease-in-out on [0, 1].
static func ease_in_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Cubic ease-out on [0, 1].
static func ease_out_cubic(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var v := 1.0 - u
	return 1.0 - v * v * v


## Back ease-out (one overshoot) on [0, 1].
static func ease_out_back(u: float, s: float = 1.70158) -> float:
	u = clampf(u, 0.0, 1.0) - 1.0
	return u * u * ((s + 1.0) * u + s) + 1.0


## Any Variant as a String (Godot 4 has no String(int) / String(bool) constructor);
## null → `def`.
static func s(v: Variant, def: String = "") -> String:
	match typeof(v):
		TYPE_NIL:
			return def
		TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_FLOAT:
			var f: float = v
			return str(int(f)) if f == floorf(f) else str(f)
	return str(v)


## Id string of a value that may be an interned int (sorted-id order, TECH §2) or a string.
static func id_of(v: Variant, sorted_ids: PackedStringArray) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
		TYPE_INT:
			var i := int(v)
			if i >= 0 and i < sorted_ids.size():
				return sorted_ids[i]
			return "" if i < 0 else str(i)
		TYPE_NIL:
			return ""
	return str(v)
