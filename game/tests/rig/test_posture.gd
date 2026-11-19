## Reach posture (docs/research/animation.md, phase 3): high props make Hush step back, straighten,
## look up, tiptoe and hop until a glove touches; chin-height props are reached exactly; low props make
## her crouch with her feet planted; leaving eases back to exactly the authored clip; rigs without a
## `reach_posture` (Bellows) never change. Gloves and feet are measured by full FK (socket / part
## transforms), not by the solver's own report.
extends TestBase

const DT := 1.0 / 60.0
## Hush stands at the kitchen tea station (kettle / honey) facing right.
const STAND := Vector2(2940, 0)
const HONEY := Vector2(2998, -378)
const KETTLE := Vector2(3000, -240)
const COIN := Vector2(5312, -19)

var _nodes: Array = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			(n as Node).free()
	_nodes.clear()


func _player(rig_id: String = "hush", at: Vector2 = STAND) -> RigPlayer:
	var p := RigPlayer.new()
	p.configure_for_tools()
	p.springs_enabled = false
	tree.root.add_child(p)
	_nodes.append(p)
	p.setup(rig_id)
	p.position = at
	return p


func _grips_mid(p: RigPlayer) -> Vector2:
	return (p.socket_global_transform("hand_r:grip").origin + p.socket_global_transform("hand_l:grip").origin) * 0.5


func _best_grip(p: RigPlayer, side: String, t: Vector2, frames: int) -> float:
	var best := INF
	for i in frames:
		p.advance(DT)
		best = minf(best, p.socket_global_transform("hand_%s:grip" % side).origin.distance_to(t))
	return best


func test_rigs_declare_their_posture() -> void:
	var h := RigDef.for_id("hush")
	assert_eq(h.errors, PackedStringArray())
	assert_false(h.reach_posture.is_empty(), "Hush's rig.json has reach_posture")
	assert_eq(String(h.reach_posture["toe_tex"]), "tiptoe")
	var b := RigDef.for_id("bellows")
	assert_false(b.reach_posture.is_empty(), "Bellows has one too (phase 4: tiptoe + hop for the pickle jar)")
	assert_almost_eq(float(b.reach_posture["step_back"]), 0.0, 0.001, "but he never steps back: his stations stand him beside his props")
	assert_almost_eq(float(b.reach_posture["crouch"]), 0.0, 0.001, "and never crouches")
	var bad := RigDef.from_dict({"version": 1, "rig": "x", "parts": {"root": {"offset": [0, -50]}},
		"reach_posture": {"chin": 200, "wings": 2}})
	assert_true(Array(bad.errors).any(func(e: String) -> bool: return e.contains("wings")), "unknown keys are errors")


func test_high_prop_steps_back_looks_up_tiptoes_and_hops_to_touch() -> void:
	var p := _player()
	p.play("hush/act_tinker_q", {"blend_in": 0})
	p.set_target("grab", HONEY)
	for i in 60:
		p.advance(DT)
	var info := p.posture_info()
	assert_gt(info.x, 0.95, "full posture for the honey jar (%.2f)" % info.x)
	assert_gt(info.y, 5.0, "she steps back (%.1f px)" % info.y)
	assert_gt(info.z, 20.0, "she hops (%.1f px)" % info.z)
	assert_lt(info.w, -20.0, "she looks up (%.1f°)" % info.w)
	var ft := p.rig.idx("foot_r")
	assert_eq(int(p.pose_buffer()[RigDef.ch(ft, RigDef.C_TEX)]), p.rig.tex_index(ft, "tiptoe"), "tiptoe feet")
	var best := _best_grip(p, "r", HONEY, 90)
	assert_lt(best, 12.0, "the glove touches the jar at the top of a hop (closest %.1f px)" % best)


func test_chin_height_prop_is_reached_exactly_every_frame() -> void:
	var p := _player()
	p.play("hush/act_tinker_q", {"blend_in": 0})
	p.set_target("grab", KETTLE)
	for i in 40:
		p.advance(DT)
	var worst := 0.0
	for i in 48:
		p.advance(DT)
		worst = maxf(worst, p.reach_info("arm_r").y)
	assert_lt(worst, 1.0, "every frame of the loop solves (worst %.2f px)" % worst)
	assert_gt(p.posture_info().x, 0.5, "the kettle gets the posture (she straightens, it is at her chin)")
	assert_almost_eq(p.posture_info().z, 0.0, 0.5, "no hop needed")
	var hr := p.rig.idx("hand_r")
	assert_eq(int(p.pose_buffer()[RigDef.ch(hr, RigDef.C_TEX)]), p.rig.tex_index(hr, "pinch"), "the glove pinches on contact")
	var c := ClipLib.get_clip("hush/act_tinker_q")
	var q := _player()
	q.play(c.id, {"blend_in": 0})
	q.set_target("grab", KETTLE)
	for i in 96 + c.reach_ref_f:
		q.advance(DT)
	assert_lt(_grips_mid(q).distance_to(KETTLE), 3.0, "the gloves' midpoint is on the spout at the contact frame (%.1f px)" % _grips_mid(q).distance_to(KETTLE))


func test_low_prop_crouches_with_the_feet_planted() -> void:
	var a := _player("hush", Vector2(5308, 0))
	var b := _player("hush", Vector2(5308, 0))
	for p in [a, b]:
		(p as RigPlayer).play("hush/act_tinker_q", {"blend_in": 0})
	b.set_target("grab", COIN)
	var worst_foot := 0.0
	for i in 90:
		a.advance(DT)
		b.advance(DT)
		if i > 30:
			for f in ["foot_l", "foot_r"]:
				worst_foot = maxf(worst_foot, a.part_global_position(f).distance_to(b.part_global_position(f)))
	assert_gt(b.crouch_weight(), 0.9, "a coin on the ground: full crouch (%.2f)" % b.crouch_weight())
	assert_lt(worst_foot, 1.0, "the feet stay where the clip plants them (worst %.2f px)" % worst_foot)
	assert_lt(b.socket_global_transform("hand_r:grip").origin.y - COIN.y, 30.0, "the glove gets down to the coin")
	var hip_a := a.part_global_position("pelvis").y
	var hip_b := b.part_global_position("pelvis").y
	assert_gt(hip_b - hip_a, 30.0, "the hips drop (%.1f px)" % (hip_b - hip_a))


func test_posture_eases_out_to_exactly_the_authored_clip() -> void:
	var a := _player()
	var b := _player()
	for p in [a, b]:
		(p as RigPlayer).play("hush/act_tinker_q", {"blend_in": 0})
	b.set_target("grab", HONEY)
	for i in 60:
		a.advance(DT)
		b.advance(DT)
	b.clear_target("grab")
	a.advance(DT)
	b.advance(DT)
	assert_gt(b.posture_info().x, 0.5, "one frame after release she is still mid-ease (no pop)")
	for i in 120:
		a.advance(DT)
		b.advance(DT)
	assert_eq(b.posture_info(), Vector4.ZERO, "eased out")
	assert_eq(b.crouch_weight(), 0.0)
	var pa := a.pose_buffer()
	var pb := b.pose_buffer()
	var diff := 0.0
	var where := ""
	for i in pa.size():
		if absf(pa[i] - pb[i]) > diff:
			diff = absf(pa[i] - pb[i])
			where = "ch %d (part %s, channel %d) %.3f vs %.3f" % [i, b.rig.names[(i - RigDef.ROOT_CH) / RigDef.STRIDE] if i >= RigDef.ROOT_CH else "root", (i - RigDef.ROOT_CH) % RigDef.STRIDE if i >= RigDef.ROOT_CH else i, pa[i], pb[i]]
	assert_lt(diff, 0.001, "back to the authored pose (max channel diff %.4f at %s)" % [diff, where])


func test_bellows_without_a_reach_clip_never_changes() -> void:
	var a := _player("bellows")
	var b := _player("bellows")
	for p in [a, b]:
		(p as RigPlayer).play("bellows/loco_idle", {"blend_in": 0})
	b.set_target("grab", Vector2(3000, -380))
	for i in 30:
		a.advance(DT)
		b.advance(DT)
	assert_eq(a.pose_buffer(), b.pose_buffer(), "a clip without a reach block: identical, posture or not")
	assert_eq(b.posture_info(), Vector4.ZERO)


func test_bellows_reaches_the_pickle_jar_on_tiptoe() -> void:
	# st_pickles: he stands at 3050 facing right; the jar's centre is ~ (3110, -390) (grab / grab_l midpoint).
	var p := _player("bellows", Vector2(3050, 0))
	p.scale = Vector2(0.9, 0.9)    # the game's VISUAL_SCALE for him
	p.play("bellows/act_pickles", {"blend_in": 0})
	p.set_target("grab", Vector2(3110, -390))
	for i in 90:
		p.advance(DT)
	assert_true(p.is_reaching(), "the twist frames reach")
	var info := p.posture_info()
	assert_gt(info.x, 0.8, "a high jar: the posture is on (%.2f)" % info.x)
	assert_almost_eq(info.y, 0.0, 0.001, "no step back for Bellows")
	assert_lt(info.w, -10.0, "he looks up at it (%.1f°)" % info.w)
	var best := INF
	for i in 120:
		p.advance(DT)
		if p.reach_info("arm_r").x > 0.9:
			var mid := (p.socket_global_transform("hand_r:grip").origin + p.socket_global_transform("hand_l:grip").origin) * 0.5
			best = minf(best, mid.distance_to(Vector2(3110, -390)))
	# The jar sits very high for him: at the top of his hop the hands reach its lower half (the jar art is
	# 130 px tall, so 30 px under its centre is still on the jar) — "Bellows loses a fight with a jar".
	assert_lt(best, 30.0, "his hands get onto the jar (closest %.1f px, hop %.0f px)" % [best, p.posture_info().z])
	assert_gt(p.posture_info().z, 40.0, "it takes a real hop")
