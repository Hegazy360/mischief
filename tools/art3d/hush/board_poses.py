"""board_poses -- static poses of Hush for the review boards (reach proof, turnaround, poses, silhouettes).

Imported by build.py with `--poses <out.glb>` (a scratch glb: the character + one action per pose, never shipped;
the shipped clips are r3d-anim's). Poses are set with armature-space matrices (FK "rotate about an armature axis",
aim a bone at a point / along a direction, an analytic 2-bone arm IK at B's arm lengths, pelvis offsets), then keyed
on frame 0 and 1.

Blender armature space: the character faces -Y, +X = her LEFT, +Z up.
"""
import json
import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
L_UP, L_FORE = None, None     # set from the armature
HAND_TO_GRIP = 0.09


class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.pb = arm.pose.bones

    # ---- basics ------------------------------------------------------------------------------------------------
    def reset(self):
        for p in self.pb:
            p.rotation_mode = "QUATERNION"
            p.rotation_quaternion = (1, 0, 0, 0)
            p.location = (0, 0, 0)
            p.scale = (1, 1, 1)
        self.update()

    def update(self):
        bpy.context.view_layer.update()

    def M(self, n) -> Matrix:
        return self.pb[n].matrix.copy()

    def head(self, n) -> Vector:
        return self.pb[n].matrix.translation.copy()

    def set_M(self, n, m: Matrix):
        self.pb[n].matrix = m
        self.update()

    def rot(self, n, axis, deg, pivot=None):
        """Rotate bone n (and so its children) about an armature-space axis through its head (or pivot)."""
        m = self.M(n)
        p = m.translation.copy() if pivot is None else Vector(pivot)
        R = Quaternion(Vector(axis).normalized(), math.radians(deg)).to_matrix().to_4x4()
        self.set_M(n, Matrix.Translation(p) @ R @ Matrix.Translation(-p) @ m)

    def aim(self, n, direction, roll_ref=None):
        """Turn bone n so its Y axis points along `direction` (minimal rotation from its current pose)."""
        m = self.M(n)
        y = m.to_3x3().col[1].normalized()
        q = y.rotation_difference(Vector(direction).normalized())
        R = q.to_matrix().to_4x4()
        t = m.translation.copy()
        self.set_M(n, Matrix.Translation(t) @ R @ Matrix.Translation(-t) @ m)
        if roll_ref is not None:
            self.roll_to(n, roll_ref)

    def roll_to(self, n, ref):
        """Twist bone n about its own Y axis so its Z axis leans toward `ref` (an armature direction)."""
        m = self.M(n)
        y = m.to_3x3().col[1].normalized()
        z = m.to_3x3().col[2].normalized()
        r = Vector(ref) - y * Vector(ref).dot(y)
        if r.length < 1e-6:
            return
        r.normalize()
        ang = math.atan2(y.dot(z.cross(r)), z.dot(r))
        self.rot(n, y, math.degrees(ang))

    def aim_at(self, n, point, roll_ref=None):
        self.aim(n, Vector(point) - self.head(n), roll_ref)

    def move(self, n, offset):
        m = self.M(n)
        m.translation = m.translation + Vector(offset)
        self.set_M(n, m)

    # ---- 2-bone arm IK at B's lengths --------------------------------------------------------------------------
    def arm_ik(self, side, wrist, pole):
        """Place the wrist (hand_<side> head) at `wrist` with the elbow bending toward `pole` (a direction)."""
        ua, la, hd = "upperarm_" + side, "lowerarm_" + side, "hand_" + side
        S = self.head(ua)
        L1 = (self.head(la) - S).length
        L2 = (self.head(hd) - self.head(la)).length
        T = Vector(wrist)
        d = T - S
        dist = min(d.length, (L1 + L2) * 0.9995)
        dn = d.normalized()
        a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
        h = math.sqrt(max(L1 * L1 - a * a, 0.0))
        pv = Vector(pole) - dn * Vector(pole).dot(dn)
        if pv.length < 1e-6:
            pv = Vector((0, 0, -1)) - dn * Vector((0, 0, -1)).dot(dn)
        pv.normalize()
        E = S + dn * a + pv * h
        self.aim_at(ua, E)
        self.aim_at(la, S + dn * dist if d.length > dist else T)
        return E

    def hand(self, side, fingers_dir, palm_normal):
        """Orient the hand: Y along the fingers, the palm facing `palm_normal`."""
        self.aim("hand_" + side, fingers_dir)
        # the UAL hand's local X points out of the back of the hand for _l (roll +90 deg); lean the palm
        m = self.M("hand_" + side)
        x = m.to_3x3().col[0].normalized()
        want = -Vector(palm_normal) if side == "l" else Vector(palm_normal)
        y = m.to_3x3().col[1].normalized()
        r = want - y * want.dot(y)
        if r.length > 1e-6:
            r.normalize()
            ang = math.atan2(y.dot(x.cross(r)), x.dot(r))
            self.rot("hand_" + side, y, math.degrees(ang))

    def curl(self, side, deg=35.0, thumb=15.0):
        for f in ("index", "middle", "ring", "pinky"):
            for i in (1, 2, 3):
                n = f"{f}_{i:02d}_{side}"
                m = self.M(n)
                ax = m.to_3x3().col[0].normalized()
                self.rot(n, ax, deg * (1.0 if side == "l" else 1.0))
        n = "thumb_02_" + side
        self.rot(n, self.M(n).to_3x3().col[0].normalized(), thumb)

    def rest_rot(self, n) -> Matrix:
        return self.arm.data.bones[n].matrix_local.to_3x3()

    def frame_R(self, y_rest, a_rest, y_des, a_des) -> Matrix:
        """The rotation taking the rest pair (y_rest, a_rest) onto (y_des, a_des) (a orthogonalised against y)."""
        def frame(y, a):
            y = Vector(y).normalized()
            a = Vector(a) - y * Vector(a).dot(y)
            a.normalize()
            return Matrix((y, a, y.cross(a))).transposed()
        return frame(y_des, a_des) @ frame(y_rest, a_rest).transposed()

    def set_rot(self, n, R3: Matrix, head=None):
        """Bone n's armature-space rotation = R3 @ its rest rotation, its head at `head` (default: where it is)."""
        h = self.head(n) if head is None else Vector(head)
        m = (R3 @ self.rest_rot(n)).to_4x4()
        m.translation = h
        self.set_M(n, m)

    def tiptoe_foot(self, side, ground_z):
        """Turn the foot (toes down) until the ball sits on ground_z + its rest height; the ball bends back."""
        ft, bl = "foot_" + side, "ball_" + side
        m0 = self.M(ft)
        rest_ball = self.arm.data.bones[bl].head_local.z
        best = None
        for k in range(0, 71, 2):
            self.set_M(ft, m0)
            self.rot(ft, (1, 0, 0), k)
            dz = abs(self.head(bl).z - (ground_z + rest_ball))
            if best is None or dz < best[0]:
                best = (dz, k)
        self.set_M(ft, m0)
        self.rot(ft, (1, 0, 0), best[1])
        self.aim(bl, (0, -1, 0))
        return best[1]

    def look(self, direction, amount=0.8):
        """Turn the head (and a little the neck) toward an armature-space direction: yaw about +Z, then pitch."""
        d = Vector(direction).normalized()
        yaw = math.degrees(math.atan2(d.x, -d.y))           # about +Z: 0 = straight ahead (-Y), + turns the face to her left (+X)
        pitch = math.degrees(math.asin(max(-1.0, min(1.0, d.z))))
        yaw = max(-70.0, min(70.0, yaw)) * amount
        pitch = max(-25.0, min(30.0, pitch)) * amount
        self.rot("neck_01", (0, 0, 1), yaw * 0.35)
        self.rot("Head", (0, 0, 1), yaw * 0.65)
        m = self.M("Head")
        side_ax = m.to_3x3().col[0].normalized()
        self.rot("Head", side_ax, pitch)

    # ---- legs -------------------------------------------------------------------------------------------------
    def leg_ik(self, side, ankle, pole):
        th, ca, ft = "thigh_" + side, "calf_" + side, "foot_" + side
        S = self.head(th)
        L1 = (self.head(ca) - S).length
        L2 = (self.head(ft) - self.head(ca)).length
        T = Vector(ankle)
        d = T - S
        dist = min(d.length, (L1 + L2) * 0.9995)
        dn = d.normalized()
        a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
        h = math.sqrt(max(L1 * L1 - a * a, 0.0))
        pv = Vector(pole) - dn * Vector(pole).dot(dn)
        pv.normalize()
        K = S + dn * a + pv * h
        self.aim_at(th, K)
        self.aim_at(ca, T)
        return K

    def foot_flat(self, side, fwd=(0, -1, 0)):
        """Foot pointing forward, flat on its ground (the ball level with the ankle drop of the rest pose)."""
        self.aim("foot_" + side, Vector(fwd) + Vector((0, 0, -0.55)))
        self.aim("ball_" + side, fwd)

    def key(self, name, hide_props=("prop_r",), extra_scale=None):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        self.arm.animation_data_create()
        self.arm.animation_data.action = act
        for p in self.pb:
            p.rotation_mode = "QUATERNION"
        for n in hide_props:
            self.pb[n].scale = (0.0, 0.0, 0.0)
        for n, s in (extra_scale or {}).items():
            self.pb[n].scale = s
        for f in (0, 1):
            for p in self.pb:
                p.keyframe_insert("rotation_quaternion", frame=f, group=p.name)
                p.keyframe_insert("location", frame=f, group=p.name)
                p.keyframe_insert("scale", frame=f, group=p.name)
        self.arm.animation_data.action = None
        return act


# ======================================================================================================================
def relaxed_arms(P, splay=12.0, bend=14.0, fwd=6.0):
    """Arms down from the T-pose: the glove hangs beside the thigh, a small elbow bend."""
    for s, sx in (("l", 1), ("r", -1)):
        sh = P.head("upperarm_" + s)
        down = Vector((sx * math.sin(math.radians(splay)), -math.sin(math.radians(fwd)), -math.cos(math.radians(splay))))
        P.aim("upperarm_" + s, down)
        el = P.head("lowerarm_" + s)
        fore = (down + Vector((0, -math.sin(math.radians(bend)), 0))).normalized()
        P.aim("lowerarm_" + s, fore)
        P.aim("hand_" + s, fore + Vector((sx * 0.05, -0.05, 0)))
        P.curl(s, 18.0, 6.0)


def pose_idle(P):
    P.reset()
    relaxed_arms(P)
    P.rot("Head", (1, 0, 0), -3)
    return P.key("Board_Idle")


def pose_tpose(P):
    P.reset()
    return P.key("Board_Rest")


def reach_pose(P, name, target_b, feet_y=0.0, pelvis_up=0.0, tiptoe=0.0, both=False, kneel=False, pot=False,
               spout_target=None, pole=None, side="r", look_b=None):
    """A reach at B's arm lengths: the palm centre of the `side` glove on `target_b` (armature space, relative to her
    floor), standing on a step `feet_y` high (Bellows' stool) or raised `pelvis_up` (the mime's invisible step), on
    tiptoe for the high band. `pot`: the pepper pot hangs spout-down with its spout at `spout_target`."""
    P.reset()
    T = Vector(target_b)
    o = "l" if side == "r" else "r"
    out_x = -1.0 if side == "r" else 1.0
    if pole is None:
        pole = (out_x * 0.7, 0.45, -0.35)          # the elbow bends out to her side, a little back and down
    P.move("root", (0, 0, feet_y + pelvis_up + tiptoe))
    ground = feet_y + pelvis_up
    if tiptoe:
        for s_ in ("l", "r"):
            P.tiptoe_foot(s_, ground)
    if kneel:
        P.move("pelvis", (0, 0.05, -0.40))
        P.leg_ik("r", Vector((-0.10, 0.23, 0.10)), (0, -1, -0.2))
        P.aim("foot_r", (0, 1, -0.25))
        P.leg_ik("l", Vector((0.11, -0.22, 0.082)), (0, -1, 0.3))
        P.foot_flat("l")
        P.rot("spine_01", (1, 0, 0), 12)
        P.rot("spine_02", (1, 0, 0), 10)
    elif pelvis_up and not tiptoe:
        # the mime step: one foot planted on the invisible step, the other knee lifted a little
        P.leg_ik("l", Vector((0.10, 0.07, 0.082 + pelvis_up)), (0, -1, 0))
        P.foot_flat("l")
        P.leg_ik("r", Vector((-0.10, -0.06, 0.16 + pelvis_up)), (0, -1, 0))
        P.foot_flat("r")
    sh = P.head("upperarm_" + side)
    d = T - sh
    P.rot("spine_02", (1, 0, 0), max(-8.0, min(10.0, math.degrees(math.atan2(-d.y, max(d.z, 0.05))) * 0.12)))
    P.rot("spine_03", (0, 0, 1), 8.0 if side == "r" else -8.0)
    sh = P.head("upperarm_" + side)
    if pot and spout_target is not None:
        h = Vector(((T - sh).x, (T - sh).y, 0.0)).normalized()
        down = (h + Vector((0, 0, -0.55))).normalized()      # the shaking angle: cap tipped ~29 deg below level
        grip = Vector(spout_target) - down * 0.215
        fingers = (h.cross(Vector((0, 0, 1))) * (1.0 if side == "r" else -1.0) + Vector((0, 0, 0.9))).normalized()
        B = P.arm.data.bones
        a_rest = Vector((0, -1, 0))                     # the pot's axis at rest (prop_r points out of the thumb side)
        y_rest = B["hand_" + side].matrix_local.to_3x3().col[1]
        R = P.frame_R(y_rest, a_rest, fingers, down)
        g_off = Vector(B["prop_" + side].head_local) - Vector(B["hand_" + side].head_local)
        wrist = grip - R @ g_off
        P.arm_ik(side, wrist, Vector(pole))
        P.set_rot("hand_" + side, R)
    else:
        fingers = (T - sh).normalized()
        B = P.arm.data.bones
        g_off = Vector(B["prop_" + side].head_local) - Vector(B["hand_" + side].head_local)
        wrist = T - fingers * g_off.length
        P.arm_ik(side, wrist, Vector(pole))
        P.hand(side, fingers, (0, 1, 0))
    P.curl(side, 45.0, 25.0)
    sx = 1.0 if o == "l" else -1.0
    if both:
        tl = T + Vector((sx * 0.075, 0.02, -0.03))
        shl = P.head("upperarm_" + o)
        fl = (tl - shl).normalized()
        P.arm_ik(o, tl - fl * 0.095, (sx * 0.7, 0.45, -0.35))
        P.hand(o, fl, (0, 1, 0))
        P.curl(o, 45.0, 25.0)
    else:
        P.aim("upperarm_" + o, (sx * 0.45, 0.10, -0.88))
        P.aim("lowerarm_" + o, (sx * 0.20, -0.35, -0.9))
        P.aim("hand_" + o, (sx * 0.1, -0.4, -0.9))
        P.curl(o, 20.0, 5.0)
    if look_b is not None:
        P.look(look_b, 0.85)
    B = P.arm.data.bones
    grip = P.M("hand_" + side) @ (B["hand_" + side].matrix_local.inverted() @ Vector(B["prop_" + side].head_local))
    spout = P.head("fx_pepper")
    print("POSE %s target %s grip %s err %.3f | foot_l %s ball_l %s | spout %s want %s" % (
        name, tuple(round(x, 3) for x in T), tuple(round(x, 3) for x in grip), (grip - T).length,
        tuple(round(x, 3) for x in P.head("foot_l")), tuple(round(x, 3) for x in P.head("ball_l")),
        tuple(round(x, 3) for x in spout), spout_target))
    return P.key(name, hide_props=() if pot else ("prop_r",))


def arm_to(P, side, wrist, fingers, pole, curl=30.0, thumb=10.0):
    P.arm_ik(side, Vector(wrist), Vector(pole))
    P.aim("hand_" + side, Vector(fingers))
    P.curl(side, curl, thumb)


def pose_sneak(P):
    """The cartoon sneak: knees high, elbows up, gloves like paws, leaning 15 deg forward, on tiptoe."""
    P.reset()
    P.move("pelvis", (0, 0.0, -0.07))
    P.rot("pelvis", (1, 0, 0), 8)
    P.rot("spine_01", (1, 0, 0), 5)
    P.rot("spine_02", (1, 0, 0), 4)
    # left knee lifted high, the toe pointed; right leg planted on its toes
    P.leg_ik("l", Vector((0.10, -0.20, 0.30)), (0, -1, 0.1))
    P.aim("foot_l", (0, -0.35, -1))
    P.aim("ball_l", (0, -0.6, -0.8))
    P.leg_ik("r", Vector((-0.10, 0.10, 0.14)), (0, -1, 0))
    P.tiptoe_foot("r", 0.0)
    for s_, sx in (("l", 1), ("r", -1)):
        sh = P.head("upperarm_" + s_)
        arm_to(P, s_, sh + Vector((sx * 0.13, -0.24, 0.02)), (sx * 0.05, -0.35, -0.95), (sx * 0.6, 0.3, 0.5), curl=55.0)
    P.look((0.35, -1.0, 0.05), 0.9)
    return P.key("Board_Sneak")


def pose_run(P):
    """The run: leaning 25 deg, arms pumping, a long stride."""
    P.reset()
    P.move("pelvis", (0, 0.0, -0.05))
    P.rot("pelvis", (1, 0, 0), 12)
    P.rot("spine_01", (1, 0, 0), 8)
    P.rot("spine_02", (1, 0, 0), 5)
    P.leg_ik("l", Vector((0.09, -0.34, 0.22)), (0, -1, 0))
    P.aim("foot_l", (0, -1, -0.3))
    P.leg_ik("r", Vector((-0.09, 0.38, 0.16)), (0, -1, 0.2))
    P.aim("foot_r", (0, 0.5, -1))
    shl, shr = P.head("upperarm_l"), P.head("upperarm_r")
    arm_to(P, "l", shl + Vector((0.06, 0.24, -0.22)), (0.02, 0.6, -0.8), (0.3, 0.4, 0.8), curl=70.0)
    arm_to(P, "r", shr + Vector((-0.06, -0.30, -0.08)), (0.0, -0.5, 0.85), (-0.3, 0.8, -0.4), curl=70.0)
    return P.key("Board_Run")


def pose_statue(P):
    """A marble statue on the plinth (freeze): one arm raised in a flourish, a toe pointed, chin up."""
    P.reset()
    P.move("root", (0, 0, 0.12))
    shl, shr = P.head("upperarm_l"), P.head("upperarm_r")
    arm_to(P, "r", shr + Vector((-0.16, -0.08, 0.34)), (-0.3, -0.2, 0.9), (-0.8, 0.4, 0.0), curl=10.0)
    arm_to(P, "l", shl + Vector((0.34, -0.06, -0.12)), (1.0, -0.1, 0.1), (0.2, 0.2, -1.0), curl=10.0)
    P.leg_ik("l", Vector((0.20, -0.16, 0.16)), (0, -1, 0))
    P.aim("foot_l", (0.3, -0.3, -1))
    P.rot("Head", (1, 0, 0), 10)
    return P.key("Board_Statue")


def pose_squeak(P):
    """Squeak: Clarence whipped out of the brace and squeezed in the right glove, his comb flaring."""
    P.reset()
    shr, shl = P.head("upperarm_r"), P.head("upperarm_l")
    arm_to(P, "r", shr + Vector((-0.05, -0.30, -0.02)), (0.1, -0.7, 0.7), (-0.8, 0.2, -0.4), curl=60.0, thumb=30.0)
    arm_to(P, "l", shl + Vector((0.18, -0.10, 0.22)), (0.2, -0.3, 0.9), (0.8, 0.2, -0.3), curl=0.0)
    P.rot("spine_02", (1, 0, 0), 5)
    B = P.arm.data.bones
    g = P.M("hand_r") @ (B["hand_r"].matrix_local.inverted() @ Vector(B["prop_r"].head_local))
    m = P.M("prop_clarence")
    m.translation = g + Vector((0, 0, -0.05))
    P.set_M("prop_clarence", m)
    P.look((0.3, -1.0, 0.1), 0.8)
    return P.key("Board_Squeak", extra_scale={"clarence_body": (1.35, 1.35, 0.55), "clarence_comb": (1.4, 1.4, 1.4)})


def pose_snicker(P):
    """The snicker glance at the audience: hunched, both gloves at her mouth, head turned to the Stalls."""
    P.reset()
    P.rot("spine_02", (1, 0, 0), 12)
    P.rot("spine_03", (1, 0, 0), 6)
    mouth = P.head("Head") + Vector((0.0, -0.17, 0.05))
    for s_, sx in (("l", 1), ("r", -1)):
        arm_to(P, s_, mouth + Vector((sx * 0.07, 0.02, -0.07)), (-sx * 0.3, -0.4, 0.85), (sx * 0.9, 0.2, -0.3), curl=45.0)
    P.move("pelvis", (0, 0, -0.03))
    for s_ in ("l", "r"):
        P.rot("thigh_" + s_, (1, 0, 0), -6)
    P.look((0.6, -1.0, 0.0), 1.0)
    return P.key("Board_Snicker")


def pose_bow(P):
    """The curtain-call bow: bent 55 deg at the waist, one glove across the belly, the other out in a flourish."""
    P.reset()
    P.rot("pelvis", (1, 0, 0), 20, pivot=P.head("thigh_l") * 0.5 + P.head("thigh_r") * 0.5)
    P.rot("spine_01", (1, 0, 0), 18)
    P.rot("spine_02", (1, 0, 0), 12)
    for s_ in ("l", "r"):
        P.leg_ik(s_, Vector((0.10 * (1 if s_ == "l" else -1), 0.07 if s_ == "l" else -0.04, 0.082)), (0, -1, 0))
        P.foot_flat(s_)
    shl, shr = P.head("upperarm_l"), P.head("upperarm_r")
    belly = P.head("spine_01") + Vector((0.0, -0.16, 0.0))
    arm_to(P, "r", belly + Vector((0.04, 0.0, 0.0)), (1.0, -0.2, 0.0), (-0.5, 0.2, -0.8), curl=20.0)
    arm_to(P, "l", shl + Vector((0.38, 0.05, -0.05)), (1.0, 0.1, -0.2), (0.0, 0.5, -0.8), curl=5.0)
    P.rot("Head", (1, 0, 0), 12)
    return P.key("Board_Bow")


def build(arm, rig, reach_file=None):
    """Key every board pose into its own action."""
    P = Poser(arm)
    pose_tpose(P)
    pose_idle(P)
    for fn in (pose_sneak, pose_run, pose_statue, pose_squeak, pose_snicker, pose_bow):
        fn(P)
    rf = reach_file or os.path.join(HERE, "..", "..", "..", "build", "art3d", "hush", "reach_targets.json")
    if os.path.exists(rf):
        R = json.load(open(rf))
        for k, r in R["poses"].items():
            reach_pose(P, "Board_" + k, r["target_b"], feet_y=r.get("feet_y", 0.0), pelvis_up=r.get("pelvis_up", 0.0),
                       tiptoe=r.get("tiptoe", 0.0), both=r.get("both", False), kneel=r.get("kneel", False),
                       pot=r.get("pot", False), spout_target=r.get("spout_b"), pole=tuple(r["pole"]) if "pole" in r else None,
                       side="r" if r.get("both") else r.get("nearer_shoulder", "r"), look_b=r.get("look_b"))
    for p in P.pb:
        p.rotation_quaternion = (1, 0, 0, 0)
        p.location = (0, 0, 0)
        p.scale = (1, 1, 1)
