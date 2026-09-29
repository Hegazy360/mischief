## FxParticlePool — pooled CPUParticles2D bursts (TECH §5.7, §9): dust, flour, feathers,
## drops, steam, sparkles, notes, roses. At most MAX_EMITTERS emitters and PARTICLE_BUDGET
## live particles; `fixed_fps = 30`; one-shot + `restart()`. Ramps and curves are built once
## at warm-up, so a burst allocates no Objects. Particles stay on visibility layer 1 so a
## payoff in the Gag-Cam PiP still flies.
class_name FxParticlePool
extends Node2D

const MAX_EMITTERS := 8
const PARTICLE_BUDGET := 300

## kind → look. speed / scale are [min, max]; grav px/s² (y down); spread degrees.
const LOOKS := {
	"dust": {"life": 0.7, "speed": [70, 200], "spread": 80, "grav": -60, "scale": [0.4, 0.8], "spin": 90, "damp": 140,
		"colors": ["#E8DCC8", "#CFC3AE", "#FFF4E0"], "amount": 14, "grow": true},
	"flour": {"life": 1.3, "speed": [90, 340], "spread": 120, "grav": 110, "scale": [0.25, 0.65], "spin": 0, "damp": 170,
		"colors": ["#FFFFFF", "#F4F1EA", "#FFFDF5"], "amount": 44, "grow": true},
	"feathers": {"life": 1.9, "speed": [120, 380], "spread": 160, "grav": 80, "scale": [0.4, 0.7], "spin": 260, "damp": 190,
		"colors": ["#FFFFFF", "#FFF4E0", "#F3EAD6"], "amount": 24, "grow": false},
	"drops": {"life": 0.9, "speed": [240, 560], "spread": 70, "grav": 1400, "scale": [0.28, 0.5], "spin": 0, "damp": 0,
		"colors": ["#7CC6F2", "#3AA7E0", "#BDE6FF"], "amount": 26, "grow": false, "align": true},
	"steam": {"life": 1.1, "speed": [60, 170], "spread": 40, "grav": -170, "scale": [0.45, 0.95], "spin": 30, "damp": 60,
		"colors": ["#FFFFFF", "#EEF4F8"], "amount": 12, "grow": true},
	"sparkles": {"life": 0.7, "speed": [120, 400], "spread": 180, "grav": 220, "scale": [0.28, 0.55], "spin": 360, "damp": 200,
		"colors": ["#FFD23F", "#FFFFFF", "#E8B33A"], "amount": 18, "grow": false},
	"notes": {"life": 1.3, "speed": [80, 210], "spread": 60, "grav": -130, "scale": [0.4, 0.6], "spin": 70, "damp": 20,
		"colors": ["#7B3F8C", "#2B3566", "#E8B33A"], "amount": 8, "grow": false},
	"roses": {"life": 1.8, "speed": [220, 500], "spread": 45, "grav": 900, "scale": [0.5, 0.75], "spin": 300, "damp": 10,
		"colors": ["#FFFFFF"], "amount": 12, "grow": false},
}

var reduce_motion: bool = false
## Multiplied into every burst's amount (reduce-flash / low-end phones).
var amount_scale: float = 1.0
var _emitters: Array[CPUParticles2D] = []
var _next := 0
var _ramps: Dictionary = {}
var _fade: Gradient = null
var _grow: Curve = null
var _flat: Curve = null


func _init() -> void:
	name = "Particles"
	z_index = 30


func _ready() -> void:
	warm()


## Build the emitters, ramps and curves (idempotent).
func warm() -> void:
	if not _emitters.is_empty():
		return
	_fade = Gradient.new()
	_fade.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	_fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_grow = Curve.new()
	_grow.add_point(Vector2(0.0, 0.6))
	_grow.add_point(Vector2(1.0, 1.3))
	_flat = Curve.new()
	_flat.add_point(Vector2(0.0, 1.0))
	_flat.add_point(Vector2(1.0, 1.0))
	for kind in LOOKS:
		var cols: Array = LOOKS[kind]["colors"]
		var g := Gradient.new()
		var offs := PackedFloat32Array()
		var cs := PackedColorArray()
		var n := cols.size()
		for i in n:
			offs.append(float(i) / float(n))
			cs.append(Color(String(cols[i])))
			offs.append(float(i + 1) / float(n) - 0.0001)
			cs.append(Color(String(cols[i])))
		g.offsets = offs
		g.colors = cs
		_ramps[kind] = g
		FxArt.particle(kind)
	for i in MAX_EMITTERS:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.fixed_fps = 30
		p.local_coords = false
		p.explosiveness = 0.9
		p.randomness = 0.4
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 14.0
		p.color_ramp = _fade
		_emitters.append(p)
		add_child(p)


## One-shot burst of `kind` at `world_pos`. `amount` < 0 = the kind's default. Returns the
## particle count granted (0 when over budget or unknown).
func burst(kind: String, world_pos: Vector2, amount: int = -1, dir: Vector2 = Vector2.UP) -> int:
	if not LOOKS.has(kind):
		return 0
	warm()
	var look: Dictionary = LOOKS[kind]
	var want := int(round(float(amount if amount > 0 else int(look["amount"])) * amount_scale))
	# Prefer an idle emitter; else recycle the oldest (round-robin).
	var idx := -1
	for i in MAX_EMITTERS:
		var j := (_next + i) % MAX_EMITTERS
		if not _emitters[j].emitting:
			idx = j
			break
	if idx < 0:
		idx = _next
	_next = (idx + 1) % MAX_EMITTERS
	var p := _emitters[idx]
	p.emitting = false
	var room := PARTICLE_BUDGET - live_particles()
	var n := mini(want, room)
	if n < 2:
		return 0
	p.texture = FxArt.particle(kind)
	p.amount = n
	p.lifetime = float(look["life"])
	p.direction = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	p.spread = float(look["spread"])
	var sp: Array = look["speed"]
	p.initial_velocity_min = float(sp[0])
	p.initial_velocity_max = float(sp[1])
	p.gravity = Vector2(0.0, float(look["grav"]))
	var sc: Array = look["scale"]
	p.scale_amount_min = float(sc[0])
	p.scale_amount_max = float(sc[1])
	p.scale_amount_curve = _grow if bool(look.get("grow", false)) else _flat
	var spin := float(look["spin"])
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	var align := bool(look.get("align", false))
	p.particle_flag_align_y = align
	p.angle_min = 0.0 if align else -180.0
	p.angle_max = 0.0 if align else 180.0
	p.damping_min = float(look["damp"]) * 0.6
	p.damping_max = float(look["damp"])
	p.color_initial_ramp = _ramps[kind]
	p.global_position = world_pos
	p.restart()
	p.emitting = true
	return n


## Particles alive across the pool (an emitting one-shot counts fully).
func live_particles() -> int:
	var n := 0
	for q in _emitters:
		if q.emitting:
			n += q.amount
	return n


func active_emitters() -> int:
	var n := 0
	for q in _emitters:
		if q.emitting:
			n += 1
	return n


func emitter_count() -> int:
	return _emitters.size()


## Speed scale of every emitter (the view rate: slow-mo, hit-stop, freeze-frame).
func set_speed(sp: float) -> void:
	for q in _emitters:
		if q.speed_scale != sp:
			q.speed_scale = sp


## Stop everything (retry).
func clear() -> void:
	for q in _emitters:
		q.emitting = false
