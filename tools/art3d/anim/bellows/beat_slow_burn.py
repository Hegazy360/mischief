"""bellows/beat_slow_burn — the T3 last beat and the curtain call's slow burn (70 f; reactions.json clip_timings:
stare 0-70, blink 40; bassoon_burn f 0): he turns his head, very slowly, to the Stalls and STARES — one eyebrow up,
the chest swelling with each breath, a single blink on f 40, a twitch of the cheek and the sideburns at 56. The face
never leaves the audience (a runtime gaze on top of the keyed turn). Standing, feet planted, cheat 35."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 70


def build(ctx):
    c = Clip(ctx, "bellows/beat_slow_burn", length=L, cheat_deg=35)

    def stand(hz=0.0, hx=-4.0, hy=0.0, chest=0.0):
        return merge(STAND, ARMS_POMPOUS, fist("l"), fist("r"), lean(fwd=-3 - 4 * chest, turn=hz * 0.3),
                     head(x=hx, y=hy, z=hz), {"clavicle_l": [("y", -6 * chest)], "clavicle_r": [("y", 6 * chest)]})
    c.key(0, stand(hz=-6), "in_out_sine")
    c.key(22, stand(hz=16, hx=-6, chest=0.5), "in_out_sine")          # the slow turn to the audience
    c.key(38, stand(hz=20, hx=-8, hy=-3, chest=1.0), "in_out_sine")
    c.key(52, stand(hz=20, hx=-8, hy=-3, chest=0.6))
    c.key(56, stand(hz=22, hx=-10, hy=-6, chest=0.8), "out_quad")    # the twitch
    c.key(58, stand(hz=19, hx=-7, hy=-2, chest=0.8), "in_quad")
    c.key(L, stand(hz=20, hx=-8, hy=-3, chest=1.0), "in_out_sine")
    c.motion(lambda f: breath(f, 35.0, 1.6))
    c.motion(lambda f: {"sideburn_l": [("x", 10 * math.exp(-((f - 57) / 2.5) ** 2))],
                        "sideburn_r": [("x", -10 * math.exp(-((f - 57) / 2.5) ** 2))]})
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(10, L, weight=1.0, blend=8)
    c.beats(stare=(0, 70), blink=(40, 44), twitch=(56, 60))
    c.face(0, "slow_burn")
    c.face(30, "slow_burn", slots={"brows": "one_up"})
    c.face(40, slots={"eyes": "closed"}, blink=False)
    c.face(44, "slow_burn", slots={"brows": "one_up"})
    return c
