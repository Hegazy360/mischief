## FaceCards3D — the painted face on a 3D head (REDESIGN §5.6): which atlas cell each face layer shows this frame,
## packed for the `char_toon` uniforms (`face_cell_a` = brows, eyes, pupils, mouth; `face_cell_b` = extra_a,
## extra_b, lids, spare; −1 = off) plus `pupil_offset` (−1…1 of the rig's `pupil_range`). A port of the 2D
## `face_state.gd` rules:
##
## * **Source:** the playing clip's face timeline (`{f, preset}` / `{f, slots}`, held until the next entry) wins;
##   without one, the preset the view set (`set_face`). Runtime overrides (`set_face` / `set_slot` while a clip
##   with a timeline plays) hold until the clip's next timeline entry (the 2D rule).
## * **Blinks** every 2–6 s (rig `face.blink.every_s`; seeded xorshift32, so a seed blinks on the same frames),
##   `face.blink.frames` long (6: 2 half, 2 closed, 2 half), 15 % doubles; only over `blinkable` eyes; suppressed
##   while `suppressed` (a take's hold) or a timeline entry says `"blink": false`.
## * **Pupils** default to the `centre` cell, hidden in blinks and behind `no_pupils` eyes; the offset is the
##   preset's `gaze` + the look-at direction, clamped.
## * **Mirror:** facing −1 swaps every cell through the rig's `face.mirror_cells` (facing is a yaw, never a
##   negative scale, so asymmetric marks are swapped explicitly).
## `update(frames)` advances face time and recomputes; `changed` says whether the packed uniforms moved. No per-frame
## allocation.
class_name FaceCards3D
extends RefCounted

const N_LAYERS := 8
const L_BROWS := 0
const L_EYES := 1
const L_PUPILS := 2
const L_MOUTH := 3
const L_EXTRA_A := 4
const L_EXTRA_B := 5
const L_LIDS := 6
const DOUBLE_PCT := 15
const DOUBLE_GAP := 3
const OFF := -1
const UNSET := -2

var def: RigDef3D
var suppressed: bool = false
var blinks_enabled: bool = true
var facing: int = 1
## Look-at pupil direction (−1…1 per axis, x toward the character's right on screen, y up).
var look: Vector2 = Vector2.ZERO
## The clip whose face timeline drives the face (null = the view preset) and its frame.
var clip: ClipDef3D = null
var clip_frame: float = 0.0
## The view's preset (`set_face`), used when the clip has no face timeline.
var view_preset: String = "neutral"
var face_misses: int = 0
var miss_names: Dictionary = {}

## Packed output (what the material gets).
var cell_a: Vector4i = Vector4i(-1, -1, -1, -1)
var cell_b: Vector4i = Vector4i(-1, -1, -1, -1)
var pupil: Vector2 = Vector2.ZERO
var changed: bool = true
## The preset name in force (tests, the AnimViewer label).
var active_preset: String = ""

var time_f: float = 0.0
var next_blink_f: float = 0.0
var blink_t: float = -1.0
var blink_count: int = 0
var double_count: int = 0

var _rng: int = 1
var _double_pending: bool = false
var _next_is_second: bool = false
var _layer_of: Dictionary = {}                   ## layer name -> slot index
var _preset_cells: Dictionary = {}               ## preset -> PackedInt32Array(8) (UNSET = not named)
var _override := PackedInt32Array()              ## per slot: UNSET, OFF or a cell
var _look := PackedInt32Array()                  ## per slot: cells the active looks force (FRAZZLED's singe)
var _blink_hide := PackedInt32Array()            ## slots hidden during a blink (pupils, lids)
var _cur := PackedInt32Array()                   ## resolved cells this frame
var _mirror: Array[Dictionary] = []              ## per slot: cell -> mirrored cell
var _blinkable: Dictionary = {}                  ## eyes cell -> true
var _no_pupils: Dictionary = {}
var _half: int = -1
var _closed: int = -1
var _centre: int = -1
var _last_entry: int = -1
var _last_clip: ClipDef3D = null
var _entry_blink: bool = true
var _blink_min: int = 120
var _blink_max: int = 360


## Bind to a rig descriptor; `seed` fixes the blink schedule.
func setup(rig_def: RigDef3D, seed: int = 1) -> void:
	def = rig_def
	_override.resize(N_LAYERS)
	_override.fill(UNSET)
	_cur.resize(N_LAYERS)
	_cur.fill(OFF)
	_look.resize(N_LAYERS)
	_look.fill(UNSET)
	_mirror.clear()
	for i in N_LAYERS:
		_layer_of[RigDef3D.FACE_LAYERS[i]] = i
		_mirror.append({})
	for ln in def.face_cells:
		if not _layer_of.has(ln):
			continue
		var li: int = _layer_of[ln]
		var cells: Dictionary = def.face_cells[ln]
		for cn in cells:
			var m := def.mirrored(String(ln), String(cn))
			if m != String(cn) and cells.has(m):
				(_mirror[li] as Dictionary)[int(cells[cn])] = int(cells[m])
	for pn in def.presets:
		_preset_cells[pn] = _resolve_preset(def.presets[pn] as Dictionary, String(pn))
	_half = def.cell_index("eyes", def.blink_half_cell)
	_closed = def.cell_index("eyes", def.blink_cell)
	_centre = def.cell_index("pupils", "centre")
	for cn in def.blinkable:
		var ci := def.cell_index("eyes", cn)
		if ci >= 0:
			_blinkable[ci] = true
	for cn in def.no_pupils:
		var ci2 := def.cell_index("eyes", cn)
		if ci2 >= 0:
			_no_pupils[ci2] = true
	_blink_hide.clear()
	for ln2 in def.blink_hide_layers:
		if _layer_of.has(ln2):
			_blink_hide.append(int(_layer_of[ln2]))
	_blink_min = maxi(1, roundi(def.blink_every_s.x * 60.0))
	_blink_max = maxi(_blink_min, roundi(def.blink_every_s.y * 60.0))
	reseed(seed)
	changed = true


## True when the rig has a face (atlas cells).
func has_face() -> bool:
	return def != null and not def.face_cells.is_empty()


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
	next_blink_f = float(_range(_blink_min, _blink_max))


## The view's preset (and a runtime override while a clip timeline plays, until its next entry).
func set_face(preset: String) -> void:
	view_preset = preset
	_override.fill(UNSET)
	if not _preset_cells.has(preset):
		_miss("preset:" + preset)
		return
	var cells: PackedInt32Array = _preset_cells[preset]
	for i in N_LAYERS:
		_override[i] = cells[i]
	changed = true


## Override one layer by cell name ("none" hides it; "" clears the override).
func set_slot(layer: String, cell: String) -> void:
	if not _layer_of.has(layer):
		_miss("layer:" + layer)
		return
	var li: int = _layer_of[layer]
	if cell == "":
		_override[li] = UNSET
	elif cell == "none":
		_override[li] = OFF
	else:
		var ci := def.cell_index(layer, cell)
		if ci < 0:
			_miss("%s/%s" % [layer, cell])
			return
		_override[li] = ci
	changed = true


## Cells the active looks force ({layer: cell}; "none" hides the layer); {} clears them.
func set_look_cells(cells: Dictionary) -> void:
	_look.fill(UNSET)
	for ln in cells:
		if not _layer_of.has(String(ln)):
			continue
		var cn := String(cells[ln])
		_look[int(_layer_of[String(ln)])] = OFF if cn == "none" or cn == "" else def.cell_index(String(ln), cn)
	changed = true


## Drop every runtime override.
func clear() -> void:
	_override.fill(UNSET)
	changed = true


## The cells a preset resolves to (UNSET where the preset names nothing), for tests.
func preset_cells(preset: String) -> PackedInt32Array:
	return _preset_cells.get(preset, PackedInt32Array())


## Advance face time by `frames` and recompute the packed output.
func update(frames: float) -> void:
	if def == null:
		return
	_advance_blink(frames)
	_resolve()


## 0 = eyes open, 1 = half, 2 = closed (the current blink phase).
func blink_phase() -> int:
	if blink_t < 0.0:
		return 0
	var n := float(maxi(1, def.blink_frames))
	if _half >= 0 and (blink_t < n / 3.0 or blink_t >= n * 2.0 / 3.0):
		return 1
	return 2


func _resolve() -> void:
	# 1. the source: the clip's timeline entry, else the view preset.
	var src: PackedInt32Array
	var entry_i := -1
	if clip != null and not clip.face_entries.is_empty():
		entry_i = clip.face_index_at(clip_frame)
	if clip != _last_clip or entry_i != _last_entry:
		if entry_i >= 0:
			_override.fill(UNSET)   # the clip's keyed face change wins over runtime overrides
		_last_clip = clip
		_last_entry = entry_i
	_entry_blink = true
	var pname := view_preset
	if entry_i >= 0:
		var e: Dictionary = clip.face_entries[entry_i]
		if clip.face_presets[entry_i] != "":
			pname = clip.face_presets[entry_i]
		_entry_blink = bool(e.get("blink", true))
	active_preset = pname
	src = _preset_cells.get(pname, PackedInt32Array())
	for i in N_LAYERS:
		_cur[i] = src[i] if not src.is_empty() else UNSET
	if src.is_empty() and has_face():
		_miss("preset:" + pname)
	if entry_i >= 0:
		var slots: Variant = (clip.face_entries[entry_i] as Dictionary).get("slots", null)
		if slots is Dictionary:
			for ln in (slots as Dictionary):
				if _layer_of.has(String(ln)):
					var cn := String((slots as Dictionary)[ln])
					var li: int = _layer_of[String(ln)]
					_cur[li] = OFF if cn == "none" or cn == "" else def.cell_index(String(ln), cn)
	# 2. runtime overrides, then the looks' forced cells.
	for i in N_LAYERS:
		if _override[i] != UNSET:
			_cur[i] = _override[i]
		if _look[i] != UNSET:
			_cur[i] = _look[i]
		if _cur[i] == UNSET:
			_cur[i] = OFF
	# 3. pupils default + blink.
	var eyes := _cur[L_EYES]
	if _cur[L_PUPILS] == OFF and src.size() == N_LAYERS and src[L_PUPILS] == UNSET and _override[L_PUPILS] == UNSET:
		_cur[L_PUPILS] = _centre
	if blink_t >= 0.0 and not suppressed and _entry_blink and eyes >= 0 and _can_blink(eyes):
		var ph := blink_phase()
		var bi := _half if ph == 1 and _half >= 0 else _closed
		if bi >= 0:
			_cur[L_EYES] = bi
			for hl in _blink_hide:
				_cur[hl] = OFF
	if _no_pupils.has(_cur[L_EYES]) or _cur[L_EYES] < 0:
		_cur[L_PUPILS] = OFF
	# 4. mirror by facing.
	if facing < 0:
		for i in N_LAYERS:
			var m: Dictionary = _mirror[i]
			if not m.is_empty() and m.has(_cur[i]):
				_cur[i] = int(m[_cur[i]])
	var a := Vector4i(_cur[0], _cur[1], _cur[2], _cur[3])
	var b := Vector4i(_cur[4], _cur[5], _cur[6], _cur[7])
	# The preset's gaze is authored facing right (the 2D art space): mirrored with facing. The look-at direction is
	# already in the body's frame (+x = the face's u axis), so it is never mirrored.
	var g: Vector2 = def.gaze.get(pname, Vector2.ZERO)
	if facing < 0 and def.mirror_pupil_x:
		g.x = -g.x
	var pv := Vector2(clampf(g.x + clampf(look.x, -1.0, 1.0), -1.0, 1.0), clampf(g.y + clampf(look.y, -1.0, 1.0), -1.0, 1.0))
	if a != cell_a or b != cell_b or not pv.is_equal_approx(pupil):
		cell_a = a
		cell_b = b
		pupil = pv
		changed = true


func _can_blink(eyes: int) -> bool:
	if eyes == _half or eyes == _closed:
		return false
	return _blinkable.is_empty() or _blinkable.has(eyes)


func _advance_blink(frames: float) -> void:
	if frames <= 0.0:
		return
	time_f += frames
	if blink_t >= 0.0:
		blink_t += frames
		if blink_t >= float(maxi(1, def.blink_frames)):
			blink_t = -1.0
			if _double_pending:
				_double_pending = false
				_next_is_second = true
				next_blink_f = time_f + float(DOUBLE_GAP)
			else:
				next_blink_f = time_f + float(_range(_blink_min, _blink_max))
		return
	if time_f >= next_blink_f:
		if suppressed or not blinks_enabled or not _entry_blink:
			_next_is_second = false
			next_blink_f = time_f + float(_range(_blink_min / 2, _blink_max / 2))
			return
		blink_t = 0.0
		blink_count += 1
		if _next_is_second:
			_next_is_second = false
		elif _chance(DOUBLE_PCT):
			_double_pending = true
			double_count += 1


func _resolve_preset(p: Dictionary, pname: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(N_LAYERS)
	out.fill(UNSET)
	for k in p:
		var key := String(k)
		var cn := String(p[k])
		if _layer_of.has(key):
			var li: int = _layer_of[key]
			if cn == "none" or cn == "":
				out[li] = OFF
			else:
				var ci := def.cell_index(key, cn)
				if ci < 0:
					_miss("%s:%s/%s" % [pname, key, cn])
				out[li] = ci
		elif cn != "none" and cn != "":
			# 2D-style overlay slots ("blush": "on") land in the first extra layer that has that cell.
			for li2 in [L_EXTRA_A, L_EXTRA_B]:
				var ln: String = RigDef3D.FACE_LAYERS[li2]
				var ci2 := def.cell_index(ln, key)
				if ci2 >= 0 and out[li2] == UNSET:
					out[li2] = ci2
					break
	return out


func _miss(what: String) -> void:
	if not miss_names.has(what):
		miss_names[what] = true
		face_misses += 1


func _next() -> int:
	var x := _rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_rng = x & 0xFFFFFFFF
	return _rng


func _range(lo: int, hi: int) -> int:
	return lo + (_next() % (maxi(1, hi - lo + 1)))


func _chance(pct: int) -> bool:
	return (_next() % 100) < pct
