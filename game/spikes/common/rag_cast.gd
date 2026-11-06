## RagCast — the SPIKE cast: a cutout character with NO keyframed clips at all (docs/review/pivot §5).
##
## Everything it does is procedural, so the motion is never the same twice and no animator is needed:
##
## * **Rendering** reuses the real `data/rigs/<id>/rig.json` and its SVG parts — textured parts are
##   Sprite2Ds pinned at their pivots, rubber-hose limbs are drawn strokes through their joints — so the
##   cast looks exactly like the game's, and only the motion is new.
## * **Active ragdoll.** Every joint is an angular spring with a `muscle` strength. At muscle 1 the
##   springs chase the procedural pose; at 0 they go limp and gravity torque swings each limb toward
##   hanging. `hit()` drops the muscle to 0, throws the body and lets it tumble; when it has lain still
##   for a moment the muscle ramps back and he scrambles up. That one number is the whole comedy.
## * **Procedural locomotion.** The walk is a sine cycle over hips, knees, arms and a waddling torso,
##   scaled by speed — no `loco_walk` clip, so any speed and any stagger works.
## * **Secondary motion.** The bouffant, cravat, coat tails, sideburns and hair are jiggle springs
##   driven by the body's own acceleration (no muscle, never posed).
##
##     var c := RagCast.new(); add_child(c); c.setup("bellows"); c.floor_y = 420.0
##     c.walk_to(1200.0)                      # procedural walk
##     c.hit(Vector2(600, -400), c.position)  # clobbered: flop, settle, get up
##
## Spike code: throwaway, not part of the game (no tests, no lints, no content).
class_name RagCast
extends Node2D

## Body modes. ANIM = the procedural pose drives everything; LIMP = free-falling ragdoll;
## GETUP = blending back up off the floor.
enum Mode { ANIM, LIMP, GETUP }

const DEG := 180.0 / PI
const GRAVITY := 2200.0
## Gravity torque on a limp limb (deg/s^2 at 90 degrees off hanging).
const LIMB_GRAVITY := 900.0
const FLOOR_BOUNCE := 0.32
const FLOOR_FRICTION := 0.74
## Per-second survival factors while limp (air drag on travel and on spin) and the spin cap.
const AIR_DRAG := 0.35
const SPIN_DRAG := 0.22
const MAX_SPIN := 520.0
## Lie still for this long before scrambling up. Short on purpose: a fall is funny, a wait is not —
## the whole knocked-flat-and-up-again beat wants to land inside about a second and a half.
const SETTLE_S := 0.34
const SETTLE_SPEED := 95.0
const GETUP_S := 0.62
## Treat the body as touching the floor for this long after the last contact.
const GROUND_COYOTE := 0.18
## Face slots that are the face proper; the rest (sweat, blush, steam, vein...) are effect overlays
## the spike never shows.
const FACE_SLOTS: PackedStringArray = ["eyes", "pupils", "brows", "mouth"]
## Parts that are always jiggle (plus anything with a `spring` block in rig.json).
const JIGGLE_PARTS: PackedStringArray = ["bouffant", "cravat", "coat_tails", "sideburn_l", "sideburn_r",
	"hair_back", "beret", "braces_loop", "braces_front"]
## Where a LIMP limb drifts (degrees): a dead cartoon splays, it does not fold into a heap. A weak
## spring to these keeps the pile readable at 50 px while gravity torque still does the flopping.
const LIMP_TARGET := {
	"arm_upper_l": 115.0, "arm_upper_r": -115.0, "arm_lower_l": 35.0, "arm_lower_r": 35.0,
	"leg_upper_l": 22.0, "leg_upper_r": -16.0, "leg_lower_l": -42.0, "leg_lower_r": -28.0,
	"head": 14.0, "torso": -10.0,
}
const LIMP_SPRING := 0.26
## Joints the muscle drives, with their spring constants and limits (degrees).
const DRIVEN := {
	"torso": {"k": 150.0, "d": 17.0, "lo": -70.0, "hi": 70.0},
	"head": {"k": 120.0, "d": 15.0, "lo": -55.0, "hi": 55.0},
	"arm_upper_l": {"k": 70.0, "d": 10.0, "lo": -170.0, "hi": 170.0},
	"arm_lower_l": {"k": 55.0, "d": 8.0, "lo": -8.0, "hi": 150.0},
	"arm_upper_r": {"k": 70.0, "d": 10.0, "lo": -170.0, "hi": 170.0},
	"arm_lower_r": {"k": 55.0, "d": 8.0, "lo": -8.0, "hi": 150.0},
	"leg_upper_l": {"k": 110.0, "d": 13.0, "lo": -110.0, "hi": 110.0},
	"leg_lower_l": {"k": 90.0, "d": 11.0, "lo": -135.0, "hi": 6.0},
	"leg_upper_r": {"k": 110.0, "d": 13.0, "lo": -110.0, "hi": 110.0},
	"leg_lower_r": {"k": 90.0, "d": 11.0, "lo": -135.0, "hi": 6.0},
	"hand_l": {"k": 45.0, "d": 7.0, "lo": -80.0, "hi": 80.0},
	"hand_r": {"k": 45.0, "d": 7.0, "lo": -80.0, "hi": 80.0},
	"foot_l": {"k": 70.0, "d": 9.0, "lo": -45.0, "hi": 55.0},
	"foot_r": {"k": 70.0, "d": 9.0, "lo": -45.0, "hi": 55.0},
}

## One simulated joint.
class Joint extends RefCounted:
	var name: String = ""
	var parent: int = -1
	var offset: Vector2 = Vector2.ZERO
	var pivot: Vector2 = Vector2.ZERO
	var z: int = 0
	var angle: float = 0.0        ## local, degrees
	var vel: float = 0.0
	var target: float = 0.0
	var k: float = 0.0
	var d: float = 0.0
	var lo: float = -1.0e9
	var hi: float = 1.0e9
	var driven: bool = false
	var jiggle: bool = false
	var sprite: Sprite2D = null
	var world_pos: Vector2 = Vector2.ZERO
	var world_rot: float = 0.0

## Rubber-hose limb drawn through its joints.
class Limb extends RefCounted:
	var idx: PackedInt32Array = PackedInt32Array()
	var width: float = 24.0
	var fill: Color = Color.WHITE
	var ink: Color = Color("#1B2340")
	var outline: float = 6.0
	var z: int = 0
	var node: Node2D = null

## Floor line in this node's parent space.
var floor_y: float = 0.0
## 1 = facing right (art default), -1 = left.
var facing: int = 1
## 0 limp .. 1 fully driven.
var muscle: float = 1.0
var mode: int = Mode.ANIM
## Height of the root joint above the feet when standing.
var stand_h: float = 65.0
## Set by the owner each frame: the procedural pose to chase ("idle", "walk", "carry", "blind", "getup").
var pose: String = "idle"
## Walk speed in px/s (drives the cycle rate).
var speed: float = 0.0
var vel: Vector2 = Vector2.ZERO
var ang_vel: float = 0.0
var root_rot: float = 0.0
## True once the body has come to rest while limp.
var settled: bool = false

var _joints: Array[Joint] = []
var _by_name: Dictionary = {}
var _limbs: Array[Limb] = []
var _root: int = -1
var _rig: Dictionary = {}
var _phase: float = 0.0
var _t: float = 0.0
var _still_t: float = 0.0
var _getup_t: float = 0.0
var _limp_t: float = 0.0
## Time since the body last touched the floor. Settling on a per-frame contact flag never works: as he
## rotates into his lying pose the contact point keeps changing, so contact flickers on and off and the
## still-timer resets for ever. A short coyote window fixes it.
var _air_t: float = 0.0
var _face: Dictionary = {}
var _face_slots: Dictionary = {}
var _prev_vel: Vector2 = Vector2.ZERO
## Extra world-space acceleration fed into the jiggle springs.
var _shake: float = 0.0


## Build the cast from `data/rigs/<rig_id>/rig.json`.
func setup(rig_id: String) -> void:
	var path := "res://data/rigs/%s/rig.json" % rig_id
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("RagCast: cannot parse %s" % path)
		return
	_rig = j.data
	var parts: Dictionary = _rig.get("parts", {})
	var root_name := str(_rig.get("root_part", ""))
	# parent-first: rig.json is already authored that way
	for pname: String in parts:
		var pd: Dictionary = parts[pname]
		var jt := Joint.new()
		jt.name = pname
		jt.parent = int(_by_name.get(str(pd.get("parent", "")), -1)) if pd.has("parent") else -1
		var off: Array = pd.get("offset", [0, 0])
		jt.offset = Vector2(float(off[0]), float(off[1]))
		var pv: Array = pd.get("pivot", [0, 0])
		jt.pivot = Vector2(float(pv[0]), float(pv[1]))
		jt.z = int(pd.get("z", 0))
		if DRIVEN.has(pname) and pname != root_name:
			var cfg: Dictionary = DRIVEN[pname]
			jt.driven = true
			jt.k = float(cfg["k"])
			jt.d = float(cfg["d"])
			jt.lo = float(cfg["lo"])
			jt.hi = float(cfg["hi"])
		elif JIGGLE_PARTS.has(pname) or pd.has("spring"):
			jt.jiggle = true
			jt.k = 90.0
			jt.d = 7.0
			jt.lo = -38.0
			jt.hi = 38.0
		_by_name[pname] = _joints.size()
		_joints.append(jt)
		if pname == root_name:
			_root = _joints.size() - 1
			stand_h = -jt.offset.y
		# textured parts get a sprite; limb bones are drawn as strokes instead. Parts with texture
		# variants and no plain `file` (Hush's hands and feet) use their first variant.
		var file := str(pd.get("file", ""))
		if file == "":
			var tex: Dictionary = pd.get("tex", {})
			for tn: String in tex:
				file = str(tex[tn])
				break
		if file != "" and ResourceLoader.exists(file):
			var s := Sprite2D.new()
			s.texture = load(file)
			s.centered = false
			s.offset = -jt.pivot
			s.z_index = jt.z
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			add_child(s)
			jt.sprite = s
	_build_limbs()
	_build_face()
	reset_pose()


func _build_limbs() -> void:
	var limbs: Dictionary = _rig.get("limbs", {})
	for lid: String in limbs:
		var ld: Dictionary = limbs[lid]
		var lb := Limb.new()
		for jn: String in ld.get("joints", []):
			if _by_name.has(jn):
				lb.idx.append(int(_by_name[jn]))
		if lb.idx.size() < 2:
			continue
		lb.width = float(ld.get("width", 24))
		lb.fill = Color(str(ld.get("fill", "#888888")))
		lb.ink = Color(str(ld.get("ink", "#1B2340")))
		lb.outline = float(ld.get("outline", 6))
		lb.z = _joints[lb.idx[0]].z
		var n := Node2D.new()
		n.z_index = lb.z
		n.draw.connect(_draw_limb.bind(n, lb))
		add_child(n)
		lb.node = n
		_limbs.append(lb)


## Eyes / brows / mouth as sprites on the head, so a take can change the face.
func _build_face() -> void:
	_face = _rig.get("face", {})
	if _face.is_empty():
		return
	var slots: Dictionary = _face.get("slots", {})
	for sid: String in slots:
		if not FACE_SLOTS.has(sid):
			continue
		var sd: Dictionary = slots[sid]
		var variants: Dictionary = sd.get("variants", {})
		var first := ""
		for v: String in variants:
			first = v
			break
		if first == "":
			continue
		var s := Sprite2D.new()
		s.centered = false
		var pv: Array = sd.get("pivot", [0, 0])
		s.offset = -Vector2(float(pv[0]), float(pv[1]))
		s.z_index = int(sd.get("z", 40))
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.texture = load(str(variants[first])) if ResourceLoader.exists(str(variants[first])) else null
		add_child(s)
		_face_slots[sid] = {"node": s, "variants": variants}
	_set_slot("pupils", "centre")
	set_face("open", "neutral", "smile")


## Swap a face slot's variant by name ("spiral" eyes, "O" mouth, ...). Unknown names are ignored.
func set_face(eyes: String = "", brows: String = "", mouth: String = "") -> void:
	_set_slot("eyes", eyes)
	_set_slot("brows", brows)
	_set_slot("mouth", mouth)


func _set_slot(slot: String, variant: String) -> void:
	if variant == "" or not _face_slots.has(slot):
		return
	var d: Dictionary = _face_slots[slot]
	var variants: Dictionary = d["variants"]
	if not variants.has(variant):
		return
	var p := str(variants[variant])
	if ResourceLoader.exists(p):
		(d["node"] as Sprite2D).texture = load(p)


## Stand upright in the rest pose.
func reset_pose() -> void:
	for jt in _joints:
		jt.angle = 0.0
		jt.vel = 0.0
		jt.target = 0.0
	root_rot = 0.0
	vel = Vector2.ZERO
	ang_vel = 0.0
	muscle = 1.0
	mode = Mode.ANIM
	settled = false
	position.y = floor_y - stand_h


## Feet position on the floor line.
func feet() -> Vector2:
	return Vector2(position.x, floor_y)


## Clobbered: go limp, take the impulse, tumble. `kind` shapes the fall:
## "" generic, "trip" forward tumble, "slide" feet-out skid, "bonk" straight backwards.
func hit(impulse: Vector2, kind: String = "") -> void:
	mode = Mode.LIMP
	muscle = 0.0
	settled = false
	_still_t = 0.0
	_limp_t = 0.0
	vel += impulse
	var spin := signf(impulse.x) if absf(impulse.x) > 1.0 else 1.0
	match kind:
		"trip":
			ang_vel += spin * 300.0
			vel.y -= 230.0
		"slide":
			ang_vel += spin * 120.0
			vel.y -= 70.0
			vel.x += spin * 360.0
		"bonk":
			ang_vel -= spin * 260.0
			vel.y -= 300.0
		_:
			ang_vel += spin * 200.0
	_air_t = 0.0
	_shake = 1.0
	set_face("wide", "up", "O_big")   # whichever of these names the rig has
	set_face("wide", "up", "O")


## True while he is down or getting up (no walking).
func is_down() -> bool:
	return mode != Mode.ANIM


## Walk toward `x` this frame at `px_s`; returns true when he is there.
func walk_to(x: float, px_s: float) -> bool:
	if mode != Mode.ANIM:
		return false
	var dx := x - position.x
	if absf(dx) < 8.0:
		speed = 0.0
		pose = "idle"
		return true
	facing = 1 if dx > 0.0 else -1
	speed = px_s
	pose = "walk"
	position.x += signf(dx) * minf(px_s * get_physics_process_delta_time(), absf(dx))
	return false


func _physics_process(delta: float) -> void:
	if _joints.is_empty():
		return
	_t += delta
	_step_body(delta)
	_pose_targets()
	_step_joints(delta)
	_solve_transforms()
	scale.x = float(facing)
	for lb in _limbs:
		lb.node.queue_redraw()


## Root rigid body: driven while standing, free while limp, blended on the way up.
func _step_body(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.0)
	match mode:
		Mode.ANIM:
			var bob := 0.0
			var lean := 0.0
			if pose == "walk":
				bob = -absf(sin(_phase * 2.0)) * 7.0
				lean = sin(_phase * 2.0) * 3.0 + 4.0 * signf(float(facing)) * 0.0
			else:
				bob = sin(_t * 1.8) * 2.0
			position.y = lerpf(position.y, floor_y - stand_h + bob, 1.0 - pow(0.001, delta))
			root_rot = lerpf(root_rot, lean, 1.0 - pow(0.004, delta))
			vel = Vector2.ZERO
			ang_vel = 0.0
		Mode.LIMP:
			_limp_t += delta
			vel.y += GRAVITY * delta
			# air drag on both, so a throw always runs out of energy instead of spinning for ever
			vel.x *= pow(AIR_DRAG, delta)
			ang_vel = clampf(ang_vel * pow(SPIN_DRAG, delta), -MAX_SPIN, MAX_SPIN)
			position += vel * delta
			root_rot += ang_vel * delta
			_air_t = 0.0 if _collide(delta) else _air_t + delta
			var grounded := _air_t < GROUND_COYOTE
			if grounded:
				# he comes to rest LYING DOWN (nearest +-90), never balanced on his head
				var want := 90.0 * (1.0 if root_rot >= 0.0 else -1.0)
				root_rot = lerpf(root_rot, want, 1.0 - pow(0.004, delta))
				ang_vel *= pow(0.004, delta)
			if grounded and vel.length() < SETTLE_SPEED and absf(ang_vel) < 60.0 and _limp_t > 0.3:
				_still_t += delta
				if _still_t >= SETTLE_S:
					mode = Mode.GETUP
					_getup_t = 0.0
					settled = true
			else:
				_still_t = 0.0
		Mode.GETUP:
			_getup_t += delta
			var p: float = clampf(_getup_t / GETUP_S, 0.0, 1.0)
			var e := p * p * (3.0 - 2.0 * p)
			muscle = e
			vel = vel.lerp(Vector2.ZERO, e)
			ang_vel = lerpf(ang_vel, 0.0, e)
			position.y = lerpf(position.y, floor_y - stand_h, 1.0 - pow(0.02, delta))
			root_rot = lerpf(root_rot, 0.0, 1.0 - pow(0.015, delta))
			if p >= 1.0:
				mode = Mode.ANIM
				muscle = 1.0
				root_rot = 0.0
				vel = Vector2.ZERO
				ang_vel = 0.0
				set_face("open", "neutral", "smile")
				_set_slot("pupils", "centre")


## Keep the body (and roughly its head and feet) above the floor line. Returns true when touching.
func _collide(delta: float) -> bool:
	var r := stand_h * 0.72
	var deepest := position.y + r - floor_y
	for n in ["head", "foot_l", "foot_r", "hand_l", "hand_r"]:
		if not _by_name.has(n):
			continue
		var jt: Joint = _joints[int(_by_name[n])]
		deepest = maxf(deepest, position.y + jt.world_pos.y - floor_y)
	if deepest <= 0.0:
		return false
	position.y -= deepest
	if vel.y > 0.0:
		vel.y = -vel.y * FLOOR_BOUNCE
		if absf(vel.y) < 140.0:
			vel.y = 0.0
	vel.x *= FLOOR_FRICTION
	# the floor scrubs off spin, and a sliding body picks a little up from friction
	ang_vel = ang_vel * 0.86 - vel.x * delta * 1.2
	_shake = maxf(_shake, minf(1.0, deepest * 0.05))
	return true


## The procedural pose every driven joint chases while the muscle is on.
func _pose_targets() -> void:
	for jt in _joints:
		if jt.driven:
			jt.target = 0.0
	match pose:
		"walk":
			_pose_walk()
		"carry":
			_pose_carry()
		"blind":
			_pose_blind()
		_:
			_pose_idle()
	if mode == Mode.GETUP:
		_pose_getup()


func _tgt(n: String, deg: float) -> void:
	if _by_name.has(n):
		_joints[int(_by_name[n])].target = deg


func _pose_idle() -> void:
	var b := sin(_t * 1.8)
	_tgt("arm_upper_l", 6.0 + b * 2.0)
	_tgt("arm_upper_r", -6.0 - b * 2.0)
	_tgt("arm_lower_l", 10.0)
	_tgt("arm_lower_r", 10.0)
	_tgt("head", b * 2.0)
	_tgt("torso", b * 1.2)


## A cartoon walk cycle: hips and knees on one sine, arms counter-phase, a waddling torso.
func _pose_walk() -> void:
	_phase += get_physics_process_delta_time() * maxf(2.0, speed * 0.027)
	var s := sin(_phase)
	var c := cos(_phase)
	var amp: float = clampf(speed / 260.0, 0.55, 1.7)
	_tgt("leg_upper_l", s * 34.0 * amp)
	_tgt("leg_upper_r", -s * 34.0 * amp)
	_tgt("leg_lower_l", -maxf(0.0, c) * 48.0 * amp)
	_tgt("leg_lower_r", -maxf(0.0, -c) * 48.0 * amp)
	_tgt("foot_l", maxf(0.0, s) * 16.0)
	_tgt("foot_r", maxf(0.0, -s) * 16.0)
	_tgt("arm_upper_l", -s * 26.0 * amp)
	_tgt("arm_upper_r", s * 26.0 * amp)
	_tgt("arm_lower_l", 14.0 + maxf(0.0, s) * 22.0)
	_tgt("arm_lower_r", 14.0 + maxf(0.0, -s) * 22.0)
	_tgt("torso", -sin(_phase * 2.0) * 3.5)
	_tgt("head", sin(_phase * 2.0) * 2.5)


## Both arms up, holding something over the head.
func _pose_carry() -> void:
	_pose_walk() if speed > 1.0 else _pose_idle()
	_tgt("arm_upper_l", 150.0)
	_tgt("arm_upper_r", -150.0)
	_tgt("arm_lower_l", 20.0)
	_tgt("arm_lower_r", 20.0)


## Arms groping forward (a bucket on the head).
func _pose_blind() -> void:
	_pose_walk() if speed > 1.0 else _pose_idle()
	var w := sin(_t * 5.0) * 12.0
	_tgt("arm_upper_l", 86.0 + w)
	_tgt("arm_upper_r", -86.0 + w)
	_tgt("arm_lower_l", 8.0)
	_tgt("arm_lower_r", 8.0)
	_tgt("head", sin(_t * 3.0) * 8.0)


## Pushing up off the floor.
func _pose_getup() -> void:
	var p: float = clampf(_getup_t / GETUP_S, 0.0, 1.0)
	var push := (1.0 - p)
	_tgt("arm_upper_l", 120.0 * push)
	_tgt("arm_upper_r", -120.0 * push)
	_tgt("arm_lower_l", 70.0 * push)
	_tgt("arm_lower_r", 70.0 * push)
	_tgt("leg_upper_l", -40.0 * push)
	_tgt("leg_upper_r", -25.0 * push)
	_tgt("leg_lower_l", -70.0 * push)
	_tgt("leg_lower_r", -50.0 * push)
	_tgt("torso", 26.0 * push)
	_tgt("head", -18.0 * push)


## Integrate every joint: muscle spring toward the pose, gravity torque when limp, limits.
func _step_joints(delta: float) -> void:
	# world rotations first, so gravity torque knows which way each limb points
	for i in _joints.size():
		var jt: Joint = _joints[i]
		var pr := root_rot if i == _root else (_joints[jt.parent].world_rot if jt.parent >= 0 else 0.0)
		jt.world_rot = pr + jt.angle
	var accel := (vel - _prev_vel) / maxf(delta, 0.0001)
	_prev_vel = vel
	for i in _joints.size():
		var jt: Joint = _joints[i]
		if i == _root or (not jt.driven and not jt.jiggle):
			continue
		var torque := 0.0
		if jt.driven:
			torque += muscle * jt.k * (jt.target - jt.angle)
			var limp := 1.0 - muscle
			# limp limbs swing toward hanging straight down (local +y is along the bone)...
			torque += limp * -LIMB_GRAVITY * sin(jt.world_rot / DEG)
			# ...but keep a little tone, so he lands splayed and readable instead of folded up
			torque += limp * jt.k * LIMP_SPRING * (float(LIMP_TARGET.get(jt.name, 0.0)) - jt.angle)
			torque -= jt.d * jt.vel * (0.35 + 0.65 * muscle)
		else:
			# jiggle: a soft spring to rest, kicked by the body's own acceleration and by impacts
			torque += jt.k * (0.0 - jt.angle) - jt.d * jt.vel
			torque += -accel.x * 0.05 * float(facing) - _shake * 220.0 * sin(_t * 31.0 + float(i))
		jt.vel += torque * delta
		jt.vel = clampf(jt.vel, -1600.0, 1600.0)
		jt.angle += jt.vel * delta
		if jt.angle < jt.lo:
			jt.angle = jt.lo
			jt.vel = absf(jt.vel) * 0.25
		elif jt.angle > jt.hi:
			jt.angle = jt.hi
			jt.vel = -absf(jt.vel) * 0.25


## Walk the hierarchy and place every sprite.
func _solve_transforms() -> void:
	for i in _joints.size():
		var jt: Joint = _joints[i]
		if i == _root:
			jt.world_pos = Vector2.ZERO
			jt.world_rot = root_rot
		else:
			var p: Joint = _joints[jt.parent]
			jt.world_pos = p.world_pos + jt.offset.rotated(p.world_rot / DEG)
			jt.world_rot = p.world_rot + jt.angle
		if jt.sprite != null:
			jt.sprite.position = jt.world_pos
			jt.sprite.rotation = jt.world_rot / DEG
	_place_face()


func _place_face() -> void:
	if _face.is_empty() or not _by_name.has(str(_face.get("anchor", "head"))):
		return
	var head: Joint = _joints[int(_by_name[str(_face.get("anchor", "head"))])]
	var off: Array = _face.get("offset", [0, 0])
	var fo := Vector2(float(off[0]), float(off[1]))
	var p := head.world_pos + fo.rotated(head.world_rot / DEG)
	for sid: String in _face_slots:
		var s: Sprite2D = (_face_slots[sid] as Dictionary)["node"]
		s.position = p
		s.rotation = head.world_rot / DEG


func _draw_limb(n: Node2D, lb: Limb) -> void:
	var pts := PackedVector2Array()
	for i in lb.idx:
		pts.append(_joints[i].world_pos)
	if pts.size() < 2:
		return
	var w := lb.width
	# ink underlay, then the fill, with round caps at every joint
	for pass_i in 2:
		var col := lb.ink if pass_i == 0 else lb.fill
		var ww := w + lb.outline * 2.0 if pass_i == 0 else w
		for i in pts.size() - 1:
			n.draw_line(pts[i], pts[i + 1], col, ww)
		for p in pts:
			n.draw_circle(p, ww * 0.5, col)
