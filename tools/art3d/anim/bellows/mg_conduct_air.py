"""bellows/mg_conduct_air — warm-up micro-gag (activities.json warmup `conduct_air`, emote smug; 60 f, OVERLAY `upper`,
the view clock; the audio table: baton_swish f 5 / 20 / 30, bow_creak f 42): "Conducts an invisible orchestra ... then
bows to it." With the BATON (the warm-up's signature prop, REDESIGN §4.2 W4): a big DOWN-beat (5), a sweep across (20),
a flick UP (30), the left glove shushing the strings — then a deep, gracious bow of the head and barrel to the
empty room (42), and up, pleased. Staged at st_gramophone (facing -1, cheat 35): face baked to the camera + gaze (D8)."""
import math
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 60
SING_ARMS = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 38), ("z", -44)], "lowerarm_l": [("z", -34)],
             "hand_l": [("x", -30), ("y", -10)],
             "clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 40)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", -24), ("y", 8)]}


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def baton(y, z, fore, wrist, left=None):
    arm = {"clavicle_r": [("y", 12)], "upperarm_r": [("y", y), ("z", z)], "lowerarm_r": [("z", fore)],
           "hand_r": [("x", wrist)]}
    return merge(SING_ARMS, arm, left or {})


def build(ctx):
    st = Stage(x=8.65, z=-1.4, facing=-1, cheat=35.0)
    c = Clip(ctx, "bellows/mg_conduct_air", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=35, stage=st, tags=["micro_gag", "warmup"])
    hide_fx(c)
    B = lambda *p: merge(STAND, grip("r", 66, 40), *p)
    SING = B(SING_ARMS, open_hand("l", 12), pompous(1.3), head(x=-16, z=4))
    c.key(0, SING)
    c.key(3, B(baton(-40, 34, 96, -40), open_hand("l", 14), pompous(1.5), head(x=-20, z=4)), "in_out_sine")   # up...
    c.key(5, B(baton(-12, 30, 40, 10), open_hand("l", 14), lean(fwd=4), head(x=-6, z=4)), "out_quad")        # DOWN
    c.key(12, B(baton(-18, 36, 60, -10), open_hand("l", 18), pompous(1.2), head(x=-12, z=6)), "in_out_sine")
    SHUSH = {"upperarm_l": [("y", 30), ("z", -54)], "lowerarm_l": [("z", -40)], "hand_l": [("x", -50)]}
    c.key(20, B(baton(-4, 60, 30, 0, SHUSH), open_hand("l", 6), pompous(1.2), lean(turn=-8), head(x=-10, z=-6)),
          "out_quad")                                                                                         # sweep
    c.key(26, B(baton(-10, 44, 60, -20, SHUSH), open_hand("l", 6), pompous(1.3), head(x=-14, z=0)), "in_out_sine")
    c.key(30, B(baton(-46, 30, 100, -50, SHUSH), open_hand("l", 8), pompous(1.6), head(x=-22, z=4)), "out_quad")  # UP
    c.key(36, B(baton(-40, 32, 94, -40), open_hand("l", 12), pompous(1.5), head(x=-18, z=4)), "in_out_sine")
    BOW = B(baton(-70, 50, 70, 10), glove("l", 20, 12), {"upperarm_l": [("y", 66), ("z", -40)], "lowerarm_l": [("z", -60)]},
            lean(fwd=24), head(x=18, z=2))
    c.key(42, BOW, "in_out_cubic")                                                                            # the bow
    c.key(48, merge(BOW, lean(fwd=26), head(x=20, z=2)), "in_out_sine")
    c.key(55, B(SING_ARMS, open_hand("l", 12), pompous(1.5), head(x=-18, y=4, z=4)), "in_out_cubic")
    c.key(L, SING, "in_out_sine")
    c.motion(lambda f: breath(f, 60.0, 1.0))
    c.look(("camera",), 0, L, weight=0.6, blend=(6, 6))
    c.look_camera(4, 40, weight=1.0, blend=6)
    c.look_camera(50, 58, weight=1.0, blend=4)
    c.beats(downbeat=(0, 5), across=(5, 20), up=(20, 30), flourish=(30, 42), bow=(42, 55))
    for f, p in ((0, "sing_small"), (5, "smug"), (30, "sing_mid"), (40, "pompous"), (50, "smug")):
        c.face(f, p)
    return c
