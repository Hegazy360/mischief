from _fx import take
def build(ctx):
    return take(ctx, "hush/fx_draft", acc=(24, 30), antic=(12, 24), draft=True)
