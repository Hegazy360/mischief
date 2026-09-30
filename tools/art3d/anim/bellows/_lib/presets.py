"""Horace Bellows' shared pose presets and helpers for every Bellows clip spec (owner `r3d-anim-bellows-a`;
`r3d-anim-bellows-b` / `-c` import them read-only and send requests):

    from _lib.presets import *

Angles are degrees about ARMATURE axes (+x his LEFT, -y his FRONT, +z up; tools/art3d/anim/README.md). The right side
is always the mirror (`sym` / `mirror`). The rig's `arm_out` layer (+40 deg upper-arm abduction so the arms clear the
0.85 m barrel) is added by the pipeline to EVERY clip after the keys: never key it here — an arm keyed `y 84` hangs
44 deg below the horizontal after the layer, which is his natural "penguin" rest.

Body landmarks (rest, armature space): hip 0.435 m, thighs 0.45, knees 0.27, ankles 0.08; shoulders (+-0.27, 1.04);
shoulder->wrist 0.503 m; the barrel (0, 0, 0.70) radii 0.405 / 0.355 / 0.43; head centre 1.26, top of the bouffant
1.78. Sockets: `seat` (the barrel's underside, 0.316 m at rest) — `seat()` keeps it on the stool's 0.55 m seat;
`mouth`, `grip_r` (prop_r), `grip_l` (prop_l). Props ride extra bones: prop_r > prop_teacup / prop_spoon / prop_comb /
prop_baton, prop_l > prop_saucer; set pieces lent to `grip_r` / `grip_l` (index R5e) sit with their BASE on the prop
bone's head and their up axis along the prop bone — `place_prop()` moves the prop bone so a lent kettle / jar hangs
right in the glove.
"""
import math
from mathutils import Vector, Quaternion, Matrix

from lib.pose import sym, merge, mirror, curl, swap, add, scaled, rot_q
from lib import pose as P
from lib.stage import Stage

# ------------------------------------------------------------------------------------------------------------------
# staging (house.json st_tea stand_x 3000 px = 15.0 m, house3d.json st_tea: z -1.4, seat 0.55, facing -1, cheat 35)
# ------------------------------------------------------------------------------------------------------------------
TEA_X, TEA_Z, TEA_FACING, TEA_CHEAT = 15.0, -1.4, -1, 35.0
SEAT_H = 0.55


def tea_stage():
    """Where act_tea and the sneeze are performed: on his stool at the dresser, facing -x, cheated 35 deg."""
    return Stage(x=TEA_X, z=TEA_Z, facing=TEA_FACING, cheat=TEA_CHEAT)


# ------------------------------------------------------------------------------------------------------------------
# hands (big white gloves; pinky_01 is weighted: the pinkie-up gag)
# ------------------------------------------------------------------------------------------------------------------
DIGITS = ("index", "middle", "ring", "pinky")


def glove(side, c=22.0, thumb=14.0, spread=0.0):
    return curl(side, c, thumb=thumb, fingers=DIGITS, spread=spread)


def gloves(c=22.0, thumb=14.0, spread=0.0):
    return merge(glove("l", c, thumb, spread), glove("r", c, thumb, spread))


def fist(side):
    return curl(side, 82, thumb=48, fingers=DIGITS)


def grip(side, c=64.0, thumb=40.0):
    """Fingers round a handle (kettle arch, spoon, comb, baton)."""
    return curl(side, c, thumb=thumb, fingers=DIGITS)


def pinkie_up(side="r", lift=1.0):
    """Three fingers round the teacup handle, the PINKIE cocked up and out (`lift` 0..1.3 — the wobble)."""
    s = 1.0 if side == "r" else -1.0
    out = curl(side, 66, thumb=42, fingers=("index", "middle", "ring"))
    out["pinky_01_" + side] = [("y", s * 38 * lift), ("z", -s * 14 * lift)]
    return out


def open_hand(side, spread=16.0):
    return curl(side, 4, thumb=2, fingers=DIGITS, spread=spread)


# ------------------------------------------------------------------------------------------------------------------
# arms (FK presets; the arm_out layer is added by the pipeline)
# ------------------------------------------------------------------------------------------------------------------
ARMS_DOWN = sym({"clavicle_l": [], "upperarm_l": [("y", 84), ("z", -12)], "lowerarm_l": [("z", -24)],
                 "hand_l": [("x", -6), ("y", 8)]})
# the pompous rest: elbows a little back, gloves by the barrel's sides, fingers soft
ARMS_POMPOUS = sym({"clavicle_l": [("z", 4)], "upperarm_l": [("y", 80), ("z", 6)], "lowerarm_l": [("z", -30)],
                    "hand_l": [("x", -10), ("y", 12)]})
# arms flung out (the CHOO, windmills, surprise)
ARMS_FLUNG = sym({"clavicle_l": [("y", -14)], "upperarm_l": [("y", -10), ("z", -30)], "lowerarm_l": [("z", -12)],
                  "hand_l": [("x", -20)]})
# hands on the knees / the stool's edge while seated
ARMS_ON_KNEES = sym({"clavicle_l": [("y", 4)], "upperarm_l": [("y", 70), ("z", -48)], "lowerarm_l": [("z", -34)],
                     "hand_l": [("x", 20), ("y", 10)]})

POLE_R = (-0.9, 0.35, -0.45)     # elbow out to his right, back, down
POLE_L = (0.9, 0.35, -0.45)

# ------------------------------------------------------------------------------------------------------------------
# legs
# ------------------------------------------------------------------------------------------------------------------
# standing: tiny legs, toes turned out (a pompous duck stance)
STAND = {"thigh_l": [("x", -2), ("z", 8)], "calf_l": [("x", 3)], "foot_l": [("x", -1), ("z", -3)],
         "thigh_r": [("x", -2), ("z", -8)], "calf_r": [("x", 3)], "foot_r": [("x", -1), ("z", 3)]}
# sitting on the stool: thighs forward inside the barrel, the little legs dangling (look A's seated legs)
SIT = {"thigh_l": [("x", -82), ("z", 8)], "calf_l": [("x", 68)], "foot_l": [("x", 12)],
       "thigh_r": [("x", -78), ("z", -8)], "calf_r": [("x", 62)], "foot_r": [("x", 16)]}
# legs thrown up (the flight, the sink): thighs past vertical, calves straight, slippers up
LEGS_UP = {"thigh_l": [("x", -140), ("y", -18)], "calf_l": [("x", 18)], "foot_l": [("x", -30)],
           "thigh_r": [("x", -128), ("y", 18)], "calf_r": [("x", 26)], "foot_r": [("x", -24)]}


def dangle(f, period=48.0, amp=7.0, phase=0.0, feet=True):
    """The seated feet swinging a little (motion layer): the left and right out of phase (feet=False: calves only,
    fewer animated tracks for long loops — the .res size budget)."""
    a = 2 * math.pi * (f / period + phase)
    out = {"calf_l": [("x", amp * math.sin(a))], "calf_r": [("x", amp * math.sin(a + 2.1))]}
    if feet:
        out["foot_l"] = [("x", 0.5 * amp * math.sin(a + 0.8))]
        out["foot_r"] = [("x", 0.5 * amp * math.sin(a + 2.9))]
    return out


# ------------------------------------------------------------------------------------------------------------------
# spine / head
# ------------------------------------------------------------------------------------------------------------------
def lean(fwd=0.0, side=0.0, turn=0.0):
    """Distribute a forward lean (- = back) / side lean (+ = to his left) / turn (+ = to his left) over the spine."""
    return {"spine_01": [("x", fwd * 0.4), ("y", side * 0.4), ("z", turn * 0.3)],
            "spine_02": [("x", fwd * 0.35), ("y", side * 0.35), ("z", turn * 0.35)],
            "spine_03": [("x", fwd * 0.25), ("y", side * 0.25), ("z", turn * 0.35)]}


def head(x=0.0, y=0.0, z=0.0, neck=0.35):
    """Head nod (+x down, - = chin up) / tilt (+y to his left) / turn (+z to his left), split with the neck."""
    return {"neck_01": [("x", x * neck), ("y", y * neck), ("z", z * neck)],
            "Head": [("x", x * (1 - neck)), ("y", y * (1 - neck)), ("z", z * (1 - neck))]}


def pompous(k=1.0):
    """Chest out, chin up: his default carriage."""
    return merge(lean(fwd=-6 * k), head(x=-8 * k))


def breath(f, period=110.0, amp=1.0):
    """Belly breathing (motion layer): spine rocks back, clavicles lift, the belly swells (extra bone scale)."""
    a = 2 * math.pi * f / period
    s = math.sin(a) * amp
    return {"spine_02": [("x", -1.4 * s)], "spine_03": [("x", -0.9 * s)], "clavicle_l": [("y", -1.6 * s)],
            "clavicle_r": [("y", 1.6 * s)], "belly": {"r": [], "s": 1.0 + 0.025 * s}}


def finger_drum(f, side="l", period=24, amp=26.0):
    """Fingers tapping in turn on the belly (motion layer; a period dividing the loop keeps the seam clean)."""
    out = {}
    s = 1 if side == "l" else -1
    for i, fg in enumerate(("pinky", "ring", "middle", "index")):
        ph = (f - i * 3) % period
        k = math.sin(math.pi * ph / 8.0) if ph < 8 else 0.0
        out["%s_01_%s" % (fg, side)] = [("y", s * amp * k)]
        out["%s_02_%s" % (fg, side)] = [("y", s * amp * 0.6 * k)]
    return out


def tremble(f, amp=1.0, bones=("spine_03", "Head"), rate=2.3):
    """A fast shiver (the sneeze build, the strain): two incommensurate sines per bone, a few degrees."""
    out = {}
    for i, b in enumerate(bones):
        out[b] = [("x", amp * 1.6 * math.sin(rate * f + i)), ("y", amp * 1.2 * math.sin(1.7 * rate * f + 2 * i))]
    return out


# ------------------------------------------------------------------------------------------------------------------
# in-place walk cycles (procedural feet on leg IK: the planted foot slides back at exactly `speed` in clip space, so
# it stays put in lane space — the lint's L12 rule; after r3d-anim's hush/loco_walk)
# ------------------------------------------------------------------------------------------------------------------
class Gait:
    """A two-step cycle of L frames at `speed` m/s: each foot planted `stance` frames (left contact at f 0, right at
    L/2), touching down `front` m ahead of the ankle's rest y (armature -y = his front), swinging `lift` m high."""

    def __init__(self, L, speed, stance, front=None, lift=0.07, toe_out=10.0, width=1.0, pitch_st=0.0,
                 pitch_sw=-18.0, heel=True, rise=0.8):
        self.L, self.speed, self.stance = int(L), float(speed), int(stance)
        self.D = self.speed * self.stance / 60.0
        self.front = -self.D * 0.5 if front is None else float(front)
        self.lift, self.toe_out, self.width = float(lift), float(toe_out), float(width)
        self.pitch_st, self.pitch_sw, self.heel = float(pitch_st), float(pitch_sw), heel
        self.rise = float(rise)          # swing height profile exponent (< 0.8: a low shuffle clears the floor fast)

    def phase(self, f, side):
        return ((f / float(self.L)) + (0.0 if side == "l" else 0.5)) % 1.0

    def foot(self, f, side):
        """(sole y offset, sole z, foot pitch deg, planted) — y relative to the ankle's rest y."""
        s = self.stance / float(self.L)
        ph = self.phase(f, side)
        if ph < s:
            u = ph / s
            # heel strike -> flat -> toe-off (a small roll of the pitch)
            pitch = self.pitch_st + (-8.0 * (1 - u) ** 6 + 14.0 * u ** 4 if self.heel else 0.0)
            return self.front + self.D * u, 0.0, pitch, True
        v = (ph - s) / (1.0 - s)
        e = 0.5 - 0.5 * math.cos(math.pi * v)
        y = self.front + self.D - self.D * e
        z = self.lift * math.sin(math.pi * v) ** self.rise
        return y, z, self.pitch_sw * math.sin(math.pi * v), False

    def apply(self, c, pelvis_h=None, knee_dir=(0, -1.0, 0.1), f0=0, f1=None, w=None):
        """Adds the leg constraint to clip c: pelvis height (callable f -> offset from rest, m) then both legs on IK
        with the planted sole on the floor (z 0) and its heel/ball point where foot() says."""
        sk = c.skel
        gait = self

        def legs(pose, f):
            k = 1.0 if w is None else float(w(f))
            if k <= 0.0:
                return
            if k < 1.0:
                keep = pose.copy()
            if pelvis_h is not None:
                pz = pose.pelvis_offset().z
                pose.add_pelvis_offset(Vector((0, 0, float(pelvis_h(f)) - pz)))
            for side in ("l", "r"):
                ft = "foot_" + side
                y, z, pitch, planted = gait.foot(f, side)
                s = 1.0 if side == "l" else -1.0
                x = sk.head(ft).x * gait.width
                Mf = sk.rest_q[ft]
                Rf = P.rot_q([("z", s * gait.toe_out), ("x", pitch)]) @ Mf
                soles = sk.soles()[side]
                heel_pt, ball_pt = soles[0][1], soles[1][1]
                ankle_rest = sk.head(ft)
                target = Vector((x, ankle_rest.y + y, z))      # where the heel is when the foot is flat
                # the roll pivots on the heel while the toes are up, on the ball once they point down (toe-off)
                piv = heel_pt if pitch <= 0.0 else ball_pt
                tgt = target + P.rot_q([("z", s * gait.toe_out)]) @ (piv - heel_pt)   # the flat (yawed) foot's pivot
                ankle = tgt - (Rf @ Mf.inverted()) @ (piv - ankle_rest)
                P.solve_leg(pose, side, ankle, foot_world=Rf, knee_dir=Vector(knee_dir))
            if k < 1.0:     # blend the stepping legs with the keyed ones (a walk that starts / stops)
                for b in ("pelvis", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"):
                    l0, r0, s0 = keep.get(b)
                    l1, r1, _ = pose.get(b)
                    pose.basis[b] = (l0.lerp(l1, k), P.qslerp(r0, r1, k), s0)
                pose.solve()
        c.custom(legs, f0, self.L if f1 is None else f1)
        return c


# ------------------------------------------------------------------------------------------------------------------
# constraints and bone placement (for c.custom)
# ------------------------------------------------------------------------------------------------------------------
def seat(c, f0=0, f1=None, h=SEAT_H, xy=(0.0, -0.02), w=None):
    """Keep the `seat` socket (the barrel's underside) on a seat of height h, over armature (x, y) `xy`, every frame
    of [f0, f1] (w: optional callable(frame) -> 0..1). Add it BEFORE the arm IK (it moves the whole body)."""
    bone, pt = c.ctx.socket("seat")
    f1 = c.length if f1 is None else f1

    def fn(pose, f):
        k = 1.0 if w is None else float(w(f))
        if k <= 0.0:
            return
        p = pose.skel.carried(pose.world, bone, pt)
        pose.add_pelvis_offset(Vector((xy[0] - p.x, xy[1] - p.y, h - p.z)) * k)
    c.custom(fn, f0, f1)
    return c


def seat_point(pose, ctx):
    bone, pt = ctx.socket("seat")
    return pose.skel.carried(pose.world, bone, pt)


def place_bone(pose, bone, M):
    """Set `bone`'s basis so its armature-space matrix becomes M (rotation + translation; scale kept)."""
    sk = pose.skel
    par = sk.parent[bone]
    if pose.world is None:
        pose.solve()
    PW = Matrix.Identity(4) if par is None else pose.world[par]
    B = (PW @ sk.rest_rel[bone]).inverted() @ M
    loc, rot, _ = B.decompose()
    pose.basis[bone] = (loc, rot, pose.get(bone)[2].copy())
    pose.update_from(bone)


def blend_place(pose, bone, M, w=1.0):
    """place_bone(), blended with the bone's keyed placement by w (0..1)."""
    loc0, rot0, sc0 = pose.get(bone)
    place_bone(pose, bone, M)
    if w < 1.0:
        loc1, rot1, _ = pose.get(bone)
        pose.basis[bone] = (loc0.lerp(loc1, w), P.qslerp(rot0, rot1, w), sc0)
        pose.update_from(bone)


def rigid(sk, bone, R, anchor_rest, anchor_to):
    """The armature matrix of `bone` rotated by R (a Quaternion about armature axes) about the rest point
    `anchor_rest`, then moved so that point lands on `anchor_to`."""
    return (Matrix.Translation(Vector(anchor_to)) @ R.to_matrix().to_4x4() @ Matrix.Translation(-Vector(anchor_rest))
            @ sk.rest[bone])


def arm_ik(pose, side, target, pole, hand_R=None, effector=None, w=1.0):
    """Blend-weighted 2-bone arm IK on an evaluated pose (armature-space target; hand_R a Quaternion; effector a rest
    point riding on the hand). Returns the remaining error (m)."""
    if w <= 0.0:
        return 0.0
    ikp = pose.copy()
    err = P.solve_arm(ikp, side, Vector(target), pole, hand_world=hand_R, effector=effector)
    for b in ("upperarm_" + side, "lowerarm_" + side, "hand_" + side):
        pose.set_rot(b, P.qslerp(pose.get(b)[1], ikp.get(b)[1], min(1.0, w)))
    pose.solve()
    return err


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ramp(f, f0, f1):
    """0 before f0, 1 after f1, smoothstep between."""
    if f1 <= f0:
        return 1.0 if f >= f1 else 0.0
    return smooth((f - f0) / float(f1 - f0))


def window(f, a0, a1, b0, b1):
    """0 -> 1 over [a0, a1], 1 until b0, 1 -> 0 over [b0, b1]."""
    return min(ramp(f, a0, a1), 1.0 - ramp(f, b0, b1))


def track(f, keys, ease=smooth):
    """Piecewise interpolation of (frame, value) keys (floats, tuples or Vectors), eased per segment."""
    if f <= keys[0][0]:
        return _val(keys[0][1])
    for (fa, va), (fb, vb) in zip(keys, keys[1:]):
        if f <= fb:
            t = ease((f - fa) / float(max(1, fb - fa)))
            a, b = _val(va), _val(vb)
            return a + (b - a) * t
    return _val(keys[-1][1])


def _val(v):
    if isinstance(v, (int, float)):
        return float(v)
    return Vector(v)


# ------------------------------------------------------------------------------------------------------------------
# the tea set (x1.8 teacup + saucer on prop bones; rest geometry from tools/art3d/bellows/parts.py)
# ------------------------------------------------------------------------------------------------------------------
CUP_SCALE = 1.8
CUP_DROP = 0.054 * CUP_SCALE          # cup centre -> its base (the cup is 0.108 m tall)
SAUCER_TOP = 0.012                    # saucer centre -> its top face


class TeaSet:
    """Rest points of the tea things on this skeleton (armature space)."""

    def __init__(self, ctx):
        sk = ctx.skel
        self.sk = sk
        self.ctx = ctx
        self.cup_c = sk.head("prop_teacup") + Vector((-0.045 * CUP_SCALE, -0.010, 0.0))     # the cup's centre
        self.cup_handle = sk.head("prop_teacup") + Vector((0.046 * CUP_SCALE - 0.045 * CUP_SCALE, -0.010, 0.004))
        self.saucer_c = sk.head("prop_saucer") + Vector((0.035, -0.010, 0.012))
        self.spoon_grip = sk.head("prop_spoon")
        self.spoon_bowl = sk.head("prop_spoon") + Vector((0.0, -0.028, 0.20))
        self.grip_r = sk.head("prop_r")
        self.grip_l = sk.head("prop_l")
        self.mouth = ctx.socket("mouth")          # (bone, rest point)
        self.nose = ctx.socket("nose_tip")

    def mouth_at(self, pose):
        b, p = self.mouth
        return pose.skel.carried(pose.world, b, p)

    def palm_rest(self, side):
        """The palm-centre rest point of a glove (an IK effector riding the hand)."""
        sk = self.sk
        hd, mid = "hand_" + side, "middle_01_" + side
        return sk.head(hd) + (sk.head(mid) - sk.head(hd)).normalized() * 0.09

    def palm(self, pose, side):
        """The palm centre of a glove in `pose` (the IK 'palm' effector: 0.09 m past the wrist toward the fingers)."""
        sk = pose.skel
        hd = "hand_" + side
        mid = "middle_01_" + side
        d = (sk.head(mid) - sk.head(hd)).normalized()
        return sk.carried(pose.world, hd, sk.head(hd) + d * 0.09)

    def place_cup(self, pose, centre, R=Quaternion()):
        """Put the teacup (prop_teacup) with its centre on `centre`, rotated R from upright (armature axes)."""
        place_bone(pose, "prop_teacup", rigid(self.sk, "prop_teacup", R, self.cup_c, centre))

    def place_saucer(self, pose, centre, R=Quaternion()):
        place_bone(pose, "prop_saucer", rigid(self.sk, "prop_saucer", R, self.saucer_c, centre))

    def place_spoon(self, pose, grip_at, direction, w=1.0):
        """The spoon's handle end in the glove at `grip_at`, its bowl pointing along `direction` (w < 1 blends from
        its keyed placement: ease it in before it is shown)."""
        rest_dir = (self.spoon_bowl - self.spoon_grip).normalized()
        R = rest_dir.rotation_difference(Vector(direction).normalized())
        blend_place(pose, "prop_spoon", rigid(self.sk, "prop_spoon", R, self.spoon_grip, grip_at), w)


def place_prop(pose, sk, bone, R, base_at, w=1.0):
    """A lent set piece rides `bone` (prop_r / prop_l) with its base on the bone's head and its up axis = the bone's
    (rest: armature +z; model -x = his right). Put the piece's base at `base_at`, rotated R from upright; `w` < 1
    blends from the bone's keyed (rest) placement — ease it in over the lend's slide frames (no > 45 deg/f pop)."""
    loc0, rot0, sc0 = pose.get(bone)
    place_bone(pose, bone, rigid(sk, bone, R, sk.head(bone), base_at))
    if w < 1.0:
        loc1, rot1, _ = pose.get(bone)
        pose.basis[bone] = (loc0.lerp(loc1, w), P.qslerp(rot0, rot1, w), sc0)
        pose.update_from(bone)


def qx(d):
    return Quaternion((1, 0, 0), math.radians(d))


def qy(d):
    return Quaternion((0, 1, 0), math.radians(d))


def qz(d):
    return Quaternion((0, 0, 1), math.radians(d))


# glove orientations (world rotation about armature axes applied to the rest glove; rest = palm down, fingers out)
SIP_R = qx(-8) @ qz(155)               # the sip: fingers pointing in, the cup between the glove and the face (cast (a))
CUP_LOW_R = qx(-4) @ qz(150)           # the cup held low over the saucer
SAUCER_L = qz(-15)                     # the saucer flat on the left glove
KETTLE_R = qz(-70)                     # palm down on the kettle's arch, fingers across it
JAR_L = qz(-90) @ qx(180)              # palm UP under the jar, fingers forward (the waiter's hold)

# ------------------------------------------------------------------------------------------------------------------
# THE SIP — act_tea's trigger-frame pose (f 420 = ACHOO-RIA!'s mark_s 7.0) and rx_sneeze_blast_a's frame 0: both clips
# build it from here, so the switch into the sneeze never pops.
# ------------------------------------------------------------------------------------------------------------------
SIP_BODY = merge(SIT, lean(fwd=-4, turn=4), head(x=-12, z=10), pinkie_up("r"), glove("l", 16, 10),
                 {"pelvis": [("x", -2)]})
CHEST = "spine_03"
# chest-carried rest points (they ride spine_03): where the cup / saucer sit when not at the lips
CUP_BELLY = Vector((-0.10, -0.47, 0.90))      # the cup held low in front of the belly top, over the saucer
SAUCER_BELLY = CUP_BELLY - Vector((0.0, 0.0, 0.109))   # the saucer right under it (the cup sits on it)
SAUCER_CHIN = Vector((0.04, -0.47, 0.99))     # the saucer under the chin while he sips


POLE_SIP_R = Vector((-0.45, -0.35, -0.8))       # the sipping elbow: down, a little out and forward


def cup_lips(ts, pose):
    """The cup centre at the lips: 0.10 m in front of the mouth, 0.05 m below it (cast reach proof (a))."""
    return ts.mouth_at(pose) + Vector((0.0, -0.10, -0.05))


def chest_point(pose, p_rest):
    return pose.skel.carried(pose.world, CHEST, Vector(p_rest))


def sip_arms(ts, pose, lift=1.0, cup_low=None, saucer_at=None, cup_R=None, saucer_R=None, w_r=1.0, w_l=1.0):
    """Both arms on the tea set: the right glove carries the cup from `cup_low` (a chest-carried rest point, default
    CUP_BELLY) to the lips by `lift` 0..1; the left glove holds the saucer at `saucer_at` (chest-carried; default under
    the chin while lifted, under the cup while low). Returns the worst IK error (m)."""
    low = chest_point(pose, cup_low if cup_low is not None else CUP_BELLY)
    top = cup_lips(ts, pose)
    k = smooth(lift) if 0.0 < lift < 1.0 else lift
    tgt = low.lerp(top, k)
    R = cup_R if cup_R is not None else SIP_R.slerp(CUP_LOW_R, 1.0 - k)
    # the elbow drops forward-and-out as the cup comes up (POLE_R is nearly opposite the reach at the lips: unstable)
    pole = Vector(POLE_R).lerp(POLE_SIP_R, k)
    e1 = arm_ik(pose, "r", tgt, pole, hand_R=R, effector=ts.cup_c, w=w_r)
    if saucer_at is None:
        s_low = chest_point(pose, SAUCER_BELLY)
        s_top = chest_point(pose, SAUCER_CHIN)
        sp = s_low.lerp(s_top, k)
    else:
        sp = chest_point(pose, saucer_at)
    e2 = arm_ik(pose, "l", sp, POLE_L, hand_R=saucer_R if saucer_R is not None else SAUCER_L, effector=ts.saucer_c, w=w_l)
    return max(e1, e2)


# ------------------------------------------------------------------------------------------------------------------
# lent set pieces (house3d.json prop frames, x1.5: the kettle's arch top 0.36 m above its base; the jar 0.26 m tall)
# ------------------------------------------------------------------------------------------------------------------
KETTLE_ARCH = 0.36
JAR_H = 0.26
JAR_MOUTH = 0.225


# ------------------------------------------------------------------------------------------------------------------
# D8: faces face the camera on every face beat (baked on staged clips; the sidecar gaze covers either facing)
# ------------------------------------------------------------------------------------------------------------------
FACE_BONES = ("spine_02", "spine_03", "neck_01", "Head")
FACE_SHARE = (0.15, 0.15, 0.25, 0.45)  # the upper body turns with the head (a cheat of the chest: the shoulders come
                                       # round with it, so a glove at the mouth never has to cross the barrel)


def face_to(pose, point, weight=1.0, bones=FACE_BONES, share=FACE_SHARE, max_deg=85.0):
    """Turn the face toward `point` (armature space) about the VERTICAL only: the keyed head pitch and roll stay (the
    head tipped back on "AHHH", the loll in the sink), the yaw goes to the point, `share` of it per bone."""
    if weight <= 0.0:
        return
    if pose.world is None:
        pose.solve()
    head_b = bones[-1]
    for i, (b, k) in enumerate(zip(bones, share)):
        if not pose.skel.has(b):
            continue
        eye = pose.pos(head_b) + Vector((0, 0, 0.1))
        fd = P.face_dir(pose, head_b)
        want = Vector(point) - eye
        if Vector((fd.x, fd.y)).length < 1e-4:
            return
        d = math.atan2(want.x, -want.y) - math.atan2(fd.x, -fd.y)
        d = (d + math.pi) % (2 * math.pi) - math.pi
        lim = math.radians(max_deg)
        d = max(-lim, min(lim, d))
        rel = min(1.0, k / max(1e-6, sum(share[i:]))) * weight
        pose.set_world_rot(b, Quaternion((0.0, 0.0, 1.0), d * rel) @ pose.world_rot(b))


def face_cam(c, f0, f1, weight=1.0, ease=(8, 8), target=None, bones=FACE_BONES, share=FACE_SHARE):
    """D8 on a staged clip: the face to the audience camera over [f0, f1] (`ease` in / out frames, 0 = already full at
    the edge — loop seams), weight a float or callable(f). target: None = the stage's camera, a point or callable(f).
    Add it BEFORE the IK that must follow the head (the cup at the lips). Pair it with c.look_camera for the view."""
    e0, e1 = ease

    def fn(pose, f):
        w = weight(f) if callable(weight) else weight
        w *= window(f, f0, f0 + e0, f1 - e1, f1)
        if w <= 1e-4:
            return
        t = c.stage.camera() if target is None else (target(f) if callable(target) else Vector(target))
        face_to(pose, t, w, bones=bones, share=share)
    c.custom(fn, f0, f1)
    return c


# ------------------------------------------------------------------------------------------------------------------
# FX bones (hidden at scale 0 by the descriptor unless a clip keys their scale)
# ------------------------------------------------------------------------------------------------------------------
def fx_hidden(*bones):
    """Scale-0 entries for FX bones a clip animates at other frames (keeps the track at 0 where they are off)."""
    return {b: {"r": [], "s": 0.0} for b in bones}


def stars(f, k=1.0, rate=9.0):
    """fx_stars: the vinyl star ring spinning over his head (rate deg/f)."""
    return {"fx_stars": {"r": [("z", rate * f)], "s": max(0.0, k)}}


def notes(f, k=1.0, rate=6.0):
    return {"fx_notes": {"r": [("z", -rate * f)], "s": max(0.0, k)}}


__all__ = [n for n in dir() if not n.startswith("__")]
