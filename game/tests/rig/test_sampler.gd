## RigSampler: incoming-key eases, stepped discrete channels, loops, faces on keys, `set`
## overrides, the plant lock, crossfade blend, masked overlays and additive layers, FK.
extends TestBase

const RIG := "_mannequin"

var rig: RigDef
var lib: PoseLib


func before_each() -> void:
	rig = RigDef.for_id(RIG)
	lib = PoseLib.for_rig(RIG)


func _clip(d: Dictionary) -> ClipDef:
	var base := {"version": 1, "clip": "_mannequin/test", "rig": RIG}
	base.merge(d, true)
	return ClipLib.from_dict(base, "_mannequin/test", rig, lib)


func _ch(part: String, c: int) -> int:
	return RigDef.ch(rig.idx(part), c)


func test_continuous_channels_use_the_incoming_keys_ease() -> void:
	var c := _clip({"length": 20, "keys": [
		{"f": 0, "pose": "m_stand"},
		{"f": 10, "pose": "m_stand", "ease": "linear", "set": {"head": {"rot": 30}}},
		{"f": 20, "pose": "m_stand", "ease": "out_cubic", "set": {"head": {"rot": 0}}}]})
	assert_eq(c.errors, PackedStringArray())
	var out := rig.rest.duplicate()
	var h := _ch("head", RigDef.C_ROT)
	var h0 := lib.pose("m_stand")[h]
	RigSampler.sample(c, 5.0, out)
	assert_almost_eq(out[h], h0 + (30.0 - h0) * 0.5, 0.001, "linear into f10")
	RigSampler.sample(c, 15.0, out)
	var e := RigEase.apply(RigEase.id("out_cubic"), 0.5)
	assert_almost_eq(out[h], 30.0 + (0.0 - 30.0) * e, 0.001, "out_cubic into f20")
	RigSampler.sample(c, 25.0, out)
	assert_almost_eq(out[h], 0.0, 0.001, "clamped after the last key")


func test_discrete_channels_step_on_keys() -> void:
	var c := _clip({"length": 20, "keys": [
		{"f": 0, "pose": "m_stand", "set": {"hand_r": {"tex": "open", "z": 10, "vis": true}}},
		{"f": 10, "pose": "m_stand", "set": {"hand_r": {"tex": "fist", "z": 2, "vis": false}}},
		{"f": 20, "pose": "m_stand"}]})
	var out := rig.rest.duplicate()
	var hr := rig.idx("hand_r")
	for f in [0.0, 5.0, 9.99]:
		RigSampler.sample(c, f, out)
		assert_eq(int(out[_ch("hand_r", RigDef.C_TEX)]), rig.tex_index(hr, "open"), "tex holds until the key (f=%s)" % f)
		assert_eq(out[_ch("hand_r", RigDef.C_Z)], 10.0)
		assert_eq(out[_ch("hand_r", RigDef.C_VIS)], 1.0)
	RigSampler.sample(c, 10.0, out)
	assert_eq(int(out[_ch("hand_r", RigDef.C_TEX)]), rig.tex_index(hr, "fist"), "steps exactly on the key")
	assert_eq(out[_ch("hand_r", RigDef.C_Z)], 2.0)
	assert_eq(out[_ch("hand_r", RigDef.C_VIS)], 0.0)


func test_hold_and_pop_keys_step() -> void:
	var c := _clip({"length": 10, "keys": [
		{"f": 0, "pose": "m_stand"},
		{"f": 4, "pose": "m_take_antic", "ease": "hold"},
		{"f": 8, "pose": "m_take_accent", "ease": "pop"}]})
	var out := rig.rest.duplicate()
	var a := _ch("arm_upper_r", RigDef.C_ROT)
	RigSampler.sample(c, 3.9, out)
	assert_almost_eq(out[a], lib.pose("m_stand")[a], 0.0001, "hold keeps the previous pose")
	RigSampler.sample(c, 7.9, out)
	assert_almost_eq(out[a], lib.pose("m_take_antic")[a], 0.0001, "pop keeps the previous pose…")
	RigSampler.sample(c, 8.0, out)
	assert_almost_eq(out[a], lib.pose("m_take_accent")[a], 0.0001, "…then pops on the key")


func test_faces_step_on_keys_and_carry() -> void:
	var c := _clip({"length": 30, "keys": [
		{"f": 0, "pose": "m_stand"},
		{"f": 10, "pose": "m_stand_b", "face": "shock"},
		{"f": 20, "set": {"head": {"rot": 4}}},
		{"f": 30, "pose": "m_stand"}]})
	assert_eq(c.key_face, PackedStringArray(["neutral", "shock", "shock", "neutral"]), "pose face, explicit, carried (no pose), pose face")
	var out := rig.rest.duplicate()
	var eyes := rig.idx("face_eyes")
	RigSampler.sample(c, 9.0, out)
	assert_eq(int(out[_ch("face_eyes", RigDef.C_TEX)]), rig.tex_index(eyes, "open"))
	RigSampler.sample(c, 10.0, out)
	assert_eq(int(out[_ch("face_eyes", RigDef.C_TEX)]), rig.tex_index(eyes, "wide"))
	RigSampler.sample(c, 25.0, out)
	assert_eq(int(out[_ch("face_eyes", RigDef.C_TEX)]), rig.tex_index(eyes, "wide"), "carried face persists")


func test_loop_wraps_to_the_first_key() -> void:
	var c := _clip({"length": 40, "loop": true, "keys": [
		{"f": 0, "pose": "m_stand"},
		{"f": 20, "pose": "m_stand", "ease": "linear", "set": {"head": {"rot": 20}}}]})
	var out := rig.rest.duplicate()
	var h := _ch("head", RigDef.C_ROT)
	var h0 := lib.pose("m_stand")[h]
	RigSampler.sample(c, 30.0, out)
	assert_almost_eq(out[h], 20.0 + (h0 - 20.0) * 0.5, 0.001, "last key → first key over the wrap")
	RigSampler.sample(c, 70.0, out)
	assert_almost_eq(out[h], 20.0 + (h0 - 20.0) * 0.5, 0.001, "frames wrap by length")
	var a := rig.rest.duplicate()
	RigSampler.sample(c, 0.0, a)
	RigSampler.sample(c, 40.0, out)
	assert_almost_eq(out[h], a[h], 0.001, "seam continuous")


func test_blend_takes_the_short_way_round_and_steps_discrete() -> void:
	var a := rig.rest.duplicate()
	var b := rig.rest.duplicate()
	var out := rig.rest.duplicate()
	var h := _ch("head", RigDef.C_ROT)
	a[h] = 170.0
	b[h] = -170.0
	a[_ch("hand_r", RigDef.C_TEX)] = 0.0
	b[_ch("hand_r", RigDef.C_TEX)] = 1.0
	RigSampler.blend(a, b, 0.5, out)
	assert_almost_eq(absf(wrapf(out[h], -180.0, 180.0)), 180.0, 0.001, "lerp_angle: through 180, not through 0")
	RigSampler.blend(a, b, 0.49, out)
	assert_eq(out[_ch("hand_r", RigDef.C_TEX)], 0.0)
	RigSampler.blend(a, b, 0.5, out)
	assert_eq(out[_ch("hand_r", RigDef.C_TEX)], 1.0)
	RigSampler.blend(a, b, 0.0, out)
	assert_almost_eq(out[h], 170.0, 0.0001)
	RigSampler.blend(a, b, 1.0, out)
	assert_almost_eq(wrapf(out[h], -180.0, 180.0), -170.0, 0.0001)


func test_masked_overlay_touches_only_masked_parts() -> void:
	var base := lib.pose("m_walk_r2").duplicate()
	var over := lib.pose("m_take_accent")
	var out := base.duplicate()
	var mask := rig.mask_from("upper")
	RigSampler.apply_mask(out, over, mask, 1.0)
	var arm := _ch("arm_upper_r", RigDef.C_ROT)
	var leg := _ch("leg_upper_r", RigDef.C_ROT)
	assert_almost_eq(out[arm], over[arm], 0.0001, "upper body from the overlay")
	assert_almost_eq(out[leg], base[leg], 0.0001, "legs keep walking")
	assert_almost_eq(out[RigDef.R_Y], base[RigDef.R_Y], 0.0001, "root untouched")
	var half := base.duplicate()
	RigSampler.apply_mask(half, over, mask, 0.5)
	assert_almost_eq(half[arm], base[arm] + wrapf(over[arm] - base[arm], -180.0, 180.0) * 0.5, 0.001, "weight blends")
	assert_eq(mask[rig.idx("hat")], 1, "torso* includes its whole subtree")
	assert_eq(mask[rig.idx("hips")], 0)


func test_additive_adds_deltas_from_rest() -> void:
	var out := lib.pose("m_stand").duplicate()
	var add := rig.rest.duplicate()
	var h := _ch("head", RigDef.C_ROT)
	var sy := _ch("torso", RigDef.C_SY)
	add[h] = 10.0
	add[sy] = 1.1
	var before := out.duplicate()
	RigSampler.apply_additive(out, add, rig.rest, 0.5)
	assert_almost_eq(out[h], before[h] + 5.0, 0.0001)
	assert_almost_eq(out[sy], before[sy] * 1.05, 0.0001, "scales multiply")
	var bpose := out.duplicate()
	RigSampler.breathe(rig, bpose, 0.8, 1.0)
	assert_almost_eq(bpose[sy], out[sy] * (1.0 + rig.breath_amp), 0.0001, "breathing peaks at a quarter period")
	var s := out.duplicate()
	RigSampler.shiver(rig, s, 1.0 / 48.0, 2.0, 12.0)
	assert_almost_eq(s[_ch("torso", RigDef.C_ROT)] - out[_ch("torso", RigDef.C_ROT)], 2.0, 0.001, "shiver amplitude")


func test_fk_puts_feet_on_the_floor_in_the_stand_pose() -> void:
	var xf: Array[Transform2D] = []
	RigSampler.solve(rig, lib.pose("m_stand"), xf)
	for foot in rig.feet:
		var s := RigBounds.sole(rig, lib.pose("m_stand"), xf, foot)
		assert_almost_eq(s.y, 0.0, 0.6, "%s sole on the floor" % rig.names[foot])
	var top := RigBounds.bbox(rig, lib.pose("m_stand"), xf).position.y
	assert_between(-top, rig.height_px * 0.9, rig.height_px * 1.25, "standing height ≈ height_px (hat included)")


func test_plant_lock_holds_feet_between_planted_keys() -> void:
	# Squash / stretch keys with different knee bends: without the lock the soles dip and slide.
	var keys := [{"f": 0, "pose": "m_land_squash"}, {"f": 8, "pose": "m_land_stretch", "ease": "out_back"},
		{"f": 16, "pose": "m_dazed", "ease": "in_out_sine"}]
	var locked := _clip({"length": 16, "plant": true, "keys": keys})
	var free := _clip({"length": 16, "plant": false, "keys": keys})
	var out := rig.rest.duplicate()
	var xf: Array[Transform2D] = []
	var worst_locked := 0.0
	var worst_free := 0.0
	for foot in rig.feet:
		RigSampler.sample(locked, 0.0, out)
		RigSampler.solve(rig, out, xf)
		var sole0 := RigBounds.sole(rig, out, xf, foot)
		for f in 17:
			RigSampler.sample(locked, float(f), out)
			RigSampler.solve(rig, out, xf)
			worst_locked = maxf(worst_locked, RigBounds.sole(rig, out, xf, foot).distance_to(sole0))
			RigSampler.sample(free, float(f), out)
			RigSampler.solve(rig, out, xf)
			worst_free = maxf(worst_free, RigBounds.sole(rig, out, xf, foot).distance_to(sole0))
	assert_lt(worst_locked, 0.75, "planted soles stay put through squash / stretch / dazed (%.2f px)" % worst_locked)
	assert_gt(worst_free, worst_locked + 1.0, "without the lock they drift (%.2f px vs %.2f)" % [worst_free, worst_locked])
