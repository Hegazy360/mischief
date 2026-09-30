from _fx import take
def build(ctx):
    return take(ctx, "hush/fx_no_antic", oppose=False)
