## Overlay clips (s2-rig §4.1.1): a micro-gag blends over the base walk / activity on its mask
## (rig mask name, part list, or — without a rig mask — the parts it keys), never touches the
## locomotion parts (root, feet, their ancestors), blends in / out over ≥ 4 f without a pop,
## auto-stops at its end, stops on stop_layer(), crossfades overlay → overlay, fires its own
## events; plus the `decor` clip event (parse + emit). Mannequin + a Bellows fixture.
extends TestBase

const DT := 1.0 / 60.0
const FIX := "res://tests/rig/fixtures/real"

var p: RigPlayer
var q: RigPlayer
var events: Array = []
var finished: Array = []


func after_each() -> void:
	for n in [p, q]:
		if is_instance_valid(n):
			n.free()
	for id in ["_mannequin/_mg_wave", "_mannequin/_mg_nod", "_mannequin/_mg_short", "_mannequin/_decor"]:
		ClipLib.invalidate(id)


func _pair(rig_id: String) -> bool:
	if not FileAccess.file_exists("res://data/rigs/%s/rig.json" % rig_id):
		return false
	p = _mk(rig_id)
	q = _mk(rig_id)
	events = []
	finished = []
	p.clip_event.connect(func(e: Dictionary) -> void: events.append(e))
	p.layer_finished.connect(func(layer: String, id: String) -> void: finished.append([layer, id]))
	return true


func _mk(rig_id: String) -> RigPlayer:
	var r := RigPlayer.new()
	r.configure_for_tools()
	r.springs_enabled = false
	r.smears_enabled = false
	tree.root.add_child(r)
	r.setup(rig_id)
	return r


func _step(n: int) -> void:
	for i in n:
		p.advance(DT)
		q.advance(DT)


func _mq_overlay(id: String, d: Dictionary) -> void:
	var base := {"version": 1, "rig": "_mannequin", "layer": "overlay", "mask": "upper"}
	base.merge(d, true)
	ClipLib.register(ClipLib.from_dict(base, id))


## Max |p − q| over the channels of parts where `sel` is 1 (and the root channels when `root`).
func _max_diff(sel: PackedByteArray, root: bool) -> float:
	var a := p.pose_buffer()
	var b := q.pose_buffer()
	var m := 0.0
	if root:
		for i in RigDef.ROOT_CH:
			m = maxf(m, absf(a[i] - b[i]))
	for part in sel.size():
		if sel[part] == 0:
			continue
		var base := RigDef.ROOT_CH + part * RigDef.STRIDE
		for c in RigDef.STRIDE:
			m = maxf(m, absf(a[base + c] - b[base + c]))
	return m


func test_mannequin_overlay_over_a_walk_leaves_locomotion_alone() -> void:
	assert_true(_pair("_mannequin"))
	_mq_overlay("_mannequin/_mg_wave", {"length": 60, "blend_in": 6, "blend_out": 6,
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": 15, "pose": "m_take_accent", "ease": "out_back", "face": "shock"},
			{"f": 45, "pose": "m_take_accent", "ease": "in_out_sine"}, {"f": 60, "pose": "m_stand", "ease": "in_out_sine"}],
		"events": [{"f": 15, "type": "sfx", "id": "boing_eyes"}]})
	for r in [p, q]:
		r.play("_mannequin/loco_walk", {"speed": 180.0, "blend_in": 0})
	_step(10)
	p.play("_mannequin/_mg_wave")
	assert_eq(p.layer_clip("overlay"), "_mannequin/_mg_wave")
	assert_eq(p.current_clip(), "_mannequin/loco_walk", "the base keeps walking")
	var rig := p.rig
	var upper := rig.mask_from("upper")
	var arm := RigDef.ch(rig.idx("arm_upper_r"), RigDef.C_ROT)
	var worst_loco := 0.0
	for f in 40:
		_step(1)
		# Feet, their chains, the root part and the root channels: exactly the walk's.
		worst_loco = maxf(worst_loco, _max_diff(rig.locomotion, true))
	assert_almost_eq(worst_loco, 0.0, 0.00001, "feet, legs, hips and root never move off the walk")
	var acc := PoseLib.for_rig("_mannequin").pose("m_take_accent")
	assert_almost_eq(p.pose_buffer()[arm], acc[arm], 1.0, "upper body from the overlay")
	assert_gt(_max_diff(upper, false), 5.0, "the overlay really drives the upper body")
	var fired := false
	for e in events:
		if String(e.get("type", "")) == "sfx" and String(e.get("clip", "")) == "_mannequin/_mg_wave":
			fired = true
	assert_true(fired, "overlay events go out through clip_event")
	# Auto-stop at the clip's end: faded out, finished once, pose back to the walk.
	_step(40)
	assert_eq(p.layer_clip("overlay"), "", "auto-stopped")
	assert_eq(finished.size(), 1, "layer_finished once")
	assert_eq(finished[0], ["overlay", "_mannequin/_mg_wave"])
	var all := PackedByteArray()
	all.resize(rig.names.size())
	all.fill(1)
	assert_almost_eq(_max_diff(all, true), 0.0, 0.0001, "back to the pure walk")


func test_blend_is_smooth_and_at_least_four_frames() -> void:
	assert_true(_pair("_mannequin"))
	_mq_overlay("_mannequin/_mg_nod", {"length": 120, "loop": true, "blend_in": 1, "blend_out": 1,
		"keys": [{"f": 0, "pose": "m_take_accent"}, {"f": 60, "pose": "m_take_accent_b", "ease": "in_out_sine"}, {"f": 120, "pose": "m_take_accent", "ease": "in_out_sine"}]})
	p.play("_mannequin/loco_idle", {"blend_in": 0})
	_step(5)
	p.play("_mannequin/_mg_nod")
	var ws: Array[float] = []
	for i in 6:
		p.advance(DT)
		ws.append(p.layer_weight("overlay"))
	assert_lt(ws[0], 0.2, "blend_in 1 is clamped to 4 f (smoothstep: w(1/4) ≈ 0.16)")
	assert_almost_eq(ws[3], 1.0, 0.0001, "fully in after 4 f")
	for i2 in range(1, 4):
		assert_gt(ws[i2], ws[i2 - 1], "monotonic")
	# The per-frame change of the driven arm during the blend stays below the full jump / 2.
	var rig := p.rig
	var arm := RigDef.ch(rig.idx("arm_upper_r"), RigDef.C_ROT)
	p.stop_layer("overlay")
	var a0 := p.pose_buffer()[arm]
	var biggest := 0.0
	for i3 in 6:
		p.advance(DT)
		biggest = maxf(biggest, absf(p.pose_buffer()[arm] - a0))
		a0 = p.pose_buffer()[arm]
	var jump := absf(PoseLib.for_rig("_mannequin").pose("m_take_accent")[arm] - PoseLib.for_rig("_mannequin").pose("m_stand")[arm])
	assert_lt(biggest, jump * 0.5 + 0.5, "no pop on the blend out (max step %.1f° of a %.1f° change)" % [biggest, jump])
	assert_eq(p.layer_clip("overlay"), "", "stop_layer ends it")


func test_overlay_to_overlay_crossfades_and_reactions_stop_it() -> void:
	assert_true(_pair("_mannequin"))
	_mq_overlay("_mannequin/_mg_wave", {"length": 200, "loop": true, "keys": [{"f": 0, "pose": "m_take_accent"}, {"f": 200, "pose": "m_take_accent"}]})
	_mq_overlay("_mannequin/_mg_nod", {"length": 200, "loop": true, "keys": [{"f": 0, "pose": "m_crouch"}, {"f": 200, "pose": "m_crouch"}]})
	p.play("_mannequin/loco_idle", {"blend_in": 0})
	p.play("_mannequin/_mg_wave")
	_step(10)
	var arm := RigDef.ch(p.rig.idx("arm_upper_r"), RigDef.C_ROT)
	var before := p.pose_buffer()[arm]
	p.play("_mannequin/_mg_nod")
	p.advance(DT)
	var lib := PoseLib.for_rig("_mannequin")
	var gap := absf(lib.pose("m_crouch")[arm] - lib.pose("m_take_accent")[arm])
	assert_lt(absf(p.pose_buffer()[arm] - before), gap * 0.2 + 1.0, "the new overlay does not pop in over the old one")
	_step(10)
	var crouch := PoseLib.for_rig("_mannequin").pose("m_crouch")
	assert_almost_eq(p.pose_buffer()[arm], crouch[arm], 1.0, "the new overlay took over")
	p.play("_mannequin/rx_take")
	_step(8)
	assert_eq(p.layer_clip("overlay"), "", "a base reaction stops the micro-gag")


func test_play_opts_layer_and_mask_override() -> void:
	assert_true(_pair("_mannequin"))
	for r in [p, q]:
		r.play("_mannequin/loco_walk", {"speed": 180.0, "blend_in": 0})
	_step(5)
	p.play("_mannequin/rx_take", {"layer": "overlay", "mask": ["head*"], "start_frame": 30})
	assert_eq(p.current_clip(), "_mannequin/loco_walk", "a base clip played as an overlay leaves the base alone")
	assert_eq(p.layer_clip("overlay"), "_mannequin/rx_take")
	_step(10)
	var rig := p.rig
	var head := rig.mask_from(["head*"])
	var not_head := PackedByteArray()
	not_head.resize(rig.names.size())
	for part in rig.names.size():
		not_head[part] = 1 - head[part]
	assert_almost_eq(_max_diff(not_head, true), 0.0, 0.00001, "only the head subtree is driven")
	assert_gt(_max_diff(head, false), 0.5, "the head is")
	assert_eq(p.overlay_mask(), head, "the mask override is the effective mask")


func test_bellows_fixture_without_a_rig_mask_uses_its_keyed_parts() -> void:
	if not _pair("bellows"):
		skip("bellows rig not delivered")
		return
	var walk := ClipLib.register_file(FIX + "/bellows_strut.json")
	var mg := ClipLib.register_file(FIX + "/bellows_mg_preen.json")
	assert_true(walk != null and mg != null, "fixtures load")
	assert_eq(walk.errors, PackedStringArray(), "strut fixture clean")
	assert_eq(mg.errors, PackedStringArray(), "micro-gag fixture clean")
	var rig := p.rig
	var mask := mg.overlay_mask()
	if rig.has_mask("upper"):
		assert_eq(mg.mask_src, ClipDef.MASK_RIG)
	else:
		assert_eq(mg.mask_src, ClipDef.MASK_KEYS, "no rig mask yet → the parts the clip keys")
	for part in rig.names.size():
		if rig.locomotion[part] == 1:
			assert_eq(mask[part], 0, "locomotion part %s never in an overlay mask" % rig.names[part])
	assert_eq(mask[rig.idx("head")], 1, "the head is driven")
	for r in [p, q]:
		r.play("bellows/_fx_strut", {"speed": 225.0, "blend_in": 0})
	_step(7)
	p.play("bellows/_fx_mg_preen")
	var worst := 0.0
	for f in 70:
		_step(1)
		worst = maxf(worst, _max_diff(rig.locomotion, true))
	assert_almost_eq(worst, 0.0, 0.00001, "Bellows' torso, legs and feet stay on the strut")
	var decor := false
	for e in events:
		if String(e.get("type", "")) == "decor" and String(e.get("id", "")) == "kitchen_stool":
			decor = true
			assert_true(bool(e.get("visible", false)))
	assert_true(decor, "a decor event inside an overlay reaches clip_event")
	ClipLib.invalidate("bellows/_fx_strut")
	ClipLib.invalidate("bellows/_fx_mg_preen")


func test_decor_event_parses_and_emits() -> void:
	assert_true(_pair("_mannequin"))
	var c := ClipLib.register(ClipLib.from_dict({"version": 1, "rig": "_mannequin", "length": 30,
		"keys": [{"f": 0, "pose": "m_stand"}, {"f": 30, "pose": "m_notice", "ease": "in_out_sine"}],
		"events": [{"f": 5, "type": "decor", "id": "kitchen_stool", "visible": false},
			{"f": 25, "type": "decor", "id": "kitchen_stool", "visible": true}]}, "_mannequin/_decor"))
	assert_eq(c.errors, PackedStringArray(), "decor is in the event vocabulary")
	assert_has(ClipDef.EVENT_TYPES, "decor")
	p.play("_mannequin/_decor", {"blend_in": 0})
	_step(31)
	var seen: Array = []
	for e in events:
		if String(e["type"]) == "decor":
			seen.append([int(e["f"]), String(e["id"]), bool(e["visible"])])
	assert_eq(seen, [[5, "kitchen_stool", false], [25, "kitchen_stool", true]], "emitted on their frames")
