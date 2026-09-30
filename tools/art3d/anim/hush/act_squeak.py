"""hush/act_squeak — the squeak (state:squeaking, 18 f): she whips Clarence out of the brace (grab f 3, attached to
her glove f 4), thrusts him out at arm's length and SQUEEZES (f 8: the fist clenches, his body squashes, his comb flares),
a little recoil, and tucks him back into the brace by f 16. Table row: no events (the sim plays the squeak)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, clarence

L = 18


def build(ctx):
    c = Clip(ctx, "hush/act_squeak", length=L, cheat_deg=35, audio="table", blend_in=3, blend_out=8)
    stand = merge(ARMS_DOWN, STAND, gloves(18, 12), head())
    GRAB_R = {"clavicle_r": [("y", 4)], "upperarm_r": [("y", -64), ("z", 36)], "lowerarm_r": [("z", 96)],
              "hand_r": [("x", -20)]}
    THRUST_R = {"clavicle_r": [("y", 12), ("z", 10)], "upperarm_r": [("y", -6), ("z", 70)], "lowerarm_r": [("z", 18)],
                "hand_r": [("x", -24), ("y", -10)]}
    RECOIL = merge(THRUST_R, {"upperarm_r": [("y", 0), ("z", 60)], "lowerarm_r": [("z", 34)]})
    c.key(0, stand)
    c.key(3, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=6, turn=-10), head(x=14, z=-10)), "out_quad")   # grab
    c.key(6, merge(stand, THRUST_R, glove("r", 40, 30), lean(fwd=-6, turn=12), head(x=-8, z=16)), "out_back")    # out!
    c.key(8, merge(stand, THRUST_R, glove("r", 92, 60), lean(fwd=-2, turn=12), head(x=-4, z=18),
                   {"clavicle_r": [("y", 16), ("z", 12)]}), "pop")                                              # SQUEEZE
    c.key(11, merge(stand, RECOIL, glove("r", 50, 30), lean(fwd=-8, turn=10), head(x=-10, z=14)), "out_quad")
    c.key(14, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=4, turn=-6), head(x=10, z=-4)), "in_out_sine")  # tuck
    c.key(L, stand, "in_out_sine")
    # Clarence's own squash (his body bone) and comb flare on the squeeze
    def squash(f):
        if f < 7 or f > 13:
            return {}
        k = max(0.0, 1.0 - abs(f - 8) / 4.0) if f >= 8 else (f - 7) / 1.0
        return {"clarence_body": {"s": (1.0 + 0.45 * k, 1.0 - 0.45 * k, 1.0 + 0.45 * k)},
                "clarence_comb": {"s": (1.0 + 0.7 * k, 1.0 + 0.7 * k, 1.0 + 0.7 * k), "r": [("x", -30 * k)]}}
    c.motion(squash)
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.event(4, "prop", op="attach", prop="clarence", socket="grip_r")
    c.event(15, "prop", op="attach", prop="clarence", socket="brace_r")
    c.face(0, "determined")
    c.face(4, "grin")
    c.face(8, "laugh")
    c.face(13, "smug")
    c.mark(8, "accent")
    c.pop_frames.append(4)                                 # the whip out of the brace
    return c
