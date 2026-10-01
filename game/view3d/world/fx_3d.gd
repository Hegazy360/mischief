## Fx3D — the 3D particle bursts (brief r3d-view3d §4.6): one pool of CPUParticles3D (≤ 8 emitters, `fixed_fps` 30,
## one-shot bursts) with vinyl quads (fx_toon, billboarded): dust, pepper, sparkles, notes, drops, roses, onions,
## steam, stars. `burst(id, at)` reuses the oldest emitter; nothing is allocated after `_ready`. Visual layer 5
## MAIN_ONLY (the Bellows window never shows them).
class_name Fx3D
extends Node3D

const MAX_EMITTERS := 8
## The music-note glyph (white, navy ink) the note kinds draw instead of a disc (r3d-fix-gags: dots read as smoke).
const NOTE_TEX := "res://art/fx/particles/note.svg"
## id → [colour, amount, lifetime, speed, size, gravity y, spread deg, emissive, (texture path)]
const KINDS := {
	"dust": [Color("#D8CBB4"), 10, 0.5, 1.0, 0.08, -1.0, 70.0, 0.0],
	"pepper": [Color("#3B2F2A"), 16, 0.6, 1.4, 0.035, -3.0, 40.0, 0.0],
	"pepper_shake": [Color("#3B2F2A"), 12, 0.5, 0.6, 0.03, -4.0, 20.0, 0.0],
	"sparkles": [Color("#FFE38A"), 10, 0.6, 1.3, 0.07, 0.5, 180.0, 1.0],
	"notes": [Color.WHITE, 5, 1.0, 0.7, 0.13, 0.6, 50.0, 0.0, NOTE_TEX],
	"drops": [Color("#5CB8FF"), 14, 0.6, 2.0, 0.05, -6.0, 60.0, 0.0],
	"roses": [Color("#D8263A"), 12, 1.2, 2.4, 0.09, -4.0, 45.0, 0.0],
	"onions": [Color("#F4EFE6"), 8, 0.9, 2.6, 0.08, -7.0, 70.0, 0.0],
	"steam": [Color(1, 1, 1, 0.8), 8, 1.1, 0.5, 0.14, 1.0, 25.0, 1.0],
	"stars": [Color("#FFD23F"), 6, 1.2, 0.8, 0.09, 0.0, 180.0, 1.0],
	"choo_puff": [Color("#F7F4EE"), 14, 0.7, 2.2, 0.16, 0.3, 35.0, 0.0],
	## r3d-fix-gags: a jet of big notes out of the gramophone's horn (the record running away, Q-G1)
	"note_jet": [Color.WHITE, 8, 1.1, 2.4, 0.2, 0.2, 16.0, 0.0, NOTE_TEX],
	## r3d-fix-gags: his warm-up note flying across the room to the vase (Q-G4): few, big, straight, slow to fade
	"note_fly": [Color.WHITE, 3, 1.6, 2.0, 0.2, 0.05, 6.0, 0.0, NOTE_TEX],
	## r3d-fix-gags: the squeak's yellow burst out of Clarence's beak (Q-G5 / Q-V1: the toy and the noise read)
	"squeak_puff": [Color("#FFD23F"), 12, 0.45, 2.2, 0.08, 0.0, 75.0, 1.0],
	## r3d-fix-gags: the door-frame bonk's contact (Q-G2): a big plaster puff off the frame and big stars
	## r3d-fix-gags: the top's dust ring at his toe while he spins (Q-G1: the spin reads in a still frame)
	"spin_dust": [Color("#E9DCC4"), 10, 0.45, 1.9, 0.11, -0.4, 88.0, 0.0],
	"bonk_dust": [Color("#EFE6D2"), 12, 0.55, 1.5, 0.16, -0.6, 55.0, 0.0],
	"bonk_stars": [Color("#FFD23F"), 7, 1.3, 0.9, 0.15, 0.0, 180.0, 1.0],
}

var _emitters: Array[CPUParticles3D] = []
var _mats: Dictionary = {}
var _next := 0
var bursts: int = 0


func _init() -> void:
	name = "Fx3D"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i in MAX_EMITTERS:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.fixed_fps = 30
		p.mesh = quad
		p.layers = View3DConst.MASK_MAIN_ONLY
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.local_coords = false
		add_child(p)
		_emitters.append(p)
	for id in KINDS:
		var k: Array = KINDS[id]
		var m := ShaderMaterial.new()
		m.shader = load(View3DConst.SH_FX)
		m.set_shader_parameter("albedo_color", k[0])
		m.set_shader_parameter("billboard", true)
		var tex_path := str(k[8]) if k.size() > 8 else ""
		if tex_path != "" and ResourceLoader.exists(tex_path):
			m.set_shader_parameter("tex", load(tex_path))
			m.set_shader_parameter("round_disc", false)
		else:
			m.set_shader_parameter("round_disc", true)
		m.set_shader_parameter("emissive", k[7])
		_mats[id] = m
		MaterialWarm3D.register(m, &"fx")


## One burst of `id` at the world point `at` (unknown ids play `sparkles`). `dir` biases the direction.
func burst(id: String, at: Vector3, dir: Vector3 = Vector3.UP) -> void:
	var key := id if KINDS.has(id) else "sparkles"
	var k: Array = KINDS[key]
	var p := _emitters[_next]
	_next = (_next + 1) % MAX_EMITTERS
	p.emitting = false
	p.amount = int(k[1])
	p.lifetime = float(k[2])
	p.initial_velocity_min = float(k[3]) * 0.6
	p.initial_velocity_max = float(k[3])
	p.scale_amount_min = float(k[4]) * 0.7
	p.scale_amount_max = float(k[4])
	p.gravity = Vector3(0.0, float(k[5]), 0.0)
	p.spread = float(k[6])
	p.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	p.material_override = _mats[key]
	if p.is_inside_tree():
		p.global_position = at
	else:
		p.position = at
	p.restart()
	p.emitting = true
	bursts += 1


## Emitters currently emitting (≤ 8, the budget).
func live_emitters() -> int:
	var n := 0
	for p in _emitters:
		if p.emitting:
			n += 1
	return n


func advance(_dt: float) -> void:
	pass


func clear() -> void:
	for p in _emitters:
		p.emitting = false
