"""bellows/mg_walk_scale — walking micro-gag (activities.json walk_beats `walk_scale`, emote sing; 48 f, OVERLAY `upper`
over the strut, the view clock; no audio-table row): "Sings 'do-re-mi' a note per footfall, stepping on the beat."
Three notes on the strut's step period (0 / 16 / 32): with each one the chin climbs higher, the mouth opens wider
(sing_small → sing_mid → sing_big) and the right glove climbs a rung of an invisible ladder, palm up; a note burst per
note; on the last he holds it, the left arm flung out operatically. Facing-proof; the face is the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 48


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def rung(i):
    """The right glove on rung i (0..2), palm up."""
    return {"clavicle_r": [("y", 6 + 6 * i)], "upperarm_r": [("y", -64 + 20 * i), ("z", 44 - 4 * i)],
            "lowerarm_r": [("z", 70 - 12 * i)], "hand_r": [("x", -20 - 10 * i), ("y", -30)]}


def build(ctx):
    c = Clip(ctx, "bellows/mg_walk_scale", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=20, audio="own", tags=["micro_gag", "walk"])
    hide_fx(c)
    BASE = merge(STAND, ARMS_POMPOUS, gloves(22, 12))
    c.key(0, merge(BASE, pompous(1.2), head(x=-6)))
    for i, f in enumerate((4, 20, 36)):
        OUT = {"clavicle_l": [("y", -10)], "upperarm_l": [("y", 40), ("z", -20)], "lowerarm_l": [("z", -20)],
               "hand_l": [("x", -30)]} if i == 2 else {}
        c.key(f, merge(BASE, rung(i), open_hand("r", 12), open_hand("l", 16) if i == 2 else {}, OUT,
                       pompous(1.4 + 0.3 * i), head(x=-12 - 7 * i, y=3 * (1 - i))), "out_back")
        if i < 2:
            c.key(f + 10, merge(BASE, rung(i), open_hand("r", 10), pompous(1.3 + 0.3 * i),
                                head(x=-10 - 7 * i, y=2 * (1 - i))), "in_out_sine")
    c.key(44, merge(BASE, rung(2), open_hand("r", 12), open_hand("l", 16),
                    {"clavicle_l": [("y", -12)], "upperarm_l": [("y", 36), ("z", -22)], "lowerarm_l": [("z", -16)],
                     "hand_l": [("x", -34)]}, pompous(2.0), head(x=-28)), "in_out_sine")
    c.key(L, merge(BASE, pompous(1.2), head(x=-6)), "in_out_cubic")
    c.motion(lambda f: tremble(f, 0.9, ("Head", "spine_03"), 2.7), 36, 46, weight=lambda f: window(f, 36, 38, 44, 46))
    c.motion(lambda f: breath(f, 48.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(2, 46, weight=1.0, blend=6)
    c.beats(do=(0, 16), re=(16, 32), mi=(32, L))
    c.event(0, "voice", id="vo_bellows_scales")
    for f in (1, 17, 33):
        c.event(f, "fx", id="notes")
    for f, p in ((0, "sing_small"), (16, "sing_mid"), (32, "sing_big"), (46, "smug")):
        c.face(f, p)
    return c
