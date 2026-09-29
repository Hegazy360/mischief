## FxBadges — every hotspot badge in one node (GDD §3.5): 56 px icons above hotspots —
## gold (usable now), blue closed eye (hiding spot), red (in use next), grey thought-cloud
## (needs an item you haven't got). Shown for Hush's room (Hints: Always), or for everything
## in view for 2 s after a long-press reveal (Hints: On long-press), or never (Off). They bob
## gently and pop in. Few textures → a handful of batched draw calls.
class_name FxBadges
extends Node2D

const SIZE := 56.0
const REVEAL_S := 2.0
const POP_S := 0.18
const KINDS: PackedStringArray = ["gold", "blue", "red", "grey"]

## "always" | "long_press" | "off" (Settings `hints`).
var hints: String = "always"
var _anchor: Dictionary = {}     ## hotspot id → Vector2 (world)
var _kind: Dictionary = {}       ## hotspot id → kind ("" = none)
var _room: Dictionary = {}       ## hotspot id → room id
var _born: Dictionary = {}       ## hotspot id → age (s) since its kind changed
var _tex: Dictionary = {}
var _current_room := ""
var _reveal := 0.0
var _t := 0.0
var _unit := 1.0


func _init() -> void:
	name = "Badges"
	visibility_layer = 2
	# Behind the characters (a badge never covers a face), above the props.
	z_index = -1


func _ready() -> void:
	for k in KINDS:
		_tex[k] = FxArt.badge(k)


## Register a hotspot's badge anchor (world) and room.
func register(hotspot_id: String, anchor: Vector2, room: String) -> void:
	_anchor[hotspot_id] = anchor
	_room[hotspot_id] = room
	if not _kind.has(hotspot_id):
		_kind[hotspot_id] = ""
		_born[hotspot_id] = 99.0


## Set a hotspot's badge kind (TECH §5.7 `badge(hotspot, kind)`); "" hides it.
func badge(hotspot_id: String, kind: String) -> void:
	if ViewKit.s(_kind.get(hotspot_id, "")) == kind:
		return
	_kind[hotspot_id] = kind
	_born[hotspot_id] = 0.0
	queue_redraw()


## The kind currently set for a hotspot (tests).
func kind_of(hotspot_id: String) -> String:
	return ViewKit.s(_kind.get(hotspot_id, ""))


## Which room is "current" (Hush's).
func set_current_room(room: String) -> void:
	if room != _current_room:
		_current_room = room
		queue_redraw()


## Long-press reveal: every badge in view for 2 s.
func reveal() -> void:
	_reveal = REVEAL_S
	queue_redraw()


## End a reveal early (the finger lifted onto a hotspot).
func stop_reveal() -> void:
	_reveal = 0.0
	queue_redraw()


func revealing() -> bool:
	return _reveal > 0.0


func tick(dt: float, unit: float) -> void:
	_t += dt
	_unit = unit
	if _reveal > 0.0:
		_reveal -= dt
	for id in _born:
		if float(_born[id]) < POP_S:
			_born[id] = float(_born[id]) + dt
	queue_redraw()


func _draw() -> void:
	if hints == "off" and _reveal <= 0.0:
		return
	for id in _kind:
		var k := ViewKit.s(_kind[id])
		if k == "":
			continue
		var in_room := ViewKit.s(_room.get(id, "")) == _current_room
		var show := _reveal > 0.0 or (in_room and hints == "always")
		if not show:
			continue
		var tex: Texture2D = _tex.get(k, null)
		if tex == null:
			continue
		var a: Vector2 = _anchor.get(id, Vector2.ZERO)
		var age := float(_born.get(id, 99.0))
		var s := SIZE * _unit
		if age < POP_S:
			s *= ViewKit.ease_out_back(age / POP_S)
		var bob := sin(_t * 2.4 + a.x * 0.01) * 4.0 * _unit
		draw_texture_rect(tex, Rect2(a + Vector2(-s * 0.5, -s + bob), Vector2(s, s)), false)
