## CaptureStub — a two-scene stand-in for the real game under capture.sh (s2-rig §4.1.6),
## until the Boot → NightScene e2e route is there: scene 1 ("curtain") plays two game sounds
## through the Audio autoload at known frames, then changes the CURRENT scene (like Boot →
## Router → NightScene); scene 2 plays a mannequin take whose clip sfx go through the Audio
## autoload too (the game's own mix, as the view's AudioDirector would). The capture's
## `_sync.json` must show every sound within ± 1 f of its logged frame.
##   CAPTURE_SANDBOX=<sb> tools/scripts/capture.sh res://scenes/dev/CaptureStub.tscn 200 out.gif
extends Node2D

const SELF := "res://scenes/dev/CaptureStub.tscn"
## Scene-1 sounds: frame → Audio id.
const CURTAIN_SFX := {12: "card_whoosh", 30: "boing_med"}
const CHANGE_AT := 45
## Clip sfx ids that are not in the game's sfx map play as this one.
const FALLBACK_SFX := "boing_small"

static var stage: int = 1

var _f: int = 0
var _rp: RigPlayer = null
var _label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#3B1F2B") if stage == 1 else Color("#2A2342"))
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 48)
	_label.position = Vector2(40, 30)
	add_child(_label)
	if stage == 2:
		_rp = RigPlayer.new()
		_rp.name = "Mannequin"
		_rp.manual = true
		_rp.position = get_viewport_rect().size * Vector2(0.5, 0.85)
		add_child(_rp)
		_rp.setup("_mannequin")
		_rp.clip_event.connect(_on_clip_event)
		_rp.play("_mannequin/rx_take", {"blend_in": 0})


func _process(delta: float) -> void:
	_label.text = "capture stub · scene %d · frame %d" % [stage, _f]
	if stage == 1:
		if CURTAIN_SFX.has(_f):
			_sfx(String(CURTAIN_SFX[_f]))
		if _f == CHANGE_AT:
			stage = 2
			get_tree().change_scene_to_file(SELF)
	elif _rp != null:
		_rp.advance(delta)
	_f += 1


func _on_clip_event(e: Dictionary) -> void:
	if String(e.get("type", "")) == "sfx":
		_sfx(String(e.get("id", "")))


func _sfx(id: String) -> void:
	var au := get_node_or_null("/root/Audio")
	if au == null:
		return
	au.call("play_sfx", id if au.call("has_sfx", id) else FALLBACK_SFX)
