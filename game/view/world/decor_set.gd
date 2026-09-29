## DecorSet — the house's non-hotspot sprites (house.json `decor[]`, STYLE §8; art-house requests
## 7 and the Stage-2 set dressing): one Sprite2D per decor item in the right band — `z < 0`
## behind the props, `0–1` in front of the props (still behind the characters), `z ≥ 2` OVER
## the characters (the `kitchen_sink_lip` he lands behind) — with `frames` + `fps` animated in
## view time, `blend: "add"` glows, `pulse_hz`, `raster` hints, locked-room tint and state
## textures (`idle`, `falling`, `floured`, …).
##
## Staging hooks: `set_visible(id, on)` (clip `decor` events — never two stools on screen —,
## the smashed vase, the front-door glow), `set_state(id, state)`, `set_offset(id, px)` (the
## vase creeping along the mantel), `drop(id)` (a Meltdown quake prop leaves its hook: the
## sprite hides while FxLayer's falling copy flies), `wobble(id)` (a `spring` clip event),
## and `snapshot_into(PackedByteArray)` / `restore_from()` for MomentRecorder. Clip-forced
## visibility is released by `release_clip_overrides()` once the forcing clip is over.
class_name DecorSet
extends RefCounted

const WOBBLE_S := 0.6

## Parents per band (set by WorldView before build()).
var back: Node2D = null
var front: Node2D = null
var over: Node2D = null
var layout: HouseLayout = null

var items: Array[HouseLayout.Decor] = []
var sprites: Dictionary = {}
var _base_pos: Dictionary = {}
var _state: Dictionary = {}
var _frames: Dictionary = {}
var _pulse: Dictionary = {}
var _wobble: Dictionary = {}
var _forced: Dictionary = {}
var _t := 0.0

## Decor id → the art scale it was built at (reset() restores the same texture).
var _ras: Dictionary = {}


## Build every decor sprite of `h`. `locked_rooms` get the unlit-set tint (and 1× art);
## `room_scales` (WorldView.room_art_scales) NO_ART = the room is never on camera tonight: no art.
func build(h: HouseLayout, locked_rooms: PackedStringArray, room_scales: Dictionary = {}) -> void:
	layout = h
	items.clear()
	sprites.clear()
	_ras.clear()
	for d in h.decor:
		var parent := back if d.z < 0 else (over if d.z >= 2 else front)
		if parent == null:
			continue
		var s := Sprite2D.new()
		s.name = "Decor_" + d.id
		s.centered = false
		# The unlit set's decor at 1× (s2-fix G #7), else the item's raster hint.
		var rsc := float(room_scales.get(d.room, -1.0))
		var ras := (rsc if rsc > 0.0 else ViewKit.LOCKED_SCALE) if locked_rooms.has(d.room) else d.raster
		if float(room_scales.get(d.room, -1.0)) == ViewKit.NO_ART:
			ras = ViewKit.NO_ART
		_ras[d.id] = ras
		s.texture = _tex(ViewKit.s(d.art.get("idle", "")), ras)
		s.position = d.pos
		s.visible = not d.hidden
		if locked_rooms.has(d.room):
			s.modulate = RoomView.LOCKED_MODULATE
		var raw := _raw(d.id)
		if ViewKit.s(raw.get("blend", "")) == "add":
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			s.material = m
		if raw.get("pulse_hz", null) != null:
			_pulse[d.id] = float(raw["pulse_hz"])
		if d.frames.size() >= 2 and d.fps > 0.0:
			var texs: Array[Texture2D] = []
			for f in d.frames:
				var t := _tex(f, ras)
				if t != null:
					texs.append(t)
			if texs.size() >= 2:
				_frames[d.id] = texs
		parent.add_child(s)
		items.append(d)
		sprites[d.id] = s
		_base_pos[d.id] = d.pos
		_state[d.id] = "idle"


func _raw(id: String) -> Dictionary:
	var hj: Variant = ViewKit.json(HouseLayout.HOUSE_JSON)
	if hj is Dictionary:
		for d in (hj as Dictionary).get("decor", []):
			if d is Dictionary and ViewKit.s((d as Dictionary).get("id", "")) == id:
				return d
	return {}


static func _tex(path: String, raster: float) -> Texture2D:
	if path == "" or raster == ViewKit.NO_ART:
		return null
	var packed := HouseArt.tex(path, HouseArt.want_scale(raster, false))
	if packed != null:
		return packed
	if raster > 0.0:
		var hs := ViewKit.soft_script(ViewKit.HIRES_PATH)
		if hs != null and hs.has_method("get_texture") and ResourceLoader.exists(path):
			var v: Variant = hs.call("get_texture", path, {}, raster)
			if v is Texture2D:
				return v
	return ViewKit.tex(path)


func has(id: String) -> bool:
	return sprites.has(id)


func sprite(id: String) -> Sprite2D:
	return sprites.get(id, null)


func is_visible(id: String) -> bool:
	var s: Sprite2D = sprites.get(id, null)
	return s != null and s.visible


## Show / hide a decor sprite. `by_actor` marks a clip-forced change (released later).
func set_visible(id: String, on: bool, by_actor: String = "", by_clip: String = "") -> void:
	var s: Sprite2D = sprites.get(id, null)
	if s == null:
		return
	s.visible = on
	if by_actor != "":
		_forced[id] = [by_actor, by_clip]


## Switch a decor's state texture ("idle", "falling", "floured", …; unknown = idle).
func set_state(id: String, state: String) -> void:
	var s: Sprite2D = sprites.get(id, null)
	var d := layout.decor_item(id) if layout != null else null
	if s == null or d == null:
		return
	_state[id] = state
	var p := ViewKit.s(d.art.get(state, d.art.get("idle", "")))
	s.texture = _tex(p, float(_ras.get(id, d.raster)))


func state_of(id: String) -> String:
	return ViewKit.s(_state.get(id, "idle"))


## Offset from the authored position (px).
func set_offset(id: String, off: Vector2) -> void:
	var s: Sprite2D = sprites.get(id, null)
	if s != null:
		s.position = (_base_pos[id] as Vector2) + off


func offset_of(id: String) -> Vector2:
	var s: Sprite2D = sprites.get(id, null)
	return s.position - (_base_pos[id] as Vector2) if s != null else Vector2.ZERO


## World rect of a decor sprite (its canvas at its current offset).
func rect_of(id: String) -> Rect2:
	var s: Sprite2D = sprites.get(id, null)
	var d := layout.decor_item(id) if layout != null else null
	if s == null or d == null:
		return Rect2()
	return Rect2(s.position, d.size)


## A quake prop leaves its hook: hide it (the falling copy is FxLayer's). Returns its rect.
func drop(id: String) -> Rect2:
	var r := rect_of(id)
	set_visible(id, false)
	return r


## A small damped rock (a `spring` clip event on the prop).
func wobble(id: String) -> void:
	if sprites.has(id):
		_wobble[id] = WOBBLE_S


## Release visibility a clip forced once `still_forcing(actor, clip) == false` (the clip is
## over and the actor is no longer reacting): the sprite goes back to its authored default.
func release_clip_overrides(still_forcing: Callable) -> void:
	if _forced.is_empty():
		return
	for id in _forced.keys():
		var f: Array = _forced[id]
		if not bool(still_forcing.call(ViewKit.s(f[0]), ViewKit.s(f[1]))):
			_forced.erase(id)
			var d := layout.decor_item(id) if layout != null else null
			if d != null:
				(sprites[id] as Sprite2D).visible = not d.hidden


## Per frame (view time): frame animation, pulses, wobbles.
func advance(dt: float) -> void:
	_t += dt
	for id in _frames:
		var texs: Array = _frames[id]
		var d := layout.decor_item(id)
		var s: Sprite2D = sprites[id]
		if d != null and s.visible and state_of(id) == "idle":
			s.texture = texs[int(floor(_t * d.fps)) % texs.size()]
	for id2 in _pulse:
		var s2: Sprite2D = sprites[id2]
		if s2.visible:
			s2.modulate.a = 0.7 + 0.3 * sin(_t * TAU * float(_pulse[id2]))
	if not _wobble.is_empty():
		for id3 in _wobble.keys():
			var left := float(_wobble[id3]) - dt
			var s3: Sprite2D = sprites[id3]
			var d3 := layout.decor_item(id3)
			if left <= 0.0:
				_wobble.erase(id3)
				s3.rotation = 0.0
				s3.offset = Vector2.ZERO
				continue
			_wobble[id3] = left
			# Rock about the bottom centre.
			var piv := Vector2(d3.size.x * 0.5, d3.size.y) if d3 != null else Vector2.ZERO
			var ang := sin((WOBBLE_S - left) * 26.0) * 0.12 * (left / WOBBLE_S)
			s3.offset = Vector2.ZERO
			s3.rotation = ang
			s3.position = (_base_pos[id3] as Vector2) + piv - piv.rotated(ang)


## Retry: every decor back to its authored state.
func reset() -> void:
	_forced.clear()
	_wobble.clear()
	for d in items:
		var s: Sprite2D = sprites[d.id]
		s.visible = not d.hidden
		s.position = d.pos
		s.rotation = 0.0
		_state[d.id] = "idle"
		s.texture = _tex(ViewKit.s(d.art.get("idle", "")), float(_ras.get(d.id, d.raster)))


## Visibility bits of every decor item (MomentRecorder), into a preallocated array.
func snapshot_into(out: PackedByteArray) -> void:
	if out.size() != items.size():
		out.resize(items.size())
	for i in items.size():
		out[i] = 1 if (sprites[items[i].id] as Sprite2D).visible else 0
