"""hush/freeze_5 — statue 5 of 8, THE HAT-TIP (REDESIGN §4.2 Freeze "she snaps into one of 8 statue poses"; statues 1–4
are r3d-anim's): the 2D statue timing kept — a 5-f hop-pop into the pose, the woodblock CLACK on the landing (f 5), a
held pose with a strained tremble and one blink (f 78), 150 f, played once and held. The view turns her to marble on a
plinth (eyes, beret and braces keep colour).

The hat-tip: a gentleman's greeting frozen mid-bow — the right glove tips the beret by its brim, a small bow from the
waist, the left arm swept out behind, one heel forward with the toes up.

`statue(ctx, clip_id, pose, doc_face)` is shared by freeze_5..8 (they import it)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head

L = 150
START = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-4))
DIP = merge(sym({"clavicle_l": [("y", 8)], "upperarm_l": [("y", 80), ("z", -6)], "lowerarm_l": [("z", -30)]}),
            gloves(40, 20), lean(fwd=10), head(x=10),
            {"thigh_l": [("x", -34)], "calf_l": [("x", 62)], "foot_l": [("x", -26)],
             "thigh_r": [("x", -30)], "calf_r": [("x", 58)], "foot_r": [("x", -26)]})
BLINK_F = 78


def tremble(f):
    """The strain of holding the pose: a fine shiver from the landing on (not in the legs — the feet stay planted)."""
    if f < 9:
        return {}
    a = math.sin(2 * math.pi * f * 7.0 / 60.0)
    b = math.sin(2 * math.pi * f * 5.5 / 60.0 + 1.1)
    return {"spine_03": [("y", 0.5 * a)], "neck_01": [("x", 0.4 * b)], "Head": [("z", 0.6 * a)],
            "upperarm_l": [("z", 0.7 * b)], "upperarm_r": [("z", -0.7 * a)], "hand_l": [("x", 1.0 * a)],
            "hand_r": [("x", 1.0 * b)]}


def statue(ctx, clip_id, pose, face="statue", over=None, lift=0.07, extra=None, ik=None):
    """A statue clip: START -> DIP (anticipation f 0-2) -> hop -> POSE pops at f 5 (clack) -> one overshoot -> the hold."""
    c = Clip(ctx, clip_id, length=L, cheat_deg=35, blend_in=2, blend_out=4, audio="own")
    c.key(0, START)
    c.key(2, DIP, "out_quad")
    c.key(5, over if over is not None else pose, "pop")
    c.pop_frames.append(6)                   # the snap rebounds into the hold (one overshoot)
    c.key(9, pose, "out_back")
    c.key(L, pose, "linear")
    c.motion(tremble)
    c.ground(lift=lambda f: lift * math.sin(math.pi * (f - 2) / 3.0) if 2 < f < 5 else 0.0)
    for sd in ("l", "r"):
        c.plant(sd, 0, 2)                     # the dip: the feet stay put until the hop
    c.freeze_hold(9, L)
    c.beats(anticipation=(0, 2), accent=(2, 5), hold=(9, L))
    c.sfx(5, "freeze_clack")
    c.face(0, "neutral")
    c.face(2, "shock")
    c.face(5, face)
    c.face(BLINK_F, "statue_blink")
    c.face(BLINK_F + 6, face)
    for side, target, pole, hand in (ik or []):                 # gloves pinned to the body (the beret brim …)
        c.ik(side, target, 4, L, pole=pole, hand=hand, effector="palm", blend=2)
    if extra:
        extra(c)
    return c


HAT_TIP = merge({"clavicle_r": [("y", 14), ("z", 8)], "upperarm_r": [("y", 60), ("z", 40)], "lowerarm_r": [("z", 110)]},
                {"clavicle_l": [("z", 10)], "upperarm_l": [("y", 50), ("z", 44)], "lowerarm_l": [("z", -10)],
                 "hand_l": [("x", 30)]},                                                         # the other arm swept back
                glove("r", 46, 26), glove("l", 4, 2, spread=16), lean(fwd=20, side=-4, turn=-8), head(x=-6, y=-12, z=-14),
                {"thigh_l": [("x", -16), ("z", 4)], "calf_l": [("x", 6)], "foot_l": [("x", -18)],        # heel forward, toes up
                 "thigh_r": [("x", 16), ("z", -4)], "calf_r": [("x", 14)], "foot_r": [("x", 8)], "pelvis": [("y", -4)]})
# the right glove on the brim of the beret (rest point on the head's right side, above the ear)
BRIM = ("r", ("Head", Vector((-0.12, -0.03, 1.52))), (-1.0, 0.2, 0.3), [("z", 90), ("x", 30)])


def build(ctx):
    return statue(ctx, "hush/freeze_5", HAT_TIP, face="smug", ik=[BRIM])
