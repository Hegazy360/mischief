"""bellows/loco_turn — the haughty about-face (8 f; the map's `turn` — the player yaws him through the 6-frame turn,
the clip gives the attitude): the chin snaps up, the shoulders square, a little rise onto the balls of his feet and
down again with a sniff. Feet planted, cheat 20."""
from lib.clip import Clip
from _lib.presets import *

L = 8


def build(ctx):
    c = Clip(ctx, "bellows/loco_turn", length=L, cheat_deg=20)
    base = merge(STAND, ARMS_POMPOUS, gloves(20, 12), pompous(1.0))
    c.key(0, base)
    c.key(3, merge(base, pompous(2.0), lean(side=4), {"clavicle_l": [("y", -8)], "clavicle_r": [("y", 8)],
                   "foot_l": [("x", 14)], "foot_r": [("x", 14)], "ball_l": [("x", -14)], "ball_r": [("x", -14)]}),
          "out_quad")
    c.key(L, merge(base, pompous(1.2)), "in_out_sine")
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "pompous")
    c.face(3, "disdain")
    return c
