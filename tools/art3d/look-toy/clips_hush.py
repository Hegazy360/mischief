"""Hush's custom Toy Box clips (keyed in bpy). Angles in degrees about ARMATURE axes (parent at rest):
x+ = bend forward (spine/head) / thigh back / knee flex ; y+ = lean or tilt to her LEFT, left arm DOWN ;
z+ = turn toward her LEFT, left arm BACK. Right side = mirrored (toy_pose.mirror)."""
from toy_pose import sym, swap, merge, curl, mirror, lerp_pose

HIDE_PROP = {"prop_r": {"s": 0.0}, "fx_pepper": {"s": 0.0}}
# relaxed arms: down but a little out from the round torso, elbows soft, gloves half open
ARMS = sym({"clavicle_l": [], "upperarm_l": [("y", 64), ("z", -6)], "lowerarm_l": [("z", -14)], "hand_l": [("x", -8)]})
GLOVES = merge(curl("l", 16, thumb=10), curl("r", 16, thumb=10))


def pose(*parts, **kw):
    p = merge(HIDE_PROP, ARMS, GLOVES, *parts)
    for k, v in kw.items():
        p["_" + k] = v
    return p


def build(anim, rig):
    # ---- Toy_Idle_Loop: a cheerful bob + head sway with a lagging beret (48 f = 1.6 s) -----------------
    def idle(t):
        import math
        s = math.sin(2 * math.pi * t)
        c = math.cos(2 * math.pi * t)
        b = abs(math.sin(2 * math.pi * t))
        return pose({"pelvis": [("y", 2 * s)], "spine_01": [("x", 2), ("y", -2 * s)], "spine_02": [("x", 2 + b)],
                     "spine_03": [("y", -1.5 * s)], "neck_01": [("y", 3 * s)], "Head": [("y", 5 * s), ("x", -3 + 1.5 * b)],
                     "beret": [("y", -4 * c), ("x", 2 * s)],
                     "upperarm_l": [("y", 62 + 3 * b), ("z", -6)], "upperarm_r": [("y", -62 - 3 * b), ("z", 6)],
                     "thigh_l": [("x", -4 - 2 * s)], "calf_l": [("x", 8 + 4 * max(0, s))], "foot_l": [("x", -4)],
                     "thigh_r": [("x", -4 + 2 * s)], "calf_r": [("x", 8 + 4 * max(0, -s))], "foot_r": [("x", -4)]},
                    pelvis=(0, 0, -0.012 * b))
    keys = [(1 + int(48 * i / 8), idle(i / 8)) for i in range(9)]
    anim.clip("Toy_Idle_Loop", keys, faces=[(1, "neutral")], loop=True)

    # ---- Toy_Tiptoe_Loop: the cartoon sneak (32 f, two steps); head cheated toward her right (the Stalls
    #      when she walks right; the view mirrors the rig for left walks) --------------------------------
    paws = sym({"clavicle_l": [("z", -8), ("y", -6)], "upperarm_l": [("y", 34), ("z", -60)], "lowerarm_l": [("z", -92), ("y", -34)],
                "hand_l": [("y", 62), ("x", 0)]})
    paws.update(merge(curl("l", 40, thumb=10), curl("r", 40, thumb=10)))
    lean = {"spine_01": [("x", 18)], "spine_02": [("x", 12)], "spine_03": [("x", 6)], "neck_01": [("x", -6)]}

    def step(phase, turn, bob):
        if phase == 0:     # left knee high, right on its toes
            legs = {"thigh_l": [("x", -84)], "calf_l": [("x", 104)], "foot_l": [("x", 46)],
                    "thigh_r": [("x", 16)], "calf_r": [("x", 20)], "foot_r": [("x", 44)], "ball_r": [("x", -34)]}
            pz = -0.035
        else:              # passing: both on tiptoe, body up
            legs = {"thigh_l": [("x", -30)], "calf_l": [("x", 58)], "foot_l": [("x", 46)],
                    "thigh_r": [("x", 2)], "calf_r": [("x", 8)], "foot_r": [("x", 44)], "ball_r": [("x", -38)]}
            pz = 0.02
        return pose(lean, paws, legs, {"Head": [("x", 2 + bob), ("z", turn), ("y", -4)], "beret": [("y", 5), ("x", -bob)],
                                        "spine_03": [("x", 6), ("z", turn * 0.25)]}, pelvis=(0, 0, pz))
    A0, A1 = step(0, -24, 4), step(1, -20, -2)
    A2, A3 = swap(step(0, 24, 4)), swap(step(1, 20, -2))
    for P in (A2, A3):
        P.update(HIDE_PROP)
    anim.clip("Toy_Tiptoe_Loop", [(1, A0), (9, A1), (17, A2), (25, A3), (33, A0)], faces=[(1, "sneaky")], loop=True)

    # ---- Toy_Snicker: gloves up to the chin, knock-kneed, shoulders shaking, a sly glance (one-shot) ----
    giggle = sym({"clavicle_l": [("y", -12)], "upperarm_l": [("y", 30), ("z", -96)], "lowerarm_l": [("y", -100), ("z", -10)],
                  "hand_l": [("x", -30), ("z", -20)]})
    giggle.update(merge(curl("l", 30, thumb=20), curl("r", 30, thumb=20)))
    legs = {"thigh_r": [("x", -10), ("z", 12)], "calf_r": [("x", 40)], "foot_r": [("x", 44), ("z", 10)], "ball_r": [("x", -30)],
            "thigh_l": [("x", -4), ("z", -4)], "calf_l": [("x", 8)]}
    base = pose(giggle, legs, {"spine_01": [("x", 4)], "spine_02": [("x", 4)], "spine_03": [("x", 2)], "neck_01": [("x", 2)],
                               "Head": [("x", 4), ("y", 10)]})
    keys = [(1, pose({"Head": [("x", -2)]})), (6, merge(base, {"_pelvis": (0, 0, -0.03)}))]
    f = 6
    for i in range(9):
        up = i % 2
        p = dict(base)
        p["clavicle_l"] = [("y", -12 - 10 * up)]
        p["clavicle_r"] = [("y", 12 + 10 * up)]
        p["spine_02"] = [("x", 4 + 4 * up)]
        glance = i >= 6
        p["Head"] = [("x", 4 - 5 * up - (6 if glance else 0)), ("y", 10 if not glance else 6), ("z", 0 if not glance else -24)]
        p["beret"] = [("y", -5 * up)]
        p["_pelvis"] = (0, 0, -0.03 + 0.022 * up)
        f += 4
        keys.append((f, p))
    f += 14
    keys.append((f, keys[-1][1]))
    anim.clip("Toy_Snicker", keys, faces=[(1, "sneaky"), (6, "snicker"), (30, "sneaky")])

    # ---- Toy_Pour_Loop: on tiptoe, shaker tipped over the honey jar, shake-shake, grinning at the Stalls --
    def pour(shake):
        arm_r = {"clavicle_r": [("y", 14)], "upperarm_r": [("y", 40 + 5 * shake), ("z", 92)], "lowerarm_r": [("y", -10), ("z", 6)],
                 "hand_r": [("x", 80 + 14 * shake), ("y", -20)]}
        arm_l = {"clavicle_l": [("y", -12)], "upperarm_l": [("y", 30), ("z", -96)], "lowerarm_l": [("y", -100), ("z", -10)],
                 "hand_l": [("x", -30), ("z", -20)]}
        return merge(ARMS, GLOVES, arm_r, arm_l, curl("r", 80, thumb=40), curl("l", 30, thumb=20),
                     {"spine_01": [("x", 8)], "spine_02": [("x", 4), ("z", -6)], "neck_01": [("x", 2)],
                      "Head": [("x", 2), ("y", 6), ("z", -34)], "beret": [("y", -4 * shake)],
                      "thigh_l": [("x", -4)], "calf_l": [("x", 6)], "foot_l": [("x", 40)], "ball_l": [("x", -36)],
                      "thigh_r": [("x", 6)], "calf_r": [("x", 8)], "foot_r": [("x", 40)], "ball_r": [("x", -36)],
                      "prop_r": {"s": 1.0}, "fx_pepper": {"s": 0.0},
                      "_pelvis": (0, 0, 0.035 + 0.01 * shake)})
    anim.clip("Toy_Pour_Loop", [(1, pour(0)), (7, pour(1)), (13, pour(0)), (19, pour(1)), (25, pour(0)), (31, pour(1)), (37, pour(0))],
              faces=[(1, "sneaky")], loop=True)

    # ---- Toy_Peek_Loop: parting the curtains with both gloves, face poked through, eyes left / right -----
    def peek(look):
        return pose(sym({"clavicle_l": [("y", -8)], "upperarm_l": [("y", 16), ("z", -70)], "lowerarm_l": [("y", -86), ("z", 20)],
                         "hand_l": [("x", -40), ("y", 10)]}),
                    merge(curl("l", 55, thumb=30), curl("r", 55, thumb=30)),
                    {"spine_01": [("x", 16)], "spine_02": [("x", 12)], "spine_03": [("x", 6)],
                     "neck_01": [("x", -2)], "Head": [("x", -8), ("z", look), ("y", look * -0.3)], "beret": [("y", 4)],
                     "thigh_l": [("x", -18)], "calf_l": [("x", 26)], "thigh_r": [("x", -18)], "calf_r": [("x", 26)]},
                    pelvis=(0, 0.04, -0.03))
    anim.clip("Toy_Peek_Loop", [(1, peek(-14)), (20, peek(-14)), (30, peek(16)), (50, peek(16)), (61, peek(-14))],
              faces=[(1, "focus")], loop=True)

    # ---- Toy_Freeze_Statue: caught -> strike an arabesque and hold (eyes shut, smug) --------------------
    statue = pose({"spine_01": [("x", 10)], "spine_02": [("x", 6)], "neck_01": [("x", -14)], "Head": [("x", -12), ("y", 10)],
                   "beret": [("y", -6)],
                   "clavicle_l": [("y", -10)], "upperarm_l": [("y", -22), ("z", -20)], "lowerarm_l": [("y", -10)], "hand_l": [("y", -20)],
                   "clavicle_r": [("y", 6)], "upperarm_r": [("y", -18), ("z", -40)], "lowerarm_r": [("z", -20)], "hand_r": [("y", 25)],
                   "thigh_r": [("x", 62)], "calf_r": [("x", 10)], "foot_r": [("x", 46)],
                   "thigh_l": [("x", -4)], "calf_l": [("x", 2)], "foot_l": [("x", 0)]},
                  merge(curl("l", -6, thumb=0), curl("r", -6, thumb=0)), pelvis=(0, 0, -0.005))
    anim.clip("Toy_Freeze_Statue", [(1, statue), (31, statue)], faces=[(1, "statue")])
