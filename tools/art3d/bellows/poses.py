"""Proof poses for Horace Bellows (reach proof, turnaround idle, seated hand-off) -- Blender, used by build.py --poses.

Poses are keyed as one-frame actions on the contract armature and exported with the body into a SCRATCH glb (never
under game/: the game glb has no clips, index R2). They apply the `arm_out` pose layer exactly as the bake pipeline
must (rig3d.json anim.layers / layer_params: an armature-axis rotation pre-multiplied onto each keyed local rotation,
look B's layer_rotation), and B's analytic 2-bone arm IK (look-cartoon/src/poses.py solve_arm) for the reaches.

Conventions (armature axes, as if the parent were at rest; look A/B): x+ = bend forward, y+ = left arm DOWN,
z+ = turn to his left / left arm back. Right side mirrored.
"""
import bpy, math
from mathutils import Vector, Quaternion, Matrix
import skeleton as SK

AX = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
ARM = None
REST = {}


def setup(arm):
    global ARM
    ARM = arm
    for b in arm.data.bones:
        REST[b.name] = b.matrix_local.to_quaternion()
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"


def rot_q(rots):
    R = Quaternion()
    for ax, deg in rots:
        R = Quaternion(AX[ax], math.radians(deg)) @ R
    return R


def local_q(n, rots):
    M = REST[n]
    return M.inverted() @ rot_q(rots) @ M


def reset_pose():
    for pb in ARM.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


ARMS_LEGS = [b for s in ("l", "r") for b in ("clavicle_" + s, "upperarm_" + s, "lowerarm_" + s, "hand_" + s)] + \
    [f"{f}_{i:02d}_{s}" for s in ("l", "r") for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3)]


def apply_action_frame(act_name, frame, only=None):
    """Pose the armature as a library action at a frame (keeps the result as the current pose); `only` = bone subset."""
    ARM.animation_data_create()
    act = bpy.data.actions[act_name]
    ARM.animation_data.action = act
    if hasattr(ARM.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
        ARM.animation_data.action_slot = act.slots[0]
    bpy.context.scene.frame_set(int(act.frame_range[0]) + frame - 1)
    bpy.context.view_layer.update()
    snap = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in ARM.pose.bones}
    ARM.animation_data.action = None
    for pb in ARM.pose.bones:
        if only is not None and pb.name not in only:
            pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
            continue
        l, r, s = snap[pb.name]
        pb.location, pb.rotation_quaternion, pb.scale = l, r, s
    bpy.context.view_layer.update()


def apply_layer(rots_by_bone):
    """The arm_out layer on the CURRENT pose: q <- off @ q (off = the armature-axis rotation in the bone's frame)."""
    for n, rots in rots_by_bone.items():
        pb = ARM.pose.bones[n]
        pb.rotation_quaternion = local_q(n, [(a, d) for a, d in rots]) @ pb.rotation_quaternion
    bpy.context.view_layer.update()


def fk(pose):
    """Pre-multiply armature-axis rotations onto the current pose ({bone: [(ax, deg)]})."""
    for n, rots in pose.items():
        if n.startswith("_"):
            continue
        pb = ARM.pose.bones[n]
        pb.rotation_quaternion = local_q(n, rots) @ pb.rotation_quaternion
    bpy.context.view_layer.update()


def set_pelvis_offset(off):
    pb = ARM.pose.bones["pelvis"]
    pb.location = REST["pelvis"].inverted() @ Vector(off)
    bpy.context.view_layer.update()


# ---- analytic 2-bone arm IK (look B) -------------------------------------------------------------------------------
def solve_arm(side, wrist_target, pole_dir):
    """Place the wrist (hand head) at wrist_target (armature space); the elbow bends toward pole_dir."""
    bpy.context.view_layer.update()
    up = ARM.pose.bones["upperarm_" + side]
    lo = ARM.pose.bones["lowerarm_" + side]
    hd = ARM.pose.bones["hand_" + side]
    T = Vector(wrist_target)
    pole = Vector(pole_dir).normalized()
    S = up.head.copy()
    L1 = (lo.bone.head_local - up.bone.head_local).length
    L2 = (hd.bone.head_local - lo.bone.head_local).length
    D = T - S
    reach = D.length
    d = max(1e-4, min(D.length, (L1 + L2) * 0.999))
    dv = D.normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    pp = pole - dv * pole.dot(dv)
    pp.normalize()
    E = S + dv * a + pp * h
    Tt = S + dv * d
    u = (E - S).normalized()
    f = (Tt - E).normalized()
    # keep each bone's roll frame: rotate the rest frame onto the new direction with the minimal twist about the
    # bend plane normal (so the hinge is the rest X axis)
    hinge = u.cross(f)
    if hinge.length < 1e-5:
        hinge = u.cross(pp)
    hinge.normalize()

    def place(pb, y, t):
        rest = (ARM.matrix_world @ pb.bone.matrix_local).to_3x3()
        x_rest, y_rest = rest.col[0], rest.col[1]
        # a frame with Y = y and X as close to the hinge-consistent rest X as possible
        x = hinge if abs(hinge.dot(x_rest)) >= 0 else -hinge
        if hinge.dot(x_rest) < 0:
            x = -hinge
        z = x.cross(y).normalized()
        x = y.cross(z).normalized()
        M = Matrix((x, y, z)).transposed().to_4x4()
        M.translation = t
        pb.matrix = M
        bpy.context.view_layer.update()
    place(up, u, S)
    place(lo, f, lo.head.copy())
    return reach, L1 + L2


def set_world_rot(bone, R):
    """Set a bone's world orientation to R @ (its rest orientation), keeping its head."""
    pb = ARM.pose.bones[bone]
    rest = (ARM.matrix_world @ pb.bone.matrix_local).to_3x3()
    M = (R.to_matrix() @ rest).to_4x4()
    M.translation = pb.head.copy()
    pb.matrix = M
    bpy.context.view_layer.update()


def key_pose(name, scales=None):
    """Key every bone's current pose at frame 1 into a new action `name` (+ bone scales, e.g. hidden props = 0)."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ARM.animation_data_create()
    ARM.animation_data.action = act
    for pb in ARM.pose.bones:
        s = (scales or {}).get(pb.name)
        if s is not None:
            pb.scale = (s, s, s)
        pb.keyframe_insert("rotation_quaternion", frame=1, group=pb.name)
        pb.keyframe_insert("location", frame=1, group=pb.name)
        pb.keyframe_insert("scale", frame=1, group=pb.name)
        pb.keyframe_insert("rotation_quaternion", frame=2, group=pb.name)
        pb.keyframe_insert("location", frame=2, group=pb.name)
        pb.keyframe_insert("scale", frame=2, group=pb.name)
    ARM.animation_data.action = None
    return act


def wpos(bone):
    return ARM.pose.bones[bone].head.copy()


def grip_offset(side):
    """Rest vector wrist -> grip (prop_<side> head), armature space."""
    B = ARM.data.bones
    return B["prop_" + side].head_local - B["hand_" + side].head_local


HIDE_ALL = ["prop_teacup", "prop_saucer", "prop_spoon", "prop_comb", "prop_baton", "specs_face", "fx_choo", "fx_stars", "fx_notes"]


def scales_showing(*bones):
    s = {b: 0.0 for b in HIDE_ALL}
    for b in bones:
        s[b] = 1.0
    return s


def reach_to(side, grip_target, R_hand, pole):
    """IK so that the grip point (prop_<side>) lands on grip_target with the hand at world rotation R_hand."""
    off = R_hand.to_matrix() @ grip_offset(side)
    wrist = Vector(grip_target) - off
    reach, total = solve_arm(side, wrist, pole)
    set_world_rot("hand_" + side, R_hand)
    return {"wrist_dist": round(reach, 3), "arm_len": round(total, 3), "grip_err": round((wpos("prop_" + side) - Vector(grip_target)).length, 4)}


def build_proof_poses(landmarks):
    """Idle (UAL Idle_Loop f0 + arm_out), the four reach proofs, and a few blockout poses. Returns a report dict."""
    L = landmarks
    rep = {}
    HC, TC = L["HC"], L["TC"]
    mouth = Vector(L["mouth"])
    Rz = lambda deg: Quaternion(Vector((0, 0, 1)), math.radians(deg))
    Rx = lambda deg: Quaternion(Vector((1, 0, 0)), math.radians(deg))
    Ry = lambda deg: Quaternion(Vector((0, 1, 0)), math.radians(deg))

    def base_idle(full=False):
        """The proofs' base: UAL Idle_Loop f1 arms (+ the arm_out layer) on an upright, chin-up body."""
        reset_pose()
        apply_action_frame("UAL_Idle_Loop", 1, None if full else ARMS_LEGS)
        apply_layer(SK.ARM_OUT)

    def posed(bone, p_rest):
        pb = ARM.pose.bones[bone]
        return pb.matrix @ pb.bone.matrix_local.inverted() @ Vector(p_rest)

    # ---- idle (turnaround) ----
    base_idle()
    key_pose("idle", scales_showing())
    base_idle(full=True)
    key_pose("ual_idle_layer", scales_showing())
    base_idle()
    key_pose("idle_specs", scales_showing("specs_face"))
    # ---- (a) the sip: the x1.8 teacup at the mouth (cup rim under the lip, in front of the face and belly) ----
    base_idle()
    # the cup hangs 0.081 m toward -X of the right grip at rest; turn the hand 180 deg about Z so the cup sits
    # between the hand and the face (fingers toward the centre), tilted 10 deg toward the lips
    # hand beside the cup (his right), fingers pointing in and a little toward the camera so the cup shows
    # the cup in front of the mouth, the hand at his right cheek beside it (not in front of it)
    R = Rx(-6) @ Rz(115)
    m = posed("Head", mouth)
    cup_c = m + Vector((0.0, -0.130, -0.040))
    grip = cup_c + (R.to_matrix() @ Vector((0.081, 0.010, 0.0)))
    rep["a_mouth"] = reach_to("r", grip, R, (-0.9, 0.3, -0.5))
    rep["a_mouth_posed"] = [round(v, 3) for v in m]
    # the saucer below it in the left hand
    Rl = Rz(-15)
    rep["a_saucer"] = reach_to("l", Vector((0.10, -0.40, 0.96)), Rl, (0.9, 0.3, -0.5))
    rep["a_cup_centre"] = [round(v, 3) for v in cup_c]
    key_pose("reach_mouth", scales_showing("prop_teacup", "prop_saucer"))
    # ---- (b) 0.25 m in front of the belly at y 1.0 m (the gramophone needle, the phone) ----
    base_idle()
    belly_y = L["belly_y_at_1m"]
    rep["b_shoulder_idle"] = [round(v, 3) for v in wpos("upperarm_r")]
    fk({"clavicle_r": [("z", 16)], "spine_03": [("z", -4)]})     # reach forward: the shoulder protracts a little
    rep["b_shoulder"] = [round(v, 3) for v in wpos("upperarm_r")]
    tgt = Vector((-0.20, belly_y - 0.25, 1.0))
    rep["b_front"] = reach_to("r", tgt, Rz(90) @ Rx(-20), (-0.8, 0.4, -0.6))
    rep["b_target"] = [round(v, 3) for v in tgt]
    key_pose("reach_front", scales_showing())
    # ---- (c) the comb flourish on the top of the bouffant (a little shrug of the clavicle) ----
    base_idle()
    fk({"clavicle_r": [("y", 20)], "spine_03": [("y", 5)], "Head": [("y", 8)]})
    top = Vector(L["bouffant_top"])
    # the comb sticks out of the fist along the fingers (rest -X): aim it up and in so its tip passes over the crown
    dir_c = Vector((0.62, 0.10, 0.78)).normalized()
    Rc = Vector((-1.0, 0.0, 0.0)).rotation_difference(dir_c)
    tip = top + Vector((-0.03, -0.02, 0.02))
    grip = tip - dir_c * 0.20
    rep["c_top"] = reach_to("r", grip, Rc, (-0.9, 0.3, -0.3))
    rep["c_comb_tip"] = [round(v, 3) for v in (wpos("prop_r") + dir_c * 0.20)]
    rep["c_bouffant_top"] = [round(v, 3) for v in top]
    key_pose("reach_top", scales_showing("prop_comb"))
    # ---- (d) seated on the stool (seat 0.55 m): the lent kettle at grip_r, the honey jar at grip_l, in front ----
    base_idle()
    lift = 0.55 - L["seat_z"]
    set_pelvis_offset((0.0, 0.0, lift))
    fk({"thigh_l": [("x", -78), ("z", 6)], "thigh_r": [("x", -78), ("z", -6)], "calf_l": [("x", 62)], "calf_r": [("x", 62)],
        "foot_l": [("x", 12)], "foot_r": [("x", 12)]})
    rep["d_kettle"] = reach_to("r", Vector((-0.20, belly_y - 0.20, 0.98 + lift)), Rz(90) @ Rx(-10), (-0.9, 0.3, -0.5))
    rep["d_jar"] = reach_to("l", Vector((0.20, belly_y - 0.20, 0.96 + lift)), Rz(-90) @ Rx(-10), (0.9, 0.3, -0.5))
    rep["d_lift"] = round(lift, 3)
    key_pose("reach_seat", scales_showing())
    # ---- blockout extras for boards: seated tea (sip) ----
    base_idle()
    set_pelvis_offset((0.0, 0.0, lift))
    fk({"thigh_l": [("x", -78), ("z", 6)], "thigh_r": [("x", -78), ("z", -6)], "calf_l": [("x", 62)], "calf_r": [("x", 62)]})
    R = Rx(-10) @ Rz(180)
    R = Rx(-6) @ Rz(115)
    cup_c = posed("Head", mouth) + Vector((0.0, -0.130, -0.040))
    reach_to("r", cup_c + (R.to_matrix() @ Vector((0.081, 0.010, 0.0))), R, (-0.9, 0.3, -0.5))
    reach_to("l", Vector((0.10, -0.40, 0.96 + lift)), Rz(-15), (0.9, 0.3, -0.5))
    key_pose("tea_seat", scales_showing("prop_teacup", "prop_saucer"))

    # ---- board poses (P2: props, looks, CHOO, stars / notes, silhouettes) ----
    # the signature tea hold: saucer flat in the left glove at the chest, the cup lifted just above it, pinkie out
    base_idle()
    R = Rz(95)
    cup_c = Vector((-0.02, belly_y - 0.20, 1.10))
    rep["tea_hold"] = reach_to("r", cup_c + (R.to_matrix() @ Vector((0.081, 0.010, 0.0))), R, (-0.9, 0.3, -0.5))
    reach_to("l", Vector((0.06, belly_y - 0.20, 0.99)), Rz(-40), (0.9, 0.3, -0.5))
    fk({"pinky_01_r": [("z", -35)], "Head": [("x", -6)]})
    key_pose("tea_hold", scales_showing("prop_teacup", "prop_saucer"))
    SEAT = {"thigh_l": [("x", -78), ("z", 6)], "thigh_r": [("x", -78), ("z", -6)], "calf_l": [("x", 62)], "calf_r": [("x", 62)]}
    # specs on (the Livid / suspicious look)
    base_idle()
    sc = scales_showing("specs_face")
    sc["specs_chest"] = 0.0
    key_pose("specs_on", sc)
    # the strut (UAL Walk_Formal_Loop mid-stride, chin up)
    reset_pose()
    apply_action_frame("UAL_Walk_Formal_Loop", 9)
    apply_layer(SK.ARM_OUT)
    fk({"Head": [("x", -10)], "neck_01": [("x", -4)], "spine_03": [("x", -4)]})
    key_pose("strut", scales_showing())
    # conducting with the baton (right arm up, left fist on the belly)
    base_idle()
    fk({"clavicle_r": [("y", 12)], "spine_03": [("y", -3)], "Head": [("x", -8), ("z", -6)]})
    rep["conduct"] = reach_to("r", Vector((-0.34, belly_y - 0.14, 1.40)), Vector((-1.0, 0.0, 0.0)).rotation_difference(
        Vector((0.35, -0.55, 0.76)).normalized()), (-0.9, 0.2, -0.4))
    reach_to("l", Vector((0.16, belly_y - 0.06, 0.86)), Rz(-60), (0.9, 0.3, -0.5))
    key_pose("conduct", scales_showing("prop_baton"))
    # the honey spoon, held up in front of the belly
    base_idle()
    rep["spoon"] = reach_to("r", Vector((-0.16, belly_y - 0.22, 1.02)), Rz(90), (-0.9, 0.3, -0.5))
    key_pose("spoon", scales_showing("prop_spoon"))
    # the CHOO (seated, the instant of the blast): head and chest snap forward, arms flung back, feet kick up
    base_idle()
    set_pelvis_offset((0.0, 0.03, lift))
    fk(SEAT)
    fk({"thigh_l": [("x", -18)], "thigh_r": [("x", -18)], "calf_l": [("x", -30)], "calf_r": [("x", -30)],
        "spine_01": [("x", 6)], "spine_02": [("x", 8)], "spine_03": [("x", 8)], "Head": [("x", 16)],
        "upperarm_l": [("y", -45), ("z", 40)], "upperarm_r": [("y", 45), ("z", -40)],
        "lowerarm_l": [("z", 20)], "lowerarm_r": [("z", -20)]})
    key_pose("choo", scales_showing("fx_choo"))
    # dazed in the sink: bottom down, slippers up, arms flopped, stars round his head
    base_idle()
    set_pelvis_offset((0.0, 0.10, 0.10))
    fk({"pelvis": [("x", -40)], "thigh_l": [("x", -70), ("z", 18)], "thigh_r": [("x", -70), ("z", -18)],
        "calf_l": [("x", 10)], "calf_r": [("x", 10)], "spine_02": [("x", 10)], "Head": [("y", 16), ("x", 4)],
        "upperarm_l": [("y", -35), ("z", 20)], "upperarm_r": [("y", 35), ("z", -20)],
        "lowerarm_l": [("z", -30)], "lowerarm_r": [("z", 30)]})
    key_pose("dazed_sink", scales_showing("fx_stars"))
    # dizzy under orbiting notes (ALLEGRO-GO-GO!'s collapse): sat on the floor, head lolling
    base_idle()
    set_pelvis_offset((0.0, 0.0, -0.20))
    fk({"thigh_l": [("x", -84), ("z", 24)], "thigh_r": [("x", -84), ("z", -24)], "calf_l": [("x", 30)], "calf_r": [("x", 30)],
        "Head": [("y", -18), ("x", 8)], "spine_03": [("y", -6)],
        "upperarm_l": [("y", 10)], "upperarm_r": [("y", -10)]})
    key_pose("dizzy_notes", scales_showing("fx_notes"))
    # blind shuffle: hair over the eyes (look), arms out groping
    base_idle()
    fk({"upperarm_l": [("y", -25), ("z", -55)], "upperarm_r": [("y", 25), ("z", 55)], "lowerarm_l": [("z", -15)],
        "lowerarm_r": [("z", 15)], "Head": [("x", 6)], "spine_03": [("x", 4)]})
    key_pose("grope", scales_showing())
    reset_pose()
    return rep
