## FxStareStrip — what Bellows can see, painted on the floor (GDD §3.9, §4.3): a 20 px amber
## band (alpha 0.35) from his feet in his facing direction, as long as his MOVING sight, with
## a darker inner segment (alpha 0.55) as long as his FROZEN sight. Specs on: red-amber and
## to the wall. Grey while he's blind. Through a doorway he faces (within 250 px of it) it
## continues 300 px into the next room. Calm by design: no pulsing, a soft far end.
## The ranges mirror the GDD sight table (`ranges()`, pure).
class_name FxStareStrip
extends Node2D

const H := 20.0
## The band sits on the floor surface just above the floor line (the lighter boards).
const Y_TOP := -22.0
const AMBER := Color("#FFB020")
const SPECS := Color("#F2552C")
const GREY := Color("#9AA3B5")
const DOORWAY_REACH := 250.0
const DOORWAY_SEE := 300.0
const WALL := 99999.0

enum Mode { AMBER, SPECS, GREY, NONE }

var layout: HouseLayout = null
var enabled: bool = true
var _x0 := 0.0
var _dir := 1.0
var _y := 0.0
var _move_end := 0.0
var _frozen_end := 0.0
var _mode: int = Mode.NONE
var _a := 0.0


func _init() -> void:
	name = "StareStrip"
	visibility_layer = 2
	z_index = -4


## Bellows' sight → Vector3(moving_px, frozen_px, mode). WALL = to the wall. From the sim's
## `sight_ranges()` when the snapshot carries it (one source of truth, s2-sim §4.4); this GDD
## §4.3 table is the fallback.
static func ranges(b: ViewSnapshot.Actor, glyph: String, awareness: String) -> Vector3:
	if not b.present:
		return Vector3(0, 0, Mode.NONE)
	if b.sight_known:
		if b.sight_moving <= 0.0 and b.sight_frozen <= 0.0 and not b.sight_wall:
			return Vector3(0, 0, Mode.GREY)
		var mv := WALL if b.sight_wall else b.sight_moving
		var mode := Mode.SPECS if (b.sight_wall or b.specs_on) else Mode.AMBER
		if b.blinded:
			mode = Mode.GREY
		return Vector3(mv, b.sight_frozen, mode)
	if b.reacting or b.state == "REACTING" or b.state == "MELTDOWN" or glyph == "stars" \
			or glyph == "asleep" or awareness == "asleep" or awareness == "blind":
		return Vector3(0, 0, Mode.GREY)
	if b.blinded or b.state == "EXHAUSTED" or glyph == "blinded":
		return Vector3(150, 150, Mode.GREY)
	if awareness == "absorbed":
		return Vector3(250, 0, Mode.AMBER)
	if b.specs_on or glyph == "specs_on":
		return Vector3(WALL, 600, Mode.SPECS)
	return Vector3(600, 250, Mode.AMBER)


## Update from the (interpolated) Bellows snapshot. `x` = his drawn x.
func stare_strip(snap: ViewSnapshot, x: float) -> void:
	var b := snap.bellows
	var rg := FxStareStrip.ranges(b, snap.bubble_glyph, snap.awareness)
	_mode = int(rg.z)
	if not enabled or _mode == Mode.NONE or b.state == "CAUGHT_HOLD":
		_mode = Mode.NONE
		queue_redraw()
		return
	_dir = float(b.facing)
	_x0 = x + _dir * 36.0
	_y = b.y
	var limit := _limit(b.room, x, _dir)
	var mv := minf(rg.x, limit)
	var fr := minf(rg.y, limit)
	_move_end = _x0 + _dir * maxf(mv, 0.0)
	_frozen_end = _x0 + _dir * maxf(fr, 0.0)
	queue_redraw()


## Distance he can see ahead before a wall (plus the doorway look-through).
func _limit(room_id: String, x: float, dir: float) -> float:
	if layout == null:
		return WALL
	var r := layout.room(room_id)
	if r == null:
		return WALL
	var wall_x := r.x1 if dir > 0.0 else r.x0
	var d := absf(wall_x - x) - 36.0
	for l in layout.links_of(room_id):
		if l.kind == "doorway" and absf(l.x - wall_x) < 2.0 and absf(wall_x - x) <= DOORWAY_REACH + 36.0:
			return d + DOORWAY_SEE
	return maxf(0.0, d)


## Current strip in world x: [start, moving end, frozen end, mode] (tests).
func extent() -> Vector4:
	return Vector4(_x0, _move_end, _frozen_end, float(_mode))


func tick(dt: float) -> void:
	var want := 1.0 if _mode != Mode.NONE else 0.0
	var a0 := _a
	_a = move_toward(_a, want, dt * 5.0)
	if a0 != _a:
		queue_redraw()


func _draw() -> void:
	if _mode == Mode.NONE and _a <= 0.0:
		return
	var col := AMBER
	match _mode:
		Mode.SPECS:
			col = SPECS
		Mode.GREY:
			col = GREY
	if _mode == Mode.GREY and absf(_move_end - _x0) < 1.0:
		# Blind: a short grey stub so "he can't see" still reads.
		_band(_x0, _x0 + _dir * 60.0, Color(col, 0.3 * _a))
		return
	_band(_x0, _move_end, Color(col, 0.35 * _a))
	if absf(_frozen_end - _x0) > 1.0:
		_band(_x0, _frozen_end, Color(col.darkened(0.25), 0.55 * _a))
	# Crisp edges so it reads on any floor (calm: thin, static, no pulse): a light top edge,
	# an ink bottom edge, and small chevrons pointing where he looks.
	var lo := minf(_x0, _move_end)
	var hi := maxf(_x0, _move_end)
	var top := _y + Y_TOP
	draw_line(Vector2(lo, top), Vector2(hi, top), Color(col.lightened(0.35), 0.9 * _a), 3.0)
	draw_line(Vector2(lo, top + H), Vector2(hi, top + H), Color(ViewKit.INK, 0.45 * _a), 3.0)
	var cc := Color(col.lightened(0.5), 0.75 * _a)
	var cx := _x0 + _dir * 70.0
	var n := 0
	while (_dir > 0.0 and cx < _move_end - 30.0) or (_dir < 0.0 and cx > _move_end + 30.0):
		var tip := Vector2(cx + _dir * 6.0, top + H * 0.5)
		draw_line(tip, tip + Vector2(-_dir * 8.0, -6.0), cc, 3.0)
		draw_line(tip, tip + Vector2(-_dir * 8.0, 6.0), cc, 3.0)
		cx += _dir * 110.0
		n += 1
		if n > 40:
			break
	# End ticks.
	var tc := Color(col.darkened(0.35), 0.7 * _a)
	draw_line(Vector2(_move_end, _y + Y_TOP - 6.0), Vector2(_move_end, _y + Y_TOP + H + 4.0), tc, 3.0)
	if absf(_frozen_end - _x0) > 1.0:
		draw_line(Vector2(_frozen_end, _y + Y_TOP - 6.0), Vector2(_frozen_end, _y + Y_TOP + H + 4.0), tc, 3.0)


## A band from x0 to x1 with a soft far end (3 fading steps over the last 48 px).
func _band(x0: float, x1: float, c: Color) -> void:
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	var fade := minf(48.0, (hi - lo) * 0.3)
	var solid0 := lo if x1 > x0 else lo + fade
	var solid1 := hi - fade if x1 > x0 else hi
	draw_rect(Rect2(solid0, _y + Y_TOP, solid1 - solid0, H), c)
	for i in 3:
		var a := c.a * (0.75 - 0.25 * float(i))
		var w := fade / 3.0
		var fx := solid1 + w * float(i) if x1 > x0 else solid0 - w * float(i + 1)
		draw_rect(Rect2(fx, _y + Y_TOP, w, H), Color(c, a))
