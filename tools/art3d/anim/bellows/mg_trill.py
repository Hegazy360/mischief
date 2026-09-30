"""bellows/mg_trill — warm-up micro-gag (activities.json warmup `trill`, emote sing; 48 f, OVERLAY `upper`, the view
clock; the audio table: vo_bellows_trill f 0, teacups_rattle f 30): "A trill so high the teacups on the mantel rattle;
he taps his throat, delighted." Chin right up, chest out, the head VIBRATING on the trill, the baton quivering at the
ceiling; at the rattle (30) he stops, taps his throat twice with the left glove — "still got it" — and preens.
Staged at st_gramophone (facing -1, cheat 35): face baked to the camera + the sidecar gaze (D8)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 48
SING_ARMS = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 38), ("z", -44)], "lowerarm_l": [("z", -34)],
             "hand_l": [("x", -30), ("y", -10)],
             "clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 40)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", -24), ("y", 8)]}
HIGH = {"clavicle_l": [("y", -14)], "upperarm_l": [("y", 18), ("z", 34)], "lowerarm_l": [("z", -14)],
        "hand_l": [("x", -40), ("y", -14)],
        "clavicle_r": [("y", 16)], "upperarm_r": [("y", -2), ("z", 20)], "lowerarm_r": [("z", 40)],
        "hand_r": [("x", -30), ("y", 10)]}
THROAT_L = ("spine_03", Vector((0.17, -0.30, 0.99)))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def build(ctx):
    st = Stage(x=8.65, z=-1.4, facing=-1, cheat=35.0)
    c = Clip(ctx, "bellows/mg_trill", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6, cheat_deg=35,
             stage=st, tags=["micro_gag", "warmup"])
    hide_fx(c)
    SING = merge(STAND, SING_ARMS, grip("r", 64, 40), open_hand("l", 12), pompous(1.3), head(x=-16, z=4))
    c.key(0, SING)
    TRILL = merge(STAND, HIGH, grip("r", 66, 40), open_hand("l", 22), pompous(1.9), head(x=-26, z=6),
                  {"clavicle_l": [("y", -16)], "clavicle_r": [("y", 18)]})
    c.key(6, TRILL, "out_cubic")
    c.key(28, merge(TRILL, head(x=-28, z=6)), "in_out_sine")
    TAP = merge(STAND, SING_ARMS, grip("r", 64, 40), glove("l", 30, 20), pompous(1.5), head(x=-14, y=6, z=4))
    c.key(32, TAP, "in_out_quad")                                                             # stops: the rattle
    c.key(42, merge(TAP, head(x=-18, y=8, z=4)), "in_out_sine")
    c.key(L, SING, "in_out_sine")
    # the trill: the head and chest vibrate, the baton quivers
    c.motion(lambda f: tremble(f, 2.2, ("Head", "spine_03", "hand_r"), 3.3), 4, 30, weight=lambda f: window(f, 4, 7, 26, 30))
    # the throat taps (left glove), then it lets go
    c.ik("l", THROAT_L, 30, 44, pole=(0.9, 0.25, 0.35), effector="palm", blend=(3, 4), world=False)
    c.motion(lambda f: {"hand_l": [("x", 14 * max(0.0, math.sin(2 * math.pi * (f - 32) / 6.0)))]}, 32, 42,
             weight=lambda f: window(f, 32, 33, 40, 42))
    c.look(("camera",), 0, L, weight=0.6, blend=(6, 6))
    c.look_camera(4, 44, weight=1.0, blend=6)
    c.beats(trill=(0, 30), taps=(30, 42))
    for f, p in ((0, "trill"), (30, "admiring"), (36, "smug"), (46, "sing_small")):
        c.face(f, p)
    return c
