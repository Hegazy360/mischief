## PropSim3D — the deterministic ballistic flight of a launched prop (a port of the 2D `prop_sim.gd` to metres):
## no physics engine, the pose is a CLOSED-FORM function of the time since launch, so seeking a sim-locked
## reaction (or replaying it) puts the teacup in exactly the same place. Gravity 9.8 × 1.6 (comedy), a floor bounce
## keeping RESTITUTION of the vertical speed (FRICTION of the horizontal), spin halves per bounce, still after
## MAX_BOUNCES. Spin is about the screen-plane axis (world z). Pure.
class_name PropSim3D
extends RefCounted

const GRAVITY := 9.8 * 1.6
const RESTITUTION := 0.3
const FRICTION := 0.6
const SPIN_KEEP := 0.5
const MAX_BOUNCES := 2
const MIN_BOUNCE_VY := 0.6


## World pose at `t` seconds after a launch from `start` (world transform) with velocity `vel` (m/s, world) and
## `spin_deg` (°/s about world z); the prop rests when its origin is `radius` above `floor_y`.
static func pose_at(start: Transform3D, vel: Vector3, spin_deg: float, t: float, floor_y: float, radius := 0.05) -> Transform3D:
	var r := ballistic(start.origin, vel, spin_deg, maxf(0.0, t), floor_y + radius)
	var rot := Basis(Vector3(0, 0, 1), deg_to_rad(r.w))
	return Transform3D(rot * start.basis, Vector3(r.x, r.y, r.z))


## Closed-form flight from (p, v) with floor bounces at y = floor_y (the lowest allowed origin y). Returns
## Vector4(x, y, z, spin angle °). Pure.
static func ballistic(p: Vector3, v: Vector3, spin_d: float, t: float, floor_y: float) -> Vector4:
	var pos := p
	var vel := v
	var ang := 0.0
	var sp := spin_d
	var left := t
	for b in MAX_BOUNCES + 1:
		# Time to reach the floor: pos.y + vel.y·τ − ½gτ² = floor_y.
		var a := -0.5 * GRAVITY
		var bb := vel.y
		var c := pos.y - floor_y
		var disc := bb * bb - 4.0 * a * c
		var tau := INF
		if disc >= 0.0:
			var root := (-bb - sqrt(disc)) / (2.0 * a)
			if root > 0.00001:
				tau = root
		if left <= tau:
			return Vector4(pos.x + vel.x * left, pos.y + vel.y * left + a * left * left, pos.z + vel.z * left, ang + sp * left)
		pos = Vector3(pos.x + vel.x * tau, floor_y, pos.z + vel.z * tau)
		ang += sp * tau
		var vy := vel.y - GRAVITY * tau
		left -= tau
		if b >= MAX_BOUNCES or -vy * RESTITUTION < MIN_BOUNCE_VY:
			return Vector4(pos.x, floor_y, pos.z, ang)
		vel = Vector3(vel.x * FRICTION, -vy * RESTITUTION, vel.z * FRICTION)
		sp *= SPIN_KEEP
	return Vector4(pos.x, floor_y, pos.z, ang)
