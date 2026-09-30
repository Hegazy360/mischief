"""bellows/mg_hum — warm-up micro-gag (activities.json warmup `hum`, emote hum; 48 f, OVERLAY `upper`, the view clock;
the audio table: vo_bellows_hum f 0): "Hums along to his own record, eyes shut, swaying like a metronome." The barrel
tick-tocks side to side (two full sways), the head riding it a beat late, eyes shut, the baton wagging in time like a
metronome's arm, a little note burst over his head. Staged at st_gramophone (facing -1, cheat 35): the face is baked to
the camera + the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 48
SING_ARMS = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 38), ("z", -44)], "lowerarm_l": [("z", -34)],
             "hand_l": [("x", -30), ("y", -10)],
             "clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 40)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", -24), ("y", 8)]}
# the metronome: the baton arm upright, the forearm wagging; the left glove resting on the top of his belly
METRO = {"clavicle_l": [("y", 2)], "upperarm_l": [("y", 76), ("z", -30)], "lowerarm_l": [("z", -52)],
         "hand_l": [("x", 10), ("y", 20)],
         "clavicle_r": [("y", 8)], "upperarm_r": [("y", -40), ("z", 36)], "lowerarm_r": [("z", 96)],
         "hand_r": [("x", -10)]}


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def build(ctx):
    st = Stage(x=8.65, z=-1.4, facing=-1, cheat=35.0)
    c = Clip(ctx, "bellows/mg_hum", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6, cheat_deg=35,
             stage=st, tags=["micro_gag", "warmup"])
    hide_fx(c)
    SING = merge(STAND, SING_ARMS, grip("r", 64, 40), open_hand("l", 12), pompous(1.3), head(x=-16, z=4))
    c.key(0, SING)
    for f, s in ((10, 1.0), (22, -1.0), (34, 1.0), (44, -0.4)):
        c.key(f, merge(STAND, METRO, grip("r", 64, 40), glove("l", 14, 8), pompous(1.1),
                       lean(side=7 * s, turn=2 * s), head(x=-12, y=9 * s, z=3)), "in_out_sine")
    c.key(L, SING, "in_out_sine")
    # the baton ticks like a metronome arm (a beat every 12 f), the head lags the barrel by a few frames
    c.motion(lambda f: {"lowerarm_r": [("y", 16 * math.sin(2 * math.pi * (f - 4) / 24.0))]}, 4, 44,
             weight=lambda f: window(f, 4, 10, 38, 44))
    c.motion(lambda f: {"Head": [("y", 4 * math.sin(2 * math.pi * (f - 7) / 24.0))]}, 6, 44,
             weight=lambda f: window(f, 6, 10, 38, 44))
    c.look(("camera",), 0, L, weight=0.6, blend=(6, 6), bones=("spine_03", "neck_01", "Head"))
    c.look_camera(4, 44, weight=1.0, blend=6)
    c.beats(sway_a=(0, 10), sway_b=(10, 22), sway_c=(22, 34), sway_d=(34, 44))
    c.event(2, "fx", id="notes")
    for f, p in ((0, "sing_small"), (6, "hum"), (40, "blissful"), (46, "sing_small")):
        c.face(f, p)
    return c
