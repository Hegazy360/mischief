from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _fx import sway
def build(ctx):
    c = Clip(ctx, "hush/fx_foot_slide", length=60, audio="own")
    for f in range(0, 61, 6):
        c.key(f, sway(f / 40.0))
    c.ground()
    base = {}
    def slide(pose, f):
        if "a" not in base:
            base["a"] = pose.pos("foot_l").copy()
            base["q"] = pose.world_rot("foot_l").copy()
        t = min(1.0, f / 30.0)
        P.solve_leg(pose, "l", base["a"] + Vector((0.03 * t, 0, 0)), foot_world=base["q"])    # 0.03 m in 30 f
    c.custom(slide, 0, 60)
    c.face(0, "neutral")
    return c
