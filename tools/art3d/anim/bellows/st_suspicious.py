"""bellows/st_suspicious — the curious stop (clip_rules.json `oneshot:curious_stop`, 60 f = SimConst.CURIOUS_STOP_TICKS,
base, frame-locked): a lure or a big-rig noise makes him Curious — he stops dead ("?" starts filling) before he walks
to the spot. The stop has to say "something's not right" at 64 px:

  0-8     he halts, the barrel rocking forward over his little feet (the walk's momentum)
  8-14    a sniff: the chin pulls back and up (the wind-up)
  14-18   the lean-IN: neck out, chin forward, the eyes narrowed — and the right glove comes up to stroke his chin
  18-48   a moving hold: the eyes (and the head) shift one way... then the other... the chin-stroke finger taps
  48-60   "hmm." — up straight, the glove drops, ready to walk to the noise

Facing-proof: the head shifts are small and symmetric; the face beat is the sidecar gaze (D8)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 60
CHIN_R = ("Head", Vector((-0.10, -0.22, 1.08)))       # under the chin, his right side
STROKE = merge(curl("r", 70, thumb=30, fingers=("middle", "ring", "pinky")), curl("r", 20, thumb=0, fingers=("index",)))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def body(*parts):
    return merge(STAND, ARMS_POMPOUS, gloves(18, 10), {"upperarm_l": [("y", 78), ("z", 14)]}, *parts)


def build(ctx):
    c = Clip(ctx, "bellows/st_suspicious", length=L, lock="sim", blend_in=6, blend_out=8, cheat_deg=35, audio="own",
             tags=["oneshot", "curious"])
    hide_fx(c)
    c.key(0, body(pompous(1.0), head(x=-6)))
    c.key(4, body(lean(fwd=8), head(x=4), {"pelvis": [("x", 4)]}), "out_quad")               # the halt: rocks forward
    c.key(8, body(lean(fwd=-2), head(x=-6)), "in_out_sine")                                   # ... and back
    c.key(13, body(lean(fwd=-8), head(x=-20, y=-3), {"clavicle_l": [("y", -6)], "clavicle_r": [("y", 6)]}),
          "in_out_sine")                                                                      # the sniff
    LEAN_IN = body(lean(fwd=14), head(x=-12, y=4), STROKE, {"pelvis": [("x", 6)]})   # chin out, face level
    c.key(18, LEAN_IN, "out_back")                                                            # lean IN
    c.key(26, merge(LEAN_IN, lean(fwd=15, turn=8), head(x=-12, y=6, z=14)), "in_out_sine")    # eyes one way...
    c.key(34, merge(LEAN_IN, lean(fwd=15, turn=-6), head(x=-13, y=2, z=-12)), "in_out_sine")  # ...the other
    c.key(42, merge(LEAN_IN, lean(fwd=16, turn=2), head(x=-10, y=5, z=2)), "in_out_sine")
    c.key(48, merge(LEAN_IN, lean(fwd=12)), "in_out_sine")
    c.key(55, body(pompous(1.2), head(x=-10, y=-3)), "in_out_cubic")                          # "hmm."
    c.key(L, body(pompous(1.0), head(x=-6)), "in_out_sine")
    # the chin-stroke: the right glove to his chin over the lean-in, the index tapping
    c.ik("r", CHIN_R, 14, 52, pole=(-0.9, 0.1, -0.4), effector="palm", blend=(5, 7), world=False)
    c.motion(lambda f: {"index_01_r": [("z", 14 * max(0.0, math.sin(2 * math.pi * (f - 20) / 8.0)))]}, 20, 46,
             weight=lambda f: window(f, 20, 23, 43, 46))
    c.motion(lambda f: breath(f, 90.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(14, 52, weight=1.0, blend=7)
    c.beats(halt=(0, 8), sniff=(8, 14), lean_in=(14, 18), search=(18, 48), hmm=(48, 60))
    c.event(10, "sfx", id="sniffle", vol_db=-4.0, sync=False)
    for f, p in ((0, "pompous"), (8, "sniff"), (16, "suspicious"), (48, "huh"), (55, "irked")):
        c.face(f, p)
    return c
