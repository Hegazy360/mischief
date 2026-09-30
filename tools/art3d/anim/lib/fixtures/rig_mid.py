from _rig import reach
def build(ctx):
    c = reach(ctx, "hush/rig_mid", length=48)
    c.mark(24, "glance")                                     # band clips carry no baked glance marks
    return c
