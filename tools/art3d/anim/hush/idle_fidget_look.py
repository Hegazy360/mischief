"""hush/idle_fidget_look — idle flavour after ≥ 3 s still (`idle:fidgets`, 80 f; the 2D beat kept: the ear-cup and the eye
dart by f 9): she cups her right glove to her ear — listening for him — cocks her head, then peers round, left over
her shoulder and back right past the audience with the glove shading her eyes, and settles. Starts and ends on
loco_idle's first pose (weight on her left, the left glove on her hip); interruptible at any frame."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge
from lib.hush_presets import gloves, glove, lean, head, breath, clarence
from loco_idle import base

L = 80
# FK arm shapes near the IK below (the IK puts the glove exactly on the ear / the brow and follows the head)
EAR = {"clavicle_r": [("y", 10)], "upperarm_r": [("y", 30), ("z", 20)], "lowerarm_r": [("z", 130)]}
SHADE = {"clavicle_r": [("y", 10)], "upperarm_r": [("y", 20), ("z", 40)], "lowerarm_r": [("z", 125)]}
EAR_PT = Vector((-0.175, 0.06, 1.33))       # behind her right ear (rest space, rides on the head)
BROW_PT = Vector((-0.07, -0.17, 1.46))      # a visor over her eyes


def build(ctx):
    c = Clip(ctx, "hush/idle_fidget_look", length=L, cheat_deg=35, blend_in=6, blend_out=8,
             audio="own")
    A = base(+1)
    c.key(0, A)
    c.key(9, merge(A, EAR, glove("r", 30, 10), head(x=4, y=-18, z=-10), lean(side=-6)), "in_out_sine")     # listen!
    c.key(20, merge(A, EAR, glove("r", 34, 10), head(x=6, y=-22, z=-14), lean(side=-8)))
    c.key(28, merge(A, SHADE, glove("r", 0, 0), head(x=-6, y=4, z=46), lean(turn=14, side=-2)), "in_out_cubic")  # left
    c.key(38, merge(A, SHADE, glove("r", 0, 0), head(x=-8, y=6, z=52), lean(turn=16, side=-2)))
    c.key(50, merge(A, SHADE, glove("r", 0, 0), head(x=-4, y=-4, z=-44), lean(turn=-12, side=-4)), "in_out_cubic")  # right
    c.key(60, merge(A, SHADE, glove("r", 0, 0), head(x=-6, y=-6, z=-50), lean(turn=-14, side=-4)))
    c.key(70, merge(A, head(x=-2, y=3, z=-6)), "in_out_cubic")
    c.key(L, A, "in_out_sine")
    hip_l = ("pelvis", Vector((0.155, 0.03, 0.905)))
    c.ik("l", hip_l, 0, L, pole=(1.0, 0.7, 0.05), hand=[("x", -8), ("y", 58), ("z", 22)], blend=0)
    c.ik("r", ("Head", EAR_PT), 3, 44, pole=(-1.0, 0.3, 0.1), hand=[("z", 90), ("x", 10)], effector="palm", blend=6)
    c.ik("r", ("Head", BROW_PT), 40, 66, pole=(-1.0, 0.1, 0.3), hand=[("x", 90), ("z", 60), ("y", -20)], effector="palm",
         blend=6)
    c.motion(lambda f: breath(f, 120.0, 1.0))
    c.motion(lambda f: {"Head": [("z", 3.0 * math.sin(2 * math.pi * f / 7.0))] if 9 <= f <= 20 else []})   # the eye dart
    c.motion(lambda f: clarence(0.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "neutral")
    c.face(9, "curious")
    c.face(28, "sneak")
    c.face(50, "glance")
    c.face(70, "neutral")
    return c
