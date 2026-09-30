"""bellows/beat_bow_topple — a T3 last beat (60 f; reactions.json clip_timings: bow 0-30, topple 30, floor 34-60; the
audio table: bow_creak 4, slide_down_short 30, slip_thud 34): making the best of it, he takes a grand courtly bow to
the Stalls — one glove on his belly, the other flourishing out — and the bow goes on, and on, deeper, the barrel
creaking over (0-30) … until he TOPPLES (30): the slippers leave the floor and he lands flat on his belly (34),
rocking on the barrel like a beached tortoise, arms and slippers paddling in the air (34-60).

The topple pitches the PELVIS (not the root) forward over the planted toes, so the root and the pelvis stay on the
spot (root.travel "sim") while the barrel and the bouffant go down in front of him; on the floor the barrel's front
(`belly_front`) rests on the boards. Faces the Stalls with a runtime gaze through the bow. Cheat 35."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 60


def hold_feet(c, f0, f1, at=None):
    """Both feet held exactly where they are at frame `at` (default f0) after the keys and vertical constraints."""
    cache = {}

    def fn(pose, f):
        if "a" not in cache:
            ap = c._anchor_pose(f0 if at is None else at)
            cache["a"] = {s: (ap.world["foot_" + s].translation.copy(), ap.world["foot_" + s].to_quaternion())
                          for s in ("l", "r")}
        for s in ("l", "r"):
            loc, q = cache["a"][s]
            P.solve_leg(pose, s, loc, foot_world=q)
    c.custom(fn, f0, f1)


# the courtly bow: the right glove on the belly, the left arm flourishing out and back
BOW_ARMS = merge({"clavicle_r": [("z", -6)], "upperarm_r": [("y", -60), ("z", 44)], "lowerarm_r": [("z", 96)],
                  "hand_r": [("x", 10)],
                  "clavicle_l": [("y", -10)], "upperarm_l": [("y", 20), ("z", 40)], "lowerarm_l": [("z", -20)],
                  "hand_l": [("x", -30), ("y", 20)]},
                 glove("r", 20, 12), open_hand("l", 14))


def bow(k, legs_up=0.0):
    """k: the bow's depth in degrees of PELVIS pitch (+ = forward); legs_up: 0..1 the legs swinging up behind."""
    # the thighs counter the pelvis pitch (the legs stay upright under him while the feet are planted), then swing
    # up behind as he goes over
    th = -k * (1.0 - legs_up) + 30.0 * legs_up
    legs = merge(STAND, {"thigh_l": [("x", th - 2), ("z", 8)], "thigh_r": [("x", th - 1), ("z", -8)],
                         "calf_l": [("x", 40 * legs_up)], "calf_r": [("x", 30 * legs_up)],
                         "foot_l": [("x", 30 * legs_up)], "foot_r": [("x", 26 * legs_up)]})
    return merge(legs, BOW_ARMS, {"pelvis": [("x", k)]}, lean(fwd=min(20.0, k * 0.3)), head(x=-min(30.0, k * 0.45)))


# on his belly: pitched right over, arms out like wings, slippers up behind, the chin up off the floor
def flat(rock=0.0, paddle=0.0):
    return merge({"pelvis": [("x", 92 + 8 * rock)]},
                 {"thigh_l": [("x", 20 + 10 * paddle), ("y", -14)], "thigh_r": [("x", 18 - 10 * paddle), ("y", 14)],
                  "calf_l": [("x", 70 - 20 * paddle)], "calf_r": [("x", 64 + 20 * paddle)],
                  "foot_l": [("x", 30)], "foot_r": [("x", 26)]},
                 {"clavicle_l": [("y", -12)], "upperarm_l": [("y", -6 + 16 * paddle), ("z", 20)], "lowerarm_l": [("z", -20)],
                  "clavicle_r": [("y", 12)], "upperarm_r": [("y", 6 + 16 * paddle), ("z", -20)], "lowerarm_r": [("z", 20)],
                  "hand_l": [("x", -20)], "hand_r": [("x", -20)]},
                 open_hand("l", 20), open_hand("r", 20), lean(fwd=-10), head(x=-40 + 6 * rock))


def build(ctx):
    c = Clip(ctx, "bellows/beat_bow_topple", length=L, cheat_deg=35, blend_in=8, blend_out=12,
             tags=["last_beat", "t3"], notes="the pelvis pitches, the root stays; ends flat on his belly (the next "
                                            "clip blends him up)")
    sk = ctx.skel
    c.key(0, bow(0.0))
    c.key(10, bow(24.0), "in_out_sine")
    c.key(20, bow(40.0), "in_out_sine")
    c.key(28, bow(56.0), "in_out_sine")
    c.key(30, bow(62.0), "in_quad")
    c.key(33, bow(86.0, legs_up=0.6), "in_cubic")                        # topples
    c.key(34, flat(rock=1.0, paddle=0.2), "pop")                           # SLAP on the boards
    c.key(38, flat(rock=-0.6, paddle=-0.6), "out_quad")
    c.key(44, flat(rock=0.4, paddle=0.8), "in_out_sine")
    c.key(50, flat(rock=-0.2, paddle=-0.8), "in_out_sine")
    c.key(55, flat(rock=0.1, paddle=0.6), "in_out_sine")
    c.key(L, flat(rock=0.0, paddle=-0.4), "in_out_sine")
    c.motion(lambda f: {"belly": {"r": [], "s": 1.0}, "Head": [("y", 3 * math.sin(2 * math.pi * f / 16.0))]}, 34, L)
    # the bow on planted feet; from the topple the barrel's front rests on the floor
    c.ground(0, 0)
    hold_feet(c, 0, 29)
    bb, bp = ctx.socket("belly_front")

    def on_floor(pose, f):
        lowest = min(sk.carried(pose.world, bb, bp).z, sk.carried(pose.world, "Head", sk.head("Head") + Vector((0, -0.30, 0.22))).z)
        k = ramp(f, 30, 34)
        if f >= 34:
            pose.add_pelvis_offset(Vector((0.0, 0.0, 0.02 - lowest)))
        else:
            # toppling: the pelvis sinks onto the barrel as the slippers leave the floor (they clear it by 2 cm)
            pose.add_pelvis_offset(Vector((0.0, 0.0, -0.12 * k)))
            low = sk.lowest_sole(pose.world)
            if low < 0.02:
                pose.add_pelvis_offset(Vector((0.0, 0.0, 0.02 - low)))
    c.custom(on_floor, 30, L)
    c.pop_frames.append(30)          # the slippers let go of the floor: the legs snap off their IK plant
    c.look_camera(0, 26, weight=0.8, blend=6)
    c.beats(bow=(0, 30), creak=(4, 30), topple=(30, 34), floor=(34, 60), anticipation=(28, 33), accent=(33, 37))
    c.event(34, "shake", trauma=0.3)
    c.event(34, "jiggle", bones=["belly", "bouffant", "bouffant_l", "bouffant_r", "tail_l", "tail_r"], kick=1.0)
    for f, p in ((0, "pompous"), (14, "smug"), (26, "strain"), (30, "shock"), (34, "dazed_open"), (44, "mortified")):
        c.face(f, p)
    return c
