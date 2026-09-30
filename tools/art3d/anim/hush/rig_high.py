"""hush/rig_high — the band fallback for a HIGH reach (1.40–2.15 m: rig_actions.json `bands.high`; N1/N2 pranks without
a clip of their own — the pickle-jar lid, the clock face, the mirror top). Normalised: one clip serves the Q / S / B
tiers (lock rig_pm), authored at 120 f.

What it must read as (REDESIGN §4.2 Rig DURING, index R5c): the mime's INVISIBLE STEP — above 1.70 m this is the only
way B's arms reach. She pats an invisible rail (the gloves stop dead on the same plane: mime), taps the invisible step
with her toe (the foot stops in mid-air), hops up onto nothing (pelvis +0.40, `step_up("mime", 0.40)`), wobbles and
beams at the audience (look: standing on air), then reaches UP to the thing and cranks it with both gloves over her
head, elbows high; she hops down by the last frame (a stepped clip ends on the floor, R5d). No baked glances.

Staging as `rig_mid` (baked facing +1, cheat 10°, the thing ahead and up-stage at her front-left), glove target 1.90 m."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, TIPTOE, gloves, glove, lean, head, breath
from rig_mid import stage, add_reach_offset, LEGS

L = 120
Y = 1.86                        # glove height of the band's typical high target
H = 0.40                        # the invisible step
TARGET_W = (0.24, Y, -1.70)     # relative to reach_pos (x 0, z -1.5)
RAIL_W = (0.22, 0.86, -1.50)    # the invisible rail she pats (waist height, straight ahead)
UP0, UP1 = 20, 27               # the hop up onto nothing
DN0, DN1 = 103, 110             # the hop down
WORK = ((42, 60), (60, 78), (78, 96))    # three cranking rounds
PATS = (6, 11)
TAPS = (15, 18)

REST = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-4))
# flat mime palms, the arms forward toward the invisible rail (FK near the IK: no slerp flips)
FLAT = merge(gloves(4, 2, spread=6), {"upperarm_l": [("y", 50), ("z", -50)], "lowerarm_l": [("z", -30)], "hand_l": [("x", -60)], "hand_r": [("x", -60)],
                                      "upperarm_r": [("y", -50), ("z", 50)], "lowerarm_r": [("z", 30)]})
GRIP = merge(gloves(56, 30), glove("r", 64, 36))
CROUCH = {"thigh_l": [("x", -38), ("z", 4)], "calf_l": [("x", 66)], "foot_l": [("x", -26)],
          "thigh_r": [("x", -34), ("z", -4)], "calf_r": [("x", 62)], "foot_r": [("x", -26)]}
TUCK = {"thigh_l": [("x", -62), ("z", 4)], "calf_l": [("x", 86)], "foot_l": [("x", 10)],
        "thigh_r": [("x", -58), ("z", -4)], "calf_r": [("x", 82)], "foot_r": [("x", 10)]}
# the toe test: the right knee up, the sole flat on the step's top (in the air, 0.40 m)
TOE_TEST = {"thigh_r": [("x", -64), ("y", 4)], "calf_r": [("x", 60)], "foot_r": [("x", -6)],
            "thigh_l": [("x", -4)], "calf_l": [("x", 10)]}
TOE_TOUCH = {"thigh_r": [("x", -58), ("y", 4)], "calf_r": [("x", 74)], "foot_r": [("x", -4)],
             "thigh_l": [("x", -4)], "calf_l": [("x", 12)]}
ARMS_UP = {"clavicle_r": [("y", -10), ("z", 10)], "upperarm_r": [("y", 40), ("z", 60)], "lowerarm_r": [("z", 60)],
           "clavicle_l": [("y", 10), ("z", -8)], "upperarm_l": [("y", -30), ("z", -40)], "lowerarm_l": [("z", -60)]}
BALANCE = merge(sym({"upperarm_l": [("y", 10), ("z", 4)], "lowerarm_l": [("z", -20), ("y", 10)], "hand_l": [("x", -10)]}),
                glove("l", 4, 2, spread=18), glove("r", 4, 2, spread=18))


def body(turn=20.0, fwd=4.0, side=8.0, up=0.0):
    """Standing on the step, shoulders turned into the thing, the chest lifted toward it (up = back-bend)."""
    return merge(LEGS, {"pelvis": [("z", 6)], "_pelvis": (0.03, 0.0, 0.0)}, lean(fwd=fwd - up, side=side, turn=turn))


def crank(f, T):
    """(right glove = the crank circling the key, left glove = holding the thing's rim) at frame f: 1.5 turns a round,
    continuous across the rounds (and held where it stops outside them)."""
    a0, b1 = WORK[0][0], WORK[-1][1]
    u = min(1.0, max(0.0, (f - a0) / float(b1 - a0)))
    ang = 2.0 * math.pi * 1.5 * len(WORK) * u
    r = 0.085
    top = T + Vector((-0.13, 0.01, -0.08)) + Vector((0.0, r * math.cos(ang), r * math.sin(ang)))
    return top, T + Vector((-0.05, 0.08, -0.03))


def build(ctx):
    st = stage()
    T = st.to_char(TARGET_W)
    rail = st.to_char(RAIL_W)
    c = Clip(ctx, "hush/rig_high", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own",
             notes="band fallback, high: the mime step %.2f m, glove target %.2f m, baked facing +1" % (H, Y))
    # 1. pat the invisible rail (the palms stop on one plane), 2. toe-test the invisible step
    c.key(0, REST)
    c.key(4, merge(REST, FLAT, lean(fwd=6), head(x=6, z=-10)), "in_out_sine")
    c.key(PATS[0], merge(REST, FLAT, lean(fwd=8), head(x=8, z=-12)), "out_quad")
    c.key(9, merge(REST, FLAT, lean(fwd=6), head(x=6, z=-12)))
    c.key(PATS[1], merge(REST, FLAT, lean(fwd=8), head(x=10, z=-14)), "out_quad")
    c.key(13, merge(REST, FLAT, TOE_TEST, lean(fwd=4), head(x=14, z=-10)), "in_out_sine")
    c.key(TAPS[0], merge(REST, FLAT, TOE_TOUCH, lean(fwd=5), head(x=16, z=-10)), "out_quad")
    c.key(17, merge(REST, FLAT, TOE_TEST, lean(fwd=4), head(x=14, z=-8)))
    c.key(TAPS[1], merge(REST, FLAT, TOE_TOUCH, lean(fwd=5), head(x=16, z=-8)), "out_quad")
    # 3. the hop up onto nothing, a wobble, a beam at the audience
    c.key(UP0, merge(REST, FLAT, CROUCH, lean(fwd=14), head(x=-4)), "in_out_sine")
    c.key(24, merge(REST, BALANCE, TUCK, lean(fwd=4), head(x=-8)), "out_quad")
    c.key(UP1, merge(BALANCE, CROUCH, lean(fwd=10, side=4), head(x=-2)), "in_quad")
    c.key(31, merge(BALANCE, STAND, lean(fwd=-2, side=-8), head(x=-6, y=8)), "out_back")
    c.key(35, merge(BALANCE, STAND, lean(fwd=0, side=6), head(x=-6, y=-6)), "in_out_sine")
    # 4. reach up and crank it, three rounds, bouncing on the step
    c.key(40, merge(body(), ARMS_UP, GRIP), "in_out_cubic")
    for a, b in WORK:
        m = (a + b) // 2
        c.key(m, merge(body(turn=20, up=8, side=6), ARMS_UP, GRIP, TIPTOE), "in_out_sine")
        c.key(b, merge(body(turn=14, up=2, side=3), ARMS_UP, GRIP, {"calf_l": [("x", 18)], "calf_r": [("x", 14)]}),
              "in_out_sine")
    c.key(100, merge(REST, BALANCE, STAND, lean(fwd=6), head(x=-2)), "in_out_cubic")
    # 5. hop down, land, settle
    c.key(DN0, merge(REST, BALANCE, CROUCH, lean(fwd=12)), "in_out_sine")
    c.key(106, merge(REST, BALANCE, TUCK, lean(fwd=4)), "out_quad")
    c.key(DN1, merge(REST, BALANCE, CROUCH, lean(fwd=10)), "in_quad")
    c.key(L, merge(REST, gloves(12, 8, spread=8), lean(fwd=2), head(x=-2)), "in_out_sine")
    c.motion(lambda f: breath(f, 40.0, 1.2))
    c.ground()
    c.step_up("mime", H, UP0, UP1)
    c.step_down(DN0, DN1)
    c.auto_plant(speed_m_s=0.0)
    # the palms on the rail (IK: they stop dead on one plane, twice), then the gloves on the thing
    pat = lambda f: 0.05 * max(0.0, math.sin(math.pi * (f - 4) / 5.0)) if 4 <= f <= 13 else 0.0
    c.ik("r", lambda f: rail + Vector((-0.10, -0.06, pat(f))), 2, 19, pole=(-0.8, 0.3, -0.4), hand=[("x", -85), ("z", 10)],
         effector="palm", blend=5, world=False)
    c.ik("l", lambda f: rail + Vector((0.06, 0.02, pat(f))), 2, 19, pole=(0.8, 0.3, -0.4), hand=[("x", -85), ("z", -10)],
         effector="palm", blend=5, world=False)
    c.ik("r", lambda f: crank(f, T)[0], 33, 100, pole=(-0.6, 0.3, 0.7), hand=[("z", 40), ("x", -100)],
         effector="palm", blend=8, world=False)
    c.ik("l", lambda f: crank(f, T)[1], 33, 100, pole=(0.8, 0.3, 0.3), hand=[("z", -40), ("x", -100)],
         effector="palm", blend=8, world=False)
    c.look(("camera",), 24, 100, weight=0.9, blend=6, bones=("neck_01", "Head"), share=(0.4, 0.6))
    c.pop_frames.extend([UP1, UP1 + 1, DN1, DN1 + 1])      # the landings (on nothing, then the floor)
    for f in PATS:
        c.mark(f, "contact")
    for f in TAPS:
        c.mark(f, "contact")
    c.sfx(TAPS[0], "tiptoe")
    c.sfx(UP1, "slide_up_short")
    for a, b in WORK:
        c.mark(b - 1, "contact")
        c.sfx(b - 1, "tinker")
    c.sfx(DN1, "land_soft")
    c.face(0, "sneak")
    c.face(13, "curious")
    c.face(UP1, "proud")
    c.face(40, "determined")
    c.face(60, "frantic")
    c.face(70, "determined")
    c.face(96, "frantic")
    c.face(DN1, "grin")
    add_reach_offset(c, TARGET_W)
    return c
