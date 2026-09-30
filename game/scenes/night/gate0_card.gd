## Gate0Card — the 3-icon card before "Gate 0: the Sneeze" (s2-night §4.1, ruling L8): on the red
## curtain, three big panels in a row — tap the honey → hold RIG → hide in the pantry — each with its
## icon and a 3-word label (`stage_door.gate0_card_*`), numbered, joined by arrows. It shows for
## SHOW_S or until tapped (a tap in the first MIN_S is ignored so a stray thumb never skips it), then
## `closed` fires and the curtain rises on the kitchen. Everything is drawn in one `_draw()`.
## **3D view** (R3D): the icons are the 3D game's own pieces — the honey jar and the pantry curtain rendered live as
## glowing Prop3D thumbnails (a small own-world SubViewport each), and the middle step is the LIVE RIG action button
## (gold disc, the rig glove, its ring filling as if held).
class_name Gate0Card
extends Control

signal closed()

const SHOW_S := 2.5
const MIN_S := 0.35
const PANEL := Vector2(420, 460)
const GAP := 120.0
const ICON := 220.0
## (icon card key, string key) per step.
const STEPS := [["fixup_honey", "stage_door.gate0_card_honey"], ["hold", "stage_door.gate0_card_hold"],
	["hide", "stage_door.gate0_card_hide"]]

var age: float = 0.0
## Test hook: no automatic close.
var auto_close: bool = true
## 3D icons (the honey / pantry thumbnails and the LIVE RIG button).
var icons3d: bool = false
var thumbs: Array[SubViewport] = []

var _icons: Array[Texture2D] = []
var _labels := PackedStringArray()
var _arrow: Texture2D = null
var _curtain: Texture2D = null
var _closed: bool = false
var _down: int = -1


func _init() -> void:
	name = "Gate0Card"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	icons3d = BootConfig.view() != "2d" and ResourceLoader.exists("res://view3d/set/prop_3d.gd")
	for s in STEPS:
		_icons.append(UiIcons.card(String(s[0])))
		_labels.append(UiStrings.t(String(s[1])))
	if icons3d:
		var hj: Variant = ViewKit.json("res://data/house/house3d.json")
		var hs: Dictionary = (hj as Dictionary).get("hotspots", {}) if hj is Dictionary else {}
		var honey := _thumb("kitchen_honey", hs, "rig", Vector3(0.0, 0.22, 0.0), 1.05)
		var pantry := _thumb("kitchen_pantry_curtain", hs, "hide", Vector3(0.0, 1.0, 0.0), 3.6)
		if honey != null:
			_icons[0] = honey
		if pantry != null:
			_icons[2] = pantry
		_icons[1] = UiIcons.get_icon(&"rig")
	_arrow = UiIcons.get_icon(&"arrow")
	if ResourceLoader.exists(NightCurtain.ART):
		_curtain = load(NightCurtain.ART) as Texture2D


func _process(delta: float) -> void:
	age += delta
	if auto_close and age >= SHOW_S:
		close()
	queue_redraw()


## A live 3D thumbnail of a hotspot's prop (glowing in its verb colour), or null.
func _thumb(id: String, hotspots: Dictionary, verb: String, aim: Vector3, dist: float) -> Texture2D:
	var e: Variant = hotspots.get(id, null)
	if not (e is Dictionary):
		return null
	var vp := SubViewport.new()
	vp.name = "Thumb_" + id
	vp.size = Vector2i(320, 320)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p := Prop3D.new()
	p.setup(id, e, Transform3D.IDENTITY, "kitchen", verb, true)
	vp.add_child(p)
	p.set_glow(Prop3D.verb_color(verb), 1.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var s := float((e as Dictionary).get("scale", 1.0))
	cam.look_at_from_position(aim * s + Vector3(0.35, 0.15, dist), aim * s, Vector3.UP)
	cam.current = true
	thumbs.append(vp)
	return vp.get_texture()


## Close (once).
func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()


func is_closed() -> bool:
	return _closed


## A tap (touch-up) — ignored during the first MIN_S.
func tap() -> void:
	if age >= MIN_S:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.pressed:
			_down = st.index
		elif st.index == _down:
			_down = -1
			tap()
	elif event is InputEventMouse or event is InputEventScreenDrag:
		accept_event()


## The three panel rects (screen px) for a view of `vs`.
static func panel_rects(vs: Vector2) -> Array[Rect2]:
	var total := PANEL.x * 3.0 + GAP * 2.0
	var x := (vs.x - total) * 0.5
	var y := (vs.y - PANEL.y) * 0.5 + 20.0
	var out: Array[Rect2] = []
	for i in 3:
		out.append(Rect2(x + float(i) * (PANEL.x + GAP), y, PANEL.x, PANEL.y))
	return out


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	if _curtain != null:
		var ts := _curtain.get_size()
		var tw := ts.x * (vs.y / maxf(1.0, ts.y))
		var x := 0.0
		while x < vs.x:
			draw_texture_rect(_curtain, Rect2(x, 0, tw, vs.y), false)
			x += tw
	else:
		draw_rect(Rect2(Vector2.ZERO, vs), UiKit.CURTAIN)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(UiKit.NAVY, 0.35))
	var rects := panel_rects(vs)
	var df := UiKit.display_font()
	for i in 3:
		# each panel pops in 0.12 s after the previous one
		var k := clampf((age - float(i) * 0.12) / 0.22, 0.0, 1.0)
		if UiKit.reduce_motion():
			k = 1.0
		if k <= 0.0:
			continue
		var r := rects[i]
		var c := r.get_center()
		var e := 1.0 + 0.12 * sin(k * PI) if k < 1.0 else 1.0
		draw_set_transform(c, 0.0, Vector2(e, e) * lerpf(0.7, 1.0, k))
		var lr := Rect2(-r.size * 0.5, r.size)
		UiKit.draw_chunky_rect(self, lr, 36.0, UiKit.CREAM, UiKit.CREAM_SHADE, UiKit.BUTTON_OUTLINE, 14.0)
		# the step number
		UiKit.draw_disc(self, lr.position + Vector2(52, 52), 40.0, UiKit.CHERRY, UiKit.CHERRY_SHADE)
		UiKit.draw_text_centered(self, df, lr.position + Vector2(52, 48), str(i + 1), UiKit.SIZE_BANNER, UiKit.CREAM, 0)
		if icons3d and i == 1:
			_draw_live_rig(Vector2(0, -50.0))
		elif i < _icons.size() and _icons[i] != null:
			UiKit.draw_icon(self, _icons[i], Rect2(Vector2(-ICON * 0.5, -ICON * 0.5 - 50.0), Vector2(ICON, ICON)))
		if i < _labels.size():
			var fs := ScriptPanel.fit_size(df, _labels[i], r.size.x - 40.0, UiKit.SIZE_BANNER)
			UiKit.draw_text_centered(self, df, Vector2(0, lr.end.y - 80.0), _labels[i], fs, UiKit.NAVY, 0)
		draw_set_transform(Vector2.ZERO)
		if i < 2 and _arrow != null and k >= 1.0:
			var ac := Vector2(r.end.x + GAP * 0.5, c.y)
			UiKit.draw_icon(self, _arrow, Rect2(ac - Vector2(44, 44), Vector2(88, 88)), UiKit.GOLD_LIGHT)
	# the countdown bar under the panels
	var bar := Rect2(rects[0].position.x, rects[0].end.y + 48.0, rects[2].end.x - rects[0].position.x, 14.0)
	draw_rect(bar, Color(UiKit.NAVY, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(age / SHOW_S, 0.0, 1.0), bar.size.y)), UiKit.GOLD_LIGHT)


## The LIVE RIG action button (REDESIGN §2.4): a gold disc, the rig glove, the 14 px ring filling as if held.
func _draw_live_rig(c: Vector2) -> void:
	var r := 95.0
	UiKit.draw_disc(self, c, r, UiKit.GOLD, UiKit.GOLD_SHADE)
	if _icons.size() > 1 and _icons[1] != null:
		UiKit.draw_icon(self, _icons[1], Rect2(c - Vector2(52, 52), Vector2(104, 104)), UiKit.NAVY)
	var fr := fposmod(age / 1.2, 1.0)
	draw_arc(c, r + 16.0, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 18.0, true)
	UiKit.draw_ring(self, c, r + 16.0, fr, 14.0, UiKit.YELLOW.lerp(UiKit.GREEN, fr))
