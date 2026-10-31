## CastProxy2D — draws a 3D cast member inside the 2D stage, behind RigPlayer's own interface.
##
## The view is mid-pivot: the house, HUD and FX are still 2D (REDESIGN_3D R1 rebuilds those), but
## the cast is 3D now. Rather than wait for the whole view to be rebuilt before anyone can see the
## new characters in a real Night, this renders each character into its own SubViewport and shows
## the result as a sprite exactly where the 2D rig used to stand.
##
## `CharacterView` talks to its rig through a duck-typed interface and checks each method with
## `has_method` first, so a backend only has to implement what it can honour; everything else is
## skipped. This implements the parts that decide what you SEE — clip, facing, speed, frame locks,
## face and tint — and deliberately leaves the 2D-cutout-specific ones (part textures, socket
## transforms) unimplemented so CharacterView routes around them.
##
## Scale: the sim works in px, the 3D cast in metres, at REDESIGN_3D §5.5's 1 m = 200 sim px. The
## camera is orthographic so that ratio is exact and constant — a perspective camera would make a
## character's size depend on where it stood in the viewport.
##
## This is a bridge, not the destination: at R1 the set becomes 3D and the characters move into the
## shared world, at which point this file goes away.
class_name CastProxy2D
extends Node2D

const PX_PER_M := 200.0
## Viewport box per character, in px. Generous enough for arms out and a prop overhead.
const VP := Vector2i(420, 620)
## Vertical extent the orthographic camera sees, in metres.
const CAM_HEIGHT_M := 2.9
## Body yaw either side of straight-to-camera: the "cheat out" of REDESIGN_3D §5.1, so a painted
## face never goes edge-on while the walk direction still reads.
const CHEAT_YAW := 52.0

signal clip_event(ev: Dictionary)

## Mirrors of RigPlayer's probed properties, so CharacterView's "did it load" check passes.
var rig: Variant = null
var poses: Variant = null
var atlas: Variant = null
var self_hitstop := false
var time_scale := 1.0

var character: Character3D = null
var _vp: SubViewport = null
var _sprite: Sprite2D = null
var _facing := 1
var _external_frame := -1.0


## True when the 3D cast is the active backend. Off by default: the 2D rig is still what the whole
## test suite and every review shot of the house assume. Turn it on with `--cast3d` on the command
## line, or `MND_CAST3D=1` in the environment for a whole shell session.
static func enabled() -> bool:
	if OS.get_cmdline_user_args().has("--cast3d") or OS.get_cmdline_args().has("--cast3d"):
		return true
	return OS.get_environment("MND_CAST3D") == "1"


## Build the viewport, camera and character. Returns false when the 3D cast is unavailable, and
## CharacterView falls back to the 2D rig exactly as if this backend did not exist.
func setup(rig_id: String, _skin: String = "") -> bool:
	var c := Character3D.new()
	if not c.setup(rig_id):
		c.free()
		return false
	character = c

	_vp = SubViewport.new()
	_vp.size = VP
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	_vp.disable_3d = false
	add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS      # transparent, with ambient for the toon shader
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	_vp.add_child(env)
	_vp.add_child(character)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_HEIGHT_M
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 20.0
	# Dead side-on, centred on the character's mid-height.
	cam.position = Vector3(0, CAM_HEIGHT_M * 0.5, 6.0)
	_vp.add_child(cam)
	cam.look_at(Vector3(0, CAM_HEIGHT_M * 0.5, 0), Vector3.UP)
	cam.make_current()

	character.base_position = Vector3.ZERO
	character.floor_y = 0.0
	character.set_manual(true)      # CharacterView owns the clock

	# One sprite showing the viewport, scaled so metres land on sim px, anchored at the feet.
	_sprite = Sprite2D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.centered = true
	var px_per_m_vp := float(VP.y) / CAM_HEIGHT_M
	var s := PX_PER_M / px_per_m_vp
	_sprite.scale = Vector2(s, s)
	# The camera's centre sits at CAM_HEIGHT_M/2 above the floor, and this node sits AT the floor.
	_sprite.position = Vector2(0, -CAM_HEIGHT_M * 0.5 * PX_PER_M)
	add_child(_sprite)

	character.clip_event.connect(func(ev: Dictionary) -> void: clip_event.emit(ev))
	rig = character.rig3d
	poses = character.rig3d
	atlas = _vp
	set_facing(1, false)
	return true


func _process(delta: float) -> void:
	if character == null:
		return
	if _external_frame >= 0.0:
		return                      # frame-locked: set_external_frame drives it
	character.advance(delta * time_scale)


# --- the RigPlayer interface CharacterView uses --------------------------------------------------

func play(clip_id: String, opts: Dictionary = {}) -> void:
	if character == null:
		return
	_external_frame = -1.0
	character.play(clip_id, opts)


## Reactions and one-shots are frame-locked to the sim tick, so the view never drifts from the
## logic that scored them.
func set_external_frame(f: float) -> void:
	if character == null:
		return
	_external_frame = f
	character.seek_frame(f)


func current_frame() -> float:
	return character.frame() if character != null else 0.0


func set_speed(px_per_s: float) -> void:
	if character != null:
		character.set_speed(px_per_s)


## `animate` is ignored: a 3D body turns by yawing, which is already continuous.
func set_facing(dir: int, _animate: bool = true) -> void:
	_facing = -1 if dir < 0 else 1
	if character != null:
		character.rotation.y = deg_to_rad(-CHEAT_YAW * _facing)


func set_face(preset: String) -> void:
	if character != null:
		character.set_face(preset)


func set_tint_tier(tier: int) -> void:
	if character != null:
		character.set_temper(clampf(float(tier) / 4.0, 0.0, 1.0))


func look_toward(_world_pos: Vector2, _weight: float = 1.0) -> void:
	pass        # head aim lands with the face cards


func height_px() -> float:
	if character == null or character.rig3d == null:
		return 320.0
	return character.rig3d.height_m * PX_PER_M
