## FxEntryWarning — "he's coming" ≥ 1.5 s before Bellows enters Hush's room (GDD §3.9, §4.2):
## at a door the handle jiggles with rattle marks; at an open doorway footprint chevrons
## pulse in from his side; on the stairs his legs appear stepping down at the stair top.
## One warning at a time; it lasts the event's `eta` (≈ 90 ticks) in view time.
class_name FxEntryWarning
extends Node2D

enum Kind { NONE, DOOR, DOORWAY, STAIRS }

const AMBER := Color("#FFB020")

var _kind: int = Kind.NONE
var _pos := Vector2.ZERO
var _dir := 1.0
var _t := 0.0
var _len := 1.5
var _unit := 1.0
var _handle: Texture2D = null
var _legs: Texture2D = null


func _init() -> void:
	name = "EntryWarning"
	visibility_layer = 2
	z_index = 12


func _ready() -> void:
	_handle = FxArt.prop("door_handle")
	_legs = FxArt.sprite("fallback/legs")


## Start a warning for Bellows entering `room` (Hush's) coming from `from_room`, `eta` ticks.
func start(layout: HouseLayout, room: String, from_room: String, eta: int) -> void:
	_kind = Kind.NONE
	if layout == null:
		return
	var l := layout.link_between(room, from_room) if from_room != "" else null
	if l == null:
		# Unknown side: the nearest link of the room to Bellows is not known; pick any door.
		for cand in layout.links_of(room):
			l = cand
			break
	if l == null:
		return
	var r := layout.room(room)
	if r == null:
		return
	var fy := layout.floor_y(r.floor)
	_len = maxf(0.5, float(eta) / 60.0)
	_t = 0.0
	match l.kind:
		"door":
			_kind = Kind.DOOR
			_dir = 1.0 if l.x <= r.x0 + 1.0 else -1.0
			_pos = Vector2(l.x + _dir * 40.0, fy - 190.0)
		"stairs":
			_kind = Kind.STAIRS
			var foot := l.ax if l.a == room else l.bx
			_pos = Vector2(foot, fy - layout.interior_h + 10.0)
			_dir = -1.0
		_:
			_kind = Kind.DOORWAY
			_dir = 1.0 if l.x <= r.x0 + 1.0 else -1.0
			_pos = Vector2(l.x, fy)
	queue_redraw()


func stop() -> void:
	_kind = Kind.NONE
	queue_redraw()


func is_active() -> bool:
	return _kind != Kind.NONE


func tick(dt: float, unit: float) -> void:
	if _kind == Kind.NONE:
		return
	_unit = unit
	_t += dt
	if _t >= _len + 0.3:
		stop()
		return
	queue_redraw()


func _draw() -> void:
	if _kind == Kind.NONE:
		return
	var fade := clampf((_len + 0.3 - _t) / 0.3, 0.0, 1.0)
	match _kind:
		Kind.DOOR:
			var j := sin(_t * 38.0) * 5.0
			var rot := sin(_t * 38.0) * 0.35
			if _handle != null:
				draw_set_transform(_pos + Vector2(j, 0), rot, Vector2.ONE)
				draw_texture(_handle, Vector2(-20, -30), Color(1, 1, 1, fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var c := Color(AMBER, 0.9 * fade)
			for i in 3:
				var off := float(i) * 16.0
				var s := 1.0 if int(_t * 8.0) % 2 == 0 else 0.7
				draw_line(_pos + Vector2(_dir * (34 + off), -26 - off * 0.5), _pos + Vector2(_dir * (46 + off) * s, -34 - off * 0.5), c, 5.0)
				draw_line(_pos + Vector2(_dir * (34 + off), 26 + off * 0.5), _pos + Vector2(_dir * (46 + off) * s, 34 + off * 0.5), c, 5.0)
		Kind.DOORWAY:
			# His shadow falls through the doorway, growing as he nears, and chevrons march in.
			var u := clampf(_t / _len, 0.0, 1.0)
			var sh_w := lerpf(60.0, 220.0, u)
			var sh_c := Vector2(_pos.x - _dir * lerpf(90.0, 10.0, u), _pos.y - 8.0)
			draw_set_transform(sh_c, 0.0, Vector2(1.0, 0.18))
			draw_circle(Vector2.ZERO, sh_w * 0.5, Color(0.1, 0.06, 0.16, 0.35 * fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var tall := lerpf(120.0, 380.0, u)
			draw_rect(Rect2(_pos.x - _dir * 10.0 - 30.0, _pos.y - tall, 60.0, tall), Color(0.1, 0.06, 0.16, 0.18 * fade))
			for i in 3:
				var ph := fmod(_t * 2.0 + float(i) * 0.33, 1.0)
				var x := _pos.x + _dir * (30.0 + ph * 170.0)
				var a := (0.5 + 0.5 * u) * sin(ph * PI) * fade
				var h := 30.0
				var tip := Vector2(x + _dir * 20.0, _pos.y - 60.0)
				draw_line(tip, tip + Vector2(-_dir * 26.0, -h), Color(ViewKit.INK, a * 0.8), 14.0)
				draw_line(tip, tip + Vector2(-_dir * 26.0, h), Color(ViewKit.INK, a * 0.8), 14.0)
				draw_line(tip, tip + Vector2(-_dir * 26.0, -h), Color(AMBER, a), 8.0)
				draw_line(tip, tip + Vector2(-_dir * 26.0, h), Color(AMBER, a), 8.0)
		Kind.STAIRS:
			if _legs != null:
				var u2 := clampf(_t / _len, 0.0, 1.0)
				var step := int(_t * 3.5) % 2
				var y := _pos.y - 150.0 + u2 * 120.0 + (6.0 if step == 1 else 0.0)
				draw_texture(_legs, Vector2(_pos.x - 60.0 + u2 * 30.0, y), Color(1, 1, 1, fade))
