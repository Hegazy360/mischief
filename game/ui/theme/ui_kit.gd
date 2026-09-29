## UiKit — shared palette, type scale, fonts, soft autoload bridges and draw helpers for every
## Mischief Next Door HUD widget and panel.
##
## * Palette (GDD §9.1 / ui brief §3.1): cream, navy, cherry, brass, curtain red, stage gold.
## * Type scale (GDD §3.10): ≥ 36 px anywhere, 44 px for play text, 48–56 px HUD numbers,
##   80–96 px titles; 4–6 px navy outline on anything drawn over the world.
## * Fonts: Lilita One (display) and Nunito (UI), switched to MSDF rendering at first use so
##   scaled / popping text stays crisp and outlines are cheap.
## * Soft bridges to the Settings / Haptics / Audio autoloads: every call is a no-op when the
##   autoload is not registered (tests, demos), so widgets work in isolation.
## * `draw_*` helpers used from widgets' `_draw()` (no allocations beyond the engine's own).
class_name UiKit
extends RefCounted

const THEME_PATH := "res://ui/theme/theme.tres"
const FONT_DISPLAY_PATH := "res://ui/theme/fonts/LilitaOne-Regular.ttf"
const FONT_UI_PATH := "res://ui/theme/fonts/Nunito-ExtraBold.ttf"
const FONT_BLACK_PATH := "res://ui/theme/fonts/Nunito-Black.ttf"
const FONT_BOLD_PATH := "res://ui/theme/fonts/Nunito-Bold.ttf"

# --- palette ---------------------------------------------------------------------------------
const CREAM := Color("#FFF4E0")
const CREAM_SHADE := Color("#E9D6B4")
const NAVY := Color("#1B2340")
const NAVY_SOFT := Color("#2E3760")
const CHERRY := Color("#E23B4E")
const CHERRY_SHADE := Color("#B3243A")
const BRASS := Color("#D9A441")
const BRASS_SHADE := Color("#A8792A")
const BRASS_LIGHT := Color("#F2CF7E")
const CURTAIN := Color("#B3122E")
const CURTAIN_SHADE := Color("#7E0B20")
const GOLD := Color("#E8B33A")
const GOLD_SHADE := Color("#C08A1E")
const GOLD_LIGHT := Color("#FFE08A")
const YELLOW := Color("#FFD23F")
const GREEN := Color("#5CC94B")
const GREEN_SHADE := Color("#3E9E36")
const AMBER := Color("#FF9F1C")
const AMBER_SHADE := Color("#D07A08")
const RED := Color("#E8413C")
const RED_SHADE := Color("#B32A26")
const BLUE := Color("#3A7BD5")
const PLUM := Color("#2A1E3A")
const GREY := Color("#8C88A3")
const WHITE := Color("#FFFFFF")
## Panel paper (Script, cards) and its shade.
const PAPER := Color("#FFF4E0")
const PAPER_SHADE := Color("#EBD7B3")
## Dimmer behind modal panels.
const SCRIM := Color(0.106, 0.137, 0.251, 0.62)
## PiP frame / temper tiers (GDD §4.5): calm cream, irked pink, steaming red, livid beetroot.
const TIER_COLORS: Array[Color] = [Color("#FFF4E0"), Color("#FF9FB2"), Color("#F0512F"), Color("#9E1F45")]

# --- type scale (logical px at the 1080-high base) ------------------------------------------
const SIZE_MIN := 36
const SIZE_PLAY := 44
const SIZE_HUD_NUM := 56
const SIZE_HUD_NUM_S := 48
const SIZE_BANNER := 52
const SIZE_TITLE := 88
const SIZE_BIG_TITLE := 96
## Outline thickness (Godot outline_size, px) for text over the world / on panels.
const OUTLINE_WORLD := 12
const OUTLINE_PANEL := 0
## Chunky button outline (ui brief §3.1).
const BUTTON_OUTLINE := 6.0
## Pressed state: scale 0.94 + darker shade, applied in the same frame as the touch.
const PRESS_SCALE := 0.94
const PRESS_DARKEN := 0.16

# --- touch constants (touchux §1.1) ----------------------------------------------------------
const TOUCH_MIN := 144.0
const TOUCH_GAP := 24.0

## Test hook: when ≥ 0, `now_ms()` returns it instead of the real clock (widget timing tests).
static var now_override: int = -1

static var _fonts: Dictionary = {}
static var _theme: Theme = null


## Drop the static font / theme / stylebox caches (on quit, so nothing outlives the renderer).
static func clear_caches() -> void:
	_fonts.clear()
	_theme = null
	_sb_cache.clear()


## Real-time milliseconds used by every widget timer (verb hysteresis, tap vs hold …).
static func now_ms() -> int:
	return now_override if now_override >= 0 else Time.get_ticks_msec()
static var _args: PackedStringArray = PackedStringArray()
static var _args_loaded: bool = false


# --- fonts -----------------------------------------------------------------------------------

## A font by path, cached, switched to MSDF rendering (crisp at any scale, cheap outlines).
## Falls back to the engine default font when the file is missing.
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
		# The .ttf.import sidecars set multichannel_signed_distance_field=true (Stage 2), so the
		# flag switch is a no-op on imported fonts; the pixel range (24, for the 12 px world
		# outlines) and the glyph size stay runtime settings — set only when they differ.
		var ff := f as FontFile
		if ff != null:
			if ff.msdf_pixel_range != 24:
				ff.msdf_pixel_range = 24
			if ff.msdf_size != 64:
				ff.msdf_size = 64
			if not ff.multichannel_signed_distance_field:
				ff.multichannel_signed_distance_field = true
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[path] = f
	return f


## Lilita One — numbers, captions, titles.
static func display_font() -> Font:
	return font(FONT_DISPLAY_PATH)


## Nunito ExtraBold — UI text.
static func ui_font() -> Font:
	return font(FONT_UI_PATH)


## Nunito Black — emphasis inside UI text.
static func black_font() -> Font:
	return font(FONT_BLACK_PATH)


## The shared theme (res://ui/theme/theme.tres) with its fonts made MSDF; null if missing.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	if ResourceLoader.exists(THEME_PATH):
		_theme = load(THEME_PATH) as Theme
	if _theme == null:
		_theme = Theme.new()
	_theme.default_font = ui_font()
	_theme.default_font_size = SIZE_PLAY
	return _theme


## Test / demo hook: a text scale that wins over Settings (≤ 0 = use Settings).
static var text_scale_override: float = -1.0


## Text scale from Settings.text_scale (1.0 or 1.2 = "Text +20 %").
static func text_scale() -> float:
	if text_scale_override > 0.0:
		return clampf(text_scale_override, 1.0, 1.4)
	return clampf(float(setting("text_scale", 1.0)), 1.0, 1.4)


## `base` scaled by the text-size setting (never below SIZE_MIN).
static func text_size(base: int) -> int:
	return maxi(SIZE_MIN, int(round(float(base) * text_scale())))


# --- autoload bridges ------------------------------------------------------------------------

## /root/<name> or null.
static func autoload(autoload_name: String) -> Node:
	var t := Engine.get_main_loop() as SceneTree
	if t == null or t.root == null:
		return null
	return t.root.get_node_or_null(NodePath(autoload_name))


## Settings value (Settings autoload `get_value`), or `fallback` without the autoload.
static func setting(key: String, fallback: Variant) -> Variant:
	var s := autoload("Settings")
	if s != null and s.has_method("get_value"):
		return s.call("get_value", key, fallback)
	return fallback


## Named haptic pulse via the Haptics autoload (tap, ui, ring_half, rig_done, …); no-op without it.
static func haptic(kind: StringName) -> void:
	var h := autoload("Haptics")
	if h != null and h.has_method("pulse"):
		h.call("pulse", kind)


## UI sound via Audio.play_sfx (soft; missing ids are the Audio autoload's no-op).
static func sfx(id: String) -> void:
	var a := autoload("Audio")
	if a != null and a.has_method("play_sfx"):
		a.call("play_sfx", id)


## Reduce motion (Settings.reduce_motion or `--reduce-motion`).
static func reduce_motion() -> bool:
	return has_flag("--reduce-motion") or bool(setting("reduce_motion", false))


## Reduce flashing (Settings.reduce_flash or `--reduce-flash`).
static func reduce_flash() -> bool:
	return has_flag("--reduce-flash") or bool(setting("reduce_flash", false))


## True when `flag` is among the user command-line args (after `--`).
static func has_flag(flag: String) -> bool:
	return _cmdline().has(flag)


## Value of `--key=value` in the user args, or `fallback`.
static func flag_value(key: String, fallback: String = "") -> String:
	var prefix := key + "="
	for a in _cmdline():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


static func _cmdline() -> PackedStringArray:
	if not _args_loaded:
		_args = OS.get_cmdline_user_args()
		_args_loaded = true
	return _args


# --- colours ---------------------------------------------------------------------------------

## The pressed shade of a fill colour.
static func pressed(c: Color) -> Color:
	return c.darkened(PRESS_DARKEN)


## Temper tier (0 calm … 3 livid; 4+ = livid) → frame colour.
static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]


# --- drawing helpers (call from _draw) --------------------------------------------------------

## A chunky disc: navy outline ring, flat fill, one lower shade crescent.
static func draw_disc(ci: CanvasItem, center: Vector2, radius: float, fill: Color, shade: Color,
		outline: float = BUTTON_OUTLINE) -> void:
	ci.draw_circle(center, radius, NAVY)
	var r := radius - outline
	ci.draw_circle(center, r, shade)
	ci.draw_circle(center + Vector2(0, -r * 0.1), r * 0.9, fill)


## Draws `text` with a navy outline. `pos` is the baseline-left of the text box of `width`
## (-1 = natural); `align` a HorizontalAlignment.
static func draw_text(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, color: Color,
		outline: int = OUTLINE_WORLD, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, outline_color: Color = NAVY) -> void:
	if outline > 0:
		ci.draw_string_outline(f, pos, text, align, width, size, outline, outline_color)
	ci.draw_string(f, pos, text, align, width, size, color)


## Draws `text` centred on `center` (vertically by cap height).
static func draw_text_centered(ci: CanvasItem, f: Font, center: Vector2, text: String, size: int,
		color: Color, outline: int = OUTLINE_WORLD, outline_color: Color = NAVY) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var base := center.y + (asc - desc) * 0.5 - size * 0.06
	draw_text(ci, f, Vector2(center.x - w * 0.5, base), text, size, color, outline,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, outline_color)


## A texture fitted (keep aspect) into `rect`; returns false when `tex` is null.
static func draw_icon(ci: CanvasItem, tex: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	if tex == null:
		return false
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return false
	var k := minf(rect.size.x / ts.x, rect.size.y / ts.y)
	var s := ts * k
	ci.draw_texture_rect(tex, Rect2(rect.position + (rect.size - s) * 0.5, s), false, modulate)
	return true


## A rounded rectangle with a navy outline and a bottom shade strip (flat "chunky" card).
static func draw_chunky_rect(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, shade: Color,
		outline: float = BUTTON_OUTLINE, shade_px: float = 10.0) -> void:
	if outline > 0.0:
		_sb(NAVY, radius).draw(ci.get_canvas_item(), rect)
	var inner := rect.grow(-outline)
	var sbs := _sb(shade, maxf(0.0, radius - outline))
	sbs.draw(ci.get_canvas_item(), inner)
	if shade_px <= 0.0 and fill == shade:
		return
	var top := Rect2(inner.position, Vector2(inner.size.x, maxf(0.0, inner.size.y - shade_px)))
	var sbf := _sb(fill, maxf(0.0, radius - outline))
	sbf.draw(ci.get_canvas_item(), top)


static var _sb_cache: Dictionary = {}


## Cached flat StyleBox per (colour, radius) so _draw never allocates a new one.
static func _sb(c: Color, radius: float) -> StyleBoxFlat:
	var key := Vector4(c.r8 * 65536 + c.g8 * 256 + c.b8, c.a8, roundf(radius), 0)
	var sb: StyleBoxFlat = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(radius))
		sb.corner_detail = 10
		sb.anti_aliasing = true
		_sb_cache[key] = sb
	return sb


## An arc ring from 12 o'clock clockwise covering `frac` (0..1).
static func draw_ring(ci: CanvasItem, center: Vector2, radius: float, frac: float, width: float,
		color: Color) -> void:
	if frac <= 0.0:
		return
	var f := minf(frac, 1.0)
	var a0 := -PI * 0.5
	var pts := maxi(8, int(64.0 * f))
	ci.draw_arc(center, radius, a0, a0 + TAU * f, pts, color, width, true)


## A 5-point star polygon (for sparkles); `points` must hold 10 entries (reused buffer).
static func star_points(points: PackedVector2Array, center: Vector2, r_out: float, r_in: float,
		rot: float = -PI * 0.5) -> void:
	for i in 10:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + float(i) * PI / 5.0
		points[i] = center + Vector2(cos(a), sin(a)) * r
