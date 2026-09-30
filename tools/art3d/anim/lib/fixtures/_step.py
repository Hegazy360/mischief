from lib.clip import Clip
from lib.pose import merge
from _fx import sway, arm_up

CROUCH = {"thigh_l": [("x", -40)], "calf_l": [("x", 72)], "foot_l": [("x", -32)],
          "thigh_r": [("x", -38)], "calf_r": [("x", 70)], "foot_r": [("x", -32)], "spine_01": [("x", 14)]}
TUCK = {"thigh_l": [("x", -60)], "calf_l": [("x", 80)], "thigh_r": [("x", -55)], "calf_r": [("x", 75)]}


def stepped(ctx, cid, down=True):
    c = Clip(ctx, cid, length=48, lock="rig_pm", cheat_deg=10, audio="own")
    c.key(0, sway(0.0))
    c.key(3, merge(sway(0.1), CROUCH), "in_out_quad")
    c.key(6, merge(sway(0.15), TUCK), "out_quad")
    c.key(9, merge(sway(0.2), CROUCH), "out_quad")
    c.key(16, merge(sway(0.4), arm_up(0.7)))
    c.key(30, merge(sway(0.75), arm_up(0.8)))
    if down:
        c.key(40, merge(sway(1.0), CROUCH))
        c.key(43, merge(sway(1.1), TUCK), "out_quad")
        c.key(46, merge(sway(1.15), CROUCH), "out_quad")
        c.key(48, sway(1.2))
    else:
        c.key(48, merge(sway(1.2), arm_up(0.7)))
    c.ground()
    c.step_up("mime", 0.40, 3, 9)
    if down:
        c.step_down(40, 46)
    c.auto_plant(speed_m_s=0.0)          # feet held where they land (on the step, then on the floor)
    c.face(0, "determined")
    return c
