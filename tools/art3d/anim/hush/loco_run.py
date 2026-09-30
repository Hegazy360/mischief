"""hush/loco_run — the cartoon dash (run, loop): lean 25° into it, fists pumping, knees high, bounding on the balls of
her feet with a real flight phase; 3.6 m/s, 5 steps/s (a 24 f cycle = the table's steps at f 0 / 12, stride 1.44 m),
in place (the view moves her; the lint checks the planted balls in lane space); a dust puff at each contact (the view
draws the 2.5 m noise ring). Cheat 20°.

Procedural feet (like loco_walk): a short stance sliding back at exactly 3.6 m/s, a high swing, legs by IK; the upper
body is keyed + layered."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from lib.pose import merge
from lib.hush_presets import gloves, lean, head

L = 24                 # frames per cycle (two steps)
SPEED = 3.6            # m/s
STANCE = 5             # frames each foot is planted (a 7 f flight between the steps)
D = SPEED * STANCE / 60.0          # 0.30 m the planted ball travels back in clip space
FRONT = -0.20          # the ball's y at touch-down (armature -y = her front), a little ahead of the hip
LIFT = 0.34            # swing height of the ball
PITCH_ST, PITCH_SW = 22.0, 40.0
TOE_SW = 20.0
H0, BOB = 0.82, 0.05   # pelvis height at mid-stance and the rise into the flight


def phase(f, side):
    return ((f / float(L)) + (0.0 if side == "l" else 0.5)) % 1.0


def foot_target(f, side):
    s = STANCE / float(L)
    ph = phase(f, side)
    if ph < s:
        u = ph / s
        return FRONT + D * u, 0.0, PITCH_ST + 8.0 * u, 0.0, True
    v = (ph - s) / (1.0 - s)
    # the heel kicks up behind first, then the knee drives the foot forward and high
    e = 0.5 - 0.5 * math.cos(math.pi * v)
    y = FRONT + D - D * e + 0.22 * math.sin(math.pi * min(1.0, v * 1.6)) * (1.0 - v)
    z = LIFT * math.sin(math.pi * v) ** 0.8
    return y, z, PITCH_SW, TOE_SW * math.sin(math.pi * v), False


def pelvis_h(f):
    mid_flight = (STANCE + (L / 2.0 - STANCE) / 2.0) / (L / 2.0)
    return H0 + BOB * (0.5 + 0.5 * math.cos(2 * math.pi * (2 * f / float(L) - mid_flight)))


def pump(k):
    """Fists pumping hard (left arm forward at k = +1): the elbows at 90 degrees, a big swing fore and aft."""
    def arm(side, a):
        s = 1 if side == "l" else -1
        return {"clavicle_%s" % side: [("y", -4 * s)],
                "upperarm_%s" % side: [("y", 64 * s), ("z", -8 * s), ("x", -58 * a)],   # the swing is about her x
                "lowerarm_%s" % side: [("z", s * (-88 - 18 * max(0.0, a)))], "hand_%s" % side: [("x", -12)]}
    return merge(arm("l", k), arm("r", -k))


def body(k):
    """Upper body at step phase k (+1 = the left foot leading)."""
    return merge(pump(k), gloves(78, 46), {"pelvis": [("x", 12), ("z", 10 * k)]},
                 lean(fwd=24, side=-2 * k, turn=-14 * k), head(x=-22, y=2 * k, z=12 * k))


def build(ctx):
    sk = ctx.skel
    c = Clip(ctx, "hush/loco_run", length=L, loop=True, cheat_deg=20, audio="table", stride_m=SPEED * L / 60.0,
             speed_m_s=SPEED)
    c.key(0, body(1.0))
    c.key(L // 2, body(-1.0))
    c.key(L, body(1.0))
    c.motion(lambda f: {"Head": [("x", 3 * math.sin(4 * math.pi * f / L + 2.2))],
                        "spine_03": [("x", 2 * math.sin(4 * math.pi * f / L + 1.0))]})
    rest_pel = sk.head("pelvis").z

    def legs(pose, f):
        pz = pose.pelvis_offset().z
        pose.add_pelvis_offset(Vector((0, 0, (pelvis_h(f) - rest_pel) - pz)))
        for side in ("l", "r"):
            ft, bl = "foot_" + side, "ball_" + side
            y, z, pitch, toe, planted = foot_target(f, side)
            x = sk.head(ft).x * 0.8
            Mf = sk.rest_q[ft]
            Rf = P.rot_q([("x", pitch)]) @ Mf
            heel_pt, ball_pt, toe_pt = [pt for _, pt in sk.soles()[side]]
            ankle = Vector((x, y, z)) - (Rf @ Mf.inverted()) @ (ball_pt - sk.head(ft))
            P.solve_leg(pose, side, ankle, foot_world=Rf, knee_dir=Vector((0, -1.0, 0.1)))
            pose.set_world_rot(bl, P.rot_q([("x", toe)]) @ sk.rest_q[bl])
    c.custom(legs, 0, L)
    for f in (0, L // 2):
        c.event(f, "fx", id="dust_puff")
    c.face(0, "determined")
    return c
