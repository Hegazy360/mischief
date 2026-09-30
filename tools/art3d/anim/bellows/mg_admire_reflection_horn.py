"""bellows/mg_admire_reflection_horn — warm-up micro-gag (activities.json warmup `admire_reflection_horn`, emote smug;
60 f, OVERLAY `upper`, the view clock; the audio table: glint f 6, vo_bellows_smug f 14, kiss_smack f 42): "Leans into
the gramophone horn, sees his face bloom huge in the brass, blows it a kiss."

  0-6     he leans over toward the horn (at his right shoulder, house3d parlour_gramophone) — glint on 6
  6-14    peering into the brass, chin tilted, admiring
  14-26   a SMUG look back to the house (the face to the camera, D8): "not bad, eh?"
  26-40   back to the horn, lips puckered, the baton glove rises to his lips
  42      the KISS: the glove flung open toward the horn (kiss_smack)
  42-60   back to the warm-up carriage, delighted

Staged at st_gramophone (x 8.65, z -1.4, facing -1, cheat 35); the horn is the world point (8.2, 1.15, -1.9)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 60
HORN = (8.2, 1.15, -1.9)
SING_ARMS = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 38), ("z", -44)], "lowerarm_l": [("z", -34)],
             "hand_l": [("x", -30), ("y", -10)],
             "clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 40)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", -24), ("y", 8)]}
LIPS = ("Head", Vector((-0.04, -0.33, 1.13)))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def build(ctx):
    st = Stage(x=8.65, z=-1.4, facing=-1, cheat=35.0)
    c = Clip(ctx, "bellows/mg_admire_reflection_horn", length=L, layer="overlay", mask="upper", blend_in=6,
             blend_out=6, cheat_deg=35, stage=st, tags=["micro_gag", "warmup"])
    hide_fx(c)
    S = lambda *p: merge(STAND, grip("r", 64, 40), *p)
    SING = S(SING_ARMS, open_hand("l", 12), pompous(1.3), head(x=-16, z=4))
    c.key(0, SING)
    LEAN = S(SING_ARMS, glove("l", 20, 12), {"upperarm_l": [("y", 70), ("z", -20)], "lowerarm_l": [("z", -40)]},
             lean(fwd=8, side=-10, turn=-20), head(x=0, y=-10))
    c.key(6, LEAN, "out_cubic")                                                         # into the horn
    c.key(13, merge(LEAN, lean(fwd=9, side=-12, turn=-22), head(x=2, y=-14)), "in_out_sine")
    SMUG = S(SING_ARMS, glove("l", 20, 12), {"upperarm_l": [("y", 70), ("z", -20)], "lowerarm_l": [("z", -40)]},
             lean(fwd=2, side=-4, turn=6), pompous(1.2), head(x=-10, y=8, z=8))
    c.key(17, SMUG, "out_back")                                                         # to the house: smug
    c.key(25, merge(SMUG, head(x=-12, y=10, z=8)), "in_out_sine")
    PUCKER = S({"clavicle_r": [("y", 12)], "upperarm_r": [("y", -40), ("z", 70)], "lowerarm_r": [("z", 128)],
                "hand_r": [("x", -10)]}, {"upperarm_l": [("y", 72), ("z", -20)], "lowerarm_l": [("z", -40)]},
               glove("l", 20, 12), lean(fwd=6, side=-9, turn=-16), head(x=-2, y=-8))
    c.key(34, PUCKER, "in_out_cubic")                                                   # glove to the lips
    c.key(40, merge(PUCKER, lean(fwd=7, side=-10, turn=-18)), "in_out_sine")
    KISS = S({"clavicle_r": [("y", 16)], "upperarm_r": [("y", -24), ("z", -10)], "lowerarm_r": [("z", 20)],
              "hand_r": [("x", -40)]}, open_hand("r", 26), {"upperarm_l": [("y", 72), ("z", -20)], "lowerarm_l": [("z", -40)]},
             glove("l", 20, 12), lean(fwd=4, side=-6, turn=-10), head(x=-8, y=-4, z=4))
    c.key(43, KISS, "out_back")                                                         # MWAH (toward the horn)
    c.key(50, merge(KISS, pompous(1.3), head(x=-14, y=4, z=6)), "in_out_sine")
    c.key(L, SING, "in_out_cubic")
    c.ik("r", LIPS, 30, 41, pole=(-0.9, 0.2, -0.3), effector="tip", blend=(4, 1), world=False)
    c.pop_frames.extend([41, 42])     # the blown kiss is a snap of the arm
    c.motion(lambda f: breath(f, 60.0, 1.0))
    # the looks: into the horn (a baked aim at the brass), the smug face to the house
    c.look(HORN, 2, 14, weight=0.7, blend=(4, 3), bones=("neck_01", "Head"), share=(0.35, 0.65))
    c.look(("camera",), 14, 28, weight=0.9, blend=(3, 4))
    c.look(HORN, 30, 44, weight=0.5, blend=(4, 4), bones=("neck_01", "Head"), share=(0.35, 0.65))
    c.look(("camera",), 44, L, weight=0.7, blend=(4, 4))
    c.look_camera(14, 28, weight=1.0, blend=6)
    c.look_camera(46, 58, weight=1.0, blend=6)
    c.beats(lean_in=(0, 6), admire=(6, 14), to_house=(14, 26), pucker=(26, 42), kiss=(42, 50))
    c.event(6, "fx", id="sparkles")
    for f, p in ((0, "sing_small"), (6, "admiring"), (14, "smug"), (30, "kiss"), (43, "smug"), (54, "sing_small")):
        c.face(f, p)
    return c
