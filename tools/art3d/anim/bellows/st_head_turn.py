"""bellows/st_head_turn — "...the pipes?" (clip_rules.json `oneshot:head_turn`, 60 f = SimConst.HEAD_TURN_TICKS, an
OVERLAY on the `head` mask, frame-locked to the one-shot): he hears a squeak his activity has no bit for. The event's
own voice ("huh", cues.json) plays on f 0; the view already aims his head at the squeak's spot for 1.2 s
(WorldView3D noise gaze), so this clip gives the head its CHARACTER on top of that aim: a start, the ear cocked hard
over (the listening tilt), a suspicious squint with the chin pushed forward, a shake-off, and back.

Only neck_01 and below drive (the mask): the body is keyed to a plain asymmetric stance so the clip stays sane (and
lint-clean) if it is ever played on the base layer. Facing-proof: tilts and nods only, no baked turn; the face beat
turns to the camera through the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 60
BODY = merge(STAND, ARMS_POMPOUS, gloves(18, 10), pompous(1.0),
             {"upperarm_r": [("y", -72), ("z", 14)], "lowerarm_r": [("z", 36)], "calf_r": [("x", 5)]})
HEAD_BONES = ("neck_01", "Head")



def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c

def build(ctx):
    c = Clip(ctx, "bellows/st_head_turn", length=L, layer="overlay", mask="head", lock="sim", blend_in=4,
             blend_out=6, cheat_deg=35, audio="own", tags=["oneshot", "head_turn"])
    hide_fx(c)
    c.key(0, merge(BODY, head(x=-8, z=0)))
    c.key(3, merge(BODY, head(x=-16, y=-4, z=4)), "out_quad")                  # a start: the chin jerks up
    c.key(8, merge(BODY, head(x=-4, y=24, z=6, neck=0.45)), "out_back")        # the ear cocked hard over: listening
    c.key(20, merge(BODY, head(x=-2, y=28, z=8, neck=0.45)), "in_out_sine")
    c.key(30, merge(BODY, head(x=6, y=20, z=4, neck=0.45)), "in_out_sine")     # ...chin forward, squinting
    c.key(38, merge(BODY, head(x=10, y=14, z=2, neck=0.45)), "in_out_sine")
    c.key(44, merge(BODY, head(x=-6, y=-10, z=-2)), "in_out_quad")            # a shake-off
    c.key(48, merge(BODY, head(x=-8, y=8, z=2)), "in_out_sine")
    c.key(52, merge(BODY, head(x=-10, y=-4, z=0)), "in_out_sine")
    c.key(L, merge(BODY, head(x=-8, z=0)), "in_out_sine")
    # the listening hold never goes dead: a tiny searching bob of the head
    c.motion(lambda f: {"Head": [("x", 1.6 * math.sin(2 * math.pi * f / 14.0)), ("z", 2.0 * math.sin(2 * math.pi * f / 23.0))]},
             8, 42, weight=lambda f: window(f, 8, 12, 38, 42))
    c.motion(lambda f: breath(f, 120.0, 0.8))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(6, 46, weight=1.0, blend=7)
    c.beats(start=(0, 3), listen=(8, 30), squint=(30, 42), shake_off=(42, 52))
    for f, p in ((0, "huh"), (8, "pardon"), (30, "suspicious"), (44, "irked"), (52, "pompous")):
        c.face(f, p)
    return c
