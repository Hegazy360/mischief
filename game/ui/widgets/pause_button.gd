## PauseButton — top-left (S+24, T+24), 144 hit / 112 visual (GDD §3.8). `tapped` → Hud.pause_tap.
class_name PauseButton
extends HudButton


func _ready() -> void:
	super()
	set_icon(UiIcons.get_icon(&"pause"))
