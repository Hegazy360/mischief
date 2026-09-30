"""hush/act_rummage — the rummage (REDESIGN §4.2 "Pick up" DURING; `state:rummage` / `state:pick_window`, loop, 0.6 s
cycle = 36 f): she has dived into the container up to her waist — folded over its rim at the hips, head and arms out
of sight inside, her bottom in the air and BOTH legs kicking up behind her in a flutter, the gloves digging in turns
(things rattle). Its silhouette is a folded L with the legs up — nothing like the dive's flat arc.

Facing: the fold is straight ahead of her (sagittal, no left/right bias), so it plays with any facing; the view should
yaw her toward the container while she rummages (request in the report: her back to the audience, the kicking legs
toward them, reads best)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import gloves, glove, head

L = 36
# folded over the rim: the hips bent, the torso plunging forward and down, the arms reaching in
FOLD = merge({"pelvis": [("x", 70)], "spine_01": [("x", 30)], "spine_02": [("x", 26)], "spine_03": [("x", 20)],
              "neck_01": [("x", -14)], "Head": [("x", -10)]},
             sym({"clavicle_l": [("z", -10), ("y", -10)], "upperarm_l": [("y", -64), ("z", -24)], "lowerarm_l": [("z", -24)],
                  "hand_l": [("x", -10)]}),
             {"upperarm_r": [("y", 58), ("z", 30)]}, gloves(30, 16))                 # arms reaching on in, past her head
LIFT = 0.18                     # the belly on the rim: the pelvis up so both feet leave the floor


def legs(f):
    """Both legs up behind her (the hips folded 62° forward), kicking in turn: 2 kicks a cycle."""
    a = 2 * math.pi * f / L
    kl = 0.5 + 0.5 * math.sin(a)
    kr = 0.5 + 0.5 * math.sin(a + math.pi)
    # the thighs hang down-and-back from the folded hips (the pelvis' 70° tip undone to ~25-45° past vertical),
    # the shins kick up behind
    return {"thigh_l": [("x", -48 + 20 * kl), ("y", -8)], "calf_l": [("x", 50 + 60 * kl)], "foot_l": [("x", 30 + 20 * kl)],
            "thigh_r": [("x", -50 + 20 * kr), ("y", 8)], "calf_r": [("x", 54 + 60 * kr)], "foot_r": [("x", 32 + 20 * kr)]}


def dig(f):
    """The gloves dig in turns inside the container (hidden, but the shoulders and elbows pump) + a bum wiggle."""
    a = 2 * math.pi * f / (L / 2.0)
    return {"clavicle_l": [("z", 8 * math.sin(a))], "clavicle_r": [("z", 8 * math.sin(a + 1.8))],
            "lowerarm_l": [("z", -18 * math.sin(a))], "lowerarm_r": [("z", 18 * math.sin(a + 1.8))],
            "pelvis": [("y", 5 * math.sin(2 * math.pi * f / L))], "spine_03": [("y", -4 * math.sin(2 * math.pi * f / L))]}


def build(ctx):
    c = Clip(ctx, "hush/act_rummage", length=L, loop=True, cheat_deg=20, blend_in=5, blend_out=6, audio="own")
    c.key(0, merge(FOLD, {"_pelvis": (0.0, 0.0, LIFT)}))
    c.key(L // 2, merge(FOLD, {"_pelvis": (0.0, 0.0, LIFT)}, {"spine_02": [("x", 20)]}))
    c.key(L, merge(FOLD, {"_pelvis": (0.0, 0.0, LIFT)}))
    c.motion(legs)
    c.motion(dig)
    for f in (0, L // 2):
        c.mark(f, "contact")
        c.sfx(f, "rustle")
    c.face(0, "determined")
    return c
