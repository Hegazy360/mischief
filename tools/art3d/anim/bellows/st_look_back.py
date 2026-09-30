"""bellows/st_look_back — the look back (clip_rules.json `oneshot:look_back`, 60 f = SimConst.LOOK_BACK_TICKS, base,
frame-locked): Steaming or angrier, he stops at a doorway and looks back over his shoulder — is someone following
him? A paranoid DOUBLE check: over one shoulder, then snapping over the other, then a huffy face-front.

  0-6     the stop: a small rock back on his heels
  6-12    anticipation: a shifty glance the other way
  12-26   over his LEFT shoulder: the torso twists, the head goes round (eyes narrowed)
  26-30   SNAP over his RIGHT shoulder (quicker)
  30-44   a moving hold, squinting back into the room
  44-60   "hmph": face front, chin up, fists — back to walking

Facing-proof: one of the two looks back always turns his face past the camera (the left one when he faces -1, the
right one when he faces +1); the face beats also carry the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 60


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def body(*parts):
    return merge(STAND, ARMS_POMPOUS, fist("l"), fist("r"), {"upperarm_r": [("y", -76), ("z", -10)]}, *parts)


def build(ctx):
    c = Clip(ctx, "bellows/st_look_back", length=L, lock="sim", blend_in=6, blend_out=8, cheat_deg=35, audio="own",
             tags=["oneshot", "look_back"])
    hide_fx(c)
    c.key(0, body(pompous(1.0), head(x=-8)))
    c.key(5, body(lean(fwd=-6), head(x=-12), {"pelvis": [("x", -4)]}), "out_quad")                 # rocks back
    c.key(11, body(lean(fwd=-2, turn=-8), head(x=-6, z=-16)), "in_out_sine")                         # a shifty flick
    LEFT = body(lean(fwd=2, side=-4, turn=40), head(x=6, y=-6, z=62, neck=0.45), {"pelvis": [("z", 12)]})
    c.key(20, LEFT, "in_out_cubic")                                                                  # over his left
    c.key(30, merge(LEFT, head(x=8, y=-8, z=66, neck=0.45)), "in_out_sine")
    RIGHT = body(lean(fwd=2, side=4, turn=-42), head(x=6, y=6, z=-64, neck=0.45), {"pelvis": [("z", -12)]})
    c.key(35, RIGHT, "out_back")                                                                     # SNAP: over his right
    c.key(42, merge(RIGHT, head(x=10, y=8, z=-60, neck=0.45)), "in_out_sine")
    c.key(52, body(pompous(1.3), head(x=-16, y=-2)), "in_out_cubic")                                 # hmph
    c.key(L, body(pompous(1.0), head(x=-8)), "in_out_sine")
    c.pop_frames.extend([31, 32, 33, 34])     # the snap over the other shoulder IS the accent: a whip of the head
    c.motion(lambda f: breath(f, 60.0, 1.2))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(44, 60, weight=1.0, blend=6)
    c.beats(stop=(0, 6), shifty=(6, 12), over_left=(12, 30), over_right=(30, 44), hmph=(44, 60))
    for f, p in ((0, "irked"), (11, "suspicious"), (20, "look_back"), (35, "suspicious"), (46, "disdain")):
        c.face(f, p)
    return c
