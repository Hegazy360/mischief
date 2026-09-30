"""hush/rig_mid — the band fallback for a MID reach (0.55–1.40 m: rig_actions.json `bands.mid`; N1/N2 pranks without a
clip of their own — kettle, sink tap, fridge shelf, newspaper, phone). Normalised: one clip serves the Q / S / B tiers
(lock rig_pm: frame = rig progress ‰ × length), so it reads at any speed.

What it must read as (REDESIGN §4.2 Rig DURING, W1): "she is fiddling with THAT thing" — not the 2D generic tinker. She
plants her feet wide beside the prop, turns her shoulders into it and gets BOTH gloves on it: the top glove cranks a
twist (elbow winging up and out), the other hand holds, then a lean-back TUG; three twist-and-tug rounds, a proud pat.
Her head stays turned to the audience (the face reads: tongue out, concentrating, then a grin). No baked glances: the
view overlays hush/act_glance at rig_actions.json's ‰ marks.

Staging (index R5d, §7.10): baked facing +1, cheat 10°, the thing 0.30 m AHEAD of her and 0.28 m up-stage (her
front-left, 45°) — so her body never hides it or her gloves from the camera (requested of r3d-sets: band props'
reach_pos.dx = −0.30, she stands beside the prop, not in front of it); the view plays it with the sidecar's
`stage.facing`. The glove target is the band's typical height (1.00 m); `freeze_midjob` reuses this module's poses."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, breath

L = 96
Y = 1.00                        # glove height (the band's typical reach target)
TARGET_W = (0.26, Y, -1.70)     # the reach target, world, relative to reach_pos (x 0, z -1.5): ahead and up-stage
CYCLES = ((14, 38), (38, 62), (62, 86))   # twist (first 2/3) then tug (last 1/3) per round
TWIST_F = 14                              # frames of cranking per round, then the tug
TUGS = [a + TWIST_F for a, _ in CYCLES]   # the tug accents


def stage():
    return Stage(x=0.0, z=-1.5, facing=1, cheat=10.0)


# the working stance: feet wide, weight on the up-stage (left) leg, shoulders turned into the prop
LEGS = merge(STAND, {"thigh_l": [("x", -8), ("y", -9), ("z", 6)], "calf_l": [("x", 16)], "foot_l": [("x", -6), ("z", -6)],
                     "thigh_r": [("x", 4), ("y", 8), ("z", -8)], "calf_r": [("x", 8)], "foot_r": [("x", -2), ("z", 8)]})


def body(turn=22.0, fwd=12.0, side=4.0, pel=8.0, shrug=0.0):
    """The torso (IK does the arms): hips and shoulders turned toward the prop (her left), leaning into it."""
    return merge(LEGS, {"pelvis": [("z", pel), ("y", -3)], "_pelvis": (0.035, 0.0, 0.0)},
                 lean(fwd=fwd, side=side, turn=turn),
                 {"clavicle_l": [("y", -6 - shrug), ("z", -6)], "clavicle_r": [("y", 4 + shrug), ("z", 10)]})


REST = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-4))
# the up-stage foot comes up and braces its sole against the prop's front (knee up, out toward it)
BRACE_UP = {"thigh_l": [("x", -48), ("y", -12), ("z", 10)], "calf_l": [("x", 70)], "foot_l": [("x", -10)]}
BRACE = {"thigh_l": [("x", -62), ("y", -18), ("z", 12)], "calf_l": [("x", 36)], "foot_l": [("x", -34)]}
# FK arms close to the IK solution (the IK then corrects a few degrees: no slerp flips on the blend)
ARMS = {"clavicle_r": [("z", 14)], "upperarm_r": [("y", -24), ("z", 72)], "lowerarm_r": [("z", 48)], "hand_r": [("x", -30)],
        "upperarm_l": [("y", 40), ("z", -48)], "lowerarm_l": [("z", -62)], "hand_l": [("x", -20)]}
GRIP = merge(gloves(58, 30), glove("r", 64, 36), ARMS)         # gloves closed on the thing


def twist_phase(f):
    """(round index, u in 0..1 through the twist, tug 0..1) at frame f."""
    for i, (a, b) in enumerate(CYCLES):
        if a <= f < b:
            t0 = a + TWIST_F
            if f < t0:
                return i, (f - a) / float(TWIST_F), 0.0
            d = f - t0                                  # the pull: 4 f out, eased back by the round's end
            if d <= 4:
                k = d / 4.0
                return i, 1.0, k * k * (3 - 2 * k)
            k = min(1.0, (d - 4) / float(max(1, b - t0 - 4)))
            return i, 1.0, 1.0 - k * k * (3 - 2 * k)
    return -1, 0.0, 0.0


def targets(f, T):
    """Glove targets (armature space) around the reach target T: the top glove cranks a circle, the lower one holds the
    front of the thing; a tug pulls both 6 cm toward her."""
    i, u, tug = twist_phase(f)
    a = 2.0 * math.pi * u
    r = 0.075
    toward = Vector((-0.6, 0.8, 0.15)).normalized()      # from the prop back toward her chest
    # the crank circles in her front/up plane (the camera sees it face-on: she is side-on to the audience)
    top = T + Vector((-0.13, 0.05, 0.09)) + Vector((0.0, r * math.cos(a), r * math.sin(a))) + toward * (0.11 * tug)
    low = T + Vector((0.04, 0.05, -0.05)) + toward * (0.11 * tug)
    return top, low


def add_work(c, T, f0, f1, blend=8, fixed=None):
    """The two IK gloves on the thing over [f0, f1]; `fixed` = a frame whose targets are held (freeze_midjob)."""
    fn = (lambda f: targets(f, T)) if fixed is None else (lambda f, _t=targets(fixed, T): _t)
    # the down-stage (right) glove cranks on top — the camera sees it — the up-stage one holds the thing below
    c.ik("r", lambda f: fn(f)[0], f0, f1, pole=(-0.45, 0.35, 1.0), hand=[("z", 40), ("x", -60), ("y", -20)],
         effector="palm", blend=blend, world=False)
    c.ik("l", lambda f: fn(f)[1], f0, f1, pole=(0.85, 0.2, -0.4), hand=[("z", -30), ("x", -20), ("y", 60)],
         effector="palm", blend=blend, world=False)


def build(ctx):
    st = stage()
    T = st.to_char(TARGET_W)
    c = Clip(ctx, "hush/rig_mid", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own",
             notes="band fallback, mid: glove target %.2f m, baked facing +1" % Y)
    c.key(0, REST)
    c.key(8, merge(REST, body(turn=18, fwd=4, side=2, pel=3), head(x=-2, z=-6), ARMS, gloves(30, 16)), "in_out_sine")   # reaches in
    c.key(14, merge(body(), GRIP), "in_out_cubic")
    for i, (a, b) in enumerate(CYCLES):
        t0 = a + TWIST_F
        last = i == len(CYCLES) - 1
        # the twist: shoulders wind up with the crank, the elbow wings up
        c.key(a + 8, merge(body(turn=26, fwd=14, side=6, shrug=6), GRIP))
        antic = merge(body(turn=28, fwd=18, side=7, shrug=10), GRIP)
        tug = merge(body(turn=14, fwd=-14, side=-2, pel=-2, shrug=-6), GRIP, head(x=8),
                    {"_pelvis": (0.035, 0.07, 0.0), "thigh_l": [("x", -22), ("y", -9), ("z", 6)], "calf_l": [("x", 40)],
                     "calf_r": [("x", 26)], "thigh_r": [("x", 2), ("y", 8), ("z", -8)]})
        if last:
            # the big one: her up-stage foot braced flat against the thing, hauling back (the cartoon tug)
            antic = merge(antic, BRACE_UP)
            tug = merge(body(turn=16, fwd=-20, side=-4, pel=-4, shrug=-8), GRIP, head(x=10), BRACE,
                        {"_pelvis": (0.035, 0.09, 0.0), "thigh_r": [("x", 6), ("y", 8), ("z", -8)], "calf_r": [("x", 30)],
                         "foot_r": [("x", -14)]})
        c.key(t0 - 3, antic, "in_out_sine")                                                     # anticipation of the tug
        c.key(t0, tug, "out_quad")                                                              # TUG: she hangs back
        c.key(b - 1, merge(body(turn=22, fwd=10, side=4), GRIP, BRACE if last else {}), "out_back")
    c.key(90, merge(body(turn=20, fwd=6, side=3), GRIP, glove("r", 10, 6, spread=10)), "in_out_cubic")   # foot down, a proud pat
    c.key(L, merge(body(turn=18, fwd=4, side=2), GRIP, glove("r", 6, 4, spread=14)), "in_out_sine")
    add_work(c, T, 6, L, blend=8)
    c.motion(lambda f: breath(f, 48.0, 1.4))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    # the face to the audience: neck + head only (the shoulders stay turned into the prop, the gloves stay on it)
    c.look(("camera",), 6, L, weight=0.9, blend=8, bones=("neck_01", "Head"), share=(0.4, 0.6))
    for f in TUGS:
        c.mark(f, "contact")
        c.sfx(f, "tinker")
    c.face(0, "sneak")
    c.face(12, "determined")
    c.face(TUGS[0], "frantic")
    c.face(TUGS[0] + 6, "determined")
    c.face(TUGS[1], "frantic")
    c.face(TUGS[1] + 6, "determined")
    c.face(TUGS[2], "frantic")
    c.face(88, "grin")
    return c
