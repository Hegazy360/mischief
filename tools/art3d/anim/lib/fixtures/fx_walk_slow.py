from _walk import walk
def build(ctx):
    c = walk(ctx, "hush/fx_walk_slow", 2.0, plant_speed=1.6)     # the stance moves at 0.8 × the declared speed
    c._setup_auto()
    c.speed_m_s = 2.0
    c.stride_m = 1.8
    return c
