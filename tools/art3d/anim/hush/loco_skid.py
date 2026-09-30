"""hush/loco_skid — the run's skid stop (REDESIGN §4.2 "Run" AFTER; clip_rules.json `flavour:skid`, 6 f): from the
25° run lean she throws her weight BACK, the front heel digs in with the toes up, the back knee folds, both arms
windmill up and over once for balance; a dust puff at the heel. The view decelerates her; the clip stays in place."""
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import gloves, glove, lean, head

# the run's lean (loco_run: 25°, fists pumping) — what the 2-f blend-in lands on
RUN = merge(sym({"upperarm_l": [("y", 62), ("z", -30)], "lowerarm_l": [("z", -84)], "hand_l": [("x", -10)]}),
            {"upperarm_r": [("y", -62), ("z", -20)], "lowerarm_r": [("z", 70)]}, gloves(70, 30), lean(fwd=24),
            head(x=-16), {"thigh_l": [("x", -40)], "calf_l": [("x", 50)], "foot_l": [("x", 10)],
                          "thigh_r": [("x", 10)], "calf_r": [("x", 40)], "foot_r": [("x", 20)], "pelvis": [("x", 6)]})
# heels in: weight thrown back, the front leg long with the toes up, the back knee folded, arms flung forward-up
DIG = merge(sym({"clavicle_l": [("y", -8)], "upperarm_l": [("y", -10), ("z", -60)], "lowerarm_l": [("z", -20)],
                 "hand_l": [("x", -20)]}),
            {"upperarm_r": [("y", 20), ("z", 70)]}, glove("l", 2, 0, spread=20), glove("r", 4, 0, spread=18),
            lean(fwd=-16), head(x=6, z=-6),
            {"thigh_l": [("x", -34), ("z", 4)], "calf_l": [("x", 4)], "foot_l": [("x", -30)],
             "thigh_r": [("x", 20), ("z", -4)], "calf_r": [("x", 70)], "foot_r": [("x", 10)], "pelvis": [("x", -8)]})
# the windmill's top: arms up and over, still leaning back
OVER = merge(sym({"clavicle_l": [("y", -12)], "upperarm_l": [("y", -60), ("z", -10)], "lowerarm_l": [("z", -24)],
                  "hand_l": [("x", -10)]}),
             {"upperarm_r": [("y", -30), ("z", 24)]}, glove("l", 4, 0, spread=20), glove("r", 6, 0, spread=16),
             lean(fwd=-10), head(x=2, z=-4),
             {"thigh_l": [("x", -26), ("z", 4)], "calf_l": [("x", 8)], "foot_l": [("x", -24)],
              "thigh_r": [("x", 16), ("z", -4)], "calf_r": [("x", 56)], "foot_r": [("x", 6)], "pelvis": [("x", -6)]})
STOP = merge(sym({"upperarm_l": [("y", 4), ("z", 14)], "lowerarm_l": [("z", -20)], "hand_l": [("x", -10)]}),
             {"upperarm_r": [("y", -22), ("z", -14)]}, gloves(10, 6, spread=12), lean(fwd=-4), head(x=0, z=-2),
             {"thigh_l": [("x", -18), ("z", 4)], "calf_l": [("x", 12)], "foot_l": [("x", -10)],
              "thigh_r": [("x", 8), ("z", -4)], "calf_r": [("x", 30)], "foot_r": [("x", 4)]})


# the legs through the whole skid: heels dug in (front leg long, toes up), the back knee folded — the feet stay put,
# the stop is in the body (the view decelerates her along the lane)
LEGS = {"thigh_l": [("x", -30), ("z", 4)], "calf_l": [("x", 16)], "foot_l": [("x", -26)],
        "thigh_r": [("x", 16), ("z", -4)], "calf_r": [("x", 62)], "foot_r": [("x", 8)]}


def build(ctx):
    c = Clip(ctx, "hush/loco_skid", length=6, cheat_deg=20, blend_in=2, blend_out=8, audio="own")
    c.key(0, merge(RUN, LEGS))
    c.key(2, merge(DIG, LEGS), "out_quad")
    c.key(4, merge(OVER, LEGS), "in_out_sine")
    c.key(6, merge(STOP, LEGS, {"calf_r": [("x", 44)], "calf_l": [("x", 20)]}), "in_out_sine")
    c.ground()
    c.auto_plant(speed_m_s=0.0, release=1)
    c.pop_frames.extend([1, 2, 3])                   # the heels hit: an impact
    c.mark(2, "contact")
    c.sfx(2, "slide_down_short")
    c.event(2, "fx", id="dust")
    c.face(0, "determined")
    c.face(2, "shock")
    return c
