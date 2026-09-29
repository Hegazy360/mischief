## FaceState — the live face on top of the clip's keyed faces (TECH §5.3, comedy.md §5.3):
## runtime slot overrides (`set_face` / `set_slot`), seeded blinks and the pupil look.
##
## * Blinks every 2–6 s (uniform, seeded xorshift32 → the same seed blinks on the same
##   frames), 6 frames long: 2 closing (`half`), 2 closed, 2 opening; 15 % are doubles (a
##   second blink 3 frames after the first). Suppressed while `suppressed` (clips tagged
##   `take`), never over eyes that are already shut / half.
## * Overrides: `set_face(preset)` / `set_slot(slot, variant)` hold until `clear()` or the
##   clip's next keyed face change (the player calls `on_clip_face_changed()`).
## * `apply(pose)` writes overrides, the blink and the pupil offset into the face parts.
## * Pupils hide in BOTH blink phases (half and closed) and whenever the eyes variant is one
##   that bakes its own pupils (rig `face.slots.pupils.hide_with` / `eyes.no_pupils`).
## * Runtime eye changes (`set_slot("eyes", v)`, `set_face`, blinks) bring their paired lids
##   variant (rig `face.slots.eyes.lids`: Bellows' half / angry eyes).
## * The active preset's faces.json `gaze` ([dx, dy] px) is the resting pupil offset (Bellows'
##   slow burn stares at the Stalls); `look` adds on top. The active preset is the runtime
##   override (`set_face`) or the clip's keyed face (`clip_preset`, set by the player).
## Frames are 60 fps "face time" advanced by the player (view time). Allocation-free.
class_name FaceState
extends RefCounted

const BLINK_LEN := 6
const BLINK_MIN_F := 120
const BLINK_MAX_F := 360
const DOUBLE_PCT := 15
const DOUBLE_GAP := 3

var rig: RigDef
var lib: PoseLib
var suppressed: bool = false
var blinks_enabled: bool = true
## Pupil look (−1..1 per axis; scaled by the slot range when applied).
var look: Vector2 = Vector2.ZERO
## The clip's keyed face preset at the current frame (the player keeps it current).
var clip_preset: String = ""
## The preset set with set_face() ("" = none / cleared).
var override_preset: String = ""
## Frames of face time since setup.
var time_f: float = 0.0
## Frame the next blink starts (face time).
var next_blink_f: float = 0.0
## Blink progress in frames (−1 = not blinking).
var blink_t: float = -1.0
## Number of blinks started (tests).
var blink_count: int = 0
var double_count: int = 0

var _rng: int = 1
var _double_pending: bool = false
var _next_is_second: bool = false
var _override: PackedInt32Array = PackedInt32Array()   ## per face slot: variant, -1 none, -2 hidden
var _half: int = -1
var _closed: int = -1


## Bind to a rig; `seed` fixes the blink schedule.
func setup(rig_def: RigDef, pose_lib: PoseLib, seed: int = 1) -> void:
	rig = rig_def
	lib = pose_lib
	_override.resize(rig.face_slots.size())
	_override.fill(-1)
	if rig.eyes_part >= 0:
		_half = rig.tex_index(rig.eyes_part, "half")
		_closed = rig.tex_index(rig.eyes_part, "closed")
		if _half < 0:
			_half = _closed
	reseed(seed)


## Restart the blink schedule from `seed`.
func reseed(seed: int) -> void:
	_rng = seed if seed != 0 else 0x2545F491
	_rng &= 0xFFFFFFFF
	time_f = 0.0
	blink_t = -1.0
	blink_count = 0
	double_count = 0
	_double_pending = false
	_next_is_second = false
	next_blink_f = float(_range(BLINK_MIN_F, BLINK_MAX_F))


## Override every slot a preset names (until clear() or the clip's next face key).
func set_face(preset: String) -> void:
	_override.fill(-1)
	override_preset = ""
	if lib == null or not lib.presets.has(preset):
		return
	override_preset = preset
	var arr: PackedInt32Array = lib.presets[preset]
	for s in arr.size():
		_override[s] = arr[s]


## Override one slot by variant name ("none" hides it; "" clears the override).
func set_slot(slot: String, variant: String) -> void:
	var s := rig.face_slots.find(slot)
	if s < 0:
		return
	if variant == "":
		_override[s] = -1
	elif variant == "none":
		_override[s] = -2
	else:
		var vi := rig.tex_index(rig.face_slot_part[s], variant)
		if vi >= 0:
			_override[s] = vi


## Drop every override.
func clear() -> void:
	_override.fill(-1)
	override_preset = ""


## The clip's keyed face changed: overrides yield to it.
func on_clip_face_changed() -> void:
	_override.fill(-1)
	override_preset = ""


## The face preset in charge of the gaze: the runtime override, else the clip's keyed face.
func active_preset() -> String:
	return override_preset if override_preset != "" else clip_preset


## True when any slot is overridden.
func has_override() -> bool:
	for v in _override:
		if v != -1:
			return true
	return false


## Advance face time by `frames` (blink scheduling).
func advance(frames: float) -> void:
	if frames <= 0.0:
		return
	time_f += frames
	if blink_t >= 0.0:
		blink_t += frames
		if blink_t >= float(BLINK_LEN):
			blink_t = -1.0
			if _double_pending:
				_double_pending = false
				_next_is_second = true
				next_blink_f = time_f + float(DOUBLE_GAP)
			else:
				next_blink_f = time_f + float(_range(BLINK_MIN_F, BLINK_MAX_F))
		return
	if time_f >= next_blink_f:
		if suppressed or not blinks_enabled:
			_next_is_second = false
			next_blink_f = time_f + float(_range(BLINK_MIN_F / 2, BLINK_MAX_F / 2))
			return
		blink_t = 0.0
		blink_count += 1
		if _next_is_second:
			_next_is_second = false
		elif _chance(DOUBLE_PCT):
			_double_pending = true
			double_count += 1


## 0 = eyes open, 1 = half, 2 = closed (the current blink phase).
func blink_phase() -> int:
	if blink_t < 0.0:
		return 0
	if blink_t < 2.0 or blink_t >= 4.0:
		return 1
	return 2


## Writes overrides, the blink and the pupils into `pose`.
func apply(pose: PackedFloat32Array) -> void:
	for s in _override.size():
		var v := _override[s]
		if v == -1:
			continue
		var b := RigDef.ROOT_CH + rig.face_slot_part[s] * RigDef.STRIDE
		if v == -2:
			pose[b + RigDef.C_VIS] = 0.0
		else:
			pose[b + RigDef.C_TEX] = float(v)
			pose[b + RigDef.C_VIS] = 1.0
	if rig.eyes_part >= 0 and blink_t >= 0.0 and not suppressed:
		var be := RigDef.ROOT_CH + rig.eyes_part * RigDef.STRIDE
		var cur := int(pose[be + RigDef.C_TEX])
		if cur != _half and cur != _closed and pose[be + RigDef.C_VIS] > 0.5:
			var ph := blink_phase()
			var vi := _half if ph == 1 else _closed
			if vi >= 0:
				pose[be + RigDef.C_TEX] = float(vi)
				if rig.pupils_part >= 0:
					# Both phases: pupils over a half-shut lid flicker for 4 frames otherwise.
					pose[RigDef.ROOT_CH + rig.pupils_part * RigDef.STRIDE + RigDef.C_VIS] = 0.0
	# Paired lids (Bellows' half / angry eyes) follow runtime eye changes; pupils hide behind
	# shut or lidded eyes (rig `hide_with` / `no_pupils`) — keyed faces and blinks alike.
	if rig.eyes_part >= 0:
		var eb := RigDef.ROOT_CH + rig.eyes_part * RigDef.STRIDE
		var ev := int(pose[eb + RigDef.C_TEX])
		if rig.lids_part >= 0 and (blink_t >= 0.0 or _override[rig.face_slot_of[rig.eyes_part]] != -1):
			var lb := RigDef.ROOT_CH + rig.lids_part * RigDef.STRIDE
			if rig.eyes_lids.has(ev):
				pose[lb + RigDef.C_TEX] = float(rig.eyes_lids[ev])
				pose[lb + RigDef.C_VIS] = 1.0
			else:
				pose[lb + RigDef.C_VIS] = 0.0
		if rig.pupils_part >= 0 and rig.pupils_hide.has(ev):
			pose[RigDef.ROOT_CH + rig.pupils_part * RigDef.STRIDE + RigDef.C_VIS] = 0.0
	if rig.pupils_part >= 0:
		var g := Vector2.ZERO
		if lib != null and not lib.gaze.is_empty():
			var ap := active_preset()
			if ap != "":
				g = lib.gaze_of(ap)
		if look != Vector2.ZERO or g != Vector2.ZERO:
			var bp := RigDef.ROOT_CH + rig.pupils_part * RigDef.STRIDE
			var r := rig.pupil_range
			pose[bp + RigDef.C_X] += clampf(g.x + clampf(look.x, -1.0, 1.0) * r.x, -r.x * 1.5, r.x * 1.5)
			pose[bp + RigDef.C_Y] += clampf(g.y + clampf(look.y, -1.0, 1.0) * r.y, -r.y * 1.5, r.y * 1.5)


func _next() -> int:
	var x := _rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_rng = x & 0xFFFFFFFF
	return _rng


func _range(lo: int, hi: int) -> int:
	return lo + (_next() % (hi - lo + 1))


func _chance(pct: int) -> bool:
	return (_next() % 100) < pct
