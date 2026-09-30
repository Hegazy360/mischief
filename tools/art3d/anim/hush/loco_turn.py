"""hush/loco_turn — the 6-frame squash turn (turn): the player yaws her (and swaps the mirrored face cells at the
midpoint); the clip squashes down into it and stretches up out of it — knees dip, gloves tuck in, a little hop of the
shoulders, back to the sneak's carriage by f 6."""
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import PAWS, STAND, TIPTOE, gloves, lean, head

L = 6


def build(ctx):
    c = Clip(ctx, "hush/loco_turn", length=L, cheat_deg=20, audio="own", blend_in=2, blend_out=4)
    base = merge(PAWS, STAND, TIPTOE, gloves(34, 12), lean(fwd=12), head(x=-12))
    SQUASH = {"thigh_l": [("x", -34), ("z", 4)], "calf_l": [("x", 58)], "thigh_r": [("x", -32), ("z", -4)],
              "calf_r": [("x", 56)]}
    TUCK = sym({"clavicle_l": [("y", -4)], "upperarm_l": [("y", 44), ("z", -70)], "lowerarm_l": [("z", -110), ("y", -30)]})
    c.key(0, base)
    c.key(2, merge(base, SQUASH, TUCK, lean(fwd=18), head(x=-4)), "out_quad")               # squash
    c.key(4, merge(base, {"calf_l": [("x", 2)], "calf_r": [("x", 2)]}, lean(fwd=4), head(x=-16)), "out_quad")   # stretch
    c.key(L, base, "in_out_sine")
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "sneak")
    return c
