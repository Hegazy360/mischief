"""A small in-place sneak cycle for the walk fixtures (54 f, two steps, knees high)."""
from lib.clip import Clip
from lib.pose import merge, swap, sym

BASE = merge(sym({"upperarm_l": [("y", 30), ("z", -40)], "lowerarm_l": [("z", -80)], "hand_l": [("y", 40)]}),
             {"spine_01": [("x", 12)], "spine_02": [("x", 6)], "neck_01": [("x", -8)], "Head": [("x", -6)]})


def contact():
    return merge(BASE, {"thigh_l": [("x", -40)], "calf_l": [("x", 30)], "foot_l": [("x", -10)],
                        "thigh_r": [("x", 28)], "calf_r": [("x", 20)], "foot_r": [("x", 24)], "pelvis": [("z", -4)]})


def passing():
    return merge(BASE, {"thigh_r": [("x", -70)], "calf_r": [("x", 100)], "foot_r": [("x", 30)],
                        "thigh_l": [("x", 2)], "calf_l": [("x", 10)], "foot_l": [("x", -6)], "pelvis": [("z", -1)]})


def walk(ctx, cid, speed=2.0, plant_speed=None):
    c = Clip(ctx, cid, length=54, loop=True, cheat_deg=20, audio="own")
    A0, A1 = contact(), passing()
    c.key(0, A0)
    c.key(13, A1)
    c.key(27, swap(A0))
    c.key(40, swap(A1))
    c.ground()
    c.auto_plant(speed_m_s=plant_speed if plant_speed is not None else speed)
    c.face(0, "sneak")
    return c
