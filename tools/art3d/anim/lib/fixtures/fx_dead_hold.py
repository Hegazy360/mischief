from lib.clip import Clip
from _fx import sway
def build(ctx):
    c = Clip(ctx, "hush/fx_dead_hold", length=60, audio="own")
    still = sway(0.25)
    for f in (0, 6, 12, 18):
        c.key(f, sway(f / 40.0))
    c.key(20, still)
    c.key(42, still)                  # 22 frames without motion
    c.key(48, sway(48 / 40.0))
    c.key(54, sway(54 / 40.0))
    c.key(60, sway(60 / 40.0))
    c.ground()
    c.face(0, "neutral")
    return c
