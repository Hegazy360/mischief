"""hush/act_wheeze — the held wheeze (clip_rules.json `oneshot:wheeze`: Clarence held, a loop ≤ 90 f; REDESIGN §4.2
Squeak's slow cousin): she has Clarence out of the brace in both gloves at her chest and squeezes him SLOWLY — he
squashes flat, a long rubber wheeze — cheeks puffed, shoulders creeping up to her ears with the strain, then eases off
and squeezes again. Loop, 60 f (the sim ends it)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, breath

L = 60
BASE = merge(STAND, {"upperarm_l": [("y", 50), ("z", -60)], "lowerarm_l": [("z", -100)],
                     "upperarm_r": [("y", -50), ("z", 60)], "lowerarm_r": [("z", 100)]},
             gloves(40, 24), lean(fwd=4), head(x=2, z=-8))
SQUEEZE = {"clavicle_l": [("y", -26), ("z", -8)], "clavicle_r": [("y", 26), ("z", 8)]}     # shoulders up to her ears
# the strain goes down through the body: knees dip, the spine curls over him (the feet stay planted)
STRAIN = {"thigh_l": [("x", -19), ("z", 4)], "calf_l": [("x", 36)], "foot_l": [("x", -17), ("z", -4)],
          "thigh_r": [("x", -18), ("z", -5)], "calf_r": [("x", 34)], "foot_r": [("x", -16), ("z", 5)]}
# the gasp after the squeeze: shoulders drop below rest, chin up — one small rebound, then the next squeeze
GASP = {"clavicle_l": [("y", 6)], "clavicle_r": [("y", -6)]}
# the gloves around Clarence, in front of her chest (rest points riding on spine_03)
GL = Vector((0.10, -0.30, 1.16))
GR = Vector((-0.08, -0.31, 1.21))


def squeeze(f):
    """0 -> 1 over the slow squeeze (f 0-40), back to 0 by f 60 (loop)."""
    if f <= 40:
        k = f / 40.0
        return k * k * (3 - 2 * k)
    k = (f - 40) / 20.0
    return 1.0 - k * k * (3 - 2 * k)


def build(ctx):
    c = Clip(ctx, "hush/act_wheeze", length=L, loop=True, cheat_deg=35, blend_in=6, blend_out=8, audio="own")
    c.key(0, BASE)
    c.key(40, merge(BASE, SQUEEZE, STRAIN, lean(fwd=20), head(x=12, z=-10)), "in_out_sine")   # hunched, straining
    c.key(48, merge(BASE, GASP, lean(fwd=-3), head(x=-6, z=-6)), "out_quad")                 # the gasp
    c.key(L, BASE, "in_out_sine")
    # the hands press together on Clarence as the squeeze builds; he squashes (clarence_body scale survives the bake)
    c.ik("l", lambda f: ("spine_03", GL + Vector((-0.05 * squeeze(f), 0.03 * squeeze(f), -0.03 * squeeze(f))))[1], 0, L, blend=0,
         pole=(1.0, 0.1, 0.1), hand=[("z", -80), ("x", 10)], effector="palm", world=False)
    c.ik("r", lambda f: ("spine_03", GR + Vector((0.05 * squeeze(f), 0.03 * squeeze(f), -0.03 * squeeze(f))))[1], 0, L, blend=0,
         pole=(-1.0, 0.1, 0.1), hand=[("z", 80), ("x", 10)], effector="palm", world=False)
    c.motion(lambda f: {"clarence_body": {"r": [], "s": (1.0 + 0.5 * squeeze(f), 1.0 - 0.6 * squeeze(f),
                                                          1.0 + 0.5 * squeeze(f))},
                        "clarence_comb": [("x", 30 * squeeze(f))]})
    c.motion(lambda f: breath(f, 30.0, 0.8))
    c.motion(lambda f: {"Head": [("y", 1.5 * math.sin(2 * math.pi * f * 3 / L))]})         # the strain tremble
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.event(0, "prop", op="attach", prop="clarence", socket="grip_r")
    c.mark(0, "contact")
    c.sfx(0, "wheeze_chicken")
    c.face(0, "hold_breath")
    # lead note D8: the held breath faces the camera (runtime gaze; the gloves are not on the head)
    c.look_camera(0, L, weight=0.9, blend=6)
    return c
