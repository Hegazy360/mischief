"""Shared build for the statue freezes (freeze_1..4 here, freeze_5..8 in r3d-anim-hush-b): a 3-frame wind to an
overshoot, SNAP into the statue on f 5 (the table's `freeze_clack`), then perfectly still to f 150 (the view turns her
to marble on a plinth). The pose must read as a silhouette at 64 px (verbs_64.png)."""
from lib.clip import Clip
from lib.pose import merge, mix
from lib.hush_presets import ARMS_DOWN, STAND, gloves, head

L = 150


def build_freeze(ctx, cid, statue, cheat=35.0, face="statue", ball_feet=(), mid=None):
    """ball_feet: the sides that rise onto the ball of the foot (held there by a ball plant: no slide as the heel
    lifts); every other contact is found by auto_plant. mid: an optional pose layered on f 2 (a foot lifted clear on
    its way to the statue, so it steps instead of dragging)."""
    c = Clip(ctx, cid, length=L, cheat_deg=cheat, audio="table", blend_in=3, blend_out=8)
    stand = merge(ARMS_DOWN, STAND, gloves(18, 12), head())
    pose = merge(stand, statue)
    c.key(0, stand)
    if mid is not None:                       # half-way there, the stepping foot clear of the floor
        c.key(2, merge(mix(stand, pose, 0.45), mid), "in_out_sine")
    c.overshoot(4, pose, pct=0.06, frames=1, ease_in="linear")      # f 4 past it, f 5 SNAP into the statue
    c.key(L, pose)
    c.freeze_hold(5, L)
    c.ground()
    for side in ball_feet:
        c.plant(side, 0, L, part="ball")
    others = tuple(sd for sd in ("l", "r") if sd not in ball_feet)
    if others:
        c.auto_plant(speed_m_s=0.0, sides=others)
    c.pop_frames.append(5)                    # the snap
    c.face(0, "determined")
    c.face(5, face)
    c.mark(5, "accent")
    return c
