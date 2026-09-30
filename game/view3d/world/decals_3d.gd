## Decals3D — the floor "decals" of the 3D view (REDESIGN §4.2–§4.4, §5.8; brief r3d-view3d §4.4): unshaded alpha
## quads lying on the floor (decal.gdshader; Godot's Decal is not on the Compatibility renderer), on visual layer 4
## DECAL (the Bellows window never shows them), pooled — nothing is allocated after `_ready`.
##
## * the **stare strip** (z −1.5…−0.5 along his sight: the moving range pale gold, the darker inner frozen range,
##   grey while he is blinded);
## * **rings**: the run noise ring (white, to its true 2.5 m radius, every 0.5 s while running), the squeak ring
##   (yellow, to the true hearing reach), B-rig noise rings; expanding over 0.6 s and fading;
## * the **destination ring** (0.5 m, white) + the dotted path, the **tapped-spot pop** (≤ 16 ms), a grey pop on a
##   rejected tap, the **W3 ghost ring** with a small chevron at a queued target, floor **pins**;
## * the **N4 spotlight pool** (a soft warm pool on the floor in front of the "next useful" spot).
class_name Decals3D
extends Node3D

const RING_POOL := 8
const POP_POOL := 4
const PIN_POOL := 2
const POOL_POOL := 2
const RING_GROW_S := 0.6
const POP_S := 0.30
const DEST_R := 0.5
const STRIP_W := 1.0

class Slot:
	var mi: MeshInstance3D
	var mat: ShaderMaterial
	var t: float = 0.0
	var life: float = 0.0
	var r0: float = 0.2
	var r1: float = 1.0
	var active: bool = false
	var key: String = ""

var _rings: Array[Slot] = []
var _pops: Array[Slot] = []
var _pins: Array[Slot] = []
var _pools: Array[Slot] = []
var _strip: Slot = null
var _dest: Slot = null
var _path: Slot = null
var _ghost: Slot = null
var _chevron: Slot = null
var _last_tap := Vector3.ZERO
var _ring_i := 0
var _pop_i := 0
var _pin_i := 0


func _init() -> void:
	name = "Decals3D"
	for i in RING_POOL:
		_rings.append(_slot("ring", View3DConst.DECAL_RING))
	for i in POP_POOL:
		_pops.append(_slot("pop", View3DConst.DECAL_RING))
	for i in PIN_POOL:
		_pins.append(_slot("pin", View3DConst.DECAL_DISC))
	for i in POOL_POOL:
		_pools.append(_slot("pool", View3DConst.DECAL_DISC))
	_strip = _slot("strip", View3DConst.DECAL_STRIP)
	_dest = _slot("ring", View3DConst.DECAL_RING)
	_path = _slot("path", View3DConst.DECAL_DOTS)
	_ghost = _slot("ring", View3DConst.DECAL_RING)
	_chevron = _slot("pin", View3DConst.DECAL_DISC)


func _slot(kind: String, shape: int) -> Slot:
	var s := Slot.new()
	s.mi = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	s.mi.mesh = q
	s.mat = ShaderMaterial.new()
	s.mat.shader = load(View3DConst.SH_DECAL)
	s.mat.set_shader_parameter("shape", shape)
	s.mat.render_priority = int(View3DConst.DECAL_PRIORITY.get(kind, -3))
	s.mi.material_override = s.mat
	s.mi.layers = View3DConst.MASK_DECAL
	s.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.mi.visible = false
	MaterialWarm3D.register(s.mat, &"decal")
	add_child(s.mi)
	return s


func _place(s: Slot, p: Vector3, size: Vector2) -> void:
	s.mi.position = Vector3(p.x, p.y + View3DConst.DECAL_Y, p.z)
	s.mi.scale = Vector3(size.x, 1.0, size.y)
	s.mi.visible = true


## The stare strip along the lane band (x from his feet `from_x` toward `dir`, `moving` m, the inner `frozen` m).
func stare_strip(on: bool, from_x: float, dir: float, moving: float, frozen: float, floor_y: float, blind: bool) -> void:
	if not on or moving <= 0.01:
		_strip.mi.visible = false
		return
	var len_m := maxf(0.1, moving)
	var cx := from_x + dir * len_m * 0.5
	var z := (View3DConst.STARE_STRIP_Z[0] + View3DConst.STARE_STRIP_Z[1]) * 0.5
	_place(_strip, Vector3(cx, floor_y, z), Vector2(len_m, STRIP_W))
	_strip.mat.set_shader_parameter("color", View3DConst.STARE_BLIND if blind else View3DConst.STARE_STRIP)
	_strip.mat.set_shader_parameter("color2", View3DConst.STARE_BLIND if blind else View3DConst.STARE_FROZEN)
	# the frozen range runs from his feet; UV.x 0 is the quad's −x end
	var fr := clampf(frozen / len_m, 0.0, 1.0)
	if dir >= 0.0:
		_strip.mat.set_shader_parameter("seg_a", 0.0)
		_strip.mat.set_shader_parameter("seg_b", fr)
	else:
		_strip.mat.set_shader_parameter("seg_a", 1.0 - fr)
		_strip.mat.set_shader_parameter("seg_b", 1.0)
	_strip.mat.set_shader_parameter("softness", 0.5)


func strip_visible() -> bool:
	return _strip.mi.visible


## An expanding ring on the floor at `p` to radius `r` (m) in `col`, fading over `life` s.
func ring(p: Vector3, r: float, col: Color, life: float = 0.8) -> void:
	var s := _rings[_ring_i]
	_ring_i = (_ring_i + 1) % RING_POOL
	s.active = true
	s.t = 0.0
	s.life = maxf(RING_GROW_S, life)
	s.r0 = minf(0.3, r * 0.2)
	s.r1 = r
	s.mat.set_shader_parameter("color", col)
	s.mat.set_shader_parameter("inner", 0.9)
	s.mat.set_shader_parameter("softness", 0.3)
	s.mat.set_shader_parameter("progress", 0.0)
	_place(s, Vector3(p.x, p.y, View3DConst.LANE_Z - 0.05), Vector2(s.r0 * 2.0, s.r0 * 2.0))


## Rings live now (tests).
func active_rings() -> int:
	var n := 0
	for s in _rings:
		if s.active:
			n += 1
	return n


## The tapped-spot pop (or a grey one on a rejected tap).
func pop(p: Vector3, rejected: bool) -> void:
	_last_tap = p
	var s := _pops[_pop_i]
	_pop_i = (_pop_i + 1) % POP_POOL
	s.active = true
	s.t = 0.0
	s.life = POP_S
	s.r0 = 0.12
	s.r1 = 0.45
	s.mat.set_shader_parameter("color", Color(0.7, 0.7, 0.72, 0.8) if rejected else Color(1, 1, 1, 0.95))
	s.mat.set_shader_parameter("inner", 0.7)
	s.mat.set_shader_parameter("progress", 0.0)
	_place(s, Vector3(p.x, p.y, View3DConst.LANE_Z), Vector2(s.r0 * 2.0, s.r0 * 2.0))


func last_tap() -> Vector3:
	return _last_tap


## The destination ring (0.5 m) at `to` and the dotted path from `from`.
func destination(to: Vector3, from: Vector3) -> void:
	_dest.active = true
	_dest.mat.set_shader_parameter("color", View3DConst.DEST_RING)
	_dest.mat.set_shader_parameter("inner", 0.82)
	_dest.mat.set_shader_parameter("progress", 0.0)
	_place(_dest, Vector3(to.x, to.y, View3DConst.LANE_Z), Vector2(DEST_R * 2.0, DEST_R * 2.0))
	var len_m := absf(to.x - from.x)
	if len_m > 0.6:
		_path.active = true
		_path.mat.set_shader_parameter("color", Color(1, 1, 1, 0.55))
		_path.mat.set_shader_parameter("dots", maxf(2.0, round(len_m / 0.3)))
		_place(_path, Vector3((to.x + from.x) * 0.5, to.y, View3DConst.LANE_Z), Vector2(len_m, 0.1))
	else:
		_path.mi.visible = false


## Hush arrived: the ring pops (fades) and the path goes.
func destination_done() -> void:
	if _dest.mi.visible:
		_dest.t = 0.0
		_dest.life = POP_S
		_dest.key = "fade"
	_path.mi.visible = false


func destination_visible() -> bool:
	return _dest.mi.visible


## The W3 ghost ring + chevron at a queued target.
func ghost_ring(p: Vector3) -> void:
	_ghost.active = true
	_ghost.mat.set_shader_parameter("color", Color(1, 1, 1, 0.45))
	_ghost.mat.set_shader_parameter("inner", 0.75)
	_ghost.mat.set_shader_parameter("progress", 0.0)
	_place(_ghost, Vector3(p.x, p.y, View3DConst.LANE_Z), Vector2(0.9, 0.9))
	_chevron.mat.set_shader_parameter("color", Color(1, 1, 1, 0.7))
	_chevron.mat.set_shader_parameter("softness", 0.2)
	_place(_chevron, Vector3(p.x, p.y, View3DConst.LANE_Z + 0.55), Vector2(0.16, 0.16))


func ghost_off() -> void:
	_ghost.mi.visible = false
	_chevron.mi.visible = false


func ghost_visible() -> bool:
	return _ghost.mi.visible


## A floor pin (tapped while frozen / hidden).
func pin(p: Vector3) -> void:
	var s := _pins[_pin_i]
	_pin_i = (_pin_i + 1) % PIN_POOL
	s.mat.set_shader_parameter("color", Color("#FFD84A", 0.9))
	s.mat.set_shader_parameter("softness", 0.15)
	_place(s, Vector3(p.x, p.y, View3DConst.LANE_Z), Vector2(0.22, 0.22))


## The N4 spotlight pool in front of a hotspot (keyed by hotspot id).
func pool_on(key: String, p: Vector3) -> void:
	for s in _pools:
		if s.key == key and s.mi.visible:
			return
	for s in _pools:
		if not s.mi.visible:
			s.key = key
			s.t = 0.0
			s.mat.set_shader_parameter("color", View3DConst.POOL)
			s.mat.set_shader_parameter("softness", 0.8)
			s.mat.set_shader_parameter("progress", 0.0)
			_place(s, p, Vector2(1.5, 1.0))
			return


func pool_off(key: String) -> void:
	for s in _pools:
		if s.key == key:
			s.mi.visible = false
			s.key = ""


func pool_visible(key: String) -> bool:
	for s in _pools:
		if s.key == key and s.mi.visible:
			return true
	return false


## One frame (view time): rings grow and fade, pops pop, the pool breathes.
func advance(dt: float) -> void:
	for s in _rings:
		if not s.active:
			continue
		s.t += dt
		var u := clampf(s.t / RING_GROW_S, 0.0, 1.0)
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var r := lerpf(s.r0, s.r1, e)
		s.mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
		s.mat.set_shader_parameter("progress", clampf(s.t / s.life, 0.0, 1.0))
		if s.t >= s.life:
			s.active = false
			s.mi.visible = false
	for s in _pops:
		if not s.active:
			continue
		s.t += dt
		var u2 := clampf(s.t / s.life, 0.0, 1.0)
		var r2 := lerpf(s.r0, s.r1, 1.0 - (1.0 - u2) * (1.0 - u2))
		s.mi.scale = Vector3(r2 * 2.0, 1.0, r2 * 2.0)
		s.mat.set_shader_parameter("progress", u2)
		if u2 >= 1.0:
			s.active = false
			s.mi.visible = false
	if _dest.key == "fade" and _dest.mi.visible:
		_dest.t += dt
		_dest.mat.set_shader_parameter("progress", clampf(_dest.t / _dest.life, 0.0, 1.0))
		if _dest.t >= _dest.life:
			_dest.mi.visible = false
			_dest.key = ""
	for s in _pools:
		if s.mi.visible:
			s.t += dt
			s.mat.set_shader_parameter("progress", 0.15 + 0.15 * sin(s.t * 2.6))


## Hides everything (retry, seek).
func clear() -> void:
	for arr in [_rings, _pops, _pins, _pools]:
		for s in arr:
			(s as Slot).active = false
			(s as Slot).mi.visible = false
			(s as Slot).key = ""
	for s in [_strip, _dest, _path, _ghost, _chevron]:
		(s as Slot).mi.visible = false
		(s as Slot).key = ""
