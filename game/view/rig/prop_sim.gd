## PropSim — the rig's socketed props (TECH §5.3): attach / detach / state, and a
## deterministic ballistic `launch` with spin and floor bounces. No physics engine: a
## launched prop's pose is a CLOSED-FORM function of the frames since launch, so seeking a
## sim-locked reaction (or replaying it) puts the teacup in exactly the same place.
##
## Positions are in character space (feet origin, y down, art facing right); `floor_y` is
## the floor line (0) and a prop rests when its lowest point (`radius` below its pivot)
## reaches it. Each bounce keeps RESTITUTION of the vertical speed and FRICTION of the
## horizontal speed and halves the spin; after MAX_BOUNCES it lies still.
class_name PropSim
extends RefCounted

const GRAVITY := 2600.0
const RESTITUTION := 0.42
const FRICTION := 0.6
const SPIN_KEEP := 0.5
const MAX_BOUNCES := 2
const MIN_BOUNCE_VY := 120.0

const ATTACHED := 0
const HIDDEN := 1
const FLYING := 2
const LOOSE := 3

var rig: RigDef
var count: int = 0
## ATTACHED / HIDDEN / FLYING / LOOSE per prop.
var mode: PackedInt32Array = PackedInt32Array()
## Texture state index per prop (into RigDef.RigProp.states).
var state: PackedInt32Array = PackedInt32Array()
## Socket index per prop while attached.
var socket: PackedInt32Array = PackedInt32Array()
var launch_f: PackedFloat32Array = PackedFloat32Array()
var p0: PackedVector2Array = PackedVector2Array()
var v0: PackedVector2Array = PackedVector2Array()
var rot0: PackedFloat32Array = PackedFloat32Array()
var spin: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
## LOOSE props: where they were put down.
var loose_xf: Array[Transform2D] = []


## Bind to a rig: every prop attached to its socket in its default state.
func setup(rig_def: RigDef) -> void:
	rig = rig_def
	count = rig.props.size()
	mode.resize(count)
	state.resize(count)
	socket.resize(count)
	launch_f.resize(count)
	p0.resize(count)
	v0.resize(count)
	rot0.resize(count)
	spin.resize(count)
	radius.resize(count)
	loose_xf.resize(count)
	reset()


## Back to the rig defaults.
func reset() -> void:
	for i in count:
		var pr: RigDef.RigProp = rig.props[i]
		mode[i] = ATTACHED if pr.socket_i >= 0 and not pr.hidden else HIDDEN
		state[i] = pr.default_state
		socket[i] = pr.socket_i
		launch_f[i] = 0.0
		p0[i] = Vector2.ZERO
		v0[i] = Vector2.ZERO
		rot0[i] = 0.0
		spin[i] = 0.0
		var sz: Vector2 = pr.state_sizes[pr.default_state] if not pr.state_sizes.is_empty() else Vector2(40, 40)
		radius[i] = maxf(sz.x, sz.y) * 0.5
		loose_xf[i] = Transform2D.IDENTITY


## Prop index by id (-1 unknown).
func index_of(prop_id: String) -> int:
	return int(rig.prop_index.get(prop_id, -1)) if rig != null else -1


## Set a prop's texture state by name ("hidden" hides it, "shown" re-attaches it).
func set_state(i: int, state_name: String) -> void:
	if i < 0 or i >= count:
		return
	if state_name == "hidden":
		mode[i] = HIDDEN
		return
	if state_name == "shown":
		if mode[i] == HIDDEN:
			mode[i] = ATTACHED if socket[i] >= 0 else HIDDEN
		return
	var si := (rig.props[i] as RigDef.RigProp).states.find(state_name)
	if si >= 0:
		state[i] = si
		if mode[i] == HIDDEN and socket[i] >= 0:
			mode[i] = ATTACHED


## Attach to a socket ("part:socket"; "" = the prop's own socket).
func attach(i: int, socket_name: String = "") -> void:
	if i < 0 or i >= count:
		return
	var s := rig.socket_index(socket_name) if socket_name != "" else (rig.props[i] as RigDef.RigProp).socket_i
	if s >= 0:
		socket[i] = s
		mode[i] = ATTACHED


## Put the prop down at transform `xf` (character space).
func detach(i: int, xf: Transform2D) -> void:
	if i < 0 or i >= count:
		return
	loose_xf[i] = xf
	mode[i] = LOOSE


## Launch from pose `start` (character space; its origin = the prop pivot) at `frame` with
## velocity `vel` (px/s, art facing right) and `spin_deg` (°/s).
func launch(i: int, frame: float, start: Transform2D, vel: Vector2, spin_deg: float) -> void:
	if i < 0 or i >= count:
		return
	mode[i] = FLYING
	launch_f[i] = frame
	p0[i] = start.origin
	rot0[i] = rad_to_deg(start.get_rotation())
	v0[i] = vel
	spin[i] = spin_deg


## Transform of a FLYING prop at `frame` (closed form), else its loose transform.
func flying_xf(i: int, frame: float) -> Transform2D:
	if mode[i] == LOOSE:
		return loose_xf[i]
	var t := maxf(0.0, (frame - launch_f[i]) / 60.0)
	var out := ballistic(p0[i], v0[i], rot0[i], spin[i], t, -radius[i])
	return Transform2D(deg_to_rad(out.z), Vector2(out.x, out.y))


## Closed-form ballistic pose at time `t` (s) from (p, v, rot°, spin°/s) with floor bounces
## at y = floor_y (the pivot's lowest allowed y). Returns Vector3(x, y, rot°). Pure.
static func ballistic(p: Vector2, v: Vector2, rot: float, spin_d: float, t: float, floor_y: float) -> Vector3:
	var pos := p
	var vel := v
	var r := rot
	var sp := spin_d
	var left := t
	for b in MAX_BOUNCES + 1:
		# Time to reach the floor: pos.y + vel.y·τ + ½gτ² = floor_y.
		var a := 0.5 * GRAVITY
		var bb := vel.y
		var c := pos.y - floor_y
		var disc := bb * bb - 4.0 * a * c
		var tau := INF
		if disc >= 0.0:
			var root := (-bb + sqrt(disc)) / (2.0 * a)
			if root > 0.00001:
				tau = root
		if left <= tau:
			return Vector3(pos.x + vel.x * left, pos.y + vel.y * left + a * left * left, r + sp * left)
		pos = Vector2(pos.x + vel.x * tau, floor_y)
		r += sp * tau
		var vy := vel.y + GRAVITY * tau
		left -= tau
		if b >= MAX_BOUNCES or vy * RESTITUTION < MIN_BOUNCE_VY:
			return Vector3(pos.x, floor_y, r)
		vel = Vector2(vel.x * FRICTION, -vy * RESTITUTION)
		sp *= SPIN_KEEP
	return Vector3(pos.x, floor_y, r)
