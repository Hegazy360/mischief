"""hush/idle_fidget_proud — idle flavour (`idle:fidgets`, 84 f; the 2D beat kept: fists on hips by f 10, two smug chin
bobs): both gloves slap onto her hips, chest OUT, up on her toes, two smug chin bobs at the audience, then the right
glove sweeps out in a "ta-da" flourish and she sinks back to loco_idle's first pose. Interruptible at any frame."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge
from lib.hush_presets import gloves, glove, lean, head, breath
from loco_idle import base, FLOURISH_UP, FLOURISH_TA

L = 84
CHEST = merge(lean(fwd=-10, side=-2), {"clavicle_l": [("y", -6), ("z", 8)], "clavicle_r": [("y", 6), ("z", -8)]})
FISTS = merge(gloves(80, 40))


def build(ctx):
    c = Clip(ctx, "hush/idle_fidget_proud", length=L, cheat_deg=35, blend_in=6, blend_out=8, audio="own")
    A = base(+1)
    c.key(0, A)
    c.key(6, merge(A, CHEST, FISTS, head(x=-6)), "in_out_sine")                                  # (the breath in)
    c.key(10, merge(A, CHEST, FISTS, head(x=-14, z=-8)), "out_back")                       # fists on hips, chest out
    c.key(20, merge(A, CHEST, FISTS, head(x=-16, z=-10)))
    c.key(24, merge(A, CHEST, FISTS, head(x=4, z=-12)), "out_quad")                        # chin bob 1
    c.key(30, merge(A, CHEST, FISTS, head(x=-14, z=-12)), "in_out_sine")
    c.key(36, merge(A, CHEST, FISTS, head(x=4, z=-14)), "out_quad")                        # chin bob 2
    c.key(44, merge(A, CHEST, FISTS, head(x=-12, z=-12)), "in_out_sine")
    c.key(52, merge(A, CHEST, FISTS, FLOURISH_UP, head(x=-6, z=-16)), "in_out_cubic")             # the flourish ...
    c.key(60, merge(A, CHEST, FLOURISH_TA, glove("r", 2, 0, spread=20), head(x=-10, z=-20)), "out_back")   # ... ta-da
    c.key(70, merge(A, FLOURISH_TA, glove("r", 4, 2, spread=16), head(x=-6, z=-14)))
    c.key(L, A, "in_out_cubic")
    hip_l = ("pelvis", Vector((0.155, 0.03, 0.905)))
    hip_r = ("pelvis", Vector((-0.155, 0.03, 0.905)))
    c.ik("l", hip_l, 0, L, pole=(1.0, 0.7, 0.05), hand=[("x", -8), ("y", 58), ("z", 22)], blend=0)
    c.ik("r", hip_r, 4, 50, pole=(-1.0, 0.7, 0.05), hand=[("x", -8), ("y", -58), ("z", -22)], blend=5)
    c.motion(lambda f: breath(f, 60.0, 1.4))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "neutral")
    c.face(10, "smug")
    c.face(52, "proud")
    c.face(72, "neutral")
    # lead note D8: showing off to the Stalls — the face turns to the camera (runtime gaze, facing-proof, 8 f ease)
    c.look_camera(6, 78, weight=1.0, blend=8)
    return c
