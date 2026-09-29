## UiScale — the HUD scale factor (GDD §3.8): ×0.8 on tablets / foldables, whose logical
## height (base 1920×1080, canvas_items + expand) exceeds TABLET_HEIGHT; ×1.0 on every phone.
## Only the HUD scales — the world keeps zoom 1.0 so characters stay the same size relative to
## the screen height. Dev flag `--hud-scale=<f>` overrides (0.5..1.5).
class_name UiScale
extends RefCounted

const TABLET_HEIGHT := 1250.0
const TABLET_FACTOR := 0.8
const FLAG := "--hud-scale"


## Pure: the HUD factor for a logical viewport of `size`.
static func factor_for(size: Vector2) -> float:
	return TABLET_FACTOR if size.y > TABLET_HEIGHT else 1.0


## The factor for `vp` (the dev flag wins).
static func factor(vp: Viewport) -> float:
	var o := parse_override(OS.get_cmdline_user_args())
	if o > 0.0:
		return o
	if vp == null:
		return 1.0
	return factor_for(vp.get_visible_rect().size)


## Pure: `--hud-scale=<f>` or -1.0.
static func parse_override(args: PackedStringArray) -> float:
	var prefix := FLAG + "="
	for a in args:
		if a.begins_with(prefix):
			var s := a.substr(prefix.length())
			if s.is_valid_float():
				return clampf(s.to_float(), 0.5, 1.5)
	return -1.0
