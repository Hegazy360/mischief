"""bellows/act_fixup_mirror — the mirror fix-up (loop, 240 f): at the hall mirror (st_hall_mirror stand_x 952 px =
4.76 m, z -1.4, facing +1, cheat 35) with his red COMB in his right glove the whole loop (REDESIGN §4.2 W4): he
admires himself (chin up, a turn of the head to each side), combs the bouffant back in long strokes over the top,
pats it into shape with his left glove, and winks at his reflection. Seen in the Bellows window in the Prologue
(the hall lit to 0.9 while he is in it). The mirror is a world point (staged clip)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 240
X, Z = 4.76, -1.4
MIRROR = (5.68, 1.45, -2.15)      # house3d.json hall_mirror (rect centre-x + visual_offset, the glass's centre, z)


def build(ctx):
    sk = ctx.skel
    st = Stage(x=X, z=Z, facing=1, cheat=35.0)
    c = Clip(ctx, "bellows/act_fixup_mirror", length=L, loop=True, cheat_deg=35, stage=st, audio="own", blend_in=8,
             notes="staged at st_hall_mirror")
    comb_tip = sk.head("prop_comb") + Vector((-0.19, -0.005, 0.0))
    comb_tip.freeze()

    def stand(hx=-8.0, hy=0.0, hz=14.0, fwd=-3.0, turn=6.0):
        return merge(STAND, ARMS_POMPOUS, grip("r", 70, 44), glove("l", 12, 8), lean(fwd=fwd, turn=turn),
                     head(x=hx, y=hy, z=hz))
    keys = [(0, stand()), (24, stand(hx=-14, hy=6, hz=22)), (40, stand(hx=-6, hy=-4, hz=12)),
            (60, stand(hx=2, hy=-8, hz=10)), (80, stand(hx=4, hy=-10, hz=8)), (100, stand(hx=-10, hy=4, hz=16)),
            (118, stand(hx=-14, hy=8, hz=26, turn=8)), (136, stand(hx=-12, hy=-6, hz=6, turn=2)),
            (152, stand(hx=-10, hy=2, hz=18)), (172, stand(hx=2, hy=-8, hz=10)), (192, stand(hx=4, hy=-10, hz=8)),
            (212, stand(hx=-8, hy=4, hz=16)), (L, stand())]
    for f, p in keys:
        c.key(f, p, "in_out_sine")
    c.motion(lambda f: breath(f, 120.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look(MIRROR, 0, L, weight=0.5, blend=0)
    # D8: the face beats to the audience — the smug glance (12-30) and the admire section (104-146: the kiss, smug)
    for f0, f1 in ((12, 30), (104, 146)):
        face_cam(c, f0, f1, ease=(6, 6))
        c.look_camera(f0, f1, weight=1.0, blend=6)

    def stroke(u):
        """A comb stroke over the right side of the bouffant, u 0 (forehead) .. 1 (the back of the head)."""
        return Vector((-0.30 + 0.04 * math.sin(math.pi * u), -0.22 + 0.36 * u, 1.50 + 0.16 * math.sin(math.pi * u)))
    rest_hand = Vector((-0.44, -0.18, 1.06))

    def comb(pose, f):
        # strokes on 40-100 and 152-212 (three each), riding the head
        w = window(f, 30, 42, 98, 108) + window(f, 144, 154, 210, 220)
        if w <= 0.0:
            return
        base = f - 40 if f < 120 else f - 152
        u = (base % 20) / 20.0 if 0 <= base < 60 else (0.0 if base < 0 else 1.0)
        target_rest = stroke(smooth(u))
        tgt = pose.skel.carried(pose.world, "Head", target_rest)
        # between strokes the comb lifts off and comes back to the front (a small arc away from the hair)
        lift = 0.06 * math.sin(math.pi * u) ** 6
        tgt = tgt + Vector((-lift, 0.0, lift))
        arm_ik(pose, "r", tgt, (-0.8, 0.3, -0.6), hand_R=qz(-90) @ qy(-60), effector=comb_tip, w=min(1.0, w))
    c.custom(comb, 0, L)
    # the left glove pats the bouffant at 16 and 118, then rests on the barrel
    def pat(pose, f):
        w = window(f, 8, 16, 30, 38) + window(f, 110, 118, 132, 140)
        if w <= 0.0:
            return
        tgt = pose.skel.carried(pose.world, "Head", Vector((0.30, -0.06, 1.46 + 0.02 * math.sin(f * 0.8))))
        arm_ik(pose, "l", tgt, (0.9, 0.2, -0.6), hand_R=None, effector=TeaSet(ctx).palm_rest("l"), w=min(1.0, w))
    c.custom(pat, 0, L)
    c.event(0, "prop", op="show", prop="comb")
    c.event(40, "voice", id="vo_bellows_hum", vol_db=-3.0)          # he hums while he combs
    c.event(152, "voice", id="vo_bellows_hum", vol_db=-3.0)
    c.beats(strokes=(40, 100), admire=(100, 152), strokes2=(152, 212))
    for f, p in ((0, "admiring"), (24, "smug"), (40, "pompous"), (100, "admiring"), (118, "kiss"), (136, "smug"),
                 (152, "pompous"), (212, "admiring")):
        c.face(f, p)
    fx_off(c)                     # the FX bones it never shows reset to hidden (an overlay's notes / stars)
    return c
