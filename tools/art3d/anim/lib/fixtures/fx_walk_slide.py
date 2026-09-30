from mathutils import Vector
from lib import pose as P
from _walk import walk
def build(ctx):
    c = walk(ctx, "hush/fx_walk_slide", 2.0)
    c._setup_auto()
    runs = c._auto_runs
    def slide(pose, f):
        for side, spans in runs.items():
            for f0, f1 in spans:
                ff = f if f0 <= f <= f1 else (f + c.length if f0 <= f + c.length <= f1 else None)
                if ff is None:
                    continue
                k = (ff - f0) / float(max(1, f1 - f0))
                a = pose.pos("foot_" + side) + Vector((0.03 * k, 0, 0))                   # +0.03 m per stance
                P.solve_leg(pose, side, a, foot_world=pose.world_rot("foot_" + side))
    c.custom(slide, 0, c.length)
    return c
