"""bellows/mg_walk_hum — walking micro-gag (activities.json walk_beats `walk_hum`, emote hum; 48 f, OVERLAY `upper`
over the strut, the view clock; no audio-table row): "Hums a march in time with his strut, chin up, arms swinging." The
chin right up, eyes shut, humming (vo_bellows_hum, a note burst); the right glove's index finger conducts the march —
a crisp beat every 16 f (the strut's step period); the left arm swings stiffly like a guardsman's. Facing-proof; the
face beat is the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 48
POINT = merge(curl("r", 72, thumb=40, fingers=("middle", "ring", "pinky")), curl("r", 4, thumb=0, fingers=("index",)))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def build(ctx):
    c = Clip(ctx, "bellows/mg_walk_hum", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=20, audio="own", tags=["micro_gag", "walk"])
    hide_fx(c)
    ARMS = merge(ARMS_POMPOUS, glove("l", 22, 12), POINT,
                 {"clavicle_r": [("y", 8)], "upperarm_r": [("y", -46), ("z", 36)], "lowerarm_r": [("z", 92)]})
    beat = lambda k: {"lowerarm_r": [("z", 92 - 18 * k)], "hand_r": [("x", 20 * k)]}
    swing = lambda k: {"upperarm_l": [("y", 80), ("z", -22 * k)], "lowerarm_l": [("z", -30)]}
    c.key(0, merge(STAND, ARMS_POMPOUS, gloves(22, 12), pompous(1.2), head(x=-4)))
    for i, f in enumerate((8, 16, 24, 32, 40)):
        k = 1.0 if i % 2 == 0 else -1.0
        c.key(f, merge(STAND, ARMS, beat(1.0 if i % 2 == 0 else 0.0), swing(k), pompous(1.8), head(x=-22, y=4 * k)),
              "out_quad" if i % 2 == 0 else "in_out_sine")
    c.key(L, merge(STAND, ARMS_POMPOUS, gloves(22, 12), pompous(1.2), head(x=-4)), "in_out_cubic")
    c.motion(lambda f: breath(f, 48.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(4, 44, weight=1.0, blend=6)
    c.beats(start=(0, 8), beat_1=(8, 16), beat_2=(16, 24), beat_3=(24, 32), beat_4=(32, 40))
    c.event(0, "voice", id="vo_bellows_hum")
    c.event(2, "fx", id="notes")
    c.event(24, "fx", id="notes")
    for f, p in ((0, "hum"), (40, "blissful")):
        c.face(f, p)
    return c
