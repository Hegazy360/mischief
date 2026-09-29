## Rig data layer: RigDef parsing, PoseLib resolution (base, mirror_of, face presets).
extends TestBase

const RIG := "_mannequin"


func test_mannequin_rig_loads_clean() -> void:
	var r := RigDef.for_id(RIG)
	if not assert_true(r != null, "rig loads"):
		return
	assert_eq(r.errors, PackedStringArray(), "no rig errors")
	assert_ge(r.names.size() - r.face_slots.size(), 14, "≥ 14 real parts")
	assert_eq(r.names[0], "hips", "root first")
	for i in r.names.size():
		if r.parent[i] >= 0:
			assert_lt(r.parent[i], i, "parent-first order: %s" % r.names[i])
	assert_eq(r.limbs.size(), 4, "2 hose arms + 2 hose legs")
	assert_eq(r.face_slots.size(), 4, "face slots")
	assert_ge(r.idx("face_eyes"), 0, "eyes are a virtual part")
	assert_eq(r.parent[r.idx("face_eyes")], r.idx("head"), "face parts hang off the anchor")
	assert_eq(r.spring_part.size(), 1, "hat spring")
	assert_eq(r.socket_index("hand_r:grip") >= 0, true, "hand socket")
	assert_eq(r.props.size(), 1, "mug prop")
	assert_eq(r.mirror_idx[r.idx("hand_l")], r.idx("hand_r"), "mirror pair")
	assert_eq(r.no_mirror[r.idx("badge")], 1, "badge counter-flips")
	assert_eq(r.pose_size, RigDef.ROOT_CH + r.names.size() * RigDef.STRIDE)


func test_poses_resolve_with_base_and_mirror() -> void:
	var lib := PoseLib.for_rig(RIG)
	if not assert_true(lib != null):
		return
	assert_eq(lib.errors, PackedStringArray(), "no pose errors")
	assert_ge(lib.names.size(), 12, "≥ 12 poses")
	var r := lib.rig
	# base: m_take_hold starts from m_take_accent and overrides a few channels.
	var acc := lib.pose("m_take_accent")
	var hold := lib.pose("m_take_hold")
	var leg := RigDef.ch(r.idx("leg_upper_r"), RigDef.C_ROT)
	assert_almost_eq(hold[leg], acc[leg], 0.0001, "inherited channel")
	var arm := RigDef.ch(r.idx("arm_upper_r"), RigDef.C_ROT)
	assert_almost_eq(hold[arm], -118.0, 0.0001, "overridden channel")
	# mirror_of: l pose = r pose with every _l/_r partner swapped (z stays).
	var pr := lib.pose("m_walk_r2")
	var pl := lib.pose("m_walk_l2")
	for n in ["arm_upper", "leg_upper", "leg_lower", "foot", "hand"]:
		var il := r.idx(n + "_l")
		var ir := r.idx(n + "_r")
		assert_almost_eq(pl[RigDef.ch(il, RigDef.C_ROT)], pr[RigDef.ch(ir, RigDef.C_ROT)], 0.0001, "mirror %s" % n)
		assert_almost_eq(pl[RigDef.ch(ir, RigDef.C_ROT)], pr[RigDef.ch(il, RigDef.C_ROT)], 0.0001, "mirror %s back" % n)
		assert_eq(pl[RigDef.ch(il, RigDef.C_Z)], pr[RigDef.ch(il, RigDef.C_Z)], "z stays with the side")
	# face preset baked into the virtual face parts.
	var shock := lib.pose("m_take_accent")
	var eyes := r.idx("face_eyes")
	assert_eq(int(shock[RigDef.ch(eyes, RigDef.C_TEX)]), r.tex_index(eyes, "wide"), "shock → wide eyes")
	var sq := lib.pose("m_take_antic")
	assert_eq(sq[RigDef.ch(r.idx("face_pupils"), RigDef.C_VIS)], 0.0, "squint hides the pupils")


func test_mirror_maps_textures_by_name() -> void:
	var r := RigDef.for_id(RIG)
	var lib := PoseLib.from_dicts(r, {"poses": {"a": {"bones": {"hand_r": {"tex": "fist"}, "hand_l": {"tex": "open"}}}},
		"mirror_of": {"b": "a"}})
	var b := lib.pose("b")
	var hl := r.idx("hand_l")
	var hr := r.idx("hand_r")
	assert_eq(int(b[RigDef.ch(hl, RigDef.C_TEX)]), r.tex_index(hl, "fist"))
	assert_eq(int(b[RigDef.ch(hr, RigDef.C_TEX)]), r.tex_index(hr, "open"))


func test_bad_pose_references_are_reported() -> void:
	var r := RigDef.for_id(RIG)
	var lib := PoseLib.from_dicts(r, {"poses": {"a": {"base": "nope", "bones": {"tail": {"rot": 1}, "head": {"spin": 2}}},
		"c1": {"base": "c2"}, "c2": {"base": "c1"}}})
	var text := "\n".join(lib.errors)
	assert_has(text, "unknown base 'nope'")
	assert_has(text, "bone 'tail'")
	assert_has(text, "cycle")
	# Unknown channels are the tolerant parser's warnings (warned once, skipped).
	assert_has("\n".join(lib.warnings), "unknown channel 'spin'")
