"""bellows/bit_livid — the squeak bit at Livid (120 f, lock "sim"; activities.json squeak_bits.bit_livid, once per
Night, any activity): Hush squeaks while he is beetroot with his specs jammed on — he goes rigid (0-6), sucks in an
enormous breath, rising and swelling, fists drawn back (6-30), stamps and bellows "WHO SQUEAKED?!" at the ceiling:
head thrown back, arms flung up and out, fists shaking (30, the accent), a trembling rage aria with a second stamp of
the fists (33-78), then glares round the room, left, right, over his specs (78-104), and harrumphs back into a
livid stance (104-120).

The voice (`vo_bellows_who_squeaked`, activities.json) is the clip's own event on the bellow frame (the AudioDirector
skips a bit voice a clip owns). Plays facing either way: the aria is at the ceiling, the glare is a runtime gaze.
Feet: both planted on IK; the right lifts straight up off its print for the stamp (22-29) and slams back on 30.
"""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 120


def hold_feet(c, f0, f1, at=None, lift=None):
    """Feet held exactly (position + rotation, no blend) where they are at frame `at` (default f0) after the keys
    and the vertical constraints; `lift` = {side: [(frame, metres), …]} raises a foot straight up off its print
    (the stamp: the knee comes up on IK and the slipper slams back on the same spot)."""
    cache = {}

    def fn(pose, f):
        if "a" not in cache:
            ap = c._anchor_pose(f0 if at is None else at)
            cache["a"] = {s: (ap.world["foot_" + s].translation.copy(), ap.world["foot_" + s].to_quaternion())
                          for s in ("l", "r")}
        for s in ("l", "r"):
            loc, q = cache["a"][s]
            h = track(f, lift[s]) if lift and s in lift else 0.0
            P.solve_leg(pose, s, loc + Vector((0.0, 0.0, h)), foot_world=q)
    c.custom(fn, f0, f1)


FISTS = merge(fist("l"), fist("r"))
# livid stance: chest out, fists at his sides, elbows bowed, chin down, glowering
STANCE = merge(STAND, lean(fwd=4), head(x=6), FISTS,
               {"clavicle_l": [("z", -4)], "upperarm_l": [("y", 78), ("z", 12)], "lowerarm_l": [("z", -40)],
                "clavicle_r": [("z", -4)], "upperarm_r": [("y", -76), ("z", -10)], "lowerarm_r": [("z", 42)],
                "hand_l": [("x", -8)], "hand_r": [("x", -8)]})
RIGID = merge(STANCE, lean(fwd=-4), head(x=-6, z=4),
              {"clavicle_l": [("y", -8)], "clavicle_r": [("y", 8)], "_pelvis": (0.0, 0.0, -0.01)})
# the enormous breath: arching back, shoulders up, fists pulled back behind the barrel, the belly swelling
INHALE = merge(STAND, FISTS, lean(fwd=-18), head(x=-14),
               {"clavicle_l": [("y", -18)], "upperarm_l": [("y", 86), ("z", 44)], "lowerarm_l": [("z", -70)],
                "clavicle_r": [("y", 16)], "upperarm_r": [("y", -84), ("z", -42)], "lowerarm_r": [("z", 72)],
                "hand_l": [("x", 20)], "hand_r": [("x", 20)]})
# the stamp: the right slipper lifted straight up off its print on IK (a flamingo of fury), slammed down on 30
STAMP_R = [(21, 0.0), (23, 0.03), (26, 0.12), (28, 0.13), (29, 0.07), (30, 0.0)]
# WHO SQUEAKED?!: bellowed at the ceiling, arms flung up and out, fists, the knees punched down
BELLOW = merge(STAND, FISTS, lean(fwd=-22, side=2), head(x=-34, y=-4, neck=0.45),
               {"clavicle_l": [("y", -24)], "upperarm_l": [("y", -40), ("z", 10)], "lowerarm_l": [("z", -20)],
                "clavicle_r": [("y", 22)], "upperarm_r": [("y", 36), ("z", -8)], "lowerarm_r": [("z", 26)],
                "hand_l": [("x", -20)], "hand_r": [("x", -24)], "_pelvis": (0.0, 0.0, 0.0)})
BELLOW_B = merge(BELLOW, lean(fwd=-18, side=-3), head(x=-30, y=6, neck=0.45),
                 {"upperarm_l": [("y", -24), ("z", -14)], "upperarm_r": [("y", 36), ("z", 6)], "_pelvis": (0.0, 0.0, -0.035)})
# the fists hammered down (the second stamp, 56)
POUND = merge(STAND, FISTS, lean(fwd=10), head(x=-8),
              {"clavicle_l": [("y", 8)], "upperarm_l": [("y", 60), ("z", -40)], "lowerarm_l": [("z", -60)],
               "clavicle_r": [("y", -8)], "upperarm_r": [("y", -58), ("z", 40)], "lowerarm_r": [("z", 62)],
               "hand_l": [("x", 30)], "hand_r": [("x", 30)], "_pelvis": (0.0, 0.0, -0.06)})
# glaring round: over the specs, the body turning with the head
GLARE_L = merge(STANCE, lean(fwd=8, turn=16), head(x=10, z=34))
GLARE_R = merge(STANCE, lean(fwd=8, turn=-16), head(x=10, z=-32))
HARRUMPH = merge(STANCE, lean(fwd=-8), head(x=-12, z=-4), {"clavicle_l": [("y", -6)], "clavicle_r": [("y", 6)]})


def build(ctx):
    c = Clip(ctx, "bellows/bit_livid", length=L, lock="sim", cheat_deg=35, blend_in=6, blend_out=10,
             tags=["bit", "squeak", "livid"], audio="own",
             notes="any activity while Livid; plays facing either way")
    c.key(0, STANCE)
    c.key(4, RIGID, "out_back")
    c.key(12, merge(INHALE, {"_pelvis": (0.0, 0.0, -0.02)}), "in_out_sine")
    c.key(22, merge(INHALE, lean(fwd=-22), head(x=-18), {"_pelvis": (0.0, 0.0, -0.005)}), "in_out_sine")
    c.key(28, merge(INHALE, lean(fwd=22), head(x=20), {"_pelvis": (0.0, 0.0, -0.09)}), "out_quad")
    c.key(30, BELLOW, "pop")
    c.key(33, merge(BELLOW, head(x=-38, y=-6, neck=0.45), {"_pelvis": (0.0, 0.0, 0.0)}), "out_quad")
    c.key(44, BELLOW_B, "in_out_sine")
    c.key(52, merge(BELLOW, {"upperarm_l": [("y", -44)], "upperarm_r": [("y", 40)]}), "in_out_sine")
    c.key(57, POUND, "in_out_sine")
    c.key(62, merge(POUND, lean(fwd=6), head(x=-14)), "in_out_sine")
    c.key(72, merge(BELLOW_B, {"_pelvis": (0.0, 0.0, -0.03)}), "in_out_sine")
    c.key(78, merge(STANCE, head(x=0)), "in_out_cubic")
    c.key(86, GLARE_L, "in_out_cubic")
    c.key(92, merge(GLARE_L, head(x=12, z=38)), "in_out_sine")
    c.key(98, GLARE_R, "in_out_cubic")
    c.key(104, merge(GLARE_R, head(x=12, z=-36)), "in_out_sine")
    c.key(110, HARRUMPH, "in_out_cubic")
    c.key(L, STANCE, "in_out_sine")
    # the rage tremble (fists and head), the vibrato belly on the aria
    c.motion(lambda f: tremble(f, 2.2, ("spine_03", "Head", "neck_01"), rate=3.1), 30, 76, weight=lambda f: window(f, 30, 33, 70, 76))
    c.motion(lambda f: {"lowerarm_l": [("z", -6 * math.sin(f * 2.2))], "lowerarm_r": [("z", 6 * math.sin(f * 2.0 + 1.3))],
                        "belly": {"r": [], "s": 1.0}}, 30, 76, weight=lambda f: window(f, 30, 33, 70, 76))
    c.motion(lambda f: breath(f, 40.0, 1.2), 0, L, weight=lambda f: 1.0 - window(f, 26, 30, 76, 82))
    # feet: grounded at 0, planted; the right lifts for the stamp and slams back on its own print at 30
    c.ground(0, 0)
    hold_feet(c, 0, L, at=0, lift={"r": STAMP_R})
    c.look_camera(80, 108, weight=0.5, blend=6)
    # the accent beat opens on the last inhale frame (29) so the pop (30) and the punch after it sit inside it
    c.beats(anticipation=(6, 29), accent=(29, 33), hold=(33, 78), settle=(78, 120),
            rigid=(0, 6), inhale=(6, 29), bellow=(30, 57), pound=(57, 62), glare=(78, 104), harrumph=(104, 120))
    c.mark(30, "accent")
    c.event(30, "voice", id="vo_bellows_who_squeaked")
    c.sfx(30, "stomp")
    c.event(30, "shake", trauma=0.3)
    c.event(30, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r", "sideburn_l", "sideburn_r", "belly"], kick=0.9)
    c.sfx(57, "meltdown_stomp")
    c.event(57, "jiggle", bones=["belly", "cravat"], kick=0.5)
    for f, p in ((0, "furious"), (4, "irked"), (8, "inhale"), (30, "livid"), (57, "furious"), (62, "livid"),
                 (78, "suspicious"), (86, "furious"), (98, "suspicious"), (104, "furious"), (110, "irked")):
        c.face(f, p)
    return c
