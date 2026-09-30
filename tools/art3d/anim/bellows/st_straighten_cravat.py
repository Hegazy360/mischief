"""bellows/st_straighten_cravat — the doorway pause (clip_rules.json `oneshot:doorway_pause`, base, a LOOP: the sim
inserts 90 − eta ticks at a portal so Hush always gets the 1.5 s entry warning; the event's own "ahem" is cues.json's).
He stops in the doorway and makes himself presentable before he sweeps in: both gloves straighten the cravat, a sharp
tug (cravat_tug), the lapels smoothed, chin up — a pompous entrance being prepared. 60 f per cycle.

  0-10    both gloves come up to the cravat
  10-16   the TUG (both hands pull down, the chin lifts: cravat_tug on 14)
  16-32   smooths the lapels outward, down the barrel
  32-48   chin up, a haughty sniff, weight shift
  48-60   the gloves drift back up (= frame 0)

Facing-proof; the preening face carries the sidecar gaze (D8)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 60
CRAVAT_L = ("spine_03", Vector((0.06, -0.38, 0.99)))
CRAVAT_R = ("spine_03", Vector((-0.07, -0.38, 0.97)))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def base(w=0.0, *parts):
    return merge(STAND, ARMS_POMPOUS, {"pelvis": [("y", 3 * w)], "_pelvis": (0.015 * w, 0.0, 0.0)},
                 lean(side=-2 * w), *parts)


def build(ctx):
    c = Clip(ctx, "bellows/st_straighten_cravat", length=L, loop=True, lock="sim", blend_in=8, blend_out=8,
             cheat_deg=35, audio="own", tags=["oneshot", "doorway_pause"])
    hide_fx(c)
    A = base(0.4, grip("l", 50, 30), grip("r", 54, 32), pompous(0.9), head(x=2))
    c.key(0, A)
    c.key(10, base(0.2, grip("l", 60, 36), grip("r", 62, 36), pompous(0.8), head(x=6, y=2)), "in_out_sine")
    c.key(14, base(0.0, grip("l", 70, 40), grip("r", 70, 40), pompous(1.4), head(x=-16, y=-2)), "out_back")   # TUG
    c.key(18, base(0.0, grip("l", 66, 38), grip("r", 66, 38), pompous(1.3), head(x=-12)), "in_out_sine")
    c.key(30, base(-0.4, open_hand("l", 6), open_hand("r", 6), pompous(1.3), head(x=-10, y=-3, z=-4)), "in_out_sine")
    c.key(40, base(-0.6, gloves(18, 10), pompous(1.6), head(x=-18, y=-4, z=-6)), "in_out_cubic")   # chin up: sniff
    c.key(48, base(-0.2, gloves(22, 12), pompous(1.3), head(x=-12, y=2, z=4)), "in_out_sine")
    c.key(L, A, "in_out_sine")
    # the gloves: the cravat (0-18), sliding outward down the lapels (18-32), back to the sides, up again (48-60)
    def lap(side, f):
        s = 1.0 if side == "l" else -1.0
        k = ramp(f, 18, 32)
        return Vector((s * (0.07 + 0.22 * k), -0.38 - 0.03 * k, 0.99 - 0.22 * k))

    def hands(pose, f):
        for side, tgt0, pole in (("l", CRAVAT_L, POLE_L), ("r", CRAVAT_R, POLE_R)):
            if f <= 18 or f >= 50:
                p_rest = tgt0[1]
            else:
                p_rest = lap(side, f)
            w = window(f, -1, 0, 32, 40) if f < 45 else ramp(f, 48, 58)
            arm_ik(pose, side, chest_point(pose, p_rest), pole, w=w)
    c.custom(hands, 0, L)
    c.motion(lambda f: breath(f, 60.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(10, 50, weight=1.0, blend=8)
    c.beats(reach=(0, 10), tug=(10, 14), tugged=(14, 18), lapels=(18, 32), sniff=(32, 48))
    c.event(14, "sfx", id="cravat_tug", vol_db=-3.0)
    c.event(14, "jiggle", bones=["cravat"], kick=0.6)
    for f, p in ((0, "pompous"), (12, "strained_grin"), (18, "smug"), (34, "sniff"), (44, "disdain"), (52, "pompous")):
        c.face(f, p)
    return c
