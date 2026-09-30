"""The custom comedy clips (conventions in poses.py). 30 fps; frame 1 = t 0.

Hush:    Hush_Idle_Loop, Tiptoe_Loop, Snicker, Freeze_Statue, Rig_Pour_Loop, Peek_Loop
Bellows: Pompous_Idle_Loop, Strut_Loop, Tea_Sip_Loop, Sneeze, Dazed_Loop
Face timelines (the face bones are never keyed here) are written to <dir>/<who>_faces.json.
"""
import bpy, math, os, json
from mathutils import Vector
import poses
from poses import clip, sym, swap, mirror

FACES = {}


def L(**kw):
    return kw


def merge(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


def V3(*a):
    return Vector(a)


def ik(side, bone, p, pole):
    """IK wrist target p (rest armature space) riding on `bone`; pole = elbow direction."""
    return {"ik_" + side: (bone, Vector(p), Vector(pole))}


def arm_pose(side, up, lo, hand=None, clav=None):
    """side 'l' or 'r'; rotation lists written for the LEFT side, mirrored for the right."""
    d = {"upperarm_l": up, "lowerarm_l": lo}
    if hand is not None:
        d["hand_l"] = hand
    if clav is not None:
        d["clavicle_l"] = clav
    if side == "l":
        return d
    return {k[:-2] + "_r": mirror(v) for k, v in d.items()}


# =================================================================================================
# HUSH
# =================================================================================================
def hush():
    G = {"_ground": True}
    # --- idle: jaunty, weight on the right leg, right glove on the hip, left arm loose, a little bounce
    base = merge(G, {
        "pelvis": [("y", 4), ("z", 6)], "spine_01": [("y", -3)], "spine_02": [("y", -3), ("x", -2)], "spine_03": [("x", -3)],
        "neck_01": [("y", 4)], "Head": [("y", 6), ("z", -8), ("x", -2)],
        "thigh_l": [("x", -12), ("z", 8)], "calf_l": [("x", 22)], "foot_l": [("x", 6)],
        "thigh_r": [("y", 3)], "calf_r": [("x", 2)], "foot_r": [("x", -2)],
    }, ik("r", "pelvis", (-0.17, 0.02, META_J["pelvis"][2] + 0.1), (-1.0, 0.6, 0.1)), {"hand_r": mirror([("z", 20), ("y", -30)])},
        arm_pose("l", [("y", 76), ("z", -6)], [("z", -18)], [("y", 12)]))
    up = merge(base, {"spine_03": [("x", -5)], "Head": [("y", 3), ("z", -4), ("x", -5)], "_lift": 0.0,
                      "thigh_l": [("x", -8), ("z", 8)], "calf_l": [("x", 16)]})
    clip("Hush_Idle_Loop", [(1, base), (16, up), (31, base), (46, up), (61, base)], fingers={"l": 18, "r": 30})

    # --- tiptoe: cartoon sneak, 10 f per step, knees high, 'paws' up, leaning in
    J = META_J
    cy, cz = J["spine_03"][1] - 0.2, J["spine_03"][2] + 0.03
    paws = merge({"hand_l": [("z", -20), ("y", 70)], "hand_r": mirror([("z", -20), ("y", 70)])},
                 ik("l", "spine_03", (0.085, cy, cz), (1.0, 0.4, -0.7)), ik("r", "spine_03", (-0.085, cy, cz), (-1.0, 0.4, -0.7)))
    lean = {"spine_01": [("x", 14)], "spine_02": [("x", 10)], "spine_03": [("x", 4)], "neck_01": [("x", -8)], "Head": [("x", -10)]}

    def step_contact():
        return merge(G, lean, paws, {
            "thigh_l": [("x", -38)], "calf_l": [("x", 18)], "foot_l": [("x", 34)], "ball_l": [("x", -22)],
            "thigh_r": [("x", 24)], "calf_r": [("x", 34)], "foot_r": [("x", 42)], "ball_r": [("x", -32)],
            "pelvis": [("z", -6)], "spine_03": [("x", 4), ("z", 8)], "Head": [("x", -10), ("z", -6)]})

    def step_pass():
        return merge(G, lean, paws, {
            "thigh_r": [("x", -84)], "calf_r": [("x", 112)], "foot_r": [("x", 48)],
            "thigh_l": [("x", 4)], "calf_l": [("x", 6)], "foot_l": [("x", 40)], "ball_l": [("x", -40)],
            "pelvis": [("z", -2)], "spine_03": [("x", 2), ("z", 3)], "Head": [("x", -12), ("z", -3)], "_lift": 0.012})

    A0, A1 = step_contact(), step_pass()
    A2, A3 = swap(A0), swap(A1)
    for p in (A2, A3):
        p["_ground"] = True
    clip("Tiptoe_Loop", [(1, A0), (6, A1), (11, A2), (16, A3), (21, A0)], fingers={"l": 38, "r": 38})

    # --- snicker at the Stalls: hunch, glove at the mouth, knees pinched, shoulders shaking
    sn = merge(G, {
        "pelvis": [("y", -6)], "spine_01": [("x", 16)], "spine_02": [("x", 10), ("z", 10)], "spine_03": [("x", 6), ("z", 8)],
        "neck_01": [("x", -8)], "Head": [("y", -12), ("z", 6), ("x", -12)],
        "thigh_l": [("x", -18), ("z", -8)], "calf_l": [("x", 36)], "foot_l": [("x", 18)],
        "thigh_r": [("x", -10), ("z", 10)], "calf_r": [("x", 24)], "foot_r": [("x", 10)],
    }, {"hand_r": mirror([("z", -70), ("y", 10)]), "hand_l": [("z", -30), ("y", 20)]},
        ik("r", "Head", tuple(V3(*MOUTH) + V3(-0.07, -0.1, -0.11)), (-1.0, 0.2, -0.8)),
        ik("l", "spine_01", (0.03, J["spine_01"][1] - 0.2, J["spine_01"][2] + 0.03), (1.0, 0.1, -1.0)))
    keys = [(1, merge(G, base)), (6, merge(sn, {"spine_01": [("x", 6)], "Head": [("y", -6), ("z", 14), ("x", -12)]}))]
    f = 9
    for i in range(10):
        upk = i % 2 == 0
        p = dict(sn)
        p["clavicle_l"] = [("y", -9 if upk else 2), ("z", -6)]
        p["clavicle_r"] = mirror([("y", -9 if upk else 2), ("z", -10)])
        p["spine_03"] = [("x", 6 - (4 if upk else 0)), ("z", 8)]
        p["Head"] = [("y", -12 + (4 if upk else -2)), ("z", 6), ("x", -12 - (5 if upk else 0))]
        p["_lift"] = 0.012 if upk else 0.0
        keys.append((f, p))
        f += 4
    keys.append((f + 4, merge(sn, {"Head": [("y", -10), ("z", 16), ("x", -8)]})))
    clip("Snicker", keys, fingers={"l": 35, "r": 12})
    FACES["Snicker"] = [[0.0, "neutral"], [0.14, "glee"], [0.3, "snicker"], [1.55, "sneaky"]]

    # --- freeze statue: flamingo, one arm curved over the head, one out, chin up, eyes shut
    st = merge(G, {
        "pelvis": [("z", -4)], "spine_01": [("y", 4)], "spine_02": [("y", 6), ("x", -4)], "spine_03": [("x", -6), ("y", 4)],
        "neck_01": [("x", -8)], "Head": [("x", -12), ("y", -12), ("z", 6)],
        "thigh_r": [("x", -72), ("z", -6)], "calf_r": [("x", 96)], "foot_r": [("x", 50)],
        "thigh_l": [("x", 2)], "calf_l": [("x", 2)], "foot_l": [("x", 34)], "ball_l": [("x", -34)],
    }, arm_pose("l", [("y", -62), ("z", 6)], [("z", -58)], [("y", -20)]),
        arm_pose("r", [("y", -8), ("z", 12)], [("z", -14)], [("y", -28)]))
    st2 = dict(st)
    st2["Head"] = [("x", -12), ("y", -13), ("z", 6)]
    clip("Freeze_Statue", [(1, st), (61, st2)], fingers={"l": 10, "r": 4})
    FACES["Freeze_Statue"] = [[0.0, "statue"]]

    # --- rigging: pepper into the honey. The jar sits in her left glove at belly height, the pepper pot in
    #     the right is shaken over it: the whole action happens in front of her body (reads from the front).
    pr = merge(G, {
        "pelvis": [("z", -6)], "spine_01": [("x", 10)], "spine_02": [("x", 10), ("z", -4)], "spine_03": [("x", 8), ("z", -4)],
        "neck_01": [("x", 6), ("z", 6)], "Head": [("x", 12), ("z", 22), ("y", 10)],
        "thigh_l": [("x", -10), ("z", 6)], "calf_l": [("x", 18)], "foot_l": [("x", 8)],
        "thigh_r": [("x", 4), ("z", -4)], "calf_r": [("x", 10)], "foot_r": [("x", 6)],
    }, ik("l", "spine_01", JAR_HOLD, (1.0, 0.3, -1.0)), {"hand_l": [("z", 30), ("y", -20)]})
    keys = []
    f = 1
    for i in range(6):
        p = dict(pr)
        k = 1 if i % 2 == 0 else -1
        p.update(ik("r", "spine_02", tuple(V3(*POUR_WRIST) + V3(0.0, 0.0, 0.025 * k)), (-0.6, 0.2, -1.0)))
        p["hand_r"] = mirror([("z", -35 - 18 * k), ("y", 10)])
        p["Head"] = [("x", 12 + 2 * k), ("z", 22), ("y", 10 + 3 * k)]
        keys.append((f, p))
        f += 5
    keys.append((f, keys[0][1]))
    clip("Rig_Pour_Loop", keys, fingers={"l": 20, "r": 62})
    FACES["Rig_Pour_Loop"] = [[0.0, "focus"]]

    # --- peek from the pantry: crouched behind the curtain edge, lean out to her left, glove on the edge
    pk = merge(G, {
        "pelvis": [("y", 10)], "spine_01": [("y", 12), ("x", 14)], "spine_02": [("y", 12), ("x", 12)], "spine_03": [("y", 8), ("x", 6)],
        "neck_01": [("y", 10), ("x", -6)], "Head": [("y", 12), ("z", 16), ("x", -10)],
        "thigh_l": [("x", -34), ("z", 10)], "calf_l": [("x", 58)], "foot_l": [("x", 20)],
        "thigh_r": [("x", -24), ("z", -6)], "calf_r": [("x", 50)], "foot_r": [("x", 26)],
    }, ik("l", "root", (0.3, -0.32, 1.02), (1.0, 0.6, -0.6)), {"hand_l": [("z", -60), ("y", 0)]},
        ik("r", "spine_03", (-0.02, J["spine_03"][1] - 0.2, J["spine_03"][2] - 0.02), (-1.0, 0.3, -1.0)), {"hand_r": mirror([("y", 50)])})
    pk_in = merge(pk, {"spine_01": [("y", 4), ("x", 6)], "spine_02": [("y", 4), ("x", 4)], "neck_01": [("y", 2)],
                       "Head": [("y", 4), ("z", 22), ("x", -2)]})
    clip("Peek_Loop", [(1, pk), (20, pk_in), (40, pk), (61, pk)], fingers={"l": 55, "r": 30})
    FACES["Peek_Loop"] = [[0.0, "peek"]]


# =================================================================================================
# BELLOWS
# =================================================================================================
def bellows():
    G = {"_ground": True}
    # arms: his hands rest on the sides of the barrel (arm-out already built into the pose)
    chest = {"spine_01": [("x", -3)], "spine_02": [("x", -6)], "spine_03": [("x", -4)], "neck_01": [("x", -6)], "Head": [("x", -8)]}
    J = META_J
    yb = J["spine_02"][1] - 0.36
    zb_ = J["spine_01"][2] + 0.1
    belly_hands = merge(ik("l", "spine_01", (0.42, -0.14, 0.8), (1.0, 0.5, -0.2)), ik("r", "spine_01", (-0.42, -0.14, 0.8), (-1.0, 0.5, -0.2)),
                        {"hand_l": [("z", -55), ("y", 25)], "hand_r": mirror([("z", -55), ("y", 25)])})
    idle = merge(G, chest, belly_hands, {"thigh_l": [("z", 6)], "thigh_r": [("z", -6)]})
    breathe = merge(idle, {"spine_02": [("x", -9)], "spine_03": [("x", -6)], "Head": [("x", -11), ("z", 8)], "_lift": 0.008})
    look = merge(idle, {"Head": [("x", -8), ("z", -10)]})
    clip("Pompous_Idle_Loop", [(1, idle), (24, breathe), (46, idle), (68, look), (91, idle)], fingers={"l": 30, "r": 30})
    FACES["Pompous_Idle_Loop"] = [[0.0, "pompous"]]

    # strut: chin up, chest out, tiny fast steps (12 f per step), arms swinging wide, waddle
    def strut(k):
        s = "l" if k > 0 else "r"
        o = "r" if k > 0 else "l"
        leg = {"thigh_" + s: [("x", -34)], "calf_" + s: [("x", 12)], "foot_" + s: [("x", -12)],
               "thigh_" + o: [("x", 22)], "calf_" + o: [("x", 14)], "foot_" + o: [("x", 14)]}
        arms = merge(arm_pose(o, [("y", 42), ("z", -30)], [("z", -30)]), arm_pose(s, [("y", 42), ("z", 26)], [("z", -12)]))
        return merge(G, chest, arms, leg, {"spine_01": [("y", 5 * k), ("x", -3)], "spine_02": [("x", -7), ("z", 6 * k)],
                                           "Head": [("x", -10), ("y", -3 * k)], "pelvis": [("z", -8 * k)]})

    def strut_pass(k):
        s = "l" if k > 0 else "r"
        o = "r" if k > 0 else "l"
        leg = {"thigh_" + o: [("x", -44)], "calf_" + o: [("x", 62)], "foot_" + o: [("x", 10)],
               "thigh_" + s: [("x", 2)], "calf_" + s: [("x", 4)]}
        return merge(G, chest, belly_hands, leg, {"spine_02": [("x", -8)], "Head": [("x", -11)], "_lift": 0.03,
                                                  "spine_01": [("y", 2 * k)]})

    clip("Strut_Loop", [(1, strut(1)), (7, strut_pass(1)), (13, strut(-1)), (19, strut_pass(-1)), (25, strut(1))], fingers={"l": 25, "r": 25})
    FACES["Strut_Loop"] = [[0.0, "pompous"]]

    # --- sitting on the stool (seat 0.66 m): his tiny legs dangle
    seat_dz = 0.66 - (META_J["pelvis"][2] - 0.07)
    sit = {"_root": (0, 0, seat_dz), "pelvis": [("x", -4)],
           "thigh_l": [("x", -82), ("z", 10)], "calf_l": [("x", 58)], "foot_l": [("x", 18)],
           "thigh_r": [("x", -78), ("z", -12)], "calf_r": [("x", 70)], "foot_r": [("x", 22)],
           "spine_01": [("x", -4)], "spine_02": [("x", -4)], "spine_03": [("x", -2)]}
    zs = J["spine_02"][2] + 0.02
    saucer = merge(ik("l", "spine_02", (0.34, -0.3, 0.92), (1.0, 0.3, -0.5)), {"hand_l": [("z", -40), ("y", 10)]})
    cup_low = merge(ik("r", "spine_02", (-0.3, -0.34, 0.97), (-1.0, 0.3, -0.5)), {"hand_r": mirror([("z", -40), ("y", 10)])})
    cup_up = merge(ik("r", "Head", tuple(V3(*MOUTH) + V3(-0.05, -0.12, -0.03)), (-1.0, 0.1, -0.6)), {"hand_r": mirror([("z", -50), ("y", 0)])})
    tea0 = merge(sit, saucer, cup_low, {"Head": [("x", -4)], "neck_01": [("x", -2)]})
    tea1 = merge(sit, saucer, cup_up, {"Head": [("x", -14)], "neck_01": [("x", -6)], "spine_03": [("x", -6)]})
    tea2 = merge(tea1, {"Head": [("x", -18)], "spine_02": [("x", -7)]})
    clip("Tea_Sip_Loop", [(1, tea0), (16, tea1), (30, tea2), (44, tea1), (61, tea0), (91, tea0)], fingers={"l": 20, "r": 55})
    FACES["Tea_Sip_Loop"] = [[0.0, "pompous"], [0.5, "sip"], [2.0, "pompous"]]

    # --- the sneeze: ah (20 f) .. ahh (24 f) .. AHHH (30 f) .. false stop (20 f) .. CHOO -> launched backwards
    #     off the stool into the sink (root motion: 1.15 m back, 0.9 m to his right = into the basin), dazed.
    def ah(level):
        k = level
        return merge(sit, {"spine_02": [("x", -6 - 6 * k)], "spine_03": [("x", -4 - 7 * k)], "neck_01": [("x", -4 - 6 * k)],
                           "Head": [("x", -6 - 10 * k)], "pelvis": [("x", -4 - 3 * k)],
                           "thigh_l": [("x", -82 - 6 * k), ("z", 10)], "thigh_r": [("x", -78 - 6 * k), ("z", -12)]},
                     arm_pose("l", [("y", 36 - 14 * k), ("z", -44 + 8 * k)], [("z", -66 + 10 * k)], [("y", 6)]),
                     arm_pose("r", [("y", 34 - 16 * k), ("z", -46 + 8 * k)], [("z", -78 + 12 * k)], [("y", 0)]))
    relief = merge(tea0, {"Head": [("x", 2)], "spine_03": [("x", 2)]})
    choo = merge(sit, {"spine_01": [("x", 16)], "spine_02": [("x", 18)], "spine_03": [("x", 14)], "neck_01": [("x", 10)],
                       "Head": [("x", 22)], "pelvis": [("x", 6)]},
                 arm_pose("l", [("y", -10), ("z", 40)], [("z", -10)]), arm_pose("r", [("y", -10), ("z", 40)], [("z", -10)]))
    back = (-0.9, 1.15)            # his right (toward the back wall), backwards (toward the sink)
    land_dz = 0.8 - (META_J["pelvis"][2] - 0.07)

    def flight(t, rot):
        x = back[0] * t
        y = back[1] * t
        z = seat_dz + (land_dz - seat_dz) * t + 0.55 * math.sin(math.pi * t)
        return merge({"_root": (x, y, z), "pelvis": [("x", -rot)]},
                     {"thigh_l": [("x", -95)], "calf_l": [("x", 25)], "thigh_r": [("x", -80)], "calf_r": [("x", 45)],
                      "spine_02": [("x", -10)], "Head": [("x", -18)], "neck_01": [("x", -8)]},
                     arm_pose("l", [("y", -40), ("z", 20)], [("z", -30)]), arm_pose("r", [("y", -30), ("z", 30)], [("z", -50)]))
    # wedged bum-first in the basin: reclined against the window, tiny legs up over the front edge,
    # arms draped over the sides, head lolling, the bouffant flopped over his face
    sink = {"_root": (back[0], back[1], land_dz - 0.1), "root": [("z", 48)], "pelvis": [("x", -40)],
            "thigh_l": [("x", -78), ("z", 16)], "calf_l": [("x", 24)], "foot_l": [("x", 24)],
            "thigh_r": [("x", -70), ("z", -18)], "calf_r": [("x", 40)], "foot_r": [("x", 10)],
            "spine_01": [("x", 8)], "spine_02": [("x", 8)], "spine_03": [("x", 10)], "neck_01": [("x", 14)], "Head": [("x", 16), ("y", 12)],
            "bouffant": [("x", 38)]}
    sink_arms = merge(arm_pose("l", [("y", 10), ("z", 20)], [("z", -8)], [("y", 45)]), arm_pose("r", [("y", 16), ("z", 24)], [("z", -14)], [("y", 48)]))
    sinkA = merge(sink, sink_arms)
    sinkB = merge(sinkA, {"Head": [("x", 20), ("y", -14), ("z", 12)], "neck_01": [("x", 12), ("y", -6)], "bouffant": [("x", 34), ("y", 8)]})
    sinkC = merge(sinkA, {"Head": [("x", 10), ("y", 6), ("z", -14)], "bouffant": [("x", 42), ("y", -8)]})
    for p in (tea0, relief, choo, sinkA, sinkB, sinkC):
        p.setdefault("bouffant", [])
    keys = [(1, tea0), (8, merge(tea0, {"Head": [("x", -8)]})),
            (28, ah(1.0)), (36, ah(0.6)), (52, ah(1.7)), (60, ah(1.1)), (82, ah(2.6)),
            (96, merge(ah(2.2), {"Head": [("x", -30), ("z", 4)]})),
            (104, relief), (122, merge(relief, {"Head": [("x", 0), ("z", -4)]})),
            (125, ah(2.8)), (128, choo),
            (130, merge(flight(0.08, 25), {"bouffant": [("x", -30)]})),
            (135, merge(flight(0.4, 80), {"bouffant": [("x", -40)]})),
            (140, merge(flight(0.75, 70), {"bouffant": [("x", 20)]})),
            (144, merge(flight(1.0, 50), {"bouffant": [("x", 80)]})),
            (147, merge(sinkA, {"pelvis": [("x", -50)], "_root": (back[0], back[1], land_dz - 0.16), "bouffant": [("x", 80)]})),
            (151, sinkA), (160, sinkB), (170, sinkC), (180, sinkB), (190, sinkA)]
    clip("Sneeze", keys, fingers={"l": 20, "r": 50})
    FACES["Sneeze"] = [[0.0, "sip"], [0.3, "pompous"], [0.55, "sneeze_build"], [1.2, "neutral"], [1.4, "sneeze_build"],
                       [3.2, "sneeze_build"], [3.45, "neutral"], [4.08, "sneeze_build"], [4.23, "choo"], [4.33, "shock"],
                       [4.9, "dazed"]]
    clip("Dazed_Loop", [(1, sinkA), (16, sinkB), (31, sinkC), (46, sinkB), (61, sinkA)], fingers={"l": 20, "r": 20})
    FACES["Dazed_Loop"] = [[0.0, "dazed"]]


META_J = {}
MOUTH = (0, 0, 0)
JAR_HOLD = (0.3, -0.22, 0.98)
POUR_WRIST = (0.2, -0.3, 1.14)


def make(who):
    global MOUTH
    META_J.update(poses.META["joints"])
    MOUTH = tuple(poses.META["mouth_c"])
    if who == "hush":
        hush()
    else:
        bellows()
    d = poses.META.get("_dir")
    if d:
        json.dump(FACES, open(os.path.join(d, who + "_faces.json"), "w"), indent=1)


def preview(arm, char, who, out, which=""):
    pass
