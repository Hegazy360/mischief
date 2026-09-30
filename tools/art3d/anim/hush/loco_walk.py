"""hush/loco_walk — the cartoon sneak (REDESIGN §4.2 "Move — tiptoe"): knees high, elbows up, gloves drooping like
paws, the body leaning 15° into the walk, on her toes; 2.2 steps/s at 2.0 m/s (a 54 f cycle, stride 1.80 m), in place
(the view moves her; the lint checks the planted toes in lane space); a pizzicato step on each contact. Cheat 20°.

The feet are driven procedurally (a toe-contact stance sliding back at exactly 2.0 m/s + a high, dainty swing arc) and
the legs solved with IK, so the planted toes never slide on the lane; the upper body is keyed + layered motion."""
import math
from mathutils import Vector, Quaternion
from lib.clip import Clip
from lib import pose as P
from lib.pose import merge, sym, mirror
from lib.hush_presets import PAWS, gloves, lean, head

L = 54                 # frames per cycle (two steps)
SPEED = 2.0            # m/s
STANCE = 18            # frames each foot is planted (a 9 f float between the steps: a springy tiptoe bound)
D = SPEED * STANCE / 60.0          # 0.8 m the planted toes travel back in clip space
FRONT = -0.40          # the ball's y at touch-down (armature -y = her front): the ankle range centred under the hip
LIFT = 0.30            # swing height of the ball (knees high)
PITCH_ST, PITCH_SW = 38.0, 52.0    # foot pitch (toes down) in stance / swing
TOE_SW = 18.0          # toes curl down in the swing
H0, BOB = 0.69, 0.035  # pelvis height at mid-stance (m) and the bob up into each float


def phase(f, side):
    return ((f / float(L)) + (0.0 if side == "l" else 0.5)) % 1.0


def foot_target(f, side):
    """(ball sole point y, z, foot pitch, toe pitch, planted) of a foot at frame f."""
    s = STANCE / float(L)
    ph = phase(f, side)
    if ph < s:
        u = ph / s
        return FRONT + D * u, 0.0, PITCH_ST + 10.0 * u * u, 0.0, True
    v = (ph - s) / (1.0 - s)
    e = 0.5 - 0.5 * math.cos(math.pi * v)
    y = FRONT + D - D * e
    z = LIFT * math.sin(math.pi * v) ** 0.9
    return y, z, PITCH_SW, TOE_SW * math.sin(math.pi * v), False


def pelvis_h(f):
    # lowest mid-stance (the knee gives), highest mid-float: two bobs per cycle
    mid_float = (STANCE + (L / 2.0 - STANCE) / 2.0) / (L / 2.0)
    return H0 + BOB * (0.5 + 0.5 * math.cos(2 * math.pi * (2 * f / float(L) - mid_float)))


def body(k):
    """Upper body at step phase k (+1 = the left foot leading)."""
    return merge(PAWS, gloves(34, 12),
                 {"pelvis": [("x", 12), ("z", 7 * k)]}, lean(fwd=16, side=-2 * k, turn=-10 * k),
                 head(x=-18, y=2 * k, z=8 * k),
                 {"upperarm_l": [("y", 30 - 6 * k), ("z", -58 + 8 * k)], "upperarm_r": [("y", -30 - 6 * k), ("z", 58 + 8 * k)]})


def build(ctx):
    sk = ctx.skel
    c = Clip(ctx, "hush/loco_walk", length=L, loop=True, cheat_deg=20, audio="own", stride_m=SPEED * L / 60.0,
             speed_m_s=SPEED)
    c.key(0, body(1.0))
    c.key(L // 2, body(-1.0))
    c.key(L, body(1.0))
    # the paws bob with the steps; the head floats (counter-bob)
    c.motion(lambda f: {"lowerarm_l": [("z", -8 * math.sin(4 * math.pi * f / L))],
                        "lowerarm_r": [("z", 8 * math.sin(4 * math.pi * f / L + 0.6))],
                        "hand_l": [("y", 10 * math.sin(4 * math.pi * f / L + 1.2))],
                        "hand_r": [("y", -10 * math.sin(4 * math.pi * f / L + 1.8))],
                        "Head": [("x", 3 * math.sin(4 * math.pi * f / L + 2.0))]})
    rest_pel = sk.head("pelvis").z

    def legs(pose, f):
        # pelvis height
        pz = pose.pelvis_offset().z
        pose.add_pelvis_offset(Vector((0, 0, (pelvis_h(f) - rest_pel) - pz)))
        for side in ("l", "r"):
            ft, bl = "foot_" + side, "ball_" + side
            y, z, pitch, toe, planted = foot_target(f, side)
            x = sk.head(ft).x * 0.9
            Mf = sk.rest_q[ft]
            Rf = P.rot_q([("x", pitch)]) @ Mf
            heel_pt, ball_pt, toe_pt = [pt for _, pt in sk.soles()[side]]
            ankle_rest = sk.head(ft)
            target = Vector((x, y, z))
            ankle = target - (Rf @ Mf.inverted()) @ (ball_pt - ankle_rest)
            P.solve_leg(pose, side, ankle, foot_world=Rf, knee_dir=Vector((0, -1.0, 0.15)))
            pose.set_world_rot(bl, P.rot_q([("x", toe)]) @ sk.rest_q[bl])
    c.custom(legs, 0, L)
    c.sfx(0, "step_pizz_up")
    c.sfx(L // 2, "step_pizz_up")
    c.face(0, "sneak")
    return c
