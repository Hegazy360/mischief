## FxArt — texture lookup for every FX sprite, with fallbacks so the view never shows a hole.
## Real art first (ui's glyphs/badges in `res://art/ui/`, art-house's activity icons in
## `res://art/icons/activities/`), then the view's own sprites in `res://art/fx/`, then a
## white square. Everything is cached (ViewKit.tex).
class_name FxArt
extends RefCounted

const FX := "res://art/fx"
const UI := "res://art/ui"
## Particle kind → sprite file (res://art/fx/particles/<file>.svg).
const PARTICLE_FILES := {"dust": "dust", "flour": "flour", "feathers": "feather", "drops": "drop",
	"steam": "steam", "sparkles": "sparkle", "notes": "note", "roses": "rose"}
## Badge kind → ui file (badge_<name>.svg) and the view's fallback.
const BADGE_FILES := {"gold": "badge_gold", "blue": "badge_hide", "red": "badge_in_use", "grey": "badge_needs"}
## Prop-name aliases used by content (quake / T3 props).
const PROP_ALIAS := {"portrait": "picture_frame", "pans": "pan", "hats": "hat"}
const GLYPHS: PackedStringArray = ["specs_off", "specs_on", "blinded", "asleep", "stars"]

static var _white: Texture2D = null


static func particle(kind: String) -> Texture2D:
	var f := String(PARTICLE_FILES.get(kind, "flour"))
	return _first(["%s/particles/%s.svg" % [FX, f]])


## Awareness glyph (48 px): specs_off, specs_on, blinded, asleep, stars.
static func glyph(id: String) -> Texture2D:
	var g := id if GLYPHS.has(id) else "specs_off"
	return _first(["%s/glyph_%s.svg" % [UI, g], "%s/glyphs/%s.svg" % [UI, g], "%s/fallback/glyph_%s.svg" % [FX, g]])


## Hotspot badge (56 px): gold, blue, red, grey.
static func badge(kind: String) -> Texture2D:
	var ui_name := String(BADGE_FILES.get(kind, "badge_gold"))
	return _first(["%s/%s.svg" % [UI, ui_name], "%s/badges/%s.svg" % [UI, kind], "%s/fallback/badge_%s.svg" % [FX, kind]])


## Activity / detour icon (88 px) from a path (bubble.icon) or an id.
static func activity_icon(path_or_id: String) -> Texture2D:
	if path_or_id == "":
		return _first(["%s/fallback/icon_generic.svg" % FX])
	var p := path_or_id if path_or_id.begins_with("res://") else ViewSnapshot.icon_for(path_or_id)
	return _first([p, "%s/fallback/icon_generic.svg" % FX])


## Falling / quake prop sprite (picture_frame, vase, hat, sausage, pan, onion, door_handle).
static func prop(name: String) -> Texture2D:
	var n := String(PROP_ALIAS.get(name, name))
	return _first(["%s/props/%s.svg" % [FX, n], "%s/props/picture_frame.svg" % FX])


## Any file under res://art/fx (e.g. "thought_bubble", "caption_burst", "dot").
static func sprite(name: String) -> Texture2D:
	return _first(["%s/%s.svg" % [FX, name], "%s/fallback/%s.svg" % [FX, name]])


## An 8 × 8 white texture (tinted rects that should batch with sprites).
static func white() -> Texture2D:
	if _white == null:
		var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


static func _first(paths: Array) -> Texture2D:
	for p in paths:
		var t := ViewKit.tex(String(p))
		if t != null:
			return t
	return white()
