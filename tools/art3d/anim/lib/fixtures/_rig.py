"""A small reach clip for the rig-rule fixtures (rig_pm, cheat 10)."""
from lib.clip import Clip
from lib.pose import merge
from _fx import sway, arm_up


def reach(ctx, cid, length=48, lock="rig_pm", **kw):
    c = Clip(ctx, cid, length=length, lock=lock, cheat_deg=10, audio="own", **kw)
    for f in range(0, length + 1, 8):
        c.key(f, merge(sway(f / 40.0), arm_up(0.6 + 0.2 * ((f // 8) % 2))))
    c.ground()
    c.face(0, "determined")
    return c
