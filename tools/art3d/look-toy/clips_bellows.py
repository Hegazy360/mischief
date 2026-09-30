"""Bellows' custom Toy Box clips. Same angle conventions as clips_hush (armature axes, parent at rest):
x+ = bend forward / thigh back / knee flex; y+ = lean or tilt to his LEFT, left arm DOWN; z+ = turn to his
LEFT, left arm BACK. Right side mirrored. '_pelvis' / '_root' = armature-space offsets (m); +Y = backward."""
from toy_pose import sym, swap, merge, curl, mirror, lerp_pose
import math

HIDE = {"prop_r": {"s": 0.0}, "prop_l": {"s": 0.0}, "specs_face": {"s": 0.0}, "fx_choo": {"s": 0.0}}
TEA = {"prop_r": {"s": 1.0}, "prop_l": {"s": 1.0}, "specs_face": {"s": 0.0}, "fx_choo": {"s": 0.0}}
ARMS = sym({"upperarm_l": [("y", 56), ("z", -12)], "lowerarm_l": [("z", -30)], "hand_l": [("x", -10)]})
HANDS = merge(curl("l", 24, thumb=10), curl("r", 24, thumb=10))
# the tea grip: cup in the right hand (fingers round the handle, PINKIE UP), saucer flat in the left
PINKIE_UP = merge(curl("r", 70, thumb=40, fingers=("index", "middle", "ring")), {f"pinky_{i:02d}_r": [("y", 30), ("z", -10)] for i in (1, 2, 3)})
SAUCER = curl("l", -8, thumb=0)


def pose(*parts, **kw):
    p = merge(HIDE, ARMS, HANDS, *parts)
    for k, v in kw.items():
        p["_" + k] = v
    return p


# sitting on the kitchen stool (seat 0.66 m): barrel on the seat, tiny legs dangling
SIT_Z = 0.44
SIT = {"thigh_l": [("x", -84), ("z", 8)], "calf_l": [("x", 70)], "foot_l": [("x", 10)],
       "thigh_r": [("x", -80), ("z", -8)], "calf_r": [("x", 62)], "foot_r": [("x", 16)]}


def sip_arms(lift):
    """lift 0 = cup down by the belly, 1 = cup at the lips."""
    up = {"clavicle_r": [("y", 10 * lift)],
          "upperarm_r": [("y", -30 + 30 * lift), ("z", 72 - 6 * lift)],
          "lowerarm_r": [("y", 30 + 70 * lift), ("z", 30 - 10 * lift)],
          "hand_r": [("x", -20 * lift), ("y", -20 + 10 * lift)]}
    sau = {"upperarm_l": [("y", 34), ("z", -64)], "lowerarm_l": [("z", -40), ("y", -10)], "hand_l": [("y", -6), ("x", 0)]}
    return merge(up, sau, PINKIE_UP, SAUCER)


def build(anim, rig):
    # ---- Toy_Idle_Loop: pompous breathing, chin up, the bouffant and sideburns breathe too (2 s) --------
    def idle(t):
        s = math.sin(2 * math.pi * t)
        b = 0.5 - 0.5 * math.cos(2 * math.pi * t)
        return pose({"spine_01": [("x", -3 - 2 * b)], "spine_02": {"r": [("x", -2 * b)], "s": 1.0 + 0.03 * b},
                     "neck_01": [("x", -4)], "Head": [("x", -8 - 3 * b), ("y", 3 * s)],
                     "bouffant": {"r": [("y", -3 * s)], "s": 1.0 + 0.02 * b},
                     "sideburn_l": {"s": 1.0 + 0.04 * b}, "sideburn_r": {"s": 1.0 + 0.04 * b},
                     "upperarm_l": [("y", 54 - 4 * b), ("z", -12)], "upperarm_r": [("y", -54 + 4 * b), ("z", 12)]},
                    pelvis=(0, 0, 0.006 * b))
    anim.clip("Toy_Idle_Loop", [(1 + int(60 * i / 6), idle(i / 6)) for i in range(7)], faces=[(1, "pompous")], loop=True)

    # ---- Toy_Walk_Loop: the pompous strut-waddle: chest out, chin up, tiny quick steps, rocking barrel ---
    def walk(ph):
        c = math.cos(2 * math.pi * ph)
        s = math.sin(2 * math.pi * ph)
        lift_l = max(0.0, s)
        lift_r = max(0.0, -s)
        return pose({"pelvis": [("y", 7 * c), ("z", 6 * c)], "spine_01": [("x", -6), ("y", -4 * c)], "spine_02": [("x", -4)],
                     "spine_03": [("z", -6 * c)], "neck_01": [("x", -6)], "Head": [("x", -10), ("y", 5 * c), ("z", 4 * c)],
                     "bouffant": {"r": [("y", -4 * c), ("x", 3 * abs(s))], "s": 1.0 - 0.03 * abs(c)},
                     "sideburn_l": {"s": 1.0 + 0.05 * abs(s)}, "sideburn_r": {"s": 1.0 + 0.05 * abs(s)},
                     "upperarm_l": [("y", 50), ("z", -30 * c)], "lowerarm_l": [("z", -40)],
                     "upperarm_r": [("y", -50), ("z", -30 * c)], "lowerarm_r": [("z", 40)],
                     "thigh_l": [("x", -38 * c - 25 * lift_l)], "calf_l": [("x", 10 + 55 * lift_l)], "foot_l": [("x", -15 * c)],
                     "thigh_r": [("x", 38 * c - 25 * lift_r)], "calf_r": [("x", 10 + 55 * lift_r)], "foot_r": [("x", 15 * c)]},
                    pelvis=(0, 0, 0.018 * abs(s)))
    anim.clip("Toy_Walk_Loop", [(1 + int(24 * i / 8), walk(i / 8)) for i in range(9)], faces=[(1, "pompous")], loop=True)

    # ---- Toy_Tea_Sit_Loop: on the stool, sip (pinkie up), lower, savour ------------------------------------
    def sit(lift, head_back=0.0, b=0.0):
        return merge(pose(SIT, sip_arms(lift), TEA,
                          {"spine_01": [("x", -6 - 3 * b)], "spine_02": {"r": [("x", -3)], "s": 1.0 + 0.03 * b}, "neck_01": [("x", -4)],
                           "Head": [("x", -6 - head_back), ("y", 3)]}),
                     {"_pelvis": (0, 0.02, SIT_Z)})
    anim.clip("Toy_Tea_Sit_Loop", [(1, sit(0.0)), (16, sit(1.0, 6)), (34, sit(1.0, 10, 1)), (48, sit(0.0, 0, 0.5)), (72, sit(0.0)), (91, sit(0.0))],
              faces=[(1, "pompous"), (14, "sip"), (44, "pompous")], loop=True)

    # ---- Toy_Sneeze: sip -> nose twitch -> ah... ah-ah... AHHH -> CHOO! launched backwards off the stool,
    #      riding the air into the sink (root motion 1.40 m back) -> legs up, dazed. -----------------------
    # staged for yaw -38 deg on the stool mark: world travel stool -> sink basin (1.12, -0.80) m
    SIDE, BACK = 0.390, 1.320
    k = []
    k.append((1, sit(1.0, 6)))
    k.append((12, sit(0.3)))
    tw = merge(sit(0.25), {"nose": {"s": 1.12}})
    k.append((18, tw))
    k.append((21, merge(sit(0.25), {"nose": {"s": 0.94}})))
    k.append((24, merge(sit(0.25), {"nose": {"s": 1.14}})))

    def ah(level, tremble=0.0):
        hb = [8, 13, 18][level]
        p = pose(SIT, sip_arms(0.1), TEA,
                 {"pelvis": [("x", -4 * level)], "spine_01": [("x", -6 - 4 * level)], "spine_02": {"r": [("x", -4 - 3 * level)], "s": 1.0 + 0.04 * (level + 1)},
                  "spine_03": [("x", -2 - 2 * level)], "neck_01": [("x", -6 - 3 * level)],
                  "Head": [("x", -hb + tremble), ("y", 3 + tremble)],
                  "nose": {"s": 1.12 + 0.07 * level}, "bouffant": {"r": [("x", 4 * level)], "s": 1.0 + 0.03 * level},
                  "sideburn_l": {"s": 1.0 + 0.1 * level}, "sideburn_r": {"s": 1.0 + 0.1 * level},
                  "upperarm_l": [("y", 34 - 22 * level), ("z", -64 + 14 * level)],
                  "upperarm_r": [("y", -24 + 22 * level), ("z", 66 - 14 * level)]})
        p["_pelvis"] = (0, 0.02, SIT_Z + 0.012 * level)
        return p
    k += [(30, ah(0)), (36, ah(0)), (44, ah(1)), (50, ah(1)), (58, ah(2)), (61, ah(2, 2)), (63, ah(2, -2)), (65, ah(2, 2))]
    # CHOO: head whips down-forward, the body is blown back (root starts to travel)
    choo = pose(TEA, {"pelvis": [("x", -40)], "spine_01": [("x", 10)], "spine_02": {"r": [("x", 10)], "s": 0.92},
                 "neck_01": [("x", 8)], "Head": [("x", 12)], "nose": {"s": 1.05}, "fx_choo": {"s": 1.0},
                 "bouffant": {"r": [("x", -18)], "s": (1.0, 1.0, 1.15)}, "sideburn_l": {"s": 1.3}, "sideburn_r": {"s": 1.3},
                 "upperarm_l": [("y", -10), ("z", -40)], "lowerarm_l": [("z", -10)], "upperarm_r": [("y", 10), ("z", 40)], "lowerarm_r": [("z", 10)],
                 "thigh_l": [("x", -40), ("y", -24)], "calf_l": [("x", 20)], "thigh_r": [("x", -36), ("y", 24)], "calf_r": [("x", 26)]})
    choo["_pelvis"] = (0, 0.0, SIT_Z + 0.04)
    choo["_root"] = (SIDE * 0.08, BACK * 0.08, 0)
    k.append((67, choo))
    k.append((66, merge(ah(2, -2), {"fx_choo": {"s": 0.0}})))
    k.sort(key=lambda kv: kv[0])

    def fly(t, spin):
        p = pose({"pelvis": [("x", -58 - 20 * t)], "spine_01": [("x", 6)], "spine_02": [("x", 4)], "neck_01": [("x", 10)],
                  "Head": [("x", 16 - 10 * t), ("y", 8 * spin)],
                  "bouffant": {"r": [("x", -24), ("y", 8 * spin)], "s": (1.0, 1.0, 1.2)}, "sideburn_l": {"s": 1.25}, "sideburn_r": {"s": 1.25},
                  "upperarm_l": [("y", -30 + 20 * spin), ("z", -50)], "lowerarm_l": [("y", -30)],
                  "upperarm_r": [("y", 30 + 20 * spin), ("z", 50)], "lowerarm_r": [("y", 30)],
                  "thigh_l": [("x", -40 - 15 * spin), ("y", -26)], "calf_l": [("x", 10)], "foot_l": [("x", -20)],
                  "thigh_r": [("x", -34 + 15 * spin), ("y", 26)], "calf_r": [("x", 16)], "foot_r": [("x", -20)]}, TEA)
        arc = math.sin(math.pi * t)
        p["_root"] = (SIDE * (0.08 + 0.92 * t), BACK * (0.08 + 0.92 * t), 0)
        p["fx_choo"] = {"s": max(0.0, 1.4 - 3.2 * t)}
        p["_pelvis"] = (0, 0, SIT_Z + 0.04 + 0.45 * arc + (0.52 - SIT_Z - 0.04) * t)
        return p
    k += [(71, fly(0.12, 1)), (76, fly(0.35, -1)), (81, fly(0.6, 1)), (86, fly(0.85, -1)), (89, fly(1.0, 0))]
    # SPLASH: into the basin, squash, legs up, then a wobbly settle
    def sink(sq, head_x, head_y, legs_up=1.0):
        p = pose({"pelvis": [("x", -72)], "spine_01": {"r": [("x", 22)], "s": (1.0 + 0.1 * sq, 1.0 - 0.14 * sq, 1.0 + 0.1 * sq)},
                  "spine_02": [("x", 12)], "neck_01": [("x", 14)], "Head": [("x", head_x + 6), ("y", head_y)],
                  "bouffant": {"r": [("x", -10), ("y", head_y * 0.5)], "s": (1.0 + 0.08 * sq, 1.0, 1.0 - 0.1 * sq)},
                  "sideburn_l": {"s": 1.0}, "sideburn_r": {"s": 1.0},
                  "upperarm_l": [("y", 10), ("z", -20)], "lowerarm_l": [("y", -20), ("z", -30)],
                  "upperarm_r": [("y", -10), ("z", 20)], "lowerarm_r": [("y", 20), ("z", 30)],
                  "thigh_l": [("x", -34 * legs_up), ("y", -30)], "calf_l": [("x", 4)], "foot_l": [("x", -34)],
                  "thigh_r": [("x", -28 * legs_up), ("y", 30)], "calf_r": [("x", 8)], "foot_r": [("x", -34)]}, TEA)
        p["_root"] = (SIDE, BACK, 0)
        p["_pelvis"] = (0, 0, 0.52 - 0.05 * sq)
        return p
    k += [(91, sink(1.0, 16, 0)), (95, sink(-0.4, 4, 6)), (99, sink(0.2, 10, -8)), (104, sink(0.0, 6, 10)),
          (112, sink(0.0, 8, -10)), (120, sink(0.0, 6, 10)), (128, sink(0.0, 8, -10)), (136, sink(0.0, 6, 8))]
    anim.clip("Toy_Sneeze", k, faces=[(1, "sip"), (12, "pompous"), (18, "suspicious"), (28, "sneeze_build"), (66, "choo"),
                                      (72, "shock"), (91, "dazed")])

    # ---- Toy_Dazed_Sink_Loop: stuck in the basin, slippers up, head lolling in circles ---------------------
    dz = []
    for i in range(9):
        a = 2 * math.pi * i / 8
        dz.append((1 + 5 * i, sink(0.0, 7 + 5 * math.cos(a), 10 * math.sin(a))))
    anim.clip("Toy_Dazed_Sink_Loop", dz, faces=[(1, "dazed")], loop=True)
