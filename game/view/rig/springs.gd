## Springs — per-part damped springs for secondary motion (TECH §5.3; the reference "noodle"
## values: k 220 s⁻², c 10 s⁻¹ ≈ ζ 0.34). One spring per rig.json `spring` entry, acting on
## that part's `rot` (degrees, clamped ±clamp) or `sy` (a fraction, clamped ±clamp,
## area-preserving: sx ÷ (1 + v)).
##
## * Driven by the body: `feed(xf, world_offset, facing, dt)` measures each spring part's
##   joint acceleration (character motion + the node's own world motion, converted into the
##   unflipped character space) and its parent's angular acceleration, so a hat lags when the
##   head snaps, a belly jiggles on a landing. Teleports (> 200 px in a frame) are ignored.
## * Kicked by events: `kick(part, amount)` is a velocity impulse whose first peak ≈ amount
##   (degrees for rot, fraction for sy).
## * Integrated with semi-implicit Euler in FIXED 1/60 s sub-steps with an accumulator and
##   render interpolation, so it behaves the same at 30, 60 and 120 fps (tests check it).
## Allocation-free after setup(); sleeps (costs nothing) once everything is at rest.
class_name Springs
extends RefCounted

const H := 1.0 / 60.0
const MAX_STEPS := 8
## Linear drive: deg/s² of rot per px/s² of perpendicular joint acceleration.
const DRIVE_ROT := 0.075
## Angular drive: fraction of the parent's angular acceleration fed back (lag).
const DRIVE_ANG := 0.55
## sy drive: fraction/s² per px/s² of vertical acceleration.
const DRIVE_SY := 0.00009
const MAX_ACCEL := 40000.0
const TELEPORT_PX := 200.0
const REST_ROT := 0.05
const REST_SY := 0.0005

var rig: RigDef
var count: int = 0
var val: PackedFloat32Array = PackedFloat32Array()
var vel: PackedFloat32Array = PackedFloat32Array()
var prev_val: PackedFloat32Array = PackedFloat32Array()
var drive: PackedFloat32Array = PackedFloat32Array()
var awake: bool = false
## Multiplier on every drive (0 = only explicit kicks).
var drive_scale: float = 1.0

var _acc: float = 0.0
var _pos: PackedVector2Array = PackedVector2Array()
var _vel_px: PackedVector2Array = PackedVector2Array()
var _prot: PackedFloat32Array = PackedFloat32Array()
var _pang: PackedFloat32Array = PackedFloat32Array()
var _have_prev: PackedByteArray = PackedByteArray()


## Build the springs of `rig_def`.
func setup(rig_def: RigDef) -> void:
	rig = rig_def
	count = rig.spring_part.size()
	val.resize(count)
	vel.resize(count)
	prev_val.resize(count)
	drive.resize(count)
	_prot.resize(count)
	_pang.resize(count)
	_pos.resize(count)
	_vel_px.resize(count)
	_have_prev.resize(count)
	reset()


## Everything at rest; history cleared.
func reset() -> void:
	val.fill(0.0)
	vel.fill(0.0)
	prev_val.fill(0.0)
	drive.fill(0.0)
	_have_prev.fill(0)
	_acc = 0.0
	awake = false


## Index of the spring on part `part` (-1 when that part has none).
func index_of(part: int) -> int:
	return rig.spring_part.find(part) if rig != null else -1


## Velocity impulse on spring `s` so that its first peak from rest ≈ `amount`.
func kick(s: int, amount: float) -> void:
	if s < 0 or s >= count or amount == 0.0:
		return
	vel[s] += amount * kick_gain(rig.spring_k[s], rig.spring_c[s])
	awake = true


## Kick by part name (no-op when that part has no spring).
func kick_part(part_name: String, amount: float) -> void:
	kick(index_of(rig.idx(part_name)), amount)


## Measure drives from the solved transforms (character space). `world_offset` = the node's
## world position, `facing` its sign (±1), `dt` the frame time (s).
func feed(xf: Array[Transform2D], world_offset: Vector2, facing: float, dt: float) -> void:
	if dt <= 0.0 or count == 0:
		return
	var local_world := Vector2(world_offset.x * signf(facing) if facing != 0.0 else world_offset.x, world_offset.y)
	for s in count:
		var p := rig.spring_part[s]
		var par := rig.parent[p]
		var joint := xf[p].origin + local_world
		var prot := xf[par].get_rotation() if par >= 0 else 0.0
		if _have_prev[s] == 0:
			_pos[s] = joint
			_vel_px[s] = Vector2.ZERO
			_prot[s] = prot
			_pang[s] = 0.0
			_have_prev[s] = 1
			drive[s] = 0.0
			continue
		var d := joint - _pos[s]
		if d.length() > TELEPORT_PX:
			_pos[s] = joint
			_vel_px[s] = Vector2.ZERO
			_prot[s] = prot
			_pang[s] = 0.0
			drive[s] = 0.0
			continue
		var v := d / dt
		var a := ((v - _vel_px[s]) / dt).limit_length(MAX_ACCEL)
		var w := wrapf(prot - _prot[s], -PI, PI) / dt
		var alpha := clampf((w - _pang[s]) / dt, -2000.0, 2000.0)
		_pos[s] = joint
		_vel_px[s] = v
		_prot[s] = prot
		_pang[s] = w
		if rig.spring_channel[s] == RigDef.SPRING_ROT:
			# The part's centre of mass direction (pivot → canvas centre) in world orientation.
			var r := _mass_dir(p, xf)
			var torque := -(r.x * a.y - r.y * a.x)      # cross(r, −a)
			drive[s] = (torque * DRIVE_ROT - rad_to_deg(alpha) * DRIVE_ANG) * drive_scale
		else:
			drive[s] = a.y * DRIVE_SY * drive_scale
		if absf(drive[s]) > 0.001:
			awake = true


## Advance by `dt` seconds (fixed sub-steps; the remainder is interpolated in apply()).
func step(dt: float) -> void:
	if count == 0 or dt <= 0.0:
		return
	if not awake:
		_acc = 0.0
		return
	_acc += dt
	var steps := 0
	while _acc >= H and steps < MAX_STEPS:
		_acc -= H
		steps += 1
		for s in count:
			prev_val[s] = val[s]
			var k := rig.spring_k[s]
			var c := rig.spring_c[s]
			var v := vel[s] + (-k * val[s] - c * vel[s] + drive[s]) * H
			var x := val[s] + v * H
			var cl := rig.spring_clamp[s]
			if x > cl:
				x = cl
				v = minf(v, 0.0)
			elif x < -cl:
				x = -cl
				v = maxf(v, 0.0)
			val[s] = x
			vel[s] = v
	if steps >= MAX_STEPS:
		_acc = 0.0
	var rest := true
	for s2 in count:
		var tol := REST_ROT if rig.spring_channel[s2] == RigDef.SPRING_ROT else REST_SY
		if absf(val[s2]) > tol or absf(vel[s2]) > tol * 20.0 or absf(drive[s2]) > 0.001:
			rest = false
			break
	if rest:
		val.fill(0.0)
		vel.fill(0.0)
		prev_val.fill(0.0)
		awake = false


## Current (interpolated) value of spring `s`.
func value(s: int) -> float:
	var a := clampf(_acc / H, 0.0, 1.0)
	return lerpf(prev_val[s], val[s], a)


## Adds every spring into `pose` (rot += deg; sy × (1 + v), sx ÷ (1 + v)).
func apply(pose: PackedFloat32Array) -> void:
	if not awake:
		return
	for s in count:
		var b := RigDef.ROOT_CH + rig.spring_part[s] * RigDef.STRIDE
		var v := value(s)
		if rig.spring_channel[s] == RigDef.SPRING_ROT:
			pose[b + RigDef.C_ROT] += v
		else:
			pose[b + RigDef.C_SY] *= 1.0 + v
			pose[b + RigDef.C_SX] /= 1.0 + v


## Largest |value| (degrees for rot springs, fraction for sy).
func max_abs() -> float:
	var m := 0.0
	for s in count:
		m = maxf(m, absf(val[s]))
	return m


## True when every spring is (nearly) at rest.
func settled(tol_rot: float = 0.5, tol_sy: float = 0.003) -> bool:
	for s in count:
		var tol := tol_rot if rig.spring_channel[s] == RigDef.SPRING_ROT else tol_sy
		if absf(val[s]) > tol:
			return false
	return true


static var _gains: Dictionary = {}


## Velocity per unit of first peak for a (k, c) spring from rest, measured on the SAME
## fixed-step integrator (semi-implicit Euler at 60 Hz peaks ≈ 12 % below the analytic
## x(t) = v0/ωd · e^(−ζω0 t) · sin(ωd t)), so a kick of 20 really peaks at ≈ 20. Cached.
static func kick_gain(k: float, c: float) -> float:
	var key := Vector2(k, c)
	if _gains.has(key):
		return _gains[key]
	var x := 0.0
	var v := 1.0
	var peak := 0.0
	for i in 600:
		v += (-k * x - c * v) * H
		x += v * H
		if x < peak:
			break
		peak = x
	var g := 1.0 / maxf(peak, 0.00001)
	_gains[key] = g
	return g


func _mass_dir(p: int, xf: Array[Transform2D]) -> Vector2:
	var sizes: PackedVector2Array = rig.tex_sizes[p]
	var size := sizes[0] if not sizes.is_empty() else Vector2.ZERO
	var local := size * 0.5 - rig.pivot[p]
	if local.length() < 1.0:
		local = Vector2(0, -1)
	var dirv := xf[p].basis_xform(local)
	return dirv.normalized() if dirv.length() > 0.0001 else Vector2(0, -1)
