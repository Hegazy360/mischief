"""hush/st_yanked — yanked back by Figgis' hook (clip_rules.json `oneshot:yanked`, 36 f, fx "cane"; the can't-fail
safety net): the crook catches her collar — a startled freeze (f 0–4), then she is JERKED backwards off her feet (the
pop at f 5: head and chest snap back, arms and legs flung forward, the beret flying up), hangs trailing through the
pull (the view carries her along the travel), lands on her heels with a stumble and a dazed wobble. In place in x/z
(root travel "sim": the view moves her)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, PAWS, gloves, glove, lean, head

L = 36
START = merge(PAWS, gloves(34, 12), lean(fwd=10), head(x=-8),
              {"thigh_l": [("x", -20)], "calf_l": [("x", 30)], "thigh_r": [("x", 6)], "calf_r": [("x", 16)]})
STARTLE = merge(sym({"clavicle_l": [("y", -12)], "upperarm_l": [("y", 40), ("z", -40)], "lowerarm_l": [("z", -60)]}),
                glove("l", 0, 0, spread=22), glove("r", 0, 0, spread=22), lean(fwd=4), head(x=-14),
                {"thigh_l": [("x", -12)], "calf_l": [("x", 20)], "thigh_r": [("x", 2)], "calf_r": [("x", 14)]})
# jerked off her feet: the chest and head snapped back, limbs flung forward (the whiplash)
YANK = merge(sym({"clavicle_l": [("y", -10)], "upperarm_l": [("y", 0), ("z", -70)], "lowerarm_l": [("z", -20)],
                  "hand_l": [("x", 20)]}),
             {"upperarm_r": [("y", 14), ("z", 64)]}, glove("l", 0, 0, spread=24), glove("r", 2, 0, spread=20),
             lean(fwd=-30, side=4), head(x=-22, y=6),
             {"thigh_l": [("x", -58)], "calf_l": [("x", 30)], "foot_l": [("x", 30)],
              "thigh_r": [("x", -44)], "calf_r": [("x", 50)], "foot_r": [("x", 30)], "pelvis": [("x", -10)]})
TRAIL = merge(YANK, lean(fwd=-24, side=2), head(x=-16, y=4),
              {"thigh_l": [("x", -50)], "calf_l": [("x", 40)], "thigh_r": [("x", -36)], "calf_r": [("x", 60)],
               "upperarm_l": [("y", 10), ("z", -64)], "upperarm_r": [("y", 4), ("z", 70)]})
LAND = merge(sym({"upperarm_l": [("y", 30), ("z", -20)], "lowerarm_l": [("z", -30)]}), gloves(10, 6, spread=12),
             lean(fwd=-8), head(x=-4, y=-6),
             {"thigh_l": [("x", -34)], "calf_l": [("x", 40)], "foot_l": [("x", -20)],
              "thigh_r": [("x", -18)], "calf_r": [("x", 44)], "foot_r": [("x", -10)]})
WOBBLE = merge(ARMS_DOWN, STAND, gloves(16, 10), lean(fwd=2, side=-6), head(x=4, y=-12, z=6))
AIR = (5, 27)                    # feet off the floor


def build(ctx):
    c = Clip(ctx, "hush/st_yanked", length=L, cheat_deg=20, blend_in=2, blend_out=8, audio="own")
    c.key(0, START)
    c.key(4, STARTLE, "out_quad")                               # caught! (anticipation: she tips forward)
    c.key(6, YANK, "pop")                                        # JERKED back
    c.key(12, merge(YANK, lean(fwd=-32, side=5), head(x=-24, y=8)), "out_quad")
    c.key(22, TRAIL, "in_out_sine")                              # trailing through the pull
    c.key(27, LAND, "in_quad")                                   # heels down
    c.key(31, merge(WOBBLE, lean(fwd=-2, side=6), head(x=2, y=10, z=-4)), "out_back")
    c.key(L, WOBBLE, "in_out_sine")
    lift = lambda f: 0.09 * math.sin(math.pi * (f - AIR[0]) / float(AIR[1] - AIR[0])) if AIR[0] < f < AIR[1] else 0.0
    c.ground(lift=lift)
    for sd in ("l", "r"):
        c.plant(sd, 0, 4)
        c.plant(sd, AIR[1], L)
    c.beats(anticipation=(0, 4), accent=(4, 7), hold=(7, 27), settle=(27, L))
    c.pop_frames.extend([5, 6, 7, AIR[1]])
    c.event(4, "fx", id="cane")
    c.sfx(4, "whoosh")
    c.sfx(AIR[1], "land_soft")
    c.mark(AIR[1], "contact")
    c.event(6, "jiggle", bones=["beret", "beret_stalk"], kick=1.0)
    c.face(0, "sneak")
    c.face(4, "shock")
    c.face(27, "dazed")
    return c
