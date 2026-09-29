## Cast — the stage door's live cast sheet (Gate 0 G3; s2-night §4.1): the real RigPlayers in the
## engine at phone scale — Hush (with a Hush / Pip skin toggle), Bellows, Figgis — and the Stalls, side
## by side on the stage floor. "Next" cycles every actor through idle → snicker → freeze → take (each
## rig's own clip for that beat when it exists; the rig's rest pose and the clip id otherwise). Back
## returns to the stage door.
class_name CastPage
extends Control

const BEATS: PackedStringArray = ["idle", "snicker", "freeze", "take"]
## rig → the clip per beat.
const CLIPS := {
	"hush": ["hush/loco_idle", "hush/act_snicker", "hush/freeze_1", "hush/st_near_miss"],
	"bellows": ["bellows/loco_idle", "bellows/act_tea", "bellows/st_spotted", "bellows/rx_sneeze_blast_a"],
	"figgis": ["figgis/f_idle", "figgis/f_psst", "figgis/f_shh", "figgis/f_proud"],
}
const RIGS: PackedStringArray = ["hush", "bellows", "figgis"]
const STALL_TIERS := [0, 1, 3, 4]
## The cast at a size that reads on a phone (world px × this).
const ACTOR_SCALE := 1.45

var beat: int = 0
var skin: String = ""
var players: Dictionary = {}          ## rig → RigPlayer (or a FallbackPuppet)
var stalls: StallsView = null
var buttons: Dictionary = {}
var _labels: Dictionary = {}
var _stalls_layer: CanvasLayer = null


func _init() -> void:
	name = "Cast"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()


func _ready() -> void:
	skin = String(ViewKit.setting("hush_skin", ""))
	_build()
	resized.connect(_layout)
	_layout()
	set_beat(0)


func _build() -> void:
	for id in RIGS:
		var n: Node2D = null
		if FileAccess.file_exists("res://data/rigs/%s/rig.json" % id) or ResourceLoader.exists("res://data/rigs/%s/rig.json" % id):
			var rp := RigPlayer.new()
			rp.name = "Rig_" + id
			add_child(rp)
			rp.setup(id, skin if id == "hush" else "")
			n = rp
		else:
			var fp := FallbackPuppet.new()
			fp.kind = id
			add_child(fp)
			n = fp
		players[id] = n
		var l := Label.new()
		l.add_theme_font_override("font", UiKit.ui_font())
		l.add_theme_font_size_override("font_size", UiKit.SIZE_MIN)
		l.add_theme_color_override("font_color", UiKit.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		_labels[id] = l
	_stalls_layer = CanvasLayer.new()
	_stalls_layer.layer = 1
	add_child(_stalls_layer)
	stalls = StallsView.new()
	_stalls_layer.add_child(stalls)
	for spec in [["next", "stage_door.cast_next", UiKit.GOLD, UiKit.GOLD_SHADE], ["skin", "stage_door.cast_skin",
			UiKit.CREAM, UiKit.CREAM_SHADE], ["back", "stage_door.back", UiKit.CREAM, UiKit.CREAM_SHADE]]:
		var b := UiButton.make(UiStrings.t(String(spec[1])), Vector2(360, 144), spec[2], spec[3])
		b.name = "Btn_" + String(spec[0])
		b.pressed.connect(press.bind(String(spec[0])))
		add_child(b)
		buttons[String(spec[0])] = b


func _layout() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	var floor_y := vs.y * 0.74
	var xs := [0.2, 0.48, 0.76]
	for i in RIGS.size():
		var n: Node2D = players[RIGS[i]]
		n.position = Vector2(vs.x * float(xs[i]), floor_y)
		n.scale = Vector2.ONE * (ACTOR_SCALE * (1.6 if RIGS[i] == "figgis" else 1.0))
		var l: Label = _labels[RIGS[i]]
		l.position = Vector2(vs.x * float(xs[i]) - 300.0, floor_y + 20.0)
		l.size = Vector2(600, 60)
	var by := 40.0
	var bx := vs.x - 48.0
	for id in ["next", "skin", "back"]:
		var b: UiButton = buttons[id]
		bx -= b.size.x
		b.position = Vector2(bx, by)
		bx -= 24.0


## next | skin | back
func press(id: String) -> void:
	match id:
		"next":
			set_beat((beat + 1) % BEATS.size())
		"skin":
			skin = "" if skin == "pip" else "pip"
			var s := ViewKit.autoload("Settings")
			if s != null and s.has_method("set_value"):
				s.call("set_value", "hush_skin", skin)
			var h: Variant = players.get("hush")
			if h is RigPlayer:
				(h as RigPlayer).setup("hush", skin)
			set_beat(beat)
		"back":
			get_tree().change_scene_to_file(StageDoor.SCENE)


## Show beat `i` on every actor.
func set_beat(i: int) -> void:
	beat = i
	for id in RIGS:
		var clip := String((CLIPS[id] as Array)[i])
		var n: Variant = players[id]
		var ok := ClipMap.clip_exists(clip)
		if n is RigPlayer and ok:
			(n as RigPlayer).play(clip, {"loop": true, "blend_in": 4})
		elif n is FallbackPuppet:
			(n as FallbackPuppet).pose = ["stand", "step", "freeze", "shock"][i]
		(_labels[id] as Label).text = "%s · %s%s" % [id, BEATS[i], "" if ok else " (%s)" % clip.get_file()]
	if stalls != null:
		stalls.react(int(STALL_TIERS[i]))


func handle_back() -> bool:
	press("back")
	return true


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	draw_rect(Rect2(Vector2.ZERO, vs), Color("#3A2A4A"))
	draw_rect(Rect2(0, vs.y * 0.74, vs.x, vs.y * 0.26), Color("#5A3A2A"))
	draw_rect(Rect2(0, vs.y * 0.74, vs.x, 8), UiKit.GOLD_SHADE)
	UiKit.draw_text_centered(self, UiKit.display_font(), Vector2(260.0, 110.0), UiStrings.t("stage_door.cast"),
		UiKit.SIZE_TITLE, UiKit.GOLD_LIGHT, 16)
