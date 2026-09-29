## OverviewButton — (W−S−168, T+300), 144 hit / 112 visual (GDD §3.8): the one-finger zoom toggle
## 1.0 ↔ 0.5. `set_overview(on)` swaps the icon (house-with-arrows ↔ magnifier "zoom back in").
## `tapped` → Hud.overview_tap.
class_name OverviewButton
extends HudButton

var overview_on: bool = false


func _ready() -> void:
	super()
	_refresh()


## Show the "back to 1.0" icon while the overview is on.
func set_overview(on: bool) -> void:
	if on == overview_on:
		return
	overview_on = on
	_refresh()


func _refresh() -> void:
	set_icon(UiIcons.get_icon(&"overview_back" if overview_on else &"overview"))
