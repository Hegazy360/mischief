"""hush/idle_fidget_clarence — idle flavour (`idle:fidgets`, 80 f; the 2D beat and the audio-table row kept:
Clarence up and smitten by f 12 — `clarence_smitten` at f 12 —, home at f 60): the rubber chicken pops up out of her
brace and gazes at the audience; she looks down at him, raises one glove finger to her lips — "shhh!" — and pats him
back down into the brace. Starts and ends on loco_idle's first pose. Interruptible at any frame."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge
from lib.hush_presets import gloves, glove, lean, head, breath, clarence
from loco_idle import base

L = 80
SHUSH = {"clavicle_r": [("y", 6)], "upperarm_r": [("y", 40), ("z", 76)], "lowerarm_r": [("y", 116), ("z", 8)],
         "hand_r": [("x", -10), ("z", -20)]}
POINT = merge(glove("r", 80, 30), {"index_01_r": [("y", 0)], "index_02_r": [("y", 0)], "index_03_r": [("y", 0)]})
PAT = {"clavicle_r": [("y", 2)], "upperarm_r": [("y", -60), ("z", 44)], "lowerarm_r": [("z", 64)], "hand_r": [("x", -30)]}
LIPS = Vector((-0.02, -0.25, 1.30))       # in front of her mouth (rest space, rides on the head)
CLARENCE_TOP = Vector((-0.075, -0.17, 1.06))  # just over Clarence's head in her right brace (rides on spine_02)


def peek(f):
    if f < 4 or f > 66:
        return clarence(0.0)
    k = min(1.0, (f - 4) / 8.0) if f < 58 else max(0.0, (66 - f) / 8.0)
    k = k * k * (3 - 2 * k)
    bob = 8 * math.sin(2 * math.pi * (f - 12) / 18.0) * k if 12 <= f < 40 else 0.0
    return clarence(1.5 * k, bob=bob)


def build(ctx):
    c = Clip(ctx, "hush/idle_fidget_clarence", length=L, cheat_deg=35, blend_in=6, blend_out=8)
    A = base(+1)
    c.key(0, A)
    c.key(12, merge(A, head(x=4, y=-2, z=-4)), "in_out_sine")
    c.key(20, merge(A, head(x=26, y=-10, z=-22), lean(fwd=6, turn=-8)), "in_out_cubic")           # she looks down at him
    c.key(28, merge(A, SHUSH, POINT, head(x=16, y=-8, z=-18), lean(fwd=6, turn=-8)), "in_out_cubic")  # "shhh!"
    c.key(44, merge(A, SHUSH, POINT, head(x=18, y=-10, z=-20), lean(fwd=7, turn=-9)))
    c.key(54, merge(A, PAT, glove("r", 10, 8), head(x=24, y=-8, z=-26), lean(fwd=8, turn=-12)), "in_out_cubic")   # pat
    c.key(60, merge(A, PAT, glove("r", 10, 8), {"hand_r": [("x", -10)]}, head(x=20, z=-24), lean(fwd=7, turn=-10)), "out_quad")
    c.key(68, merge(A, head(x=-2, y=3, z=-4)), "in_out_cubic")
    c.key(L, A, "in_out_sine")
    hip_l = ("pelvis", Vector((0.155, 0.03, 0.905)))
    c.ik("l", hip_l, 0, L, pole=(1.0, 0.7, 0.05), hand=[("x", -8), ("y", 58), ("z", 22)], blend=0)
    # "shhh!": the index finger up against her lips (IK on the finger tip, riding the head), then the pat on his head
    c.ik("r", ("Head", LIPS), 22, 52, pole=(-1.0, 0.2, -0.5), hand=[("z", 90), ("x", 90)], effector="palm", blend=8)
    c.ik("r", ("spine_02", CLARENCE_TOP), 46, 70, pole=(-1.0, 0.1, -0.2), hand=[("z", 70), ("x", 80)], effector="palm",
         blend=9)
    c.motion(lambda f: breath(f, 120.0, 1.0))
    c.motion(peek)
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.mark(12, "contact")                       # Clarence up (the audio table's smitten squeak lands here)
    c.face(0, "neutral")
    c.face(12, "curious")
    c.face(26, "shush")
    c.face(54, "happy")
    c.face(68, "neutral")
    return c
