"""hush/act_snicker — AFTER the arm (flavour:snicker, 60 f, interruptible): the gloves fly to her chin, the shoulders
shake with a stifled giggle, a sly look out at the audience mid-giggle (runtime gaze to the camera + the `glance`
face, both facing-proof), one last snort and she settles back to the rest pose by f 48 (40 f of action inside 60).
Cheat 35 (face to camera)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, CHIN, gloves, lean, head, breath

L = 60


def build(ctx):
    c = Clip(ctx, "hush/act_snicker", length=L, cheat_deg=35, audio="table", blend_in=4, blend_out=10)
    stand = merge(ARMS_DOWN, STAND, gloves(20, 14), head(x=-3))
    hunch = merge(STAND, CHIN, gloves(62, 40), {"clavicle_l": [("y", -18)], "clavicle_r": [("y", 18)]})
    c.key(0, stand)
    c.key(2, merge(stand, {"clavicle_l": [("y", -10)], "clavicle_r": [("y", 10)]}, lean(fwd=-4), head(x=-10)), "out_quad")
    half = sym({"clavicle_l": [("y", -6)], "upperarm_l": [("y", 54), ("z", -48)], "lowerarm_l": [("y", -54), ("z", -12)],
                "hand_l": [("x", -18), ("z", -10)]})
    c.key(5, merge(stand, half, gloves(40, 24), lean(fwd=6), head(x=4)), "in_out_sine")
    c.key(8, merge(hunch, lean(fwd=16, turn=-6), head(x=5, z=-4)), "out_sine")              # gloves to the chin
    c.key(20, merge(hunch, lean(fwd=12, side=4, turn=-4), head(x=2, y=8, z=4)))
    c.key(26, merge(hunch, lean(fwd=8, side=6, turn=4), head(x=-6, y=10, z=6)), "in_out_sine")   # the sly look
    c.key(36, merge(hunch, lean(fwd=8, side=6, turn=4), head(x=-4, y=10, z=6)))
    c.key(40, merge(hunch, lean(fwd=20, turn=-8), head(x=12, z=-4)), "out_quad")            # the snort
    c.key(48, merge(stand, lean(fwd=2), head(x=-4)), "in_out_cubic")                        # composure
    c.key(L, stand)
    # the giggle: shoulders and head shake in bursts (8 Hz), fading out by the snort
    def giggle(f):
        if f < 7 or f > 44:
            return {}
        env = min(1.0, (f - 7) / 4.0) * min(1.0, (44 - f) / 6.0)
        burst = 0.55 + 0.45 * math.sin(2 * math.pi * (f - 7) / 18.0)
        s = math.sin(2 * math.pi * f / 7.5) * env * burst
        return {"spine_03": [("x", 3.5 * s)], "clavicle_l": [("y", -5 * s)], "clavicle_r": [("y", 5 * s)],
                "Head": [("x", 4 * s), ("z", 1.5 * s)]}
    c.motion(giggle)
    c.motion(lambda f: breath(f, 90.0, 0.6))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(22, 40, weight=0.9, blend=4)
    c.face(0, "grin")
    c.face(6, "snicker")
    c.face(24, "glance")
    c.face(38, "snicker")
    c.face(46, "smug")
    c.mark(8, "accent")
    return c
