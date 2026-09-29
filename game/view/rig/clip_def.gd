## ClipDef — one parsed clip (`data/anim/<rig>/<clip>.json`, TECH §4.8 / comedy.md §6),
## with every key resolved to a FULL pose at load, so sampling is never ambiguous.
##
## * `key_f` (ints, 60 fps), `key_pose` (full poses: pose + face preset + `set` overrides),
##   `key_ease` (RigEase ids: the curve INTO that key), `key_face` (the effective face preset
##   at that key — explicit, the pose's, or carried from the previous key).
## * `events` sorted by frame (stable), `ev_f` their frames; `beats` name → Vector2i
##   [start, end]; `marks` name → frame (`mark` events, plus `accent` = beats.accent start
##   and `release` = beats.settle end / length when not given).
## * `layer` (LAYER_BASE / LAYER_OVERLAY / LAYER_ADDITIVE), `mask` (per-part bytes for
##   overlays), `blend_in` / `blend_out` (+ whether the JSON set them), `stride_px` (walks:
##   root travel per loop), `variation`, `smear_auto`, `tags`, `is_take` (tagged `take`, or
##   an `rx_` / `sig_` clip: blinks are suppressed), `skippable`.
## Built by ClipLib; problems go to `errors` / `warnings` (the animation lint reports them).
class_name ClipDef
extends RefCounted

const LAYER_BASE := 0
const LAYER_OVERLAY := 1
const LAYER_ADDITIVE := 2
const LAYERS: PackedStringArray = ["base", "overlay", "additive"]
## The closed event vocabulary (TECH §4.8) + `spring` (a spring kick: {part, kick}).
const EVENT_TYPES: PackedStringArray = ["sfx", "voice", "laugh", "fx", "face", "cam", "shake", "hitstop",
	"slowmo", "freeze", "prop", "smear", "mark", "spring"]
const DEFAULT_BLEND := 6

var id: String = ""
var rig_id: String = ""
var path: String = ""
var raw: Dictionary = {}
var rig: RigDef
var poses: PoseLib
var loop: bool = false
var length: int = 1
var layer: int = LAYER_BASE
var mask: PackedByteArray = PackedByteArray()
var blend_in: int = DEFAULT_BLEND
var blend_out: int = DEFAULT_BLEND
var has_blend_in: bool = false
var has_blend_out: bool = false
var stride_px: float = 0.0
var beats: Dictionary = {}
var marks: Dictionary = {}
var key_f: PackedInt32Array = PackedInt32Array()
var key_pose: Array[PackedFloat32Array] = []
var key_pose_name: PackedStringArray = PackedStringArray()
var key_ease: PackedInt32Array = PackedInt32Array()
var key_face: PackedStringArray = PackedStringArray()
var key_face_explicit: PackedByteArray = PackedByteArray()
var key_set: Array[Dictionary] = []
var events: Array[Dictionary] = []
var ev_f: PackedInt32Array = PackedInt32Array()
var time_jitter: float = 0.0
var rot_jitter: float = 0.0
var smear_auto: bool = false
var tags: PackedStringArray = PackedStringArray()
var is_take: bool = false
var skippable: bool = false
## Plant lock (`"plant": true`): feet planted on the floor at two neighbouring keys are held
## there exactly by a 2-bone IK while the clip interpolates between them (no sliding or
## sinking between planted keys, even under squash). Per key × foot:
var plant: bool = false
var plant_on: PackedByteArray = PackedByteArray()
var plant_pos: PackedVector2Array = PackedVector2Array()
var plant_rot: PackedFloat32Array = PackedFloat32Array()
var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()


## The clip's short name ("rx_take" for "_mannequin/rx_take").
func short_name() -> String:
	return id.get_slice("/", 1) if id.contains("/") else id


## Beat [start, end] (Vector2i(-1, -1) when absent).
func beat(name: String) -> Vector2i:
	return beats.get(name, Vector2i(-1, -1))


## Frame of a mark (-1 when absent).
func mark(name: String) -> int:
	return int(marks.get(name, -1))


## True for reaction clips (`rx_` / `sig_`), whose timing the sim trusts.
func is_reaction() -> bool:
	var s := short_name()
	return s.begins_with("rx_") or s.begins_with("sig_")


## Index of the key at frame `f` (-1 when no key sits exactly there).
func key_at(f: int) -> int:
	var i := key_f.bsearch(f, true)
	return i if i < key_f.size() and key_f[i] == f else -1


## True when frame `f` is within `tol` frames of a key.
func near_key(f: int, tol: int = 0) -> bool:
	for k in key_f:
		if absi(k - f) <= tol:
			return true
	return false
