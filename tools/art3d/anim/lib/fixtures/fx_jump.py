from lib.clip import Clip
from lib.pose import merge
from _fx import sway
def build(ctx):
    c = Clip(ctx, "hush/fx_jump", length=60, audio="own")
    for f in range(0, 31, 6):
        c.key(f, sway(f / 40.0))
    c.key(31, merge(sway(31 / 40.0), {"upperarm_l": [("y", 20), ("z", -4)]}), "linear")    # 50°/f in one frame
    for f in range(36, 61, 6):
        c.key(f, merge(sway(f / 40.0), {"upperarm_l": [("y", 20), ("z", -4)]}))
    c.ground()
    c.face(0, "neutral")
    return c
