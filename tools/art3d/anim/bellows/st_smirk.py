"""bellows/st_smirk — the fizzle smirk (clip_rules.json `oneshot:fizzle`, 30 f = SimConst.FIZZLE_TICKS, an OVERLAY on
the `upper` mask, frame-locked): a rigged prank's condition failed — the trap went off at the wrong moment and he is
none the wiser. He is PLEASED with himself: a smug little chuckle, the chin up, a pat on his own belly, a sly look
to the house (the event's own sting + "hmph" + the crowd's "aww" come from cues.json).

  0-5     a tiny dip of the chin (the wind-up)
  5-8     the chest puffs, the chin goes up, the left glove lands on the top of his belly (pat)
  8-22    the chuckle: the shoulders bounce three times, a second pat
  22-30   settles, still smug

Facing-proof; the face beat is the sidecar gaze (D8). The legs are a plain stance (the overlay only drives the upper
body)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 30
LEGS = merge(STAND, {"calf_r": [("x", 5)]})
PAT_L = ("spine_03", Vector((0.20, -0.44, 0.86)))     # the top-front of his barrel, left


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def up(*parts):
    return merge(LEGS, ARMS_POMPOUS, gloves(20, 12), {"upperarm_r": [("y", -74), ("z", 12)]}, *parts)


def build(ctx):
    c = Clip(ctx, "bellows/st_smirk", length=L, layer="overlay", mask="upper", lock="sim", blend_in=4, blend_out=6,
             cheat_deg=35, audio="own", tags=["oneshot", "fizzle"])
    hide_fx(c)
    c.key(0, up(pompous(1.0), head(x=-6)))
    c.key(5, up(lean(fwd=4), head(x=6, y=2)), "in_out_sine")                                  # a tiny dip
    c.key(8, up(pompous(1.6), head(x=-18, y=-6, z=6), open_hand("l", 10)), "out_back")        # chest out, chin up
    for i, f in enumerate((11, 14, 17, 20)):                                                   # the chuckle
        s = 1.0 if i % 2 == 0 else -1.0
        c.key(f, up(pompous(1.5 - 0.1 * i), head(x=-16 + 3 * s, y=-6, z=6),
                    {"clavicle_l": [("y", -5 * (1 + s) / 2)], "clavicle_r": [("y", 5 * (1 + s) / 2)]},
                    open_hand("l", 10)), "in_out_sine")
    c.key(25, up(pompous(1.3), head(x=-12, y=-4, z=4)), "in_out_sine")
    c.key(L, up(pompous(1.2), head(x=-10, y=-3, z=2)), "in_out_sine")
    # the pats on his belly (left glove)
    c.ik("l", PAT_L, 6, 24, pole=(0.9, 0.2, -0.4), effector="palm", blend=(2, 5), world=False)
    c.motion(lambda f: {"hand_l": [("x", 16 * max(0.0, math.sin(2 * math.pi * (f - 8) / 10.0)))]}, 8, 22,
             weight=lambda f: window(f, 8, 10, 20, 22))
    c.motion(lambda f: breath(f, 60.0, 0.8))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(5, L, weight=1.0, blend=5)
    c.beats(dip=(0, 5), puff=(5, 8), chuckle=(8, 22), settle=(22, L))
    for f, p in ((0, "pompous"), (6, "sly_smile"), (14, "smug"), (24, "sly_smile")):
        c.face(f, p)
    return c
