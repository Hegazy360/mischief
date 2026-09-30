from _fx import take
def build(ctx):
    # reactions_override in the test says antic 14 / accent 28 / hold [31, 70]: the accent here is 4 f early
    return take(ctx, "hush/rx_fx_beats", length=90, acc=(24, 27), antic=(10, 24), hold_end=70, lock="sim")
