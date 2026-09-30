from lib.clip import Clip
from lib.pose import merge
from _fx import sway
def build(ctx):
    c = Clip(ctx, "hush/fx_seam", length=40, loop=True, audio="own")
    c.raw_seam = True
    for f in range(0, 40, 5):
        c.key(f, sway(f / 40.0))
    c.key(40, merge(sway(1.0), {"Head": [("z", 5), ("x", -2), ("y", 2)]}))      # frame 40 is 2° off frame 0
    c.ground()
    c.face(0, "neutral")
    return c
