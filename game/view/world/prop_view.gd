## PropView — one hotspot's prop on the set (TECH §5.4, GDD §3.5 / §5.1, STYLE §8): the state
## texture (`idle / open / rigged / rigged_<prank> / spent / occupied` from house.json `art`) drawn
## at scale 1 from `art_pos` (state canvases differ in size, so each state keeps its own canvas
## at the same top-left), its `front` overlay above the characters (the cheval mirror's empty
## frame while Hush stands in it), a HotspotView outline pulse (tinted per room: gold on the
## buttercream kitchen and the sage hall) while Hush shares the room, and the badge it wants
## (drawn in one batch by FxBadges). Spent rig points without `spent` art are greyed. Without art
## it draws a greybox prop inside the hit rect (counted by `WorldView.fallback_counts()`).
class_name PropView
extends Node2D

const SPENT_MODULATE := Color(0.62, 0.62, 0.66)
const BOX := Color("#C9A27A")
const WOOD := Color("#8A5A3A")
const METAL := Color("#9AA3B5")
const GOLDEN := Color("#E8B33A")
## Outline tint per room (STYLE §3 palette): flat white reads weakly on the pale walls, so the
## buttercream / sage / glass / mint rooms get the stage gold; the rest keep the cream.
const OUTLINE_TINT := {"kitchen": Color("#FFC93C"), "hall": Color("#FFC93C"), "conservatory": Color("#FFC93C"),
	"bathroom": Color("#FFC93C"), "porch": Color("#FFC93C"), "landing": Color("#FFF4E0"), "parlour": Color("#FFE08A"),
	"bedroom": Color("#FFF4E0"), "dressing": Color("#FFF4E0"), "garden": Color("#FFF4E0")}
const STATES: PackedStringArray = ["idle", "open", "rigged", "spent", "occupied", "outline", "front"]

var hotspot: HouseLayout.Hotspot = null
var layout: HouseLayout = null
var locked: bool = false
var sprite: Sprite2D = null
var front: Sprite2D = null
var highlight: HotspotView = null
## The current visual state (idle, open, rigged, rigged_<prank>, spent, occupied).
var state: String = "idle"
var _tex: Dictionary = {}
var _grey_rect := Rect2()


func _init() -> void:
	z_index = 0


## Build for `hs`. `front_parent` receives the `front` overlay (drawn above the characters).
func setup(hs: HouseLayout.Hotspot, h: HouseLayout, is_locked: bool, front_parent: Node2D = null) -> void:
	hotspot = hs
	layout = h
	locked = is_locked
	name = "Prop_" + hs.id
	for k in hs.art:
		var ks := ViewKit.s(k)
		var p: Variant = hs.art[k]
		if p is String and ViewKit.s(p) != "" and (STATES.has(ks) or ks.begins_with("rigged_")):
			var t := PropView._tex_for(ViewKit.s(p), 1.0 if ks == "outline" else hs.raster)
			if t != null:
				_tex[ks] = t
	_grey_rect = _greybox_rect()
	if _tex.has("idle"):
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture = _tex["idle"]
		sprite.position = _art_pos(_tex["idle"])
		add_child(sprite)
	if _tex.has("front") and front_parent != null:
		front = Sprite2D.new()
		front.centered = false
		front.texture = _tex["front"]
		front.position = sprite.position if sprite != null else _grey_rect.position
		front.visible = false
		front.name = "Front_" + hs.id
		front_parent.add_child(front)
	highlight = HotspotView.new()
	highlight.hotspot = hs
	highlight.tint = PropView.outline_tint(hs.room)
	if _tex.has("outline"):
		highlight.outline_tex = _tex["outline"]
		highlight.outline_scale = Vector2.ONE
		highlight.outline_pos = (sprite.position if sprite != null else _grey_rect.position) - Vector2(4, 4)
	highlight.prop_rect = Rect2(sprite.position, sprite.texture.get_size()) if sprite != null else _grey_rect
	add_child(highlight)
	if locked:
		modulate = RoomView.LOCKED_MODULATE
		if front != null:
			front.modulate = RoomView.LOCKED_MODULATE
	queue_redraw()


## The outline pulse colour for a room (art-house outline note).
static func outline_tint(room: String) -> Color:
	return OUTLINE_TINT.get(room, Color("#FFF4E0"))


static func _tex_for(path: String, raster: float) -> Texture2D:
	if raster > 0.0 and ResourceLoader.exists(path):
		var hs := ViewKit.soft_script(ViewKit.HIRES_PATH)
		if hs != null and hs.has_method("get_texture"):
			var v: Variant = hs.call("get_texture", path, {}, raster)
			if v is Texture2D:
				return v
	return ViewKit.tex(path)


func _art_pos(t: Texture2D) -> Vector2:
	if hotspot.art_pos != Vector2.INF:
		return hotspot.art_pos
	var ap: Variant = hotspot.art.get("pos", null)
	if ap is Array and (ap as Array).size() >= 2:
		return Vector2(float(ap[0]), float(ap[1]) + layout.room_floor_y(hotspot.room))
	var sz := t.get_size()
	var r := hotspot.rect
	return Vector2(r.get_center().x - sz.x * 0.5, r.end.y - sz.y)


## The state a hotspot shows (pure): occupied > spent > rigged (`rigged_<prank>` when that art
## exists for the rigged prank) > open (a container being rummaged, a door being traversed) >
## idle. `have` = the art keys this prop has.
static func state_for(hs_state: Dictionary, open: bool, rigged_prank: String, have: Dictionary) -> String:
	if bool(hs_state.get("occupant", false)):
		return "occupied" if have.has("occupied") else "idle"
	if bool(hs_state.get("spent", false)):
		return "spent"
	if bool(hs_state.get("rigged", false)):
		if rigged_prank != "" and have.has("rigged_" + rigged_prank):
			return "rigged_" + rigged_prank
		return "rigged"
	if open and have.has("open"):
		return "open"
	return "idle"


## Visual state from the hotspot state (TECH §3.4 hotspot_state), whether it shows open, and the
## prank rigged on it ("" unknown).
func set_state_from(hs_state: Dictionary, open: bool, rigged_prank: String = "") -> void:
	_set_state(PropView.state_for(hs_state, open, rigged_prank, _tex))


## Force the `open` look (a door being traversed, the kitchen window at the entry).
func show_open(on: bool) -> void:
	if on and _tex.has("open") and state != "open":
		_set_state("open")


func _set_state(s: String) -> void:
	if s == state:
		return
	state = s
	if sprite != null:
		sprite.texture = _tex.get(s, _tex["idle"])
		sprite.modulate = SPENT_MODULATE if s == "spent" and not _tex.has("spent") else Color.WHITE
	queue_redraw()


func has_front() -> bool:
	return front != null


## Show the `front` overlay (above the characters).
func set_front(on: bool) -> void:
	if front != null and front.visible != on:
		front.visible = on


## The badge this hotspot shows now (GDD §3.5): "gold" usable now, "blue" hiding spot,
## "red" in use next, "grey" needs an item Hush hasn't got, "" none.
static func badge_kind(kind: String, hs_state: Dictionary, carrying: PackedStringArray) -> String:
	if bool(hs_state.get("spent", false)) or not bool(hs_state.get("enabled", true)):
		return ""
	match kind:
		"hiding":
			if bool(hs_state.get("occupant", false)):
				return ""
			return "red" if bool(hs_state.get("in_use_next", false)) else "blue"
		"rig_point":
			if bool(hs_state.get("rigged", false)):
				return ""
			var need := ViewKit.s(hs_state.get("needs_item", ""))
			if need != "" and not carrying.has(need):
				return "grey"
			return "gold"
		"container":
			var stock: Variant = hs_state.get("stock", [])
			if stock is Array and (stock as Array).is_empty():
				return ""
			return "gold"
	return ""


## World point above the prop where its badge sits.
func badge_anchor() -> Vector2:
	var r := Rect2(sprite.position, sprite.texture.get_size()) if sprite != null else _grey_rect
	return Vector2(r.get_center().x, r.position.y - 44.0)


func set_highlight(on: bool) -> void:
	if highlight != null:
		highlight.highlighted = on and not locked


func _greybox_rect() -> Rect2:
	var r := hotspot.rect
	match hotspot.kind:
		"rig_point":
			var w := minf(r.size.x * 0.55, 90.0)
			var h := minf(r.size.y * 0.5, 80.0)
			return Rect2(r.get_center().x - w * 0.5, r.end.y - h - 10.0, w, h)
		"container":
			return Rect2(r.position.x + 14.0, r.position.y + r.size.y * 0.3, r.size.x - 28.0, r.size.y * 0.7)
		"stairs":
			return Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, r.size.y - 20.0)
	return Rect2(r.position.x + 8.0, r.position.y + 10.0, r.size.x - 16.0, r.size.y - 10.0)


## True when this prop has no art and draws a greybox (stairs hit boxes and untappable props never do).
func is_greybox() -> bool:
	return sprite == null and hotspot != null and hotspot.kind != "stairs" and hotspot.tappable


func _draw() -> void:
	if not is_greybox():
		return
	var r := _grey_rect
	var ink := ViewKit.INK
	var spent := state == "spent"
	match hotspot.kind:
		"container":
			var c := BOX if not spent else BOX.darkened(0.3)
			draw_rect(r, c)
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 16), c.darkened(0.15))
			if state == "open":
				draw_rect(Rect2(r.position.x - 10, r.position.y - 40, r.size.x * 0.5, 14), c.lightened(0.1))
			_outline(r, ink, 5.0)
		"hiding":
			var c2 := WOOD
			if state == "occupied":
				c2 = WOOD.darkened(0.3)
			draw_rect(r, c2)
			draw_rect(Rect2(r.position.x + 12, r.position.y + 14, r.size.x - 24, r.size.y - 28), c2.lightened(0.12))
			draw_line(Vector2(r.get_center().x, r.position.y + 14), Vector2(r.get_center().x, r.end.y - 14), ink, 3.0)
			_outline(r, ink, 5.0)
		"rig_point":
			var c3 := GOLDEN if not spent else Color("#B9B3A6")
			draw_rect(r, c3)
			draw_rect(Rect2(r.position.x + 6, r.position.y + 6, r.size.x * 0.35, r.size.y * 0.3), c3.lightened(0.35))
			_outline(r, ink, 5.0)
			if state.begins_with("rigged"):
				var bc := Vector2(r.end.x - 6, r.position.y + 4)
				draw_rect(Rect2(bc - Vector2(22, 10), Vector2(44, 18)), Color("#E23B4E"))
				draw_line(bc + Vector2(0, -10), bc + Vector2(4, -18), ink, 4.0)
		"exit", "door":
			draw_rect(r, Color("#7A4A2A"))
			draw_rect(Rect2(r.position.x + 14, r.position.y + 18, r.size.x - 28, r.size.y * 0.35), Color("#8E5A36"))
			draw_rect(Rect2(r.position.x + 14, r.get_center().y + 10, r.size.x - 28, r.size.y * 0.35), Color("#8E5A36"))
			draw_rect(Rect2(r.end.x - 30, r.get_center().y - 6, 14, 14), GOLDEN)
			_outline(r, ink, 5.0)


func _outline(r: Rect2, c: Color, w: float) -> void:
	draw_line(r.position, Vector2(r.end.x, r.position.y), c, w)
	draw_line(Vector2(r.end.x, r.position.y), r.end, c, w)
	draw_line(r.end, Vector2(r.position.x, r.end.y), c, w)
	draw_line(Vector2(r.position.x, r.end.y), r.position, c, w)
