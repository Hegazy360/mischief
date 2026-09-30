"""hush/rig_low — the band fallback for a LOW reach (0.00–0.55 m: rig_actions.json `bands.low`; N1/N2 pranks without a
clip of their own — LIFT-OFF's winding key under the recliner seat). Normalised (lock rig_pm), authored at 144 f (the
B tier's 150 f plays it at ~1×).

What it must read as (REDESIGN §4.2/§4.3 "reach-low"): she plops to her knees, drops onto all fours and crawls HALF
UNDER the thing — head and one arm out of sight under it, her bottom up and her legs sticking out toward the audience,
feet kicking — while the working glove cranks a big winding key in visible turns and the other glove braces on the
floor; she backs out, sits up on her knees and pops up. No baked glances (the view overlays act_glance at 30/60/90 %).

Staging as `rig_mid` (baked facing +1, cheat 10°, the thing ahead and up-stage at her front-left), glove target 0.28 m;
her hips and shoulders turn 40° into it so her legs stick out down-stage."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, breath
from rig_mid import stage

L = 144
Y = 0.28                          # the low target (under a seat / a low cupboard)
TARGET_W = (0.30, Y, -1.72)       # relative to reach_pos (x 0, z -1.5)
FLOOR_W = (0.30, 0.04, -1.60)     # where the bracing glove plants (under her up-stage shoulder)
DOWN, CRAWL, OUT, UP = 10, 22, 118, 132
WORK = (28, 112)                  # the winding: 4 big turns
KNEE_MIN = 0.06                   # the knees' clearance over the floor (the ground rule measures soles only)

REST = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-4))
# on her knees, upright (shins on the floor, toes pointed back)
KNEES = {"thigh_l": [("x", 0), ("y", -4)], "calf_l": [("x", 92)], "foot_l": [("x", 62)],
         "thigh_r": [("x", 4), ("y", 4)], "calf_r": [("x", 96)], "foot_r": [("x", 62)]}
# all fours, the hips high: the pelvis tips forward 50° and turns 40° into the thing; thighs back to vertical
def crawl(tip=50.0, turn=40.0):
    """All fours, the hips high: the pelvis tips forward and turns into the thing; the thighs back to vertical, both
    knees on the floor, the right toes on the floor, the left foot cocked up in the air (it waggles: kick())."""
    return {"pelvis": [("x", tip), ("z", turn)],
            "thigh_l": [("x", -tip + 10), ("y", -6)], "calf_l": [("x", 128)], "foot_l": [("x", 20)],
            "thigh_r": [("x", -tip + 10), ("y", 6)], "calf_r": [("x", 94)], "foot_r": [("x", 62)],
            "spine_01": [("x", 10)], "spine_02": [("x", 10)], "spine_03": [("x", 6), ("z", 6)],
            "neck_01": [("x", -30)], "Head": [("x", -24)]}


ARMS_CRAWL = {"upperarm_r": [("y", -40), ("z", 70)], "lowerarm_r": [("z", 30)], "hand_r": [("x", -30)],
              "upperarm_l": [("y", 70), ("z", -40)], "lowerarm_l": [("z", -10)], "hand_l": [("x", 40)]}
GRIP = merge(glove("r", 62, 34), glove("l", 6, 4, spread=12))


def kick(f):
    """The feet flutter while she works (a slow kick, one then the other)."""
    if not (WORK[0] <= f <= WORK[1]):
        return 0.0
    e = min(1.0, (f - WORK[0]) / 8.0, (WORK[1] - f) / 8.0)
    return e * math.sin(2 * math.pi * (f - WORK[0]) / 21.0)


def crank(f, T):
    u = min(1.0, max(0.0, (f - WORK[0]) / float(WORK[1] - WORK[0])))
    ang = 2.0 * math.pi * 4.0 * u
    r = 0.08
    return T + Vector((-0.12, 0.02, 0.10)) + Vector((0.0, r * math.cos(ang), r * math.sin(ang)))


def build(ctx):
    st = stage()
    T = st.to_char(TARGET_W)
    fl = st.to_char(FLOOR_W)
    c = Clip(ctx, "hush/rig_low", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own",
             notes="band fallback, low: glove target %.2f m, baked facing +1" % Y)
    c.key(0, REST)
    c.key(3, merge(REST, lean(fwd=4), head(x=4)), "in_out_sine")
    c.key(DOWN, merge(ARMS_DOWN, KNEES, gloves(10, 6, spread=10), lean(fwd=-4), head(x=-6)), "in_quad")   # PLOP on the knees
    c.key(16, merge(ARMS_CRAWL, crawl(tip=30, turn=24), gloves(20, 10), head(x=-6)), "in_out_sine")
    c.key(CRAWL, merge(ARMS_CRAWL, crawl(), GRIP), "in_out_cubic")                           # half under it
    c.key(OUT - 6, merge(ARMS_CRAWL, crawl(), GRIP), "in_out_sine")
    c.key(OUT, merge(ARMS_CRAWL, crawl(tip=40, turn=30), GRIP), "in_out_sine")               # backs out
    c.key(124, merge(ARMS_DOWN, KNEES, gloves(10, 6, spread=10), lean(fwd=-6), head(x=-8, y=6)), "in_out_cubic")   # sits up
    c.key(UP, merge(REST, {"thigh_l": [("x", -30)], "calf_l": [("x", 54)], "thigh_r": [("x", -28)], "calf_r": [("x", 50)]},
                    lean(fwd=12)), "out_quad")                                                 # pops up
    c.key(L, merge(REST, gloves(10, 6, spread=10), head(x=-2)), "out_back")
    c.motion(lambda f: breath(f, 36.0, 1.5))
    c.motion(lambda f: {"calf_l": [("x", -26 * kick(f))], "foot_l": [("x", 30 * kick(f))]})     # the cocked foot waggles
    # a little hop onto the knees (the feet leave the floor: they do not scrape back as she drops)
    c.ground(lift=lambda f: 0.09 * math.sin(math.pi * (f - 3) / 7.0) if 3 < f < DOWN else
             (0.12 * math.sin(math.pi * (f - 124) / 8.0) if 124 < f < UP else 0.0))       # ... and a pop back up to her feet

    def knees_clear(pose, f):
        """Knees and ankles (the shins lie on the floor, the insteps down) stay KNEE_MIN above it."""
        low = min(pose.pos("calf_l").z, pose.pos("calf_r").z, pose.pos("foot_l").z + 0.01, pose.pos("foot_r").z + 0.01)
        if low < KNEE_MIN:
            pose.add_pelvis_offset(Vector((0, 0, KNEE_MIN - low)))
    c.custom(knees_clear, 0, L)
    c.ik("r", lambda f: crank(f, T), 16, OUT + 2, pole=(-0.5, 0.2, 0.8), hand=[("z", 60), ("x", -40)], effector="palm",
         blend=6, world=False)
    c.ik("l", lambda f: fl, 14, OUT + 4, pole=(0.9, 0.2, 0.2), hand=[("x", -80), ("z", -20)], effector="palm", blend=5,
         world=False)
    # standing feet held (auto_plant cannot hold a pointed foot: its toe points straight down)
    for sd in ("l", "r"):
        c.plant(sd, 0, 3)
        c.plant(sd, UP, L)
    c.look(("camera",), 10, 128, weight=0.7, blend=8, bones=("neck_01", "Head"), share=(0.4, 0.6))
    c.pop_frames.extend([DOWN - 1, DOWN, DOWN + 1, UP])
    c.mark(DOWN, "contact")
    c.sfx(DOWN, "thud")
    for k in range(4):
        f = WORK[0] + int((WORK[1] - WORK[0]) * (k + 1) / 4.0) - 1
        c.mark(f, "contact")
        c.sfx(f, "tinker")
    c.sfx(UP, "boing_small")
    c.face(0, "sneak")
    c.face(DOWN, "determined")
    c.face(40, "frantic")
    c.face(60, "determined")
    c.face(88, "frantic")
    c.face(106, "determined")
    c.face(124, "grin")
    return c
