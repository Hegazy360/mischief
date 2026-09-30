"""bellows/st_bonk — the bonk (60 f; the door-slam stun one-shot and the curtain call's closer when the curtain drops
on his head; reactions.json clip_timings st_bonk: accent 0, stars 6-60): the clip opens ON the hit — his head driven
down into his collar, the knees buckling, the barrel squashed (woodblock_bonk f 0) — then he sways on the spot in a
dizzy circle under the vinyl stars (dizzy_tweets f 6), eyes spinning, gives his head a shake and comes up groggy.
Standing, feet planted. Cheat 35."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 60


def build(ctx):
    c = Clip(ctx, "bellows/st_bonk", length=L, cheat_deg=35)
    HIDE = fx_hidden("fx_stars")

    def pose(squash=0.0, sway=0.0, hx=0.0, hy=0.0, star=0.0, knees=0.0, arms=0.0):
        legs = merge(STAND, {"thigh_l": [("x", -2 - 30 * knees), ("z", 8)], "calf_l": [("x", 3 + 58 * knees)],
                             "foot_l": [("x", -1 - 28 * knees)],
                             "thigh_r": [("x", -2 - 30 * knees), ("z", -8)], "calf_r": [("x", 3 + 58 * knees)],
                             "foot_r": [("x", -1 - 28 * knees)]})
        arm = sym({"clavicle_l": [("y", 10 * squash)], "upperarm_l": [("y", 86 - 30 * arms), ("z", -10 + 20 * arms)],
                   "lowerarm_l": [("z", -20 - 30 * arms)], "hand_l": [("x", -10)]})
        return merge(HIDE, legs, arm, open_hand("l", 12 * arms), open_hand("r", 12 * arms),
                     lean(fwd=14 * squash + 3 * sway, side=6 * sway), head(x=hx + 24 * squash, y=hy),
                     {"fx_stars": {"r": [], "s": star}})
    c.key(0, pose(squash=1.0, knees=1.0, arms=1.0, hx=6), "pop")                 # BONK
    c.key(2, pose(squash=0.45, knees=0.55, arms=0.6, hx=-30), "out_quad")        # the recoil (the accent)
    c.key(6, pose(squash=0.4, knees=0.5, arms=0.4, star=1.2), "in_out_sine")
    c.key(9, pose(squash=0.3, knees=0.45, sway=1.0, hy=10, star=1.0), "in_out_sine")
    c.key(18, pose(squash=0.25, knees=0.4, sway=-1.0, hy=-10, hx=6, star=1.0), "in_out_sine")
    c.key(27, pose(squash=0.2, knees=0.35, sway=1.0, hy=12, star=1.0), "in_out_sine")
    c.key(36, pose(squash=0.15, knees=0.3, sway=-1.0, hy=-12, hx=4, star=1.0), "in_out_sine")
    c.key(44, pose(squash=0.1, knees=0.2, sway=0.4, hy=4, star=1.0), "in_out_sine")
    c.key(48, pose(squash=0.1, knees=0.15, sway=-0.2, hy=-14, star=1.0), "in_out_quad")     # a shake of the head
    c.key(51, pose(squash=0.1, knees=0.15, sway=0.2, hy=14, star=1.0), "in_out_quad")
    c.key(54, pose(squash=0.05, knees=0.1, hy=-4, star=0.8), "in_out_quad")
    c.key(L, pose(squash=0.0, knees=0.05, hx=-4, star=0.0), "in_out_sine")
    c.motion(lambda f: {"fx_stars": [("z", 14.0 * (f - 6))]}, 6, L)
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.beats(accent=(0, 3), dazed=(6, 60), shake=(48, 54))
    c.event(0, "jiggle", bones=["bouffant", "belly"], kick=0.8)
    c.event(0, "shake", trauma=0.35)
    c.face(0, "wild_take")
    c.face(6, "dazed")
    c.face(48, "dazed_open")
    c.face(56, "dazed")
    return c
