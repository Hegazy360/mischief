"""bellows/mg_peer_under_piano — the hunt's micro-gag (60 f ± 12; activities.json hunt micro_gags peer_under_piano,
at 2.5 s): specs on, he bends double to peer under the piano as he passes — the barrel tipped right over, one glove
braced on his knee, the other shading his specs, his nose an inch off the floor, the magnified eyes swivelling
(0-38) — "Hmm." — and heaves himself upright again: nothing (38-60).

An OVERLAY (mask `upper`) over the walk / act_hunt: it starts and ends near their carriage (blend 6 in / 8 out). The
peer turns a little to his right (the piano is up-stage on the Prologue's leftward hunt, facing -1)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 60

UPRIGHT = merge({"clavicle_l": [("z", -6)], "upperarm_l": [("y", 70), ("z", -30)], "lowerarm_l": [("z", -54)],
                 "hand_l": [("x", 14)],
                 "clavicle_r": [("z", 6)], "upperarm_r": [("y", -68), ("z", 32)], "lowerarm_r": [("z", 58)],
                 "hand_r": [("x", 14)]},
                curl("l", 40, thumb=26), curl("r", 36, thumb=24), lean(fwd=12), head(x=10))
# bent double: spine_02 and up tipped right over (the overlay's bones), the head turned sideways to look under
PEER = merge({"clavicle_l": [("y", 6)], "upperarm_l": [("y", 56), ("z", -64)], "lowerarm_l": [("z", -20)],
              "hand_l": [("x", 30), ("y", 10)],                                # the left glove down on his knee
              "clavicle_r": [("y", -10)], "upperarm_r": [("y", -18), ("z", 70)], "lowerarm_r": [("z", 122)],
              "hand_r": [("x", -30), ("z", 20)]},                              # the right shading his specs
             glove("l", 30, 16), open_hand("r", 6), lean(fwd=58, side=-4, turn=-14),
             {"spine_02": [("x", 30), ("y", -2), ("z", -6)], "spine_03": [("x", 22), ("z", -6)]},
             head(x=-26, y=-22, z=-16))
# the hands on the small of his back as he heaves up (hmph)
HEAVE = merge({"clavicle_l": [("y", -8)], "upperarm_l": [("y", 64), ("z", 50)], "lowerarm_l": [("z", -86)],
               "hand_l": [("x", 20)],
               "clavicle_r": [("y", 8)], "upperarm_r": [("y", -64), ("z", -50)], "lowerarm_r": [("z", 86)],
               "hand_r": [("x", 20)]},
              glove("l", 24, 12), glove("r", 22, 12), lean(fwd=-10), head(x=-10, z=4))


def build(ctx):
    c = Clip(ctx, "bellows/mg_peer_under_piano", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=8,
             cheat_deg=35, audio="own", tags=["micro_gag", "hunt", "overlay"])
    c.key(0, UPRIGHT)
    c.key(12, PEER, "in_out_cubic")
    c.key(22, merge(PEER, head(x=-28, y=-24, z=-6)), "in_out_sine")          # the magnified eyes swivel
    c.key(32, merge(PEER, head(x=-24, y=-20, z=-24)), "in_out_sine")
    c.key(38, merge(PEER, head(x=-20, y=-18, z=-14)), "in_out_sine")
    c.key(48, HEAVE, "in_out_cubic")
    c.key(L, UPRIGHT, "in_out_sine")
    c.motion(lambda f: {"nose": [("x", 10 * math.sin(2 * math.pi * f / 7.0))],
                        "spine_03": [("y", 1.5 * math.sin(2 * math.pi * f / 11.0))]}, 10, 40,
             weight=lambda f: window(f, 10, 14, 36, 40))
    c.beats(peer=(0, 38), hmm=(38, 48), heave=(48, 60))
    c.event(38, "voice", id="vo_bellows_hmm")
    for f, p in ((0, "suspicious"), (12, "magnified"), (38, "suspicious"), (48, "irked")):
        c.face(f, p)
    return c
